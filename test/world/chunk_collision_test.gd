extends GdUnitTestSuite

var _mesher: ChunkMesher = ChunkMesher.new(BlockRegistry)


func test_empty_chunk_has_no_collision_faces() -> void:
	assert_int(ChunkCollision.build_faces(_mesher.build_surfaces(ChunkData.new())).size()).is_equal(0)


func test_each_visible_face_becomes_two_triangles() -> void:
	var chunk: ChunkData = ChunkData.new()
	chunk.set_block(5, 10, 7, BlockTable.STONE)

	assert_int(ChunkCollision.build_faces(_mesher.build_surfaces(chunk)).size()).is_equal(36)


func test_transparent_blocks_also_collide() -> void:
	var chunk: ChunkData = ChunkData.new()
	chunk.set_block(5, 10, 7, BlockTable.GLASS)

	assert_int(ChunkCollision.build_faces(_mesher.build_surfaces(chunk)).size()).is_equal(36)


func test_triangles_keep_the_mesh_vertex_order() -> void:
	var chunk: ChunkData = ChunkData.new()
	chunk.set_block(5, 10, 7, BlockTable.STONE)
	var surfaces: Array[ChunkSurfaceArrays] = _mesher.build_surfaces(chunk)
	var surface: ChunkSurfaceArrays = surfaces[ChunkMesher.SURFACE_OPAQUE]
	var faces: PackedVector3Array = ChunkCollision.build_faces(surfaces)

	for position: int in faces.size():
		assert_vector(faces[position]).is_equal(surface.vertices[surface.indices[position]])
