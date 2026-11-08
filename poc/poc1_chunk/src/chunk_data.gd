class_name ChunkData
extends RefCounted

const SIZE_X: int = 16
const SIZE_Z: int = 16
const SIZE_Y: int = 64
const VOLUME: int = SIZE_X * SIZE_Z * SIZE_Y

var blocks: PackedByteArray = PackedByteArray()


func _init() -> void:
	blocks.resize(VOLUME)
	blocks.fill(BlockTable.AIR)


static func index_of(x: int, y: int, z: int) -> int:
	return x + SIZE_X * z + SIZE_X * SIZE_Z * y


static func is_inside(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < SIZE_X and y >= 0 and y < SIZE_Y and z >= 0 and z < SIZE_Z


func get_block(x: int, y: int, z: int) -> int:
	return blocks[index_of(x, y, z)]


func set_block(x: int, y: int, z: int, id: int) -> void:
	blocks[index_of(x, y, z)] = id
