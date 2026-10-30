class_name ItemComponent extends EntityComponent

const VISUAL_MATERIAL := preload("res://assets/resources/model_material.tres")
const BLOCK_TEXTURE := preload("res://assets/textures/mhycraftblocks.png")

@export var item_id: StringName = &"dirt"
@export var count := 1
@export var visual_scale := 0.35
@export var spin_speed := 1.5
@export var bob_height := 0.05
@export var bob_speed := 2.0

static var _cube_material: ShaderMaterial # shared by every dropped cube

var _visual: Node3D
var _spins := false
var _time := 0.0


func on_attach() -> void:
	var block: Block = BlockRegistry.get_by_id(item_id)
	if block == null:
		push_error("ItemComponent: unknown item '%s'" % item_id)
		return

	var sprite_comp := _find_sprite(block)
	if not block.render_cube and sprite_comp != null:
		_visual = sprite_comp.create_sprite(visual_scale) # billboards by itself, no spin
	else:
		_visual = _build_cube(block)
		_spins = true
	entity.add_child(_visual)


func _find_sprite(block: Block) -> SpriteComponent:
	if block is SceneBlock:
		for c in block.components:
			if c is SpriteComponent: return c
	return null


func _build_cube(block: Block) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var a := block.atlas_position
	var o := Vector3(-0.5, -0.5, -0.5) # centre the cube on the entity
	BlockMesh.add_face(st, BlockMesh.TOP,    o, a.TOP,    block.emission)
	BlockMesh.add_face(st, BlockMesh.BOTTOM, o, a.BOTTOM, block.emission)
	BlockMesh.add_face(st, BlockMesh.NORTH,  o, a.NORTH,  block.emission)
	BlockMesh.add_face(st, BlockMesh.SOUTH,  o, a.SOUTH,  block.emission)
	BlockMesh.add_face(st, BlockMesh.EAST,   o, a.EAST,   block.emission)
	BlockMesh.add_face(st, BlockMesh.WEST,   o, a.WEST,   block.emission)
	st.generate_normals(false)
	st.set_material(_get_cube_material())

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.scale = Vector3.ONE * visual_scale
	return mi


## model_material.tres has no texture, so give the cubes a copy that uses the block atlas.
static func _get_cube_material() -> ShaderMaterial:
	if _cube_material == null:
		_cube_material = VISUAL_MATERIAL.duplicate()
		_cube_material.set_shader_parameter("albedo_texture", BLOCK_TEXTURE)
	return _cube_material


func _process(delta: float) -> void:
	if _visual == null: return
	_time += delta
	if _spins: _visual.rotate_y(spin_speed * delta)
	_visual.position.y = sin(_time * bob_speed) * bob_height
