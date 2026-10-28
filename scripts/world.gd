extends Node3D

const CHUNK_SCENE := preload("res://scenes/chunk.tscn")
const SAVE_DIR := "user://world/test/chunk"

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
				chunk.on_chunk_ready.connect(_check_player_chunk) # new
				add_child(chunk)


func _process(_delta: float) -> void:
	chunk_processing.call_deferred()


#region ChunkStreaming

## Chunks form a grid that wraps around the player on all 3 axes.
func chunk_processing() -> void:
	var player_chunk := Vector3i((player.position / Vector3(Global.CHUNK_SIZE)).floor())

	for c in get_children():
		if c is not Chunk: continue
		var cp: Vector3i = c.chunk_position
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


func get_chunk(pos: Vector3i) -> Chunk:
	var wrapped := Global.wrap_chunk(pos)
	for c in get_children():
		if c is Chunk and Global.wrap_chunk(c.chunk_position) == wrapped:
			return c
	return null


func _check_player_chunk(chunk: Chunk) -> void:
	if player_released: return
	var player_chunk := Vector3i((player.position / Vector3(Global.CHUNK_SIZE)).floor())
	if chunk.chunk_position == player_chunk:
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


func _on_player_place_block(pos: Vector3, block_idx: int) -> void:
	var is_breaking := block_idx == air_idx
	var cs := Global.CHUNK_SIZE
	var b := Vector3i(pos.floor()) # global block coords
	var chunk := get_chunk(Vector3i(
		floori(float(b.x) / cs.x),
		floori(float(b.y) / cs.y),
		floori(float(b.z) / cs.z)))
	if chunk == null or not chunk.hasChunkGenerated: return
	if not is_breaking and will_collide_with_player(pos): return

	var bx := posmod(b.x, cs.x)
	var by := posmod(b.y, cs.y)
	var bz := posmod(b.z, cs.z)

	if not chunk.blocksMutex.try_lock(): return
	var i := Chunk.block_index(bx, by, bz)
	var old_block := BlockRegistry.get_by_idx(chunk.blocks[i])
	if old_block != null and old_block.has_method("on_block_destroyed"):
		old_block.on_block_destroyed(Vector3i(bx, by, bz), chunk.chunk_position, chunk)
	chunk.blocks[i] = block_idx
	chunk.blocksMutex.unlock()

	chunk.request_remesh()
	if is_breaking:
		player.play_break_sfx()
	else:
		player.play_place_sfx()


func _on_player_break_block(pos: Vector3) -> void:
	_on_player_place_block(pos, air_idx)

#endregion

#region SavingAndDebug

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug4"):
		_print_chunk_sizes()


func _print_chunk_sizes() -> void:
	var total := 0
	for c in get_children():
		if c is not Chunk: continue
		var byte_count := var_to_bytes(c.blocks).size()
		print("%d bytes" % byte_count)
		total += byte_count
	print("total of %d bytes" % total)


func save_chunk_to_file(chunk: Chunk) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var cp := Global.wrap_chunk(chunk.chunk_position)
	var path := "%s/c.%d.%d.%d.chunk" % [SAVE_DIR, cp.x, cp.y, cp.z]
	var file := FileAccess.open(path, FileAccess.WRITE)
	WorldFile.new().write_chunk(chunk, file)

#endregion
