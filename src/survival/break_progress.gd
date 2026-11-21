class_name BreakProgress
extends RefCounted

## How long the break button has been held on one block.

const STAGES: int = 4

var cell: Vector3i = Vector3i.ZERO
var elapsed: float = 0.0
var seconds: float = 1.0
var active: bool = false


## Adds [param delta] on [param target], starting over when the block changes.
## Returns true once the block has been held for [param needed] seconds.
func advance(target: Vector3i, delta: float, needed: float) -> bool:
	if not active or target != cell:
		active = true
		cell = target
		elapsed = 0.0
	seconds = needed
	elapsed += delta
	return elapsed >= seconds


func reset() -> void:
	active = false
	elapsed = 0.0


## Crack stage from 0 to [constant STAGES] - 1.
func stage() -> int:
	return clampi(floori(elapsed / seconds * STAGES), 0, STAGES - 1)
