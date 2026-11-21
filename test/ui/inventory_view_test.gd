extends GdUnitTestSuite

var _view: InventoryView
var _inventory: Inventory


func before_test() -> void:
	var scene: PackedScene = load("res://src/game.tscn")
	var game: Node = auto_free(scene.instantiate())
	_view = game.get_node("InventoryLayer/Inventory")
	game.remove_child(_view.get_parent())
	add_child(_view.get_parent())
	_inventory = Inventory.new()
	_view.setup(_inventory)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_view.get_parent().queue_free()


func test_starts_hidden_and_keeps_running_while_paused() -> void:
	assert_bool(_view.visible).is_false()
	assert_int(_view.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_open_pauses_and_close_resumes() -> void:
	_view.open()
	assert_bool(get_tree().paused).is_true()

	_view.close()
	assert_bool(get_tree().paused).is_false()


func test_clicks_move_a_stack_between_slots() -> void:
	_inventory.add(BlockTable.LOG, 3)

	_view.click_slot(0)
	_view.click_slot(20)

	assert_int(_inventory.items[20]).is_equal(BlockTable.LOG)
	assert_int(_inventory.counts[20]).is_equal(3)


func test_closing_returns_the_held_stack() -> void:
	_inventory.add(BlockTable.LOG, 3)
	_view.open()
	_view.click_slot(0)

	_view.close()

	assert_int(_inventory.held_count).is_equal(0)
	assert_int(_inventory.count_of(BlockTable.LOG)).is_equal(3)


func test_recipes_are_available_only_with_their_ingredients() -> void:
	assert_bool(_view.is_recipe_available(0)).is_false()

	_inventory.add(BlockTable.LOG, 1)

	assert_bool(_view.is_recipe_available(0)).is_true()
	assert_bool(_view.craft(0)).is_true()
	assert_int(_inventory.count_of(BlockTable.PLANKS)).is_equal(4)
	assert_bool(_view.is_recipe_available(0)).is_false()
