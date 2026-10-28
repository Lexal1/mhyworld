@tool
class_name Chunk extends StaticBody3D

signal on_chunk_ready

const SX := Global.CHUNK_SIZE.x
const SY := Global.CHUNK_SIZE.y
const SZ := Global.CHUNK_SIZE.z
const SEAM := 128 ## Blocks before the world edge over which the wrap is blended.

@export var shaderMaterial: ShaderMaterial

var noise := FastNoiseLite.new()

# blocks[block_index(x, y, z)] = block index. Guarded by blocksMutex.
var blocks := PackedInt32Array()
var blocksMutex := Mutex.new()
var hasChunkGenerated := false

# Remesh bookkeeping
var _mesh_lock := Mutex.new()   # one meshing at a time (st is shared)
var _state_mutex := Mutex.new() # guards _meshing and _dirty
var _meshing := false
var _dirty := false

var solid_table: PackedByteArray
var air_idx: int
var stone_idx: int
var dirt_idx: int
var grass_idx: int

var st := SurfaceTool.new()
var mesh_instance: MeshInstance3D = null
var block_tags: Dictionary[Vector3, Variant] = {} # LightBlock stores its light here
var _face_count := 0

var _chunk_position := Vector3i.ZERO
var chunk_position := Vector3i.ZERO:
	get:
		return _chunk_position
	set(value):
		_chunk_position = value
		position = Vector3(value * Global.CHUNK_SIZE)
		self.visible = false


static func block_index(x: int, y: int, z: int) -> int:
	return (y * SZ + z) * SX + x


func _ready() -> void:
	solid_table = BlockRegistry.solid_table
	air_idx = BlockRegistry.get_idx_of(&"air")
	stone_idx = BlockRegistry.get_idx_of(&"stone")
	dirt_idx = BlockRegistry.get_idx_of(&"dirt")
	grass_idx = BlockRegistry.get_idx_of(&"grass")
	noise.seed = 128 if Engine.is_editor_hint() else int(Global.world_seed)

	if Engine.is_editor_hint():
		# Noise seed is fixed in the editor, so this lands on the surface.
		chunk_position.y = _height_at(0, 0) / Global.CHUNK_SIZE.y

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


#region TerrainGen

## Terrain height in world blocks. Only depends on world x and z.
func _height_at(gx: int, gz: int) -> int:
	return int((_periodic_noise(gx, gz) + 1) / 2 * Global.TERRAIN_HEIGHT)

func _periodic_noise(gx: int, gz: int) -> float:
	var n := Global.world_size
	var x := posmod(gx, n)
	var z := posmod(gz, n)
	var tx := smoothstep(n - SEAM, n, x) # 0 away from the edge, 1 right at it
	var a := _blend_z(x, z)
	if tx == 0.0: return a
	return lerpf(a, _blend_z(x - n, z), tx)

func _blend_z(x: int, z: int) -> float:
	var n := Global.world_size
	var a := noise.get_noise_2d(x, z)
	var tz := smoothstep(n - SEAM, n, z)
	if tz == 0.0: return a
	return lerpf(a, noise.get_noise_2d(x, z - n), tz)

## gy is the block's WORLD y, not its y inside the chunk.
@warning_ignore("integer_division")
func _block_for_height(gy: int, height: int) -> int:
	if gy < height / 2: return stone_idx
	if gy < height: return dirt_idx
	if gy == height: return grass_idx
	return air_idx


func _generate() -> void:
	blocksMutex.lock()
	hasChunkGenerated = false

	var origin := _chunk_position * Global.CHUNK_SIZE # world coords of this chunk's corner
	var new_blocks := PackedInt32Array()
	new_blocks.resize(SX * SY * SZ)

	for x in SX:
		for z in SZ:
			if Global.gameIsQuitting:
				blocksMutex.unlock()
				return
			# Height only depends on x and z, so compute it once per column.
			var height := _height_at(origin.x + x, origin.z + z)
			for y in SY:
				new_blocks[block_index(x, y, z)] = _block_for_height(origin.y + y, height)

	blocks = new_blocks
	blocksMutex.unlock()
	hasChunkGenerated = true

#endregion

#region Meshing

func update() -> void:
	_mesh_lock.lock()
	_update_mesh()
	_mesh_lock.unlock()


func update_async() -> int:
	return WorkerThreadPool.add_task(update)


func _update_mesh() -> void:
	if Global.gameIsQuitting: return

	blocksMutex.lock()
	var snap := blocks.duplicate() # the only time the lock is held
	blocksMutex.unlock()

	var old_instance := mesh_instance # freed last, so collision never disappears
	_face_count = 0

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for x in SX:
		for y in SY:
			for z in SZ:
				if Global.gameIsQuitting: return
				_create_block(snap, Vector3i(x, y, z))

	# All-air or fully buried chunks have no faces; an empty mesh makes
	# create_trimesh_collision() error, so don't build one.
	var new_instance: MeshInstance3D = null
	if _face_count > 0:
		st.generate_normals(false)
		st.set_material(shaderMaterial)
		new_instance = MeshInstance3D.new()
		new_instance.set_mesh(st.commit())
	else:
		st.clear()
	mesh_instance = new_instance

	if Engine.is_editor_hint():
		if old_instance: old_instance.queue_free()
		if new_instance:
			add_child(new_instance)
			new_instance.create_trimesh_collision()
		set_visible(true)
		return

	if old_instance: old_instance.queue_free.call_deferred()
	if new_instance:
		add_child.call_deferred(new_instance)
		new_instance.create_trimesh_collision.call_deferred()
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
	Global.Tasks.add_task(WorkerThreadPool.add_task(_remesh_loop, true))


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


func _is_transparent(snap: PackedInt32Array, x: int, y: int, z: int) -> bool:
	if x < 0 or x >= SX or y < 0 or y >= SY or z < 0 or z >= SZ:
		# Outside this chunk (any of the 6 sides): ask the terrain instead of loading the neighbour.
		var origin := _chunk_position * Global.CHUNK_SIZE
		return origin.y + y > _height_at(origin.x + x, origin.z + z)
	return solid_table[snap[block_index(x, y, z)]] == 0


func _create_block(snap: PackedInt32Array, pos: Vector3i) -> void:
	var block := snap[block_index(pos.x, pos.y, pos.z)]
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


func _add_face_if_exposed(snap: PackedInt32Array, face: Array, pos: Vector3i, dir: Vector3i, atlas_offset: Vector2) -> void:
	var n := pos + dir
	if _is_transparent(snap, n.x, n.y, n.z):
		_face_count += 1
		BlockMesh.add_face(st, face, Vector3(pos), atlas_offset)

#endregion
