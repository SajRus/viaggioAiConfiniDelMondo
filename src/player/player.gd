class_name Player
extends CharacterBody3D

const HALF_WIDTH: float = 0.3
const HEIGHT: float = 1.8
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


## Box of a player standing at [param feet], shrunk by [param tolerance] per side.
static func box_at(feet: Vector3, tolerance: float) -> AABB:
	var corner: Vector3 = feet - Vector3(HALF_WIDTH, 0.0, HALF_WIDTH)
	return AABB(corner, Vector3(HALF_WIDTH * 2.0, HEIGHT, HALF_WIDTH * 2.0)).grow(-tolerance)


func _physics_process(delta: float) -> void:
	if human_controlled:
		_read_keyboard()
	velocity = PlayerMotion.next_velocity(velocity, _wish_direction(), is_on_floor(), wish_jump, delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not human_controlled:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
