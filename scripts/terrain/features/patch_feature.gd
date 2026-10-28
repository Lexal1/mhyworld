# patch_feature.gd  (flower patches: follows the ground height per column)
class_name PatchFeature extends TerrainFeature

@export var block: StringName = &"flower_red"
@export var patch_radius := 3
@export_range(0.0, 1.0) var density := 0.5

func get_extent() -> Vector3i: # ground rarely climbs more than 1 block per block
	return Vector3i(patch_radius, patch_radius, patch_radius)

func generate(ctx: FeatureContext) -> void:
	var b := ctx.block(block)
	for dx in range(-patch_radius, patch_radius + 1):
		for dz in range(-patch_radius, patch_radius + 1):
			if Vector2(dx, dz).length() <= patch_radius and ctx.rng.randf() < density:
				ctx.place_on_surface(dx, dz, b)
