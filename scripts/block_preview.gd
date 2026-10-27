@tool
extends StaticBody3D

const vertices = [
	Vector3(0,0,0),
	Vector3(1,0,0),
	Vector3(0,1,0),
	Vector3(1,1,0),
	Vector3(0,0,1),
	Vector3(1,0,1),
	Vector3(0,1,1),
	Vector3(1,1,1)
]

const TOP =    [2,3,7,6]
const BOTTOM = [0,4,5,1]
const NORTH =  [7,5,4,6]
const SOUTH =  [2,0,1,3]
const EAST =   [3,1,5,7]
const WEST =   [6,4,0,2]

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
	if mesh_instance != null:
		mesh_instance.queue_free()
		mesh_instance = null
	for obj in block_tags.values():
		if obj.has_method("queue_free"):
			obj.queue_free()
	block_tags = {}

	if previewBlock == null or previewBlock.id == &"air":
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	# a lone block has no neighbours, so all 6 faces are always visible
	var atlas := previewBlock.atlas_position
	create_face(st, TOP, atlas.TOP)
	create_face(st, BOTTOM, atlas.BOTTOM)
	create_face(st, NORTH, atlas.NORTH)
	create_face(st, SOUTH, atlas.SOUTH)
	create_face(st, EAST, atlas.EAST)
	create_face(st, WEST, atlas.WEST)

	st.generate_normals(false)
	st.set_material(shaderMaterial)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	add_child(mesh_instance)
	mesh_instance.create_trimesh_collision()

	if previewBlock.has_method("on_block_created"):
		previewBlock.on_block_created(Vector3.ZERO, Vector2.ZERO, self)

func create_face(st: SurfaceTool, i: Array, atlas_offset: Vector2) -> void:
	var a = vertices[i[0]]
	var b = vertices[i[1]]
	var c = vertices[i[2]]
	var d = vertices[i[3]]

	var uv_offset = atlas_offset / Global.TEXTURE_ATLAS_SIZE
	var height = 1.0 / Global.TEXTURE_ATLAS_SIZE.y
	var width = 1.0 / Global.TEXTURE_ATLAS_SIZE.x

	var uv_a = uv_offset
	var uv_b = uv_offset + Vector2(0, height)
	var uv_c = uv_offset + Vector2(width, height)
	var uv_d = uv_offset + Vector2(width, 0)

	st.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c])
	st.add_triangle_fan([a, c, d], [uv_a, uv_c, uv_d])
