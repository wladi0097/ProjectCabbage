extends GdUnitTestSuite

const CONSULTANT := preload("res://entities/consultant/consultant.tscn")
const PRICE_SLATE := preload("res://entities/price_slate/price_slate.tscn")
const Slate := preload("res://entities/price_slate/price_slate.gd")
const STEP := 0.05

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


## A stamped consultant beside an unlocked slate at $2, aiming at $5 (marketing 1.5, skill 0).
func _desk() -> Consultant:
	var save := SaveManager.save
	save.stamped.append(Consultant.CARD)
	save.slate_unlocked = true
	save.marketing = 1.5
	save.sale_price = 2
	var slate := PRICE_SLATE.instantiate() as PriceSlate
	add_child(auto_free(slate))
	slate.set_process(false)
	var consultant := CONSULTANT.instantiate() as Consultant
	consultant.slate = slate
	add_child(auto_free(consultant))
	consultant.set_process(false)
	return consultant


func _run(consultant: Consultant, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		consultant._process(STEP)


func test_a_junior_consultant_aims_where_about_nine_in_ten_units_sell_at_a_normal_mood() -> void:
	var save := SaveGame.new()
	save.marketing = 1.5
	save.demand_mood = 1.2

	assert_int(Consultant.target_price(save, 0)).is_equal(5)


func test_a_skilled_consultant_reads_the_streets_mood() -> void:
	var save := SaveGame.new()
	save.marketing = 1.5
	save.demand_mood = 1.2

	assert_int(Consultant.target_price(save, 1)).is_equal(6)


func test_no_whole_price_sells_nearer_ninety_percent_than_the_juniors_aim() -> void:
	var save := SaveGame.new()
	save.marketing = 3.0
	var ref := Slate.ref_price(save.marketing, 1.0)
	var aim := Consultant.target_price(save, 0)
	var miss := absf(Slate.demand(aim, ref) - Consultant.TARGET_ACCEPTANCE)
	for price in range(Slate.MIN_PRICE, Slate.max_price(save.marketing) + 1):
		assert_float(absf(Slate.demand(price, ref) - Consultant.TARGET_ACCEPTANCE)).is_greater_equal(miss - 0.0001)


func test_a_senior_consultant_earns_the_most_per_unit_after_pack_costs() -> void:
	var save := SaveGame.new()
	save.marketing = 1.5
	save.demand_mood = 1.2
	var ref := Slate.ref_price(save.marketing, save.demand_mood)
	var cost := SupplyConsole.pack_price(save.price_factor, save.pack_size) / float(save.pack_size)
	var best := Consultant.income(Consultant.target_price(save, 2), ref, cost)
	for price in range(Slate.MIN_PRICE, Slate.max_price(save.marketing) + 1):
		assert_float(Consultant.income(price, ref, cost)).is_less_equal(best + 0.001)


func test_dearer_stage_two_crates_push_the_senior_consultants_price_up() -> void:
	var save := SaveGame.new()
	assert_int(Consultant.target_price(save, 2)).is_equal(3)

	save.supply_shock = true
	assert_int(Consultant.target_price(save, 2)).is_equal(4)


func test_during_the_squeeze_the_senior_consultant_ignores_crate_prices_since_none_are_bought() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.squeeze_left = SupplyConsole.SQUEEZE_TIME + SupplyConsole.EASE_TIME

	assert_int(Consultant.target_price(save, 2)).is_equal(3)


func test_once_the_squeeze_eases_the_senior_consultant_counts_crate_prices_again() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.squeeze_left = SupplyConsole.EASE_TIME - 1.0

	assert_int(Consultant.target_price(save, 2)).is_greater(3)


func test_a_senior_consultant_prices_crates_as_the_console_does_after_its_discount() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.pack_discount = 0.7
	save.price_factor = 0.5
	var discounted := Consultant.target_price(save, 2)
	save.pack_discount = 1.0
	save.price_factor = 1.0

	assert_int(discounted).is_equal(Consultant.target_price(save, 2))


func test_with_hired_hands_the_senior_consultant_throttles_only_while_no_markup_is_set() -> void:
	var save := SaveGame.new()
	save.consultant_skill = 2
	save.hands = 1
	assert_bool(Consultant.throttles(save)).is_true()
	save.consultant_markup = 0.2
	assert_bool(Consultant.throttles(save)).is_false()


func test_a_step_down_on_the_slate_never_comes_back_as_a_dearer_price() -> void:
	var consultant := _desk()
	var save := SaveManager.save
	save.consultant_skill = 2
	save.hands = 1
	var target := Consultant.target_price(save, 2)
	consultant._extra = 3
	save.sale_price = target + 2
	consultant.slate.player_rewrote.emit()

	_run(consultant, Consultant.PLAYER_PAUSE + 30.0)

	assert_int(save.sale_price).is_less_equal(target + 2)
	assert_int(consultant._extra).is_equal(0)


func test_income_per_unit_is_the_chance_of_a_sale_times_the_margin() -> void:
	assert_float(Consultant.income(6, 5.4, 1.1)).is_equal_approx(0.81 * 4.9, 0.0001)
	assert_float(Consultant.income(4, 5.4, 1.1)).is_equal_approx(2.9, 0.0001)


func test_the_target_never_drops_under_the_slates_minimum() -> void:
	var save := SaveGame.new()
	save.marketing = 0.2

	assert_int(Consultant.target_price(save, 0)).is_equal(Slate.MIN_PRICE)


func test_the_throttle_asks_a_step_more_while_the_hands_are_starved() -> void:
	assert_int(Consultant.throttle(0, false, 5, 5.0)).is_equal(1)
	assert_int(Consultant.throttle(1, false, 5, 5.0)).is_equal(2)


func test_the_throttle_stops_at_one_point_six_times_the_full_sale_price() -> void:
	assert_int(Consultant.throttle(3, false, 5, 5.0)).is_equal(3)
	assert_int(Consultant.throttle(0, false, 10, 5.0)).is_equal(0)


func test_the_throttle_gives_a_step_back_whenever_a_unit_waits() -> void:
	assert_int(Consultant.throttle(2, true, 5, 5.0)).is_equal(1)
	assert_int(Consultant.throttle(0, true, 5, 5.0)).is_equal(0)


func test_the_consultant_taps_the_price_one_step_toward_its_target() -> void:
	var consultant := _desk()

	_run(consultant, 7.0)

	assert_int(SaveManager.save.sale_price).is_equal(3)


func test_on_target_the_consultant_never_reaches_in() -> void:
	var consultant := _desk()
	SaveManager.save.sale_price = 5

	_run(consultant, 10.0)

	assert_int(SaveManager.save.sale_price).is_equal(5)
	assert_int(consultant._phase).is_equal(Consultant.Phase.AWAY)


func test_the_consultant_does_nothing_before_its_card_is_stamped() -> void:
	var consultant := _desk()
	SaveManager.save.stamped.clear()

	_run(consultant, 10.0)

	assert_int(SaveManager.save.sale_price).is_equal(2)


func test_a_player_press_on_the_slate_sends_the_consultant_away_for_fifteen_seconds() -> void:
	var consultant := _desk()
	_run(consultant, 3.0)

	# The player leaves it at $2 (60% under the consultant's $5), then marketing moves its aim to $4.
	consultant.slate.player_rewrote.emit()
	SaveManager.save.marketing = 3.0
	_run(consultant, Consultant.PLAYER_PAUSE - 1.0)

	assert_int(SaveManager.save.sale_price).is_equal(2)
	assert_int(consultant._phase).is_equal(Consultant.Phase.AWAY)

	_run(consultant, 6.0)
	assert_int(SaveManager.save.sale_price).is_equal(3)


func test_the_adviser_keeps_the_markup_the_player_set() -> void:
	var consultant := _desk()
	SaveManager.save.sale_price = 6
	consultant.slate.player_rewrote.emit()
	assert_float(SaveManager.save.consultant_markup).is_equal_approx(0.2, 0.0001)

	_run(consultant, 30.0)
	assert_int(SaveManager.save.sale_price).is_equal(6)

	# Its own target rises from $5 to $10, so it now steers to $12, 20% over.
	SaveManager.save.marketing = 3.0
	_run(consultant, 5.0)
	assert_int(SaveManager.save.sale_price).is_equal(7)


func test_holding_the_slates_arrow_resets_the_markup_on_every_step() -> void:
	var consultant := _desk()
	consultant.slate._step = 1
	consultant.slate._wait = 0.0

	consultant.slate._process(STEP)

	assert_int(SaveManager.save.sale_price).is_equal(3)
	assert_float(SaveManager.save.consultant_markup).is_equal_approx(-0.4, 0.0001)


func test_with_no_markup_the_adviser_aims_at_its_own_target() -> void:
	var save := SaveGame.new()
	save.marketing = 1.5

	assert_int(Consultant.aim(save, 0)).is_equal(Consultant.target_price(save, 0))


func test_the_adviser_aims_the_players_markup_over_its_target_within_the_slate() -> void:
	var save := SaveGame.new()
	save.marketing = 3.0
	save.consultant_markup = 0.2
	assert_int(Consultant.aim(save, 0)).is_equal(12)

	save.consultant_markup = 9.0
	assert_int(Consultant.aim(save, 0)).is_equal(Slate.max_price(save.marketing))


func test_left_on_its_target_the_players_markup_is_zero_again() -> void:
	assert_float(Consultant.markup(5, 5)).is_equal(0.0)
	assert_float(Consultant.markup(6, 5)).is_equal_approx(0.2, 0.0001)


func test_pricing_before_the_consultant_is_retained_sets_no_markup() -> void:
	var consultant := _desk()
	SaveManager.save.stamped.clear()

	consultant.slate.player_rewrote.emit()

	assert_float(SaveManager.save.consultant_markup).is_equal(0.0)


func test_switched_off_mid_reach_the_consultant_withdraws_and_stays_away() -> void:
	var consultant := _desk()
	_run(consultant, 3.0)

	SaveManager.save.consultant_on = false
	_run(consultant, 10.0)

	assert_int(SaveManager.save.sale_price).is_equal(2)
	assert_int(consultant._phase).is_equal(Consultant.Phase.AWAY)


func test_the_slate_switch_sends_the_consultant_away_and_calls_it_back() -> void:
	var consultant := _desk()

	consultant._flick()
	assert_bool(SaveManager.save.consultant_on).is_false()

	consultant._flick()
	assert_bool(SaveManager.save.consultant_on).is_true()


func test_the_switch_is_on_the_slate_only_once_the_card_is_stamped() -> void:
	var consultant := _desk()
	SaveManager.save.stamped.clear()
	consultant._process(STEP)
	assert_bool(consultant._switch.visible).is_false()

	SaveManager.save.stamped.append(Consultant.CARD)
	consultant._process(STEP)
	assert_bool(consultant._switch.visible).is_true()
