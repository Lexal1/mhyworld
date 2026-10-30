class_name Inventory extends RefCounted
## What the player carries: a tree of InvFile starting at `root`. Space is in "KB" against `capacity`.

signal changed

var capacity := 128
var root := InvFile.folder("C:")


func used() -> int: return root.size_kb()

func free_space() -> int: return maxi(capacity - used(), 0)


func item_size(id: StringName) -> int:
	var b: Block = BlockRegistry.get_by_id(id)
	return b.size if b != null else 0


func expand(amount: int) -> void:
	capacity += amount
	changed.emit()


#region Items

## Adds as many as fit. Returns how many did NOT fit.
@warning_ignore("integer_division")
func add(id: StringName, count := 1) -> int:
	var b: Block = BlockRegistry.get_by_id(id)
	if b == null:
		push_error("Inventory: unknown item '%s'" % id)
		return count
	var fit := count if b.size <= 0 else mini(count, free_space() / b.size)
	if fit <= 0: return count
	var existing := _stacks_of(root, InvFile.Kind.ITEM, id)
	if existing.is_empty():
		_put_stack(root, InvFile.Kind.ITEM, id, fit)
	else:
		existing[0].count += fit
	changed.emit()
	return count - fit


func remove(id: StringName, count := 1) -> bool:
	var stacks := _stacks_of(root, InvFile.Kind.ITEM, id)
	var have := 0
	for s in stacks: have += s.count
	if have < count: return false
	for s in stacks:
		var take := mini(s.count, count)
		s.count -= take
		count -= take
		if s.count <= 0: _detach(s)
		if count <= 0: break
	changed.emit()
	return true

#endregion


#region File operations

func make_folder(in_folder: InvFile, folder_name: String) -> InvFile:
	var f := InvFile.folder(folder_name)
	_attach(in_folder, f)
	changed.emit()
	return f


## Needs 1 KB free. Returns null if there's no room.
func make_text(in_folder: InvFile, file_name: String) -> InvFile:
	if free_space() < 1: return null
	var f := InvFile.text_file(file_name)
	_attach(in_folder, f)
	changed.emit()
	return f


func rename(f: InvFile, new_name: String) -> void:
	if f.is_stack() or f.parent == null: return
	f.name = _unique_name(f.parent, new_name, f)
	changed.emit()


## Deletes a folder or text file. Stacks (and folders holding them) must be recycled or moved instead.
func delete(f: InvFile) -> bool:
	if f.parent == null or f.contains_stacks(): return false
	_detach(f)
	changed.emit()
	return true


## Saves as much of `text` as still fits on the drive.
func set_text(f: InvFile, text: String) -> void:
	if f.kind != InvFile.Kind.TEXT: return
	var max_chars := (f.size_kb() + free_space()) * InvFile.TEXT_CHARS_PER_KB
	f.text = text.substr(0, max_chars)
	changed.emit()


func move(f: InvFile, dest: InvFile) -> bool:
	if not dest.is_folder() or f == dest or f.parent == null or f.parent == dest: return false
	if f.is_folder() and dest.is_inside(f): return false # can't put a folder inside itself
	_detach(f)
	if f.is_stack():
		_put_stack(dest, f.kind, f.item_id, f.count)
	else:
		_attach(dest, f)
	changed.emit()
	return true


## Adds stack `a` into stack `into` (same type only).
func merge(a: InvFile, into: InvFile) -> bool:
	if a == into or not a.is_stack() or a.kind != into.kind or a.item_id != into.item_id: return false
	into.count += a.count
	_detach(a)
	changed.emit()
	return true


## Moves `amount` out of the stack into a new stack file next to it.
func split(f: InvFile, amount: int) -> bool:
	if not f.is_stack() or f.parent == null or amount <= 0 or amount >= f.count: return false
	f.count -= amount
	_attach(f.parent, InvFile.stack(f.kind, f.item_id, amount))
	changed.emit()
	return true


## Breaks a whole stack into components, placed in the same folder.
func recycle(f: InvFile) -> bool:
	if f.kind != InvFile.Kind.ITEM or f.parent == null: return false
	var b: Block = BlockRegistry.get_by_id(f.item_id)
	if b == null or b.recycle.is_empty(): return false

	var parts := 0
	for n in b.recycle.values(): parts += n
	if parts * f.count * InvFile.COMPONENT_SIZE > free_space() + f.size_kb(): return false

	var folder := f.parent
	_detach(f)
	for cid in b.recycle:
		_put_stack(folder, InvFile.Kind.COMPONENT, cid, b.recycle[cid] * f.count)
	changed.emit()
	return true

#endregion


#region Helpers

func _attach(folder: InvFile, f: InvFile) -> void:
	if not f.is_stack():
		f.name = _unique_name(folder, f.name)
	f.parent = folder
	folder.children.push_back(f)


func _detach(f: InvFile) -> void:
	var p := f.parent
	if p != null: p.children.erase(f)
	f.parent = null


## Adds to a matching stack in `folder`, or creates one.
func _put_stack(folder: InvFile, kind: InvFile.Kind, id: StringName, n: int) -> void:
	for c in folder.children:
		if c.kind == kind and c.item_id == id:
			c.count += n
			return
	_attach(folder, InvFile.stack(kind, id, n))


func _stacks_of(folder: InvFile, kind: InvFile.Kind, id: StringName) -> Array[InvFile]:
	var out: Array[InvFile] = []
	for c in folder.children:
		if c.is_folder(): out.append_array(_stacks_of(c, kind, id))
		elif c.kind == kind and c.item_id == id: out.push_back(c)
	return out


func _unique_name(folder: InvFile, wanted: String, ignore: InvFile = null) -> String:
	var base := wanted.strip_edges()
	if base.is_empty(): base = "Unnamed"
	var n := base
	var i := 2
	while _name_taken(folder, n, ignore):
		n = "%s (%d)" % [base, i]
		i += 1
	return n


func _name_taken(folder: InvFile, n: String, ignore: InvFile) -> bool:
	for c in folder.children:
		if c != ignore and not c.is_stack() and c.name == n: return true
	return false

#endregion
