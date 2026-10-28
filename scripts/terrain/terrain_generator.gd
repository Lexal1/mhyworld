class_name TerrainGenerator extends RefCounted
## Pure functions of world position. Read-only after _init, so worker threads can share it.

const BIOME_DIR := "res://assets/resources/biomes/"
const SEAM := 128
const CLIMATE_GAIN := 1.6      ## Raw noise rarely nears +-1; this spreads biomes out.
const BLEND_SHARPNESS := 12.0   ## Higher = sharper biome borders.
const CAVE_THRESHOLD := 0.4    ## Lower = more caves.
const CAVE_SURFACE_BONUS := 0.35  ## Extra threshold at the surface. Higher = fewer surface caves.
const CAVE_SURFACE_FADE := 12.0   ## Blocks of depth over which the bonus fades to 0.

static var _cache := {} # seed -> TerrainGenerator

static func for_seed(world_seed: int) -> TerrainGenerator:
	if not _cache.has(world_seed):
		_cache[world_seed] = TerrainGenerator.new(world_seed)
	return _cache[world_seed]

var shape := FastNoiseLite.new()
var temperature := FastNoiseLite.new()
var humidity := FastNoiseLite.new()
var caves := FastNoiseLite.new()

var biomes: Array[Biome] = []
var air_idx := 0
var stone_idx := 0
var _surface_idx := PackedInt32Array()
var _filler_idx := PackedInt32Array()


func _init(world_seed: int) -> void:
	shape.seed = world_seed
	temperature.seed = world_seed + 1
	temperature.frequency = 0.002
	temperature.fractal_octaves = 2
	humidity.seed = world_seed + 2
	humidity.frequency = 0.002
	humidity.fractal_octaves = 2
	caves.seed = world_seed + 3
	caves.frequency = 0.04
	caves.fractal_octaves = 2

	air_idx = BlockRegistry.get_idx_of(&"air")
	stone_idx = BlockRegistry.get_idx_of(&"stone")
	_load_biomes()


func _load_biomes() -> void:
	for filename in DirAccess.get_files_at(BIOME_DIR):
		var res := load(BIOME_DIR + filename.replace(".remap", ""))
		if res is Biome:
			biomes.push_back(res)
	if biomes.is_empty():
		printerr("No biomes found in %s, using a default" % BIOME_DIR)
		biomes.push_back(Biome.new())
	# Directory order isn't guaranteed; sorting keeps a seed identical on every machine.
	biomes.sort_custom(func(a: Biome, b: Biome): return a.id < b.id)

	for b in biomes:
		_surface_idx.push_back(_resolve(b.surface_block, b.id))
		_filler_idx.push_back(_resolve(b.filler_block, b.id))


func _resolve(block_id: StringName, biome_id: StringName) -> int:
	var idx := BlockRegistry.get_idx_of(block_id)
	if idx < 0:
		printerr("Biome '%s' uses unknown block '%s'" % [biome_id, block_id])
		return stone_idx
	return idx


#region Wrapping
# Blends the noise with copies shifted by one world width, near the far edges,
# so the value at x=0 matches x=world_size. Same idea as your old code.

func _wrap2(noise: FastNoiseLite, gx: int, gz: int) -> float:
	var n := Global.world_size
	var x := posmod(gx, n)
	var z := posmod(gz, n)
	var tx := smoothstep(n - SEAM, n, x)
	var tz := smoothstep(n - SEAM, n, z)
	var a := noise.get_noise_2d(x, z)
	if tx == 0.0 and tz == 0.0: return a
	var b := noise.get_noise_2d(x - n, z)
	var c := noise.get_noise_2d(x, z - n)
	var d := noise.get_noise_2d(x - n, z - n)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _wrap3(noise: FastNoiseLite, gx: int, gy: int, gz: int) -> float:
	var n := Global.world_size
	var x := posmod(gx, n)
	var z := posmod(gz, n)
	var tx := smoothstep(n - SEAM, n, x)
	var tz := smoothstep(n - SEAM, n, z)
	var a := noise.get_noise_3d(x, gy, z)
	if tx == 0.0 and tz == 0.0: return a
	var b := noise.get_noise_3d(x - n, gy, z)
	var c := noise.get_noise_3d(x, gy, z - n)
	var d := noise.get_noise_3d(x - n, gy, z - n)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

#endregion


## Returns Vector2i(ground height, dominant biome index) for a world column.
func sample_column(gx: int, gz: int) -> Vector2i:
	var t := clampf(_wrap2(temperature, gx, gz) * CLIMATE_GAIN, -1.0, 1.0)
	var hum := clampf(_wrap2(humidity, gx, gz) * CLIMATE_GAIN, -1.0, 1.0)

	# Every biome gets a weight based on how close the climate is to its own.
	# Blending base/amplitude (not picking one biome) makes the borders slope smoothly.
	var base := 0.0
	var amp := 0.0
	var total := 0.0
	var best := 0
	var best_w := -1.0
	for i in biomes.size():
		var b := biomes[i]
		var d2 := Vector2(t - b.temperature, hum - b.humidity).length_squared()
		var w := exp(-d2 * BLEND_SHARPNESS)
		base += b.base_height * w
		amp += b.amplitude * w
		total += w
		if w > best_w:
			best_w = w
			best = i

	var h := float(Global.world_height)
	var height := int((base / total + _wrap2(shape, gx, gz) * (amp / total)) * h)
	return Vector2i(clampi(height, 1, Global.world_height - 1), best)


## `column` is the result of sample_column(gx, gz), passed in so a whole column only samples it once.
func block_at(gx: int, gy: int, gz: int, column: Vector2i) -> int:
	var height := column.x
	if gy > height: return air_idx
	var depth := height - gy
	var threshold := CAVE_THRESHOLD + CAVE_SURFACE_BONUS * (1.0 - smoothstep(0.0, CAVE_SURFACE_FADE, depth))
	if _wrap3(caves, gx, gy, gz) > threshold: return air_idx
	if gy == height: return _surface_idx[column.y]
	if gy >= height - biomes[column.y].filler_depth: return _filler_idx[column.y]
	return stone_idx


func is_solid(gx: int, gy: int, gz: int) -> bool:
	return block_at(gx, gy, gz, sample_column(gx, gz)) != air_idx
