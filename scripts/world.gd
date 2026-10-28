extends Node3D

const CHUNK_SCENE := preload("res://scenes/chunk.tscn")
const SAVE_DIR := "user://world/test/chunk"
const MAX_IN_FLIGHT := 4 ## Generation tasks running at once. Try around your CPU core count.


@export var render_distance := 5 ## How many chunks to keep loaded along X and Z.
@export var vertical_render_distance := 5 ## How many chunks to keep loaded along Y.
@export var blockShape: Shape3D
@export var player: CharacterBody3D

var air_idx: int
var player_released := false

func _ready() -> void:
	air_idx = BlockRegistry.get_idx_of(&"air")
	for x in render_distance:
		for y in vertical_render_distance:
			for z in render_distance:
				var chunk: Chunk = CHUNK_SCENE.instantiate()
				chunk.chunk_position = Vector3i(x, y, z)
				chunk.on_chunk_ready.connect(save_chunk_to_file)
				chunk.on_chunk_ready.connect(_check_player_chunk)
				add_child(chunk)


func _process(_delta: float) -> void:
	chunk_processing.call_deferred()


#region ChunkLookup

func _chunks() -> Array[Chunk]:
	var result: Array[Chunk] = []
	for c in get_children():
		if c is Chunk: result.push_back(c)
	return result


func get_chunk(pos: Vector3i) -> Chunk:
	var wrapped := Global.wrap_chunk(pos)
	for c in _chunks():
		if Global.wrap_chunk(c.chunk_position) == wrapped:
			return c
	return null


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
			c.chunk_position = new_pos
			Global.Tasks.add_task(c.generate_and_update())
	Global.Tasks.wait_for_tasks()


## Moves a chunk coordinate to its slot inside a grid of `count` chunks centred on the player.
@warning_ignore("integer_division")
func _wrap_axis(chunk_coord: int, player_coord: int, count: int) -> int:
	var half := count / 2
	return posmod(chunk_coord - player_coord + half, count) + player_coord - half


func _check_player_chunk(chunk: Chunk) -> void:
	if player_released: return
	if chunk.chunk_position == _player_chunk():
		player.position.y = chunk._height_at(0, 0) + 2
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
	var old_block := BlockRegistry.get_by_idx(chunk.blocks[i])
	if old_block != null:
		old_block.on_block_destroyed(local, chunk.chunk_position, chunk)
	chunk.blocks[i] = block_idx
	chunk.blocksMutex.unlock()

	chunk.request_remesh()
	if is_breaking:
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
