extends CanvasLayer

@onready var animation := $AnimationPlayer

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		animation.play("tween_in")
