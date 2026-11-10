extends GdUnitTestSuite


func _generated(world_seed: int, chunk_x: int, chunk_z: int) -> ChunkData:
	var chunk: ChunkData = ChunkData.new()
	TerrainGenerator.new(world_seed).fill_chunk(chunk, chunk_x, chunk_z)
	return chunk


func test_same_seed_generates_the_same_chunk() -> void:
	assert_bool(_generated(42, 3, 5).blocks == _generated(42, 3, 5).blocks).is_true()


func test_different_seed_generates_a_different_chunk() -> void:
	assert_bool(_generated(42, 3, 5).blocks == _generated(43, 3, 5).blocks).is_false()


func test_column_is_stone_then_three_dirt_then_grass() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(42)
	var chunk: ChunkData = ChunkData.new()
	generator.fill_chunk(chunk, 0, 0)
	var height: int = generator.height_at(4, 9)

	assert_int(chunk.get_block(4, height + 1, 9)).is_equal(BlockTable.AIR)
	assert_int(chunk.get_block(4, height, 9)).is_equal(BlockTable.GRASS)
	assert_int(chunk.get_block(4, height - 1, 9)).is_equal(BlockTable.DIRT)
	assert_int(chunk.get_block(4, height - 3, 9)).is_equal(BlockTable.DIRT)
	assert_int(chunk.get_block(4, height - 4, 9)).is_equal(BlockTable.STONE)
	assert_int(chunk.get_block(4, 0, 9)).is_equal(BlockTable.STONE)


func test_height_stays_inside_the_chunk() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(7)

	for z: int in range(0, 256, 8):
		for x: int in range(0, 256, 8):
			assert_int(generator.height_at(x, z)).is_between(1, ChunkData.SIZE_Y - 1)


func test_neighboring_chunks_use_continuous_world_coordinates() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(42)
	var chunk: ChunkData = ChunkData.new()
	generator.fill_chunk(chunk, 1, 2)
	var height: int = generator.height_at(16 + 5, 32 + 6)

	assert_int(chunk.get_block(5, height, 6)).is_equal(BlockTable.GRASS)
