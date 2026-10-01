class_name LightBlock extends Block

func on_block_created(block_pos: Vector3, _chunk_pos: Vector2, node: StaticBody3D) -> void:
	if has_tag(block_pos, node): return
	var source = OmniLight3D.new()
	source.position = block_pos+Vector3(0.5,0.5,0.5)
	#source.add_to_group(&"lightblock_lights")
	set_tag(block_pos, node, source)
	node.add_child(source)

func on_block_destroyed(block_pos: Vector3, _chunk_pos: Vector2, node: StaticBody3D) -> void:
	var light_node: OmniLight3D = get_tag(block_pos, node)
	if light_node == null:
		printerr("[LightBlock] tag is SOMEHOW missing")
	light_node.queue_free()
	rm_tag(block_pos, node)
