extends GdUnitTestSuite

const DeskButton := preload("res://entities/map_table/props/desk_button.gd")


func test_a_pressed_button_goes_in_six_millimetres_fast_and_springs_back_slower() -> void:
	assert_float(DeskButton.depth(0.0)).is_equal(0.0)
	assert_float(DeskButton.depth(DeskButton.DOWN)).is_equal_approx(0.006, 0.00001)
	assert_float(DeskButton.depth(1.0)).is_equal_approx(0.0, 0.00001)
	assert_float(DeskButton.DOWN).is_less(0.5)
	for k: float in [0.1, 0.4, 0.7, 0.9]:
		assert_float(DeskButton.depth(k)).is_between(0.0, DeskButton.TRAVEL)
