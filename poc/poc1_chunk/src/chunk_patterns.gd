class_name ChunkPatterns
extends RefCounted

const BASE_HEIGHT: int = 20
const DIRT_LAYERS: int = 3
const SAMPLE_TYPES: PackedInt32Array = [
	BlockTable.GRASS, BlockTable.DIRT, BlockTable.STONE, BlockTable.SAND,
	BlockTable.LOG, BlockTable.LEAVES, BlockTable.PLANKS, BlockTable.GLASS,
]


## Rolling terrain with a pillar of each block type. Fixed, not noise based:
## the world generator belongs to PoC 2.
static func fill_hills(chunk: ChunkData) -> void:
	for z: int in ChunkData.SIZE_Z:
		for x: int in ChunkData.SIZE_X:
			var height: int = _hill_height(x, z)
			for y: int in height + 1:
				chunk.set_block(x, y, z, _terrain_block(y, height))
	for sample: int in SAMPLE_TYPES.size():
		var x: int = sample * 2
		var height: int = _hill_height(x, 2)
		for y: int in range(height + 1, height + 5):
			chunk.set_block(x, y, 2, SAMPLE_TYPES[sample])


static func fill_solid(chunk: ChunkData) -> void:
	chunk.blocks.fill(BlockTable.STONE)


## Worst case for face count: every block exposes all six faces.
static func fill_checkerboard(chunk: ChunkData) -> void:
	for y: int in ChunkData.SIZE_Y:
		for z: int in ChunkData.SIZE_Z:
			for x: int in ChunkData.SIZE_X:
				var id: int = BlockTable.STONE if (x + y + z) % 2 == 0 else BlockTable.AIR
				chunk.set_block(x, y, z, id)


static func _hill_height(x: int, z: int) -> int:
	return BASE_HEIGHT + roundi(6.0 * sin(x * 0.5) + 4.0 * cos(z * 0.35))


static func _terrain_block(y: int, height: int) -> int:
	if y == height:
		return BlockTable.GRASS
	if y >= height - DIRT_LAYERS:
		return BlockTable.DIRT
	return BlockTable.STONE
