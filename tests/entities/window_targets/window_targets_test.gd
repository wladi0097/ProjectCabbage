extends GdUnitTestSuite

const Targets := preload("res://entities/window_targets/window_targets.gd")


func test_the_next_target_comes_after_0_6_to_1_4_of_its_mean_wait() -> void:
	assert_float(Targets.next_wait(60.0, 0.0)).is_equal_approx(36.0, 0.0001)
	assert_float(Targets.next_wait(60.0, 1.0)).is_equal_approx(84.0, 0.0001)


func test_a_roll_lights_one_of_the_three_crates_evenly() -> void:
	assert_float(Targets.pick_centre(0.0)).is_equal(Targets.CRATE_X[0])
	assert_float(Targets.pick_centre(0.33)).is_equal(Targets.CRATE_X[0])
	assert_float(Targets.pick_centre(0.5)).is_equal(Targets.CRATE_X[1])
	assert_float(Targets.pick_centre(0.99)).is_equal(Targets.CRATE_X[2])


func test_a_roll_of_exactly_one_still_lights_the_last_crate() -> void:
	assert_float(Targets.pick_centre(1.0)).is_equal(Targets.CRATE_X[2])


func test_every_crate_lies_in_the_sell_span_right_of_the_qa_bay() -> void:
	assert_float(Targets.CRATE_X[0] - Targets.WIDTH / 2.0).is_greater_equal(SaleWindow.SPLIT_X)
	assert_float(Targets.CRATE_X[2] + Targets.WIDTH / 2.0).is_less_equal(SaleWindow.GAP_X.y + 0.1)


func test_a_sale_within_half_a_width_of_the_lit_crate_lands_in_it() -> void:
	assert_bool(Targets.hits(0.5, 0.6, 0.3)).is_true()
	assert_bool(Targets.hits(1.0, 0.75, 0.5)).is_true()


func test_a_sale_further_than_half_a_width_misses_the_lit_crate() -> void:
	assert_bool(Targets.hits(0.3, 0.6, 0.3)).is_false()
	assert_bool(Targets.hits(0.2, 0.6, 0.3)).is_false()


func test_a_bigger_target_size_catches_sales_a_standard_one_misses() -> void:
	var x := Targets.CRATE_X[1] + Targets.WIDTH * 0.75

	assert_bool(Targets.hits(x, Targets.CRATE_X[1], Targets.WIDTH)).is_false()
	assert_bool(Targets.hits(x, Targets.CRATE_X[1], Targets.WIDTH * 2.0)).is_true()


func test_no_target_lights_on_the_window_once_the_gun_is_bought() -> void:
	var save := SaveGame.new()
	save.stamped.append(Targets.CARD)
	assert_bool(Targets.shines(save)).is_true()
	save.stamped.append(Targets.Events.GUN_CARD)
	assert_bool(Targets.shines(save)).is_false()

