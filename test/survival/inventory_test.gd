extends GdUnitTestSuite


func test_starts_empty() -> void:
	var inventory: Inventory = Inventory.new()

	assert_int(inventory.count_of(BlockTable.DIRT)).is_equal(0)
	assert_int(inventory.space_for(BlockTable.DIRT)).is_equal(Inventory.SLOTS * 64)


func test_adding_fills_the_same_stack_before_an_empty_slot() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.DIRT, 10)
	inventory.add(BlockTable.STONE, 1)

	inventory.add(BlockTable.DIRT, 5)

	assert_int(inventory.counts[0]).is_equal(15)
	assert_int(inventory.items[1]).is_equal(BlockTable.STONE)
	assert_int(inventory.items[2]).is_equal(ItemTable.NONE)


func test_full_stack_overflows_into_the_first_empty_slot() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.DIRT, 60)
	inventory.add(BlockTable.SAND, 1)

	assert_int(inventory.add(BlockTable.DIRT, 10)).is_equal(10)

	assert_int(inventory.counts[0]).is_equal(64)
	assert_int(inventory.items[2]).is_equal(BlockTable.DIRT)
	assert_int(inventory.counts[2]).is_equal(6)


func test_what_does_not_fit_is_lost() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.STONE, Inventory.SLOTS * 64 - 3)

	assert_int(inventory.add(BlockTable.STONE, 5)).is_equal(3)
	assert_int(inventory.add(BlockTable.DIRT, 1)).is_equal(0)
	assert_int(inventory.count_of(BlockTable.STONE)).is_equal(Inventory.SLOTS * 64)


func test_tools_take_one_slot_each() -> void:
	var inventory: Inventory = Inventory.new()

	inventory.add(ItemTable.WOODEN_PICKAXE, 2)

	assert_int(inventory.counts[0]).is_equal(1)
	assert_int(inventory.counts[1]).is_equal(1)


func test_remove_takes_from_several_slots_or_nothing() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.PLANKS, 70)

	assert_bool(inventory.remove(BlockTable.PLANKS, 80)).is_false()
	assert_int(inventory.count_of(BlockTable.PLANKS)).is_equal(70)
	assert_bool(inventory.remove(BlockTable.PLANKS, 66)).is_true()
	assert_int(inventory.count_of(BlockTable.PLANKS)).is_equal(4)


func test_taking_the_last_item_empties_the_slot() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.SAND, 1)

	inventory.take_one(0)

	assert_int(inventory.items[0]).is_equal(ItemTable.NONE)
	assert_int(inventory.counts[0]).is_equal(0)


func test_click_picks_up_and_puts_down() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.LOG, 3)

	inventory.click(0)
	assert_int(inventory.held_item).is_equal(BlockTable.LOG)
	assert_int(inventory.held_count).is_equal(3)
	assert_int(inventory.items[0]).is_equal(ItemTable.NONE)

	inventory.click(12)
	assert_int(inventory.items[12]).is_equal(BlockTable.LOG)
	assert_int(inventory.held_count).is_equal(0)


func test_click_merges_the_same_item_up_to_the_limit() -> void:
	var inventory: Inventory = Inventory.new()
	var items: PackedInt32Array = PackedInt32Array()
	var counts: PackedInt32Array = PackedInt32Array()
	items.resize(Inventory.SLOTS)
	counts.resize(Inventory.SLOTS)
	items[0] = BlockTable.DIRT
	counts[0] = 40
	items[1] = BlockTable.DIRT
	counts[1] = 50
	assert_bool(inventory.load_slots(items, counts)).is_true()

	inventory.click(0)
	inventory.click(1)

	assert_int(inventory.counts[1]).is_equal(64)
	assert_int(inventory.held_item).is_equal(BlockTable.DIRT)
	assert_int(inventory.held_count).is_equal(26)


func test_click_swaps_a_different_item() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.DIRT, 2)
	inventory.add(BlockTable.SAND, 7)

	inventory.click(0)
	inventory.click(1)

	assert_int(inventory.items[1]).is_equal(BlockTable.DIRT)
	assert_int(inventory.held_item).is_equal(BlockTable.SAND)
	assert_int(inventory.held_count).is_equal(7)


func test_held_stack_goes_back_when_the_screen_closes() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.GLASS, 5)
	inventory.click(0)

	inventory.return_held()

	assert_int(inventory.held_count).is_equal(0)
	assert_int(inventory.count_of(BlockTable.GLASS)).is_equal(5)


func test_invalid_saved_slots_are_refused() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.DIRT, 1)
	var items: PackedInt32Array = PackedInt32Array()
	var counts: PackedInt32Array = PackedInt32Array()
	items.resize(Inventory.SLOTS)
	counts.resize(Inventory.SLOTS)
	items[0] = ItemTable.STONE_PICKAXE
	counts[0] = 2

	assert_bool(inventory.load_slots(items, counts)).is_false()
	assert_int(inventory.items[0]).is_equal(BlockTable.DIRT)


func test_changes_are_signalled() -> void:
	var inventory: Inventory = Inventory.new()
	var changes: Array[int] = []
	inventory.changed.connect(func() -> void: changes.append(1))

	inventory.add(BlockTable.DIRT, 1)
	inventory.add(BlockTable.DIRT, 0)

	assert_array(changes).is_equal([1] as Array[int])

