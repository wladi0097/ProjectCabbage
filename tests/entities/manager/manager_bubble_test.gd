extends GdUnitTestSuite


func test_the_speech_bubble_never_takes_the_mouse_from_the_desk() -> void:
	var bubble := auto_free(ManagerBubble.new()) as ManagerBubble
	add_child(bubble)

	assert_int(bubble.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_bar_drains_with_the_deadline_not_with_cabbages_sold() -> void:
	assert_float(ManagerBubble.time_fraction(45.0, 45.0)).is_equal(1.0)
	assert_float(ManagerBubble.time_fraction(15.0, 60.0)).is_equal(0.25)
	assert_float(ManagerBubble.time_fraction(0.0, 45.0)).is_equal(0.0)
	assert_float(ManagerBubble.time_fraction(50.0, 45.0)).is_equal(1.0)


func test_the_counter_shows_cabbages_sold_against_the_quota_and_never_past_it() -> void:
	assert_str(ManagerBubble.counter_text(0, 30)).is_equal("0 / 30")
	assert_str(ManagerBubble.counter_text(12, 30)).is_equal("12 / 30")
	assert_str(ManagerBubble.counter_text(140, 120)).is_equal("120 / 120")


func test_the_time_readout_rounds_up_and_handles_deadlines_past_a_minute() -> void:
	assert_str(ManagerBubble.clock_text(22.1)).is_equal("0:23")
	assert_str(ManagerBubble.clock_text(75.0)).is_equal("1:15")
	assert_str(ManagerBubble.clock_text(0.0)).is_equal("0:00")


func test_the_bar_turns_to_the_alarm_colour_exactly_when_the_countdown_starts_ticking() -> void:
	assert_bool(ManagerBubble.urgent(Manager.TICK_FROM + 0.01)).is_false()
	assert_bool(ManagerBubble.urgent(Manager.TICK_FROM)).is_true()
	assert_bool(ManagerBubble.urgent(0.5)).is_true()


func test_the_quota_bubble_hangs_top_right_and_never_runs_off_the_screen() -> void:
	for width in [1280.0, 1920.0, 2560.0, 3440.0]:
		var x := ManagerBubble.centre_x(width)
		assert_float(x).is_greater(width * 0.7)
		assert_float(x + ManagerBubble.SIZE.x * ManagerBubble.SCALE / 2.0).is_less_equal(width - ManagerBubble.EDGE)
