# "feature_placer.gd is the engine. You write it once and never touch it again." YEEEAHHHHHH
class_name FeaturePlacer extends RefCounted
## Stamps every TerrainFeature into a chunk. Read-only after _init, so worker threads can share it.

const FEATURE_DIR := "res://assets/resources/features/"

var _terrain: TerrainGenerator
var _seed: int
var _features: Array[TerrainFeature] = []
var _allowed_biomes: Array[PackedByteArray] = [] # per feature, [biome idx] = 1. Empty = all.


func _init(terrain: TerrainGenerator, world_seed: int) -> void:
	_terrain = terrain
	_seed = world_seed
	for filename in DirAccess.get_files_at(FEATURE_DIR):
		var res := load(FEATURE_DIR + filename.replace(".remap", ""))
		if res is TerrainFeature: _features.push_back(res)
	# Same reason as biomes: directory order isn't guaranteed.
	_features.sort_custom(func(a: TerrainFeature, b: TerrainFeature): return a.id < b.id)

	for f in _features:
		if Global.world_size % f.cell_size != 0:
			printerr("Feature '%s': cell_size %d doesn't divide the world size" % [f.id, f.cell_size])
		_allowed_biomes.push_back(_resolve_biomes(f))


func _resolve_biomes(f: TerrainFeature) -> PackedByteArray:
	var allowed := PackedByteArray()
	if f.biomes.is_empty(): return allowed
	allowed.resize(_terrain.biomes.size())
	for i in _terrain.biomes.size():
		allowed[i] = 1 if f.biomes.has(_terrain.biomes[i].id) else 0
	return allowed


## Called by Chunk after the base terrain is filled in.
func apply(blocks: PackedInt32Array, chunk_origin: Vector3i) -> void:
	var ctx := FeatureContext.new(_terrain, blocks, chunk_origin)
	var rng := RandomNumberGenerator.new()
	var cs := Global.CHUNK_SIZE
	var n := Global.world_size

	for fi in _features.size():
		var f := _features[fi]
		var ext := f.get_extent()
		var cell := f.cell_size
		var cells := n / cell
		var salt := String(f.id).hash() # by name, so adding a feature doesn't reshuffle the others

		# Every cell whose feature could reach into this chunk.
		var cx0 := floori(float(chunk_origin.x - ext.x) / cell)
		var cx1 := floori(float(chunk_origin.x + cs.x - 1 + ext.x) / cell)
		var cz0 := floori(float(chunk_origin.z - ext.x) / cell)
		var cz1 := floori(float(chunk_origin.z + cs.z - 1 + ext.x) / cell)

		for cx in range(cx0, cx1 + 1):
			for cz in range(cz0, cz1 + 1):
				# Wrapped cell coords go into the seed, so both sides of the world seam agree.
				rng.seed = _mix(_seed, salt, posmod(cx, cells), posmod(cz, cells))
				var roll := rng.randf()
				var gx := cx * cell + rng.randi_range(0, cell - 1)
				var gz := cz * cell + rng.randi_range(0, cell - 1)
				if roll >= f.chance: continue
				if gx < chunk_origin.x - ext.x or gx >= chunk_origin.x + cs.x + ext.x: continue
				if gz < chunk_origin.z - ext.x or gz >= chunk_origin.z + cs.z + ext.x: continue

				var col := _terrain.sample_column(gx, gz)
				var allowed := _allowed_biomes[fi]
				if not allowed.is_empty() and allowed[col.y] == 0: continue

				var oy: int
				if f.anchor == TerrainFeature.Anchor.SURFACE:
					if _terrain.block_at(gx, col.x, gz, col) == _terrain.air_idx: continue # cave mouth
					oy = col.x + 1
				else:
					oy = col.x - rng.randi_range(f.min_depth, f.max_depth)

				if oy + ext.y < chunk_origin.y or oy - ext.z >= chunk_origin.y + cs.y: continue

				ctx.rng = rng
				ctx.origin = Vector3i(gx, oy, gz)
				ctx.biome = _terrain.biomes[col.y]
				f.generate(ctx)


## Integer hash, so results don't depend on engine hashing details.
static func _mix(a: int, b: int, c: int, d: int) -> int:
	var h := a
	for v in [b, c, d]:
		h = (h ^ v) * 0x9E3779B1
		h ^= h >> 15
	return h
