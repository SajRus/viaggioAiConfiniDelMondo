class_name Recipe
extends RefCounted

var input_items: PackedInt32Array
var input_counts: PackedInt32Array
var output_item: int
var output_count: int


func _init(
	ingredients: PackedInt32Array, amounts: PackedInt32Array, result: int, result_count: int
) -> void:
	input_items = ingredients
	input_counts = amounts
	output_item = result
	output_count = result_count


## The four recipes of RF-26 and the two swords of RF-29, in the order the
## inventory screen lists them.
static func all() -> Array[Recipe]:
	var recipes: Array[Recipe] = [
		Recipe.new([BlockTable.LOG], [1], BlockTable.PLANKS, 4),
		Recipe.new([BlockTable.SAND], [4], BlockTable.GLASS, 1),
		Recipe.new([BlockTable.PLANKS], [5], ItemTable.WOODEN_PICKAXE, 1),
		Recipe.new([BlockTable.PLANKS, BlockTable.STONE], [2, 3], ItemTable.STONE_PICKAXE, 1),
		Recipe.new([BlockTable.PLANKS], [3], ItemTable.WOODEN_SWORD, 1),
		Recipe.new([BlockTable.PLANKS, BlockTable.STONE], [1, 2], ItemTable.STONE_SWORD, 1),
	]
	return recipes


## True when the ingredients are there and the result fits once they are used.
func can_craft(inventory: Inventory) -> bool:
	var after: Inventory = inventory.duplicate_inventory()
	for index: int in input_items.size():
		if not after.remove(input_items[index], input_counts[index]):
			return false
	return after.space_for(output_item) >= output_count


func craft(inventory: Inventory) -> bool:
	if not can_craft(inventory):
		return false
	for index: int in input_items.size():
		inventory.remove(input_items[index], input_counts[index])
	inventory.add(output_item, output_count)
	return true


func describe() -> String:
	var parts: PackedStringArray = []
	for index: int in input_items.size():
		parts.append("%d %s" % [input_counts[index], ItemTable.display_name(input_items[index]).to_lower()])
	return "%s: %s → %d" % [ItemTable.display_name(output_item), " e ".join(parts), output_count]
