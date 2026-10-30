class_name InvFile extends RefCounted
## One entry in the inventory's file tree: a folder, an item stack, a component stack or a text file.

enum Kind { FOLDER, ITEM, COMPONENT, TEXT }
const COMPONENT_SIZE := 1 ## KB per component.
const TEXT_CHARS_PER_KB := 64

var kind := Kind.FOLDER
var name := ""                 # folders and text files
var item_id: StringName = &""  # stacks
var count := 1
var text := ""
var children: Array[InvFile] = []

# Weak, so parent <-> children doesn't make a reference cycle (RefCounted would leak it).
var _parent_ref: WeakRef
var parent: InvFile:
	get: return (_parent_ref.get_ref() as InvFile) if _parent_ref != null else null
	set(value): _parent_ref = weakref(value) if value != null else null


static func folder(n: String) -> InvFile:
	var f := InvFile.new()
	f.name = n
	return f


## True if this file or anything inside it is an item/component stack.
func contains_stacks() -> bool:
	if is_stack(): return true
	for c in children:
		if c.contains_stacks(): return true
	return false


static func stack(k: Kind, id: StringName, n: int) -> InvFile:
	var f := InvFile.new()
	f.kind = k
	f.item_id = id
	f.count = n
	return f


static func text_file(n: String) -> InvFile:
	var f := InvFile.new()
	f.kind = Kind.TEXT
	f.name = n
	return f


func is_folder() -> bool: return kind == Kind.FOLDER

func is_stack() -> bool: return kind == Kind.ITEM or kind == Kind.COMPONENT


func display_name() -> String:
	return String(item_id) if is_stack() else name


func size_kb() -> int:
	match kind:
		Kind.ITEM:
			var b: Block = BlockRegistry.get_by_id(item_id)
			return count * (b.size if b != null else 0)
		Kind.COMPONENT:
			return count * COMPONENT_SIZE
		Kind.TEXT:
			return maxi(1, ceili(text.length() / float(TEXT_CHARS_PER_KB)))
	var total := 0
	for c in children: total += c.size_kb()
	return total


func path() -> String:
	var p := parent
	return name if p == null else p.path() + "\\" + name


func is_inside(other: InvFile) -> bool:
	var p := parent
	while p != null:
		if p == other: return true
		p = p.parent
	return false
