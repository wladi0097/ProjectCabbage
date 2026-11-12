extends GdUnitTestSuite


func _assert_drums(value: float, count: int, expected: Array) -> void:
	var got := TallyMachine.drum_positions(value, count)
	assert_int(got.size()).is_equal(count)
	for k in count:
		assert_float(got[k]).override_failure_message("drum %d for %s: %s" % [k, value, got]) \
				.is_equal_approx(expected[k], 0.0001)


func test_at_rest_each_drum_shows_one_digit_of_the_total_ones_first() -> void:
	_assert_drums(1234.0, 5, [4, 3, 2, 1, 0])
	_assert_drums(0.0, 5, [0, 0, 0, 0, 0])


func test_the_ones_drum_rolls_smoothly_between_whole_numbers() -> void:
	_assert_drums(15.25, 5, [5.25, 1, 0, 0, 0])


func test_a_drum_only_turns_while_every_drum_to_its_right_rolls_from_nine_to_zero() -> void:
	_assert_drums(19.5, 5, [9.5, 1.5, 0, 0, 0])
	_assert_drums(999.5, 5, [9.5, 9.5, 9.5, 0.5, 0])
	_assert_drums(1299.5, 5, [9.5, 9.5, 2.5, 1, 0])


func test_a_total_too_big_for_the_drums_rolls_over_like_an_odometer() -> void:
	_assert_drums(1234567.0, 5, [7, 6, 5, 4, 3])
	_assert_drums(999999999.0, 9, [9, 9, 9, 9, 9, 9, 9, 9, 9])
	_assert_drums(1000000000.0, 9, [0, 0, 0, 0, 0, 0, 0, 0, 0])


func test_a_negative_total_shows_all_zeros() -> void:
	_assert_drums(-42.0, 5, [0, 0, 0, 0, 0])


func test_the_tally_and_findings_drum_ticks_wait_at_least_30_ms_between_plays() -> void:
	for scene: PackedScene in [preload("res://entities/tally_machine/tally_machine.tscn"),
			preload("res://entities/tally_machine/findings_counter.tscn")]:
		var machine: Node = auto_free(scene.instantiate())
		assert_float((machine.get_node("Tick") as SoundCue).min_interval).is_equal_approx(0.03, 0.0001)
