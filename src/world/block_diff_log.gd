class_name BlockDiffLog
extends RefCounted

var _chunks: Dictionary[int, Dictionary] = {}


func record(chunk_index: int, block_index: int, id: int) -> void:
	if not _chunks.has(chunk_index):
		_chunks[chunk_index] = {}
	var entries: Dictionary = _chunks[chunk_index]
	entries[block_index] = id


func chunk_indices() -> Array[int]:
	var indices: Array[int] = _chunks.keys()
	indices.sort()
	return indices


func entries_of(chunk_index: int) -> Dictionary[int, int]:
	var entries: Dictionary[int, int] = {}
	entries.assign(_chunks[chunk_index])
	return entries


func block_count() -> int:
	var total: int = 0
	for entries: Dictionary in _chunks.values():
		total += entries.size()
	return total
