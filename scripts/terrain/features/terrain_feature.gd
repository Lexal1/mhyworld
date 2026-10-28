class_name TerrainFeature extends Resource
## One kind of natural feature. Any TerrainFeature .tres in FEATURE_DIR is picked up automatically.
## Shared by every worker thread: never store per-placement state on `self`.

enum Anchor { SURFACE, UNDERGROUND }

@export var id: StringName = &""

@export_group("Placement")
@export var biomes: Array[StringName] = [] ## Empty = every biome.
@export var cell_size := 8                  ## One attempt per cell. Must divide the world size.
@export_range(0.0, 1.0) var chance := 0.5   ## Chance that a cell gets one.
@export var anchor := Anchor.SURFACE
@export var min_depth := 3                  ## UNDERGROUND only: blocks below the surface.
@export var max_depth := 20

@export_group("Extent") ## Default reach, for features that don't override get_extent().
@export var radius := 3
@export var up := 8
@export var down := 0


## How far from the origin generate() can write: x = sideways, y = up, z = down.
## The placer uses this to skip chunks the feature can't touch, so it must not be too small.
func get_extent() -> Vector3i:
	return Vector3i(radius, up, down)


## Override this. Offsets are relative to the origin (for SURFACE, the first air block above the ground).
## Take ALL randomness from ctx.rng, and never skip a draw based on whether
## a block is inside the current chunk. That's what keeps neighbouring chunks in agreement.
func generate(_ctx: FeatureContext) -> void: pass
