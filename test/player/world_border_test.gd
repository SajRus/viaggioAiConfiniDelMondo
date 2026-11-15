extends GdUnitTestSuite

const SPAN: float = 16.0
const EDGE: float = SPAN - Player.HALF_WIDTH

var _world: World
var _player: Player


func before_test() -> void:
	_world = auto_free(World.new())
	_world.chunks_per_side = 1
	_world.chunk_material = StandardMaterial3D.new()
	add_child(_world)
	_world.start_generation(42)
	await _world.loaded
	var scene: PackedScene = load("res://src/player/player.tscn")
	_player = auto_free(scene.instantiate())
	add_child(_player)
	_player.global_position = Vector3(8.5, _world.data.surface_height(8, 8) + 1.5, 8.5)
	await _run_ticks(30)


func _run_ticks(ticks: int) -> void:
	for _tick: int in ticks:
		await get_tree().physics_frame


func _walk(wish: Vector2, ticks: int) -> void:
	_player.wish_move = wish
	_player.wish_jump = true
	await _run_ticks(ticks)


func test_player_cannot_cross_the_positive_x_border() -> void:
	await _walk(Vector2.RIGHT, 180)

	assert_float(_player.global_position.x).is_less_equal(EDGE + 0.02)


func test_player_cannot_cross_the_negative_x_border() -> void:
	await _walk(Vector2.LEFT, 180)

	assert_float(_player.global_position.x).is_greater_equal(Player.HALF_WIDTH - 0.02)


func test_player_cannot_cross_the_positive_z_border() -> void:
	await _walk(Vector2.DOWN, 180)

	assert_float(_player.global_position.z).is_less_equal(EDGE + 0.02)


func test_player_cannot_cross_the_negative_z_border() -> void:
	await _walk(Vector2.UP, 180)

	assert_float(_player.global_position.z).is_greater_equal(Player.HALF_WIDTH - 0.02)


func test_digging_to_the_bottom_does_not_drop_out_of_the_world() -> void:
	for y: int in ChunkData.SIZE_Y:
		_world.manager.set_block(8, y, 8, BlockTable.AIR)
	_player.global_position = Vector3(8.5, 40.0, 8.5)

	await _run_ticks(150)

	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.03)
