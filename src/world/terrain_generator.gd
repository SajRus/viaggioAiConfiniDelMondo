class_name TerrainGenerator
extends RefCounted

const BASE_HEIGHT: int = 30
const HEIGHT_AMPLITUDE: float = 22.0
const DIRT_LAYERS: int = 3
const NOISE_FREQUENCY: float = 0.012
const NOISE_OCTAVES: int = 4

var _noise: FastNoiseLite = FastNoiseLite.new()


func _init(world_seed: int) -> void:
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = NOISE_OCTAVES
	_noise.frequency = NOISE_FREQUENCY


func height_at(world_x: int, world_z: int) -> int:
	var height: int = BASE_HEIGHT + roundi(_noise.get_noise_2d(world_x, world_z) * HEIGHT_AMPLITUDE)
	return clampi(height, 1, ChunkData.SIZE_Y - 1)


func fill_chunk(chunk: ChunkData, chunk_x: int, chunk_z: int) -> void:
	var blocks: PackedByteArray = chunk.blocks
	var step_y: int = ChunkData.SIZE_X * ChunkData.SIZE_Z
	for z: int in ChunkData.SIZE_Z:
		for x: int in ChunkData.SIZE_X:
			var height: int = height_at(chunk_x * ChunkData.SIZE_X + x, chunk_z * ChunkData.SIZE_Z + z)
			var first_dirt: int = height - DIRT_LAYERS
			var index: int = ChunkData.index_of(x, 0, z)
			for y: int in height + 1:
				if y == height:
					blocks[index] = BlockTable.GRASS
				elif y >= first_dirt:
					blocks[index] = BlockTable.DIRT
				else:
					blocks[index] = BlockTable.STONE
				index += step_y
