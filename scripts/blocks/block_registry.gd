@tool
extends Node

const BLOCK_DIR := "res://assets/resources/blocks/"

var _blocks: Array[Block] = []
var _idx_by_id: Dictionary = {} # StringName -> int
var solid_table := PackedByteArray() # solid_table[idx] = 1 if solid
var _scene_roots: Array[Node] = [] # templates stay alive; components live in them

func _ready() -> void:
	var files := DirAccess.get_files_at(BLOCK_DIR)
	files.sort()
	for filename in files:
		var block_file := filename.replace(".remap", "")
		var res := load(BLOCK_DIR + block_file)
		var block: Block = null
		if res is Block:
			block = res
		elif res is PackedScene:
			var root := (res as PackedScene).instantiate()
			if root is BlockDef:
				_scene_roots.push_back(root) # never added to the tree
				block = root.build()
			else:
				printerr("%s root isn't a BlockDef" % block_file)
				root.free()
		if block == null:
			printerr("Failed to load block %s" % block_file)
			continue
		register(block, block_file)
		print("loaded block %s (%s)" % [block.id, block_file])
	_build_solid_table()


func register(block: Block, fname: String = "") -> void:
	if _blocks.has(block):
		printerr("Attempt to register a block (%s) twice!" % fname)
		return
	if id_exists(block.id):
		printerr("Duplicate ID '%s' while loading '%s'!" % [block.id, fname])
		return
	_idx_by_id[block.id] = _blocks.size()
	_blocks.push_back(block)


func _build_solid_table() -> void:
	solid_table.resize(_blocks.size())
	for i in _blocks.size():
		solid_table[i] = 1 if _blocks[i].solid else 0


func get_by_id(id: StringName) -> Block:
	var idx: int = _idx_by_id.get(id, -1)
	return _blocks[idx] if idx >= 0 else null


func get_by_idx(idx: int) -> Block: return _blocks[idx]

func get_idx_of(id: StringName) -> int: return _idx_by_id.get(id, -1)

func get_idx_of_block(block: Block) -> int: return _blocks.find(block)

func id_exists(id: StringName) -> bool: return _idx_by_id.has(id)

func block_exists(block: Block) -> bool: return _blocks.has(block)

func _exit_tree() -> void:
	for r in _scene_roots: r.free()
