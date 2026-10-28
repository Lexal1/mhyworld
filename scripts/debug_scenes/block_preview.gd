@tool
extends StaticBody3D
## Shows one block on its own, using the same mesh code and hooks as Chunk.

@export var shaderMaterial: ShaderMaterial:
	set(value):
		shaderMaterial = value
		if is_node_ready(): update()

## A Block .tres or a BlockDef .tscn, the same two things BlockRegistry accepts.
@export var previewBlock: Resource:
	set(value):
		if previewBlock != null and previewBlock.changed.is_connected(update):
			previewBlock.changed.disconnect(update)
		previewBlock = value
		if previewBlock != null:
			previewBlock.changed.connect(update)
		if is_node_ready(): update()

var block_tags: Dictionary[Vector3, Variant] = {} # components store their per-block nodes here
var mesh_instance: MeshInstance3D = null

var _block: Block = null   # the block the current mesh and tags were built from
var _def_root: Node = null # keeps a BlockDef scene's components alive (never in the tree)


func _ready() -> void:
	update()


func _exit_tree() -> void:
	_clear()


func update() -> void:
	_clear()

	var block := _resolve_block()
	if block == null or block.id == &"air":
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	# A lone block has no neighbours, so all 6 faces are visible.
	var atlas := block.atlas_position
	BlockMesh.add_face(st, BlockMesh.TOP,    Vector3.ZERO, atlas.TOP,    block.emission)
	BlockMesh.add_face(st, BlockMesh.BOTTOM, Vector3.ZERO, atlas.BOTTOM, block.emission)
	BlockMesh.add_face(st, BlockMesh.NORTH,  Vector3.ZERO, atlas.NORTH,  block.emission)
	BlockMesh.add_face(st, BlockMesh.SOUTH,  Vector3.ZERO, atlas.SOUTH,  block.emission)
	BlockMesh.add_face(st, BlockMesh.EAST,   Vector3.ZERO, atlas.EAST,   block.emission)
	BlockMesh.add_face(st, BlockMesh.WEST,   Vector3.ZERO, atlas.WEST,   block.emission)

	st.generate_normals(false)
	st.set_material(shaderMaterial)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	add_child(mesh_instance)
	mesh_instance.create_trimesh_collision()

	block.on_block_created(Vector3i.ZERO, Vector3i.ZERO, self)
	_block = block # only set once created, so _clear() only destroys what was created


## Same two cases BlockRegistry handles.
func _resolve_block() -> Block:
	if previewBlock is Block:
		return previewBlock
	if previewBlock is PackedScene:
		var root := (previewBlock as PackedScene).instantiate()
		if root is BlockDef:
			_def_root = root
			return root.build()
		printerr("%s root isn't a BlockDef" % previewBlock.resource_path)
		root.free()
	return null


func _clear() -> void:
	if _block != null:
		_block.on_block_destroyed(Vector3i.ZERO, Vector3i.ZERO, self)
		_block = null
	for obj in block_tags.values(): # anything a component didn't clean up itself
		if obj.has_method("queue_free"):
			obj.queue_free()
	block_tags = {}

	if mesh_instance != null:
		mesh_instance.queue_free()
		mesh_instance = null
	if _def_root != null:
		_def_root.free()
		_def_root = null
