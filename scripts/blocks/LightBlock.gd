class_name LightBlock extends Block

func on_block_created(block_pos: Vector3, chunk_pos: Vector2, node: StaticBody3D) -> void:
	var source = OmniLight3D.new()
	source.position = block_pos+Vector3(0.5,0.5,0.5)
	node.add_child(source)
