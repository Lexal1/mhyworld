@tool
class_name SpriteComponent extends BlockComponent

@export var texture: Texture2D
@export var region := Rect2(0, 0, 16, 16)
@export var pixel_size := 0.0625 ## 1/16, so a 16px tile is exactly one block wide.
## Leave empty to fall back to the plain Sprite3D look.
@export var shader: Shader = preload("res://scripts/shaders/sprites.gdshader")
@export var snap_resolution := 100.0 ## Keep equal to the chunk material's snap_resolution.

# One material shared by every sprite of this type, built on first use.
# on_block_created runs on worker threads, so creation is behind a mutex.
var _material: ShaderMaterial
var _material_mutex := Mutex.new()


func _get_material() -> ShaderMaterial:
	if shader == null: return null
	_material_mutex.lock()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter("albedo_texture", texture)
		_material.set_shader_parameter("snap_resolution", snap_resolution)
	_material_mutex.unlock()
	return _material


func on_block_created(block: Block, pos: Vector3, chunk: StaticBody3D) -> void:
	if block.has_tag(pos, chunk): return # meshing runs this on every remesh
	var s := Sprite3D.new()
	s.texture = texture
	s.region_enabled = true
	s.region_rect = region
	s.pixel_size = pixel_size
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = SpriteBase3D.FLAG_SHADED
	s.material_override = _get_material() # null = keep the default look
	s.position = pos + Vector3(0.5, 0.5, 0.5)
	block.set_tag(pos, chunk, s)
	chunk.add_child.call_deferred(s)

func on_block_destroyed(block: Block, pos: Vector3, chunk: StaticBody3D) -> void:
	if not block.has_tag(pos, chunk): return
	(block.get_tag(pos, chunk) as Node).queue_free()
	block.rm_tag(pos, chunk)
