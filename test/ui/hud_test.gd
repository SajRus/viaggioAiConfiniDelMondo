extends GdUnitTestSuite

const MAIN_SCENE: String = "res://src/game.tscn"


func _assert_ignores_mouse(root: Node) -> void:
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control != null:
			assert_int(control.mouse_filter).override_failure_message(
				"%s accepts the mouse" % control.name
			).is_equal(Control.MOUSE_FILTER_IGNORE)
		_assert_ignores_mouse(child)


# With a captured mouse the pointer sits at the screen center: a control there
# that accepts the mouse would swallow every look and click event.
func test_hud_scene_never_intercepts_the_mouse() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	var main: Node = auto_free(scene.instantiate())
	var view: HotbarView = main.get_node("Hud/Hotbar")

	view.setup(Hotbar.new())

	_assert_ignores_mouse(main.get_node("Hud"))
	assert_int(view.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_hotbar_view_highlights_the_selected_slot() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	var main: Node = auto_free(scene.instantiate())
	var view: HotbarView = main.get_node("Hud/Hotbar")
	var hotbar: Hotbar = Hotbar.new()
	view.setup(hotbar)

	hotbar.select(4)

	var selected: ColorRect = view.get_child(4)
	var idle: ColorRect = view.get_child(0)
	assert_object(selected.color).is_equal(HotbarView.COLOR_SELECTED)
	assert_object(idle.color).is_equal(HotbarView.COLOR_IDLE)


func test_survival_hotbar_shows_the_inventory_and_its_counts() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	var main: Node = auto_free(scene.instantiate())
	var view: HotbarView = main.get_node("Hud/Hotbar")
	var inventory: Inventory = Inventory.new()
	view.setup(Hotbar.new(), inventory)

	inventory.add(BlockTable.DIRT, 12)
	inventory.add(ItemTable.WOODEN_PICKAXE, 1)

	assert_str(view.count_text(0)).is_equal("12")
	assert_str(view.count_text(1)).is_equal("")
	assert_str(view.count_text(2)).is_equal("")
	_assert_ignores_mouse(main.get_node("Hud"))


func test_health_bar_ignores_the_mouse_and_shows_the_points() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	var main: Node = auto_free(scene.instantiate())
	var view: HealthView = main.get_node("Hud/Health")
	main.remove_child(view.get_parent())
	add_child(view.get_parent())
	var health: Health = Health.new()
	view.setup(health)

	health.damage(4)

	assert_str(view.label_text()).is_equal("Salute 16/20")
	assert_int(view.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_assert_ignores_mouse(view)
	view.get_parent().queue_free()
