class_name WorldFile extends RefCounted

var version: String
var name: StringName
var createdAt: int
var modifiedAt: int
var globalChunkSize: Vector3 # = Global.CHUNK_SIZE
var playtime: int

# block int format:
# [blockState-16b][entityState-32b][id-16b]
# (b = bit)
# blockState is for stuff like the block's facing direction
# entityState is an index into a map of entity states inside the chunk
# id is just the block id
class Chunk extends RefCounted:
	var position: Vector2i
	var blocks: Array
	
