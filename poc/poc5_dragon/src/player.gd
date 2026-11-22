class_name Player
extends CharacterBody3D

const LOOK_SPEED: float = 0.003
const MAX_PITCH: float = 1.5
## Horizontal push lost every second after a blow.
const PUSH_DECAY: float = 18.0

## When false, [member wish_move] and [member wish_jump] are set from code.
@export var human_controlled: bool = false

## X moves along view right, Y moves forward.
var wish_move: Vector2 = Vector2.ZERO
var wish_jump: bool = false
var yaw: float = 0.0
var pitch: float = 0.0

var _push: Vector3 = Vector3.ZERO
var _lift: float = 0.0

@onready var _head: Node3D = $Head


func _physics_process(delta: float) -> void:
	if human_controlled:
		_read_keyboard()
	velocity = PlayerMotion.next_velocity(velocity, _wish_direction(), is_on_floor(), wish_jump, delta)
	if _lift > 0.0:
		velocity.y = _lift
		_lift = 0.0
	velocity += _push
	_push = _push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if human_controlled and motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		set_look(yaw - motion.relative.x * LOOK_SPEED, pitch - motion.relative.y * LOOK_SPEED)


## Knocks the player back: the horizontal part fades, the vertical part is a jump.
func push(impulse: Vector3) -> void:
	_push = Vector3(impulse.x, 0.0, impulse.z)
	_lift = impulse.y


func teleport(feet: Vector3) -> void:
	global_position = feet
	velocity = Vector3.ZERO
	_push = Vector3.ZERO
	_lift = 0.0


func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, -MAX_PITCH, MAX_PITCH)
	_head.rotation = Vector3(pitch, yaw, 0.0)


func look_at_point(point: Vector3) -> void:
	var offset: Vector3 = point - eye_position()
	var flat: float = Vector2(offset.x, offset.z).length()
	set_look(atan2(-offset.x, -offset.z), atan2(offset.y, flat))


func eye_position() -> Vector3:
	return _head.global_position


func view_direction() -> Vector3:
	return -_head.global_basis.z


func _read_keyboard() -> void:
	wish_move = Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	)
	wish_jump = Input.is_physical_key_pressed(KEY_SPACE)


func _wish_direction() -> Vector3:
	return Vector3(wish_move.x, 0.0, -wish_move.y).limit_length(1.0).rotated(Vector3.UP, yaw)
