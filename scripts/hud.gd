extends Control

@onready var ver: Label = $Ver

func _ready() -> void:
	ver.text = "Mhyworld c."+GitStatus.get_hash_string()
