extends GdUnitTestSuite

const SCENE := preload("res://entities/hand/hand_model.tscn")


func as_floats(pose: Array) -> Array:
	return pose.map(func(row: Array) -> Array: return row.map(func(v: int) -> float: return float(v)))


func test_an_idle_hand_points() -> void:
	assert_int(HandModel.pose_for(false, false)).is_equal(HandModel.Pose.POINT)


func test_a_hand_over_something_grabbable_opens() -> void:
	assert_int(HandModel.pose_for(false, true)).is_equal(HandModel.Pose.OPEN)


func test_a_hand_holding_something_grabs_it_even_off_target() -> void:
	assert_int(HandModel.pose_for(true, true)).is_equal(HandModel.Pose.GRAB)
	assert_int(HandModel.pose_for(true, false)).is_equal(HandModel.Pose.GRAB)


func test_buttons_are_pointed_at_and_pressed_never_grabbed() -> void:
	assert_int(HandModel.pose_for(false, true, true)).is_equal(HandModel.Pose.POINT)
	assert_int(HandModel.pose_for(true, true, true)).is_equal(HandModel.Pose.POINT)


func test_paper_is_pinched_by_a_corner_while_hovered_or_held() -> void:
	assert_int(HandModel.pose_for(false, true, false, true)).is_equal(HandModel.Pose.PINCH)
	assert_int(HandModel.pose_for(true, true, false, true)).is_equal(HandModel.Pose.PINCH)


func test_paper_away_from_the_hand_is_not_pinched() -> void:
	assert_int(HandModel.pose_for(false, false, false, true)).is_equal(HandModel.Pose.POINT)


func test_a_handle_is_half_gripped_on_hover_and_gripped_once_held() -> void:
	assert_int(HandModel.pose_for(false, true, false, false, true)).is_equal(HandModel.Pose.REACH)
	assert_int(HandModel.pose_for(true, true, false, false, true)).is_equal(HandModel.Pose.GRAB)


func test_a_negative_curl_bends_a_finger_down_toward_the_palm() -> void:
	var tip := HandModel.segment_rotation(0, 1, -90, 0) * Vector3.FORWARD

	assert_vector(tip).is_equal_approx(Vector3.DOWN, Vector3.ONE * 0.0001)


func test_a_positive_spread_opens_a_finger_toward_the_thumb() -> void:
	assert_float((HandModel.segment_rotation(0, 0, 0, 20) * Vector3.FORWARD).x).is_less(0.0)


func test_only_the_first_finger_segment_spreads() -> void:
	var spread := HandModel.segment_rotation(0, 1, -30, 20)
	var plain := HandModel.segment_rotation(0, 1, -30, 0)

	assert_bool(spread.is_equal_approx(plain)).is_true()


func test_the_thumb_curls_down_about_its_own_turned_axis() -> void:
	var thumb := Vector3.FORWARD.rotated(Vector3.UP, HandModel.THUMB_YAW)

	assert_float((HandModel.segment_rotation(HandModel.THUMB, 0, -60, 0) * thumb).y).is_less(-0.8)


func test_a_pointing_hand_keeps_its_index_out_and_curls_the_others() -> void:
	var point: Array = HandModel.POSES[HandModel.Pose.POINT]

	assert_int(point[0][0] + point[0][1] + point[0][2]).is_greater(-60)
	assert_int(point[1][0] + point[1][1]).is_less(-120)
	assert_int(point[2][0] + point[2][1]).is_less(-120)


func test_every_finger_closes_when_grabbing() -> void:
	for f in HandModel.FINGERS.size():
		var grab: Array = HandModel.POSES[HandModel.Pose.GRAB][f]
		var open: Array = HandModel.POSES[HandModel.Pose.OPEN][f]
		assert_int(grab[0] + grab[1]).is_less(open[0] + open[1] - 40)


func test_every_pose_has_finger_angles_an_anchor_and_a_squash() -> void:
	for pose: int in HandModel.Pose.values():
		assert_int((HandModel.POSES[pose] as Array).size()).is_equal(HandModel.FINGERS.size())
		assert_bool(HandModel.ANCHORS.has(pose)).is_true()
		assert_bool(HandModel.PUNCH.has(pose)).is_true()


func test_a_finished_pose_blend_lands_exactly_on_the_target_pose() -> void:
	var landed := HandModel.blend(HandModel.POSES[HandModel.Pose.POINT], HandModel.POSES[HandModel.Pose.GRAB], 1.0)

	assert_array(landed).is_equal(as_floats(HandModel.POSES[HandModel.Pose.GRAB]))


func test_an_unstarted_pose_blend_is_still_the_old_pose() -> void:
	var start := HandModel.blend(HandModel.POSES[HandModel.Pose.POINT], HandModel.POSES[HandModel.Pose.GRAB], 0.0)

	assert_array(start).is_equal(as_floats(HandModel.POSES[HandModel.Pose.POINT]))


func test_a_still_hand_does_not_lean() -> void:
	assert_vector(HandModel.sway(Vector3.ZERO)).is_equal(Vector3.ZERO)


func test_a_hand_moving_right_rolls_right_and_one_moving_forward_tips_down() -> void:
	assert_float(HandModel.sway(Vector3(2, 0, 0)).z).is_less(0.0)
	assert_float(HandModel.sway(Vector3(0, 0, -2)).x).is_less(0.0)


func test_a_hand_never_leans_past_max_sway() -> void:
	var lean := HandModel.sway(Vector3(500, 0, -500)).abs()

	assert_float(lean.x).is_less_equal(HandModel.MAX_SWAY + 0.001)
	assert_float(lean.y).is_less_equal(HandModel.MAX_SWAY + 0.001)
	assert_float(lean.z).is_less_equal(HandModel.MAX_SWAY + 0.001)


func test_no_punch_leaves_the_hand_unscaled() -> void:
	assert_vector(HandModel.squash(0.0)).is_equal(Vector3.ONE)


func test_a_clench_flattens_and_widens_the_hand_and_a_pop_stretches_it() -> void:
	assert_float(HandModel.squash(1.0).y).is_less(1.0)
	assert_float(HandModel.squash(1.0).x).is_greater(1.0)
	assert_float(HandModel.squash(-0.5).y).is_greater(1.0)


func test_a_settled_hand_sits_exactly_on_its_new_pose() -> void:
	var model := SCENE.instantiate() as HandModel
	add_child(auto_free(model))
	model.pose = HandModel.Pose.GRAB
	for i in 120:
		model.move_to(Vector3.ZERO, 1.0 / 60.0)

	assert_float(model._settling).is_less_equal(0.0)
	assert_array(model._angles).is_equal(as_floats(HandModel.POSES[HandModel.Pose.GRAB]))


func test_a_hand_puts_its_pose_anchor_on_the_target() -> void:
	var model := SCENE.instantiate() as HandModel
	add_child(auto_free(model))
	var target := Vector3(0.4, 1.0, 0.2)
	model.move_to(target, 0.0)

	assert_vector(model.global_position + model.basis * HandModel.ANCHORS[HandModel.Pose.POINT]) \
			.is_equal_approx(target, Vector3.ONE * 0.0001)
