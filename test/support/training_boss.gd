class_name TrainingBoss
extends Boss

## A boss for the tests: a box around its position that counts the blows.

var size: Vector3 = Vector3.ONE
var hittable: bool = true
var damage_taken: int = 0
var blows: int = 0


func hitbox() -> AABB:
	return AABB(global_position - size * 0.5, size)


func is_hittable() -> bool:
	return hittable


func take_hit(damage: int) -> int:
	blows += 1
	damage_taken += damage
	return damage
