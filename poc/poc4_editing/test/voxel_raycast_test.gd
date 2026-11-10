extends GdUnitTestSuite

const REACH: float = 5.0

var _table: BlockTable = BlockTable.new()
var _world: WorldData


func before_test() -> void:
	_world = WorldData.new(2, 2)


func _cast(origin: Vector3, direction: Vector3) -> VoxelHit:
	return VoxelRaycast.cast_ray(_world, _table, origin, direction, REACH)


func test_hits_a_block_straight_ahead_with_its_face_normal() -> void:
	_world.set_block_world(8, 10, 5, BlockTable.STONE)

	var hit: VoxelHit = _cast(Vector3(8.5, 10.5, 8.5), Vector3.FORWARD)

	assert_object(hit).is_not_null()
	assert_vector(hit.block).is_equal(Vector3i(8, 10, 5))
	assert_vector(hit.normal).is_equal(Vector3i(0, 0, 1))


func test_reports_the_normal_of_each_axis() -> void:
	_world.set_block_world(8, 8, 8, BlockTable.STONE)

	assert_vector(_cast(Vector3(8.5, 8.5, 6.5), Vector3.BACK).normal).is_equal(Vector3i(0, 0, -1))
	assert_vector(_cast(Vector3(6.5, 8.5, 8.5), Vector3.RIGHT).normal).is_equal(Vector3i(-1, 0, 0))
	assert_vector(_cast(Vector3(10.5, 8.5, 8.5), Vector3.LEFT).normal).is_equal(Vector3i(1, 0, 0))
	assert_vector(_cast(Vector3(8.5, 10.5, 8.5), Vector3.DOWN).normal).is_equal(Vector3i(0, 1, 0))
	assert_vector(_cast(Vector3(8.5, 6.5, 8.5), Vector3.UP).normal).is_equal(Vector3i(0, -1, 0))


func test_diagonal_ray_finds_the_first_block_along_the_line() -> void:
	_world.set_block_world(10, 10, 10, BlockTable.STONE)
	_world.set_block_world(12, 12, 12, BlockTable.STONE)

	assert_vector(_cast(Vector3(8.5, 8.5, 8.5), Vector3.ONE).block).is_equal(Vector3i(10, 10, 10))


func test_block_just_inside_the_reach_is_found() -> void:
	_world.set_block_world(8, 10, 3, BlockTable.STONE)

	assert_object(_cast(Vector3(8.5, 10.5, 8.5), Vector3.FORWARD)).is_not_null()


func test_block_beyond_the_reach_is_ignored() -> void:
	_world.set_block_world(8, 10, 2, BlockTable.STONE)

	assert_object(_cast(Vector3(8.5, 10.5, 8.5), Vector3.FORWARD)).is_null()


func test_ray_crosses_chunk_borders() -> void:
	_world.set_block_world(17, 10, 8, BlockTable.STONE)

	assert_vector(_cast(Vector3(14.5, 10.5, 8.5), Vector3.RIGHT).block).is_equal(Vector3i(17, 10, 8))


func test_ray_starting_inside_a_block_has_no_normal() -> void:
	_world.set_block_world(8, 10, 8, BlockTable.STONE)

	var hit: VoxelHit = _cast(Vector3(8.5, 10.5, 8.5), Vector3.UP)

	assert_vector(hit.block).is_equal(Vector3i(8, 10, 8))
	assert_vector(hit.normal).is_equal(Vector3i.ZERO)


func test_ray_leaving_the_world_finds_nothing() -> void:
	assert_object(_cast(Vector3(0.5, 10.5, 0.5), Vector3.LEFT)).is_null()


func test_transparent_blocks_can_be_targeted() -> void:
	_world.set_block_world(8, 10, 6, BlockTable.GLASS)

	assert_vector(_cast(Vector3(8.5, 10.5, 8.5), Vector3.FORWARD).block).is_equal(Vector3i(8, 10, 6))


func test_zero_direction_finds_nothing() -> void:
	assert_object(_cast(Vector3(8.5, 10.5, 8.5), Vector3.ZERO)).is_null()
