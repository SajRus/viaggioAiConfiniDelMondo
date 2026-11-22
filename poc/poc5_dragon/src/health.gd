class_name Health
extends RefCounted

signal changed(points: int)
signal died

const MAX: int = 20
const REGEN_SECONDS: float = 4.0
## Blocks of fall that do no harm.
const SAFE_FALL_BLOCKS: int = 3
# A fall of exactly n blocks can measure a hair less than n.
const FALL_TOLERANCE: float = 0.01

var points: int = MAX

var _regen_time: float = 0.0


## One point for every whole block of fall beyond the first three.
static func fall_damage(height: float) -> int:
	return maxi(0, floori(height + FALL_TOLERANCE) - SAFE_FALL_BLOCKS)


func is_dead() -> bool:
	return points == 0


func damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	points = maxi(0, points - amount)
	_regen_time = 0.0
	changed.emit(points)
	if is_dead():
		died.emit()


## Gives back one point every [constant REGEN_SECONDS] while alive and hurt.
func update(delta: float) -> void:
	if is_dead() or points == MAX:
		_regen_time = 0.0
		return
	_regen_time += delta
	while _regen_time >= REGEN_SECONDS and points < MAX:
		_regen_time -= REGEN_SECONDS
		points += 1
		changed.emit(points)


func restore(value: int = MAX) -> void:
	points = clampi(value, 0, MAX)
	_regen_time = 0.0
	changed.emit(points)
