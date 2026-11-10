class_name VoxelAudit
extends RefCounted


## Counts the faces a correct mesh must have, working on world coordinates
## only, so that chunk borders get no special treatment.
static func expected_face_count(world: WorldData, table: BlockTable) -> int:
	var faces: int = 0
	var size_x: int = world.chunks_x * ChunkData.SIZE_X
	var size_z: int = world.chunks_z * ChunkData.SIZE_Z
	for y: int in ChunkData.SIZE_Y:
		for z: int in size_z:
			for x: int in size_x:
				if table.solid[world.get_block_world(x, y, z)] == 0:
					continue
				for offset: Vector3i in [
					Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD,
				]:
					if table.occluding[world.get_block_world(x + offset.x, y + offset.y, z + offset.z)] == 0:
						faces += 1
	return faces


static func node_matches_chunk(node: ChunkNode, chunk: ChunkData, mesher: ChunkMesher) -> bool:
	return node.collision_faces() == ChunkCollision.build_faces(mesher.build_surfaces(chunk))
