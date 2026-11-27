class_name Boss
extends Node3D

## A boss the player can strike: the dragon and the world-bearer extend it.

const GROUP: StringName = &"bosses"


func _enter_tree() -> void:
	add_to_group(GROUP)


## The box a blow must reach, in world coordinates.
func hitbox() -> AABB:
	return AABB(global_position, Vector3.ZERO)


## False while blows pass through, like the dragon in flight.
func is_hittable() -> bool:
	return false


## Returns the damage actually taken.
func take_hit(_damage: int) -> int:
	return 0
