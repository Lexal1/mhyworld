@tool
extends Node

var _blocks: Array[Block] = []

func register(block: Block, fname: String = ""):
	if _blocks.has(block):
		printerr("Attempt to register a block (%s) twice!" % [fname, block.id])
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
