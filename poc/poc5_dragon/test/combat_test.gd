extends GdUnitTestSuite

const TICK: float = 1.0 / 60.0
const CENTER: Vector3 = Vector3(0.0, 1.0, 0.0)


func _landed_dragon() -> DragonBrain:
	var brain: DragonBrain = DragonBrain.new(CENTER, 7.5)
	while brain.state != DragonBrain.State.LANDED:
		brain.update(TICK, CENTER)
	return brain


## An eye [param distance] blocks from the dragon's hitbox, looking at it.
func _eye(brain: DragonBrain, distance: float) -> Vector3:
	var box: AABB = brain.hitbox()
	return Vector3(box.end.x + distance, box.get_center().y, box.get_center().z)


func test_damage_grows_with_the_weapon() -> void:
	var combat: Combat = Combat.new()
	var damage: PackedInt32Array = PackedInt32Array()
	for weapon: Combat.Weapon in [Combat.Weapon.HAND, Combat.Weapon.PICKAXE, Combat.Weapon.WOODEN_SWORD, Combat.Weapon.STONE_SWORD]:
		combat.weapon = weapon
		damage.append(combat.damage())

	assert_array(damage).is_equal(PackedInt32Array([1, 2, 3, 5]))


func test_swing_within_reach_hurts_a_landed_dragon() -> void:
	var brain: DragonBrain = _landed_dragon()
	var combat: Combat = Combat.new()

	var dealt: int = combat.swing(_eye(brain, Combat.REACH - 0.1), Vector3.LEFT, brain)

	assert_int(dealt).is_equal(5)
	assert_int(combat.hits).is_equal(1)


func test_swing_beyond_reach_misses() -> void:
	var brain: DragonBrain = _landed_dragon()
	var combat: Combat = Combat.new()

	var dealt: int = combat.swing(_eye(brain, Combat.REACH + 0.1), Vector3.LEFT, brain)

	assert_int(dealt).is_equal(0)
	assert_int(combat.swings).is_equal(1)
	assert_int(brain.health).is_equal(DragonBrain.MAX_HEALTH)


func test_swing_looking_away_misses() -> void:
	var brain: DragonBrain = _landed_dragon()
	var combat: Combat = Combat.new()

	var dealt: int = combat.swing(_eye(brain, 1.0), Vector3.RIGHT, brain)

	assert_int(dealt).is_equal(0)


func test_one_swing_every_half_second_hit_or_miss() -> void:
	var brain: DragonBrain = _landed_dragon()
	var combat: Combat = Combat.new()
	var eye: Vector3 = _eye(brain, 1.0)
	combat.swing(eye, Vector3.RIGHT, brain)

	var too_soon: int = combat.swing(eye, Vector3.LEFT, brain)
	for _tick: int in 30:
		combat.update(TICK)
	var after_cooldown: int = combat.swing(eye, Vector3.LEFT, brain)

	assert_int(too_soon).is_equal(0)
	assert_int(after_cooldown).is_equal(5)
	assert_int(combat.swings).is_equal(2)


func test_flying_dragon_takes_no_damage() -> void:
	var brain: DragonBrain = DragonBrain.new(CENTER, 7.5)
	var combat: Combat = Combat.new()

	var dealt: int = combat.swing(_eye(brain, 1.0), Vector3.LEFT, brain)

	assert_int(dealt).is_equal(0)
	assert_int(brain.health).is_equal(DragonBrain.MAX_HEALTH)
