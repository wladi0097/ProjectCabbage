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


## A stamped consultant beside an unlocked slate at $2, aiming at $5 (marketing 1.5, mood 1, 10% refused).
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
	consultant._sheet.set_process(false)
	return consultant


func _run(consultant: Consultant, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		consultant._process(STEP)


func _street(marketing: float, mood: float) -> SaveGame:
	var save := SaveGame.new()
	save.marketing = marketing
	save.demand_mood = mood
	return save


func test_the_helper_holds_the_bounce_the_player_asked_for() -> void:
	var save := _street(1.5, 1.0)
	assert_int(Consultant.target_price(save)).is_equal(5)
	save.consultant_bounce = 50
	assert_int(Consultant.target_price(save)).is_equal(6)


func test_no_whole_price_comes_nearer_the_bounce_asked_than_the_helpers() -> void:
	var save := _street(3.0, 0.8)
	var ref := Slate.ref_price(save.marketing, save.demand_mood)
	for asked in [0, 10, 25, 50]:
		save.consultant_bounce = asked
		var miss := absf(Consultant.bounce(Consultant.target_price(save), ref) - asked / 100.0)
		for price in range(Slate.MIN_PRICE, Slate.max_price(save.marketing) + 1):
			assert_float(absf(Consultant.bounce(price, ref) - asked / 100.0)).is_greater_equal(miss - 0.0001)


func test_with_no_bounce_allowed_the_helper_chalks_the_dearest_price_that_sells_every_cabbage() -> void:
	var save := _street(1.5, 1.0)
	save.consultant_bounce = 0
	assert_int(Consultant.target_price(save)).is_equal(4)


func test_the_helper_obeys_its_mandate_against_the_current_mood() -> void:
	assert_int(Consultant.target_price(_street(1.5, 1.2))).is_equal(6)
	assert_int(Consultant.target_price(_street(1.5, 0.6))).is_equal(3)


func test_the_helper_never_chalks_below_the_floor_or_above_the_ceiling() -> void:
	var save := _street(1.5, 1.0)
	save.consultant_floor = 7
	assert_int(Consultant.target_price(save)).is_equal(7)
	save.consultant_floor = 1
	save.consultant_ceiling = 4
	assert_int(Consultant.target_price(save)).is_equal(4)


func test_the_bounce_allowed_steps_by_five_percent_from_none_to_half() -> void:
	assert_float(Consultant.step_bounce(10, 1)).is_equal(15.0)
	assert_float(Consultant.step_bounce(10, -1)).is_equal(5.0)
	assert_float(Consultant.step_bounce(0, -1)).is_equal(0.0)
	assert_float(Consultant.step_bounce(50, 1)).is_equal(50.0)
	# A share adopted from a hand-set price steps back onto the fives, and never up past itself over half.
	assert_float(Consultant.step_bounce(43.75, -1)).is_equal(40.0)
	assert_float(Consultant.step_bounce(43.75, 1)).is_equal(50.0)
	assert_float(Consultant.step_bounce(73.0, 1)).is_equal(73.0)
	assert_float(Consultant.step_bounce(73.0, -1)).is_equal(70.0)


func test_the_floor_never_climbs_over_the_ceiling_nor_the_ceiling_under_the_floor() -> void:
	var save := SaveGame.new()
	save.consultant_ceiling = 5
	save.consultant_floor = 5
	assert_int(Consultant.step_floor(save, 1)).is_equal(5)
	assert_int(Consultant.step_ceiling(save, -1)).is_equal(5)
	save.consultant_floor = 1
	assert_int(Consultant.step_floor(save, -1)).is_equal(Slate.MIN_PRICE)


func test_with_no_ceiling_set_the_ceiling_steps_down_from_the_slates_top_and_up_past_it_to_none() -> void:
	var save := SaveGame.new()
	assert_int(Consultant.ceiling_of(save)).is_equal(12)  # The slate's top at marketing 1.
	assert_int(Consultant.step_ceiling(save, 1)).is_equal(0)
	assert_int(Consultant.step_ceiling(save, -1)).is_equal(11)
	save.consultant_ceiling = 12
	assert_int(Consultant.step_ceiling(save, 1)).is_equal(0)


func test_a_new_mandate_lets_ten_percent_be_refused_with_no_price_limits() -> void:
	var save := SaveGame.new()
	assert_float(save.consultant_bounce).is_equal(10.0)
	assert_int(save.consultant_floor).is_equal(Slate.MIN_PRICE)
	assert_int(save.consultant_ceiling).is_equal(0)
	assert_bool(save.consultant_on).is_true()


func test_in_the_squeeze_the_consultant_never_aims_above_the_crate_unit_cost() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.marketing = 10
	save.stamped.append("family_farm")
	# A crate unit costs 125% of the $30 full-sale price: $37.50, so $37 at most.
	for asked in [0, 10, 50]:
		save.consultant_bounce = asked
		assert_int(Consultant.target_price(save)).is_less_equal(37)
	save.consultant_floor = 99
	assert_int(Consultant.target_price(save)).is_less_equal(37)
	assert_int(Consultant.squeeze_cap(save)).is_equal(37)
	# Outside the squeeze (the shock without the farm) nothing is capped: the slate's $120 top.
	save.stamped.clear()
	assert_int(Consultant.squeeze_cap(save)).is_equal(120)


func test_the_target_never_drops_under_the_slates_minimum() -> void:
	assert_int(Consultant.target_price(_street(0.2, 1.0))).is_equal(Slate.MIN_PRICE)


func test_the_consultant_taps_the_price_one_step_toward_its_target() -> void:
	var consultant := _desk()

	_run(consultant, 7.0)

	assert_int(SaveManager.save.sale_price).is_equal(3)


func test_yield_optimisation_chalks_the_target_in_one_visit() -> void:
	var save := SaveGame.new()
	save.sale_price = 2
	assert_int(Consultant.tap(save, 5)).is_equal(1)
	save.tree_bought.append(Consultant.SMART)
	assert_int(Consultant.tap(save, 5)).is_equal(3)
	assert_int(Consultant.tap(save, 1)).is_equal(-1)

	var consultant := _desk()
	SaveManager.save.tree_bought.append(Consultant.SMART)
	_run(consultant, 7.0)
	assert_int(SaveManager.save.sale_price).is_equal(5)


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


## The player chalks `price` by hand on the desk's slate.
func _press(consultant: Consultant, price: int) -> void:
	SaveManager.save.sale_price = price
	consultant.slate.player_rewrote.emit()


func test_a_manual_change_sets_the_mandate_to_the_new_prices_refusal_share() -> void:
	var save := _street(1.5, 1.0)
	save.stamped.append(Consultant.CARD)
	save.sale_price = 6
	Consultant.adopt(save)
	# $6 against the $4.50 full-sale price: 1 - (4.5 / 6)^2 = 43.75% refused.
	assert_float(save.consultant_bounce).is_equal_approx(43.75, 0.001)
	assert_int(Consultant.target_price(save)).is_equal(6)


func test_the_consultant_keeps_the_players_price_at_an_unchanged_mood() -> void:
	var consultant := _desk()
	_press(consultant, 6)
	_run(consultant, 20.0)
	assert_int(SaveManager.save.sale_price).is_equal(6)
	assert_int(consultant._phase).is_equal(Consultant.Phase.AWAY)

	# Even under the full-sale price, where every cabbage sells: that price becomes the ceiling.
	_press(consultant, 2)
	_run(consultant, 20.0)
	assert_int(SaveManager.save.sale_price).is_equal(2)
	assert_int(SaveManager.save.consultant_ceiling).is_equal(2)


func test_a_price_outside_the_mandates_limits_widens_them() -> void:
	var save := _street(1.5, 1.0)
	save.consultant_floor = 5
	save.consultant_ceiling = 7
	save.sale_price = 9
	Consultant.adopt(save)
	assert_int(save.consultant_ceiling).is_equal(9)
	save.sale_price = 3
	Consultant.adopt(save)
	assert_int(save.consultant_floor).is_equal(3)
	assert_int(Consultant.target_price(save)).is_equal(3)


func test_after_a_hand_change_the_consultant_follows_the_mood_with_the_players_share() -> void:
	var save := _street(1.5, 1.0)
	save.sale_price = 6
	Consultant.adopt(save)
	# A better mood: the $5.40 full-sale price refuses about the same share at $7 (40.5%).
	save.demand_mood = 1.2
	assert_int(Consultant.target_price(save)).is_equal(7)
	save.demand_mood = 0.8
	assert_int(Consultant.target_price(save)).is_equal(5)
	assert_float(save.consultant_bounce).is_equal_approx(43.75, 0.001)


func test_holding_an_arrow_is_never_fought() -> void:
	var consultant := _desk()
	_run(consultant, 3.0)  # On its way to $5.
	for price in range(3, 13):
		_press(consultant, price)
		_run(consultant, 0.1)
		assert_int(SaveManager.save.sale_price).is_equal(price)
	_run(consultant, 30.0)
	assert_int(SaveManager.save.sale_price).is_equal(12)
	assert_int(consultant._phase).is_equal(Consultant.Phase.AWAY)


func test_there_is_no_hidden_pause_after_a_hand_change() -> void:
	var consultant := _desk()
	_press(consultant, 6)
	SaveManager.save.demand_mood = 1.2
	# Well inside the old 15 s pause: one tap interval and the reach.
	_run(consultant, 7.0)
	assert_int(SaveManager.save.sale_price).is_equal(7)


func test_with_express_engagement_the_consultants_hand_crosses_the_desk_twice_as_fast() -> void:
	var save := SaveGame.new()
	assert_float(Consultant.reach_speed(save)).is_equal(Consultant.REACH_SPEED)
	save.tree_bought.append(Consultant.EXPRESS)
	assert_float(Consultant.reach_speed(save)).is_equal(Consultant.REACH_SPEED * 2.0)


func test_switched_off_mid_reach_the_consultant_withdraws_and_stays_away() -> void:
	var consultant := _desk()
	_run(consultant, 3.0)

	SaveManager.save.consultant_on = false
	_run(consultant, 10.0)

	assert_int(SaveManager.save.sale_price).is_equal(2)
	assert_int(consultant._phase).is_equal(Consultant.Phase.AWAY)


func test_clicking_the_slate_switch_opens_the_mandate_and_a_click_beside_it_closes_it() -> void:
	var consultant := _desk()
	assert_bool(consultant._sheet.visible).is_false()

	consultant._switch.flicked.emit()
	assert_bool(consultant._sheet.visible).is_true()
	assert_bool(SaveManager.save.consultant_on).is_true()

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	consultant._sheet.get_node("Shade").gui_input.emit(click)
	assert_bool(consultant._sheet.visible).is_false()


func test_the_mandates_duty_switch_sends_the_consultant_away_and_the_desk_lamp_follows() -> void:
	var consultant := _desk()
	consultant._sheet.open()
	var duty: Button = consultant._sheet.get_node("%Duty")

	duty.button_pressed = false
	assert_bool(SaveManager.save.consultant_on).is_false()
	consultant._process(STEP)
	assert_bool(consultant._shown_on).is_false()

	duty.button_pressed = true
	assert_bool(SaveManager.save.consultant_on).is_true()


func test_the_switch_is_on_the_slate_only_once_the_card_is_stamped() -> void:
	var consultant := _desk()
	SaveManager.save.stamped.clear()
	consultant._process(STEP)
	assert_bool(consultant._switch.visible).is_false()

	SaveManager.save.stamped.append(Consultant.CARD)
	consultant._process(STEP)
	assert_bool(consultant._switch.visible).is_true()


func test_an_old_save_with_the_retired_skill_and_markup_still_loads() -> void:
	var path := OS.get_user_data_dir().path_join("consultant_old_save_test.tres")
	FileAccess.open(path, FileAccess.WRITE).store_string('[gd_resource type="Resource" script_class="SaveGame" format=3]\n\n'
			+ '[ext_resource type="Script" path="res://ressources/save/save_game.gd" id="1"]\n\n'
			+ '[resource]\nscript = ExtResource("1")\nsale_price = 7\nconsultant_skill = 2\nconsultant_markup = 0.2\n')
	var old := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	DirAccess.remove_absolute(path)

	assert_object(old).is_not_null()
	assert_int(old.sale_price).is_equal(7)
	assert_float(old.consultant_bounce).is_equal(10.0)


func test_the_consultant_taps_the_biggest_step_bought_that_does_not_overshoot() -> void:
	var save := SaveGame.new()
	save.sale_price = 10
	assert_int(Consultant.tap(save, 40)).is_equal(1)
	save.tree_bought = PackedStringArray(["consultant_step_2", "consultant_step_5", "consultant_step_10"])
	assert_int(Consultant.tap(save, 40)).is_equal(10)
	assert_int(Consultant.tap(save, 17)).is_equal(5)
	assert_int(Consultant.tap(save, 13)).is_equal(2)
	assert_int(Consultant.tap(save, 11)).is_equal(1)
	assert_int(Consultant.tap(save, 1)).is_equal(-5)
	save.tree_bought = PackedStringArray(["consultant_step_2"])
	assert_int(Consultant.tap(save, 40)).is_equal(2)
	save.tree_bought.append(Consultant.SMART)
	assert_int(Consultant.tap(save, 40)).is_equal(30)
