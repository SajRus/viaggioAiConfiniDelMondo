extends GdUnitTestSuite

const GAME_SCENE: String = "res://src/game.tscn"

var _runner: GdUnitSceneRunner
var _world: World
var _player: Player
var _interaction: BlockInteraction
var _head: Node3D


func before_test() -> void:
	var state: WorldSave = WorldSave.new()
	state.world_seed = 1234
	SaveSystem.request_world(state)
	_runner = scene_runner(GAME_SCENE)
	var game: Node = _runner.scene()
	_world = game.get_node("World")
	_player = game.get_node("Player")
	_interaction = game.get_node("Player/Interaction")
	_head = game.get_node("Player/Head")
	while not _world.is_ready_to_play():
		await get_tree().process_frame
	await _settle()


func _settle() -> void:
	for _tick: int in 45:
		await get_tree().physics_frame


func _look_down() -> void:
	_head.rotation = Vector3(-1.1, 0.0, 0.0)
	await get_tree().process_frame
	_interaction.update_target()


func _chunk_index_of(cell: Vector3i) -> int:
	return (cell.x >> WorldData.CHUNK_BITS) + _world.chunks_per_side * (cell.z >> WorldData.CHUNK_BITS)


func _assert_rebuilt(cell: Vector3i) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var index: int = _chunk_index_of(cell)
	var mesher: ChunkMesher = ChunkMesher.new(BlockRegistry)
	assert_bool(
		VoxelAudit.node_matches_chunk(_world.chunk_nodes()[index], _world.data.chunks[index], mesher)
	).is_true()


func test_game_starts_with_the_player_on_the_ground() -> void:
	assert_bool(_player.is_on_floor()).is_true()
	assert_int(_world.chunk_nodes().size()).is_equal(256)


func test_breaking_a_block_updates_data_mesh_and_collision() -> void:
	await _look_down()
	var cell: Vector3i = _interaction.target.block

	assert_bool(_interaction.break_target()).is_true()
	await _assert_rebuilt(cell)

	assert_int(_world.data.get_block_world(cell.x, cell.y, cell.z)).is_equal(BlockTable.AIR)


func test_placing_a_block_updates_data_mesh_and_collision() -> void:
	var support: Vector3i = Vector3i(_player.global_position.floor()) + Vector3i(0, 1, -2)
	_world.manager.set_block(support.x, support.y, support.z, BlockTable.STONE)
	_world.manager.set_block(support.x, support.y, support.z + 1, BlockTable.AIR)
	_head.rotation = Vector3.ZERO
	await get_tree().process_frame
	_interaction.update_target()
	_interaction.hotbar.select(6)
	var cell: Vector3i = _interaction.target.block + _interaction.target.normal

	assert_bool(_interaction.place_target()).is_true()
	await _assert_rebuilt(cell)

	assert_int(_world.data.get_block_world(cell.x, cell.y, cell.z)).is_equal(BlockTable.PLANKS)


func test_player_falls_when_the_block_under_the_feet_is_removed() -> void:
	var feet: Vector3 = _player.global_position
	var column: Vector3i = Vector3i(feet.floor())
	var height_before: float = feet.y
	for offset_z: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var y: int = _world.data.surface_height(column.x + offset_x, column.z + offset_z)
			_world.manager.set_block(column.x + offset_x, y, column.z + offset_z, BlockTable.AIR)

	await _settle()

	assert_float(_player.global_position.y).is_less(height_before - 0.5)
