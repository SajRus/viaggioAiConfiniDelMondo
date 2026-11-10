class_name ChunkNode
extends StaticBody3D

var face_count: int = 0
var last_mesh_usec: int = 0
var last_collision_usec: int = 0

var _mesh_instance: MeshInstance3D = MeshInstance3D.new()
var _collision: CollisionShape3D = CollisionShape3D.new()


func _init(material: Material) -> void:
	_mesh_instance.material_override = material
	add_child(_mesh_instance)
	add_child(_collision)


func rebuild(mesher: ChunkMesher, chunk: ChunkData) -> void:
	var start: int = Time.get_ticks_usec()
	var surfaces: Array[ChunkSurfaceArrays] = mesher.build_surfaces(chunk)
	_mesh_instance.mesh = ChunkMesher.mesh_from_surfaces(surfaces)
	var after_mesh: int = Time.get_ticks_usec()
	var faces: PackedVector3Array = ChunkCollision.build_faces(surfaces)
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	_collision.shape = shape
	_collision.disabled = faces.is_empty()
	last_mesh_usec = after_mesh - start
	last_collision_usec = Time.get_ticks_usec() - after_mesh
	face_count = 0
	for surface: ChunkSurfaceArrays in surfaces:
		face_count += surface.face_count
