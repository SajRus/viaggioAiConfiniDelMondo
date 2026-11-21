extends GdUnitTestSuite

var _mesher: ChunkMesher = ChunkMesher.new(BlockRegistry)


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
	chunk.blocks.fill(BlockTable.STONE)

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


func test_faces_between_two_blocks_of_the_same_glass_are_culled() -> void:
	var positions: Array[Vector3i] = [Vector3i(5, 10, 7), Vector3i(6, 10, 7)]

	assert_int(_transparent(_chunk_with(positions, BlockTable.GLASS)).face_count).is_equal(10)


func test_faces_between_different_transparent_blocks_are_kept() -> void:
	var chunk: ChunkData = ChunkData.new()
	chunk.set_block(5, 10, 7, BlockTable.GLASS)
	chunk.set_block(6, 10, 7, BlockTable.LEAVES)

	assert_int(_transparent(chunk).face_count).is_equal(12)


func test_leaves_across_a_chunk_border_share_no_face() -> void:
	var world: WorldData = WorldData.new(2, 1)
	world.chunk_at(0, 0).set_block(15, 10, 7, BlockTable.LEAVES)
	world.chunk_at(1, 0).set_block(0, 10, 7, BlockTable.LEAVES)

	assert_int(_transparent(world.chunk_at(0, 0)).face_count).is_equal(5)
	assert_int(_transparent(world.chunk_at(1, 0)).face_count).is_equal(5)


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


func _solid_pair() -> WorldData:
	var world: WorldData = WorldData.new(2, 1)
	world.chunk_at(0, 0).blocks.fill(BlockTable.STONE)
	world.chunk_at(1, 0).blocks.fill(BlockTable.STONE)
	return world


func test_shared_border_between_full_chunks_is_culled() -> void:
	var world: WorldData = _solid_pair()
	var faces: int = _opaque(world.chunk_at(0, 0)).face_count + _opaque(world.chunk_at(1, 0)).face_count

	assert_int(faces).is_equal(2 * 32 * 16 + 2 * 32 * 64 + 2 * 16 * 64)


func test_air_in_the_neighbor_keeps_the_border_face() -> void:
	var world: WorldData = WorldData.new(2, 1)
	world.chunk_at(0, 0).set_block(15, 10, 7, BlockTable.STONE)

	assert_int(_opaque(world.chunk_at(0, 0)).face_count).is_equal(6)


func test_block_in_the_neighbor_hides_the_border_face_on_each_axis() -> void:
	var world: WorldData = WorldData.new(2, 2)
	world.chunk_at(0, 0).set_block(15, 10, 15, BlockTable.STONE)
	world.chunk_at(1, 0).set_block(0, 10, 15, BlockTable.STONE)
	world.chunk_at(0, 1).set_block(15, 10, 0, BlockTable.STONE)

	assert_int(_opaque(world.chunk_at(0, 0)).face_count).is_equal(4)
	assert_int(_opaque(world.chunk_at(1, 0)).face_count).is_equal(5)
	assert_int(_opaque(world.chunk_at(0, 1)).face_count).is_equal(5)


func test_glass_in_the_neighbor_keeps_the_border_face() -> void:
	var world: WorldData = WorldData.new(2, 1)
	world.chunk_at(0, 0).set_block(15, 10, 7, BlockTable.STONE)
	world.chunk_at(1, 0).set_block(0, 10, 7, BlockTable.GLASS)

	assert_int(_opaque(world.chunk_at(0, 0)).face_count).is_equal(6)
	assert_int(_transparent(world.chunk_at(1, 0)).face_count).is_equal(5)


func _random_chunk(rng_seed: int) -> ChunkData:
	var chunk: ChunkData = ChunkData.new()
	TerrainGenerator.new(rng_seed).fill_chunk(chunk, 0, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	for _block: int in 400:
		var ids: PackedInt32Array = [BlockTable.AIR, BlockTable.STONE, BlockTable.GLASS, BlockTable.LEAVES]
		chunk.set_block(rng.randi_range(0, 15), rng.randi_range(0, 63), rng.randi_range(0, 15), ids[rng.randi_range(0, 3)])
	return chunk


func test_top_layer_finds_the_highest_block() -> void:
	assert_int(_mesher.top_layer(ChunkData.new())).is_equal(-1)
	assert_int(_mesher.top_layer(_single_block_chunk(BlockTable.STONE))).is_equal(10)


func test_scanning_in_slices_gives_the_same_faces_as_one_scan() -> void:
	for rng_seed: int in [3, 17, 99]:
		var chunk: ChunkData = _random_chunk(rng_seed)
		var whole: PackedInt32Array = _mesher.scan_faces(chunk, 0, ChunkData.SIZE_Y)
		var joined: PackedInt32Array = _mesher.scan_faces(chunk, 0, 7)
		joined.append_array(_mesher.scan_faces(chunk, 7, 30))
		joined.append_array(_mesher.scan_faces(chunk, 30, ChunkData.SIZE_Y))

		assert_bool(joined == whole).is_true()


func test_meshing_job_matches_a_single_threaded_build() -> void:
	var chunk: ChunkData = _random_chunk(5)
	var job: MeshingJob = MeshingJob.new(chunk, _mesher.top_layer(chunk) + 1)
	for slice: ScanSlice in job.slices:
		slice.run(_mesher)

	job.finish(_mesher)

	var expected: Array[ChunkSurfaceArrays] = _mesher.build_surfaces(chunk)
	for surface: int in 2:
		assert_bool(job.surfaces[surface].vertices == expected[surface].vertices).is_true()
		assert_bool(job.surfaces[surface].uvs == expected[surface].uvs).is_true()
		assert_bool(job.surfaces[surface].indices == expected[surface].indices).is_true()
