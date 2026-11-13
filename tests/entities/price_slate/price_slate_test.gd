extends GdUnitTestSuite

const Slate := preload("res://entities/price_slate/price_slate.gd")
const PRICE_SLATE := preload("res://entities/price_slate/price_slate.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


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


func test_the_street_only_jumps_heavily_after_the_volatility_notice() -> void:
	var calm := 0.0
	var wild := 0.0
	for i in 400:
		calm = maxf(calm, absf(Slate.roll_mood(false)))
		wild = maxf(wild, absf(Slate.roll_mood(true)))
	assert_float(calm).is_less_equal(Slate.MOOD_STEP)
	assert_float(wild).is_greater(Slate.MOOD_STEP * 2.0)
	assert_float(wild).is_less_equal(Slate.WILD_STEP)
	assert_float(Slate.next_mood(1.2, 0.3)).is_equal(Slate.MOOD_RANGE.y)
	assert_float(Slate.next_mood(1.2, 0.3, true)).is_equal_approx(1.4, 0.0001)
	assert_float(Slate.next_mood(0.7, -0.3, true)).is_equal(Slate.WILD_RANGE.x)


func test_the_volatile_street_averages_the_same_full_sale_price_and_never_stops_buying() -> void:
	assert_float((Slate.WILD_RANGE.x + Slate.WILD_RANGE.y) / 2.0).is_equal_approx(1.0, 0.0001)
	# At its worst a price at the normal full-sale price still sells over a third.
	assert_float(Slate.demand(3, Slate.ref_price(1.0, Slate.WILD_RANGE.x))).is_greater(0.35)


func test_the_street_turns_volatile_two_minutes_after_the_promotion_report_is_signed() -> void:
	var save := _slate_save()
	var slate := _slate()
	slate._process(100.0)
	assert_bool(save.street_volatile).is_false()  # Promoted, but the report not signed yet.

	save.reports.append("promotion")
	slate._process(Slate.Events.VOLATILE_AFTER - 1.0)
	assert_bool(save.street_volatile).is_false()
	slate._process(1.0)
	assert_bool(save.street_volatile).is_true()


func test_the_forecast_shows_the_direction_the_street_will_really_take() -> void:
	var save := SaveGame.new()
	for case: Array in [[1.0, 0.2, false, 1], [1.0, -0.05, false, -1], [1.25, 0.05, false, 0], [1.25, 0.05, true, 1]]:
		save.demand_mood = case[0]
		save.mood_next = case[1]
		save.street_volatile = case[2]
		var was := save.demand_mood
		var way := Slate.forecast(save)
		assert_int(way).is_equal(case[3])
		assert_bool(Slate.tick_mood(save, Slate.MOOD_PERIOD, 0.0)).is_true()
		assert_int(signi(roundi((save.demand_mood - was) * 1000.0))).is_equal(way)


func test_the_mood_moves_once_a_minute_and_takes_the_step_rolled_ahead() -> void:
	var save := SaveGame.new()
	save.mood_next = -0.1
	assert_bool(Slate.tick_mood(save, 59.0, 0.05)).is_false()
	assert_int(Slate.forecast_seconds(save)).is_equal(1)
	assert_bool(Slate.tick_mood(save, 1.0, 0.05)).is_true()
	assert_float(save.demand_mood).is_equal_approx(0.9, 0.0001)
	assert_float(save.mood_next).is_equal(0.05)
	assert_int(Slate.forecast_seconds(save)).is_equal(60)


func test_the_forecast_clock_survives_a_reload() -> void:
	var save := SaveGame.new()
	save.mood_clock = 42.0
	save.mood_next = -0.2
	save.street_volatile = true
	var path := OS.get_user_data_dir().path_join("slate_forecast_test.tres")
	ResourceSaver.save(save, path)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	DirAccess.remove_absolute(path)

	assert_int(Slate.forecast_seconds(loaded)).is_equal(18)
	assert_int(Slate.forecast(loaded)).is_equal(-1)
	assert_bool(Slate.tick_mood(loaded, 18.0, 0.0)).is_true()
	assert_float(loaded.demand_mood).is_equal_approx(0.8, 0.0001)


func test_the_slate_shows_the_forecast_only_once_reads_the_room_is_bought() -> void:
	var save := _slate_save()
	var slate := _slate()
	slate._process(0.1)
	assert_bool(slate.get_node("Forecast").visible).is_false()

	save.tree_bought.append(Slate.FORECAST)
	save.mood_next = 0.1
	save.mood_clock = 18.0
	slate._process(0.0)
	assert_bool(slate.get_node("Forecast").visible).is_true()
	assert_str((slate.get_node("Forecast/Time") as Label3D).text).is_equal("0:42")


func _slate_save() -> SaveGame:
	SaveManager.save = SaveGame.new()
	SaveManager.save.slate_unlocked = true
	return SaveManager.save


func _slate() -> PriceSlate:
	var slate := PRICE_SLATE.instantiate() as PriceSlate
	add_child(auto_free(slate))
	slate.set_process(false)
	return slate


func test_holding_the_slates_arrow_keeps_stepping_the_price_and_each_step_tells_the_consultant_to_wait() -> void:
	var save := _slate_save()
	save.sale_price = 3
	var slate := _slate()
	var told := [0]
	slate.player_rewrote.connect(func() -> void: told[0] += 1)
	var up: Interactable = slate.get_node("Up/Interactable")
	up.grabbed.emit()
	assert_int(save.sale_price).is_equal(4)
	slate._process(Slate.HOLD_DELAY + 0.01)  # Still held: the first repeat...
	assert_int(save.sale_price).is_equal(5)
	slate._process(Slate.HOLD_REPEAT + 0.01)  # ...then one every HOLD_REPEAT.
	assert_int(save.sale_price).is_equal(6)
	assert_int(told[0]).is_equal(3)
	up.released.emit()
	slate._process(1.0)
	assert_int(save.sale_price).is_equal(6)
	assert_int(told[0]).is_equal(3)


func test_hovering_the_slate_explains_the_price_and_its_arrows() -> void:
	_slate_save()
	var slate := _slate()
	assert_str(Interactable.of(slate.get_node("Board")).tooltip).is_equal(Slate.BOARD_TIP)
