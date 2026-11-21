extends GdUnitTestSuite

const GAME_SCENE: String = "res://src/game.tscn"
const TEST_PATH: String = "user://gdunit_survival_flow.sav"

var _runner: GdUnitSceneRunner
var _game: Node
var _world: World
var _player: Player
var _interaction: BlockInteraction
var _head: Node3D


func before_test() -> void:
	SaveSystem.save_path = TEST_PATH
	var state: WorldSave = WorldSave.new()
	state.world_seed = 1234
	state.survival = true
	SaveSystem.request_world(state)
	_runner = scene_runner(GAME_SCENE)
	_game = _runner.scene()
	_world = _game.get_node("World")
	_player = _game.get_node("Player")
	_interaction = _game.get_node("Player/Interaction")
	_head = _game.get_node("Player/Head")
	while not _world.is_ready_to_play():
		await get_tree().process_frame
	for _tick: int in 45:
		await get_tree().physics_frame


func after_test() -> void:
	get_tree().paused = false
	for path: String in [TEST_PATH, TEST_PATH + SaveSystem.TEMPORARY_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	SaveSystem.save_path = SaveSystem.DEFAULT_SAVE_PATH


func _inventory() -> Inventory:
	return _game.get("inventory")


func _health() -> Health:
	return _game.get("health")


func _look_down() -> void:
	_head.rotation = Vector3(-1.1, 0.0, 0.0)
	await get_tree().process_frame
	_interaction.update_target()


func test_survival_starts_with_full_health_and_an_empty_inventory() -> void:
	assert_int(_health().points).is_equal(Health.MAX)
	assert_int(_inventory().count_of(BlockTable.DIRT)).is_equal(0)
	assert_bool((_game.get_node("Hud/Health") as Control).visible).is_true()


func test_breaking_takes_time_and_collects_the_drop() -> void:
	await _look_down()
	var cell: Vector3i = _interaction.target.block
	var block: int = _world.data.get_block_world(cell.x, cell.y, cell.z)
	var needed: float = ItemTable.break_seconds(block, ItemTable.NONE)

	assert_bool(_interaction.hold_break(needed * 0.5)).is_false()
	assert_int(_world.data.get_block_world(cell.x, cell.y, cell.z)).is_equal(block)
	assert_bool(_interaction.hold_break(needed * 0.6)).is_true()

	assert_int(_world.data.get_block_world(cell.x, cell.y, cell.z)).is_equal(BlockTable.AIR)
	assert_int(_inventory().count_of(ItemTable.drop_of(block))).is_equal(1)


## Puts a wall two blocks ahead at eye height and aims at it.
func _aim_at_wall() -> Vector3i:
	var support: Vector3i = Vector3i(_player.global_position.floor()) + Vector3i(0, 1, -2)
	_world.manager.set_block(support.x, support.y, support.z, BlockTable.STONE)
	_world.manager.set_block(support.x, support.y, support.z + 1, BlockTable.AIR)
	_head.rotation = Vector3.ZERO
	await get_tree().process_frame
	_interaction.update_target()
	return _interaction.target.block + _interaction.target.normal


func test_placing_uses_the_selected_stack() -> void:
	_inventory().add(BlockTable.PLANKS, 2)
	var cell: Vector3i = await _aim_at_wall()

	assert_bool(_interaction.place_target()).is_true()

	assert_int(_world.data.get_block_world(cell.x, cell.y, cell.z)).is_equal(BlockTable.PLANKS)
	assert_int(_inventory().count_of(BlockTable.PLANKS)).is_equal(1)


func test_placing_with_an_empty_slot_does_nothing() -> void:
	var cell: Vector3i = await _aim_at_wall()

	assert_bool(_interaction.place_target()).is_false()
	assert_int(_world.data.get_block_world(cell.x, cell.y, cell.z)).is_equal(BlockTable.AIR)


func test_a_tool_cannot_be_placed() -> void:
	_inventory().add(ItemTable.STONE_PICKAXE, 1)
	await _aim_at_wall()

	assert_bool(_interaction.place_target()).is_false()
	assert_int(_inventory().count_of(ItemTable.STONE_PICKAXE)).is_equal(1)


func test_pickaxe_breaks_stone_faster() -> void:
	_inventory().add(ItemTable.STONE_PICKAXE, 1)
	await _aim_at_wall()
	var wall: Vector3i = _interaction.target.block

	assert_bool(_interaction.hold_break(ItemTable.STONE_PICKAXE_STONE_SECONDS + 0.01)).is_true()

	assert_int(_world.data.get_block_world(wall.x, wall.y, wall.z)).is_equal(BlockTable.AIR)
	assert_int(_inventory().count_of(BlockTable.STONE)).is_equal(1)


func test_a_long_fall_hurts_and_death_respawns_at_the_start() -> void:
	_player.landed.emit(8.0)
	assert_int(_health().points).is_equal(Health.MAX - 5)

	_player.landed.emit(40.0)
	var death: DeathScreen = _game.get_node("DeathLayer/Death")
	assert_bool(death.visible).is_true()
	assert_bool(get_tree().paused).is_true()

	_inventory().add(BlockTable.SAND, 3)
	death.respawn_requested.emit()

	assert_bool(death.visible).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(_health().points).is_equal(Health.MAX)
	assert_vector(_player.global_position).is_equal(_world.spawn_point())
	assert_int(_inventory().count_of(BlockTable.SAND)).is_equal(3)


func test_save_keeps_health_and_inventory() -> void:
	_inventory().add(ItemTable.WOODEN_PICKAXE, 1)
	_inventory().add(BlockTable.LOG, 12)
	_player.landed.emit(6.0)

	(_game.get_node("PauseLayer/Pause") as PauseMenu).save_requested.emit()

	var saved: WorldSave = SaveSystem.read()
	assert_bool(saved.survival).is_true()
	assert_int(saved.health).is_equal(Health.MAX - 3)
	assert_array(saved.inventory_items).is_equal(_inventory().items)
	assert_array(saved.inventory_counts).is_equal(_inventory().counts)
