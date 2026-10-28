class_name SceneBlock extends Block

var components: Array[BlockComponent] = []

func on_block_created(pos: Vector3i, _chunk_pos: Vector3i, chunk: StaticBody3D) -> void:
	for c in components:
		c.on_block_created(self, Vector3(pos), chunk)

func on_block_destroyed(pos: Vector3i, _chunk_pos: Vector3i, chunk: StaticBody3D) -> void:
	for c in components:
		c.on_block_destroyed(self, Vector3(pos), chunk)
