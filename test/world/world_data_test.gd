extends GdUnitTestSuite


func test_world_has_every_chunk() -> void:
	assert_int(WorldData.new(16, 16).chunks.size()).is_equal(256)


func test_chunk_at_is_row_ordered() -> void:
	var world: WorldData = WorldData.new(16, 16)

	assert_object(world.chunk_at(3, 2)).is_same(world.chunks[35])


func test_inner_chunk_knows_its_four_neighbors() -> void:
	var world: WorldData = WorldData.new(3, 3)
	var center: ChunkData = world.chunk_at(1, 1)

	assert_object(center.get_neighbor(ChunkData.SIDE_POS_X)).is_same(world.chunk_at(2, 1))
	assert_object(center.get_neighbor(ChunkData.SIDE_NEG_X)).is_same(world.chunk_at(0, 1))
	assert_object(center.get_neighbor(ChunkData.SIDE_POS_Z)).is_same(world.chunk_at(1, 2))
	assert_object(center.get_neighbor(ChunkData.SIDE_NEG_Z)).is_same(world.chunk_at(1, 0))


func test_corner_chunk_has_no_neighbor_past_the_world_border() -> void:
	var corner: ChunkData = WorldData.new(3, 3).chunk_at(0, 0)

	assert_object(corner.get_neighbor(ChunkData.SIDE_NEG_X)).is_null()
	assert_object(corner.get_neighbor(ChunkData.SIDE_NEG_Z)).is_null()
