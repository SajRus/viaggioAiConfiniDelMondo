extends GdUnitTestSuite

const TICK: float = 1.0 / 60.0


func test_standing_on_floor_cancels_vertical_speed() -> void:
	var velocity: Vector3 = PlayerMotion.next_velocity(Vector3.DOWN, Vector3.ZERO, true, false, TICK)

	assert_float(velocity.y).is_equal(0.0)


func test_gravity_accelerates_in_the_air() -> void:
	var velocity: Vector3 = PlayerMotion.next_velocity(Vector3.ZERO, Vector3.ZERO, false, false, TICK)

	assert_float(velocity.y).is_equal_approx(-PlayerMotion.GRAVITY * TICK, 0.0001)


func test_falling_speed_is_limited() -> void:
	var fast: Vector3 = Vector3.DOWN * PlayerMotion.TERMINAL_SPEED
	var velocity: Vector3 = PlayerMotion.next_velocity(fast, Vector3.ZERO, false, false, TICK)

	assert_float(velocity.y).is_equal(-PlayerMotion.TERMINAL_SPEED)


func test_jump_needs_the_floor() -> void:
	var grounded: Vector3 = PlayerMotion.next_velocity(Vector3.ZERO, Vector3.ZERO, true, true, TICK)
	var airborne: Vector3 = PlayerMotion.next_velocity(Vector3.ZERO, Vector3.ZERO, false, true, TICK)

	assert_float(grounded.y).is_equal_approx(PlayerMotion.JUMP_SPEED, 0.0001)
	assert_float(airborne.y).is_less(0.0)


func test_horizontal_speed_follows_the_direction() -> void:
	var velocity: Vector3 = PlayerMotion.next_velocity(Vector3.ZERO, Vector3.RIGHT, true, false, TICK)

	assert_float(velocity.x).is_equal(PlayerMotion.WALK_SPEED)
	assert_float(velocity.z).is_equal(0.0)
