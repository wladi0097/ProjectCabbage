extends GdUnitTestSuite


func test_the_speech_bubble_never_takes_the_mouse_from_the_desk() -> void:
	var bubble := auto_free(ManagerBubble.new()) as ManagerBubble
	add_child(bubble)

	assert_int(bubble.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
