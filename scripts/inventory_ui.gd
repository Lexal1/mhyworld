class_name InventoryUI extends Control

@export var player: Node

var _inv: Inventory
var _bar: ProgressBar
var _usage: Label
var _list: VBoxContainer


func _ready() -> void:
	theme = preload("res://assets/resources/theme_default.tres")
	_inv = player.inventory
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
		_refresh()
		Global.open_menu()
		show()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(360, 280)
	center.add_child(window)

	var box := VBoxContainer.new()
	window.add_child(box)

	var title := Label.new()
	title.text = "Drive (C:)"
	box.add_child(title)
	box.add_child(HSeparator.new())

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	box.add_child(_bar)

	_usage = Label.new()
	box.add_child(_usage)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _refresh() -> void:
	_bar.max_value = _inv.capacity
	_bar.value = _inv.used()
	_usage.text = "%d / %d KB used" % [_inv.used(), _inv.capacity]

	for c in _list.get_children():
		_list.remove_child(c) # out of the layout now, freed at end of frame
		c.queue_free()

	for id in _inv.items:
		var count: int = _inv.items[id]
		var row := _add_row("%s  x%d  (%d KB)" % [id, count, count * _inv.item_size(id)])
		var block: Block = BlockRegistry.get_by_id(id)
		if block != null and not block.recycle.is_empty():
			var btn := Button.new()
			btn.text = "Recycle"
			btn.pressed.connect(func(): _inv.recycle(id))
			row.add_child(btn)

	if not _inv.components.is_empty():
		_list.add_child(HSeparator.new())
		for id in _inv.components:
			var count: int = _inv.components[id]
			_add_row("%s  x%d  (%d KB)" % [id, count, count * Inventory.COMPONENT_SIZE])


func _add_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_list.add_child(row)
	return row
