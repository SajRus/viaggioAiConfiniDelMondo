class_name WorldData
extends RefCounted

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
