extends GdUnitTestSuite

const TEST_PATH: String = "user://gdunit_save_system.sav"


func before_test() -> void:
	SaveSystem.save_path = TEST_PATH
	_delete_files()


func after_test() -> void:
	_delete_files()
	SaveSystem.save_path = SaveSystem.DEFAULT_SAVE_PATH


func _delete_files() -> void:
	for path: String in [TEST_PATH, TEST_PATH + SaveSystem.TEMPORARY_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _state(world_seed: int) -> WorldSave:
	var state: WorldSave = WorldSave.new()
	state.world_seed = world_seed
	state.player_position = Vector3(1.0, 2.0, 3.0)
	state.diffs.record(3, 40, BlockTable.SAND)
	return state


func test_missing_file_reads_as_no_save() -> void:
	assert_bool(SaveSystem.has_save()).is_false()
	assert_object(SaveSystem.read()).is_null()


func test_written_save_can_be_read_back() -> void:
	assert_bool(SaveSystem.write(_state(77))).is_true()

	assert_bool(SaveSystem.has_save()).is_true()
	assert_int(SaveSystem.read().world_seed).is_equal(77)
	assert_int(SaveSystem.read().diffs.entries_of(3)[40]).is_equal(BlockTable.SAND)


func test_new_save_replaces_the_old_one_and_leaves_no_temporary_file() -> void:
	SaveSystem.write(_state(1))
	SaveSystem.write(_state(2))

	assert_int(SaveSystem.read().world_seed).is_equal(2)
	assert_bool(FileAccess.file_exists(TEST_PATH + SaveSystem.TEMPORARY_SUFFIX)).is_false()


func test_corrupted_file_reads_as_null() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("non e un salvataggio")
	file.close()

	assert_object(SaveSystem.read()).is_null()


func test_requested_world_is_taken_only_once() -> void:
	var state: WorldSave = _state(5)
	SaveSystem.request_world(state)

	assert_object(SaveSystem.take_request()).is_same(state)
	assert_object(SaveSystem.take_request()).is_not_same(state)
