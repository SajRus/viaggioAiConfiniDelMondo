class_name Player
extends CharacterBody3D

const LOOK_SPEED: float = 0.003
const MAX_PITCH: float = 1.5

## When false, [member wish_move] and [member wish_jump] are set from code.
@export var human_controlled: bool = false

## X moves along world or view right, Y moves forward.
var wish_move: Vector2 = Vector2.ZERO
var wish_jump: bool = false
var yaw: float = 0.0
var pitch: float = 0.0

@onready var _head: Node3D = $Head


func _physics_process(delta: float) -> void:
	if human_controlled:
		_read_keyboard()
	velocity = PlayerMotion.next_velocity(velocity, _wish_direction(), is_on_floor(), wish_jump, delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if human_controlled and motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= motion.relative.x * LOOK_SPEED
		pitch = clampf(pitch - motion.relative.y * LOOK_SPEED, -MAX_PITCH, MAX_PITCH)
		_head.rotation = Vector3(pitch, yaw, 0.0)


func _read_keyboard() -> void:
	wish_move = Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	)
	wish_jump = Input.is_physical_key_pressed(KEY_SPACE)


func _wish_direction() -> Vector3:
	return Vector3(wish_move.x, 0.0, -wish_move.y).limit_length(1.0).rotated(Vector3.UP, yaw)
