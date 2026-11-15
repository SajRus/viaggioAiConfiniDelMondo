extends GdUnitTestSuite

const SEED: int = 42

var _world: World


func before_test() -> void:
	_world = auto_free(World.new())
	_world.chunks_per_side = 2
	_world.chunk_material = StandardMaterial3D.new()
	add_child(_world)


func _load_world(world_seed: int = SEED) -> void:
	_world.start_generation(world_seed)
	await _world.loaded


func test_loading_creates_every_chunk_and_reports_progress() -> void:
	assert_float(_world.load_progress()).is_equal(0.0)

	await _load_world()

	assert_int(_world.chunk_nodes().size()).is_equal(4)
	assert_float(_world.load_progress()).is_equal(1.0)
	assert_bool(_world.is_ready_to_play()).is_true()


func test_same_seed_generates_the_same_world() -> void:
	await _load_world()
	var other: World = auto_free(World.new())
	other.chunks_per_side = 2
	other.chunk_material = StandardMaterial3D.new()
	add_child(other)
	other.start_generation(SEED)
	await other.loaded

	for index: int in 4:
		assert_bool(_world.data.chunks[index].blocks == other.data.chunks[index].blocks).is_true()


func test_built_faces_match_an_independent_count() -> void:
	await _load_world()
	var built: int = 0
	for node: ChunkNode in _world.chunk_nodes():
		built += node.face_count

	assert_int(built).is_equal(VoxelAudit.expected_face_count(_world.data, BlockRegistry))


func test_spawn_point_stands_on_the_surface() -> void:
	await _load_world()
	var spawn: Vector3 = _world.spawn_point()
	var surface: int = _world.data.surface_height(16, 16)

	assert_vector(spawn).is_equal(Vector3(16.5, surface + 1.0, 16.5))


func test_edits_are_rebuilt_by_the_end_of_the_frame() -> void:
	await _load_world()
	var surface: int = _world.data.surface_height(5, 5)
	_world.manager.set_block(5, surface, 5, BlockTable.AIR)

	await get_tree().process_frame
	await get_tree().process_frame

	var mesher: ChunkMesher = ChunkMesher.new(BlockRegistry)
	assert_bool(VoxelAudit.node_matches_chunk(_world.chunk_nodes()[0], _world.data.chunks[0], mesher)).is_true()
	assert_bool(_world.data.chunks[0].dirty).is_false()


func test_chunk_nodes_sit_at_their_world_position() -> void:
	await _load_world()

	assert_vector(_world.chunk_nodes()[3].position).is_equal(Vector3(16.0, 0.0, 16.0))
