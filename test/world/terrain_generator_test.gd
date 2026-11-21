extends GdUnitTestSuite


func _generated(world_seed: int, chunk_x: int, chunk_z: int) -> ChunkData:
	var chunk: ChunkData = ChunkData.new()
	TerrainGenerator.new(world_seed).fill_chunk(chunk, chunk_x, chunk_z)
	return chunk


func test_same_seed_generates_the_same_chunk() -> void:
	assert_bool(_generated(42, 3, 5).blocks == _generated(42, 3, 5).blocks).is_true()


func test_different_seed_generates_a_different_chunk() -> void:
	assert_bool(_generated(42, 3, 5).blocks == _generated(43, 3, 5).blocks).is_false()


func test_column_is_stone_then_three_dirt_then_grass() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(42, TerrainGenerator.VERSION_MVP)
	var chunk: ChunkData = ChunkData.new()
	generator.fill_chunk(chunk, 0, 0)
	var height: int = generator.height_at(4, 9)

	assert_int(chunk.get_block(4, height + 1, 9)).is_equal(BlockTable.AIR)
	assert_int(chunk.get_block(4, height, 9)).is_equal(BlockTable.GRASS)
	assert_int(chunk.get_block(4, height - 1, 9)).is_equal(BlockTable.DIRT)
	assert_int(chunk.get_block(4, height - 3, 9)).is_equal(BlockTable.DIRT)
	assert_int(chunk.get_block(4, height - 4, 9)).is_equal(BlockTable.STONE)
	assert_int(chunk.get_block(4, 0, 9)).is_equal(BlockTable.STONE)


func test_height_stays_inside_the_chunk() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(7)

	for z: int in range(0, 256, 8):
		for x: int in range(0, 256, 8):
			assert_int(generator.height_at(x, z)).is_between(1, ChunkData.SIZE_Y - 1)


func test_neighboring_chunks_use_continuous_world_coordinates() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(42, TerrainGenerator.VERSION_MVP)
	var chunk: ChunkData = ChunkData.new()
	generator.fill_chunk(chunk, 1, 2)
	var height: int = generator.height_at(16 + 5, 32 + 6)

	assert_int(chunk.get_block(5, height, 6)).is_equal(BlockTable.GRASS)


func _world(world_seed: int, version: int) -> WorldData:
	var data: WorldData = WorldData.new(4, 4)
	var generator: TerrainGenerator = TerrainGenerator.new(world_seed, version)
	for index: int in data.chunks.size():
		var coords: Vector2i = data.coords_of(index)
		generator.fill_chunk(data.chunks[index], coords.x, coords.y)
	return data


func _trees(generator: TerrainGenerator, cells: int) -> Array[Vector4i]:
	var trees: Array[Vector4i] = []
	for cell_z: int in cells:
		for cell_x: int in cells:
			var tree: Vector4i = generator.tree_in_cell(cell_x, cell_z)
			if tree.w > 0:
				trees.append(tree)
	return trees


func test_mvp_terrain_has_no_trees_and_no_sand() -> void:
	var bytes: PackedByteArray = _world(1234, TerrainGenerator.VERSION_MVP).to_bytes()

	assert_int(bytes.count(BlockTable.LOG)).is_equal(0)
	assert_int(bytes.count(BlockTable.LEAVES)).is_equal(0)
	assert_int(bytes.count(BlockTable.SAND)).is_equal(0)


func test_new_terrain_has_trees_and_sand() -> void:
	var bytes: PackedByteArray = _world(1234, TerrainGenerator.LATEST_VERSION).to_bytes()

	assert_int(bytes.count(BlockTable.LOG)).is_greater(20)
	assert_int(bytes.count(BlockTable.LEAVES)).is_greater(200)
	assert_int(bytes.count(BlockTable.SAND)).is_greater(0)


func test_low_columns_are_sand_down_to_the_stone() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(1234)
	var data: WorldData = _world(1234, TerrainGenerator.LATEST_VERSION)
	var found: int = 0
	for z: int in 64:
		for x: int in 64:
			var height: int = generator.height_at(x, z)
			if height <= TerrainGenerator.SAND_HEIGHT and data.get_block_world(x, height + 1, z) == BlockTable.AIR:
				found += 1
				assert_int(data.get_block_world(x, height, z)).is_equal(BlockTable.SAND)
				assert_int(data.get_block_world(x, height - 3, z)).is_equal(BlockTable.SAND)
				assert_int(data.get_block_world(x, height - 4, z)).is_equal(BlockTable.STONE)
	assert_int(found).is_greater(0)


func test_every_tree_is_whole_even_across_chunk_borders() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(1234)
	var data: WorldData = _world(1234, TerrainGenerator.LATEST_VERSION)
	var crossing: int = 0
	# Cells fully inside the 64 x 64 world, so no crown is cut by its edge.
	for tree: Vector4i in _trees(generator, 10):
		if tree.x < 2 or tree.z < 2 or tree.x > 61 or tree.z > 61:
			continue
		if tree.x % 16 < 2 or tree.x % 16 > 13 or tree.z % 16 < 2 or tree.z % 16 > 13:
			crossing += 1
		var top: int = tree.y + tree.w
		assert_int(data.get_block_world(tree.x, tree.y, tree.z)).is_equal(BlockTable.DIRT)
		for y: int in range(tree.y + 1, top + 1):
			assert_int(data.get_block_world(tree.x, y, tree.z)).is_equal(BlockTable.LOG)
		assert_int(data.get_block_world(tree.x, top + 2, tree.z)).is_in([BlockTable.LEAVES, BlockTable.LOG])
		for offset_z: int in range(-2, 3):
			for offset_x: int in range(-2, 3):
				if absi(offset_x) == 2 and absi(offset_z) == 2:
					continue
				var block: int = data.get_block_world(tree.x + offset_x, top, tree.z + offset_z)
				assert_int(block).is_in([BlockTable.LEAVES, BlockTable.LOG])
	assert_int(crossing).is_greater(0)


func test_trunks_are_at_least_three_columns_apart() -> void:
	var trees: Array[Vector4i] = _trees(TerrainGenerator.new(1234), 20)

	for first: int in trees.size():
		for second: int in range(first + 1, trees.size()):
			var gap: Vector2i = Vector2i(trees[first].x - trees[second].x, trees[first].z - trees[second].z)
			assert_int(maxi(absi(gap.x), absi(gap.y))).is_greater_equal(3)


func test_no_tree_grows_on_sand() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(1234)

	for tree: Vector4i in _trees(generator, 40):
		assert_int(tree.y).is_greater(TerrainGenerator.SAND_HEIGHT)
