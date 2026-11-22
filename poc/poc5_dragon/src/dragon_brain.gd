class_name DragonBrain
extends RefCounted

## Flight of the Dragon of the Borders, without nodes: circles over the arena,
## dives at the player, stays on the ground and rises again. It never leaves
## the air column above the arena, which is open, so it has nothing to avoid.

signal hit_player(damage: int, push: Vector3)
signal landed
signal took_off
## Back to circling after a whole circle, dive, landing and rise.
signal cycle_completed
signal defeated

enum State { CIRCLING, DIVING, LANDED, RISING, DEFEATED }

const MAX_HEALTH: int = 60
const CIRCLE_RADIUS: float = 6.0
const CIRCLE_HEIGHT: float = 12.0
const CIRCLE_SPEED: float = 7.0
const CIRCLE_SECONDS: float = 6.0
const DIVE_SPEED: float = 16.0
const LANDED_SECONDS: float = 3.0
const RISE_SPEED: float = 8.0
const DIVE_DAMAGE: int = 4
## Distance between the dragon and the middle of the player that counts as a hit.
const DIVE_HIT_RADIUS: float = 2.0
const PUSH_SPEED: float = 9.0
const PUSH_LIFT: float = 6.0
## Dives land at least this far from the edge of the arena.
const LANDING_MARGIN: float = 2.0
const PLAYER_HALF_HEIGHT: float = 0.9
const HITBOX_SIZE: Vector3 = Vector3(3.6, 2.2, 3.6)

var state: State = State.CIRCLING
var health: int = MAX_HEALTH
var position: Vector3
var velocity: Vector3 = Vector3.ZERO
## Seconds spent in the current state.
var state_time: float = 0.0

var _center: Vector3
var _half_size: float
var _angle: float = 0.0
var _target: Vector3
var _hit_this_dive: bool = false


## [param center] is the middle of the arena's top face, [param half_size]
## half the length of its side.
func _init(center: Vector3, half_size: float) -> void:
	_center = center
	_half_size = half_size
	reset()


## Back to full health, circling: after the player's death or for a new fight.
func reset() -> void:
	health = MAX_HEALTH
	_angle = 0.0
	position = _circle_point(_angle)
	velocity = Vector3.ZERO
	_enter(State.CIRCLING)


func is_hittable() -> bool:
	return state == State.LANDED


func hitbox() -> AABB:
	return AABB(position + Vector3(-HITBOX_SIZE.x * 0.5, 0.0, -HITBOX_SIZE.z * 0.5), HITBOX_SIZE)


## Takes a blow; only a landed dragon can be hurt. Returns the damage dealt.
func take_hit(damage: int) -> int:
	if not is_hittable() or damage <= 0:
		return 0
	var dealt: int = mini(damage, health)
	health -= dealt
	if health == 0:
		_enter(State.DEFEATED)
		defeated.emit()
	return dealt


## The longest a state can last before the dragon counts as stuck.
func max_seconds(of_state: State) -> float:
	# Corner to corner of the flight volume, the longest straight line it flies.
	var span: float = Vector3(_half_size + CIRCLE_RADIUS, CIRCLE_HEIGHT, _half_size + CIRCLE_RADIUS).length()
	match of_state:
		State.CIRCLING:
			return CIRCLE_SECONDS
		State.DIVING:
			return span / DIVE_SPEED
		State.LANDED:
			return LANDED_SECONDS
		State.RISING:
			return span / RISE_SPEED
	return INF


## True when [param point] is in the air column above the arena, up to circling height.
func is_inside_flight_volume(point: Vector3) -> bool:
	return (
		absf(point.x - _center.x) <= _half_size
		and absf(point.z - _center.z) <= _half_size
		and point.y >= _center.y - 0.001
		and point.y <= _center.y + CIRCLE_HEIGHT + 0.001
	)


func update(delta: float, player_feet: Vector3) -> void:
	var before: Vector3 = position
	state_time += delta
	match state:
		State.CIRCLING:
			_angle = wrapf(_angle + CIRCLE_SPEED / CIRCLE_RADIUS * delta, 0.0, TAU)
			position = _circle_point(_angle)
			if state_time >= CIRCLE_SECONDS:
				_target = _landing_point(player_feet)
				_hit_this_dive = false
				_enter(State.DIVING)
		State.DIVING:
			var arrived: bool = _fly_towards(_target, DIVE_SPEED * delta)
			_check_dive_hit(player_feet)
			if arrived:
				_enter(State.LANDED)
				landed.emit()
		State.LANDED:
			if state_time >= LANDED_SECONDS:
				_angle = _angle_of(position)
				_target = _circle_point(_angle)
				_enter(State.RISING)
				took_off.emit()
		State.RISING:
			if _fly_towards(_target, RISE_SPEED * delta):
				_enter(State.CIRCLING)
				cycle_completed.emit()
	velocity = (position - before) / delta if delta > 0.0 else Vector3.ZERO


func _enter(next: State) -> void:
	state = next
	state_time = 0.0


func _circle_point(angle: float) -> Vector3:
	return _center + Vector3(cos(angle) * CIRCLE_RADIUS, CIRCLE_HEIGHT, sin(angle) * CIRCLE_RADIUS)


## Angle on the circle above [param point]; straight above the centre keeps the last one.
func _angle_of(point: Vector3) -> float:
	var offset: Vector2 = Vector2(point.x - _center.x, point.z - _center.z)
	if offset.length_squared() < 0.0001:
		return _angle
	return wrapf(offset.angle(), 0.0, TAU)


## Where the player stands, kept inside the arena even when they left it.
func _landing_point(player_feet: Vector3) -> Vector3:
	var limit: float = _half_size - LANDING_MARGIN
	return Vector3(
		clampf(player_feet.x, _center.x - limit, _center.x + limit),
		_center.y,
		clampf(player_feet.z, _center.z - limit, _center.z + limit)
	)


## Moves at most [param step] towards [param point]; true once it is there.
func _fly_towards(point: Vector3, step: float) -> bool:
	if position.distance_to(point) <= step:
		position = point
		return true
	position = position.move_toward(point, step)
	return false


func _check_dive_hit(player_feet: Vector3) -> void:
	var player_middle: Vector3 = player_feet + Vector3.UP * PLAYER_HALF_HEIGHT
	if _hit_this_dive or position.distance_to(player_middle) > DIVE_HIT_RADIUS:
		return
	_hit_this_dive = true
	var away: Vector3 = Vector3(player_middle.x - position.x, 0.0, player_middle.z - position.z)
	if away.length_squared() < 0.0001:
		away = Vector3(cos(_angle), 0.0, sin(_angle))
	hit_player.emit(DIVE_DAMAGE, away.normalized() * PUSH_SPEED + Vector3.UP * PUSH_LIFT)
