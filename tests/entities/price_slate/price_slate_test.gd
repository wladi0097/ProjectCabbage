extends GdUnitTestSuite

const Slate := preload("res://entities/price_slate/price_slate.gd")


func test_at_or_below_the_full_sale_price_every_cabbage_sells() -> void:
	var ref := Slate.ref_price(1.0, 1.0)
	assert_float(ref).is_equal(3.0)
	assert_float(Slate.demand(1, ref)).is_equal(1.0)
	assert_float(Slate.demand(2, ref)).is_equal(1.0)
	assert_float(Slate.demand(3, ref)).is_equal(1.0)


func test_above_the_full_sale_price_sales_fall_with_the_square_of_the_overprice() -> void:
	var ref := Slate.ref_price(1.0, 1.0)
	assert_float(Slate.demand(4, ref)).is_equal_approx(0.5625, 0.0001)
	assert_float(Slate.demand(6, ref)).is_equal_approx(0.25, 0.0001)
	assert_float(Slate.demand(30, ref)).is_equal_approx(0.01, 0.0001)


func test_overpricing_earns_less_per_flicked_cabbage_than_the_full_sale_price() -> void:
	var ref := Slate.ref_price(1.0, 1.0)
	for price in [4, 6, 12]:
		assert_float(price * Slate.demand(price, ref)).is_less(3.0 * Slate.demand(3, ref))


func test_marketing_raises_the_full_sale_price_in_proportion() -> void:
	assert_float(Slate.ref_price(2.0, 1.0)).is_equal(6.0)
	assert_float(Slate.demand(6, Slate.ref_price(2.0, 1.0))).is_equal(1.0)


func test_a_sour_street_mood_lowers_the_full_sale_price() -> void:
	assert_float(Slate.ref_price(1.0, 0.75)).is_equal_approx(2.25, 0.0001)
	assert_float(Slate.demand(3, Slate.ref_price(1.0, 0.75))).is_equal_approx(0.5625, 0.0001)
	assert_float(Slate.demand(3, Slate.ref_price(1.0, 1.25))).is_equal(1.0)


func test_a_new_save_sells_every_cabbage_at_its_starting_price() -> void:
	assert_float(Slate.acceptance(SaveGame.new())).is_equal(1.0)


func test_acceptance_reads_price_marketing_and_mood_from_the_save() -> void:
	var save := SaveGame.new()
	save.sale_price = 6
	save.marketing = 1.5
	save.demand_mood = 0.8
	assert_float(Slate.acceptance(save)).is_equal_approx(pow(3.6 / 6.0, 2.0), 0.0001)


func test_the_slate_price_ceiling_is_twelve_times_marketing_rounded() -> void:
	assert_int(Slate.max_price(1.0)).is_equal(12)
	assert_int(Slate.max_price(1.25)).is_equal(15)
	assert_int(Slate.max_price(2.25)).is_equal(27)


func test_the_full_sale_price_never_reaches_the_slate_ceiling_even_in_the_best_mood() -> void:
	for marketing in [0.5, 1.0, 1.25, 3.0, 50.0]:
		assert_float(Slate.ref_price(marketing, Slate.MOOD_RANGE.y)).is_less(Slate.max_price(marketing))


func test_the_lowest_price_on_the_slate_is_one_dollar() -> void:
	assert_int(Slate.MIN_PRICE).is_equal(1)


func test_the_street_mood_drifts_by_its_step_but_never_leaves_its_range() -> void:
	assert_float(Slate.next_mood(1.0, 0.1)).is_equal_approx(1.1, 0.0001)
	assert_float(Slate.next_mood(1.0, -0.1)).is_equal_approx(0.9, 0.0001)
	assert_float(Slate.next_mood(1.2, 0.1)).is_equal(Slate.MOOD_RANGE.y)
	assert_float(Slate.next_mood(0.8, -0.1)).is_equal(Slate.MOOD_RANGE.x)


func test_a_refusal_wiggle_starts_and_ends_at_rest_and_shakes_in_between() -> void:
	assert_float(Slate.wiggle_at(0.0)).is_equal(0.0)
	assert_float(Slate.wiggle_at(Slate.WIGGLE_TIME)).is_equal(0.0)
	assert_float(Slate.wiggle_at(Slate.WIGGLE_TIME + 1.0)).is_equal(0.0)
	assert_float(absf(Slate.wiggle_at(0.04))).is_greater(0.05)


func test_the_gauge_needle_points_up_at_even_odds_left_for_never_and_right_for_always() -> void:
	assert_float(Slate.needle_angle(0.5)).is_equal_approx(0.0, 0.0001)
	assert_float(Slate.needle_angle(0.0)).is_equal_approx(deg_to_rad(120.0), 0.0001)
	assert_float(Slate.needle_angle(1.0)).is_equal_approx(deg_to_rad(-120.0), 0.0001)
