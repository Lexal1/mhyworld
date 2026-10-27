extends Node3D

const CHUNK_SCENE := preload("res://scenes/chunk.tscn")
const SAVE_DIR := "user://world/test/chunk"

@export var render_distance := 5 ## How many chunks to keep loaded along each axis.
@export var blockShape: Shape3D
@export var player: CharacterBody3D

var air_idx: int


func _ready() -> void:
	air_idx = BlockRegistry.get_idx_of(&"air")
	for x in render_distance:
		for z in render_distance:
			var chunk: Chunk = CHUNK_SCENE.instantiate()
			chunk.chunk_position = Vector2(x, z)
			chunk.on_chunk_ready.connect(save_chunk_to_file)
			add_child(chunk)


func _process(_delta: float) -> void:
	chunk_processing.call_deferred()


# ---------- Chunk streaming ----------

## Chunks form a render_distance x render_distance grid that wraps around the player.
func chunk_processing() -> void:
	var player_cx := floori(player.position.x / Global.CHUNK_SIZE.x)
	var player_cz := floori(player.position.z / Global.CHUNK_SIZE.z)

	for c in get_children():
		if c is not Chunk: continue
		var new_pos := Vector2(
			_wrap_axis(c.chunk_position.x, player_cx),
			_wrap_axis(c.chunk_position.y, player_cz))
		if new_pos != c.chunk_position:
			c.chunk_position = new_pos
			Global.Tasks.add_task(c.generate_and_update())
	Global.Tasks.wait_for_tasks()


## Moves a chunk coordinate to its slot inside the grid centred on the player.
@warning_ignore("integer_division")
func _wrap_axis(chunk_coord: float, player_coord: int) -> int:
	var half := render_distance / 2
	return posmod(int(chunk_coord) - player_coord + half, render_distance) + player_coord - half


func get_chunk(pos: Vector2) -> Chunk:
	for c in get_children():
		if c is Chunk and c.chunk_position == pos:
			return c
	return null


# ---------- Block editing ----------

func will_collide_with_player(pos: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = blockShape
	params.transform = Transform3D(Basis(), pos)

	for r in get_world_3d().direct_space_state.intersect_shape(params):
		if r.collider == player: return true
	return false


func _on_player_place_block(pos: Vector3, block_idx: int) -> void:
	var is_breaking := block_idx == air_idx
	var chunk := get_chunk(Vector2(
		floori(pos.x / Global.CHUNK_SIZE.x),
		floori(pos.z / Global.CHUNK_SIZE.z)))
	if chunk == null or not chunk.hasChunkGenerated: return
	if not is_breaking and will_collide_with_player(pos): return

	var bx := posmod(floori(pos.x), int(Global.CHUNK_SIZE.x))
	var by := posmod(floori(pos.y), int(Global.CHUNK_SIZE.y))
	var bz := posmod(floori(pos.z), int(Global.CHUNK_SIZE.z))

	if not chunk.blocksMutex.try_lock(): return
	var old_block := BlockRegistry.get_by_idx(chunk.blocks[bx][by][bz])
	if old_block != null and old_block.has_method("on_block_destroyed"):
		old_block.on_block_destroyed(Vector3i(bx, by, bz), chunk.chunk_position, chunk)
	chunk.blocks[bx][by][bz] = block_idx
	chunk.blocksMutex.unlock()

	chunk.request_remesh()
	if is_breaking:
		player.play_break_sfx()
	else:
		player.play_place_sfx()


func _on_player_break_block(pos: Vector3) -> void:
	_on_player_place_block(pos, air_idx)


# ---------- Debug / saving ----------

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
	var path := "%s/c.%d.%d.chunk" % [SAVE_DIR, chunk.chunk_position.x, chunk.chunk_position.y]
	var file := FileAccess.open(path, FileAccess.WRITE)
	WorldFile.new().write_chunk(chunk, file)
