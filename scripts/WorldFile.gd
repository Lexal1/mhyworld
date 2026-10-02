class_name WorldFile extends RefCounted # might rename to savefile

var version: String
var name: StringName
var createdAt: int
var modifiedAt: int
var globalChunkSize: Vector3 # = Global.CHUNK_SIZE
var playtime: int

func write_chunk(chunk: Chunk, file: FileAccess) -> void:
	chunk.blocksMutex.lock() # this will be changed later, for now we just need to get the barebones
	# of the save system before doing optimization
	file.store_var(chunk.blocks) # unsafe as FUCK
	chunk.blocksMutex.unlock()

func read_chunk(file: FileAccess, pos: Vector2) -> WFChunk:
	var blocks: Array = file.get_var()
	var wfc = WFChunk.new()
	wfc.position = pos
	wfc.blocks = blocks
	return wfc

# block int format:
# [blockState-16b][entityState-32b][id-16b]
# (b = bit)
# blockState is for stuff like the block's facing direction
# entityState is an index into a map of entity states inside the chunk
# id is just the block id
class WFChunk extends RefCounted:
	var position: Vector2i
	var blocks: Array
	
