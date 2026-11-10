class_name Hotbar
extends RefCounted

signal selection_changed(index: int)

const BLOCKS: PackedInt32Array = [
	BlockTable.GRASS, BlockTable.DIRT, BlockTable.STONE, BlockTable.SAND,
	BlockTable.LOG, BlockTable.LEAVES, BlockTable.PLANKS, BlockTable.GLASS,
]

var selected_index: int = 0


func selected_block() -> int:
	return BLOCKS[selected_index]


## Ignores slots that do not exist, so any key can be passed in.
func select(index: int) -> void:
	if index >= 0 and index < BLOCKS.size() and index != selected_index:
		selected_index = index
		selection_changed.emit(selected_index)


## Moves the selection by [param steps], wrapping around the ends.
func scroll(steps: int) -> void:
	select(posmod(selected_index + steps, BLOCKS.size()))
