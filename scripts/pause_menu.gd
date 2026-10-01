extends Control

@onready var label: Label = $Label
@export var player: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var global = get_node("/root/Global")
	global.on_pause.connect(pause)
	global.on_resume.connect(unpause)

func _process(delta: float) -> void:
	label.text = \
	"\n"+str(Time.get_unix_time_from_system())+ \
	"\ns:"+str(Global.world_seed)+ \
	"\nxyz:"+str(Vector3i(player.position))

func pause(): $CRT/AnimationPlayer.play("tween_in")

func unpause(): $CRT/AnimationPlayer.play("tween_out")
