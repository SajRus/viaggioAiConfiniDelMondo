class_name Giant
extends CharacterBody3D

## The world-bearer: a giant of blocks that walks straight at its target with
## the player's physics, jumps steps of one block and breaks what stops it.

const WALK_SPEED: float = 3.5
const BREAK_SECONDS: float = 0.5
const COLOR_STONE: Color = Color(0.42, 0.38, 0.34)
const COLOR_MOSS: Color = Color(0.3, 0.42, 0.25)
const COLOR_EYES: Color = Color(1.0, 0.55, 0.1)
const STRIDE_SPEED: float = 6.0
const STRIDE_ANGLE: float = 0.5

## Where the giant wants to go: the player's feet.
var goal: Vector3 = Vector3.ZERO
var action: GiantPlanner.Action = GiantPlanner.Action.WALK
var jumps: int = 0
var breaks: int = 0
## Blocks broken, by type.
var broken_types: Dictionary[int, int] = {}

var _world: WorldData
var _manager: ChunkManager
var _planner: GiantPlanner = GiantPlanner.new()
var _break_left: float = 0.0
var _stride: float = 0.0
# Only the model turns: a turned collision box would stick out past the planner's box.
var _model: Node3D = Node3D.new()
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D


func _ready() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(GiantPlanner.HALF_WIDTH * 2.0, GiantPlanner.HEIGHT, GiantPlanner.HALF_WIDTH * 2.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3.UP * GiantPlanner.HEIGHT * 0.5
	add_child(collision)
	add_child(_model)
	var stone: StandardMaterial3D = _material(COLOR_STONE)
	var moss: StandardMaterial3D = _material(COLOR_MOSS)
	# Facing -Z. The limbs hang from hinges so they can swing.
	_left_leg = _add_limb(Vector3(-0.45, 1.6, 0.0), Vector3(0.75, 1.6, 0.75), stone)
	_right_leg = _add_limb(Vector3(0.45, 1.6, 0.0), Vector3(0.75, 1.6, 0.75), stone)
	_add_box(_model, Vector3(1.8, 1.4, 1.0), Vector3(0.0, 2.3, 0.0), moss)
	_add_box(_model, Vector3(0.9, 0.8, 0.9), Vector3(0.0, 3.4, 0.0), stone)
	_add_box(_model, Vector3(0.6, 0.15, 0.1), Vector3(0.0, 3.5, -0.46), _material(COLOR_EYES))
	_left_arm = _add_limb(Vector3(-1.15, 2.9, 0.0), Vector3(0.5, 1.8, 0.5), stone)
	_right_arm = _add_limb(Vector3(1.15, 2.9, 0.0), Vector3(0.5, 1.8, 0.5), stone)


func setup(world: WorldData, manager: ChunkManager) -> void:
	_world = world
	_manager = manager


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	var direction: Vector3 = Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		_model.rotation.y = atan2(-direction.x, -direction.z)
	_break_left = maxf(0.0, _break_left - delta)
	var wants_jump: bool = false
	var walk: Vector3 = direction
	if is_on_floor():
		action = _planner.plan(_world, global_position, goal)
		if action == GiantPlanner.Action.JUMP:
			wants_jump = true
			jumps += 1
		elif action == GiantPlanner.Action.BREAK:
			walk = Vector3.ZERO
			if _break_left <= 0.0:
				_break(_planner.target)
	var motion: Vector3 = PlayerMotion.next_velocity(velocity, walk, is_on_floor(), wants_jump, delta)
	velocity = Vector3(walk.x * WALK_SPEED, motion.y, walk.z * WALK_SPEED)
	move_and_slide()
	_animate(delta, walk)


## Moves the giant without a fall.
func teleport(feet: Vector3) -> void:
	global_position = feet
	velocity = Vector3.ZERO


func _break(cell: Vector3i) -> void:
	var id: int = _world.get_block_world(cell.x, cell.y, cell.z)
	if _manager.set_block(cell.x, cell.y, cell.z, BlockTable.AIR):
		breaks += 1
		broken_types[id] = broken_types.get(id, 0) + 1
		_break_left = BREAK_SECONDS


func _animate(delta: float, walk: Vector3) -> void:
	var swing: float = 0.0
	if walk != Vector3.ZERO:
		_stride += delta * STRIDE_SPEED
		swing = sin(_stride) * STRIDE_ANGLE
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing
	# The right arm strikes while the giant breaks a block.
	_right_arm.rotation.x = 1.4 + sin(_break_left * TAU * 2.0) * 0.5 if action == GiantPlanner.Action.BREAK else swing


func _add_limb(hinge_position: Vector3, size: Vector3, material: Material) -> Node3D:
	var hinge: Node3D = Node3D.new()
	hinge.position = hinge_position
	_model.add_child(hinge)
	_add_box(hinge, size, Vector3.DOWN * size.y * 0.5, material)
	return hinge


func _add_box(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
