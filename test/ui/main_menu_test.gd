extends GdUnitTestSuite

const TEST_PATH: String = "user://gdunit_main_menu.sav"


func before_test() -> void:
	SaveSystem.save_path = TEST_PATH
	_delete_save()


func after_test() -> void:
	_delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_SAVE_PATH


func _delete_save() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _open_menu() -> MainMenu:
	var scene: PackedScene = load("res://src/ui/main_menu.tscn")
	var menu: MainMenu = auto_free(scene.instantiate())
	add_child(menu)
	return menu


func test_load_is_disabled_without_a_save() -> void:
	var button: Button = _open_menu().get_node("%Load")

	assert_bool(button.disabled).is_true()


func test_load_is_enabled_with_a_save() -> void:
	SaveSystem.write(WorldSave.new())

	var button: Button = _open_menu().get_node("%Load")

	assert_bool(button.disabled).is_false()


func test_corrupted_save_shows_a_message_and_stays_in_the_menu() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("rotto")
	file.close()
	var menu: MainMenu = _open_menu()
	var button: Button = menu.get_node("%Load")
	var status: Label = menu.get_node("%Status")

	button.pressed.emit()

	assert_str(status.text).is_not_empty()
	assert_object(get_tree().current_scene).is_not_instanceof(Node3D)
