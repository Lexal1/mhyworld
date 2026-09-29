extends Node3D

@export var rotation_speed: float = 0.005
var is_dragging: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
	
	elif event is InputEventMouseMotion and is_dragging:
		rotate_y(-event.relative.x * rotation_speed)
		
		rotate_object_local(Vector3.RIGHT, -event.relative.y * rotation_speed)
