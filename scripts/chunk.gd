@tool
class_name Chunk extends StaticBody3D

signal on_chunk_ready

const SX := Global.CHUNK_SIZE.x
const SY := Global.CHUNK_SIZE.y
const SZ := Global.CHUNK_SIZE.z

@export var shaderMaterial: ShaderMaterial

var noise := FastNoiseLite.new()

# blocks[x][y][z] = block index. Guarded by blocksMutex.
var blocks = []
var blocksMutex := Mutex.new()
var hasChunkGenerated := false

# Remesh bookkeeping
var _mesh_lock := Mutex.new()   # one meshing at a time (st is shared)
var _state_mutex := Mutex.new() # guards _meshing and _dirty
var _meshing := false
var _dirty := false

var solid_table: PackedByteArray
var size: Vector3i
var air_idx: int
var stone_idx: int
var dirt_idx: int
var grass_idx: int

var st := SurfaceTool.new()
var mesh_instance: MeshInstance3D = null
var block_tags: Dictionary[Vector3, Variant] = {} # LightBlock stores its light here

var _chunk_position: Vector2
var chunk_position := Vector2.ZERO:
	get:
		return _chunk_position
	set(value):
		_chunk_position = value
		position = Vector3(value.x, 0, value.y) * Global.CHUNK_SIZE
		self.visible = false


func _ready() -> void:
	solid_table = BlockRegistry.solid_table
	size = Vector3i(Global.CHUNK_SIZE)
	air_idx = BlockRegistry.get_idx_of(&"air")
	stone_idx = BlockRegistry.get_idx_of(&"stone")
	dirt_idx = BlockRegistry.get_idx_of(&"dirt")
	grass_idx = BlockRegistry.get_idx_of(&"grass")
	noise.seed = 128 if Engine.is_editor_hint() else int(Global.world_seed)

	var task := generate_and_update()
	if task >= 0:
		Global.Tasks.add_task(task)


## Generates and meshes on a worker thread. Returns the task id (-1 in the editor, where it runs inline).
func generate_and_update() -> int:
	if Engine.is_editor_hint():
		_generate_and_update()
		return -1
	return WorkerThreadPool.add_task(_generate_and_update)


func _generate_and_update() -> void:
	# A regenerated chunk must drop its old block tags (e.g. lights).
	for key in block_tags:
		var obj: Variant = block_tags[key]
		if obj.has_method("queue_free"):
			obj.queue_free()
	block_tags = {}
	_generate()
	update()


# ---------- Terrain generation ----------

func _height_at(global_pos: Vector2) -> int:
	return int((noise.get_noise_2dv(global_pos) + 1) / 2 * SY)


@warning_ignore("integer_division")
func _block_for_height(y: int, height: int) -> int:
	if y < height / 2: return stone_idx
	if y < height: return dirt_idx
	if y == height: return grass_idx
	return air_idx


func _generate() -> void:
	blocksMutex.lock()
	blocks = []
	hasChunkGenerated = false

	blocks.resize(size.x)
	for x in size.x:
		if Global.gameIsQuitting:
			blocksMutex.unlock()
			return

		# Height only depends on x and z, so compute it once per column.
		var heights := PackedInt32Array()
		heights.resize(size.z)
		for z in size.z:
			heights[z] = _height_at(chunk_position * Vector2(size.x, size.z) + Vector2(x, z))

		blocks[x] = []
		blocks[x].resize(size.y)
		for y in size.y:
			blocks[x][y] = []
			blocks[x][y].resize(size.z)
			for z in size.z:
				blocks[x][y][z] = _block_for_height(y, heights[z])

	blocksMutex.unlock()
	hasChunkGenerated = true


# ---------- Meshing ----------

func update() -> void:
	_mesh_lock.lock()
	_update_mesh()
	_mesh_lock.unlock()


func update_async() -> int:
	return WorkerThreadPool.add_task(update)


func _update_mesh() -> void:
	if Global.gameIsQuitting: return

	blocksMutex.lock()
	var snap: Array = blocks.duplicate(true) # the only time the lock is held
	blocksMutex.unlock()

	var old_instance := mesh_instance # freed last, so collision never disappears
	mesh_instance = MeshInstance3D.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for x in size.x:
		for y in size.y:
			for z in size.z:
				if Global.gameIsQuitting: return
				_create_block(snap, Vector3i(x, y, z))
	st.generate_normals(false)
	st.set_material(shaderMaterial)
	mesh_instance.set_mesh(st.commit())

	if Engine.is_editor_hint():
		if old_instance: old_instance.queue_free()
		add_child(mesh_instance)
		mesh_instance.create_trimesh_collision()
		set_visible(true)
		return

	if old_instance: old_instance.queue_free.call_deferred()
	add_child.call_deferred(mesh_instance)
	mesh_instance.create_trimesh_collision.call_deferred()
	set_visible.call_deferred(true)
	on_chunk_ready.emit.call_deferred(self)


## Remeshes on a worker thread. Requests made mid-mesh are merged into one extra pass.
func request_remesh() -> void:
	_state_mutex.lock()
	if _meshing:
		_dirty = true # the running worker will loop again
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


func _is_transparent(snap: Array, x: int, y: int, z: int) -> bool:
	if y < 0: return false  # nothing renders under the world (REPLACE WITH CUBIC CHUNKS IMPL!!!!!)
	if y >= SY: return true # open sky
	if x < 0 or x >= SX or z < 0 or z >= SZ:
		# Neighbouring chunk: ask the noise instead of loading it.
		var global_pos := chunk_position * Vector2(SX, SZ) + Vector2(x, z)
		return y > _height_at(global_pos) # above the ground = transparent
	return solid_table[snap[x][y][z]] == 0


func _create_block(snap: Array, pos: Vector3i) -> void:
	var block: int = snap[pos.x][pos.y][pos.z]
	if block == air_idx: return

	var block_data: Block = BlockRegistry.get_by_idx(block)
	var atlas := block_data.atlas_position

	_add_face_if_exposed(snap, BlockMesh.TOP,    pos, Vector3i(0, 1, 0),  atlas.TOP)
	_add_face_if_exposed(snap, BlockMesh.BOTTOM, pos, Vector3i(0, -1, 0), atlas.BOTTOM)
	_add_face_if_exposed(snap, BlockMesh.NORTH,  pos, Vector3i(0, 0, 1),  atlas.NORTH)
	_add_face_if_exposed(snap, BlockMesh.SOUTH,  pos, Vector3i(0, 0, -1), atlas.SOUTH)
	_add_face_if_exposed(snap, BlockMesh.EAST,   pos, Vector3i(1, 0, 0),  atlas.EAST)
	_add_face_if_exposed(snap, BlockMesh.WEST,   pos, Vector3i(-1, 0, 0), atlas.WEST)

	if block_data.has_method("on_block_created"):
		block_data.on_block_created(pos, chunk_position, self)


func _add_face_if_exposed(snap: Array, face: Array, pos: Vector3i, dir: Vector3i, atlas_offset: Vector2) -> void:
	var n := pos + dir
	if _is_transparent(snap, n.x, n.y, n.z):
		BlockMesh.add_face(st, face, Vector3(pos), atlas_offset)
