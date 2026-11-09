class_name ObstacleCourse
extends RefCounted

const PILLARS: int = 160
const SHELTERS: int = 90
const PILLAR_HEIGHT: int = 3
const SHELTER_CLEARANCE: int = 2
const SHELTER_SPAN: int = 3


## Adds pillars and two-block-high shelters, to exercise edges and low ceilings.
static func add_to(world: WorldData, course_seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = course_seed
	var limit: int = world.chunks_x * ChunkData.SIZE_X - SHELTER_SPAN
	for _pillar: int in PILLARS:
		_add_pillar(world, rng.randi_range(0, limit), rng.randi_range(0, limit))
	for _shelter: int in SHELTERS:
		_add_shelter(world, rng.randi_range(0, limit), rng.randi_range(0, limit))


static func _add_pillar(world: WorldData, x: int, z: int) -> void:
	var base: int = world.surface_height(x, z)
	for y: int in range(base + 1, base + 1 + PILLAR_HEIGHT):
		world.set_block_world(x, y, z, BlockTable.PLANKS)


static func _add_shelter(world: WorldData, x: int, z: int) -> void:
	var roof: int = world.surface_height(x, z) + SHELTER_CLEARANCE + 1
	for offset_z: int in SHELTER_SPAN:
		for offset_x: int in SHELTER_SPAN:
			world.set_block_world(x + offset_x, roof, z + offset_z, BlockTable.STONE)
	for y: int in range(world.surface_height(x, z) + 1, roof):
		if world.get_block_world(x, y, z) == BlockTable.AIR:
			world.set_block_world(x, y, z, BlockTable.LOG)
