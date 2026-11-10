class_name EditSoak
extends RefCounted

const BORDER_BIAS: float = 0.7
const SEARCH_DEPTH: int = 5
const SEARCH_RISE: int = 3
const EDIT_IDS: PackedInt32Array = [BlockTable.AIR, BlockTable.AIR, BlockTable.STONE, BlockTable.GLASS]


## Applies random edits, favouring chunk borders, and checks each rebuild.
## Returns the number of chunks found out of sync with their data.
static func run(
	world: WorldData, manager: ChunkManager, mesher: ChunkMesher, nodes: Array[ChunkNode], edits: int, soak_seed: int
) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = soak_seed
	var mismatches: int = 0
	for _edit: int in edits:
		var x: int = _random_coordinate(rng)
		var z: int = _random_coordinate(rng)
		var surface: int = world.surface_height(x, z)
		var y: int = clampi(surface + rng.randi_range(-SEARCH_DEPTH, SEARCH_RISE), 0, ChunkData.SIZE_Y - 1)
		manager.set_block(x, y, z, EDIT_IDS[rng.randi_range(0, EDIT_IDS.size() - 1)])
		manager.flush()
		mismatches += _count_mismatches_around(world, mesher, nodes, x, z)
	return mismatches


static func _random_coordinate(rng: RandomNumberGenerator) -> int:
	var chunk: int = rng.randi_range(0, 15)
	var local: int = rng.randi_range(0, WorldData.CHUNK_MASK)
	if rng.randf() < BORDER_BIAS:
		local = WorldData.CHUNK_MASK if rng.randf() < 0.5 else 0
	return (chunk << WorldData.CHUNK_BITS) + local


static func _count_mismatches_around(
	world: WorldData, mesher: ChunkMesher, nodes: Array[ChunkNode], x: int, z: int
) -> int:
	var mismatches: int = 0
	var chunk_x: int = x >> WorldData.CHUNK_BITS
	var chunk_z: int = z >> WorldData.CHUNK_BITS
	for offset_z: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var other_x: int = chunk_x + offset_x
			var other_z: int = chunk_z + offset_z
			if other_x < 0 or other_x >= world.chunks_x or other_z < 0 or other_z >= world.chunks_z:
				continue
			var index: int = other_x + world.chunks_x * other_z
			if not VoxelAudit.node_matches_chunk(nodes[index], world.chunks[index], mesher):
				mismatches += 1
	return mismatches
