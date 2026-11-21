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

# A visible face is recorded as one int: block index, transparency bit, face.
const ENTRY_FACE_MASK: int = 7
const ENTRY_TRANSPARENT_BIT: int = 8
const ENTRY_INDEX_SHIFT: int = 4
# Block index layout from ChunkData.index_of: 16 x, then 16 z, then y.
const INDEX_X_MASK: int = ChunkData.SIZE_X - 1
const INDEX_Z_SHIFT: int = 4
const INDEX_Z_MASK: int = ChunkData.SIZE_Z - 1
const INDEX_Y_SHIFT: int = 8

var _table: BlockTable
## Atlas UV origin of every block face, at [code]id * FACES + face[/code].
var _face_uvs: PackedVector2Array = PackedVector2Array()
var _corner_uvs: PackedVector2Array = PackedVector2Array()


func _init(table: BlockTable) -> void:
	_table = table
	for id: int in BlockTable.MAX_TYPES:
		for face: int in FACES:
			_face_uvs.append(BlockTable.tile_uv_origin(_tile_for_face(id, face)))
	for corner_uv: Vector2 in CORNER_UVS:
		_corner_uvs.append(corner_uv * BlockTable.ATLAS_TILE_UV)


## Returns one [ChunkSurfaceArrays] per surface: opaque first, then transparent.
func build_surfaces(chunk: ChunkData) -> Array[ChunkSurfaceArrays]:
	return surfaces_from_faces(chunk, scan_faces(chunk, 0, top_layer(chunk) + 1))


## Highest layer that holds a block, or -1 for an empty chunk.
func top_layer(chunk: ChunkData) -> int:
	var layer_size: int = ChunkData.SIZE_X * ChunkData.SIZE_Z
	var top_y: int = ChunkData.SIZE_Y - 1
	while top_y >= 0 and chunk.blocks.slice(top_y * layer_size, (top_y + 1) * layer_size).count(BlockTable.AIR) == layer_size:
		top_y -= 1
	return top_y


## Lists the visible faces of layers [param first_y] to [param end_y] excluded.
## A face shows when its neighbor does not occlude and is not the same block:
## two leaves or two panes of glass side by side share no face.
## Scanning consecutive ranges and joining the lists in order gives the same
## result as one scan. Safe on worker threads: it only reads blocks.
func scan_faces(chunk: ChunkData, first_y: int, end_y: int) -> PackedInt32Array:
	var faces: PackedInt32Array = PackedInt32Array()
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
	var index: int = first_y * step_y - 1
	var last_layer: int = size_y - 1

	for y: int in range(first_y, end_y):
		for z: int in size_z:
			for x: int in size_x:
				index += 1
				var id: int = blocks[index]
				if solid[id] == 0:
					continue
				# Buried blocks are most of a chunk and emit nothing: reject them first.
				if (
					x > 0 and x < max_x and z > 0 and z < max_z and y > 0 and y < last_layer
					and (
						occluding[blocks[index + 1]] & occluding[blocks[index - 1]]
						& occluding[blocks[index + step_z]] & occluding[blocks[index - step_z]]
						& occluding[blocks[index + step_y]] & occluding[blocks[index - step_y]]
					) != 0
				):
					continue
				var entry: int = (index << ENTRY_INDEX_SHIFT) | (transparent[id] * ENTRY_TRANSPARENT_BIT)
				var east: int = BlockTable.AIR
				if x < max_x:
					east = blocks[index + 1]
				elif has_pos_x:
					east = pos_x_blocks[index - border_x]
				if occluding[east] == 0 and east != id:
					faces.append(entry | FACE_POS_X)
				var west: int = BlockTable.AIR
				if x > 0:
					west = blocks[index - 1]
				elif has_neg_x:
					west = neg_x_blocks[index + border_x]
				if occluding[west] == 0 and west != id:
					faces.append(entry | FACE_NEG_X)
				if y == size_y - 1 or (occluding[blocks[index + step_y]] == 0 and blocks[index + step_y] != id):
					faces.append(entry | FACE_POS_Y)
				if y == 0 or (occluding[blocks[index - step_y]] == 0 and blocks[index - step_y] != id):
					faces.append(entry | FACE_NEG_Y)
				var south: int = BlockTable.AIR
				if z < max_z:
					south = blocks[index + step_z]
				elif has_pos_z:
					south = pos_z_blocks[index - border_z]
				if occluding[south] == 0 and south != id:
					faces.append(entry | FACE_POS_Z)
				var north: int = BlockTable.AIR
				if z > 0:
					north = blocks[index - step_z]
				elif has_neg_z:
					north = neg_z_blocks[index + border_z]
				if occluding[north] == 0 and north != id:
					faces.append(entry | FACE_NEG_Z)

	return faces


## Turns a face list from [method scan_faces] into the opaque and transparent surfaces.
func surfaces_from_faces(chunk: ChunkData, faces: PackedInt32Array) -> Array[ChunkSurfaceArrays]:
	var surfaces: Array[ChunkSurfaceArrays] = [
		_surface_from_faces(faces, chunk.blocks, 0),
		_surface_from_faces(faces, chunk.blocks, ENTRY_TRANSPARENT_BIT),
	]
	return surfaces


func build_mesh(chunk: ChunkData) -> ArrayMesh:
	return mesh_from_surfaces(build_surfaces(chunk))


static func mesh_from_surfaces(surfaces: Array[ChunkSurfaceArrays]) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: ChunkSurfaceArrays in surfaces:
		if surface.face_count > 0:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.to_mesh_arrays())
	return mesh


## Writes the faces of one surface into arrays sized once, instead of growing them.
func _surface_from_faces(
	faces: PackedInt32Array, blocks: PackedByteArray, transparent_bit: int
) -> ChunkSurfaceArrays:
	var selected: PackedInt32Array = PackedInt32Array()
	for entry: int in faces:
		if entry & ENTRY_TRANSPARENT_BIT == transparent_bit:
			selected.append(entry)
	var count: int = selected.size()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.resize(count * 4)
	normals.resize(count * 4)
	uvs.resize(count * 4)
	indices.resize(count * 6)
	for face_number: int in count:
		var entry: int = selected[face_number]
		var face: int = entry & ENTRY_FACE_MASK
		var index: int = entry >> ENTRY_INDEX_SHIFT
		var origin: Vector3 = Vector3(
			index & INDEX_X_MASK, index >> INDEX_Y_SHIFT, (index >> INDEX_Z_SHIFT) & INDEX_Z_MASK
		)
		var normal: Vector3 = FACE_NORMALS[face]
		var uv_origin: Vector2 = _face_uvs[blocks[index] * FACES + face]
		var corner: int = face * 4
		var vertex: int = face_number * 4
		for offset: int in 4:
			vertices[vertex + offset] = origin + FACE_CORNERS[corner + offset]
			normals[vertex + offset] = normal
			uvs[vertex + offset] = uv_origin + _corner_uvs[offset]
		var first_index: int = face_number * 6
		indices[first_index] = vertex
		indices[first_index + 1] = vertex + 1
		indices[first_index + 2] = vertex + 2
		indices[first_index + 3] = vertex
		indices[first_index + 4] = vertex + 2
		indices[first_index + 5] = vertex + 3
	var surface: ChunkSurfaceArrays = ChunkSurfaceArrays.new()
	surface.vertices = vertices
	surface.normals = normals
	surface.uvs = uvs
	surface.indices = indices
	surface.face_count = count
	return surface


func _tile_for_face(id: int, face: int) -> int:
	if face == FACE_POS_Y:
		return _table.tile_top[id]
	if face == FACE_NEG_Y:
		return _table.tile_bottom[id]
	return _table.tile_side[id]
