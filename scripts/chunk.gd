@tool
class_name Chunk extends StaticBody3D

signal on_chunk_ready

const vertices = [
	Vector3(0,0,0),
	Vector3(1,0,0),
	Vector3(0,1,0),
	Vector3(1,1,0),
	Vector3(0,0,1),
	Vector3(1,0,1),
	Vector3(0,1,1),
	Vector3(1,1,1)
]

const TOP =    [2,3,7,6]
const BOTTOM = [0,4,5,1]
const NORTH =  [7,5,4,6]
const SOUTH =  [2,0,1,3]
const EAST =   [3,1,5,7]
const WEST =   [6,4,0,2]

const SX := Global.CHUNK_SIZE.x
const SY := Global.CHUNK_SIZE.y
const SZ := Global.CHUNK_SIZE.z


@export var shaderMaterial: ShaderMaterial

var noise := FastNoiseLite.new()

var blocksMutex := Mutex.new()
var _mesh_lock := Mutex.new()    # one meshing at a time (st is shared)
var _state_mutex := Mutex.new()  # guards the two flags below
var _meshing := false
var _dirty := false

var blocks = []
var hasChunkGenerated := false

var solid_table: PackedByteArray
var size: Vector3i

var st = SurfaceTool.new()
var mesh : Mesh = null
var mesh_instance : MeshInstance3D = null
var block_tags: Dictionary[Vector3, Variant] = {}
var air_idx: int

var material = preload("res://assets/resources/new_standard_material_3d.tres")

var _chunk_position: Vector2
var chunk_position := Vector2.ZERO:
	get:
		return _chunk_position
	set(value):
		_chunk_position = value
		position = Vector3(value.x, 0, value.y) * Global.CHUNK_SIZE
		self.visible = false

func _ready():
	solid_table = BlockRegistry.solid_table
	size = Vector3i(Global.CHUNK_SIZE)
	air_idx = BlockRegistry.get_idx_of(&"air")
	if Engine.is_editor_hint():
		noise.seed = 128
	else:
		noise.seed = Global.world_seed
	Global.Tasks.add_task(generate_and_update())

func generate_and_update():
	if Engine.is_editor_hint():
		_generate_and_update()
		return
	return WorkerThreadPool.add_task(_generate_and_update)
	
func _generate_and_update():
	# if chunk is regenerated then we need to clear out the block tags
	for key in block_tags:
		var obj: Variant = block_tags[key]
		if obj.has_method("queue_free"): # mfs better not put a primitive in there
			obj.queue_free()
	block_tags = {}
	_generate()
	update()

func _generate():
	blocksMutex.lock()
	blocks = []
	hasChunkGenerated = false
	if Global.gameIsQuitting:
		blocksMutex.unlock()
		return

	var size := Vector3i(Global.CHUNK_SIZE)
	var air := BlockRegistry.get_idx_of(&"air")
	var stone := BlockRegistry.get_idx_of(&"stone")
	var dirt := BlockRegistry.get_idx_of(&"dirt")
	var grass := BlockRegistry.get_idx_of(&"grass")

	blocks.resize(size.x)
	for i in size.x:
		# height only depends on x and z, so compute it once per column
		var heights := PackedInt32Array()
		heights.resize(size.z)
		for k in size.z:
			var global_pos = chunk_position * Vector2(size.x, size.z) + Vector2(i, k)
			heights[k] = int((noise.get_noise_2dv(global_pos) + 1) / 2 * size.y)

		blocks[i] = []
		blocks[i].resize(size.y)
		for j in size.y:
			blocks[i][j] = []
			blocks[i][j].resize(size.z)
			for k in size.z:
				if Global.gameIsQuitting:
					blocksMutex.unlock()
					return
				var height := heights[k]
				var block := air
				if j < height / 2:
					block = stone
				elif j < height:
					block = dirt
				elif j == height:
					block = grass
				blocks[i][j][k] = block

	blocksMutex.unlock()
	hasChunkGenerated = true

func update():
	_mesh_lock.lock()
	_update_mesh()
	_mesh_lock.unlock()

func update_async() -> int:
	return WorkerThreadPool.add_task(update)

func _update_mesh():
	if Global.gameIsQuitting: return

	blocksMutex.lock()
	var snap: Array = blocks.duplicate(true)   # the only time the lock is held
	blocksMutex.unlock()

	var old_instance := mesh_instance          # free it last, so collision never disappears
	mesh = ArrayMesh.new()
	mesh_instance = MeshInstance3D.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for x in size.x:
		for y in size.y:
			for z in size.z:
				if Global.gameIsQuitting: return
				create_block(snap, x, y, z)
	st.generate_normals(false)
	st.set_material(shaderMaterial)
	mesh = st.commit()
	mesh_instance.set_mesh(mesh)
	if Engine.is_editor_hint():
		if old_instance: old_instance.queue_free()
		add_child(mesh_instance)
		mesh_instance.create_trimesh_collision()
		set_visible(true)
		return
	if old_instance: old_instance.queue_free.call_deferred()
	self.call_deferred("add_child", mesh_instance)
	mesh_instance.create_trimesh_collision.call_deferred()
	self.call_deferred("set_visible", true)
	on_chunk_ready.emit.call_deferred(self)

func request_remesh() -> void:
	_state_mutex.lock()
	if _meshing:
		_dirty = true            # worker will loop again when it finishes
		_state_mutex.unlock()
		return
	_meshing = true
	_state_mutex.unlock()
	Global.Tasks.add_task(WorkerThreadPool.add_task(_remesh_loop))

func _remesh_loop() -> void:
	while true:
		update()
		_state_mutex.lock()
		if not _dirty:
			_meshing = false
			_state_mutex.unlock()
			return
		_dirty = false
		_state_mutex.unlock()

func check_transparency(b: Array, x: int, y: int, z: int) -> bool:
	if y < 0: return false   # nothing renders under the world (REPLACE WITH CUBIC CHUNKS IMPL!!!!!)
	if y >= SY: return true  # open sky
	if x < 0 or x >= SX or z < 0 or z >= SZ:
		var global_pos := chunk_position * Vector2(SX, SZ) + Vector2(x, z)
		var height := int((noise.get_noise_2dv(global_pos) + 1) / 2 * SY)
		return y > height    # above the ground = transparent
	return solid_table[b[x][y][z]] == 0

func create_block(b: Array, x, y, z):
	var block = b[x][y][z]
	if block == air_idx: return

	var block_data: Block = BlockRegistry.get_by_idx(block)
	var atlas_data = block_data.atlas_position

	if check_transparency(b, x, y+1, z): create_face(TOP, x,y,z, atlas_data.TOP)
	if check_transparency(b, x, y-1, z): create_face(BOTTOM, x,y,z, atlas_data.BOTTOM)
	if check_transparency(b, x, y, z+1): create_face(NORTH, x,y,z, atlas_data.NORTH)
	if check_transparency(b, x, y, z-1): create_face(SOUTH, x,y,z, atlas_data.SOUTH)
	if check_transparency(b, x+1, y, z): create_face(EAST, x,y,z, atlas_data.EAST)
	if check_transparency(b, x-1, y, z): create_face(WEST, x,y,z, atlas_data.WEST)

	if block_data.has_method("on_block_created"):
		block_data.on_block_created(Vector3i(x, y, z), chunk_position, self)

func create_face(i, x,y,z, atlas_offset): #what is this, miitopia?
	var offset = Vector3(x,y,z)
	var a = vertices[i[0]] + offset
	var b = vertices[i[1]] + offset
	var c = vertices[i[2]] + offset
	var d = vertices[i[3]] + offset
	
	var uv_offset = atlas_offset / Global.TEXTURE_ATLAS_SIZE
	var height = 1.0 / Global.TEXTURE_ATLAS_SIZE.y
	var width = 1.0 / Global.TEXTURE_ATLAS_SIZE.x
	
	var uv_a = uv_offset + Vector2.ZERO
	var uv_b = uv_offset + Vector2(0,height)
	var uv_c = uv_offset + Vector2(width,height)
	var uv_d = uv_offset + Vector2(width,0)
	
	st.add_triangle_fan(([a,b,c]), ([uv_a,uv_b,uv_c]))
	st.add_triangle_fan(([a,c,d]), ([uv_a,uv_c,uv_d]))
	
