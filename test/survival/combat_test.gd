extends GdUnitTestSuite

const TICK: float = 1.0 / 60.0


## A training boss whose box ends [param distance] blocks in front of the origin, along -Z.
func _boss_ahead(distance: float) -> TrainingBoss:
	var boss: TrainingBoss = auto_free(TrainingBoss.new())
	add_child(boss)
	boss.global_position = Vector3(0.0, 0.0, -distance - 0.5)
	return boss


func test_damage_grows_with_the_item_in_hand() -> void:
	var damage: Array[int] = []
	for item: int in [ItemTable.NONE, BlockTable.STONE, ItemTable.RUBY, ItemTable.WOODEN_PICKAXE,
			ItemTable.STONE_PICKAXE, ItemTable.WOODEN_SWORD, ItemTable.STONE_SWORD]:
		damage.append(Combat.damage_of(item))

	assert_array(damage).is_equal([1, 1, 1, 2, 2, 3, 5] as Array[int])


func test_distance_to_a_boss_within_reach() -> void:
	var boss: TrainingBoss = _boss_ahead(2.0)

	assert_float(Combat.distance_to(Vector3.ZERO, Vector3.FORWARD, boss)).is_equal_approx(2.0, 0.001)


func test_a_boss_beyond_reach_or_aside_cannot_be_hit() -> void:
	var far: TrainingBoss = _boss_ahead(Combat.REACH + 0.1)
	var near: TrainingBoss = _boss_ahead(1.0)

	assert_float(Combat.distance_to(Vector3.ZERO, Vector3.FORWARD, far)).is_equal(INF)
	assert_float(Combat.distance_to(Vector3.ZERO, Vector3.RIGHT, near)).is_equal(INF)


func test_a_boss_that_is_not_hittable_is_never_aimed() -> void:
	var boss: TrainingBoss = _boss_ahead(1.0)
	boss.hittable = false
	var bosses: Array[Boss] = [boss]

	assert_object(Combat.aimed_boss(Vector3.ZERO, Vector3.FORWARD, bosses)).is_null()


func test_the_nearest_boss_is_aimed() -> void:
	var far: TrainingBoss = _boss_ahead(3.0)
	var near: TrainingBoss = _boss_ahead(1.0)
	var bosses: Array[Boss] = [far, near]

	assert_object(Combat.aimed_boss(Vector3.ZERO, Vector3.FORWARD, bosses)).is_same(near)


func test_an_eye_inside_the_box_hits_at_once() -> void:
	var boss: TrainingBoss = _boss_ahead(0.0)
	boss.size = Vector3.ONE * 4.0

	assert_float(Combat.distance_to(Vector3.ZERO, Vector3.BACK, boss)).is_equal(0.0)


func test_one_blow_every_half_second() -> void:
	var boss: TrainingBoss = _boss_ahead(1.0)
	var combat: Combat = Combat.new()

	var first: int = combat.swing(boss, ItemTable.STONE_SWORD)
	var too_soon: int = combat.swing(boss, ItemTable.STONE_SWORD)
	for _tick: int in 30:
		combat.update(TICK)
	var after_cooldown: int = combat.swing(boss, ItemTable.WOODEN_SWORD)

	assert_int(first).is_equal(5)
	assert_int(too_soon).is_equal(0)
	assert_int(after_cooldown).is_equal(3)
	assert_int(boss.blows).is_equal(2)
