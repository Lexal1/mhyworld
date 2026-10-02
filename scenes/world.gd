extends Node3D

var chunk_scene = preload("res://scenes/chunk.tscn")

@export var render_distance = 5 ## Determines how many chunks to load around the player, in a radius.
@export var blockShape: Shape3D
@export var player: CharacterBody3D

@onready var environment: WorldEnvironment = $Environment/Sky

var _unfinished_thread_tasks: Array[int] = []

func _ready() -> void:
	for i in range(0, render_distance):
		for j in range(0, render_distance):
			var chunk = chunk_scene.instantiate()
			chunk.chunk_position = Vector2(i,j)
			add_child(chunk)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug1"):
		chunk_processing()
	self.call_deferred("chunk_processing")

func chunk_processing():
	for c in get_children():
		if c is not Chunk: continue
		var cx = c.chunk_position.x
		var cz = c.chunk_position.y
		
		var px = floor(player.position.x / Global.CHUNK_SIZE.x)
		var pz = floor(player.position.z / Global.CHUNK_SIZE.z)
		
		var newx = posmod(cx - px + render_distance/2, render_distance) + px - render_distance/2
		var newz = posmod(cz - pz + render_distance/2, render_distance) + pz - render_distance/2
		
		if (newx != cx or newz != cz):
			c.chunk_position = Vector2(int(newx),int(newz))
			_unfinished_thread_tasks.push_back(c.generate_and_update())
	_wait_for_tasks()

func _wait_for_tasks():
	var newUnfinishedTasks: Array[int] = []
	for task in _unfinished_thread_tasks:
		#WorkerThreadPool.wait_for_task_completion(task)
		if WorkerThreadPool.is_task_completed(task):
			var err = WorkerThreadPool.wait_for_task_completion(task) # this is needed so godot frees up the resources properly
			match err:
				OK:
					#print("[_wait_for_tasks] Task %d completed" % task)
					continue
				ERR_INVALID_PARAMETER:
					printerr("[_wait_for_tasks] Task %d doesn't exist" % task)
				ERR_BUSY:
					printerr("[_wait_for_tasks] Busy task: %d" % task)
		else:
			newUnfinishedTasks.push_back(task)
	_unfinished_thread_tasks = newUnfinishedTasks

func _force_wait_for_tasks():
	for task in _unfinished_thread_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_unfinished_thread_tasks = []

func get_chunk(pos):
	for c in get_children():
		if c.chunk_position == pos: return c
	return null

func will_collide_with_player(pos: Vector3):
	var space_state = get_world_3d().direct_space_state
	var parameters = PhysicsShapeQueryParameters3D.new()

	parameters.shape = blockShape
	parameters.transform = Transform3D(Basis(), pos)

	var result = space_state.intersect_shape(parameters)
	if result.size() > 0:
		for r in result:
			#print("Colliding with: ", r.collider.name)
			if r.collider == player:
				return true
	return false

func _on_player_place_block(pos: Vector3, t: Variant) -> void:
	var cx = int(floor(pos.x / Global.CHUNK_SIZE.x))
	var cz = int(floor(pos.z / Global.CHUNK_SIZE.z))
	
	var bx = posmod(floor(pos.x), Global.CHUNK_SIZE.x)
	var by = posmod(floor(pos.y), Global.CHUNK_SIZE.y)
	var bz = posmod(floor(pos.z), Global.CHUNK_SIZE.z)
	
	var c = get_chunk(Vector2(cx,cz))
	if c != null:
		if will_collide_with_player(pos) and t != BlockRegistry.get_idx_of(&"air"):
			return
		if not c.hasChunkGenerated:
			return
		if not c.blocksMutex.try_lock():
			return
		var block: int = c.blocks[bx][by][bz]
		var blockData = BlockRegistry.get_by_idx(block)
		if blockData != null:
			if blockData.has_method("on_block_destroyed"):
				blockData.on_block_destroyed(Vector3i(bx, by, bz), c.chunk_position, c)

		c.blocks[bx][by][bz] = t
		c.update()
		if t == BlockRegistry.get_idx_of(&"air"):
			player.play_break_sfx()
		else:
			player.play_place_sfx()
		c.blocksMutex.unlock()

func _on_player_break_block(pos: Variant) -> void: _on_player_place_block(pos, BlockRegistry.get_idx_of(&"air"))

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug4"):
		var byteSum = 0
		var chunks: Array[Node] = get_children()
		for chunk: StaticBody3D in chunks:
			var blocks: Array = chunk.blocks
			var lebytes: PackedByteArray = var_to_bytes(blocks)
			print("%d bytes" % len(lebytes))
			byteSum += len(lebytes)
		print("total of %d bytes" % byteSum)
