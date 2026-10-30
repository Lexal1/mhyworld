@tool
class_name BlockDef extends Node

@export var id: StringName = ""
@export var solid := true
@export var atlas_position: BlockAtlasPosition
@export var hardness := 1.0
@export_range(0.0, 1.0) var emission := 0.0
@export var render_cube := true ## false = no cube mesh (the block draws itself, e.g. via a component).
@export var size := 4 ## Inventory space, in KB.
@export var recycle: Dictionary[StringName, int] = {} ## component id -> amount. Empty = can't be recycled.

func build() -> SceneBlock:
	var block := SceneBlock.new(id, solid)
	block.hardness = hardness
	block.emission = emission
	block.render_cube = render_cube
	block.size = size
	block.recycle = recycle
	if atlas_position != null:
		block.atlas_position = atlas_position
	for child in get_children():
		if child is BlockComponent:
			block.components.push_back(child)
	return block
