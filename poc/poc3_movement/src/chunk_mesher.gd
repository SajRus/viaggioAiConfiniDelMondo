class_name ChunkMesher
extends RefCounted

const FACE_POS_X: int = 0
const FACE_NEG_X: int = 1
const FACE_POS_Y: int = 2
const FACE_NEG_Y: int = 3
const FACE_POS_Z: int = 4
const FACE_NEG_Z: int = 5
const FACES: int = 6

const FACE_NORMALS: PackedVector3Array = [
	Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD,
]

# Four corners per face, clockwise seen from outside: top-left, top-right,
# bottom-right, bottom-left. Godot treats clockwise triangles as front-facing.
const FACE_CORNERS: PackedVector3Array = [
	Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 1),
	Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(0, 0, 0),
	Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0),
	Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(0, 0, 1),
	Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0),
]

const CORNER_UVS: PackedVector2Array = [
	Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
]

const SURFACE_OPAQUE: int = 0
const SURFACE_TRANSPARENT: int = 1

var _table: BlockTable


func _init(table: BlockTable) -> void:
	_table = table


## Returns one [ChunkSurfaceArrays] per surface: opaque first, then transparent.
func build_surfaces(chunk: ChunkData) -> Array[ChunkSurfaceArrays]:
	var opaque: ChunkSurfaceArrays = ChunkSurfaceArrays.new()
	var see_through: ChunkSurfaceArrays = ChunkSurfaceArrays.new()
	var blocks: PackedByteArray = chunk.blocks
	var solid: PackedByteArray = _table.solid
	var transparent: PackedByteArray = _table.transparent
	var occluding: PackedByteArray = _table.occluding
	var size_x: int = ChunkData.SIZE_X
	var size_y: int = ChunkData.SIZE_Y
	var size_z: int = ChunkData.SIZE_Z
	var step_z: int = size_x
	var step_y: int = size_x * size_z
	var max_x: int = size_x - 1
	var max_z: int = size_z - 1
	var border_x: int = max_x
	var border_z: int = max_z * step_z
	var pos_x: ChunkData = chunk.get_neighbor(ChunkData.SIDE_POS_X)
	var neg_x: ChunkData = chunk.get_neighbor(ChunkData.SIDE_NEG_X)
	var pos_z: ChunkData = chunk.get_neighbor(ChunkData.SIDE_POS_Z)
	var neg_z: ChunkData = chunk.get_neighbor(ChunkData.SIDE_NEG_Z)
	var has_pos_x: bool = pos_x != null
	var has_neg_x: bool = neg_x != null
	var has_pos_z: bool = pos_z != null
	var has_neg_z: bool = neg_z != null
	var pos_x_blocks: PackedByteArray = pos_x.blocks if has_pos_x else PackedByteArray()
	var neg_x_blocks: PackedByteArray = neg_x.blocks if has_neg_x else PackedByteArray()
	var pos_z_blocks: PackedByteArray = pos_z.blocks if has_pos_z else PackedByteArray()
	var neg_z_blocks: PackedByteArray = neg_z.blocks if has_neg_z else PackedByteArray()
	var index: int = -1

	for y: int in size_y:
		for z: int in size_z:
			for x: int in size_x:
				index += 1
				var id: int = blocks[index]
				if solid[id] == 0:
					continue
				var surface: ChunkSurfaceArrays = see_through if transparent[id] != 0 else opaque
				var east: int = BlockTable.AIR
				if x < max_x:
					east = blocks[index + 1]
				elif has_pos_x:
					east = pos_x_blocks[index - border_x]
				if occluding[east] == 0:
					_emit_face(surface, x, y, z, id, FACE_POS_X)
				var west: int = BlockTable.AIR
				if x > 0:
					west = blocks[index - 1]
				elif has_neg_x:
					west = neg_x_blocks[index + border_x]
				if occluding[west] == 0:
					_emit_face(surface, x, y, z, id, FACE_NEG_X)
				if y == size_y - 1 or occluding[blocks[index + step_y]] == 0:
					_emit_face(surface, x, y, z, id, FACE_POS_Y)
				if y == 0 or occluding[blocks[index - step_y]] == 0:
					_emit_face(surface, x, y, z, id, FACE_NEG_Y)
				var south: int = BlockTable.AIR
				if z < max_z:
					south = blocks[index + step_z]
				elif has_pos_z:
					south = pos_z_blocks[index - border_z]
				if occluding[south] == 0:
					_emit_face(surface, x, y, z, id, FACE_POS_Z)
				var north: int = BlockTable.AIR
				if z > 0:
					north = blocks[index - step_z]
				elif has_neg_z:
					north = neg_z_blocks[index + border_z]
				if occluding[north] == 0:
					_emit_face(surface, x, y, z, id, FACE_NEG_Z)

	var surfaces: Array[ChunkSurfaceArrays] = [opaque, see_through]
	return surfaces


func build_mesh(chunk: ChunkData) -> ArrayMesh:
	return mesh_from_surfaces(build_surfaces(chunk))


static func mesh_from_surfaces(surfaces: Array[ChunkSurfaceArrays]) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: ChunkSurfaceArrays in surfaces:
		if surface.face_count > 0:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.to_mesh_arrays())
	return mesh


func _emit_face(surface: ChunkSurfaceArrays, x: int, y: int, z: int, id: int, face: int) -> void:
	var origin: Vector3 = Vector3(x, y, z)
	var normal: Vector3 = FACE_NORMALS[face]
	var tile_origin: Vector2 = BlockTable.tile_uv_origin(_tile_for_face(id, face))
	var base: int = surface.vertices.size()
	var corner_start: int = face * 4
	for corner: int in 4:
		surface.vertices.append(origin + FACE_CORNERS[corner_start + corner])
		surface.normals.append(normal)
		surface.uvs.append(tile_origin + CORNER_UVS[corner] * BlockTable.ATLAS_TILE_UV)
	surface.indices.append(base)
	surface.indices.append(base + 1)
	surface.indices.append(base + 2)
	surface.indices.append(base)
	surface.indices.append(base + 2)
	surface.indices.append(base + 3)
	surface.face_count += 1


func _tile_for_face(id: int, face: int) -> int:
	if face == FACE_POS_Y:
		return _table.tile_top[id]
	if face == FACE_NEG_Y:
		return _table.tile_bottom[id]
	return _table.tile_side[id]
