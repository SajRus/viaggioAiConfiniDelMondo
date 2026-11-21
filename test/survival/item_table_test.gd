extends GdUnitTestSuite


func test_item_ids_never_change() -> void:
	# Saves store these numbers: a new item takes a free ID instead.
	assert_int(ItemTable.NONE).is_equal(0)
	assert_int(ItemTable.WOODEN_PICKAXE).is_equal(256)
	assert_int(ItemTable.STONE_PICKAXE).is_equal(257)


func test_blocks_and_tools_are_items() -> void:
	for block: int in Hotbar.BLOCKS:
		assert_bool(ItemTable.is_block(block)).is_true()
	assert_bool(ItemTable.is_block(BlockTable.AIR)).is_false()
	assert_bool(ItemTable.is_tool_item(ItemTable.WOODEN_PICKAXE)).is_true()
	assert_bool(ItemTable.is_known_item(258)).is_false()


func test_tools_do_not_stack() -> void:
	assert_int(ItemTable.stack_limit(ItemTable.STONE_PICKAXE)).is_equal(1)
	assert_int(ItemTable.stack_limit(BlockTable.STONE)).is_equal(64)


func test_grass_drops_dirt_and_leaves_and_glass_drop_nothing() -> void:
	assert_int(ItemTable.drop_of(BlockTable.GRASS)).is_equal(BlockTable.DIRT)
	assert_int(ItemTable.drop_of(BlockTable.LEAVES)).is_equal(ItemTable.NONE)
	assert_int(ItemTable.drop_of(BlockTable.GLASS)).is_equal(ItemTable.NONE)
	assert_int(ItemTable.drop_of(BlockTable.STONE)).is_equal(BlockTable.STONE)


func test_break_times_follow_the_design_table() -> void:
	assert_float(ItemTable.break_seconds(BlockTable.LEAVES, ItemTable.NONE)).is_equal(0.3)
	assert_float(ItemTable.break_seconds(BlockTable.SAND, ItemTable.NONE)).is_equal(0.6)
	assert_float(ItemTable.break_seconds(BlockTable.LOG, ItemTable.STONE_PICKAXE)).is_equal(1.5)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, ItemTable.NONE)).is_equal(4.0)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, BlockTable.DIRT)).is_equal(4.0)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, ItemTable.WOODEN_PICKAXE)).is_equal(1.5)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, ItemTable.STONE_PICKAXE)).is_equal(0.8)


func test_every_item_has_a_name() -> void:
	for block: int in Hotbar.BLOCKS:
		assert_str(ItemTable.display_name(block)).is_not_empty()
	assert_str(ItemTable.display_name(ItemTable.STONE_PICKAXE)).is_equal("Piccone di pietra")
