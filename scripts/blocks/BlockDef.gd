@tool
class_name BlockDef extends Node

@export var id: StringName = ""
@export var solid := true
@export var atlas_position: BlockAtlasPosition

func build() -> SceneBlock:
	var block := SceneBlock.new(id, solid) # keeps Block's default atlas
	if atlas_position != null:
		block.atlas_position = atlas_position
	for child in get_children():
		if child is BlockComponent:
			block.components.push_back(child)
	return block
