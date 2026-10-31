class_name DialogueBox extends PanelContainer
## Text box at the bottom of the screen with a typewriter effect.
## `speaker` is whoever owns the current line, so two occupants can't fight over the box.

@export var chars_per_second := 40.0

var speaker: Node

var _label: Label
var _progress := 0.0
var _typing := false


func _ready() -> void:
	theme = preload("res://assets/resources/theme_default.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(0, 64) # ~3 lines, so the box doesn't jump while typing
	add_child(_label)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 32)
	grow_vertical = Control.GROW_DIRECTION_BEGIN # longer text grows the box upwards
	hide()


func show_line(who: Node, text: String) -> void:
	speaker = who
	_label.text = text
	_label.visible_characters = 0
	_progress = 0.0
	_typing = true
	show()


func is_typing() -> bool: return _typing


## Finishes the current line instantly.
func skip() -> void:
	_typing = false
	_label.visible_characters = -1


func close() -> void:
	_typing = false
	speaker = null
	hide()


func _process(delta: float) -> void:
	if not _typing: return
	_progress += chars_per_second * delta
	if _progress >= _label.text.length():
		skip()
	else:
		_label.visible_characters = int(_progress)
