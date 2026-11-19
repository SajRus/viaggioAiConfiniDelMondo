extends GdUnitTestSuite

## Saves written by earlier versions of the game must load forever.


func _load_world(state: WorldSave) -> World:
	var world: World = auto_free(World.new())
	world.chunk_material = StandardMaterial3D.new()
	add_child(world)
	world.start_generation(state.world_seed, state.blocks, state.diffs)
	await world.loaded
	return world


func test_terrain_generator_still_matches_version_1_saves() -> void:
	# If this fails the generator changed: keep a copy of the old one to load
	# version 1 saves, as "Salvataggio" in docs/analisi-progettazione.md says.
	var data: WorldData = WorldData.new(16, 16)
	var generator: TerrainGenerator = TerrainGenerator.new(SaveFixtures.WORLD_SEED)
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
