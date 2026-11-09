extends GdUnitTestSuite

var _table: BlockTable = BlockTable.new()


func _world_with_block() -> WorldData:
	var world: WorldData = WorldData.new(2, 1)
	world.set_block_world(16, 10, 7, BlockTable.STONE)
	return world


func test_box_in_the_air_does_not_overlap() -> void:
	var box: AABB = VoxelProbe.player_box(Vector3(15.5, 11.0, 7.5), 0.02)

	assert_bool(VoxelProbe.box_overlaps_solid(_world_with_block(), _table, box)).is_false()


func test_box_entering_a_block_overlaps_across_chunks() -> void:
	var box: AABB = VoxelProbe.player_box(Vector3(15.9, 10.5, 7.5), 0.02)

	assert_bool(VoxelProbe.box_overlaps_solid(_world_with_block(), _table, box)).is_true()


func test_tolerance_allows_touching_a_block() -> void:
	var box: AABB = VoxelProbe.player_box(Vector3(16.5, 11.0, 7.5), 0.02)

	assert_bool(VoxelProbe.box_overlaps_solid(_world_with_block(), _table, box)).is_false()


func test_block_addressing_uses_the_right_chunk() -> void:
	var world: WorldData = _world_with_block()

	assert_int(world.chunk_at(1, 0).get_block(0, 10, 7)).is_equal(BlockTable.STONE)
	assert_int(world.surface_height(16, 7)).is_equal(10)
	assert_int(world.surface_height(3, 3)).is_equal(-1)
