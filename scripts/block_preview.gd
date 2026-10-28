@tool
extends StaticBody3D

@export var shaderMaterial: ShaderMaterial:
	set(value):
		shaderMaterial = value
		if is_node_ready(): update()

@export var previewBlock: Block:
	set(value):
		if previewBlock != null and previewBlock.changed.is_connected(update):
			previewBlock.changed.disconnect(update)
		previewBlock = value
		if previewBlock != null:
			previewBlock.changed.connect(update)
		if is_node_ready(): update()

var block_tags: Dictionary[Vector3, Variant] = {} # LightBlock stores its light here
var mesh_instance: MeshInstance3D = null


func _ready() -> void:
	update()


func update() -> void:
	_clear()
	if previewBlock == null or previewBlock.id == &"air":
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	# A lone block has no neighbours, so all 6 faces are visible.
	var atlas := previewBlock.atlas_position
	BlockMesh.add_face(st, BlockMesh.TOP,    Vector3.ZERO, atlas.TOP)
	BlockMesh.add_face(st, BlockMesh.BOTTOM, Vector3.ZERO, atlas.BOTTOM)
	BlockMesh.add_face(st, BlockMesh.NORTH,  Vector3.ZERO, atlas.NORTH)
	BlockMesh.add_face(st, BlockMesh.SOUTH,  Vector3.ZERO, atlas.SOUTH)
	BlockMesh.add_face(st, BlockMesh.EAST,   Vector3.ZERO, atlas.EAST)
	BlockMesh.add_face(st, BlockMesh.WEST,   Vector3.ZERO, atlas.WEST)

	st.generate_normals(false)
	st.set_material(shaderMaterial)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	add_child(mesh_instance)
	mesh_instance.create_trimesh_collision()

	if previewBlock.has_method("on_block_created"):
		previewBlock.on_block_created(Vector3.ZERO, Vector3i.ZERO, self)


func _clear() -> void:
	if mesh_instance != null:
		mesh_instance.queue_free()
		mesh_instance = null
	for obj in block_tags.values():
		if obj.has_method("queue_free"):
			obj.queue_free()
	block_tags = {}
