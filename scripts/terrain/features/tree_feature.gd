# tree_feature.gd
class_name TreeFeature extends TerrainFeature

@export var trunk_block: StringName = &"log_wood"
@export var leaf_block: StringName = &"leaf_soft"
@export var min_height := 4
@export var max_height := 7
@export var crown_radius := 2

func get_extent() -> Vector3i:
	return Vector3i(crown_radius, max_height + 1, 0)

func generate(ctx: FeatureContext) -> void:
	var trunk := ctx.block(trunk_block)
	var leaves := ctx.block(leaf_block)
	var h := ctx.rng.randi_range(min_height, max_height)
	for y in h:
		ctx.place(Vector3i(0, y, 0), trunk)
	for dy in range(h - 2, h + 2):
		var r := crown_radius
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var corner := absi(dx) == r and absi(dz) == r
				if corner and ctx.rng.randf() < 0.5: continue
				ctx.place(Vector3i(dx, dy, dz), leaves)
