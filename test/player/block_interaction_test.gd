extends GdUnitTestSuite

const FLOOR_TOP: int = 10

var _world: WorldData
var _manager: ChunkManager
var _player: Player
var _interaction: BlockInteraction
var _head: Node3D


func before_test() -> void:
	_world = WorldData.new(1, 1)
	for z: int in ChunkData.SIZE_Z:
		for x: int in ChunkData.SIZE_X:
			for y: int in FLOOR_TOP:
				_world.set_block_world(x, y, z, BlockTable.STONE)
	var node: ChunkNode = auto_free(ChunkNode.new(StandardMaterial3D.new()))
	add_child(node)
	var nodes: Array[ChunkNode] = [node]
	_manager = ChunkManager.new(_world, ChunkMesher.new(BlockRegistry), nodes)
	var scene: PackedScene = load("res://src/player/player.tscn")
	_player = auto_free(scene.instantiate())
	add_child(_player)
	_player.global_position = Vector3(8.5, FLOOR_TOP, 8.5)
	_interaction = _player.get_node("Interaction")
	_head = _player.get_node("Head")
	_interaction.setup(_world, _manager)


func _look(pitch: float) -> void:
	_head.rotation = Vector3(pitch, 0.0, 0.0)
	await get_tree().process_frame


func test_nothing_is_targeted_at_the_horizon() -> void:
	await _look(0.0)

	_interaction.update_target()

	assert_object(_interaction.target).is_null()
	assert_bool(_interaction.break_target()).is_false()


func test_looking_down_targets_the_floor() -> void:
	await _look(-1.2)

	_interaction.update_target()

	assert_object(_interaction.target).is_not_null()
	assert_int(_interaction.target.block.y).is_equal(FLOOR_TOP - 1)


func test_break_removes_the_targeted_block() -> void:
	await _look(-1.2)
	_interaction.update_target()
	var block: Vector3i = _interaction.target.block

	assert_bool(_interaction.break_target()).is_true()

	assert_int(_world.get_block_world(block.x, block.y, block.z)).is_equal(BlockTable.AIR)


func test_place_uses_the_block_selected_in_the_hotbar() -> void:
	await _look(-1.0)
	_interaction.hotbar.select(7)
	_interaction.update_target()
	var above: Vector3i = _interaction.target.block + _interaction.target.normal

	assert_bool(_interaction.place_target()).is_true()

	assert_int(_world.get_block_world(above.x, above.y, above.z)).is_equal(BlockTable.GLASS)


func test_interaction_before_setup_does_nothing() -> void:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var player: Player = auto_free(scene.instantiate())
	add_child(player)
	var interaction: BlockInteraction = player.get_node("Interaction")

	assert_bool(interaction.break_target()).is_false()
	assert_bool(interaction.place_target()).is_false()
