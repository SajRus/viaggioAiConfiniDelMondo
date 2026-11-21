class_name ItemTable
extends RefCounted

## An item is a block, with the block ID, or a tool, with an ID above every block.
## Saves store these numbers: they never change, a new item takes a free ID.

const NONE: int = 0
const WOODEN_PICKAXE: int = 256
const STONE_PICKAXE: int = 257
const MAX_STACK: int = 64

const TILE_WOODEN_PICKAXE: int = 14
const TILE_STONE_PICKAXE: int = 15

const HAND_FAST_SECONDS: float = 0.3
const HAND_SOFT_SECONDS: float = 0.6
const HAND_WOOD_SECONDS: float = 1.5
const HAND_STONE_SECONDS: float = 4.0
const WOODEN_PICKAXE_STONE_SECONDS: float = 1.5
const STONE_PICKAXE_STONE_SECONDS: float = 0.8


static func is_block(item: int) -> bool:
	return item >= BlockTable.GRASS and item <= BlockTable.GLASS


static func is_tool_item(item: int) -> bool:
	return item == WOODEN_PICKAXE or item == STONE_PICKAXE


static func is_known_item(item: int) -> bool:
	return is_block(item) or is_tool_item(item)


static func stack_limit(item: int) -> int:
	return 1 if is_tool_item(item) else MAX_STACK


## What a broken block gives: grass gives dirt, leaves and glass give nothing.
static func drop_of(block: int) -> int:
	match block:
		BlockTable.GRASS:
			return BlockTable.DIRT
		BlockTable.LEAVES, BlockTable.GLASS:
			return NONE
	return block


## Seconds of holding the button to break [param block] with [param held] selected.
static func break_seconds(block: int, held: int) -> float:
	match block:
		BlockTable.LEAVES, BlockTable.GLASS:
			return HAND_FAST_SECONDS
		BlockTable.GRASS, BlockTable.DIRT, BlockTable.SAND:
			return HAND_SOFT_SECONDS
		BlockTable.LOG, BlockTable.PLANKS:
			return HAND_WOOD_SECONDS
		BlockTable.STONE:
			if held == STONE_PICKAXE:
				return STONE_PICKAXE_STONE_SECONDS
			if held == WOODEN_PICKAXE:
				return WOODEN_PICKAXE_STONE_SECONDS
			return HAND_STONE_SECONDS
	return HAND_SOFT_SECONDS


static func tool_tile(item: int) -> int:
	return TILE_STONE_PICKAXE if item == STONE_PICKAXE else TILE_WOODEN_PICKAXE


static func display_name(item: int) -> String:
	match item:
		BlockTable.GRASS:
			return "Erba"
		BlockTable.DIRT:
			return "Terra"
		BlockTable.STONE:
			return "Pietra"
		BlockTable.SAND:
			return "Sabbia"
		BlockTable.LOG:
			return "Tronco"
		BlockTable.LEAVES:
			return "Foglie"
		BlockTable.PLANKS:
			return "Assi"
		BlockTable.GLASS:
			return "Vetro"
		WOODEN_PICKAXE:
			return "Piccone di legno"
		STONE_PICKAXE:
			return "Piccone di pietra"
	return ""
