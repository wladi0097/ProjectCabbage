extends GdUnitTestSuite


func test_the_speech_bubble_never_takes_the_mouse_from_the_desk() -> void:
	var bubble := auto_free(ManagerBubble.new()) as ManagerBubble
	add_child(bubble)

	assert_int(bubble.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_quota_bubble_hangs_top_right_and_never_runs_off_the_screen() -> void:
	for width in [1280.0, 1920.0, 2560.0, 3440.0]:
		var x := ManagerBubble.centre_x(width)
		assert_float(x).is_greater(width * 0.7)
		assert_float(x + ManagerBubble.SIZE.x * ManagerBubble.SCALE / 2.0).is_less_equal(width - ManagerBubble.EDGE)
