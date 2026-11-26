class_name TerrainGenerator
extends RefCounted

## Terrain version 1 is the MVP terrain: grass, dirt and stone. Version 1 saves
## are rebuilt on it, so it never changes. Version 2 adds sand and trees,
## version 3 the shrines, the dragon's arena and the altar of the journey.
const VERSION_MVP: int = 1
const VERSION_TREES: int = 2
const VERSION_JOURNEY: int = 3
const LATEST_VERSION: int = VERSION_JOURNEY
const DEFAULT_WORLD_SIZE: int = 256

const BASE_HEIGHT: int = 30
const HEIGHT_AMPLITUDE: float = 22.0
const DIRT_LAYERS: int = 3
const NOISE_FREQUENCY: float = 0.012
const NOISE_OCTAVES: int = 4

## Columns this low are covered with sand instead of grass and dirt.
const SAND_HEIGHT: int = 24
## Trees grow on a grid of cells: at most one tree per cell, never on its edge,
## so two trunks are at least 3 columns apart.
const TREE_CELL: int = 6
const TREE_MARGIN: int = 1
const TREE_CHANCE_PERCENT: int = 45
const TRUNK_MIN: int = 4
const TRUNK_EXTRA: int = 2
const CROWN_RADIUS: int = 2

## Six shrines on a circle, 60 degrees apart, starting from the north (-Z).
const SHRINES: int = 6
## The room is 7 x 4 x 7 blocks inside, with walls of stone bricks.
const ROOM_HALF: int = 3
const ROOM_HEIGHT: int = 4
const ROOM_DEPTH_MIN: int = 10
const ROOM_DEPTH_EXTRA: int = 5
const LOWEST_FLOOR: int = 2
## Room enough to jump from one step to the next.
const STAIR_HEIGHT: int = 4
const OBELISK_HEIGHT: int = 5
const ARENA_HALF: int = 7
const ALTAR_HALF: int = 3
## Blocks between the world edge and the arena or the altar platform.
const EDGE_MARGIN: int = 4
## Around a platform the terrain slopes to its height over this many columns.
const PLATFORM_BLEND: int = 10
const DEPTH_ROLL_Z: int = -1000

var version: int
## Version 3: the gem block of each shrine, from the north clockwise.
var shrine_gems: Array[Vector3i] = []
## Version 3: the top block in the middle of the arena.
var arena_center: Vector3i = Vector3i.ZERO
## Version 3: the altar block.
var altar_position: Vector3i = Vector3i.ZERO

var _noise: FastNoiseLite = FastNoiseLite.new()
var _seed: int
## Steps of each shrine's stair, the door in the wall included.
var _stair_steps: PackedInt32Array = PackedInt32Array()
## The top block in the middle of each platform, with its half width in w.
var _platforms: Array[Vector4i] = []


func _init(world_seed: int, terrain_version: int = LATEST_VERSION, world_size: int = DEFAULT_WORLD_SIZE) -> void:
	_seed = world_seed
	version = terrain_version
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = NOISE_OCTAVES
	_noise.frequency = NOISE_FREQUENCY
	if version >= VERSION_JOURNEY:
		_plan_journey(world_size)


func height_at(world_x: int, world_z: int) -> int:
	var height: int = _noise_height(world_x, world_z)
	for platform: Vector4i in _platforms:
		var distance: int = maxi(absi(world_x - platform.x), absi(world_z - platform.z)) - platform.w
		if distance <= 0:
			return platform.y
		if distance <= PLATFORM_BLEND:
			return roundi(lerpf(platform.y, height, float(distance) / float(PLATFORM_BLEND + 1)))
	return height


func _noise_height(world_x: int, world_z: int) -> int:
	var height: int = BASE_HEIGHT + roundi(_noise.get_noise_2d(world_x, world_z) * HEIGHT_AMPLITUDE)
	return clampi(height, 1, ChunkData.SIZE_Y - 1)


func is_sand_column(height: int) -> bool:
	return version >= VERSION_TREES and height <= SAND_HEIGHT


func fill_chunk(chunk: ChunkData, chunk_x: int, chunk_z: int) -> void:
	var blocks: PackedByteArray = chunk.blocks
	var step_y: int = ChunkData.SIZE_X * ChunkData.SIZE_Z
	for z: int in ChunkData.SIZE_Z:
		for x: int in ChunkData.SIZE_X:
			var height: int = height_at(chunk_x * ChunkData.SIZE_X + x, chunk_z * ChunkData.SIZE_Z + z)
			var first_dirt: int = height - DIRT_LAYERS
			var top: int = BlockTable.SAND if is_sand_column(height) else BlockTable.GRASS
			var under: int = BlockTable.SAND if is_sand_column(height) else BlockTable.DIRT
			var index: int = ChunkData.index_of(x, 0, z)
			for y: int in height + 1:
				if y == height:
					blocks[index] = top
				elif y >= first_dirt:
					blocks[index] = under
				else:
					blocks[index] = BlockTable.STONE
				index += step_y
	if version >= VERSION_TREES:
		_add_trees(chunk, chunk_x, chunk_z)
	if version >= VERSION_JOURNEY:
		_add_journey(chunk, chunk_x * ChunkData.SIZE_X, chunk_z * ChunkData.SIZE_Z)


## Trunk of the tree of a grid cell, as world x, ground height and z, with the
## trunk height in w. W is 0 when the cell has no tree.
func tree_in_cell(cell_x: int, cell_z: int) -> Vector4i:
	var roll: int = _mix(cell_x, cell_z)
	if roll % 100 >= TREE_CHANCE_PERCENT:
		return Vector4i.ZERO
	var span: int = TREE_CELL - TREE_MARGIN * 2
	var x: int = cell_x * TREE_CELL + TREE_MARGIN + (roll >> 8) % span
	var z: int = cell_z * TREE_CELL + TREE_MARGIN + (roll >> 16) % span
	var ground: int = height_at(x, z)
	var trunk: int = TRUNK_MIN + (roll >> 24) % (TRUNK_EXTRA + 1)
	if is_sand_column(ground) or ground + trunk + 2 >= ChunkData.SIZE_Y:
		return Vector4i.ZERO
	return Vector4i(x, ground, z, trunk)


## Every tree whose crown reaches this chunk, so trees cross chunk borders whole.
func _add_trees(chunk: ChunkData, chunk_x: int, chunk_z: int) -> void:
	var min_x: int = chunk_x * ChunkData.SIZE_X
	var min_z: int = chunk_z * ChunkData.SIZE_Z
	var first_cell_x: int = floori(float(min_x - CROWN_RADIUS) / TREE_CELL)
	var last_cell_x: int = floori(float(min_x + ChunkData.SIZE_X - 1 + CROWN_RADIUS) / TREE_CELL)
	var first_cell_z: int = floori(float(min_z - CROWN_RADIUS) / TREE_CELL)
	var last_cell_z: int = floori(float(min_z + ChunkData.SIZE_Z - 1 + CROWN_RADIUS) / TREE_CELL)
	for cell_z: int in range(first_cell_z, last_cell_z + 1):
		for cell_x: int in range(first_cell_x, last_cell_x + 1):
			var tree: Vector4i = tree_in_cell(cell_x, cell_z)
			if tree.w > 0:
				_add_tree(chunk, tree, min_x, min_z)


func _add_tree(chunk: ChunkData, tree: Vector4i, min_x: int, min_z: int) -> void:
	var top: int = tree.y + tree.w
	# Two wide layers below the top of the trunk, then two narrow ones.
	for y: int in range(top - 1, top + 3):
		var radius: int = CROWN_RADIUS if y <= top else 1
		for offset_z: int in range(-radius, radius + 1):
			for offset_x: int in range(-radius, radius + 1):
				var corner: bool = absi(offset_x) == radius and absi(offset_z) == radius
				if corner and (radius == CROWN_RADIUS or y == top + 2):
					continue
				_put_leaf(chunk, tree.x + offset_x - min_x, y, tree.z + offset_z - min_z)
	_put(chunk, tree.x - min_x, tree.y, tree.z - min_z, BlockTable.DIRT)
	for y: int in range(tree.y + 1, top + 1):
		_put(chunk, tree.x - min_x, y, tree.z - min_z, BlockTable.LOG)


## Places the shrines halfway between the middle and the edge, the arena on the
## east edge and the altar on the west edge, where no shrine stands.
func _plan_journey(world_size: int) -> void:
	var middle: int = world_size >> 1
	# The platforms come first: they reshape the ground the shrines are dug in.
	var arena_x: int = world_size - 1 - EDGE_MARGIN - ARENA_HALF
	arena_center = Vector3i(arena_x, _average_height(arena_x, middle, ARENA_HALF), middle)
	var altar_x: int = EDGE_MARGIN + ALTAR_HALF
	altar_position = Vector3i(altar_x, _average_height(altar_x, middle, ALTAR_HALF) + 1, middle)
	_platforms.append(Vector4i(arena_center.x, arena_center.y, arena_center.z, ARENA_HALF))
	_platforms.append(Vector4i(altar_position.x, altar_position.y - 1, altar_position.z, ALTAR_HALF))
	var radius: float = world_size * 0.25
	for index: int in SHRINES:
		var angle: float = TAU * index / SHRINES
		var x: int = middle + roundi(sin(angle) * radius)
		var z: int = middle - roundi(cos(angle) * radius)
		var depth: int = ROOM_DEPTH_MIN + _mix(index, DEPTH_ROLL_Z) % (ROOM_DEPTH_EXTRA + 1)
		var floor_y: int = maxi(LOWEST_FLOOR, height_at(x, z) - depth)
		shrine_gems.append(Vector3i(x, floor_y, z))
		var steps: int = 0
		while steps < ChunkData.SIZE_Y:
			var column: int = x + ROOM_HALF + 1 + steps
			steps += 1
			if floor_y + steps - 1 > height_at(column, z):
				break
		_stair_steps.append(steps)


func _average_height(center_x: int, center_z: int, half: int) -> int:
	var total: int = 0
	for z: int in range(center_z - half, center_z + half + 1):
		for x: int in range(center_x - half, center_x + half + 1):
			total += _noise_height(x, z)
	return roundi(float(total) / float((half * 2 + 1) * (half * 2 + 1)))


## The parts of the journey's buildings that reach the chunk at [param min_x], [param min_z].
func _add_journey(chunk: ChunkData, min_x: int, min_z: int) -> void:
	_add_platform(chunk, min_x, min_z, arena_center, ARENA_HALF, BlockTable.ARENA_STONE)
	var altar_top: Vector3i = altar_position + Vector3i.DOWN
	_add_platform(chunk, min_x, min_z, altar_top, ALTAR_HALF, BlockTable.STONE_BRICKS)
	_box(chunk, min_x, min_z, altar_position, altar_position, BlockTable.ALTAR)
	for index: int in SHRINES:
		var gem: Vector3i = shrine_gems[index]
		var reach: int = ROOM_HALF + 1
		var low: Vector2i = Vector2i(gem.x - reach, gem.z - reach)
		var high: Vector2i = Vector2i(gem.x + reach + _stair_steps[index], gem.z + reach)
		if _touches(min_x, min_z, low, high):
			_add_shrine(chunk, min_x, min_z, index)


func _add_shrine(chunk: ChunkData, min_x: int, min_z: int, index: int) -> void:
	var gem: Vector3i = shrine_gems[index]
	var shell: Vector3i = Vector3i(ROOM_HALF + 1, 0, ROOM_HALF + 1)
	var inside: Vector3i = Vector3i(ROOM_HALF, 0, ROOM_HALF)
	_box(chunk, min_x, min_z, gem - shell + Vector3i.DOWN, gem + shell + Vector3i.UP * ROOM_HEIGHT, BlockTable.STONE_BRICKS)
	_box(chunk, min_x, min_z, gem - inside, gem + inside + Vector3i.UP * (ROOM_HEIGHT - 1), BlockTable.AIR)
	# The first step is the door in the east wall, level with the floor.
	for step: int in _stair_steps[index]:
		var floor_cell: Vector3i = Vector3i(gem.x + ROOM_HALF + 1 + step, gem.y + step - 1, gem.z)
		var ground: int = height_at(floor_cell.x, floor_cell.z)
		var lining_top: int = mini(floor_cell.y + STAIR_HEIGHT + 1, ground)
		var side: Vector3i = Vector3i(0, 0, 1)
		_box(chunk, min_x, min_z, floor_cell - side, Vector3i(floor_cell.x, lining_top, floor_cell.z + 1), BlockTable.STONE_BRICKS)
		_box(chunk, min_x, min_z, floor_cell, floor_cell, BlockTable.STONE_BRICKS)
		_box(chunk, min_x, min_z, floor_cell + Vector3i.UP, floor_cell + Vector3i.UP * STAIR_HEIGHT, BlockTable.AIR)
	_box(chunk, min_x, min_z, gem, gem, BlockTable.GEM_RUBY + index)
	var surface: Vector3i = Vector3i(gem.x, height_at(gem.x, gem.z), gem.z)
	_box(chunk, min_x, min_z, surface + Vector3i.UP, surface + Vector3i.UP * OBELISK_HEIGHT, BlockTable.STONE_BRICKS)


## A square platform on the flattened ground, with its top at [param top] and
## clear of everything above, trees included.
func _add_platform(chunk: ChunkData, min_x: int, min_z: int, top: Vector3i, half: int, id: int) -> void:
	var size: Vector3i = Vector3i(half, 0, half)
	_box(chunk, min_x, min_z, top - size, top + size, id)
	_box(chunk, min_x, min_z, top - size + Vector3i.UP, top + size + Vector3i.UP * ChunkData.SIZE_Y, BlockTable.AIR)


## True when the columns from [param low] to [param high] overlap the chunk.
func _touches(min_x: int, min_z: int, low: Vector2i, high: Vector2i) -> bool:
	return (
		high.x >= min_x and low.x < min_x + ChunkData.SIZE_X
		and high.y >= min_z and low.y < min_z + ChunkData.SIZE_Z
	)


## Fills the world cells from [param from] to [param to], both included, that
## fall inside the chunk at [param min_x], [param min_z].
func _box(chunk: ChunkData, min_x: int, min_z: int, from: Vector3i, to: Vector3i, id: int) -> void:
	for y: int in range(maxi(from.y, 0), mini(to.y, ChunkData.SIZE_Y - 1) + 1):
		for z: int in range(maxi(from.z - min_z, 0), mini(to.z - min_z, ChunkData.SIZE_Z - 1) + 1):
			for x: int in range(maxi(from.x - min_x, 0), mini(to.x - min_x, ChunkData.SIZE_X - 1) + 1):
				chunk.set_block(x, y, z, id)


func _put_leaf(chunk: ChunkData, x: int, y: int, z: int) -> void:
	if _is_local(x, y, z) and chunk.get_block(x, y, z) == BlockTable.AIR:
		chunk.set_block(x, y, z, BlockTable.LEAVES)


func _put(chunk: ChunkData, x: int, y: int, z: int, id: int) -> void:
	if _is_local(x, y, z):
		chunk.set_block(x, y, z, id)


func _is_local(x: int, y: int, z: int) -> bool:
	return (
		x >= 0 and x < ChunkData.SIZE_X and z >= 0 and z < ChunkData.SIZE_Z
		and y >= 0 and y < ChunkData.SIZE_Y
	)


## A non-negative pseudo-random number for a grid cell, fixed by the seed.
func _mix(cell_x: int, cell_z: int) -> int:
	var value: int = _seed ^ (cell_x * 73856093) ^ (cell_z * 19349663)
	value = (value ^ (value >> 33)) * 0x5bd1e995
	value = (value ^ (value >> 33)) * 0x27d4eb2d
	value = value ^ (value >> 33)
	return value & 0x7fffffff
