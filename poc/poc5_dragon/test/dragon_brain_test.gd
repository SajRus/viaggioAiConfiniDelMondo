extends GdUnitTestSuite

const TICK: float = 1.0 / 60.0
const CENTER: Vector3 = Vector3(0.0, 1.0, 0.0)
const HALF_SIZE: float = 7.5
const FAR_AWAY: Vector3 = Vector3(100.0, 1.0, 100.0)
const LIMIT_TICKS: int = 60 * 60


func _brain() -> DragonBrain:
	return DragonBrain.new(CENTER, HALF_SIZE)


## Updates until the brain reaches [param state]; returns the seconds it took.
func _run_until(brain: DragonBrain, state: DragonBrain.State, player_feet: Vector3) -> float:
	var seconds: float = 0.0
	for _tick: int in LIMIT_TICKS:
		if brain.state == state:
			return seconds
		brain.update(TICK, player_feet)
		seconds += TICK
	return INF


func test_starts_circling_at_full_health_inside_the_flight_volume() -> void:
	var brain: DragonBrain = _brain()

	assert_int(brain.state).is_equal(DragonBrain.State.CIRCLING)
	assert_int(brain.health).is_equal(DragonBrain.MAX_HEALTH)
	assert_bool(brain.is_inside_flight_volume(brain.position)).is_true()
	assert_float(brain.position.y).is_equal_approx(CENTER.y + DragonBrain.CIRCLE_HEIGHT, 0.0001)


func test_dives_after_circling_for_the_set_time() -> void:
	var brain: DragonBrain = _brain()

	var seconds: float = _run_until(brain, DragonBrain.State.DIVING, CENTER)

	assert_float(seconds).is_equal_approx(DragonBrain.CIRCLE_SECONDS, TICK * 1.5)


func test_lands_where_the_player_stands() -> void:
	var brain: DragonBrain = _brain()
	var feet: Vector3 = CENTER + Vector3(3.0, 0.0, -2.0)

	_run_until(brain, DragonBrain.State.LANDED, feet)

	assert_vector(brain.position).is_equal_approx(feet, Vector3.ONE * 0.0001)


func test_landing_stays_inside_the_arena_when_the_player_left_it() -> void:
	var brain: DragonBrain = _brain()

	_run_until(brain, DragonBrain.State.LANDED, FAR_AWAY)

	var limit: float = HALF_SIZE - DragonBrain.LANDING_MARGIN
	assert_vector(brain.position).is_equal_approx(Vector3(limit, CENTER.y, limit), Vector3.ONE * 0.0001)


func test_stays_landed_then_rises_back_to_the_circle() -> void:
	var brain: DragonBrain = _brain()
	var completed: Array[int] = [0]
	brain.cycle_completed.connect(func() -> void: completed[0] += 1)
	_run_until(brain, DragonBrain.State.LANDED, FAR_AWAY)

	var landed_seconds: float = _run_until(brain, DragonBrain.State.RISING, FAR_AWAY)
	_run_until(brain, DragonBrain.State.CIRCLING, FAR_AWAY)

	assert_float(landed_seconds).is_equal_approx(DragonBrain.LANDED_SECONDS, TICK * 1.5)
	assert_float(brain.position.y).is_equal_approx(CENTER.y + DragonBrain.CIRCLE_HEIGHT, 0.0001)
	assert_int(completed[0]).is_equal(1)


func test_no_state_outlasts_its_limit_whatever_the_landing_point() -> void:
	var limit: float = HALF_SIZE
	var spots: Array[Vector3] = [
		CENTER, CENTER + Vector3(limit, 0.0, limit), CENTER + Vector3(-limit, 0.0, limit),
		CENTER + Vector3(limit, 0.0, -limit), CENTER + Vector3(-limit, 0.0, -limit), FAR_AWAY,
	]
	for spot: Vector3 in spots:
		var brain: DragonBrain = _brain()
		var longest: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
		var outside: int = 0
		for _tick: int in 60 * 40:
			brain.update(TICK, spot)
			longest[brain.state] = maxf(longest[brain.state], brain.state_time)
			if not brain.is_inside_flight_volume(brain.position):
				outside += 1
		for state: DragonBrain.State in [
			DragonBrain.State.CIRCLING, DragonBrain.State.DIVING, DragonBrain.State.LANDED, DragonBrain.State.RISING
		]:
			assert_float(longest[state]).is_less_equal(brain.max_seconds(state) + TICK)
		assert_int(outside).is_equal(0)


func test_landing_straight_below_the_middle_rises_without_errors() -> void:
	var brain: DragonBrain = _brain()
	_run_until(brain, DragonBrain.State.LANDED, CENTER)

	_run_until(brain, DragonBrain.State.CIRCLING, CENTER)

	assert_bool(brain.position.is_finite()).is_true()
	assert_float(Vector2(brain.position.x, brain.position.z).length()).is_equal_approx(DragonBrain.CIRCLE_RADIUS, 0.0001)


func test_dive_hits_the_player_once_and_pushes_them_away() -> void:
	var brain: DragonBrain = _brain()
	var feet: Vector3 = CENTER + Vector3(2.0, 0.0, 0.0)
	var blows: Array[Vector3] = []
	var damages: Array[int] = []
	brain.hit_player.connect(func(damage: int, push: Vector3) -> void:
		damages.append(damage)
		blows.append(push)
	)

	_run_until(brain, DragonBrain.State.RISING, feet)

	assert_int(blows.size()).is_equal(1)
	assert_int(damages[0]).is_equal(DragonBrain.DIVE_DAMAGE)
	assert_float(blows[0].y).is_equal(DragonBrain.PUSH_LIFT)
	assert_float(Vector2(blows[0].x, blows[0].z).length()).is_equal_approx(DragonBrain.PUSH_SPEED, 0.0001)


func test_dive_misses_a_player_far_away() -> void:
	var brain: DragonBrain = _brain()
	var blows: Array[int] = [0]
	brain.hit_player.connect(func(_damage: int, _push: Vector3) -> void: blows[0] += 1)

	_run_until(brain, DragonBrain.State.RISING, FAR_AWAY)

	assert_int(blows[0]).is_equal(0)


func test_only_a_landed_dragon_can_be_hurt() -> void:
	var brain: DragonBrain = _brain()

	var in_flight: int = brain.take_hit(5)
	_run_until(brain, DragonBrain.State.LANDED, FAR_AWAY)
	var landed: int = brain.take_hit(5)

	assert_int(in_flight).is_equal(0)
	assert_int(landed).is_equal(5)
	assert_int(brain.health).is_equal(DragonBrain.MAX_HEALTH - 5)


func test_last_blow_defeats_the_dragon() -> void:
	var brain: DragonBrain = _brain()
	var defeats: Array[int] = [0]
	brain.defeated.connect(func() -> void: defeats[0] += 1)
	_run_until(brain, DragonBrain.State.LANDED, FAR_AWAY)
	brain.take_hit(DragonBrain.MAX_HEALTH - 2)

	var dealt: int = brain.take_hit(5)
	brain.update(TICK, FAR_AWAY)

	assert_int(dealt).is_equal(2)
	assert_int(brain.health).is_equal(0)
	assert_int(brain.state).is_equal(DragonBrain.State.DEFEATED)
	assert_int(defeats[0]).is_equal(1)
	assert_int(brain.take_hit(5)).is_equal(0)


func test_reset_restores_health_and_flight() -> void:
	var brain: DragonBrain = _brain()
	_run_until(brain, DragonBrain.State.LANDED, FAR_AWAY)
	brain.take_hit(10)

	brain.reset()

	assert_int(brain.health).is_equal(DragonBrain.MAX_HEALTH)
	assert_int(brain.state).is_equal(DragonBrain.State.CIRCLING)
	assert_float(brain.state_time).is_equal(0.0)


func test_hitbox_stands_on_the_dragon_feet() -> void:
	var brain: DragonBrain = _brain()
	_run_until(brain, DragonBrain.State.LANDED, CENTER)

	var box: AABB = brain.hitbox()

	assert_float(box.position.y).is_equal(CENTER.y)
	assert_bool(box.has_point(CENTER + Vector3.UP)).is_true()
