class_name VoxelProbe
extends RefCounted

const PLAYER_HALF_WIDTH: float = 0.3
const PLAYER_HEIGHT: float = 1.8


## Independent of the physics engine: checks the box against the block grid.
static func box_overlaps_solid(world: WorldData, table: BlockTable, box: AABB) -> bool:
	var low: Vector3i = Vector3i(box.position.floor())
	var high: Vector3i = Vector3i(box.end.floor())
	for y: int in range(low.y, high.y + 1):
		for z: int in range(low.z, high.z + 1):
			for x: int in range(low.x, high.x + 1):
				if table.solid[world.get_block_world(x, y, z)] != 0:
					return true
	return false


## Box of a player standing at [param feet], shrunk by [param tolerance] per side.
static func player_box(feet: Vector3, tolerance: float) -> AABB:
	var corner: Vector3 = feet - Vector3(PLAYER_HALF_WIDTH, 0.0, PLAYER_HALF_WIDTH)
	var size: Vector3 = Vector3(PLAYER_HALF_WIDTH * 2.0, PLAYER_HEIGHT, PLAYER_HALF_WIDTH * 2.0)
	return AABB(corner, size).grow(-tolerance)
