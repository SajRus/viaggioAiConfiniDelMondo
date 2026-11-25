extends GdUnitTestSuite

const GROUND: int = 10
## The body ends at x = 10, touching a wall at FRONT_X.
const FEET: Vector3 = Vector3(9.1, GROUND, 8.5)
## Along +X, far enough that the giant always wants to walk on.
const GOAL: Vector3 = Vector3(24.5, GROUND, 8.5)
## The column just in front of the giant when it walks along +X.
const FRONT_X: int = 10


## Flat stone up to [constant GROUND], air above.
func _flat_world() -> WorldData:
	var world: WorldData = WorldData.new(2, 2)
	for z: int in 32:
		for x: int in 32:
			for y: int in GROUND:
				world.set_block_world(x, y, z, BlockTable.STONE)
	return world


func _wall(world: WorldData, height: int, id: int = BlockTable.STONE) -> void:
	for z: int in range(6, 11):
		for y: int in range(GROUND, GROUND + height):
			world.set_block_world(FRONT_X, y, z, id)


func test_walks_on_open_ground() -> void:
	var planner: GiantPlanner = GiantPlanner.new()

	assert_int(planner.plan(_flat_world(), FEET, GOAL)).is_equal(GiantPlanner.Action.WALK)


func test_jumps_a_step_of_one_block() -> void:
	var world: WorldData = _flat_world()
	_wall(world, 1)
	var planner: GiantPlanner = GiantPlanner.new()

	assert_int(planner.plan(world, FEET, GOAL)).is_equal(GiantPlanner.Action.JUMP)


func test_breaks_a_wall_of_two_blocks() -> void:
	var world: WorldData = _flat_world()
	_wall(world, 2)
	var planner: GiantPlanner = GiantPlanner.new()

	var action: GiantPlanner.Action = planner.plan(world, FEET, GOAL)

	assert_int(action).is_equal(GiantPlanner.Action.BREAK)
	assert_int(planner.target.x).is_equal(FRONT_X)
	assert_int(planner.target.y).is_equal(GROUND + 1)


func test_breaks_the_block_over_a_step_before_jumping() -> void:
	var world: WorldData = _flat_world()
	_wall(world, 1)
	world.set_block_world(8, GROUND + 5, 8, BlockTable.LEAVES)
	var planner: GiantPlanner = GiantPlanner.new()

	var action: GiantPlanner.Action = planner.plan(world, FEET, GOAL)

	assert_int(action).is_equal(GiantPlanner.Action.BREAK)
	assert_vector(Vector3(planner.target)).is_equal(Vector3(8, GROUND + 5, 8))


func test_tears_down_a_tall_wall_then_walks_on() -> void:
	var world: WorldData = _flat_world()
	_wall(world, 6)
	var planner: GiantPlanner = GiantPlanner.new()
	var breaks: int = 0

	var action: GiantPlanner.Action = planner.plan(world, FEET, GOAL)
	while action == GiantPlanner.Action.BREAK and breaks < 100:
		world.set_block_world(planner.target.x, planner.target.y, planner.target.z, BlockTable.AIR)
		breaks += 1
		action = planner.plan(world, FEET, GOAL)

	assert_int(action).is_equal(GiantPlanner.Action.JUMP)
	# Three columns of the wall: the three layers in front of the body and the
	# one the body fills once on the step. The bottom layer stays as a step.
	assert_int(breaks).is_equal(3 * 4)


func test_digs_down_when_the_goal_is_below() -> void:
	var world: WorldData = _flat_world()
	var planner: GiantPlanner = GiantPlanner.new()

	var action: GiantPlanner.Action = planner.plan(world, FEET, FEET + Vector3.DOWN * 5.0)

	assert_int(action).is_equal(GiantPlanner.Action.BREAK)
	assert_int(planner.target.y).is_equal(GROUND - 1)


func test_waits_when_the_goal_is_right_here() -> void:
	var planner: GiantPlanner = GiantPlanner.new()

	assert_int(planner.plan(_flat_world(), FEET, FEET)).is_equal(GiantPlanner.Action.WALK)


func test_body_box_is_the_giant_size() -> void:
	var box: AABB = GiantPlanner.body_box(FEET)

	assert_vector(box.size).is_equal(Vector3(1.8, 3.8, 1.8))
	assert_vector(box.get_center()).is_equal_approx(FEET + Vector3.UP * 1.9, Vector3.ONE * 0.0001)


func test_solid_cells_skip_air_and_stay_inside_the_box() -> void:
	var world: WorldData = _flat_world()

	var cells: Array[Vector3i] = GiantPlanner.solid_cells(world, AABB(Vector3(2.0, GROUND - 1.0, 2.0), Vector3(2.0, 3.0, 1.0)))

	assert_int(cells.size()).is_equal(2)
	for cell: Vector3i in cells:
		assert_int(cell.y).is_equal(GROUND - 1)
