extends GdUnitTestSuite


func test_a_cabbage_on_the_mat_is_not_stray() -> void:
	assert_bool(SaleWindow.is_stray(Vector3(0.5, 0.85, 0.3))).is_false()


func test_a_cabbage_off_the_mat_or_hidden_behind_the_press_is_stray() -> void:
	assert_bool(SaleWindow.is_stray(Vector3(-1.2, 0.85, 0.3))).is_true()
	assert_bool(SaleWindow.is_stray(Vector3(0.5, 0.87, 1.4))).is_true()
	assert_bool(SaleWindow.is_stray(Vector3(1.7, 0.85, -0.6))).is_true()


func test_a_cabbage_resting_against_the_bottom_or_left_screen_bar_is_not_stray() -> void:
	# ScreenBottom at z 1.22 minus a 0.12 radius; LeftBar at x -0.564 plus 0.1.
	assert_bool(SaleWindow.is_stray(Vector3(0.2, 0.87, 1.11))).is_false()
	assert_bool(SaleWindow.is_stray(Vector3(-0.46, 0.87, 0.3))).is_false()


func test_the_qa_bay_takes_the_gaps_left_third_and_the_zone_keeps_its_right_edge() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	var zone := CollisionShape3D.new()
	zone.name = "Zone"
	var box := BoxShape3D.new()
	box.size = Vector3(2.12, 0.3, 0.58)
	zone.shape = box
	zone.position.x = 0.7
	window.add_child(zone)

	window.split()
	window.split()

	var width := (zone.shape as BoxShape3D).size.x
	assert_float(zone.position.x - width / 2.0).is_equal_approx(SaleWindow.SPLIT_X, 0.0001)
	assert_float(zone.position.x + width / 2.0).is_equal_approx(1.76, 0.0001)
	assert_float(window.sell_span().x).is_equal_approx(SaleWindow.SPLIT_X, 0.0001)
	assert_float(box.size.x).is_equal_approx(2.12, 0.0001)


func test_a_sale_pays_the_chalked_price_times_every_boost() -> void:
	assert_int(SaleWindow.payout(4, {})).is_equal(4)
	assert_int(SaleWindow.payout(4, {lamp = 5.0, combo = 1.5})).is_equal(30)


func test_a_sale_never_pays_less_than_one_coin() -> void:
	assert_int(SaleWindow.payout(1, {x = 0.1})).is_equal(1)
	assert_int(SaleWindow.payout(0.25, {})).is_equal(1)


func test_a_mini_pays_its_share_of_the_chalked_price() -> void:
	assert_int(SaleWindow.payout(8 * SaveGame.new().mini_value, {})).is_equal(2)


func test_selling_a_rotten_unit_costs_ten_times_the_price_but_never_more_than_the_tally() -> void:
	assert_int(SaleWindow.fine_for(4, 100)).is_equal(40)
	assert_int(SaleWindow.fine_for(4, 25)).is_equal(25)
	assert_int(SaleWindow.fine_for(4, 0)).is_equal(0)


func test_the_street_buys_exactly_its_acceptance_share_without_unlucky_streaks() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	window._owed = 0.0
	var bought: Array[bool] = []
	for i in 8:
		bought.append(window._buys(0.25))
	assert_array(bought).is_equal([false, false, false, true, false, false, false, true])


func test_a_sure_sale_always_sells_and_a_hopeless_price_never_does() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	window._owed = 0.0
	for i in 5:
		assert_bool(window._buys(1.0)).is_true()
	for i in 5:
		assert_bool(window._buys(0.0)).is_false()


func test_a_mini_is_accepted_35_percent_more_often_than_a_full_cabbage() -> void:
	assert_float(SaleWindow.acceptance_for(0.4, false)).is_equal_approx(0.4, 0.0001)
	assert_float(SaleWindow.acceptance_for(0.4, true)).is_equal_approx(0.54, 0.0001)


func test_a_minis_acceptance_never_goes_past_a_sure_sale() -> void:
	assert_float(SaleWindow.acceptance_for(0.9, true)).is_equal(1.0)


func test_a_golden_unit_sells_for_golden_sale_times_the_price() -> void:
	var save := SaveGame.new()
	assert_float(SaleWindow.golden_factor(true, save)).is_equal(10.0)
	assert_float(SaleWindow.golden_factor(false, save)).is_equal(1.0)
	assert_int(SaleWindow.payout(4 * SaleWindow.golden_factor(true, save), {})).is_equal(40)


func test_a_sale_counts_as_the_hands_when_a_hired_hand_lobbed_it_last_else_as_the_players() -> void:
	var save := SaveGame.new()
	SaleWindow.count_seller(save, true)
	SaleWindow.count_seller(save, false)
	SaleWindow.count_seller(save, false)
	assert_int(save.hand_sold).is_equal(1)
	assert_int(save.player_sold).is_equal(2)
