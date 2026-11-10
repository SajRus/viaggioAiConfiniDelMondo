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


func test_chunk_manager_logs_every_real_change() -> void:
	var world: WorldData = WorldData.new(2, 2)
	var nodes: Array[ChunkNode] = []
	for _index: int in 4:
		var node: ChunkNode = auto_free(ChunkNode.new(StandardMaterial3D.new()))
		add_child(node)
		nodes.append(node)
	var manager: ChunkManager = ChunkManager.new(world, ChunkMesher.new(BlockRegistry), nodes)

	manager.set_block(20, 10, 3, BlockTable.STONE)
	manager.set_block(20, 10, 3, BlockTable.STONE)
	manager.set_block(-1, 10, 3, BlockTable.STONE)

	assert_int(manager.diffs.block_count()).is_equal(1)
	assert_int(manager.diffs.entries_of(1)[ChunkData.index_of(4, 10, 3)]).is_equal(BlockTable.STONE)
