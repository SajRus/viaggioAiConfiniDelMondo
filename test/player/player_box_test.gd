extends GdUnitTestSuite


func test_box_stands_on_the_feet() -> void:
	var box: AABB = Player.box_at(Vector3(5.0, 10.0, 7.0), 0.0)

	assert_vector(box.position).is_equal(Vector3(4.7, 10.0, 6.7))
	assert_vector(box.size).is_equal_approx(Vector3(0.6, 1.8, 0.6), Vector3.ONE * 0.0001)


func test_tolerance_shrinks_every_side() -> void:
	var box: AABB = Player.box_at(Vector3(5.0, 10.0, 7.0), 0.1)

	assert_vector(box.size).is_equal_approx(Vector3(0.4, 1.6, 0.4), Vector3.ONE * 0.0001)


func test_box_matches_the_collision_shape() -> void:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var player: Player = auto_free(scene.instantiate())
	var collision: CollisionShape3D = player.get_node("Collision")
	var shape: BoxShape3D = collision.shape

	assert_vector(shape.size).is_equal_approx(Player.box_at(Vector3.ZERO, 0.0).size, Vector3.ONE * 0.0001)
