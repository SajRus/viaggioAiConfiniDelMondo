extends GdUnitTestSuite


func _sample() -> WorldSave:
	var state: WorldSave = WorldSave.new()
	state.world_seed = -987654321012
	state.player_position = Vector3(128.5, 27.25, 3.75)
	state.diffs.record(0, 0, BlockTable.AIR)
	state.diffs.record(0, ChunkData.VOLUME - 1, BlockTable.GLASS)
	state.diffs.record(255, 300, BlockTable.PLANKS)
	return state


func test_round_trip_keeps_every_field() -> void:
	var decoded: WorldSave = SaveCodec.decode(SaveCodec.encode(_sample()))

	assert_int(decoded.world_seed).is_equal(-987654321012)
	assert_bool(decoded.has_player_position).is_true()
	assert_vector(decoded.player_position).is_equal(Vector3(128.5, 27.25, 3.75))
	assert_array(decoded.diffs.chunk_indices()).is_equal([0, 255] as Array[int])
	assert_int(decoded.diffs.entries_of(0)[ChunkData.VOLUME - 1]).is_equal(BlockTable.GLASS)
	assert_int(decoded.diffs.entries_of(255)[300]).is_equal(BlockTable.PLANKS)
	assert_int(decoded.diffs.block_count()).is_equal(3)


func test_file_starts_with_the_version_number() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())

	assert_int(bytes.decode_u32(0)).is_equal(SaveCodec.VERSION)


func test_size_depends_only_on_the_modified_blocks() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())

	assert_int(bytes.size()).is_equal(
		SaveCodec.HEADER_BYTES + 2 * SaveCodec.GROUP_HEADER_BYTES + 3 * SaveCodec.ENTRY_BYTES
	)


func test_unknown_version_is_rejected() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())
	bytes.encode_u32(0, SaveCodec.VERSION + 1)

	assert_object(SaveCodec.decode(bytes)).is_null()


func test_every_truncated_file_is_rejected() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())

	for length: int in bytes.size():
		assert_object(SaveCodec.decode(bytes.slice(0, length))).is_null()


func test_trailing_bytes_are_rejected() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())
	bytes.append(0)

	assert_object(SaveCodec.decode(bytes)).is_null()


func test_block_index_outside_the_chunk_is_rejected() -> void:
	var state: WorldSave = WorldSave.new()
	state.diffs.record(0, ChunkData.VOLUME, BlockTable.STONE)

	assert_object(SaveCodec.decode(SaveCodec.encode(state))).is_null()


func test_non_finite_position_is_rejected() -> void:
	var state: WorldSave = WorldSave.new()
	state.player_position = Vector3(INF, 0.0, 0.0)

	assert_object(SaveCodec.decode(SaveCodec.encode(state))).is_null()


func test_seed_from_text() -> void:
	assert_int(WorldSave.seed_from_text(" 123 ")).is_equal(123)
	assert_int(WorldSave.seed_from_text("ciao")).is_equal("ciao".hash())
