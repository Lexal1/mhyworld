extends Node3D

@onready var die: AudioStreamPlayer = $die
@onready var sky: WorldEnvironment = $World/Environment/Sky
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
	Global.on_pause.connect(pause_menu.show)
	Global.on_resume.connect(pause_menu.hide)
	LimboConsole.register_command(func(): $Player.enable_noclip(), "noclip", "Enable noclip.")
	LimboConsole.register_command(func(): $Player.disable_noclip(), "clip", "Disable noclip.")
	

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
