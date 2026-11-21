extends GdUnitTestSuite

## Saves written by earlier versions of the game must load forever.


func _load_world(state: WorldSave) -> World:
	var world: World = auto_free(World.new())
	world.chunk_material = StandardMaterial3D.new()
	add_child(world)
	world.start_generation(state.world_seed, state.blocks, state.diffs, TerrainGenerator.VERSION_MVP)
	await world.loaded
	return world


func test_terrain_generator_still_matches_version_1_saves() -> void:
	# If this fails the MVP terrain changed: version 1 saves would come back on a
	# different ground. Changes go into a new terrain version instead.
	var data: WorldData = WorldData.new(16, 16)
	var generator: TerrainGenerator = TerrainGenerator.new(SaveFixtures.WORLD_SEED, TerrainGenerator.VERSION_MVP)
	for index: int in data.chunks.size():
		var coords: Vector2i = data.coords_of(index)
		generator.fill_chunk(data.chunks[index], coords.x, coords.y)

	assert_str(SaveFixtures.sha256(data.to_bytes())).is_equal(SaveFixtures.V1_TERRAIN_SHA256)


func test_version_1_save_is_read() -> void:
	var state: WorldSave = SaveCodec.decode(FileAccess.get_file_as_bytes(SaveFixtures.V1))

	assert_int(state.source_version).is_equal(1)
	assert_int(state.world_seed).is_equal(SaveFixtures.WORLD_SEED)
	assert_vector(state.player_position).is_equal(SaveFixtures.PLAYER_POSITION)
	assert_int(state.diffs.block_count()).is_equal(SaveFixtures.V1_EDITS)
	assert_bool(state.blocks.is_empty()).is_true()


func test_version_1_save_rebuilds_the_saved_world() -> void:
	var state: WorldSave = SaveCodec.decode(FileAccess.get_file_as_bytes(SaveFixtures.V1))

	var world: World = await _load_world(state)

	assert_str(SaveFixtures.sha256(world.data.to_bytes())).is_equal(SaveFixtures.WORLD_SHA256)


func test_version_2_save_loads_the_same_world() -> void:
	var state: WorldSave = SaveCodec.decode(FileAccess.get_file_as_bytes(SaveFixtures.V2))

	assert_int(state.source_version).is_equal(2)
	assert_int(state.world_seed).is_equal(SaveFixtures.WORLD_SEED)
	assert_vector(state.player_position).is_equal(SaveFixtures.PLAYER_POSITION)
	var world: World = await _load_world(state)
	assert_str(SaveFixtures.sha256(world.data.to_bytes())).is_equal(SaveFixtures.WORLD_SHA256)


func test_saves_without_survival_section_load_as_creative() -> void:
	for path: String in [SaveFixtures.V1, SaveFixtures.V2]:
		var state: WorldSave = SaveCodec.decode(FileAccess.get_file_as_bytes(path))

		assert_bool(state.survival).is_false()


func test_version_2_survival_save_keeps_health_and_inventory() -> void:
	var state: WorldSave = SaveCodec.decode(FileAccess.get_file_as_bytes(SaveFixtures.V2_SURVIVAL))

	assert_bool(state.survival).is_true()
	assert_int(state.health).is_equal(13)
	var inventory: Inventory = Inventory.new()
	assert_bool(inventory.load_slots(state.inventory_items, state.inventory_counts)).is_true()
	assert_int(inventory.items[0]).is_equal(ItemTable.STONE_PICKAXE)
	assert_int(inventory.count_of(BlockTable.DIRT)).is_equal(64)
	assert_int(inventory.counts[7]).is_equal(9)
	assert_int(inventory.items[31]).is_equal(BlockTable.GLASS)
	assert_int(inventory.counts[31]).is_equal(2)
	assert_str(SaveFixtures.sha256(state.blocks)).is_equal(SaveFixtures.WORLD_SHA256)
