extends GdUnitTestSuite

const FEET_FAR_AWAY: Vector3 = Vector3(3.5, 40.0, 3.5)

var _table: BlockTable = BlockTable.new()
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _world: WorldData
var _manager: ChunkManager


func before_test() -> void:
	_world = WorldData.new(1, 1)
	var node: ChunkNode = auto_free(ChunkNode.new(StandardMaterial3D.new()))
	add_child(node)
	var nodes: Array[ChunkNode] = [node]
	_manager = ChunkManager.new(_world, _mesher, nodes)
	_world.set_block_world(8, 10, 8, BlockTable.STONE)


func _hit_top() -> VoxelHit:
	return VoxelHit.new(Vector3i(8, 10, 8), Vector3i(0, 1, 0), 2.0)


func test_break_writes_air_in_the_hit_block() -> void:
	assert_bool(BlockEditor.break_block(_manager, _hit_top())).is_true()
	assert_int(_world.get_block_world(8, 10, 8)).is_equal(BlockTable.AIR)


func test_break_without_a_target_does_nothing() -> void:
	assert_bool(BlockEditor.break_block(_manager, null)).is_false()


func test_place_writes_next_to_the_hit_face() -> void:
	assert_bool(BlockEditor.place_block(_manager, _hit_top(), BlockTable.PLANKS, FEET_FAR_AWAY)).is_true()
	assert_int(_world.get_block_world(8, 11, 8)).is_equal(BlockTable.PLANKS)


func test_place_without_a_target_does_nothing() -> void:
	assert_bool(BlockEditor.place_block(_manager, null, BlockTable.PLANKS, FEET_FAR_AWAY)).is_false()


func test_place_from_inside_a_block_is_refused() -> void:
	var inside: VoxelHit = VoxelHit.new(Vector3i(8, 10, 8), Vector3i.ZERO, 0.0)

	assert_bool(BlockEditor.place_block(_manager, inside, BlockTable.PLANKS, FEET_FAR_AWAY)).is_false()


func test_place_on_an_occupied_cell_is_refused() -> void:
	_world.set_block_world(8, 11, 8, BlockTable.SAND)

	assert_bool(BlockEditor.place_block(_manager, _hit_top(), BlockTable.PLANKS, FEET_FAR_AWAY)).is_false()
	assert_int(_world.get_block_world(8, 11, 8)).is_equal(BlockTable.SAND)


func test_place_outside_the_world_is_refused() -> void:
	_world.set_block_world(8, 63, 8, BlockTable.STONE)
	var top: VoxelHit = VoxelHit.new(Vector3i(8, 63, 8), Vector3i(0, 1, 0), 2.0)

	assert_bool(BlockEditor.place_block(_manager, top, BlockTable.PLANKS, FEET_FAR_AWAY)).is_false()


func test_place_on_the_player_feet_is_refused() -> void:
	assert_bool(BlockEditor.place_block(_manager, _hit_top(), BlockTable.PLANKS, Vector3(8.5, 11.0, 8.5))).is_false()
	assert_int(_world.get_block_world(8, 11, 8)).is_equal(BlockTable.AIR)


func test_place_on_the_player_head_is_refused() -> void:
	_world.set_block_world(8, 13, 8, BlockTable.STONE)
	var underside: VoxelHit = VoxelHit.new(Vector3i(8, 13, 8), Vector3i(0, -1, 0), 2.0)

	assert_bool(BlockEditor.place_block(_manager, underside, BlockTable.PLANKS, Vector3(8.5, 11.0, 8.5))).is_false()


func test_place_right_next_to_the_player_is_allowed() -> void:
	assert_bool(BlockEditor.place_block(_manager, _hit_top(), BlockTable.PLANKS, Vector3(9.31, 11.0, 8.5))).is_true()


func test_block_overlapped_by_a_player_edge_is_refused() -> void:
	assert_bool(BlockEditor.place_block(_manager, _hit_top(), BlockTable.PLANKS, Vector3(9.29, 11.0, 8.5))).is_false()
