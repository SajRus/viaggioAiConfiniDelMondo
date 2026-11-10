class_name PlayerMotion
extends RefCounted

const WALK_SPEED: float = 5.0
const JUMP_SPEED: float = 8.4
const GRAVITY: float = 24.0
const TERMINAL_SPEED: float = 40.0


static func next_velocity(
	current: Vector3, direction: Vector3, on_floor: bool, wants_jump: bool, delta: float
) -> Vector3:
	var vertical: float = current.y
	if on_floor:
		vertical = JUMP_SPEED if wants_jump else 0.0
	else:
		vertical = maxf(vertical - GRAVITY * delta, -TERMINAL_SPEED)
	return Vector3(direction.x * WALK_SPEED, vertical, direction.z * WALK_SPEED)
