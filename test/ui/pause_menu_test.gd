extends GdUnitTestSuite

var _menu: PauseMenu


func before_test() -> void:
	var scene: PackedScene = load("res://src/ui/pause_menu.tscn")
	_menu = auto_free(scene.instantiate())
	add_child(_menu)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_starts_hidden_and_keeps_running_while_paused() -> void:
	assert_bool(_menu.visible).is_false()
	assert_int(_menu.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_open_pauses_the_game() -> void:
	_menu.open()

	assert_bool(_menu.visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_close_resumes_the_game() -> void:
	_menu.open()

	_menu.close()

	assert_bool(_menu.visible).is_false()
	assert_bool(get_tree().paused).is_false()


func test_buttons_emit_their_requests() -> void:
	var seen: Array[String] = []
	_menu.save_requested.connect(func() -> void: seen.append("save"))
	_menu.main_menu_requested.connect(func() -> void: seen.append("menu"))
	_menu.quit_requested.connect(func() -> void: seen.append("quit"))
	var save: Button = _menu.get_node("%Save")
	var main_menu: Button = _menu.get_node("%MainMenu")
	var quit: Button = _menu.get_node("%Quit")

	save.pressed.emit()
	main_menu.pressed.emit()
	quit.pressed.emit()

	assert_array(seen).is_equal(["save", "menu", "quit"] as Array[String])


func test_resume_button_closes_the_menu() -> void:
	_menu.open()
	var resume: Button = _menu.get_node("%Resume")

	resume.pressed.emit()

	assert_bool(_menu.visible).is_false()


func test_status_is_cleared_when_reopened() -> void:
	_menu.show_status("Partita salvata")

	_menu.open()

	var status: Label = _menu.get_node("%Status")
	assert_str(status.text).is_empty()


func test_buttons_do_not_take_keyboard_focus() -> void:
	for path: String in ["%Resume", "%Save", "%MainMenu", "%Quit"]:
		var button: Button = _menu.get_node(path)
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)
