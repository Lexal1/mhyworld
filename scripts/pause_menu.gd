extends Control

@onready var label: Label = $Label
@onready var debugging_button: Button = $MenuOptions/DebuggingButton
@export var player: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var global = get_node("/root/Global")
	global.on_pause.connect(pause)
	global.on_resume.connect(unpause)
	if not OS.is_debug_build():
		debugging_button.hide()

func _process(delta: float) -> void:
	label.text = \
	"\ntime:"+str(Time.get_unix_time_from_system())+ \
	"\nseed:"+str(Global.world_seed)+ \
	"\nxyz :"+str(Vector3i(player.position))

func pause(): $CRT/AnimationPlayer.play("tween_in")

func unpause(): $CRT/AnimationPlayer.play("tween_out")

func _on_continue_button_pressed() -> void:
	print("continuing")
	Global.resume_game()

func _on_quit_button_pressed() -> void:
	# BUG: doesnt work, bad address index
	# need to deinitialize all the bs in the game scene first before switching
	# scenes or godot will explode
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn") # we'll probably use a scene transition in the future
