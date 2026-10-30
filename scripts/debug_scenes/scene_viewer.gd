extends Node
## Debug viewer for chunks, blocks and entity models. Run this scene on its own (F6).
##
## Whatever is shown lives under Pivot/Holder. Holder is shifted so the subject's centre sits
## on Pivot, so the slider spins it in place and the camera always looks at the origin.

enum Mode { CHUNK, BLOCK, ENTITY }

const ENTITY_DIR := "res://scenes/entities/"
const VIEW_DIRECTION := Vector3(0.45, 0.5, 0.75) ## Which side the camera sits on.
const FIT_MARGIN := 1.2

@onready var pivot: Node3D = $Pivot
@onready var holder: Node3D = $Pivot/Holder
@onready var chunk_root: Node3D = $Pivot/Holder/ChunkRoot
@onready var chunk: Chunk = $Pivot/Holder/ChunkRoot/Chunk
@onready var camera: Camera3D = $Camera
@onready var ui: Control = $UI

var _mode: int = Mode.CHUNK
var _subject: Node3D = null ## Block host or entity model on screen (the chunk is permanent).
var _block: Block = null    ## Block on screen, so its destroy hook can run.
var _anim_player: AnimationPlayer = null

var _mode_pick: OptionButton
var _chunk_row: Control
var _x: SpinBox
var _y: SpinBox
var _z: SpinBox
var _block_pick: OptionButton
var _entity_pick: OptionButton
var _anim_pick: OptionButton
var _status: Label


## Stands in for a Chunk when showing one block: components keep their per-block
## nodes in block_tags and add them as children.
class BlockHost extends StaticBody3D:
	var block_tags: Dictionary[Vector3, Variant] = {}


func _ready() -> void:
	_build_ui()
	_set_mode(Mode.CHUNK)


func _exit_tree() -> void:
	_clear_subject()


#region UI

@warning_ignore("integer_division")
func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	_mode_pick = OptionButton.new()
	_mode_pick.add_item("Chunk", Mode.CHUNK)
	_mode_pick.add_item("Block", Mode.BLOCK)
	_mode_pick.add_item("Entity", Mode.ENTITY)
	_mode_pick.item_selected.connect(func(i: int): _set_mode(_mode_pick.get_item_id(i)))
	box.add_child(_mode_pick)

	# Chunk controls
	_chunk_row = VBoxContainer.new()
	box.add_child(_chunk_row)
	var coords := HBoxContainer.new()
	_chunk_row.add_child(coords)
	var max_xz := Global.world_size / Global.CHUNK_SIZE.x - 1
	_x = _make_spin("x ", max_xz)
	_y = _make_spin("y ", Global.world_height / Global.CHUNK_SIZE.y - 1)
	_z = _make_spin("z ", max_xz)
	for s in [_x, _y, _z]: coords.add_child(s)
	# Start on the chunk that holds the surface at (0, 0).
	var surface := TerrainGenerator.for_seed(Global.world_seed).sample_column(0, 0).x
	_y.set_value_no_signal(floori(float(surface) / Global.CHUNK_SIZE.y))
	var buttons := HBoxContainer.new()
	_chunk_row.add_child(buttons)
	buttons.add_child(_make_button("Generate", _rebuild_chunk))
	buttons.add_child(_make_button("Remesh", func(): chunk.update()))

	# Block picker. solid_table has one entry per registered block.
	_block_pick = OptionButton.new()
	for i in BlockRegistry.solid_table.size():
		var b := BlockRegistry.get_by_idx(i)
		if b.id != &"air": _block_pick.add_item(String(b.id), i)
	_block_pick.item_selected.connect(_show_block_at)
	box.add_child(_block_pick)

	# Entity picker
	_entity_pick = OptionButton.new()
	var files: Array[String] = []
	for f in DirAccess.get_files_at(ENTITY_DIR):
		var file := f.replace(".remap", "") # exported builds list remapped files
		if file.ends_with(".tscn"): files.push_back(file)
	files.sort()
	for file in files:
		_entity_pick.add_item(file.get_basename())
		_entity_pick.set_item_metadata(_entity_pick.item_count - 1, ENTITY_DIR + file)
	_entity_pick.item_selected.connect(_show_entity_at)
	box.add_child(_entity_pick)

	_anim_pick = OptionButton.new()
	_anim_pick.item_selected.connect(_play_animation)
	box.add_child(_anim_pick)

	var spin := HSlider.new()
	spin.max_value = 360.0
	spin.custom_minimum_size.x = 200
	spin.value_changed.connect(func(v: float): pivot.rotation_degrees = Vector3(0.0, v, 0.0))
	box.add_child(spin)

	_status = Label.new()
	_status.hide()
	box.add_child(_status)


func _make_spin(prefix: String, max_value: int) -> SpinBox:
	var s := SpinBox.new()
	s.prefix = prefix
	s.max_value = max_value
	s.rounded = true
	s.value_changed.connect(func(_v: float): _rebuild_chunk())
	return s


func _make_button(label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(on_press)
	return b


func _say(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()

#endregion


#region Modes

func _set_mode(mode: int) -> void:
	_mode = mode
	_clear_subject()
	chunk_root.visible = mode == Mode.CHUNK
	_chunk_row.visible = mode == Mode.CHUNK
	_block_pick.visible = mode == Mode.BLOCK
	_entity_pick.visible = mode == Mode.ENTITY
	_anim_pick.hide()
	_say("")
	match mode:
		Mode.CHUNK: _rebuild_chunk()
		Mode.BLOCK: _show_block_at(_block_pick.selected)
		Mode.ENTITY: _show_entity_at(_entity_pick.selected)


func _clear_subject() -> void:
	if _subject == null: return
	if _block != null:
		_block.on_block_destroyed(Vector3i.ZERO, Vector3i.ZERO, _subject as StaticBody3D)
		_block = null
	holder.remove_child(_subject)
	_subject.queue_free()
	_subject = null
	_anim_player = null


## Moves Holder so `bounds` (in Holder space) is centred on Pivot, and backs the camera off to fit it.
func _fit(bounds: AABB) -> void:
	holder.position = -bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.1)
	var dist := radius * FIT_MARGIN / sin(deg_to_rad(camera.fov * 0.5))
	camera.look_at_from_position(VIEW_DIRECTION.normalized() * dist, Vector3.ZERO)

#endregion


#region Chunk

## Generates and meshes the chunk at the spin box coordinates, on this thread.
func _rebuild_chunk() -> void:
	if _mode != Mode.CHUNK: return
	chunk.chunk_position = Vector3i(int(_x.value), int(_y.value), int(_z.value))
	chunk._generate_and_update() # also drops the old block_tags, unlike _generate() alone
	_fit(AABB(chunk.position, Vector3(Global.CHUNK_SIZE)))

#endregion


#region Block

func _show_block_at(item: int) -> void:
	_clear_subject()
	if item < 0: return
	var block := BlockRegistry.get_by_idx(_block_pick.get_item_id(item))

	var host := BlockHost.new()
	if block.render_cube: # flowers etc. draw themselves through their components
		host.add_child(_cube_mesh(block))
	holder.add_child(host)
	_subject = host

	block.on_block_created(Vector3i.ZERO, Vector3i.ZERO, host)
	_block = block # only set once created, so _clear_subject() only destroys what was created
	_fit(AABB(Vector3.ZERO, Vector3.ONE))


func _cube_mesh(block: Block) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# A lone block has no neighbours, so all 6 faces are visible.
	var a := block.atlas_position
	var e := block.emission
	BlockMesh.add_face(st, BlockMesh.TOP,    Vector3.ZERO, a.TOP,    e)
	BlockMesh.add_face(st, BlockMesh.BOTTOM, Vector3.ZERO, a.BOTTOM, e)
	BlockMesh.add_face(st, BlockMesh.NORTH,  Vector3.ZERO, a.NORTH,  e)
	BlockMesh.add_face(st, BlockMesh.SOUTH,  Vector3.ZERO, a.SOUTH,  e)
	BlockMesh.add_face(st, BlockMesh.EAST,   Vector3.ZERO, a.EAST,   e)
	BlockMesh.add_face(st, BlockMesh.WEST,   Vector3.ZERO, a.WEST,   e)
	st.generate_normals(false)
	st.set_material(chunk.shaderMaterial) # the same material blocks get in the world

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi

#endregion


#region Entity

## Shows only the entity's model. Putting the whole entity in the tree would run its
## physics and brain (it would wander off or fall), and the player needs scene nodes that aren't here.
func _show_entity_at(item: int) -> void:
	_clear_subject()
	_anim_pick.hide()
	_anim_pick.clear()
	_say("")
	if item < 0:
		_say("No entity scenes in %s" % ENTITY_DIR)
		return

	var path: String = _entity_pick.get_item_metadata(item)
	var root := (load(path) as PackedScene).instantiate()
	var model: Node3D = (root as Entity).model if root is Entity else null
	if model == null:
		_say("%s has no model" % path.get_file())
		root.free()
		return

	model.get_parent().remove_child(model)
	model.owner = null
	root.free() # the entity was never in the tree, so this is safe
	holder.add_child(model)
	_subject = model

	_fit(_visual_bounds(model))
	_setup_animations(model)


## Box around every mesh/sprite under `node`, in Holder space.
func _visual_bounds(node: Node3D) -> AABB:
	var to_holder := holder.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var box := to_holder * gi.global_transform * gi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first: return AABB(Vector3.ONE * -0.5, Vector3.ONE)
	return bounds


func _setup_animations(model: Node) -> void:
	_anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null: return
	for anim in _anim_player.get_animation_list():
		if anim != &"RESET": _anim_pick.add_item(anim)
	if _anim_pick.item_count == 0: return
	_anim_pick.show()
	var start := 0
	for i in _anim_pick.item_count:
		if _anim_pick.get_item_text(i) == "idle": start = i
	_anim_pick.select(start)
	_play_animation(start)


func _play_animation(item: int) -> void:
	if _anim_player == null: return
	var anim := StringName(_anim_pick.get_item_text(item))
	_anim_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR # so one-shots can be watched
	_anim_player.play(anim)

#endregion
