class_name WorldData
extends RefCounted

const CHUNK_BITS: int = 4
const CHUNK_MASK: int = (1 << CHUNK_BITS) - 1

var chunks_x: int
var chunks_z: int
var chunks: Array[ChunkData] = []


func _init(size_in_chunks_x: int, size_in_chunks_z: int) -> void:
	chunks_x = size_in_chunks_x
	chunks_z = size_in_chunks_z
	for _chunk: int in chunks_x * chunks_z:
		chunks.append(ChunkData.new())
	_link_neighbors()


func chunk_at(chunk_x: int, chunk_z: int) -> ChunkData:
	return chunks[chunk_x + chunks_x * chunk_z]


func coords_of(index: int) -> Vector2i:
	# Whole rows of chunks: the discarded remainder is the x coordinate.
	@warning_ignore("integer_division")
	return Vector2i(index % chunks_x, index / chunks_x)


func is_inside(x: int, y: int, z: int) -> bool:
	return (
		x >= 0 and x < chunks_x * ChunkData.SIZE_X
		and y >= 0 and y < ChunkData.SIZE_Y
		and z >= 0 and z < chunks_z * ChunkData.SIZE_Z
	)


func get_block_world(x: int, y: int, z: int) -> int:
	if not is_inside(x, y, z):
		return BlockTable.AIR
	var chunk: ChunkData = chunk_at(x >> CHUNK_BITS, z >> CHUNK_BITS)
	return chunk.get_block(x & CHUNK_MASK, y, z & CHUNK_MASK)


func set_block_world(x: int, y: int, z: int, id: int) -> void:
	if is_inside(x, y, z):
		chunk_at(x >> CHUNK_BITS, z >> CHUNK_BITS).set_block(x & CHUNK_MASK, y, z & CHUNK_MASK, id)


## Returns the y of the highest non-air block of the column, or -1 when empty.
func surface_height(x: int, z: int) -> int:
	for y: int in range(ChunkData.SIZE_Y - 1, -1, -1):
		if get_block_world(x, y, z) != BlockTable.AIR:
			return y
	return -1


func _link_neighbors() -> void:
	for chunk_z: int in chunks_z:
		for chunk_x: int in chunks_x:
			var chunk: ChunkData = chunk_at(chunk_x, chunk_z)
			if chunk_x + 1 < chunks_x:
				chunk.link_neighbor(ChunkData.SIDE_POS_X, chunk_at(chunk_x + 1, chunk_z))
			if chunk_x > 0:
				chunk.link_neighbor(ChunkData.SIDE_NEG_X, chunk_at(chunk_x - 1, chunk_z))
			if chunk_z + 1 < chunks_z:
				chunk.link_neighbor(ChunkData.SIDE_POS_Z, chunk_at(chunk_x, chunk_z + 1))
			if chunk_z > 0:
				chunk.link_neighbor(ChunkData.SIDE_NEG_Z, chunk_at(chunk_x, chunk_z - 1))
