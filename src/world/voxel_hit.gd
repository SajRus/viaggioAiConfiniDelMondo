class_name VoxelHit
extends RefCounted

var block: Vector3i
## Points out of the face that was hit. Zero when the ray starts inside the block.
var normal: Vector3i
var distance: float


func _init(hit_block: Vector3i, hit_normal: Vector3i, hit_distance: float) -> void:
	block = hit_block
	normal = hit_normal
	distance = hit_distance
