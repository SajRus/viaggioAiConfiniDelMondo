extends GdUnitTestSuite

const TEST_PATH: String = "user://gdunit_world_reload.sav"
const SEED: int = 4242


func before_test() -> void:
	SaveSystem.save_path = TEST_PATH


func after_test() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveSystem.save_path = SaveSystem.DEFAULT_SAVE_PATH


func _new_world(diffs: BlockDiffLog) -> World:
	var world: World = auto_free(World.new())
	world.chunks_per_side = 2
	world.chunk_material = StandardMaterial3D.new()
	add_child(world)
	world.start_generation(SEED, diffs)
	await world.loaded
	return world


func _build_house(world: World) -> void:
	for x: int in range(13, 20):
		var surface: int = world.data.surface_height(x, 16)
		world.manager.set_block(x, surface + 1, 16, BlockTable.PLANKS)
		world.manager.set_block(x, surface + 2, 16, BlockTable.GLASS)
		world.manager.set_block(x, surface, 15, BlockTable.AIR)
	world.manager.set_block(5, 0, 5, BlockTable.AIR)
	world.manager.set_block(31, 63, 31, BlockTable.LOG)
	world.manager.flush()


func test_saved_world_comes_back_identical() -> void:
	var original: World = await _new_world(BlockDiffLog.new())
	_build_house(original)
	var state: WorldSave = WorldSave.new()
	state.world_seed = SEED
	state.player_position = Vector3(16.5, 40.0, 16.5)
	state.diffs = original.manager.diffs
	assert_bool(SaveSystem.write(state)).is_true()

	var loaded_state: WorldSave = SaveSystem.read()
	var reloaded: World = await _new_world(loaded_state.diffs)

	for index: int in 4:
		assert_bool(reloaded.data.chunks[index].blocks == original.data.chunks[index].blocks).is_true()
	assert_vector(loaded_state.player_position).is_equal(Vector3(16.5, 40.0, 16.5))


func test_reloaded_meshes_match_an_independent_count() -> void:
	var original: World = await _new_world(BlockDiffLog.new())
	_build_house(original)

	var reloaded: World = await _new_world(SaveCodec.decode(_encoded(original)).diffs)

	var built: int = 0
	for node: ChunkNode in reloaded.chunk_nodes():
		built += node.face_count
	assert_int(built).is_equal(VoxelAudit.expected_face_count(reloaded.data, BlockRegistry))


func test_edits_after_a_reload_are_saved_too() -> void:
	var original: World = await _new_world(BlockDiffLog.new())
	_build_house(original)
	var reloaded: World = await _new_world(SaveCodec.decode(_encoded(original)).diffs)
	var count_before: int = reloaded.manager.diffs.block_count()

	reloaded.manager.set_block(2, 62, 2, BlockTable.SAND)

	assert_int(reloaded.manager.diffs.block_count()).is_equal(count_before + 1)
	var again: WorldSave = SaveCodec.decode(_encoded(reloaded))
	assert_int(again.diffs.block_count()).is_equal(count_before + 1)


func _encoded(world: World) -> PackedByteArray:
	var state: WorldSave = WorldSave.new()
	state.world_seed = SEED
	state.diffs = world.manager.diffs
	return SaveCodec.encode(state)
