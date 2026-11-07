extends GdUnitTestSuite

const FramedCamera := preload("res://worlds/components/framed_camera.gd")


func test_on_a_square_screen_the_horizontal_view_equals_the_vertical_one() -> void:
	assert_float(FramedCamera.horizontal_fov(60.0, 1.0)).is_equal_approx(60.0, 0.0001)


func test_a_16_9_view_with_60_degrees_vertical_spans_about_91_5_degrees_across() -> void:
	# 2 * atan(tan(30 deg) * 16 / 9)
	assert_float(FramedCamera.horizontal_fov(60.0, FramedCamera.SAFE_ASPECT)).is_equal_approx(91.49, 0.01)


func test_converting_back_from_the_horizontal_view_gives_the_authored_vertical_one() -> void:
	var across := FramedCamera.horizontal_fov(50.0, FramedCamera.SAFE_ASPECT)
	assert_float(FramedCamera.horizontal_fov(across, 1.0 / FramedCamera.SAFE_ASPECT)).is_equal_approx(50.0, 0.0001)
