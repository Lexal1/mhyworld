class_name InventoryUI extends Control
## Full-screen "file explorer" over the player's Inventory.

const GUI_TEX := preload("res://assets/textures/gui.png")
const BLOCK_TEX := preload("res://assets/textures/mhycraftblocks.png")
const ICON_PX := 16.0     ## Size of one icon in gui.png. Adjust if yours differ.
const ICON_ROW_Y := 144.0  ## Where the icon row starts (bottom half of the sheet).
const ICON_SCALE := 2.0
const COMP_TEX := preload("res://assets/textures/components.png")
const COMP_PX := 32.0
## Order matches the sheet. "aer" is unused for now, but it still has to be listed so the later icons line up.
const COMPONENT_ORDER: Array[StringName] = [&"ordo", &"terra", &"aer", &"herba", &"perditio", &"lux", &"metallum"]

enum Icon { FOLDER, TEXT, FILE }
enum Cmd { OPEN, SPLIT, RECYCLE, RENAME, DELETE, NEW_FOLDER, NEW_TEXT }

@export var player: Node

var _inv: Inventory
var _current: InvFile
var _ctx: InvFile # file the context menu was opened on (null = empty space)

var _path: Label
var _bar: ProgressBar
var _usage: Label
var _view: FolderView
var _menu: PopupMenu
var _prompt: ConfirmationDialog
var _prompt_line: LineEdit
var _prompt_cb := Callable()
var _editor: ConfirmationDialog
var _edit_text: TextEdit
var _edit_file: InvFile


func _ready() -> void:
	theme = preload("res://assets/resources/theme_default.tres")
	z_index = 100 # the HUD is z 99; without this the crosshair draws over the inventory
	_inv = player.inventory
	_current = _inv.root
	_inv.changed.connect(_refresh)
	Global.on_resume.connect(hide) # Esc also closes us, via the pause toggle
	_build()
	_refresh()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"): return
	if visible:
		Global.resume_game() # emits on_resume, which hides us
	elif not Global.is_paused():
		Global.open_menu()
		show()
		_refresh() # after show(), because _refresh skips work while hidden


#region Build

func _build() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	bg.add_child(box)

	var title := Label.new()
	title.text = "Drive (C:)"
	box.add_child(title)
	_path = Label.new()
	box.add_child(_path)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	box.add_child(_bar)
	_usage = Label.new()
	box.add_child(_usage)
	box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_view = FolderView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL # empty space must accept drops and clicks
	_view.dropped.connect(func(dragged: InvFile): _inv.move(dragged, _current))
	_view.context.connect(func(pos: Vector2): _show_menu(null, pos))
	scroll.add_child(_view)

	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)

	_prompt = ConfirmationDialog.new()
	_prompt_line = LineEdit.new()
	_prompt.add_child(_prompt_line)
	_prompt.register_text_enter(_prompt_line)
	_prompt.confirmed.connect(func(): _prompt_cb.call(_prompt_line.text))
	add_child(_prompt)

	_editor = ConfirmationDialog.new()
	_edit_text = TextEdit.new()
	_editor.add_child(_edit_text)
	_editor.confirmed.connect(func(): _inv.set_text(_edit_file, _edit_text.text))
	add_child(_editor)

#endregion


#region Refresh

func _refresh() -> void:
	if not is_visible_in_tree(): return
	_path.text = _current.path()
	_bar.max_value = _inv.capacity
	_bar.value = _inv.used()
	_usage.text = "%s / %s used" % [format_size(_inv.used()), format_size(_inv.capacity)]

	for c in _view.get_children():
		_view.remove_child(c) # out of the layout now, freed at end of frame
		c.queue_free()

	if _current.parent != null:
		_add_tile(_current.parent, "..")

	var sorted := _current.children.duplicate()
	sorted.sort_custom(func(a: InvFile, b: InvFile) -> bool:
		if a.is_folder() != b.is_folder(): return a.is_folder() # folders first
		return a.display_name() < b.display_name())
	for f in sorted:
		_add_tile(f, "")


func _add_tile(f: InvFile, label_override: String) -> void:
	var t := FileTile.new(f, label_override)
	t.opened.connect(_open)
	t.context.connect(_show_menu)
	t.dropped.connect(_on_dropped)
	_view.add_child(t)

#endregion


#region Actions

func _open(f: InvFile) -> void:
	if f.is_folder():
		_current = f
		_refresh()
	elif f.kind == InvFile.Kind.TEXT:
		_edit_file = f
		_editor.title = f.name
		_edit_text.text = f.text
		_editor.popup_centered(Vector2i(420, 320))


func _on_dropped(dragged: InvFile, onto: InvFile) -> void:
	if onto.is_folder():
		_inv.move(dragged, onto)
	elif onto.is_stack() and dragged.is_stack() and onto.kind == dragged.kind and onto.item_id == dragged.item_id:
		_inv.merge(dragged, onto)
	else:
		_inv.move(dragged, onto.parent) # dropped on a plain file: same folder as it


func _show_menu(f: InvFile, pos: Vector2) -> void:
	_ctx = f
	_menu.clear()
	if f != null:
		if f.is_folder() or f.kind == InvFile.Kind.TEXT:
			_menu.add_item("Open", Cmd.OPEN)
		if f.is_stack() and f.count > 1:
			_menu.add_item("Split stack...", Cmd.SPLIT)
		if f.kind == InvFile.Kind.ITEM:
			var b: Block = BlockRegistry.get_by_id(f.item_id)
			if b != null and not b.recycle.is_empty():
				_menu.add_item("Recycle stack", Cmd.RECYCLE)
		if not f.is_stack():
			_menu.add_item("Rename", Cmd.RENAME)
			if not f.contains_stacks():
				_menu.add_item("Delete", Cmd.DELETE)
	else:
		_menu.add_item("New folder", Cmd.NEW_FOLDER)
		_menu.add_item("New text file", Cmd.NEW_TEXT)
	if _menu.item_count > 0:
		_menu.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))


func _on_menu(id: int) -> void:
	var f := _ctx
	match id:
		Cmd.OPEN:
			_open(f)
		Cmd.RECYCLE:
			_inv.recycle(f)
		Cmd.SPLIT:
			_ask("Split off how many? (1-%d)" % (f.count - 1), "1",
				func(t: String): _inv.split(f, t.to_int()))
		Cmd.RENAME:
			_ask("Rename", f.name, func(t: String): _inv.rename(f, t))
		Cmd.NEW_FOLDER:
			_ask("New folder", "New folder", func(t: String): _inv.make_folder(_current, t))
		Cmd.NEW_TEXT:
			_ask("New text file", "note.txt", func(t: String): _inv.make_text(_current, t))
		Cmd.DELETE:
			_inv.delete(f)


func _ask(title: String, initial: String, cb: Callable) -> void:
	_prompt.title = title
	_prompt_line.text = initial
	_prompt_cb = cb
	_prompt.popup_centered(Vector2i(260, 100))
	_prompt_line.grab_focus()
	_prompt_line.select_all()

#endregion


#region Icons

## Folder/text/file sprite, with the block's top texture overlaid for items.
static func make_icon(f: InvFile) -> Control:
	var s := ICON_PX * ICON_SCALE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(s, s)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base := Icon.FILE
	if f.is_folder(): base = Icon.FOLDER
	elif f.kind == InvFile.Kind.TEXT: base = Icon.TEXT
	holder.add_child(_tex_rect(_gui_icon(base), Vector2.ZERO, Vector2(s, s)))

	if f.kind == InvFile.Kind.ITEM:
		var block_tex := _block_icon(f.item_id)
		if block_tex != null:
			holder.add_child(_tex_rect(block_tex, Vector2(s * 0.25, s * 0.35), Vector2(s, s) * 0.5))
	if f.kind == InvFile.Kind.COMPONENT:
		var comp_tex := _component_icon(f.item_id)
		if comp_tex != null:
			# 32px drawn at 32px, so the pixels stay crisp (no uneven scaling).
			holder.add_child(_tex_rect(comp_tex, Vector2((s - COMP_PX) * 0.5, s - COMP_PX - 2.0), Vector2(COMP_PX, COMP_PX)))
	return holder


static func _tex_rect(tex: Texture2D, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # before size, or the texture size wins
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = sz
	return r


static func _gui_icon(i: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = GUI_TEX
	t.region = Rect2(i * ICON_PX, ICON_ROW_Y, ICON_PX, ICON_PX)
	return t


static func _block_icon(id: StringName) -> AtlasTexture:
	var b: Block = BlockRegistry.get_by_id(id)
	if b == null: return null

	# Non-cube blocks draw themselves with a sprite, so use that image.
	if not b.render_cube and b is SceneBlock:
		for c in b.components:
			if c is SpriteComponent:
				var st := AtlasTexture.new()
				st.atlas = c.texture
				st.region = c.region # already in pixels, no tile maths needed
				return st

	if b.atlas_position == null: return null
	var tile := BLOCK_TEX.get_size() / Global.TEXTURE_ATLAS_SIZE
	var t := AtlasTexture.new()
	t.atlas = BLOCK_TEX
	t.region = Rect2(b.atlas_position.TOP * tile, tile)
	return t

static func _component_icon(id: StringName) -> AtlasTexture:
	var i := COMPONENT_ORDER.find(id)
	if i < 0: return null # unknown component: just shows the plain file sprite
	var t := AtlasTexture.new()
	t.atlas = COMP_TEX
	t.region = Rect2(i * COMP_PX, 0, COMP_PX, COMP_PX)
	return t

#endregion


#region Inner controls

## One file or folder in the view. Handles drag, drop, double-click and right-click.
class FileTile extends VBoxContainer:
	signal opened(file: InvFile)
	signal context(file: InvFile, global_pos: Vector2)
	signal dropped(dragged: InvFile, onto: InvFile)

	var file: InvFile
	var _is_up: bool # the ".." tile: a drop target and a way back, but not draggable

	func _init(f: InvFile, label_override := "") -> void:
		file = f
		if not _is_up: tooltip_text = InventoryUI.format_size(f.size_bytes())
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(80, 0)
		add_theme_constant_override("separation", 0)
		add_child(InventoryUI.make_icon(f))

		var l := Label.new()
		l.text = label_override if _is_up else f.display_name()
		if f.is_stack(): l.text += "\nx%d" % f.count
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size.x = 80
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		if not _is_up: tooltip_text = "%d KB" % f.size_bytes()

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed): return
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			opened.emit(file)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not _is_up:
			context.emit(file, event.global_position)

	func _get_drag_data(_at: Vector2) -> Variant:
		if _is_up: return null
		set_drag_preview(InventoryUI.make_icon(file))
		return {"inv_file": file}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("inv_file") and data["inv_file"] != file

	func _drop_data(_at: Vector2, data: Variant) -> void:
		dropped.emit(data["inv_file"], file)


## The background behind the tiles: drop here to move into the open folder, right-click for "New".
class FolderView extends HFlowContainer:
	signal dropped(dragged: InvFile)
	signal context(global_pos: Vector2)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			context.emit(event.global_position)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("inv_file")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		dropped.emit(data["inv_file"])

#endregion

## Formats a size in bytes as B, KB, MB or GB (1024 steps).
static func format_size(bytes: int) -> String:
	if bytes >= Inventory.GB: return "%s GB" % _trim(bytes / float(Inventory.GB))
	if bytes >= Inventory.MB: return "%s MB" % _trim(bytes / float(Inventory.MB))
	if bytes >= Inventory.KB: return "%s KB" % _trim(bytes / float(Inventory.KB))
	return "%d B" % bytes


## One decimal place, but no trailing ".0" ("2 MB", not "2.0 MB").
static func _trim(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")
