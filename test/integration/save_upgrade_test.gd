extends GdUnitTestSuite

const GAME_SCENE: String = "res://src/game.tscn"
const TEST_PATH: String = "user://gdunit_save_upgrade.sav"


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


func test_loading_a_version_1_save_rewrites_it_in_the_current_version() -> void:
	var original: PackedByteArray = FileAccess.get_file_as_bytes(SaveFixtures.V1)
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	SaveSystem.request_world(SaveSystem.read())

	var runner: GdUnitSceneRunner = scene_runner(GAME_SCENE)
	var world: World = runner.scene().get_node("World")
	while not world.is_ready_to_play():
		await get_tree().process_frame

	var saved: WorldSave = SaveSystem.read()
	assert_int(saved.source_version).is_equal(SaveCodec.VERSION)
	assert_str(SaveFixtures.sha256(saved.blocks)).is_equal(SaveFixtures.WORLD_SHA256)
	assert_bool(FileAccess.get_file_as_bytes(SaveSystem.backup_path(1)) == original).is_true()
