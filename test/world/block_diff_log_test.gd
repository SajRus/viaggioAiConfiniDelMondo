extends GdUnitTestSuite


func test_starts_empty() -> void:
	assert_int(BlockDiffLog.new().block_count()).is_equal(0)


func test_records_are_grouped_by_chunk() -> void:
	var diffs: BlockDiffLog = BlockDiffLog.new()

	diffs.record(5, 10, BlockTable.STONE)
	diffs.record(2, 20, BlockTable.AIR)
	diffs.record(5, 11, BlockTable.GLASS)

	assert_array(diffs.chunk_indices()).is_equal([2, 5] as Array[int])
	assert_int(diffs.entries_of(5).size()).is_equal(2)
	assert_int(diffs.block_count()).is_equal(3)


func test_last_write_on_a_block_wins() -> void:
	var diffs: BlockDiffLog = BlockDiffLog.new()

	diffs.record(5, 10, BlockTable.STONE)
	diffs.record(5, 10, BlockTable.AIR)

	assert_int(diffs.block_count()).is_equal(1)
	assert_int(diffs.entries_of(5)[10]).is_equal(BlockTable.AIR)

