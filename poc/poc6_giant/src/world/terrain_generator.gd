class_name TerrainGenerator
extends RefCounted

## Terrain version 1 is the MVP terrain: grass, dirt and stone. Version 1 saves
## are rebuilt on it, so it never changes. Version 2 adds sand and trees.
const VERSION_MVP: int = 1
const VERSION_TREES: int = 2
const LATEST_VERSION: int = VERSION_TREES

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

var version: int

var _noise: FastNoiseLite = FastNoiseLite.new()
var _seed: int


func _init(world_seed: int, terrain_version: int = LATEST_VERSION) -> void:
	_seed = world_seed
	version = terrain_version
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = NOISE_OCTAVES
	_noise.frequency = NOISE_FREQUENCY


func height_at(world_x: int, world_z: int) -> int:
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
