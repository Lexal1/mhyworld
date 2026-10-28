class_name Biome extends Resource
## One terrain type. Any Biome .tres in BIOME_DIR is picked up automatically.

@export var id: StringName = &""

@export_group("Climate") # Where it appears. Both range -1..1.
@export_range(-1, 1) var temperature := 0.0
@export_range(-1, 1) var humidity := 0.0

@export_group("Shape") # Fractions of Global.world_height, so biomes scale with it.
@export_range(0.0, 1.0) var base_height := 0.35 ## Average ground level.
@export_range(0.0, 1.0) var amplitude := 0.15   ## How far the ground swings around that level.

@export_group("Blocks")
@export var surface_block: StringName = &"grass"
@export var filler_block: StringName = &"dirt"
@export var filler_depth := 4 ## Layers of filler under the surface, then stone.
