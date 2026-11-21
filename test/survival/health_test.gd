extends GdUnitTestSuite


func test_falls_of_three_blocks_are_harmless() -> void:
	assert_int(Health.fall_damage(0.0)).is_equal(0)
	assert_int(Health.fall_damage(1.47)).is_equal(0)
	assert_int(Health.fall_damage(3.9)).is_equal(0)


func test_each_block_beyond_three_costs_one_point() -> void:
	assert_int(Health.fall_damage(4.0)).is_equal(1)
	assert_int(Health.fall_damage(3.995)).is_equal(1)
	assert_int(Health.fall_damage(10.5)).is_equal(7)
	assert_int(Health.fall_damage(60.0)).is_equal(57)


func test_damage_down_to_zero_kills_once() -> void:
	var health: Health = Health.new()
	var deaths: Array[int] = []
	health.died.connect(func() -> void: deaths.append(1))

	health.damage(25)
	health.damage(1)

	assert_int(health.points).is_equal(0)
	assert_bool(health.is_dead()).is_true()
	assert_array(deaths).is_equal([1] as Array[int])


func test_regenerates_one_point_every_four_seconds() -> void:
	var health: Health = Health.new()
	health.damage(5)

	health.update(3.9)
	assert_int(health.points).is_equal(15)
	health.update(0.2)
	assert_int(health.points).is_equal(16)
	health.update(8.0)
	assert_int(health.points).is_equal(18)


func test_damage_restarts_the_regeneration_wait() -> void:
	var health: Health = Health.new()
	health.damage(2)
	health.update(3.0)

	health.damage(1)
	health.update(3.0)

	assert_int(health.points).is_equal(17)


func test_no_regeneration_when_full_or_dead() -> void:
	var health: Health = Health.new()
	health.update(100.0)
	assert_int(health.points).is_equal(Health.MAX)

	health.damage(Health.MAX)
	health.update(100.0)
	assert_int(health.points).is_equal(0)


func test_restore_fills_up() -> void:
	var health: Health = Health.new()
	health.damage(Health.MAX)

	health.restore()

	assert_int(health.points).is_equal(Health.MAX)
