extends GdUnitTestSuite


func after_test() -> void:
	FarmTv.away = false


func test_a_refused_unit_hangs_no_slip_while_the_camera_is_at_the_farm_tv() -> void:
	var bubble: RefusalBubble = auto_free(RefusalBubble.new())
	add_child(bubble)
	FarmTv.away = true
	bubble.say(5, Vector3.ZERO)
	FarmTv.away = false
	assert_bool(bubble.showing()).is_false()


func test_a_slip_already_up_is_out_of_sight_while_the_camera_is_at_the_farm_tv() -> void:
	var bubble: RefusalBubble = auto_free(RefusalBubble.new())
	add_child(bubble)
	bubble.say(5, Vector3.ZERO)
	assert_bool(bubble.showing()).is_true()
	FarmTv.away = true
	assert_bool(bubble.showing()).is_false()
