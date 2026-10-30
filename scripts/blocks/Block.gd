class_name Block extends Resource

@export var id: StringName = ""
@export var solid: bool = true
@export var atlas_position: BlockAtlasPosition
@export var hardness: float = 1.0
@export var render_cube := true ## false = no cube mesh (the block draws itself, e.g. via a component).
@export_range(0.0, 1.0) var emission := 0.0 ## 0 = normal, 1 = full brightness regardless of light.
@export var size := 4 ## Inventory space, in KB.
@export var recycle: Dictionary[StringName, int] = {} ## component id -> amount. Empty = can't be recycled.

func _init(p_id: StringName = "", p_solid: bool = true, p_atlas_position: BlockAtlasPosition = null) -> void:
	id = p_id
	solid = p_solid
	atlas_position = p_atlas_position if p_atlas_position != null else _default_atlas()


static func _default_atlas() -> BlockAtlasPosition:
	return BlockAtlasPosition.new(
		Vector2(0, 0), Vector2(0, 0),
		Vector2(0, 0), Vector2(0, 0),
		Vector2(0, 0), Vector2(0, 0))


#region Hooks
## Plain blocks do nothing. SceneBlock overrides these, so callers never need has_method().

func on_block_created(_pos: Vector3i, _chunk_pos: Vector3i, _chunk: StaticBody3D) -> void: pass

func on_block_destroyed(_pos: Vector3i, _chunk_pos: Vector3i, _chunk: StaticBody3D) -> void: pass

#endregion


#region Tags
## Per-block data (e.g. a light node) lives in the chunk, never on the shared Block.

func set_tag(pos: Vector3, chunk: StaticBody3D, tag: Variant) -> void:
	chunk.block_tags[pos] = tag

func get_tag(pos: Vector3, chunk: StaticBody3D) -> Variant:
	return chunk.block_tags.get(pos) # null if missing, instead of an error

func has_tag(pos: Vector3, chunk: StaticBody3D) -> bool:
	return chunk.block_tags.has(pos)

func rm_tag(pos: Vector3, chunk: StaticBody3D) -> void:
	chunk.block_tags.erase(pos)

#endregion
