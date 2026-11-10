class_name VoxelRaycast
extends RefCounted

const AXES: int = 3


## Amanatides & Woo grid traversal. Returns null when nothing is in reach.
static func cast_ray(
	world: WorldData, table: BlockTable, origin: Vector3, direction: Vector3, max_distance: float
) -> VoxelHit:
	var unit: Vector3 = direction.normalized()
	if unit == Vector3.ZERO:
		return null
	var block: Vector3i = Vector3i(origin.floor())
	if table.solid[world.get_block_world(block.x, block.y, block.z)] != 0:
		return VoxelHit.new(block, Vector3i.ZERO, 0.0)
	var step: Vector3i = Vector3i.ZERO
	var next_boundary: Vector3 = Vector3.INF
	var boundary_gap: Vector3 = Vector3.INF
	for axis: int in AXES:
		if unit[axis] > 0.0:
			step[axis] = 1
			next_boundary[axis] = (block[axis] + 1.0 - origin[axis]) / unit[axis]
			boundary_gap[axis] = 1.0 / unit[axis]
		elif unit[axis] < 0.0:
			step[axis] = -1
			next_boundary[axis] = (origin[axis] - block[axis]) / -unit[axis]
			boundary_gap[axis] = 1.0 / -unit[axis]
	while true:
		var axis: int = next_boundary.min_axis_index()
		var distance: float = next_boundary[axis]
		if distance > max_distance:
			return null
		block[axis] += step[axis]
		next_boundary[axis] += boundary_gap[axis]
		if table.solid[world.get_block_world(block.x, block.y, block.z)] != 0:
			var normal: Vector3i = Vector3i.ZERO
			normal[axis] = -step[axis]
			return VoxelHit.new(block, normal, distance)
	return null
