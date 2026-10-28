@tool
class_name BlockComponent extends Node
## Base class for block behaviours. One instance is shared by EVERY block of
## that type, on multiple threads, so never store per-block state on `self`.
## Store it in the chunk's tags instead (block.set_tag / get_tag).

func on_block_created(_block: Block, _pos: Vector3, _chunk: StaticBody3D) -> void: pass
func on_block_destroyed(_block: Block, _pos: Vector3, _chunk: StaticBody3D) -> void: pass
