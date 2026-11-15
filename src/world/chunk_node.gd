class_name ChunkNode
extends StaticBody3D

var face_count: int = 0

var _mesh_instance: MeshInstance3D = MeshInstance3D.new()
var _collision: CollisionShape3D = CollisionShape3D.new()
var _shape: ConcavePolygonShape3D


func _init(material: Material) -> void:
	_mesh_instance.material_override = material
	add_child(_mesh_instance)
	add_child(_collision)


func rebuild(mesher: ChunkMesher, chunk: ChunkData) -> void:
	var surfaces: Array[ChunkSurfaceArrays] = mesher.build_surfaces(chunk)
	_mesh_instance.mesh = ChunkMesher.mesh_from_surfaces(surfaces)
	var faces: PackedVector3Array = ChunkCollision.build_faces(surfaces)
	_shape = ConcavePolygonShape3D.new()
	_shape.set_faces(faces)
	_collision.shape = _shape
	_collision.disabled = faces.is_empty()
	face_count = 0
	for surface: ChunkSurfaceArrays in surfaces:
		face_count += surface.face_count


func collision_faces() -> PackedVector3Array:
	return _shape.get_faces()
