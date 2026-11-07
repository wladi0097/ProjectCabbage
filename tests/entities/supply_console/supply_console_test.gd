extends GdUnitTestSuite

const Console := preload("res://entities/supply_console/supply_console.gd")
const Slate := preload("res://entities/price_slate/price_slate.gd")


func test_the_pack_price_factor_is_base_one_plus_pressure_plus_noise() -> void:
	assert_float(Console.next_factor(0.0, 0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(Console.next_factor(0.12, 0.1)).is_equal_approx(1.22, 0.0001)


func test_the_pack_price_factor_stays_within_fifty_percent_of_the_base() -> void:
	assert_float(Console.next_factor(0.9, 0.25)).is_equal_approx(1.5, 0.0001)
	assert_float(Console.next_factor(0.0, -0.7)).is_equal_approx(0.5, 0.0001)


func test_a_pack_costs_its_cabbages_at_unit_cost_times_factor_and_discount() -> void:
	assert_int(Console.pack_price(1.0, 13, 1.0)).is_equal(14)
	assert_int(Console.pack_price(0.5, 10, 1.0)).is_equal(5)
	assert_int(Console.pack_price(1.5, 10, 1.0)).is_equal(16)
	assert_int(Console.pack_price(1.0, 10, 0.5)).is_equal(5)


func test_a_pack_never_costs_less_than_one_dollar() -> void:
	assert_int(Console.pack_price(0.5, 1, 1.0)).is_equal(1)
	assert_int(Console.pack_price(0.5, 1, 0.1)).is_equal(1)


func test_a_dearer_unit_makes_the_whole_pack_dearer() -> void:
	assert_int(Console.pack_price(1.0, 10, 1.0, 1.8)).is_equal(18)


func test_before_the_shock_a_pack_unit_costs_the_textbook_unit_cost_whatever_the_marketing() -> void:
	var save := SaveGame.new()
	save.marketing = 4.0
	assert_float(Console.crate_share(false, 600.0)).is_equal(0.0)
	assert_float(Console.unit_cost(save)).is_equal_approx(Console.UNIT_COST, 0.0001)


func test_after_the_shock_a_crate_unit_costs_sixty_percent_of_the_street_price() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	assert_float(Console.unit_cost(save)).is_equal_approx(0.6 * Slate.ref_price(1.0, 1.0), 0.0001)
	save.marketing = 2.0
	assert_float(Console.unit_cost(save)).is_equal_approx(0.6 * Slate.ref_price(2.0, 1.0), 0.0001)


func test_a_crate_unit_never_costs_less_than_the_textbook_unit_cost() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.marketing = 0.1
	assert_float(Console.unit_cost(save)).is_equal_approx(Console.UNIT_COST, 0.0001)


func test_during_the_squeeze_a_crate_unit_costs_more_than_the_street_pays_for_it() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.squeeze_left = Console.SQUEEZE_TIME + Console.EASE_TIME
	assert_float(Console.unit_cost(save)).is_greater(Slate.ref_price(save.marketing, 1.0))
	save.squeeze_left = Console.EASE_TIME
	assert_float(Console.crate_share(true, save.squeeze_left)).is_equal_approx(Console.SQUEEZE_SHARE, 0.0001)


func test_the_squeeze_eases_back_to_the_shock_share_over_its_last_minutes() -> void:
	var half := Console.crate_share(true, Console.EASE_TIME * 0.5)
	assert_float(half).is_equal_approx((Console.SHOCK_SHARE + Console.SQUEEZE_SHARE) * 0.5, 0.0001)
	assert_float(Console.crate_share(true, Console.EASE_TIME * 0.25)).is_less(half)
	assert_float(Console.crate_share(true, 0.0)).is_equal_approx(Console.SHOCK_SHARE, 0.0001)


func test_with_no_stock_and_not_enough_coins_for_a_pack_the_desk_is_broke() -> void:
	assert_bool(Console.is_broke(0, 3, 6)).is_true()
	assert_bool(Console.is_broke(0, 6, 6)).is_false()
	assert_bool(Console.is_broke(1, 0, 6)).is_false()
	assert_bool(Console.is_broke(0, 0, 0)).is_false()


func test_auto_buy_waits_until_stock_is_down_to_the_reserve_and_the_tally_can_pay() -> void:
	assert_bool(Console.should_auto_buy(3, 3, 1.4, 1.5, 20, 10)).is_true()
	assert_bool(Console.should_auto_buy(4, 3, 1.0, 1.5, 20, 10)).is_false()
	assert_bool(Console.should_auto_buy(2, 3, 1.0, 1.5, 5, 10)).is_false()


func test_auto_buy_waits_for_a_fair_price_only_while_stock_is_left() -> void:
	assert_bool(Console.should_auto_buy(2, 3, 1.3, 1.0, 20, 10)).is_false()
	assert_bool(Console.should_auto_buy(2, 3, 1.0, 1.0, 20, 10)).is_true()
	assert_bool(Console.should_auto_buy(0, 3, 1.3, 1.0, 20, 10)).is_true()


func test_the_sparkline_puts_the_newest_price_at_the_right_edge_and_the_band_top_to_bottom() -> void:
	var line := Console.sparkline(PackedFloat32Array([0.5, 1.5]), 5, Vector2(4, 1))
	assert_array(Array(line)).is_equal([Vector2(3, 0), Vector2(4, 1)])


func test_a_made_up_history_walks_back_from_the_current_price_within_the_band() -> void:
	var walked := Console.walk_back(1.4, PackedFloat32Array([0.2, -0.3, 0.1]))
	assert_int(walked.size()).is_equal(4)
	for i in 4:
		assert_float(walked[i]).is_equal_approx([1.4, 1.5, 1.2, 1.4][i], 0.0001)
	assert_float(Console.walk_back(1.45, PackedFloat32Array([-0.2]))[0]).is_equal_approx(1.5, 0.0001)
