extends GdUnitTestSuite

const FLOOR_TOP: int = 10
const TOLERANCE: float = 0.02

var _table: BlockTable = BlockTable.new()
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _world: WorldData
var _chunk_node: ChunkNode
var _player: Player
var _entered_block: bool = false


func before_test() -> void:
	_world = WorldData.new(1, 1)
	for z: int in ChunkData.SIZE_Z:
		for x: int in ChunkData.SIZE_X:
			for y: int in FLOOR_TOP:
				_world.set_block_world(x, y, z, BlockTable.STONE)
	_chunk_node = auto_free(ChunkNode.new(StandardMaterial3D.new()))
	add_child(_chunk_node)
	var scene: PackedScene = load("res://player.tscn")
	_player = auto_free(scene.instantiate())
	_entered_block = false


func _build_and_spawn(feet: Vector3) -> void:
	_chunk_node.rebuild(_mesher, _world.chunks[0])
	add_child(_player)
	_player.global_position = feet
	await get_tree().physics_frame


func _run_ticks(ticks: int) -> void:
	for _tick: int in ticks:
		await get_tree().physics_frame
		if VoxelProbe.box_overlaps_solid(_world, _table, VoxelProbe.player_box(_player.global_position, TOLERANCE)):
			_entered_block = true


func _add_wall(x: int, height: int) -> void:
	for z: int in ChunkData.SIZE_Z:
		for y: int in range(FLOOR_TOP, FLOOR_TOP + height):
			_world.set_block_world(x, y, z, BlockTable.STONE)


func test_player_lands_on_the_floor() -> void:
	await _build_and_spawn(Vector3(8.5, 14.0, 8.5))

	await _run_ticks(90)

	assert_float(_player.global_position.y).is_equal_approx(FLOOR_TOP, 0.02)
	assert_bool(_player.is_on_floor()).is_true()
	assert_bool(_entered_block).is_false()


func test_wall_stops_the_player() -> void:
	_add_wall(12, 4)
	await _build_and_spawn(Vector3(9.5, FLOOR_TOP + 0.1, 8.5))
	_player.wish_move = Vector2.RIGHT

	await _run_ticks(90)

	assert_float(_player.global_position.x).is_between(11.5, 11.72)
	assert_bool(_entered_block).is_false()


func test_standing_on_a_block_corner_does_not_jitter() -> void:
	_world.set_block_world(8, FLOOR_TOP, 8, BlockTable.STONE)
	await _build_and_spawn(Vector3(7.75, FLOOR_TOP + 1.05, 7.75))
	await _run_ticks(30)
	var settled: Vector3 = _player.global_position

	await _run_ticks(120)

	assert_float(settled.y).is_equal_approx(FLOOR_TOP + 1.0, 0.02)
	assert_vector(_player.global_position).is_equal_approx(settled, Vector3.ONE * 0.005)
	assert_bool(_player.is_on_floor()).is_true()


func test_jump_clears_one_block() -> void:
	_add_wall(10, 1)
	await _build_and_spawn(Vector3(8.5, FLOOR_TOP + 0.1, 8.5))
	_player.wish_move = Vector2.RIGHT
	_player.wish_jump = true

	await _run_ticks(60)

	assert_float(_player.global_position.x).is_greater(11.0)
	assert_bool(_entered_block).is_false()


func test_jump_does_not_clear_two_blocks() -> void:
	_add_wall(10, 2)
	await _build_and_spawn(Vector3(8.5, FLOOR_TOP + 0.1, 8.5))
	_player.wish_move = Vector2.RIGHT
	_player.wish_jump = true

	await _run_ticks(90)

	assert_float(_player.global_position.x).is_less(9.75)
	assert_bool(_entered_block).is_false()


func test_player_fits_under_a_two_block_ceiling() -> void:
	for z: int in ChunkData.SIZE_Z:
		for x: int in range(10, 13):
			_world.set_block_world(x, FLOOR_TOP + 2, z, BlockTable.STONE)
	await _build_and_spawn(Vector3(8.5, FLOOR_TOP + 0.1, 8.5))
	_player.wish_move = Vector2.RIGHT

	await _run_ticks(60)

	assert_float(_player.global_position.x).is_greater(12.5)
	assert_bool(_entered_block).is_false()


func test_player_does_not_fit_under_a_one_block_ceiling() -> void:
	for z: int in ChunkData.SIZE_Z:
		for x: int in range(10, 13):
			_world.set_block_world(x, FLOOR_TOP + 1, z, BlockTable.STONE)
	await _build_and_spawn(Vector3(8.5, FLOOR_TOP + 0.1, 8.5))
	_player.wish_move = Vector2.RIGHT

	await _run_ticks(60)

	assert_float(_player.global_position.x).is_less(9.75)
	assert_bool(_entered_block).is_false()


func test_rebuilt_collision_removes_the_block_under_the_player() -> void:
	_world.set_block_world(8, FLOOR_TOP, 8, BlockTable.STONE)
	await _build_and_spawn(Vector3(8.5, FLOOR_TOP + 1.05, 8.5))
	await _run_ticks(30)
	assert_float(_player.global_position.y).is_equal_approx(FLOOR_TOP + 1.0, 0.02)

	_world.set_block_world(8, FLOOR_TOP, 8, BlockTable.AIR)
	_chunk_node.rebuild(_mesher, _world.chunks[0])
	await _run_ticks(45)

	assert_float(_player.global_position.y).is_equal_approx(FLOOR_TOP, 0.02)


func test_rebuilt_collision_adds_a_new_wall() -> void:
	await _build_and_spawn(Vector3(8.5, FLOOR_TOP + 0.1, 8.5))
	await _run_ticks(10)

	_add_wall(12, 4)
	_chunk_node.rebuild(_mesher, _world.chunks[0])
	_player.wish_move = Vector2.RIGHT
	await _run_ticks(90)

	assert_float(_player.global_position.x).is_between(11.5, 11.72)
	assert_bool(_entered_block).is_false()


func test_long_fall_at_top_speed_does_not_pass_through_the_floor() -> void:
	await _build_and_spawn(Vector3(8.5, ChunkData.SIZE_Y - 2.0, 8.5))

	await _run_ticks(180)

	assert_float(_player.global_position.y).is_equal_approx(FLOOR_TOP, 0.02)
	assert_bool(_entered_block).is_false()
