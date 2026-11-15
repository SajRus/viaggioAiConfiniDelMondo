class_name SaveCodec
extends RefCounted

const VERSION: int = 1
const HEADER_BYTES: int = 28
const GROUP_HEADER_BYTES: int = 8
const ENTRY_BYTES: int = 3


static func encode(state: WorldSave) -> PackedByteArray:
	var output: StreamPeerBuffer = StreamPeerBuffer.new()
	output.put_u32(VERSION)
	output.put_64(state.world_seed)
	output.put_float(state.player_position.x)
	output.put_float(state.player_position.y)
	output.put_float(state.player_position.z)
	var chunk_indices: Array[int] = state.diffs.chunk_indices()
	output.put_u32(chunk_indices.size())
	for chunk_index: int in chunk_indices:
		var entries: Dictionary[int, int] = state.diffs.entries_of(chunk_index)
		output.put_u32(chunk_index)
		output.put_u32(entries.size())
		for block_index: int in entries:
			output.put_u16(block_index)
			output.put_u8(entries[block_index])
	return output.data_array


## Returns null when the bytes are not a complete save of a known version.
static func decode(bytes: PackedByteArray) -> WorldSave:
	if bytes.size() < HEADER_BYTES:
		return null
	var input: StreamPeerBuffer = StreamPeerBuffer.new()
	input.data_array = bytes
	if input.get_u32() != VERSION:
		return null
	var state: WorldSave = WorldSave.new()
	state.world_seed = input.get_64()
	state.player_position = Vector3(input.get_float(), input.get_float(), input.get_float())
	state.has_player_position = true
	if not state.player_position.is_finite():
		return null
	var groups: int = input.get_u32()
	for _group: int in groups:
		if not _read_group(input, state.diffs):
			return null
	return state if input.get_available_bytes() == 0 else null


static func _read_group(input: StreamPeerBuffer, diffs: BlockDiffLog) -> bool:
	if input.get_available_bytes() < GROUP_HEADER_BYTES:
		return false
	var chunk_index: int = input.get_u32()
	var entries: int = input.get_u32()
	if input.get_available_bytes() < entries * ENTRY_BYTES:
		return false
	for _entry: int in entries:
		var block_index: int = input.get_u16()
		var id: int = input.get_u8()
		if block_index >= ChunkData.VOLUME:
			return false
		diffs.record(chunk_index, block_index, id)
	return true
