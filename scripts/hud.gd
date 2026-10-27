extends Control

@onready var ver: Label = $Ver
@onready var fps: Label = $FPS

func _ready() -> void:
	ver.text = "Mhyworld c."+GitStatus.get_hash_string()

func _process(delta: float) -> void:
	fps.text = "%d FPS" % Engine.get_frames_per_second()
