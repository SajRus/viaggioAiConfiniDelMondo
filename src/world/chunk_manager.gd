class_name ChunkManager
extends RefCounted

var diffs: BlockDiffLog

var _world: WorldData
var _mesher: ChunkMesher
var _nodes: Array[ChunkNode]
var _dirty_indices: PackedInt32Array = PackedInt32Array()


func _init(
	world: WorldData, mesher: ChunkMesher, nodes: Array[ChunkNode], block_diffs: BlockDiffLog = BlockDiffLog.new()
) -> void:
	diffs = block_diffs
	_world = world
	_mesher = mesher
	_nodes = nodes


func get_block(x: int, y: int, z: int) -> int:
	return _world.get_block_world(x, y, z)


## Writes one block and marks what must be rebuilt. Returns false when nothing changed.
func set_block(x: int, y: int, z: int, id: int) -> bool:
	if not _world.is_inside(x, y, z) or _world.get_block_world(x, y, z) == id:
		return false
	_world.set_block_world(x, y, z, id)
	var chunk_x: int = x >> WorldData.CHUNK_BITS
	var chunk_z: int = z >> WorldData.CHUNK_BITS
	var local_x: int = x & WorldData.CHUNK_MASK
	var local_z: int = z & WorldData.CHUNK_MASK
	diffs.record(chunk_x + _world.chunks_x * chunk_z, ChunkData.index_of(local_x, y, local_z), id)
	_mark_dirty(chunk_x, chunk_z)
	if local_x == 0:
		_mark_dirty(chunk_x - 1, chunk_z)
	elif local_x == WorldData.CHUNK_MASK:
		_mark_dirty(chunk_x + 1, chunk_z)
	if local_z == 0:
		_mark_dirty(chunk_x, chunk_z - 1)
	elif local_z == WorldData.CHUNK_MASK:
		_mark_dirty(chunk_x, chunk_z + 1)
	return true


## Rebuilds every marked chunk and returns their indices.
func flush() -> PackedInt32Array:
	var rebuilt: PackedInt32Array = _dirty_indices
	_dirty_indices = PackedInt32Array()
	for index: int in rebuilt:
		var chunk: ChunkData = _world.chunks[index]
		_nodes[index].rebuild(_mesher, chunk)
		chunk.dirty = false
	return rebuilt


func _mark_dirty(chunk_x: int, chunk_z: int) -> void:
	if chunk_x < 0 or chunk_x >= _world.chunks_x or chunk_z < 0 or chunk_z >= _world.chunks_z:
		return
	var index: int = chunk_x + _world.chunks_x * chunk_z
	var chunk: ChunkData = _world.chunks[index]
	if not chunk.dirty:
		chunk.dirty = true
		_dirty_indices.append(index)
