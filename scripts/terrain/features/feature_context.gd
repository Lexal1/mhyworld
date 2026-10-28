class_name FeatureContext extends RefCounted
## Handed to TerrainFeature.generate(). Writes outside the chunk being built are ignored.

var rng: RandomNumberGenerator
var origin := Vector3i.ZERO ## World position of this feature.
var biome: Biome
var terrain: TerrainGenerator

var _blocks: PackedInt32Array # shared with the chunk (packed arrays are passed by reference)
var _chunk_origin: Vector3i


func _init(p_terrain: TerrainGenerator, p_blocks: PackedInt32Array, p_chunk_origin: Vector3i) -> void:
	terrain = p_terrain
	_blocks = p_blocks
	_chunk_origin = p_chunk_origin


## Block id -> registry index. Call once at the top of generate(), not per block.
func block(id: StringName) -> int:
	var idx := BlockRegistry.get_idx_of(id)
	if idx < 0: push_error("Terrain feature uses unknown block '%s'" % id)
	return idx


## Puts a block at `offset` from the origin, only where there's air (never eats terrain).
func place(offset: Vector3i, block_idx: int) -> void:
	var i := _index_of(offset)
	if block_idx >= 0 and i >= 0 and _blocks[i] == terrain.air_idx:
		_blocks[i] = block_idx


## Swaps `target_idx` for `block_idx` (e.g. stone -> ore).
func replace(offset: Vector3i, block_idx: int, target_idx: int) -> void:
	var i := _index_of(offset)
	if block_idx >= 0 and i >= 0 and _blocks[i] == target_idx:
		_blocks[i] = block_idx


## Puts a block on top of the ground in column (dx, dz), whatever its height there.
func place_on_surface(dx: int, dz: int, block_idx: int) -> void:
	var gx := origin.x + dx
	var gz := origin.z + dz
	var cs := Global.CHUNK_SIZE
	var lx := gx - _chunk_origin.x
	var lz := gz - _chunk_origin.z
	if lx < 0 or lx >= cs.x or lz < 0 or lz >= cs.z: return # cheap reject before sampling noise
	var y := terrain.sample_column(gx, gz).x + 1
	place(Vector3i(dx, y - origin.y, dz), block_idx)


func _index_of(offset: Vector3i) -> int:
	var l := origin + offset - _chunk_origin
	var cs := Global.CHUNK_SIZE
	if l.x < 0 or l.x >= cs.x or l.y < 0 or l.y >= cs.y or l.z < 0 or l.z >= cs.z:
		return -1
	return (l.y * cs.z + l.z) * cs.x + l.x # same layout as Chunk.block_index
