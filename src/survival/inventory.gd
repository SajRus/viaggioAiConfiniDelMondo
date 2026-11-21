class_name Inventory
extends RefCounted

## 32 slots: the first 8 are the hotbar. Each slot holds one item type.

signal changed

const SLOTS: int = 32
const HOTBAR_SLOTS: int = 8

var items: PackedInt32Array = PackedInt32Array()
var counts: PackedInt32Array = PackedInt32Array()
## Stack picked up with a click in the inventory screen, not in any slot.
var held_item: int = ItemTable.NONE
var held_count: int = 0


func _init() -> void:
	items.resize(SLOTS)
	counts.resize(SLOTS)
	clear()


func clear() -> void:
	items.fill(ItemTable.NONE)
	counts.fill(0)
	held_item = ItemTable.NONE
	held_count = 0
	changed.emit()


## Loads saved slots. Returns false, and changes nothing, when they are not valid.
func load_slots(saved_items: PackedInt32Array, saved_counts: PackedInt32Array) -> bool:
	if saved_items.size() != SLOTS or saved_counts.size() != SLOTS:
		return false
	for slot: int in SLOTS:
		if not is_valid_slot(saved_items[slot], saved_counts[slot]):
			return false
	items = saved_items.duplicate()
	counts = saved_counts.duplicate()
	held_item = ItemTable.NONE
	held_count = 0
	changed.emit()
	return true


static func is_valid_slot(item: int, count: int) -> bool:
	if item == ItemTable.NONE:
		return count == 0
	return ItemTable.is_known_item(item) and count >= 1 and count <= ItemTable.stack_limit(item)


func duplicate_inventory() -> Inventory:
	var copy: Inventory = Inventory.new()
	copy.items = items.duplicate()
	copy.counts = counts.duplicate()
	return copy


func count_of(item: int) -> int:
	var total: int = 0
	for slot: int in SLOTS:
		if items[slot] == item:
			total += counts[slot]
	return total


## How many of [param item] would fit.
func space_for(item: int) -> int:
	var limit: int = ItemTable.stack_limit(item)
	var space: int = 0
	for slot: int in SLOTS:
		if items[slot] == item:
			space += limit - counts[slot]
		elif items[slot] == ItemTable.NONE:
			space += limit
	return space


## Fills stacks of the same item first, then empty slots in order. Returns how
## many fitted: the rest is lost.
func add(item: int, count: int) -> int:
	var left: int = count
	var limit: int = ItemTable.stack_limit(item)
	for slot: int in SLOTS:
		if left > 0 and items[slot] == item and counts[slot] < limit:
			var moved: int = mini(left, limit - counts[slot])
			counts[slot] += moved
			left -= moved
	for slot: int in SLOTS:
		if left > 0 and items[slot] == ItemTable.NONE:
			var moved: int = mini(left, limit)
			items[slot] = item
			counts[slot] = moved
			left -= moved
	if left != count:
		changed.emit()
	return count - left


## Removes [param count] of [param item] from any slots, or nothing when there are fewer.
func remove(item: int, count: int) -> bool:
	if count_of(item) < count:
		return false
	var left: int = count
	for slot: int in SLOTS:
		if left > 0 and items[slot] == item:
			var moved: int = mini(left, counts[slot])
			_set_count(slot, counts[slot] - moved)
			left -= moved
	changed.emit()
	return true


## Uses one item from [param slot], as placing a block does.
func take_one(slot: int) -> void:
	if counts[slot] > 0:
		_set_count(slot, counts[slot] - 1)
		changed.emit()


## A click on a slot of the inventory screen: picks the stack up, or puts the
## held stack down, merging it with the same item or swapping it with another.
func click(slot: int) -> void:
	if held_count == 0:
		held_item = items[slot]
		held_count = counts[slot]
		_set_count(slot, 0)
	elif items[slot] == ItemTable.NONE:
		items[slot] = held_item
		counts[slot] = held_count
		held_item = ItemTable.NONE
		held_count = 0
	elif items[slot] == held_item:
		var moved: int = mini(held_count, ItemTable.stack_limit(held_item) - counts[slot])
		counts[slot] += moved
		held_count -= moved
		if held_count == 0:
			held_item = ItemTable.NONE
	else:
		var swapped_item: int = items[slot]
		var swapped_count: int = counts[slot]
		items[slot] = held_item
		counts[slot] = held_count
		held_item = swapped_item
		held_count = swapped_count
	changed.emit()


## Puts the held stack back when the screen closes. What does not fit is lost.
func return_held() -> void:
	if held_count > 0:
		var item: int = held_item
		var count: int = held_count
		held_item = ItemTable.NONE
		held_count = 0
		add(item, count)
		changed.emit()


func _set_count(slot: int, count: int) -> void:
	counts[slot] = count
	if count == 0:
		items[slot] = ItemTable.NONE
