extends GdUnitTestSuite


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
	assert_vector(BlockTable.tile_uv_origin(3)).is_equal(Vector2(0.75, 0.0))
	assert_vector(BlockTable.tile_uv_origin(9)).is_equal(Vector2(0.25, 0.5))


func test_atlas_has_sixteen_pixel_tiles() -> void:
	var atlas: Texture2D = load("res://assets/textures/atlas.png")

	assert_int(atlas.get_width()).is_equal(BlockTable.ATLAS_COLUMNS * BlockTable.ATLAS_TILE_PIXELS)
	assert_int(atlas.get_height()).is_equal(BlockTable.ATLAS_COLUMNS * BlockTable.ATLAS_TILE_PIXELS)
