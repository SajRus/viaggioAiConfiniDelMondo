class_name SaveCodec
extends RefCounted

## Every version stays readable: see "Salvataggio" in docs/analisi-progettazione.md.
const VERSION: int = 2
const VERSION_BYTES: int = 4

# Version 2: the version, then sections of tag u32, length u32 and content.
const SECTION_HEADER_BYTES: int = 8
const TAG_PLAYER: String = "PLYR"
const TAG_WORLD: String = "WRLD"
const PLAYER_BYTES: int = 12
const WORLD_HEADER_BYTES: int = 10
const COMPRESSION: FileAccess.CompressionMode = FileAccess.COMPRESSION_ZSTD
const MAX_CHUNKS_PER_SIDE: int = 64

# Version 1: seed, position, then groups of modified blocks.
const V1_HEADER_BYTES: int = 28
const V1_GROUP_HEADER_BYTES: int = 8
const V1_ENTRY_BYTES: int = 3


## Writes [member WorldSave.blocks] in full. The world section comes last, so a
## file cut at any point is missing it and gets rejected.
static func encode(state: WorldSave) -> PackedByteArray:
	var output: StreamPeerBuffer = StreamPeerBuffer.new()
	output.put_u32(VERSION)
	if state.has_player_position:
		var player: StreamPeerBuffer = StreamPeerBuffer.new()
		player.put_float(state.player_position.x)
		player.put_float(state.player_position.y)
		player.put_float(state.player_position.z)
		_put_section(output, TAG_PLAYER, player.data_array)
	var world: StreamPeerBuffer = StreamPeerBuffer.new()
	world.put_64(state.world_seed)
	world.put_u16(state.chunks_per_side)
	world.put_data(state.blocks.compress(COMPRESSION))
	_put_section(output, TAG_WORLD, world.data_array)
	return output.data_array


## Returns null when the bytes are not a complete save of a known version.
static func decode(bytes: PackedByteArray) -> WorldSave:
	if bytes.size() < VERSION_BYTES:
		return null
	var input: StreamPeerBuffer = StreamPeerBuffer.new()
	input.data_array = bytes
	var version: int = input.get_u32()
	var state: WorldSave = null
	if version == 1:
		state = _decode_v1(input)
	elif version == 2:
		state = _decode_v2(input)
	if state != null:
		state.source_version = version
	return state


static func tag_value(tag: String) -> int:
	return tag.to_ascii_buffer().decode_u32(0)


static func _put_section(output: StreamPeerBuffer, tag: String, content: PackedByteArray) -> void:
	output.put_u32(tag_value(tag))
	output.put_u32(content.size())
	output.put_data(content)


## Unknown sections are skipped: a later version may add them.
static func _decode_v2(input: StreamPeerBuffer) -> WorldSave:
	var state: WorldSave = WorldSave.new()
	var has_world: bool = false
	while input.get_available_bytes() > 0:
		if input.get_available_bytes() < SECTION_HEADER_BYTES:
			return null
		var tag: int = input.get_u32()
		var length: int = input.get_u32()
		if input.get_available_bytes() < length:
			return null
		var content: PackedByteArray = input.get_data(length)[1]
		if tag == tag_value(TAG_PLAYER):
			if not _read_player(content, state):
				return null
		elif tag == tag_value(TAG_WORLD):
			if not _read_world(content, state):
				return null
			has_world = true
	return state if has_world else null


static func _read_player(content: PackedByteArray, state: WorldSave) -> bool:
	if content.size() != PLAYER_BYTES:
		return false
	state.player_position = Vector3(content.decode_float(0), content.decode_float(4), content.decode_float(8))
	state.has_player_position = true
	return state.player_position.is_finite()


static func _read_world(content: PackedByteArray, state: WorldSave) -> bool:
	if content.size() < WORLD_HEADER_BYTES:
		return false
	state.world_seed = content.decode_s64(0)
	state.chunks_per_side = content.decode_u16(8)
	if state.chunks_per_side < 1 or state.chunks_per_side > MAX_CHUNKS_PER_SIDE:
		return false
	var volume: int = state.chunks_per_side * state.chunks_per_side * ChunkData.VOLUME
	state.blocks = content.slice(WORLD_HEADER_BYTES).decompress(volume, COMPRESSION)
	return state.blocks.size() == volume


## Version 1 kept only the edits: the terrain comes back from the seed.
static func _decode_v1(input: StreamPeerBuffer) -> WorldSave:
	if input.get_available_bytes() < V1_HEADER_BYTES - VERSION_BYTES:
		return null
	var state: WorldSave = WorldSave.new()
	state.world_seed = input.get_64()
	state.player_position = Vector3(input.get_float(), input.get_float(), input.get_float())
	state.has_player_position = true
	if not state.player_position.is_finite():
		return null
	var groups: int = input.get_u32()
	for _group: int in groups:
		if not _read_v1_group(input, state.diffs):
			return null
	return state if input.get_available_bytes() == 0 else null


static func _read_v1_group(input: StreamPeerBuffer, diffs: BlockDiffLog) -> bool:
	if input.get_available_bytes() < V1_GROUP_HEADER_BYTES:
		return false
	var chunk_index: int = input.get_u32()
	var entries: int = input.get_u32()
	if input.get_available_bytes() < entries * V1_ENTRY_BYTES:
		return false
	for _entry: int in entries:
		var block_index: int = input.get_u16()
		var id: int = input.get_u8()
		if block_index >= ChunkData.VOLUME:
			return false
		diffs.record(chunk_index, block_index, id)
	return true
