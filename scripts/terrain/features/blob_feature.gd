# blob_feature.gd  (resource deposits: set anchor = UNDERGROUND)
class_name BlobFeature extends TerrainFeature

@export var deposit_block: StringName
@export var replaces: StringName = &"stone"
@export var blob_radius := 2.5

func get_extent() -> Vector3i:
	var r := ceili(blob_radius)
	return Vector3i(r, r, r)

func generate(ctx: FeatureContext) -> void:
	var ore := ctx.block(deposit_block)
	var host := ctx.block(replaces)
	var r := ceili(blob_radius)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var d := Vector3(dx, dy, dz).length() + ctx.rng.randf() * 0.8 # ragged edge
				if d <= blob_radius:
					ctx.replace(Vector3i(dx, dy, dz), ore, host)
