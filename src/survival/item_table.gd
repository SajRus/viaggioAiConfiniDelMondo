class_name ItemTable
extends RefCounted

## An item is a block, with the block ID, or a tool or a gem, with an ID above
## every block. Saves store these numbers: they never change, a new item takes a free ID.

const NONE: int = 0
const WOODEN_PICKAXE: int = 256
const STONE_PICKAXE: int = 257
## The gems, in the order of the gem blocks, then the one the dragon leaves.
const RUBY: int = 258
const EMERALD: int = 259
const OBSIDIAN: int = 260
const GOLD: int = 261
const DIAMOND: int = 262
const AMETHYST: int = 263
const BORDER_GEM: int = 264
const WOODEN_SWORD: int = 265
const STONE_SWORD: int = 266
const MAX_STACK: int = 64

const TILE_WOODEN_PICKAXE: int = 14
const TILE_STONE_PICKAXE: int = 15
const TILE_RUBY: int = 25
const TILE_WOODEN_SWORD: int = 32
const TILE_STONE_SWORD: int = 33

const HAND_FAST_SECONDS: float = 0.3
const HAND_SOFT_SECONDS: float = 0.6
const HAND_WOOD_SECONDS: float = 1.5
const HAND_STONE_SECONDS: float = 4.0
const WOODEN_PICKAXE_STONE_SECONDS: float = 1.5
const STONE_PICKAXE_STONE_SECONDS: float = 0.8
const GEM_BLOCK_SECONDS: float = 1.5
## In survival some blocks never break: the altar, and stone bricks by hand.
const UNBREAKABLE: float = INF


static func is_block(item: int) -> bool:
	return item >= BlockTable.GRASS and item <= BlockTable.LAST_BLOCK


static func is_tool_item(item: int) -> bool:
	return item == WOODEN_PICKAXE or item == STONE_PICKAXE or item == WOODEN_SWORD or item == STONE_SWORD


static func is_gem(item: int) -> bool:
	return item >= RUBY and item <= BORDER_GEM


static func is_known_item(item: int) -> bool:
	return is_block(item) or is_tool_item(item) or is_gem(item)


static func stack_limit(item: int) -> int:
	return 1 if is_tool_item(item) else MAX_STACK


## What a broken block gives: grass gives dirt, a gem block its gem; leaves,
## glass and the altar give nothing.
static func drop_of(block: int) -> int:
	if block >= BlockTable.GEM_RUBY and block <= BlockTable.GEM_AMETHYST:
		return RUBY + block - BlockTable.GEM_RUBY
	match block:
		BlockTable.GRASS:
			return BlockTable.DIRT
		BlockTable.LEAVES, BlockTable.GLASS, BlockTable.ALTAR:
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
		BlockTable.STONE, BlockTable.ARENA_STONE, BlockTable.STONE_BRICKS:
			if held == STONE_PICKAXE:
				return STONE_PICKAXE_STONE_SECONDS
			if held == WOODEN_PICKAXE:
				return WOODEN_PICKAXE_STONE_SECONDS
			return UNBREAKABLE if block == BlockTable.STONE_BRICKS else HAND_STONE_SECONDS
		BlockTable.ALTAR:
			return UNBREAKABLE
	if block >= BlockTable.GEM_RUBY and block <= BlockTable.GEM_AMETHYST:
		return GEM_BLOCK_SECONDS
	return HAND_SOFT_SECONDS


## The atlas tile of an item's icon: the side of a block, or its own tile.
static func icon_tile(item: int) -> int:
	if is_gem(item):
		return TILE_RUBY + item - RUBY
	if item == STONE_PICKAXE:
		return TILE_STONE_PICKAXE
	if item == WOODEN_PICKAXE:
		return TILE_WOODEN_PICKAXE
	if item == WOODEN_SWORD:
		return TILE_WOODEN_SWORD
	if item == STONE_SWORD:
		return TILE_STONE_SWORD
	return BlockRegistry.tile_side[item]


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
		BlockTable.STONE_BRICKS:
			return "Mattoni di pietra"
		BlockTable.ARENA_STONE:
			return "Pietra dell'arena"
		BlockTable.ALTAR:
			return "Altare dei Confini"
		BlockTable.GEM_RUBY:
			return "Blocco di rubino"
		BlockTable.GEM_EMERALD:
			return "Blocco di smeraldo"
		BlockTable.GEM_OBSIDIAN:
			return "Blocco di ossidiana"
		BlockTable.GEM_GOLD:
			return "Blocco d'oro"
		BlockTable.GEM_DIAMOND:
			return "Blocco di diamante"
		BlockTable.GEM_AMETHYST:
			return "Blocco di ametista"
		WOODEN_PICKAXE:
			return "Piccone di legno"
		STONE_PICKAXE:
			return "Piccone di pietra"
		WOODEN_SWORD:
			return "Spada di legno"
		STONE_SWORD:
			return "Spada di pietra"
		RUBY:
			return "Rubino"
		EMERALD:
			return "Smeraldo"
		OBSIDIAN:
			return "Ossidiana"
		GOLD:
			return "Oro"
		DIAMOND:
			return "Diamante"
		AMETHYST:
			return "Ametista"
		BORDER_GEM:
			return "Gemma del Confine"
	return ""
