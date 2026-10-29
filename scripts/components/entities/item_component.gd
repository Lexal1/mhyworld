class_name ItemComponent extends EntityComponent

const VISUAL_MATERIAL := preload("res://assets/resources/model_material.tres")

@export var item_id: StringName = &"dirt"
@export var count := 1
@export var visual_scale := 0.35
@export var spin_speed := 1.5
@export var bob_height := 0.05
@export var bob_speed := 2.0

var _mesh: MeshInstance3D
var _time := 0.0


func on_attach() -> void:
	var block := BlockRegistry.get_by_id(item_id)
	if block == null:
		push_error("ItemComponent: unknown item '%s'" % item_id)
		return

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
	st.set_material(VISUAL_MATERIAL)

	_mesh = MeshInstance3D.new()
	_mesh.mesh = st.commit()
	_mesh.scale = Vector3.ONE * visual_scale
	entity.add_child(_mesh)


func _process(delta: float) -> void:
	if _mesh == null: return
	_time += delta
	_mesh.rotate_y(spin_speed * delta)
	_mesh.position.y = sin(_time * bob_speed) * bob_height
