extends Node3D

var chunk_scene = preload("res://scenes/chunk.tscn")

@export var render_distance = 5 ## Determines how many chunks to load around the player, in a radius.
@export var blockShape: Shape3D

@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $Player
@onready var environment: WorldEnvironment = $Environment/Sky
@onready var die: AudioStreamPlayer = $die
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
	for i in range(0, render_distance):
		for j in range(0, render_distance):
			var chunk = chunk_scene.instantiate()
			chunk.chunk_position = Vector2(i,j)
			world.add_child(chunk)
	Global.on_pause.connect(show_pause_menu)
	Global.on_resume.connect(hide_pause_menu)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug1"):
		chunk_processing()
	self.call_deferred("chunk_processing")

func chunk_processing():
	var tasks = []
	for c in world.get_children():
		var cx = c.chunk_position.x
		var cz = c.chunk_position.y
		
		var px = floor(player.position.x / Global.CHUNK_SIZE.x)
		var pz = floor(player.position.z / Global.CHUNK_SIZE.z)
		
		var newx = posmod(cx - px + render_distance/2, render_distance) + px - render_distance/2
		var newz = posmod(cz - pz + render_distance/2, render_distance) + pz - render_distance/2
		
		if (newx != cx or newz != cz):
			c.chunk_position = Vector2(int(newx),int(newz))
			tasks.push_back(c.generate_and_update())

func _wait_for_tasks(tasks: Array):
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
func get_chunk(pos):
	for c in world.get_children():
		if c.chunk_position == pos:
			return c
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
		c.blocks[bx][by][bz] = t
		c.update()
		if t == BlockRegistry.get_idx_of(&"air"):
			player.play_break_sfx()
		else:
			player.play_place_sfx()

func _on_player_break_block(pos: Variant) -> void:
	_on_player_place_block(pos, BlockRegistry.get_idx_of(&"air"))

func _on_player_die() -> void:
	Global.music.stream_paused = true
	environment.environment.background_mode = Environment.BG_KEEP
	die.play()
	await die.finished
	get_tree().quit()
	
func show_pause_menu():
	pause_menu.show()

func hide_pause_menu():
	pause_menu.hide()
