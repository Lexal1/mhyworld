extends Node3D

@export var rotation_speed: float = 0.005
var is_dragging: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# Check when the left mouse button is pressed or released
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
	
	# Check if the mouse is moving while dragging
	elif event is InputEventMouseMotion and is_dragging:
		# Rotate around the Y axis (left/right mouse movement)
		rotate_y(-event.relative.x * rotation_speed)
		
		# Rotate around the X axis (up/down mouse movement)
		# We use rotate_object_local to keep it relative to the object's view
		rotate_object_local(Vector3.RIGHT, -event.relative.y * rotation_speed)
