extends GdUnitTestSuite

var _table: BlockTable = BlockRegistry
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _world: WorldData
var _nodes: Array[ChunkNode] = []
var _manager: ChunkManager


func before_test() -> void:
	_world = WorldData.new(3, 3)
	_nodes = []
	for chunk: ChunkData in _world.chunks:
		var node: ChunkNode = auto_free(ChunkNode.new(StandardMaterial3D.new()))
		add_child(node)
		node.rebuild(_mesher, chunk)
		_nodes.append(node)
	_manager = ChunkManager.new(_world, _mesher, _nodes)


func _rebuilt_after_edit(x: int, z: int) -> Array:
	_manager.set_block(x, 10, z, BlockTable.STONE)
	var rebuilt: Array = Array(_manager.flush())
	rebuilt.sort()
	return rebuilt


func test_interior_edit_rebuilds_only_its_chunk() -> void:
	assert_array(_rebuilt_after_edit(24, 24)).is_equal([4])


func test_edit_on_each_border_rebuilds_the_neighbor() -> void:
	assert_array(_rebuilt_after_edit(16, 24)).is_equal([3, 4])
	assert_array(_rebuilt_after_edit(31, 25)).is_equal([4, 5])
	assert_array(_rebuilt_after_edit(24, 16)).is_equal([1, 4])
	assert_array(_rebuilt_after_edit(25, 31)).is_equal([4, 7])


func test_corner_edit_rebuilds_both_neighbors() -> void:
	assert_array(_rebuilt_after_edit(16, 16)).is_equal([1, 3, 4])


func test_edit_on_the_world_border_has_no_neighbor_to_rebuild() -> void:
	assert_array(_rebuilt_after_edit(0, 0)).is_equal([0])


func test_writing_the_same_block_rebuilds_nothing() -> void:
	assert_bool(_manager.set_block(24, 10, 24, BlockTable.AIR)).is_false()
	assert_int(_manager.flush().size()).is_equal(0)


func test_several_edits_in_a_frame_rebuild_a_chunk_once() -> void:
	_manager.set_block(24, 10, 24, BlockTable.STONE)
	_manager.set_block(25, 10, 24, BlockTable.STONE)

	assert_int(_manager.flush().size()).is_equal(1)


func test_flush_clears_the_dirty_state() -> void:
	_manager.set_block(24, 10, 24, BlockTable.STONE)
	_manager.flush()

	assert_int(_manager.flush().size()).is_equal(0)
	assert_bool(_world.chunk_at(1, 1).dirty).is_false()


func test_edit_outside_the_world_is_rejected() -> void:
	assert_bool(_manager.set_block(-1, 10, 0, BlockTable.STONE)).is_false()
	assert_bool(_manager.set_block(0, 64, 0, BlockTable.STONE)).is_false()


func test_border_block_removal_reveals_the_neighbor_face() -> void:
	_world.chunk_at(1, 1).blocks.fill(BlockTable.STONE)
	_world.chunk_at(0, 1).blocks.fill(BlockTable.STONE)
	_nodes[3].rebuild(_mesher, _world.chunk_at(0, 1))
	_nodes[4].rebuild(_mesher, _world.chunk_at(1, 1))
	var faces_before: int = _nodes[3].face_count

	_manager.set_block(16, 30, 24, BlockTable.AIR)
	_manager.flush()

	assert_int(_nodes[3].face_count).is_equal(faces_before + 1)


func test_random_border_edits_keep_every_chunk_in_sync() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(7)
	for chunk_z: int in 3:
		for chunk_x: int in 3:
			generator.fill_chunk(_world.chunk_at(chunk_x, chunk_z), chunk_x, chunk_z)
	for index: int in _nodes.size():
		_nodes[index].rebuild(_mesher, _world.chunks[index])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var ids: PackedInt32Array = [BlockTable.AIR, BlockTable.STONE, BlockTable.GLASS]
	var mismatches: int = 0

	for _edit: int in 40:
		var x: int = rng.randi_range(0, 47)
		var z: int = [15, 16, 31, 32][rng.randi_range(0, 3)]
		var y: int = clampi(_world.surface_height(x, z) + rng.randi_range(-2, 2), 0, 63)
		_manager.set_block(x, y, z, ids[rng.randi_range(0, 2)])
		_manager.flush()
		for index: int in _nodes.size():
			if not VoxelAudit.node_matches_chunk(_nodes[index], _world.chunks[index], _mesher):
				mismatches += 1

	assert_int(mismatches).is_equal(0)
	var built_faces: int = 0
	for node: ChunkNode in _nodes:
		built_faces += node.face_count
	assert_int(built_faces).is_equal(VoxelAudit.expected_face_count(_world, _table))
