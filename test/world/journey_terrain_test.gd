extends GdUnitTestSuite

## Terrain version 3 on a full 16 x 16 chunk world, generated chunk by chunk as
## the game does, so every building is checked across chunk borders too.

const SEEDS: Array[int] = [1, 1234, 98765]
const WORLD_CHUNKS: int = 16
const WORLD_SIZE: int = WORLD_CHUNKS * ChunkData.SIZE_X

var _generators: Array[TerrainGenerator] = []
var _worlds: Array[WorldData] = []


func before() -> void:
	for world_seed: int in SEEDS:
		var generator: TerrainGenerator = TerrainGenerator.new(world_seed, TerrainGenerator.VERSION_JOURNEY, WORLD_SIZE)
		var data: WorldData = WorldData.new(WORLD_CHUNKS, WORLD_CHUNKS)
		for index: int in data.chunks.size():
			var coords: Vector2i = data.coords_of(index)
			generator.fill_chunk(data.chunks[index], coords.x, coords.y)
		_generators.append(generator)
		_worlds.append(data)


func test_shrines_stand_on_a_circle_sixty_degrees_apart_from_the_north() -> void:
	var gems: Array[Vector3i] = _generators[0].shrine_gems
	var middle: Vector2 = Vector2.ONE * (WORLD_SIZE >> 1)

	assert_int(gems.size()).is_equal(6)
	assert_int(gems[0].x).is_equal(128)
	assert_int(gems[0].z).is_equal(64)
	assert_int(gems[3].x).is_equal(128)
	assert_int(gems[3].z).is_equal(192)
	for gem: Vector3i in gems:
		assert_float(Vector2(gem.x, gem.z).distance_to(middle)).is_equal_approx(64.0, 1.0)
	# North-east is east of the middle, north-west west of it.
	assert_int(gems[1].x).is_greater(128)
	assert_int(gems[5].x).is_less(128)


func test_each_shrine_holds_its_gem_block_in_a_closed_room() -> void:
	for world: int in SEEDS.size():
		var data: WorldData = _worlds[world]
		for index: int in TerrainGenerator.SHRINES:
			var gem: Vector3i = _generators[world].shrine_gems[index]
			assert_int(data.get_block_world(gem.x, gem.y, gem.z)).is_equal(BlockTable.GEM_RUBY + index)
			for y: int in range(gem.y, gem.y + 4):
				for z: int in range(gem.z - 3, gem.z + 4):
					for x: int in range(gem.x - 3, gem.x + 4):
						if Vector3i(x, y, z) != gem:
							assert_int(data.get_block_world(x, y, z)).is_equal(BlockTable.AIR)
			for offset: int in range(-4, 5):
				assert_int(data.get_block_world(gem.x + offset, gem.y - 1, gem.z)).is_equal(BlockTable.STONE_BRICKS)
				assert_int(data.get_block_world(gem.x + offset, gem.y + 4, gem.z)).is_equal(BlockTable.STONE_BRICKS)
				assert_int(data.get_block_world(gem.x - 4, gem.y + 1, gem.z + offset)).is_equal(BlockTable.STONE_BRICKS)
				assert_int(data.get_block_world(gem.x + offset, gem.y + 1, gem.z - 4)).is_equal(BlockTable.STONE_BRICKS)


func test_rooms_lie_ten_to_fifteen_blocks_under_the_surface() -> void:
	for world: int in SEEDS.size():
		var generator: TerrainGenerator = _generators[world]
		for gem: Vector3i in generator.shrine_gems:
			var depth: int = generator.height_at(gem.x, gem.z) - gem.y
			if gem.y > TerrainGenerator.LOWEST_FLOOR:
				assert_int(depth).is_between(10, 15)
			else:
				assert_int(depth).is_less_equal(15)


func test_a_stair_climbs_from_the_east_door_to_the_surface() -> void:
	for world: int in SEEDS.size():
		var data: WorldData = _worlds[world]
		var generator: TerrainGenerator = _generators[world]
		for gem: Vector3i in generator.shrine_gems:
			var x: int = gem.x + 4
			var level: int = gem.y
			# Walk up one block per column until the step is above the ground.
			while level <= generator.height_at(x, gem.z):
				assert_int(data.get_block_world(x, level - 1, gem.z)).is_equal(BlockTable.STONE_BRICKS)
				for y: int in range(level, level + 4):
					assert_int(data.get_block_world(x, y, gem.z)).is_equal(BlockTable.AIR)
				x += 1
				level += 1
				assert_int(x - gem.x).is_less(4 + ChunkData.SIZE_Y)
			assert_int(data.get_block_world(x, level - 1, gem.z)).is_equal(BlockTable.STONE_BRICKS)
			for y: int in range(level, level + 4):
				assert_int(data.get_block_world(x, y, gem.z)).is_equal(BlockTable.AIR)


func test_an_obelisk_of_five_bricks_stands_over_each_shrine() -> void:
	var data: WorldData = _worlds[0]
	var generator: TerrainGenerator = _generators[0]
	for gem: Vector3i in generator.shrine_gems:
		var ground: int = generator.height_at(gem.x, gem.z)
		for y: int in range(ground + 1, ground + 6):
			assert_int(data.get_block_world(gem.x, y, gem.z)).is_equal(BlockTable.STONE_BRICKS)
		assert_int(data.get_block_world(gem.x, ground + 6, gem.z)).is_not_equal(BlockTable.STONE_BRICKS)


func test_the_arena_is_a_flat_open_platform_on_the_east_edge() -> void:
	for world: int in SEEDS.size():
		var data: WorldData = _worlds[world]
		var center: Vector3i = _generators[world].arena_center
		assert_int(center.x).is_equal(WORLD_SIZE - 1 - 4 - 7)
		assert_int(center.z).is_equal(WORLD_SIZE >> 1)
		for z: int in range(center.z - 7, center.z + 8):
			for x: int in range(center.x - 7, center.x + 8):
				assert_int(data.get_block_world(x, center.y, z)).is_equal(BlockTable.ARENA_STONE)
				assert_int(data.surface_height(x, z)).is_equal(center.y)
				assert_int(data.get_block_world(x, center.y - 1, z)).is_not_equal(BlockTable.AIR)


func test_the_altar_stands_on_a_platform_on_the_west_edge() -> void:
	for world: int in SEEDS.size():
		var data: WorldData = _worlds[world]
		var altar: Vector3i = _generators[world].altar_position
		assert_int(altar.x).is_equal(4 + 3)
		assert_int(altar.z).is_equal(WORLD_SIZE >> 1)
		assert_int(data.get_block_world(altar.x, altar.y, altar.z)).is_equal(BlockTable.ALTAR)
		assert_int(data.get_block_world(altar.x, altar.y + 1, altar.z)).is_equal(BlockTable.AIR)
		for z: int in range(altar.z - 3, altar.z + 4):
			for x: int in range(altar.x - 3, altar.x + 4):
				assert_int(data.get_block_world(x, altar.y - 1, z)).is_equal(BlockTable.STONE_BRICKS)
				if x != altar.x or z != altar.z:
					assert_int(data.surface_height(x, z)).is_equal(altar.y - 1)


## True when a player can walk onto the platform from every column just past
## its slope: up at most 1 block per column, down at most 3.
func _walkable_from_all_around(generator: TerrainGenerator, top: Vector3i, half: int) -> bool:
	var reach: int = half + TerrainGenerator.PLATFORM_BLEND + 1
	var seen: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for z: int in range(top.z - half, top.z + half + 1):
		for x: int in range(top.x - half, top.x + half + 1):
			seen[Vector2i(x, z)] = true
			queue.append(Vector2i(x, z))
	var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for side: Vector2i in sides:
			var from: Vector2i = here + side
			var outside: bool = absi(from.x - top.x) > reach or absi(from.y - top.z) > reach
			if seen.has(from) or outside or from.x < 0 or from.x >= WORLD_SIZE:
				continue
			var climb: int = generator.height_at(here.x, here.y) - generator.height_at(from.x, from.y)
			if climb <= 1 and climb >= -3:
				seen[from] = true
				queue.append(from)
	for z: int in range(top.z - reach, top.z + reach + 1):
		for x: int in range(maxi(0, top.x - reach), mini(WORLD_SIZE - 1, top.x + reach) + 1):
			if maxi(absi(x - top.x), absi(z - top.z)) == reach and not seen.has(Vector2i(x, z)):
				return false
	return true


func test_the_ground_slopes_to_the_platforms_so_they_are_reached_on_foot() -> void:
	for generator: TerrainGenerator in _generators:
		assert_bool(_walkable_from_all_around(generator, generator.arena_center, 7)).is_true()
		var altar_top: Vector3i = generator.altar_position + Vector3i.DOWN
		assert_bool(_walkable_from_all_around(generator, altar_top, 3)).is_true()


func test_the_journey_is_the_same_for_the_same_seed() -> void:
	var again: TerrainGenerator = TerrainGenerator.new(SEEDS[1], TerrainGenerator.VERSION_JOURNEY, WORLD_SIZE)

	assert_array(again.shrine_gems).is_equal(_generators[1].shrine_gems)
	assert_vector(Vector3(again.arena_center)).is_equal(Vector3(_generators[1].arena_center))
	assert_vector(Vector3(again.altar_position)).is_equal(Vector3(_generators[1].altar_position))


func test_older_terrain_versions_have_no_journey() -> void:
	var generator: TerrainGenerator = TerrainGenerator.new(SEEDS[0], TerrainGenerator.VERSION_TREES, WORLD_SIZE)
	var gem: Vector3i = _generators[0].shrine_gems[0]
	var chunk: ChunkData = ChunkData.new()
	generator.fill_chunk(chunk, gem.x >> 4, gem.z >> 4)

	assert_array(generator.shrine_gems).is_empty()
	assert_int(chunk.blocks.count(BlockTable.STONE_BRICKS)).is_equal(0)
	assert_int(chunk.blocks.count(BlockTable.GEM_RUBY)).is_equal(0)


func test_every_world_has_each_gem_block_once_and_one_altar() -> void:
	for data: WorldData in _worlds:
		var bytes: PackedByteArray = data.to_bytes()
		for id: int in range(BlockTable.GEM_RUBY, BlockTable.GEM_AMETHYST + 1):
			assert_int(bytes.count(id)).is_equal(1)
		assert_int(bytes.count(BlockTable.ALTAR)).is_equal(1)
		assert_int(bytes.count(BlockTable.ARENA_STONE)).is_greater_equal(15 * 15)
