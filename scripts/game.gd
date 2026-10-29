extends Node3D

@onready var die: AudioStreamPlayer = $die
@onready var sky: WorldEnvironment = $World/Environment/Sky
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
	Global.on_pause.connect(pause_menu.show)
	Global.on_resume.connect(pause_menu.hide)
	LimboConsole.register_command(func(): $Player.toggle_noclip(),
		"noclip", "Toggle noclip.")
	LimboConsole.register_command(func(): _on_player_die(),
		"kill", "Kill yourself.")
	LimboConsole.register_command(func(): $Player.toggle_fastbreak(),
		"fast_break", "Break blocks instantly.")
	LimboConsole.register_command(func(scene_name: String): _spawn_entity(scene_name),
		"spawn", "Spawn scenes/entities/<name>.tscn in front of you.")
	LimboConsole.register_command(func(amount: float): _hurt_target(amount),
		"hurt", "Damage the entity you're looking at.")


func _spawn_entity(scene_name: String) -> void:
	var path := "res://scenes/entities/%s.tscn" % scene_name
	if not ResourceLoader.exists(path):
		LimboConsole.error("No entity scene at %s" % path)
		return
	var cam: Camera3D = $Player/Head/Camera
	$World.spawn_entity(load(path), cam.global_position - cam.global_basis.z * 3.0)


func _hurt_target(amount: float) -> void:
	var e: Entity = $Player.target_entity
	if e == null: return
	var health := e.get_component(HealthComponent) as HealthComponent
	if health != null: health.damage(amount, $Player)


func _on_player_die() -> void:
	Global.gameIsQuitting = true
	Global.music.stream_paused = true
	sky.environment.background_mode = Environment.BG_KEEP
	die.play()
	await die.finished
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Mhyworld is closing, we gotta clean up!")
		Global.gameIsQuitting = true
		Global.Tasks.force_wait_for_tasks()
		get_tree().quit()
