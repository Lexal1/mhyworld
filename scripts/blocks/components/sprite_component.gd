@tool
class_name SpriteComponent extends BlockComponent

@export var texture: Texture2D
@export var region := Rect2(0, 0, 16, 16)
@export var pixel_size := 0.0625 ## 1/16, so a 16px tile is exactly one block wide.

func on_block_created(block: Block, pos: Vector3, chunk: StaticBody3D) -> void:
	if block.has_tag(pos, chunk): return # meshing runs this on every remesh
	var s := Sprite3D.new()
	s.texture = texture
	s.region_enabled = true
	s.region_rect = region
	s.pixel_size = pixel_size
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # stays upright, turns to face you
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = SpriteBase3D.FLAG_SHADED
	s.position = pos + Vector3(0.5, 0.5, 0.5)
	block.set_tag(pos, chunk, s)
	chunk.add_child.call_deferred(s)

func on_block_destroyed(block: Block, pos: Vector3, chunk: StaticBody3D) -> void:
	if not block.has_tag(pos, chunk): return
	(block.get_tag(pos, chunk) as Node).queue_free()
	block.rm_tag(pos, chunk)
