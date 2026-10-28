extends Control

@onready var label: Label = $Label
@onready var debugging_button: Button = $MenuOptions/DebuggingButton
@export var player: CharacterBody3D


func _ready() -> void:
	Global.on_pause.connect(pause)
	Global.on_resume.connect(unpause)
	if not OS.is_debug_build():
		debugging_button.hide()


func _process(_delta: float) -> void:
	label.text = "\ntime:%s\nseed:%s\nxyz :%s" % [
		Time.get_unix_time_from_system(), Global.world_seed, Vector3i(player.position)]


func pause() -> void: $CRT/AnimationPlayer.play("tween_in")

func unpause() -> void: $CRT/AnimationPlayer.play("tween_out")


func _on_continue_button_pressed() -> void:
	Global.resume_game()


func _on_quit_button_pressed() -> void:
	Global.gameIsQuitting = true
	$"../World".process_mode = Node.PROCESS_MODE_DISABLED # stop queuing new chunk tasks
	Global.Tasks.force_wait_for_tasks()
	await get_tree().process_frame # let already-queued deferred calls run (they can add tasks)
	Global.Tasks.force_wait_for_tasks()

	# Global is an autoload, so it survives the scene change. Reset it.
	Global.gameIsQuitting = false
	Global.paused = false
	Global.state = Global.GameState.TITLE
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
