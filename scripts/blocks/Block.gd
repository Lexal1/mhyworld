class_name Block extends Resource

@export var id: StringName = ""
@export var solid: bool = true
@export var atlas_position: BlockAtlasPosition = BlockAtlasPosition.new(
	Vector2(0, 0), Vector2(2, 0),
	Vector2(1, 0), Vector2(1, 0),
	Vector2(1, 0), Vector2(1, 0),
	)

func _init(p_id: StringName = "", p_solid: bool = true, p_atlas_position: BlockAtlasPosition = BlockAtlasPosition.new(
	Vector2(0, 0), Vector2(2, 0),
	Vector2(1, 0), Vector2(1, 0),
	Vector2(1, 0), Vector2(1, 0),
	)):
	id = p_id
	solid = p_solid
	atlas_position = p_atlas_position
