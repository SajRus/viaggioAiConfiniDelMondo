class_name GiantPlanner
extends RefCounted

## What the world-bearer does next, from the blocks around it: walk on, jump a
## step of one block, or break the block that stops it. It needs no pathfinding:
## a wall is not walked around, it is torn down, and a giant standing above its
## goal digs down.

enum Action { WALK, JUMP, BREAK }

const HALF_WIDTH: float = 0.9
const HEIGHT: float = 3.8
## How far ahead the giant looks for blocks in its way.
const PROBE_DISTANCE: float = 0.5
## A jump lifts the feet about 1.47 blocks: one block of step plus a margin.
const JUMP_RISE: float = 1.5
const EPSILON: float = 0.001

## The block to break when [method plan] returns [constant Action.BREAK].
var target: Vector3i = Vector3i.ZERO


static func body_box(feet: Vector3) -> AABB:
	return AABB(feet - Vector3(HALF_WIDTH, 0.0, HALF_WIDTH), Vector3(HALF_WIDTH * 2.0, HEIGHT, HALF_WIDTH * 2.0))


## Solid blocks overlapping [param box].
static func solid_cells(world: WorldData, box: AABB) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var low: Vector3i = Vector3i((box.position + Vector3.ONE * EPSILON).floor())
	var high: Vector3i = Vector3i((box.end - Vector3.ONE * EPSILON).floor())
	for y: int in range(low.y, high.y + 1):
		for z: int in range(low.z, high.z + 1):
			for x: int in range(low.x, high.x + 1):
				if BlockRegistry.solid[world.get_block_world(x, y, z)] == 1:
					cells.append(Vector3i(x, y, z))
	return cells


## Chooses the next action for a giant standing at [param feet] that wants to reach [param goal].
func plan(world: WorldData, feet: Vector3, goal: Vector3) -> Action:
	var body: AABB = body_box(feet)
	var flat: Vector3 = Vector3(goal.x - feet.x, 0.0, goal.z - feet.z)
	if flat.length() < HALF_WIDTH:
		if goal.y < feet.y - EPSILON:
			var below: Array[Vector3i] = solid_cells(world, AABB(body.position + Vector3.DOWN, Vector3(body.size.x, 1.0, body.size.z)))
			if not below.is_empty():
				return _break_nearest(below, body)
		return Action.WALK
	var probe: AABB = AABB(body.position + flat.normalized() * PROBE_DISTANCE, body.size)
	var ahead: Array[Vector3i] = solid_cells(world, probe)
	if ahead.is_empty():
		return Action.WALK
	var bottom: int = floori(feet.y + EPSILON)
	var wall: Array[Vector3i] = []
	for cell: Vector3i in ahead:
		if cell.y > bottom:
			wall.append(cell)
	if not wall.is_empty():
		return _break_nearest(wall, body)
	# Only a step of one block: jump it, if there is room above.
	var headroom: Array[Vector3i] = solid_cells(world, AABB(probe.position + Vector3.UP, probe.size))
	headroom.append_array(solid_cells(world, AABB(body.position + Vector3.UP * JUMP_RISE, body.size)))
	if headroom.is_empty():
		return Action.JUMP
	return _break_nearest(headroom, body)


func _break_nearest(cells: Array[Vector3i], body: AABB) -> Action:
	var middle: Vector3 = body.get_center()
	var best: float = INF
	for cell: Vector3i in cells:
		var distance: float = (Vector3(cell) + Vector3.ONE * 0.5).distance_squared_to(middle)
		if distance < best:
			best = distance
			target = cell
	return Action.BREAK
