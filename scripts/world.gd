extends Node3D

const CHUNK_SCENE := preload("res://scenes/chunk.tscn")
const SAVE_DIR := "user://world/test/chunk"
const MAX_IN_FLIGHT := 4 ## Generation tasks running at once. Try around your CPU core count.
const DROPPED_ITEM_SCENE := preload("res://scenes/entities/dropped_item.tscn")

@export var render_distance := 5 ## How many chunks to keep loaded along X and Z.
@export var vertical_render_distance := 5 ## How many chunks to keep loaded along Y.
@export var blockShape: Shape3D
@export var player: CharacterBody3D

var air_idx: int
var player_released := false
var _pending: Array[Chunk] = []    # chunks waiting to be generated
var _generating: Array[Chunk] = [] # chunks currently on a worker thread
var _spawn_chunks: Array[Vector3i] = [] # must be ready before the player is released
var _chunk_map := {}  # wrapped chunk position -> Chunk
var _map_mutex := Mutex.new()
var _entities: Node3D # parent for every spawned entity

func _ready() -> void:
	_entities = Node3D.new()
	_entities.name = "Entities"
	add_child(_entities)
	air_idx = BlockRegistry.get_idx_of(&"air")
	_place_player_at_spawn()
	var pc := _player_chunk()
	for x in render_distance:
		for y in vertical_render_distance:
			for z in render_distance:
				var chunk: Chunk = CHUNK_SCENE.instantiate()
				chunk.auto_generate = false # we schedule it ourselves
				# Put it straight into its slot around the player, no wrap-around later.
				chunk.chunk_position = Vector3i(
					_wrap_axis(x, pc.x, render_distance),
					_wrap_axis(y, pc.y, vertical_render_distance),
					_wrap_axis(z, pc.z, render_distance))
				_register_chunk(chunk, chunk.chunk_position, chunk.chunk_position)
				chunk.on_chunk_ready.connect(save_chunk_to_file)
				chunk.on_chunk_ready.connect(_check_player_chunk)
				add_child(chunk)
				_pending.push_back(chunk)


func _process(_delta: float) -> void:
	chunk_processing.call_deferred()


#region ChunkLookup

func _chunks() -> Array[Chunk]:
	var result: Array[Chunk] = []
	for c in get_children():
		if c is Chunk: result.push_back(c)
	return result


func get_chunk(pos: Vector3i) -> Chunk:
	return lookup_chunk(pos)


## Thread-safe. Chunks call this from worker threads while meshing.
func lookup_chunk(pos: Vector3i) -> Chunk:
	var key := Global.wrap_chunk(pos)
	_map_mutex.lock()
	var c: Chunk = _chunk_map.get(key)
	_map_mutex.unlock()
	return c


func _register_chunk(c: Chunk, old_pos: Vector3i, new_pos: Vector3i) -> void:
	_map_mutex.lock()
	var old_key := Global.wrap_chunk(old_pos)
	if _chunk_map.get(old_key) == c: # another chunk may already own this slot
		_chunk_map.erase(old_key)
	_chunk_map[Global.wrap_chunk(new_pos)] = c
	_map_mutex.unlock()


func _player_chunk() -> Vector3i:
	return Vector3i((player.position / Vector3(Global.CHUNK_SIZE)).floor())


## Which chunk a global block coordinate lives in.
func _chunk_of_block(b: Vector3i) -> Vector3i:
	var cs := Global.CHUNK_SIZE
	return Vector3i(floori(float(b.x) / cs.x), floori(float(b.y) / cs.y), floori(float(b.z) / cs.z))


## A global block coordinate, relative to its own chunk's corner.
func _local_in_chunk(b: Vector3i) -> Vector3i:
	var cs := Global.CHUNK_SIZE
	return Vector3i(posmod(b.x, cs.x), posmod(b.y, cs.y), posmod(b.z, cs.z))

#endregion


#region ChunkStreaming

## Chunks form a grid that wraps around the player on all 3 axes.
func chunk_processing() -> void:
	var player_chunk := _player_chunk()

	for c in _chunks():
		var cp := c.chunk_position
		var new_pos := Vector3i(
			_wrap_axis(cp.x, player_chunk.x, render_distance),
			_wrap_axis(cp.y, player_chunk.y, vertical_render_distance),
			_wrap_axis(cp.z, player_chunk.z, render_distance))
		if new_pos != cp:
			_register_chunk(c, cp, new_pos)
			c.chunk_position = new_pos
			if not _pending.has(c): _pending.push_back(c)
	_dispatch_pending(player_chunk)
	Global.Tasks.wait_for_tasks()


## Lower = load sooner. Vertical distance counts extra so chunks directly
## under the player don't beat the surface chunks beside them.
func _priority(c: Chunk, pc: Vector3i) -> int:
	var d := c.chunk_position - pc
	return d.x * d.x + d.z * d.z + d.y * d.y * 4


func _dispatch_pending(pc: Vector3i) -> void:
	# Forget chunks whose terrain has finished generating.
	var still: Array[Chunk] = []
	for c in _generating:
		if not c.hasChunkGenerated: still.append(c)
	_generating = still

	if _pending.is_empty(): return
	_pending.sort_custom(func(a: Chunk, b: Chunk): return _priority(a, pc) < _priority(b, pc))

	var i := 0
	while i < _pending.size() and _generating.size() < MAX_IN_FLIGHT:
		var c := _pending[i]
		if _generating.has(c): # moved again mid-generation: wait for it to finish
			i += 1
			continue
		_pending.remove_at(i)
		c.hasChunkGenerated = false
		_generating.push_back(c)
		Global.Tasks.add_task(c.generate_and_update())


## A block on a chunk's edge changes the faces of the chunk next to it.
## Corner blocks touch up to 3 neighbours, so this checks each axis.
func _remesh_border_neighbors(chunk: Chunk, local: Vector3i) -> void:
	var cs := Global.CHUNK_SIZE
	for axis in 3:
		var dir := Vector3i.ZERO
		if local[axis] == 0: dir[axis] = -1
		elif local[axis] == cs[axis] - 1: dir[axis] = 1
		else: continue
		var n := get_chunk(chunk.chunk_position + dir)
		if n != null and n.hasChunkGenerated:
			n.request_remesh()


## Moves a chunk coordinate to its slot inside a grid of `count` chunks centred on the player.
@warning_ignore("integer_division")
func _wrap_axis(chunk_coord: int, player_coord: int, count: int) -> int:
	var half := count / 2
	return posmod(chunk_coord - player_coord + half, count) + player_coord - half


## Puts the player just above solid ground and records which chunks must exist first.
func _place_player_at_spawn() -> void:
	var terrain := TerrainGenerator.for_seed(Global.world_seed)
	var gx := floori(player.position.x)
	var gz := floori(player.position.z)

	# Noise height ignores caves, so walk down to the first block that is really solid.
	var ground := terrain.sample_column(gx, gz).x
	while ground > 0 and not terrain.is_solid(gx, ground, gz):
		ground -= 1

	player.position.y = ground + 2
	_spawn_chunks.clear()
	for y in [ground, ground + 2]: # the block we stand on, and where our head is
		var cp := _chunk_of_block(Vector3i(gx, y, gz))
		if not _spawn_chunks.has(cp): _spawn_chunks.push_back(cp)


func _check_player_chunk(_chunk: Chunk) -> void:
	if player_released: return
	for cp in _spawn_chunks:
		var c := get_chunk(cp)
		# visible = meshed, and generated_at check = not stale from being moved
		if c == null or not c.hasChunkGenerated or not c.visible \
				or c.generated_at != c.chunk_position:
			return
	player_released = true
	player.frozen = false

#endregion


#region BlockEditing

func will_collide_with_player(pos: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = blockShape
	params.transform = Transform3D(Basis(), pos)

	for r in get_world_3d().direct_space_state.intersect_shape(params):
		if r.collider == player: return true
	return false


## Placing air is breaking, so one function handles both.
func _on_player_place_block(pos: Vector3, block_idx: int) -> void:
	var is_breaking := block_idx == air_idx
	var block_pos := Vector3i(pos.floor())

	var chunk := get_chunk(_chunk_of_block(block_pos))
	if chunk == null or not chunk.hasChunkGenerated: return
	if not is_breaking and will_collide_with_player(pos): return
	if not chunk.blocksMutex.try_lock(): return

	var local := _local_in_chunk(block_pos)
	var i := Chunk.block_index(local.x, local.y, local.z)
	var old_block: Block = BlockRegistry.get_by_idx(chunk.blocks[i])
	if old_block != null:
		old_block.on_block_destroyed(local, chunk.chunk_position, chunk)
	chunk.blocks[i] = block_idx
	chunk.blocksMutex.unlock()

	chunk.request_remesh()
	_remesh_border_neighbors(chunk, local)
	if is_breaking:
		_drop_block(old_block, pos)
		player.play_break_sfx()
	else:
		player.play_place_sfx()


func _on_player_break_block(pos: Vector3) -> void:
	_on_player_place_block(pos, air_idx)


func get_block_at(pos: Vector3) -> Block:
	var cs := Global.CHUNK_SIZE
	var b := Vector3i(pos.floor())
	var chunk := get_chunk(Vector3i(
		floori(float(b.x) / cs.x),
		floori(float(b.y) / cs.y),
		floori(float(b.z) / cs.z)))
	if chunk == null or not chunk.hasChunkGenerated: return null
	if not chunk.blocksMutex.try_lock(): return null
	var idx := chunk.blocks[Chunk.block_index(posmod(b.x, cs.x), posmod(b.y, cs.y), posmod(b.z, cs.z))]
	chunk.blocksMutex.unlock()
	return BlockRegistry.get_by_idx(idx)


## `block_center` is already the middle of the broken block (the player passes it that way).
func _drop_block(block: Block, block_center: Vector3) -> void:
	if block == null or block.id == &"air": return
	spawn_entity(DROPPED_ITEM_SCENE, block_center, func(e: Entity):
		var item := e.get_component(ItemComponent) as ItemComponent
		item.item_id = block.id # drop id = block id, which is what ItemComponent and Inventory look up
		e.velocity = Vector3(randf_range(-1.0, 1.0), 3.0, randf_range(-1.0, 1.0)))

#endregion


#region SavingAndDebug

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug4"):
		_print_chunk_sizes()


func _print_chunk_sizes() -> void:
	var total := 0
	for c in _chunks():
		var byte_count := var_to_bytes(c.blocks).size()
		print("%d bytes" % byte_count)
		total += byte_count
	print("total of %d bytes" % total)


func save_chunk_to_file(chunk: Chunk) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var cp := Global.wrap_chunk(chunk.chunk_position)
	var path := "%s/c.%d.%d.%d.chunk" % [SAVE_DIR, cp.x, cp.y, cp.z]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Couldn't save chunk to %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	WorldFile.new().write_chunk(chunk, file)

#endregion


## `setup` runs on the entity before it enters the tree, so components can be configured first.
func spawn_entity(scene: PackedScene, pos: Vector3, setup := Callable()) -> Entity:
	var node := scene.instantiate()
	if not node is Entity:
		printerr("%s root isn't an Entity" % scene.resource_path)
		node.free()
		return null
	var e := node as Entity
	e.world = self
	e.position = pos
	if setup.is_valid(): setup.call(e)
	_entities.add_child(e)
	return e


## True once the chunk at `pos` is meshed, i.e. has collision.
func is_position_loaded(pos: Vector3) -> bool:
	var c := get_chunk(_chunk_of_block(Vector3i(pos.floor())))
	return c != null and c.hasChunkGenerated and c.visible and c.generated_at == c.chunk_position
