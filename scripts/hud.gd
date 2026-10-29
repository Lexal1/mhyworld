class_name HUD extends Control

@onready var ver: Label = $Ver
@onready var fps: Label = $FPS
@onready var crosshair: Crosshair = $MarginContainer/Control/Crosshair

func _ready() -> void:
	if OS.is_debug_build():
		ver.text = "Mhyworld c." + GitStatus.get_hash_string()
	else:
		ver.text = "Mhyworld a" + ProjectSettings.get_setting("application/config/version")


func _process(_delta: float) -> void:
	fps.text = "%d FPS" % Engine.get_frames_per_second()
