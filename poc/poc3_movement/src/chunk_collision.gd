class_name ChunkCollision
extends RefCounted


## Expands the mesh surfaces into the triangle list of a [ConcavePolygonShape3D].
static func build_faces(surfaces: Array[ChunkSurfaceArrays]) -> PackedVector3Array:
	var total: int = 0
	for surface: ChunkSurfaceArrays in surfaces:
		total += surface.indices.size()
	var faces: PackedVector3Array = PackedVector3Array()
	faces.resize(total)
	var write: int = 0
	for surface: ChunkSurfaceArrays in surfaces:
		var vertices: PackedVector3Array = surface.vertices
		for vertex_index: int in surface.indices:
			faces[write] = vertices[vertex_index]
			write += 1
	return faces
