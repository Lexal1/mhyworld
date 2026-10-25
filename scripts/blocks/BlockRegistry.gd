@tool
extends Node

var _blocks: Array[Block] = []
var block_count := 0
var face_table := PackedByteArray()
var atlas_rects: Array[Rect2] = []

func register(block: Block, fname: String = ""):
	if _blocks.has(block):
		printerr("Attempt to register a block (%s) twice!" % [fname, block.id])
		return
	if id_exists(block.id):
		printerr("Duplicate ID '%s' while loading '%s'!" % [block.id, fname])
		return
	_blocks.push_back(block)

func get_by_id(id: StringName):
	for block in _blocks:
		if block.id == id:
			return block

func get_by_idx(idx: int):
	return _blocks[idx]

func id_exists(id: StringName):
	for block in _blocks:
		if block.id == id:
			return true
	return false

func block_exists(block: Block):
	return _blocks.has(block)

func get_idx_of_block(block: Block):
	var index = 0
	for item in _blocks:
		if item == block:
			return index
		index += 1
	return -1

func get_idx_of(id: StringName) -> int:
	var index = 0
	for item in _blocks:
		if item.id == id:
			return index
		index += 1
	return -1

func _build_face_table() -> void:
	#assert(MatterComponents.frozen)
	#_occlusion_id = MatterComponents.get_id(FaceOcclusionComponent)
	block_count = _blocks.size()
	face_table.resize(block_count * block_count)

	for a in block_count:
		for b in block_count:
			face_table[a * block_count + b] = 1 if _should_render(_blocks[a], _blocks[b]) else 0
func _should_render(owner: Block, neighbor: Block) -> bool:
	# air never draws anything
	if owner.id == &"air":
		return false

	# no occlusion component on the neighbor means the shared default
	#var occ := neighbor.get_component_by_id(_occlusion_id) as FaceOcclusionComponent
	#if occ == null:
	#	occ = _default_occlusion
	#return occ.should_render_face(owner, neighbor)
	return owner.solid

func _build_atlas_rects():
	atlas_rects.resize(_blocks.size())
	atlas_rects.fill(Rect2(0, 0, 1, 1))
	for i in _blocks.size()-1:
		var id = i+1 # skipping air
		var block: Block = get_by_idx(i)
		var top_face := block.atlas_position.TOP # code can currently only handle one texture for every face so for now we'll use the top one
		var atlas_pos := top_face * Global.TEXTURE_ATLAS_SIZE
		atlas_rects[i] = Rect2(atlas_pos, Global.TEXTURE_ATLAS_SIZE)

func _ready():
	for filename in DirAccess.get_files_at("res://assets/resources/blocks/"):
		var block = filename.replace(".remap", "")
		var evilBlock = load("res://assets/resources/blocks/" + block) as Block
		if evilBlock == null:
			printerr("Failed to load block %s" % block)
			continue
		#print(evilBlock)
		register(evilBlock, block)
		print("loaded block %s (%s)" % [evilBlock.id, block])
	_build_face_table()
	_build_atlas_rects()
