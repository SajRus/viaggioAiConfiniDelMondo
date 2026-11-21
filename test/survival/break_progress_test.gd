extends GdUnitTestSuite


func test_finishes_after_the_needed_time() -> void:
	var progress: BreakProgress = BreakProgress.new()

	assert_bool(progress.advance(Vector3i(1, 2, 3), 0.5, 0.6)).is_false()
	assert_bool(progress.advance(Vector3i(1, 2, 3), 0.1, 0.6)).is_true()


func test_a_different_block_starts_over() -> void:
	var progress: BreakProgress = BreakProgress.new()
	progress.advance(Vector3i(1, 2, 3), 0.5, 0.6)

	assert_bool(progress.advance(Vector3i(1, 2, 4), 0.5, 0.6)).is_false()
	assert_float(progress.elapsed).is_equal(0.5)


func test_reset_starts_over() -> void:
	var progress: BreakProgress = BreakProgress.new()
	progress.advance(Vector3i.ZERO, 0.5, 0.6)

	progress.reset()

	assert_bool(progress.advance(Vector3i.ZERO, 0.5, 0.6)).is_false()


func test_crack_has_four_stages() -> void:
	var progress: BreakProgress = BreakProgress.new()

	progress.advance(Vector3i.ZERO, 0.0, 4.0)
	assert_int(progress.stage()).is_equal(0)
	progress.advance(Vector3i.ZERO, 1.0, 4.0)
	assert_int(progress.stage()).is_equal(1)
	progress.advance(Vector3i.ZERO, 2.5, 4.0)
	assert_int(progress.stage()).is_equal(3)
	progress.advance(Vector3i.ZERO, 5.0, 4.0)
	assert_int(progress.stage()).is_equal(3)
