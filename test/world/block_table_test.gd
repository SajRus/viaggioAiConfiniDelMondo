extends GdUnitTestSuite


func test_block_ids_never_change() -> void:
	# Saves store these numbers: a new block takes a free ID instead.
	var ids: Array[int] = [
		BlockTable.AIR, BlockTable.GRASS, BlockTable.DIRT, BlockTable.STONE,
		BlockTable.SAND, BlockTable.LOG, BlockTable.LEAVES, BlockTable.PLANKS, BlockTable.GLASS,
		BlockTable.STONE_BRICKS, BlockTable.ARENA_STONE, BlockTable.ALTAR,
		BlockTable.GEM_RUBY, BlockTable.GEM_EMERALD, BlockTable.GEM_OBSIDIAN,
		BlockTable.GEM_GOLD, BlockTable.GEM_DIAMOND, BlockTable.GEM_AMETHYST,
	]

	assert_array(ids).is_equal([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17] as Array[int])


func test_every_block_is_solid_with_tiles_inside_the_atlas() -> void:
	var table: BlockTable = BlockRegistry
	var tiles: int = BlockTable.ATLAS_COLUMNS * BlockTable.ATLAS_COLUMNS

	for id: int in range(BlockTable.GRASS, BlockTable.LAST_BLOCK + 1):
		assert_int(table.solid[id]).is_equal(1)
		for tile: int in [table.tile_top[id], table.tile_side[id], table.tile_bottom[id]]:
			assert_int(tile).is_less(tiles)
	assert_int(table.solid[BlockTable.LAST_BLOCK + 1]).is_equal(0)


func test_each_gem_block_has_its_own_tile() -> void:
	var table: BlockTable = BlockRegistry

	assert_int(table.tile_side[BlockTable.GEM_RUBY]).is_equal(BlockTable.TILE_GEM_RUBY)
	assert_int(table.tile_side[BlockTable.GEM_AMETHYST]).is_equal(BlockTable.TILE_GEM_RUBY + 5)


func test_air_is_not_solid() -> void:
	assert_int(BlockRegistry.solid[BlockTable.AIR]).is_equal(0)


func test_glass_and_leaves_do_not_occlude() -> void:
	var table: BlockTable = BlockRegistry

	assert_int(table.occluding[BlockTable.GLASS]).is_equal(0)
	assert_int(table.occluding[BlockTable.LEAVES]).is_equal(0)
	assert_int(table.occluding[BlockTable.STONE]).is_equal(1)


func test_grass_uses_a_different_tile_per_side() -> void:
	var table: BlockTable = BlockRegistry

	assert_int(table.tile_top[BlockTable.GRASS]).is_equal(BlockTable.TILE_GRASS_TOP)
	assert_int(table.tile_side[BlockTable.GRASS]).is_equal(BlockTable.TILE_GRASS_SIDE)
	assert_int(table.tile_bottom[BlockTable.GRASS]).is_equal(BlockTable.TILE_DIRT)


func test_tile_uv_origin_walks_the_atlas_by_rows() -> void:
	assert_vector(BlockTable.tile_uv_origin(0)).is_equal(Vector2(0.0, 0.0))
	assert_vector(BlockTable.tile_uv_origin(3)).is_equal(Vector2(0.375, 0.0))
	assert_vector(BlockTable.tile_uv_origin(9)).is_equal(Vector2(0.125, 0.125))
	assert_vector(BlockTable.tile_uv_origin(63)).is_equal(Vector2(0.875, 0.875))


func test_atlas_has_sixteen_pixel_tiles() -> void:
	var atlas: Texture2D = load("res://assets/textures/atlas.png")

	assert_int(atlas.get_width()).is_equal(BlockTable.ATLAS_COLUMNS * BlockTable.ATLAS_TILE_PIXELS)
	assert_int(atlas.get_height()).is_equal(BlockTable.ATLAS_COLUMNS * BlockTable.ATLAS_TILE_PIXELS)
