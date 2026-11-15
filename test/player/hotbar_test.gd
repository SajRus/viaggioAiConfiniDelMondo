extends GdUnitTestSuite


func test_hotbar_offers_the_eight_block_types() -> void:
	assert_int(Hotbar.BLOCKS.size()).is_equal(8)


func test_starts_on_the_first_slot() -> void:
	assert_int(Hotbar.new().selected_block()).is_equal(BlockTable.GRASS)


func test_select_changes_the_block() -> void:
	var hotbar: Hotbar = Hotbar.new()

	hotbar.select(7)

	assert_int(hotbar.selected_block()).is_equal(BlockTable.GLASS)


func test_select_ignores_missing_slots() -> void:
	var hotbar: Hotbar = Hotbar.new()
	hotbar.select(2)

	hotbar.select(8)
	hotbar.select(-1)

	assert_int(hotbar.selected_index).is_equal(2)


func test_scroll_wraps_at_both_ends() -> void:
	var hotbar: Hotbar = Hotbar.new()

	hotbar.scroll(-1)
	assert_int(hotbar.selected_index).is_equal(7)

	hotbar.scroll(1)
	assert_int(hotbar.selected_index).is_equal(0)


func test_change_is_signalled_once() -> void:
	var hotbar: Hotbar = Hotbar.new()
	var received: Array[int] = []
	hotbar.selection_changed.connect(func(index: int) -> void: received.append(index))

	hotbar.select(3)
	hotbar.select(3)

	assert_array(received).is_equal([3] as Array[int])
