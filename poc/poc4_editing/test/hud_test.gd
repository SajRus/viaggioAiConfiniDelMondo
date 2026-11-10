extends GdUnitTestSuite


# With a captured mouse the pointer sits at the screen center: a control there
# that accepts the mouse would swallow every look and click event.
func test_hud_never_intercepts_the_mouse() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var main: Node = auto_free(scene.instantiate())

	for child: Node in main.get_node("Hud").get_children():
		var control: Control = child as Control
		assert_int(control.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
