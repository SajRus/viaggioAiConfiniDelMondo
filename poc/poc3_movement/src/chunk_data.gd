class_name ChunkData
extends RefCounted

const SIZE_X: int = 16
const SIZE_Z: int = 16
const SIZE_Y: int = 64
const VOLUME: int = SIZE_X * SIZE_Z * SIZE_Y

const SIDE_POS_X: int = 0
const SIDE_NEG_X: int = 1
const SIDE_POS_Z: int = 2
const SIDE_NEG_Z: int = 3
const SIDES: int = 4

var blocks: PackedByteArray = PackedByteArray()
# Weak references: chunks pointing at each other would otherwise never be freed.
var _neighbors: Array[WeakRef] = []


func _init() -> void:
	blocks.resize(VOLUME)
	blocks.fill(BlockTable.AIR)
	_neighbors.resize(SIDES)


static func index_of(x: int, y: int, z: int) -> int:
	return x + SIZE_X * z + SIZE_X * SIZE_Z * y


static func is_inside(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < SIZE_X and y >= 0 and y < SIZE_Y and z >= 0 and z < SIZE_Z


func get_block(x: int, y: int, z: int) -> int:
	return blocks[index_of(x, y, z)]


func set_block(x: int, y: int, z: int, id: int) -> void:
	blocks[index_of(x, y, z)] = id


func link_neighbor(side: int, neighbor: ChunkData) -> void:
	_neighbors[side] = weakref(neighbor)


## Returns null on the world border.
func get_neighbor(side: int) -> ChunkData:
	var link: WeakRef = _neighbors[side]
	if link == null:
		return null
	return link.get_ref()
