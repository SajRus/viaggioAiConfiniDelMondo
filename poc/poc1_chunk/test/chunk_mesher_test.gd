extends GdUnitTestSuite

var _mesher: ChunkMesher = ChunkMesher.new(BlockTable.new())


func _opaque(chunk: ChunkData) -> ChunkSurfaceArrays:
	return _mesher.build_surfaces(chunk)[ChunkMesher.SURFACE_OPAQUE]


func _transparent(chunk: ChunkData) -> ChunkSurfaceArrays:
	return _mesher.build_surfaces(chunk)[ChunkMesher.SURFACE_TRANSPARENT]


func _chunk_with(positions: Array[Vector3i], id: int) -> ChunkData:
	var chunk: ChunkData = ChunkData.new()
	for position: Vector3i in positions:
		chunk.set_block(position.x, position.y, position.z, id)
	return chunk


func _single_block_chunk(id: int) -> ChunkData:
	var positions: Array[Vector3i] = [Vector3i(5, 10, 7)]
	return _chunk_with(positions, id)


func test_empty_chunk_has_no_faces() -> void:
	assert_int(_opaque(ChunkData.new()).face_count).is_equal(0)


func test_single_block_has_six_quads() -> void:
	var surface: ChunkSurfaceArrays = _opaque(_single_block_chunk(BlockTable.STONE))

	assert_int(surface.face_count).is_equal(6)
	assert_int(surface.vertices.size()).is_equal(24)
	assert_int(surface.normals.size()).is_equal(24)
	assert_int(surface.uvs.size()).is_equal(24)
	assert_int(surface.indices.size()).is_equal(36)


func test_touching_blocks_cull_the_shared_faces() -> void:
	var positions: Array[Vector3i] = [Vector3i(5, 10, 7), Vector3i(6, 10, 7)]

	assert_int(_opaque(_chunk_with(positions, BlockTable.STONE)).face_count).is_equal(10)


func test_buried_block_emits_nothing() -> void:
	var chunk: ChunkData = ChunkData.new()
	for y: int in 3:
		for z: int in 3:
			for x: int in 3:
				chunk.set_block(x + 4, y + 4, z + 4, BlockTable.STONE)

	assert_int(_opaque(chunk).face_count).is_equal(54)


func test_full_chunk_only_emits_its_shell() -> void:
	var chunk: ChunkData = ChunkData.new()
	ChunkPatterns.fill_solid(chunk)

	assert_int(_opaque(chunk).face_count).is_equal(2 * 16 * 16 + 4 * 16 * 64)


func test_blocks_on_every_chunk_border_keep_their_outer_faces() -> void:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(15, 63, 15)]

	assert_int(_opaque(_chunk_with(positions, BlockTable.STONE)).face_count).is_equal(12)


func test_opaque_face_stays_visible_behind_glass() -> void:
	var chunk: ChunkData = ChunkData.new()
	chunk.set_block(5, 10, 7, BlockTable.STONE)
	chunk.set_block(6, 10, 7, BlockTable.GLASS)

	assert_int(_opaque(chunk).face_count).is_equal(6)
	assert_int(_transparent(chunk).face_count).is_equal(5)


func test_faces_between_transparent_blocks_are_kept() -> void:
	var positions: Array[Vector3i] = [Vector3i(5, 10, 7), Vector3i(6, 10, 7)]

	assert_int(_transparent(_chunk_with(positions, BlockTable.GLASS)).face_count).is_equal(12)


func test_every_face_is_clockwise_from_outside() -> void:
	var surface: ChunkSurfaceArrays = _opaque(_single_block_chunk(BlockTable.STONE))

	for face: int in surface.face_count:
		var first: Vector3 = surface.vertices[surface.indices[face * 6]]
		var second: Vector3 = surface.vertices[surface.indices[face * 6 + 1]]
		var third: Vector3 = surface.vertices[surface.indices[face * 6 + 2]]
		var cross: Vector3 = (second - first).cross(third - first)
		assert_float(cross.dot(surface.normals[face * 4])).is_less(0.0)


func test_faces_sit_on_the_block_position() -> void:
	var surface: ChunkSurfaceArrays = _opaque(_single_block_chunk(BlockTable.STONE))

	for vertex: Vector3 in surface.vertices:
		assert_bool(vertex.x == 5.0 or vertex.x == 6.0).is_true()
		assert_bool(vertex.y == 10.0 or vertex.y == 11.0).is_true()
		assert_bool(vertex.z == 7.0 or vertex.z == 8.0).is_true()


func test_each_face_samples_its_own_atlas_tile() -> void:
	var surface: ChunkSurfaceArrays = _opaque(_single_block_chunk(BlockTable.GRASS))

	for face: int in ChunkMesher.FACES:
		var expected_tile: int = BlockTable.TILE_GRASS_SIDE
		if face == ChunkMesher.FACE_POS_Y:
			expected_tile = BlockTable.TILE_GRASS_TOP
		elif face == ChunkMesher.FACE_NEG_Y:
			expected_tile = BlockTable.TILE_DIRT
		var origin: Vector2 = BlockTable.tile_uv_origin(expected_tile)
		var far_corner: Vector2 = origin + Vector2.ONE * BlockTable.ATLAS_TILE_UV
		assert_vector(surface.uvs[face * 4]).is_equal(origin)
		assert_vector(surface.uvs[face * 4 + 2]).is_equal(far_corner)


func test_mesh_has_one_surface_when_nothing_is_transparent() -> void:
	assert_int(_mesher.build_mesh(_single_block_chunk(BlockTable.STONE)).get_surface_count()).is_equal(1)


func test_mesh_has_a_second_surface_for_transparent_blocks() -> void:
	var chunk: ChunkData = ChunkData.new()
	chunk.set_block(5, 10, 7, BlockTable.STONE)
	chunk.set_block(9, 10, 7, BlockTable.LEAVES)

	assert_int(_mesher.build_mesh(chunk).get_surface_count()).is_equal(2)


func test_empty_chunk_builds_a_mesh_without_surfaces() -> void:
	assert_int(_mesher.build_mesh(ChunkData.new()).get_surface_count()).is_equal(0)
