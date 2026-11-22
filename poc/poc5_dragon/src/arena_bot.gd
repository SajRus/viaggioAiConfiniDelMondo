class_name ArenaBot
extends RefCounted

## Plays in place of a person. It wanders the arena and its surroundings, also
## stopping still under the dragon, and with [member fights] set it runs to the
## landed dragon and swings at it.

const ARRIVE_DISTANCE: float = 0.5
const STRIKE_DISTANCE: float = 2.5
const MIN_WANDER_SECONDS: float = 0.5
const MAX_WANDER_SECONDS: float = 3.0
const STAND_STILL_CHANCE: float = 0.3
const JUMP_CHANCE: float = 0.01
## How far outside the arena the wandering can go.
const OUTSIDE_REACH: float = 4.0

var fights: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _center: Vector3
var _half_size: float
var _goal: Vector3
var _standing: bool = false
var _wander_left: float = 0.0


func _init(rng_seed: int, center: Vector3, half_size: float) -> void:
	_rng.seed = rng_seed
	_center = center
	_half_size = half_size
	_goal = center


## Steers [param player] for one physics frame; returns true when it wants to swing.
func drive(delta: float, player: Player, dragon: DragonBrain) -> bool:
	var feet: Vector3 = player.global_position
	player.look_at_point(dragon.hitbox().get_center())
	player.wish_jump = false
	if fights and dragon.is_hittable():
		var to_dragon: Vector3 = dragon.position - feet
		to_dragon.y = 0.0
		_walk_towards(player, to_dragon, STRIKE_DISTANCE)
		return to_dragon.length() <= STRIKE_DISTANCE + 0.5
	_wander_left -= delta
	if _wander_left <= 0.0:
		_pick_goal()
	var to_goal: Vector3 = _goal - feet
	to_goal.y = 0.0
	if _standing:
		player.wish_move = Vector2.ZERO
	else:
		_walk_towards(player, to_goal, ARRIVE_DISTANCE)
		player.wish_jump = _rng.randf() < JUMP_CHANCE
	return false


func _pick_goal() -> void:
	_wander_left = _rng.randf_range(MIN_WANDER_SECONDS, MAX_WANDER_SECONDS)
	_standing = _rng.randf() < STAND_STILL_CHANCE
	var reach: float = _half_size + OUTSIDE_REACH
	_goal = _center + Vector3(_rng.randf_range(-reach, reach), 0.0, _rng.randf_range(-reach, reach))


## Turns the flat world offset into the player's view-relative wish.
func _walk_towards(player: Player, offset: Vector3, stop_distance: float) -> void:
	if offset.length() <= stop_distance:
		player.wish_move = Vector2.ZERO
		return
	var local: Vector3 = offset.normalized().rotated(Vector3.UP, -player.yaw)
	player.wish_move = Vector2(local.x, -local.z)
