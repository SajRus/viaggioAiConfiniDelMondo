extends GdUnitTestSuite


func test_storage_is_one_byte_per_block() -> void:
	assert_int(ChunkData.new().blocks.size()).is_equal(16384)


func test_new_chunk_is_all_air() -> void:
	assert_int(ChunkData.new().get_block(15, 63, 15)).is_equal(BlockTable.AIR)


func test_index_follows_the_design_formula() -> void:
	assert_int(ChunkData.index_of(0, 0, 0)).is_equal(0)
	assert_int(ChunkData.index_of(1, 0, 0)).is_equal(1)
	assert_int(ChunkData.index_of(0, 0, 1)).is_equal(16)
	assert_int(ChunkData.index_of(0, 1, 0)).is_equal(256)
	assert_int(ChunkData.index_of(15, 63, 15)).is_equal(16383)


func test_set_block_writes_only_that_block() -> void:
	var chunk: ChunkData = ChunkData.new()

	chunk.set_block(3, 40, 9, BlockTable.SAND)

	assert_int(chunk.get_block(3, 40, 9)).is_equal(BlockTable.SAND)
	assert_int(chunk.blocks.count(BlockTable.AIR)).is_equal(ChunkData.VOLUME - 1)
