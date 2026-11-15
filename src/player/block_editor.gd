class_name BlockEditor
extends RefCounted


static func break_block(manager: ChunkManager, hit: VoxelHit) -> bool:
	if hit == null:
		return false
	return manager.set_block(hit.block.x, hit.block.y, hit.block.z, BlockTable.AIR)


## Places on the hit face. Refuses a block that would overlap the player.
static func place_block(manager: ChunkManager, hit: VoxelHit, id: int, player_feet: Vector3) -> bool:
	if hit == null or hit.normal == Vector3i.ZERO:
		return false
	var target: Vector3i = hit.block + hit.normal
	if manager.get_block(target.x, target.y, target.z) != BlockTable.AIR:
		return false
	if Player.box_at(player_feet, 0.0).intersects(AABB(Vector3(target), Vector3.ONE)):
		return false
	return manager.set_block(target.x, target.y, target.z, id)
