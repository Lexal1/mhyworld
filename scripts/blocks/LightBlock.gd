class_name LightBlock extends Block

func on_block_created(block_pos: Vector3, _chunk_pos: Vector2, node: StaticBody3D) -> void:
	var source = OmniLight3D.new()
	source.position = block_pos+Vector3(0.5,0.5,0.5)
	source.add_to_group(&"lightblock_lights")
	node.add_child(source)

func on_block_destroyed(block_pos: Vector3, _chunk_pos: Vector2, node: StaticBody3D) -> void:
	# this feels terrible but im not sure of another way to do it without making every LightBlock stateful
	var lights = node.get_tree().get_nodes_in_group(&"lightblock_lights")
	for light: Node3D in lights:
		var actual_position = light.position - Vector3(0.5, 0.5, 0.5)
		if actual_position.is_equal_approx(block_pos):
			light.queue_free()
			break # this function is called once per block so we can safely break here
