extends GdUnitTestSuite

const HandScript := preload("res://globalScripts/hand.gd")


func test_a_tooltip_is_shown_at_once_the_first_time_its_text_is_hovered() -> void:
	assert_float(HandScript.tooltip_delay(false)).is_equal(0.0)


func test_a_tooltip_already_seen_waits_for_the_tooltip_delay() -> void:
	assert_float(HandScript.tooltip_delay(true)).is_equal(HandScript.TOOLTIP_DELAY)


func test_the_fingertip_taps_up_and_down_over_a_hovered_button() -> void:
	assert_float(HandScript.tap_lift(0.0, false)).is_greater(HandScript.tap_lift(PI / HandScript.TAP_SPEED, false))


func test_a_tapping_fingertip_stays_between_its_low_and_high_lift() -> void:
	for i in 50:
		assert_float(HandScript.tap_lift(i * 0.037, false)).is_between(HandScript.TAP_LIFT.x - 0.0001, HandScript.TAP_LIFT.y + 0.0001)


func test_a_held_button_is_pressed_in_below_its_surface() -> void:
	assert_float(HandScript.tap_lift(0.0, true)).is_less(0.0)
	assert_float(HandScript.tap_lift(3.0, true)).is_equal(HandScript.PRESS_LIFT)


func test_a_mouse_inside_the_lead_limit_stays_where_it_is() -> void:
	var mouse := Vector3(1.05, 0.9, 0)

	assert_vector(HandScript.rein(Vector3(1, 0.9, 0), mouse, 0.1)).is_equal(mouse)


func test_a_mouse_run_ahead_of_a_held_object_is_pulled_back_to_the_limit() -> void:
	assert_vector(HandScript.rein(Vector3(1, 0.9, 0), Vector3(0, 0.9, 0), 0.1)) \
			.is_equal_approx(Vector3(0.9, 0.9, 0), Vector3.ONE * 0.0001)


func test_the_lead_limit_is_measured_flat_and_keeps_the_mouse_height() -> void:
	var reined := HandScript.rein(Vector3(0, 0.2, 0), Vector3(0.3, 1.0, 0.4), 0.25)

	assert_float(reined.y).is_equal(1.0)
	assert_float(Vector2(reined.x, reined.z).length()).is_equal_approx(0.25, 0.0001)
	assert_vector(HandScript.rein(Vector3(0, 0.2, 0), Vector3(0.05, 3.0, 0), 0.1)).is_equal(Vector3(0.05, 3.0, 0))

