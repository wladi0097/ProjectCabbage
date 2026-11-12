extends GdUnitTestSuite

const Console := preload("res://entities/supply_console/supply_console.gd")
const Slate := preload("res://entities/price_slate/price_slate.gd")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


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
	assert_float(Console.crate_floor(save)).is_equal(0.0)


func test_after_the_shock_a_crate_unit_costs_sixty_percent_of_the_street_price() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	assert_float(Console.crate_floor(save)).is_equal_approx(0.6 * Slate.ref_price(1.0, 1.0), 0.0001)
	save.marketing = 2.0
	assert_float(Console.crate_floor(save)).is_equal_approx(0.6 * Slate.ref_price(2.0, 1.0), 0.0001)


func test_a_crate_unit_never_costs_less_than_the_textbook_pack_price() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.marketing = 0.1
	assert_int(Console.pack_price(1.0, 10, 1.0, Console.UNIT_COST, Console.crate_floor(save))).is_equal(Console.pack_price(1.0, 10))


func test_neither_the_pack_discount_nor_a_low_ticker_cheapens_a_stage_two_crate() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.marketing = 5.0
	var street := Slate.ref_price(save.marketing, 1.0)
	var shock := Console.pack_price(0.5, 10, 0.7, Console.UNIT_COST, Console.crate_floor(save)) / 10.0
	assert_float(shock).is_equal_approx(Console.SHOCK_SHARE * street, 0.1)
	save.stamped.append("family_farm")
	save.sale_price = roundi(street)
	var squeeze := Console.pack_price(0.5, 10, 0.7, Console.UNIT_COST, Console.crate_floor(save)) / 10.0
	assert_float(squeeze).is_greater(save.sale_price)


func test_during_the_squeeze_a_crate_unit_costs_more_than_the_street_pays_for_it() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.stamped.append("family_farm")
	assert_bool(Console.squeezing(save)).is_true()
	assert_float(Console.crate_floor(save)).is_greater(Slate.ref_price(save.marketing, 1.0))


func test_the_squeeze_needs_both_the_shock_and_the_farm() -> void:
	var save := SaveGame.new()
	save.stamped.append("family_farm")
	assert_bool(Console.squeezing(save)).is_false()
	assert_float(Console.crate_share(false, false)).is_equal(0.0)
	assert_float(Console.crate_share(true, false)).is_equal(Console.SHOCK_SHARE)
	save.supply_shock = true
	assert_bool(Console.squeezing(save)).is_true()


func test_once_the_squeeze_starts_crates_stay_dearer_than_the_street_price_for_good() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.stamped.append("family_farm")
	# The price has no clock left to run out (no lull): the lowest ticker, the biggest discount, any
	# marketing, still above the street.
	for marketing in [1.0, 3.0, 10.0]:
		save.marketing = marketing
		save.sale_price = roundi(Slate.ref_price(marketing, 1.0))
		var unit := Console.pack_price(0.5, 53, 0.5, Console.UNIT_COST, Console.crate_floor(save)) / 53.0
		assert_float(unit).is_greater(Slate.ref_price(marketing, 1.0))
		assert_float(unit).is_greater_equal(save.sale_price)


func test_in_the_squeeze_a_broke_desk_gets_no_cheap_bailout_crate() -> void:
	var save := SaveGame.new()
	assert_bool(Console.bails_out(save)).is_true()
	save.supply_shock = true
	assert_bool(Console.bails_out(save)).is_true()
	save.stamped.append("family_farm")  # A farm with no seeds or crops left: still no bailout.
	assert_bool(Console.bails_out(save)).is_false()


func test_with_no_stock_and_not_enough_coins_for_a_pack_the_desk_is_broke() -> void:
	assert_bool(Console.is_broke(0, 3, 6)).is_true()
	assert_bool(Console.is_broke(0, 6, 6)).is_false()
	assert_bool(Console.is_broke(1, 0, 6)).is_false()
	assert_bool(Console.is_broke(0, 0, 0)).is_false()


func test_a_pack_is_only_bought_while_it_fits_in_storage() -> void:
	assert_int(SaveGame.new().storage_cap).is_equal(20)
	assert_bool(SupplyConsole.fits(10, 10, 20)).is_true()
	assert_bool(SupplyConsole.fits(11, 10, 20)).is_false()
	assert_bool(SupplyConsole.fits(0, 53, 20)).is_false()


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


func test_the_auto_lamp_and_switch_follow_the_standing_order_when_the_shock_switches_it_off() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["auto_procurement"])
	SaveManager.save = save
	var console: SupplyConsole = auto_free(load("res://entities/supply_console/supply_console.tscn").instantiate())
	add_child(console)
	assert_that(console._auto.modulate).is_equal(Console.AMBER)
	assert_float(console._toggle._pivot.rotation.x).is_equal_approx(-LightSwitch.TILT, 0.001)

	UpgradeDesk.start_shock(save)
	console._process(0.0)
	await await_millis(int(LightSwitch.FLICK_TIME * 1000.0) + 100)

	assert_bool(save.auto_buy).is_false()
	assert_that(console._auto.modulate).is_equal(Console.AUTO_OFF)
	assert_float(console._toggle._pivot.rotation.x).is_equal_approx(LightSwitch.TILT, 0.001)


func test_from_130_units_in_stock_a_pack_costs_five_times_as_much_at_once() -> void:
	assert_int(Console.overstock_price(20, 129)).is_equal(20)
	assert_int(Console.overstock_price(20, 130)).is_equal(100)


func test_packs_bought_by_the_button_and_by_the_standing_order_are_counted_apart() -> void:
	var save := SaveGame.new()
	save.coins = 1000
	save.stock = 0
	save.storage_cap = 100
	SaveManager.save = save
	var console: SupplyConsole = auto_free(load("res://entities/supply_console/supply_console.tscn").instantiate())
	add_child(console)
	console._press()
	console._press(true)
	console._press(true)
	assert_int(save.packs_manual).is_equal(1)
	assert_int(save.packs_auto).is_equal(2)
