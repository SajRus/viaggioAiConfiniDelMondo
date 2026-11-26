class_name Combat
extends RefCounted

## The player's melee blows (RF-29): one every [constant COOLDOWN] seconds.

const REACH: float = 3.5
const COOLDOWN: float = 0.5
# Thirty frames of 1/60 s add up to a hair less than half a second.
const COOLDOWN_TOLERANCE: float = 0.0001
const HAND_DAMAGE: int = 1
const PICKAXE_DAMAGE: int = 2
const WOODEN_SWORD_DAMAGE: int = 3
const STONE_SWORD_DAMAGE: int = 5

var _cooldown_left: float = 0.0


## Damage of a blow with [param item] in hand: anything but a tool hits like the hand.
static func damage_of(item: int) -> int:
	match item:
		ItemTable.WOODEN_PICKAXE, ItemTable.STONE_PICKAXE:
			return PICKAXE_DAMAGE
		ItemTable.WOODEN_SWORD:
			return WOODEN_SWORD_DAMAGE
		ItemTable.STONE_SWORD:
			return STONE_SWORD_DAMAGE
	return HAND_DAMAGE


## Distance along the view to the boss's box, or INF when the boss cannot be
## hit or is out of reach.
static func distance_to(origin: Vector3, direction: Vector3, boss: Boss) -> float:
	if not boss.is_hittable():
		return INF
	var box: AABB = boss.hitbox()
	if box.has_point(origin):
		return 0.0
	var hit: Variant = box.intersects_segment(origin, origin + direction.normalized() * REACH)
	if hit == null:
		return INF
	var point: Vector3 = hit
	return origin.distance_to(point)


## The nearest boss along the view within reach, or null.
static func aimed_boss(origin: Vector3, direction: Vector3, bosses: Array[Boss]) -> Boss:
	var nearest: Boss = null
	var best: float = INF
	for boss: Boss in bosses:
		var distance: float = distance_to(origin, direction, boss)
		if distance < best:
			best = distance
			nearest = boss
	return nearest


func can_swing() -> bool:
	return _cooldown_left <= COOLDOWN_TOLERANCE


func update(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)


## Strikes [param boss] with [param item] in hand. Returns the damage it took,
## 0 while the next blow is not ready.
func swing(boss: Boss, item: int) -> int:
	if not can_swing():
		return 0
	_cooldown_left = COOLDOWN
	return boss.take_hit(damage_of(item))
