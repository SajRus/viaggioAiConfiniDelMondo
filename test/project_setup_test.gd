extends GdUnitTestSuite

const WARNING_LEVEL_ERROR: int = 2


func test_engine_is_godot_4_7() -> void:
	var version: Dictionary = Engine.get_version_info()

	assert_int(version["major"]).is_equal(4)
	assert_int(version["minor"]).is_equal(7)


func test_renderer_is_forward_plus() -> void:
	var renderer: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")

	assert_str(renderer).is_equal("forward_plus")


func test_untyped_declaration_is_an_error() -> void:
	var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration")

	assert_int(level).is_equal(WARNING_LEVEL_ERROR)
