@tool
class_name LightComponent extends BlockComponent

@export var energy := 1.0
@export var light_range := 8.0

func on_block_created(block: Block, pos: Vector3, chunk: StaticBody3D) -> void:
	if block.has_tag(pos, chunk): return # meshing runs this on every remesh
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0.5, 0.5, 0.5)
	light.light_energy = energy
	light.omni_range = light_range
	block.set_tag(pos, chunk, light)
	chunk.add_child.call_deferred(light)

func on_block_destroyed(block: Block, pos: Vector3, chunk: StaticBody3D) -> void:
	if not block.has_tag(pos, chunk): return
	var light: OmniLight3D = block.get_tag(pos, chunk)
	light.queue_free()
	block.rm_tag(pos, chunk)
