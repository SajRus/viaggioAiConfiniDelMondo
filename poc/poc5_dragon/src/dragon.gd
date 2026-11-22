class_name Dragon
extends Node3D

## The dragon on screen: coloured boxes that follow a [DragonBrain].

const COLOR_BODY: Color = Color(0.28, 0.22, 0.38)
const COLOR_WING: Color = Color(0.45, 0.35, 0.6)
const COLOR_EYES: Color = Color(1.0, 0.85, 0.2)
const COLOR_FLASH: Color = Color(1.0, 0.25, 0.25)
const FLASH_SECONDS: float = 0.15
const FLAP_SPEED: float = 7.0
const FLAP_ANGLE: float = 0.6
## Lowered just enough that the tip stays above the feet.
const FOLDED_ANGLE: float = -0.35
const MIN_TURN_SPEED: float = 0.1

var brain: DragonBrain

var _body_material: StandardMaterial3D = _material(COLOR_BODY)
var _left_wing: Node3D
var _right_wing: Node3D
var _flap_time: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	var wing_material: StandardMaterial3D = _material(COLOR_WING)
	# Facing -Z, like the camera. Heights from the feet.
	_add_box(Vector3(1.6, 1.2, 3.0), Vector3(0.0, 1.0, 0.0), _body_material)
	_add_box(Vector3(0.8, 0.8, 1.0), Vector3(0.0, 1.6, -1.8), _body_material)
	_add_box(Vector3(1.0, 0.8, 1.2), Vector3(0.0, 2.0, -2.6), _body_material)
	_add_box(Vector3(0.7, 0.2, 0.2), Vector3(0.0, 2.2, -3.2), _material(COLOR_EYES))
	_add_box(Vector3(0.6, 0.5, 2.4), Vector3(0.0, 0.9, 2.6), _body_material)
	for leg: Vector3 in [Vector3(-0.6, 0.3, -0.9), Vector3(0.6, 0.3, -0.9), Vector3(-0.6, 0.3, 0.9), Vector3(0.6, 0.3, 0.9)]:
		_add_box(Vector3(0.4, 0.6, 0.4), leg, _body_material)
	_left_wing = _add_wing(-1.0, wing_material)
	_right_wing = _add_wing(1.0, wing_material)


func flash() -> void:
	_flash_left = FLASH_SECONDS


func _process(delta: float) -> void:
	if brain == null:
		return
	global_position = brain.position
	var flat: Vector2 = Vector2(brain.velocity.x, brain.velocity.z)
	if flat.length() > MIN_TURN_SPEED:
		rotation.y = atan2(-flat.x, -flat.y)
	var climbing: bool = brain.state == DragonBrain.State.DIVING or brain.state == DragonBrain.State.RISING
	rotation.x = atan2(brain.velocity.y, maxf(flat.length(), MIN_TURN_SPEED)) if climbing else 0.0
	var wing_angle: float = FOLDED_ANGLE
	if brain.state == DragonBrain.State.CIRCLING or brain.state == DragonBrain.State.RISING:
		_flap_time += delta
		wing_angle = sin(_flap_time * FLAP_SPEED) * FLAP_ANGLE
	elif brain.state == DragonBrain.State.DIVING:
		wing_angle = 0.3
	_left_wing.rotation.z = -wing_angle
	_right_wing.rotation.z = wing_angle
	_flash_left = maxf(0.0, _flash_left - delta)
	_body_material.albedo_color = COLOR_FLASH if _flash_left > 0.0 else COLOR_BODY
	visible = brain.state != DragonBrain.State.DEFEATED or _flash_left > 0.0


func _add_box(size: Vector3, center: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
	return instance


## A wing hinged on the body's side; [param side] is -1 for the left, 1 for the right.
func _add_wing(side: float, material: Material) -> Node3D:
	var hinge: Node3D = Node3D.new()
	hinge.position = Vector3(side * 0.8, 1.4, -0.2)
	add_child(hinge)
	_add_box(Vector3(3.2, 0.15, 1.8), Vector3(side * 1.6, 0.0, 0.0), material, hinge)
	return hinge


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
