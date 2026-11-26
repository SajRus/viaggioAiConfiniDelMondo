extends GdUnitTestSuite


func test_item_ids_never_change() -> void:
	# Saves store these numbers: a new item takes a free ID instead.
	assert_int(ItemTable.NONE).is_equal(0)
	assert_int(ItemTable.WOODEN_PICKAXE).is_equal(256)
	assert_int(ItemTable.STONE_PICKAXE).is_equal(257)
	var gems: Array[int] = [
		ItemTable.RUBY, ItemTable.EMERALD, ItemTable.OBSIDIAN, ItemTable.GOLD,
		ItemTable.DIAMOND, ItemTable.AMETHYST, ItemTable.BORDER_GEM,
	]
	assert_array(gems).is_equal([258, 259, 260, 261, 262, 263, 264] as Array[int])


func test_blocks_and_tools_are_items() -> void:
	for block: int in Hotbar.BLOCKS:
		assert_bool(ItemTable.is_block(block)).is_true()
	assert_bool(ItemTable.is_block(BlockTable.AIR)).is_false()
	assert_bool(ItemTable.is_tool_item(ItemTable.WOODEN_PICKAXE)).is_true()
	assert_bool(ItemTable.is_block(BlockTable.GEM_AMETHYST)).is_true()
	assert_bool(ItemTable.is_block(BlockTable.LAST_BLOCK + 1)).is_false()
	assert_bool(ItemTable.is_known_item(BlockTable.LAST_BLOCK + 1)).is_false()
	assert_bool(ItemTable.is_known_item(ItemTable.BORDER_GEM)).is_true()
	assert_bool(ItemTable.is_known_item(ItemTable.BORDER_GEM + 1)).is_false()


func test_gems_are_not_blocks_and_stack() -> void:
	assert_bool(ItemTable.is_gem(ItemTable.RUBY)).is_true()
	assert_bool(ItemTable.is_block(ItemTable.RUBY)).is_false()
	assert_bool(ItemTable.is_tool_item(ItemTable.RUBY)).is_false()
	assert_int(ItemTable.stack_limit(ItemTable.BORDER_GEM)).is_equal(64)


func test_tools_do_not_stack() -> void:
	assert_int(ItemTable.stack_limit(ItemTable.STONE_PICKAXE)).is_equal(1)
	assert_int(ItemTable.stack_limit(BlockTable.STONE)).is_equal(64)


func test_grass_drops_dirt_and_leaves_and_glass_drop_nothing() -> void:
	assert_int(ItemTable.drop_of(BlockTable.GRASS)).is_equal(BlockTable.DIRT)
	assert_int(ItemTable.drop_of(BlockTable.LEAVES)).is_equal(ItemTable.NONE)
	assert_int(ItemTable.drop_of(BlockTable.GLASS)).is_equal(ItemTable.NONE)
	assert_int(ItemTable.drop_of(BlockTable.STONE)).is_equal(BlockTable.STONE)


func test_gem_blocks_drop_their_gem_and_the_altar_nothing() -> void:
	assert_int(ItemTable.drop_of(BlockTable.GEM_RUBY)).is_equal(ItemTable.RUBY)
	assert_int(ItemTable.drop_of(BlockTable.GEM_GOLD)).is_equal(ItemTable.GOLD)
	assert_int(ItemTable.drop_of(BlockTable.GEM_AMETHYST)).is_equal(ItemTable.AMETHYST)
	assert_int(ItemTable.drop_of(BlockTable.ALTAR)).is_equal(ItemTable.NONE)
	assert_int(ItemTable.drop_of(BlockTable.STONE_BRICKS)).is_equal(BlockTable.STONE_BRICKS)
	assert_int(ItemTable.drop_of(BlockTable.ARENA_STONE)).is_equal(BlockTable.ARENA_STONE)


func test_break_times_follow_the_design_table() -> void:
	assert_float(ItemTable.break_seconds(BlockTable.LEAVES, ItemTable.NONE)).is_equal(0.3)
	assert_float(ItemTable.break_seconds(BlockTable.SAND, ItemTable.NONE)).is_equal(0.6)
	assert_float(ItemTable.break_seconds(BlockTable.LOG, ItemTable.STONE_PICKAXE)).is_equal(1.5)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, ItemTable.NONE)).is_equal(4.0)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, BlockTable.DIRT)).is_equal(4.0)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, ItemTable.WOODEN_PICKAXE)).is_equal(1.5)
	assert_float(ItemTable.break_seconds(BlockTable.STONE, ItemTable.STONE_PICKAXE)).is_equal(0.8)


func test_break_times_of_the_journey_blocks() -> void:
	assert_float(ItemTable.break_seconds(BlockTable.STONE_BRICKS, ItemTable.NONE)).is_equal(ItemTable.UNBREAKABLE)
	assert_float(ItemTable.break_seconds(BlockTable.STONE_BRICKS, ItemTable.WOODEN_PICKAXE)).is_equal(1.5)
	assert_float(ItemTable.break_seconds(BlockTable.STONE_BRICKS, ItemTable.STONE_PICKAXE)).is_equal(0.8)
	assert_float(ItemTable.break_seconds(BlockTable.ARENA_STONE, ItemTable.NONE)).is_equal(4.0)
	assert_float(ItemTable.break_seconds(BlockTable.ARENA_STONE, ItemTable.STONE_PICKAXE)).is_equal(0.8)
	assert_float(ItemTable.break_seconds(BlockTable.ALTAR, ItemTable.STONE_PICKAXE)).is_equal(ItemTable.UNBREAKABLE)
	assert_float(ItemTable.break_seconds(BlockTable.GEM_DIAMOND, ItemTable.NONE)).is_equal(1.5)
	assert_float(ItemTable.break_seconds(BlockTable.GEM_DIAMOND, ItemTable.STONE_PICKAXE)).is_equal(1.5)


func test_unbreakable_blocks_never_finish_and_stay_at_the_first_crack() -> void:
	var progress: BreakProgress = BreakProgress.new()

	for _frame: int in 600:
		assert_bool(progress.advance(Vector3i.ZERO, 1.0 / 60.0, ItemTable.UNBREAKABLE)).is_false()
	assert_int(progress.stage()).is_equal(0)


func test_icon_tiles() -> void:
	assert_int(ItemTable.icon_tile(BlockTable.GRASS)).is_equal(BlockTable.TILE_GRASS_SIDE)
	assert_int(ItemTable.icon_tile(ItemTable.WOODEN_PICKAXE)).is_equal(ItemTable.TILE_WOODEN_PICKAXE)
	assert_int(ItemTable.icon_tile(ItemTable.STONE_PICKAXE)).is_equal(ItemTable.TILE_STONE_PICKAXE)
	assert_int(ItemTable.icon_tile(ItemTable.RUBY)).is_equal(ItemTable.TILE_RUBY)
	assert_int(ItemTable.icon_tile(ItemTable.BORDER_GEM)).is_equal(ItemTable.TILE_RUBY + 6)


func test_every_item_has_a_name() -> void:
	for block: int in Hotbar.BLOCKS:
		assert_str(ItemTable.display_name(block)).is_not_empty()
	assert_str(ItemTable.display_name(ItemTable.STONE_PICKAXE)).is_equal("Piccone di pietra")
	for item: int in range(BlockTable.GRASS, BlockTable.LAST_BLOCK + 1):
		assert_str(ItemTable.display_name(item)).is_not_empty()
	for item: int in range(ItemTable.RUBY, ItemTable.BORDER_GEM + 1):
		assert_str(ItemTable.display_name(item)).is_not_empty()
