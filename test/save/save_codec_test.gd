extends GdUnitTestSuite


func _sample() -> WorldSave:
	var state: WorldSave = WorldSave.new()
	state.world_seed = -987654321012
	state.chunks_per_side = 2
	state.blocks.resize(4 * ChunkData.VOLUME)
	state.blocks[0] = BlockTable.STONE
	state.blocks[ChunkData.VOLUME - 1] = BlockTable.GLASS
	state.blocks[state.blocks.size() - 1] = BlockTable.PLANKS
	state.has_player_position = true
	state.player_position = Vector3(128.5, 27.25, 3.75)
	return state


func _section(tag: String, content: PackedByteArray) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveCodec.SECTION_HEADER_BYTES)
	bytes.encode_u32(0, SaveCodec.tag_value(tag))
	bytes.encode_u32(4, content.size())
	bytes.append_array(content)
	return bytes


func test_round_trip_keeps_every_field() -> void:
	var decoded: WorldSave = SaveCodec.decode(SaveCodec.encode(_sample()))

	assert_int(decoded.source_version).is_equal(SaveCodec.VERSION)
	assert_int(decoded.world_seed).is_equal(-987654321012)
	assert_int(decoded.chunks_per_side).is_equal(2)
	assert_bool(decoded.blocks == _sample().blocks).is_true()
	assert_bool(decoded.has_player_position).is_true()
	assert_vector(decoded.player_position).is_equal(Vector3(128.5, 27.25, 3.75))


func test_file_starts_with_the_version_number() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())

	assert_int(bytes.decode_u32(0)).is_equal(SaveCodec.VERSION)


func test_blocks_are_compressed() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())

	assert_int(bytes.size()).is_less(_sample().blocks.size() >> 7)


func test_save_without_player_section_has_no_position() -> void:
	var state: WorldSave = _sample()
	state.has_player_position = false

	assert_bool(SaveCodec.decode(SaveCodec.encode(state)).has_player_position).is_false()


func test_unknown_sections_are_skipped() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_sample())
	var with_extra: PackedByteArray = bytes.slice(0, SaveCodec.VERSION_BYTES)
	with_extra.append_array(_section("ZZZZ", PackedByteArray([1, 2, 3])))
	with_extra.append_array(bytes.slice(SaveCodec.VERSION_BYTES))

	var decoded: WorldSave = SaveCodec.decode(with_extra)

	assert_object(decoded).is_not_null()
	assert_bool(decoded.blocks == _sample().blocks).is_true()


func test_save_without_world_section_is_rejected() -> void:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveCodec.VERSION_BYTES)
	bytes.encode_u32(0, SaveCodec.VERSION)
	bytes.append_array(_section(SaveCodec.TAG_PLAYER, SaveCodec.encode(_sample()).slice(12, 24)))

	assert_object(SaveCodec.decode(bytes)).is_null()


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


func test_blocks_of_the_wrong_size_are_rejected() -> void:
	var state: WorldSave = _sample()
	state.chunks_per_side = 3

	assert_object(SaveCodec.decode(SaveCodec.encode(state))).is_null()


func test_non_finite_position_is_rejected() -> void:
	var state: WorldSave = _sample()
	state.player_position = Vector3(INF, 0.0, 0.0)

	assert_object(SaveCodec.decode(SaveCodec.encode(state))).is_null()


func _survival_sample() -> WorldSave:
	var state: WorldSave = _sample()
	state.survival = true
	state.health = 7
	state.inventory_items.resize(Inventory.SLOTS)
	state.inventory_counts.resize(Inventory.SLOTS)
	state.inventory_items[3] = ItemTable.WOODEN_PICKAXE
	state.inventory_counts[3] = 1
	state.inventory_items[31] = BlockTable.SAND
	state.inventory_counts[31] = 64
	return state


func test_survival_round_trip_keeps_health_and_inventory() -> void:
	var decoded: WorldSave = SaveCodec.decode(SaveCodec.encode(_survival_sample()))

	assert_bool(decoded.survival).is_true()
	assert_int(decoded.health).is_equal(7)
	assert_array(decoded.inventory_items).is_equal(_survival_sample().inventory_items)
	assert_array(decoded.inventory_counts).is_equal(_survival_sample().inventory_counts)


func test_new_survival_world_saves_an_empty_inventory() -> void:
	var state: WorldSave = _sample()
	state.survival = true

	var decoded: WorldSave = SaveCodec.decode(SaveCodec.encode(state))

	assert_int(decoded.inventory_items.size()).is_equal(Inventory.SLOTS)
	assert_bool(Inventory.new().load_slots(decoded.inventory_items, decoded.inventory_counts)).is_true()


func test_creative_save_has_no_survival_section() -> void:
	var decoded: WorldSave = SaveCodec.decode(SaveCodec.encode(_sample()))

	assert_bool(decoded.survival).is_false()


func test_invalid_inventory_is_rejected() -> void:
	var state: WorldSave = _survival_sample()
	state.inventory_counts[3] = 2

	assert_object(SaveCodec.decode(SaveCodec.encode(state))).is_null()


func test_dead_or_overflowing_health_is_rejected() -> void:
	for health: int in [0, Health.MAX + 1]:
		var state: WorldSave = _survival_sample()
		state.health = health

		assert_object(SaveCodec.decode(SaveCodec.encode(state))).is_null()


func test_every_truncated_survival_file_is_rejected() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(_survival_sample())

	for length: int in bytes.size():
		assert_object(SaveCodec.decode(bytes.slice(0, length))).is_null()


func test_seed_from_text() -> void:
	assert_int(WorldSave.seed_from_text(" 123 ")).is_equal(123)
	assert_int(WorldSave.seed_from_text("ciao")).is_equal("ciao".hash())
