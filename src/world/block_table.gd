class_name BlockTable
extends Node

## Registered as the BlockRegistry autoload.

const AIR: int = 0
const GRASS: int = 1
const DIRT: int = 2
const STONE: int = 3
const SAND: int = 4
const LOG: int = 5
const LEAVES: int = 6
const PLANKS: int = 7
const GLASS: int = 8

const ATLAS_COLUMN_BITS: int = 2
const ATLAS_COLUMNS: int = 1 << ATLAS_COLUMN_BITS
const ATLAS_TILE_PIXELS: int = 16
const ATLAS_TILE_UV: float = 1.0 / ATLAS_COLUMNS

const TILE_GRASS_TOP: int = 0
const TILE_GRASS_SIDE: int = 1
const TILE_DIRT: int = 2
const TILE_STONE: int = 3
const TILE_SAND: int = 4
const TILE_LOG_TOP: int = 5
const TILE_LOG_SIDE: int = 6
const TILE_LEAVES: int = 7
const TILE_PLANKS: int = 8
const TILE_GLASS: int = 9

const MAX_TYPES: int = 256

var solid: PackedByteArray = PackedByteArray()
var transparent: PackedByteArray = PackedByteArray()
## True when a block hides the face of the block next to it.
var occluding: PackedByteArray = PackedByteArray()
var tile_top: PackedByteArray = PackedByteArray()
var tile_side: PackedByteArray = PackedByteArray()
var tile_bottom: PackedByteArray = PackedByteArray()


func _init() -> void:
	for table: PackedByteArray in [solid, transparent, occluding, tile_top, tile_side, tile_bottom]:
		table.resize(MAX_TYPES)
		table.fill(0)
	_define(GRASS, TILE_GRASS_TOP, TILE_GRASS_SIDE, TILE_DIRT, false)
	_define(DIRT, TILE_DIRT, TILE_DIRT, TILE_DIRT, false)
	_define(STONE, TILE_STONE, TILE_STONE, TILE_STONE, false)
	_define(SAND, TILE_SAND, TILE_SAND, TILE_SAND, false)
	_define(LOG, TILE_LOG_TOP, TILE_LOG_SIDE, TILE_LOG_TOP, false)
	_define(LEAVES, TILE_LEAVES, TILE_LEAVES, TILE_LEAVES, true)
	_define(PLANKS, TILE_PLANKS, TILE_PLANKS, TILE_PLANKS, false)
	_define(GLASS, TILE_GLASS, TILE_GLASS, TILE_GLASS, true)


static func tile_uv_origin(tile: int) -> Vector2:
	return Vector2(tile & (ATLAS_COLUMNS - 1), tile >> ATLAS_COLUMN_BITS) * ATLAS_TILE_UV


func _define(id: int, top: int, side: int, bottom: int, is_transparent: bool) -> void:
	solid[id] = 1
	transparent[id] = 1 if is_transparent else 0
	occluding[id] = 0 if is_transparent else 1
	tile_top[id] = top
	tile_side[id] = side
	tile_bottom[id] = bottom
