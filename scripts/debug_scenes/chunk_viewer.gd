extends Node

@onready var chunk_pivot: Node3D = $ChunkPivot
@onready var chunk: Chunk = $ChunkPivot/Chunk

func _on_rotation_slider_value_changed(value: float) -> void:
	chunk_pivot.rotation_degrees = Vector3(0, value, 0)
	
func _on_x_pos_input_value_changed(value: float) -> void:
	chunk.chunk_position.x = int(value)

func _on_y_pos_input_value_changed(value: float) -> void:
	chunk.chunk_position.y = int(value)

func _on_generate_button_pressed() -> void:
	chunk._generate()

func _on_update_button_pressed() -> void:
	chunk.update()
