class_name Inventory extends RefCounted
## What the player carries. Space is measured in "KB" against `capacity` (the Drive Capacity).

signal changed

const COMPONENT_SIZE := 1 ## Components are smaller than the items they come from.

var capacity := 128
var items := {}      # item id -> count
var components := {} # component id -> count


func used() -> int:
	var total := 0
	for id in items:
		total += items[id] * item_size(id)
	for id in components:
		total += components[id] * COMPONENT_SIZE
	return total


func free_space() -> int:
	return maxi(capacity - used(), 0)


func item_size(id: StringName) -> int:
	var b: Block = BlockRegistry.get_by_id(id)
	return b.size if b != null else 0


func expand(amount: int) -> void:
	capacity += amount
	changed.emit()


## Adds as many as fit. Returns how many did NOT fit.
@warning_ignore("integer_division")
func add(id: StringName, count := 1) -> int:
	var b: Block = BlockRegistry.get_by_id(id)
	if b == null:
		push_error("Inventory: unknown item '%s'" % id)
		return count
	var fit := count if b.size <= 0 else mini(count, free_space() / b.size)
	if fit <= 0: return count
	items[id] = items.get(id, 0) + fit
	changed.emit()
	return count - fit


func remove(id: StringName, count := 1) -> bool:
	if items.get(id, 0) < count: return false
	_take(id, count)
	changed.emit()
	return true


## Breaks items down into their components. Fails if the block has no recipe or nothing fits.
func recycle(id: StringName, count := 1) -> bool:
	var b: Block = BlockRegistry.get_by_id(id)
	if b == null or b.recycle.is_empty() or items.get(id, 0) < count: return false

	var parts := 0
	for n in b.recycle.values(): parts += n
	if parts * count * COMPONENT_SIZE > free_space() + b.size * count: return false

	_take(id, count)
	for cid in b.recycle:
		components[cid] = components.get(cid, 0) + b.recycle[cid] * count
	changed.emit()
	return true


func _take(id: StringName, count: int) -> void:
	items[id] -= count
	if items[id] <= 0: items.erase(id)
