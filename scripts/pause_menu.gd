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
	# BUG: doesn't work, bad address index.
	# The game scene has to be torn down (chunk threads stopped, etc.) before switching scenes.
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
