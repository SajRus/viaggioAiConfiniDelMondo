extends GdUnitTestSuite

const TEST_PATH: String = "user://gdunit_save_system.sav"


func before_test() -> void:
	SaveSystem.save_path = TEST_PATH
	_delete_files()


func after_test() -> void:
	_delete_files()
	SaveSystem.save_path = SaveSystem.DEFAULT_SAVE_PATH


func _delete_files() -> void:
	for path: String in [TEST_PATH, TEST_PATH + SaveSystem.TEMPORARY_SUFFIX, SaveSystem.backup_path(1)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _state(world_seed: int) -> WorldSave:
	var state: WorldSave = WorldSave.new()
	state.world_seed = world_seed
	state.chunks_per_side = 1
	state.blocks.resize(ChunkData.VOLUME)
	state.blocks[40] = BlockTable.SAND
	return state


func test_missing_file_reads_as_no_save() -> void:
	assert_bool(SaveSystem.has_save()).is_false()
	assert_object(SaveSystem.read()).is_null()


func test_written_save_can_be_read_back() -> void:
	assert_bool(SaveSystem.write(_state(77))).is_true()

	assert_bool(SaveSystem.has_save()).is_true()
	assert_int(SaveSystem.read().world_seed).is_equal(77)
	assert_int(SaveSystem.read().blocks[40]).is_equal(BlockTable.SAND)


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


func test_save_path_never_changes() -> void:
	# Players' saves live here: a new path would make them disappear.
	assert_str(SaveSystem.DEFAULT_SAVE_PATH).is_equal("user://world.sav")
	assert_str(OS.get_user_data_dir()).ends_with("app_userdata/Viaggio ai confini del mondo")


func test_reading_an_older_version_keeps_a_backup_first() -> void:
	var original: PackedByteArray = FileAccess.get_file_as_bytes(SaveFixtures.V1)
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_buffer(original)
	file.close()

	assert_int(SaveSystem.read().source_version).is_equal(1)
	SaveSystem.write(_state(9))

	assert_bool(FileAccess.get_file_as_bytes(SaveSystem.backup_path(1)) == original).is_true()
	assert_int(SaveSystem.read().source_version).is_equal(SaveCodec.VERSION)


func test_reading_the_current_version_keeps_no_backup() -> void:
	SaveSystem.write(_state(3))

	SaveSystem.read()

	assert_bool(FileAccess.file_exists(SaveSystem.backup_path(SaveCodec.VERSION))).is_false()


func test_requested_world_is_taken_only_once() -> void:
	var state: WorldSave = _state(5)
	SaveSystem.request_world(state)

	assert_object(SaveSystem.take_request()).is_same(state)
	assert_object(SaveSystem.take_request()).is_not_same(state)
