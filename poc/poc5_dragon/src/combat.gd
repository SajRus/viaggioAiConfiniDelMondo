class_name Combat
extends RefCounted

## The player's melee blows: one swing every [constant COOLDOWN] seconds, hit or miss.

enum Weapon { HAND, PICKAXE, WOODEN_SWORD, STONE_SWORD }

const REACH: float = 3.5
const COOLDOWN: float = 0.5
# Thirty frames of 1/60 s add up to a hair less than half a second.
const COOLDOWN_TOLERANCE: float = 0.0001
const DAMAGE: PackedInt32Array = [1, 2, 3, 5]
const NAMES: PackedStringArray = ["mano", "piccone", "spada di legno", "spada di pietra"]

var weapon: Weapon = Weapon.STONE_SWORD
var swings: int = 0
var hits: int = 0

var _cooldown_left: float = 0.0


static func ray_reaches(origin: Vector3, direction: Vector3, box: AABB) -> bool:
	var hit: Variant = box.intersects_segment(origin, origin + direction.normalized() * REACH)
	return hit != null


func damage() -> int:
	return DAMAGE[weapon]


func weapon_name() -> String:
	return NAMES[weapon]


func can_swing() -> bool:
	return _cooldown_left <= COOLDOWN_TOLERANCE


func update(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)


## Swings along the view; returns the damage the dragon took, 0 on a miss or while recharging.
func swing(origin: Vector3, direction: Vector3, dragon: DragonBrain) -> int:
	if not can_swing():
		return 0
	_cooldown_left = COOLDOWN
	swings += 1
	if not ray_reaches(origin, direction, dragon.hitbox()):
		return 0
	var dealt: int = dragon.take_hit(damage())
	if dealt > 0:
		hits += 1
	return dealt
