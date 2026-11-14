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


func test_the_next_pack_costs_the_ticker_price_and_five_times_that_when_overstocked() -> void:
	var save := SaveGame.new()
	save.price_factor = 1.5
	assert_int(Console.pack_cost(save)).is_equal(Console.pack_price(1.5, save.pack_size))
	save.stock = Console.OVERSTOCK
	assert_int(Console.pack_cost(save)).is_equal(Console.pack_price(1.5, save.pack_size) * Console.OVERSTOCK_MUL)


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


## A desk with the console in, `stock` cabbages and `coins` (a pack costs more than that).
func _broke_console(stock: int, coins: int, stamped := PackedStringArray()) -> SupplyConsole:
	var save := SaveGame.new()
	save.buy_unlocked = true
	save.stock = stock
	save.coins = coins
	save.stamped = stamped
	SaveManager.save = save
	var console: SupplyConsole = auto_free(load("res://entities/supply_console/supply_console.tscn").instantiate())
	add_child(console)
	return console


func test_a_player_with_nothing_to_sell_and_no_money_for_a_pack_is_helped_within_two_seconds() -> void:
	var console := _broke_console(0, 3)
	assert_int(console._cost()).is_greater(3)
	for i in 4:
		console._process(0.5)
	assert_int(console._cost()).is_equal(3)


func test_the_rescue_waits_a_short_beat_so_it_reads_as_an_answer_not_a_glitch() -> void:
	assert_float(Console.BAILOUT_WAIT).is_between(1.0, 1.5)
	var console := _broke_console(0, 3)
	console._process(0.5)
	assert_int(console._cost()).is_greater(3)


func test_once_mini_cabbages_exist_the_rescue_is_retired() -> void:
	var save := SaveGame.new()
	save.stamped.append("mini_cabbages")
	assert_bool(Console.bails_out(save)).is_false()
	var console := _broke_console(0, 3, PackedStringArray(["mini_cabbages"]))
	for i in 10:
		console._process(0.5)
	assert_int(console._cost()).is_greater(3)


func test_the_rescue_cannot_be_triggered_while_a_cabbage_is_still_on_the_mat_or_in_the_air() -> void:
	# Stock counts every cabbage on the mat, in flight and refused out in the street until it sells.
	var console := _broke_console(1, 0)
	var full := console._cost()
	for i in 10:
		console._process(0.5)
	assert_int(console._cost()).is_equal(full)


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


func test_the_auto_switch_lies_on_the_sloped_face_and_its_hit_box_covers_lamp_and_switch() -> void:
	SaveManager.save = SaveGame.new()
	var console: SupplyConsole = auto_free(load("res://entities/supply_console/supply_console.tscn").instantiate())
	add_child(console)
	var normal: Vector3 = console.get_node("Price").transform.basis.z
	var auto: Label3D = console.get_node("Auto")
	assert_vector(auto.transform.basis.z).is_equal_approx(normal, Vector3.ONE * 0.001)
	# The switch faces out of the same face, turned sideways (its toggle swings across, not uphill).
	var toggle: Node3D = console.get_node("Auto/Toggle")
	var toggle_at := toggle.global_transform
	assert_vector(toggle_at.basis.z.normalized()).is_equal_approx(normal, Vector3.ONE * 0.001)
	assert_float(absf(toggle_at.basis.y.normalized().x)).is_equal_approx(1.0, 0.001)
	var hit: Node3D = console.get_node("AutoSwitch")
	var box: Vector3 = (hit.get_node("Shape") as CollisionShape3D).shape.size
	for spot: Vector3 in [auto.global_position, toggle_at.origin]:
		var local := hit.global_transform.affine_inverse() * spot
		assert_bool(absf(local.x) <= box.x / 2.0 and absf(local.y) <= box.y / 2.0 and absf(local.z) <= box.z / 2.0).is_true()


## What the hand's ray (Hand._pick: everything but the play area) finds at `spot` on the console's
## sloped face, coming down onto it from the camera's side.
func _pick_at(console: SupplyConsole, spot: Vector3) -> Interactable:
	var normal: Vector3 = console.get_node("Price").global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(spot + normal * 0.5, spot - normal * 0.5, ~Hand.PLAY_AREA_LAYER)
	return Interactable.of(console.get_world_3d().direct_space_state.intersect_ray(query).get("collider"))


func test_hovering_the_auto_buy_switch_shows_its_tooltip_and_a_click_toggles_it() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["auto_procurement"])
	save.buy_unlocked = true  # The console on the desk, not up waiting to drop in.
	SaveManager.save = save
	var console: SupplyConsole = auto_free(load("res://entities/supply_console/supply_console.tscn").instantiate())
	add_child(console)
	await await_idle_frame()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var auto: Label3D = console.get_node("Auto")
	var toggle: Node3D = console.get_node("Auto/Toggle")
	# The lamp label, the switch, and the pilot lamp over its toggle.
	for spot: Vector3 in [auto.global_position, toggle.global_position, toggle.get_node("Lamp").global_position]:
		var picked := _pick_at(console, spot)
		assert_object(picked).override_failure_message("nothing under %s" % spot).is_not_null()
		assert_str(picked.tooltip).override_failure_message("%s shows: %s" % [spot, picked.tooltip]).contains("Auto-buy switch")
		assert_str(picked.tooltip).contains("Left").contains("Right")
		var was := save.auto_buy
		picked.grabbed.emit()
		assert_bool(save.auto_buy).is_equal(not was)

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


## A stocked, rich desk with the console in and the standing order on.
func _rich_console(stamped: Array) -> SupplyConsole:
	var save := SaveGame.new()
	save.buy_unlocked = true
	save.stock = 0
	save.coins = 100000
	save.stamped = PackedStringArray(["auto_procurement"] + stamped)
	SaveManager.save = save
	var console: SupplyConsole = auto_free(load("res://entities/supply_console/supply_console.tscn").instantiate())
	add_child(console)
	return console


func test_once_market_intelligence_is_stamped_the_supply_console_buys_nothing_by_hand_or_by_standing_order() -> void:
	var console := _rich_console([])
	var save := SaveManager.save
	console._process(0.1)  # The standing order: out of stock, money there.
	assert_int(save.packs_auto).is_equal(1)
	console._press()
	assert_int(save.packs_manual).is_equal(1)
	var was := [save.coins, save.stock, save.price_factor]

	save.stamped.append("market_intelligence")
	save.stock = 0
	was[1] = 0
	assert_bool(Console.retired(save)).is_true()
	for i in 200:  # Past the auto cooldown and a price tick.
		console._process(0.5)
	console._press()

	assert_array([save.coins, save.stock, save.price_factor]).is_equal(was)
	assert_array([save.packs_auto, save.packs_manual]).is_equal([1, 1])


func test_the_retired_console_is_lifted_off_the_desk_and_its_button_and_switch_take_no_more_clicks() -> void:
	var console := _rich_console([])
	var rest := console.position
	assert_bool(console.visible).is_true()
	SaveManager.save.stamped.append("market_intelligence")
	console._process(0.0)
	assert_bool(console._button.enabled).is_false()
	assert_bool(console._auto_switch.enabled).is_false()
	await await_millis(int(Console.LIFT_TIME * 1000.0) + 150)
	assert_bool(console.visible).is_false()
	assert_float(console.position.y).is_greater(rest.y + 5.0)


func test_a_loaded_save_with_market_intelligence_never_shows_the_supply_console() -> void:
	var console := _rich_console(["market_intelligence"])
	assert_bool(console.visible).is_false()
	assert_bool(console._button.enabled).is_false()
	assert_bool(console._auto_switch.enabled).is_false()
	console._process(0.5)
	assert_bool(console.visible).is_false()
	assert_int(SaveManager.save.packs_auto).is_equal(0)


func test_the_retired_console_scrapes_off_its_plinth_as_it_is_lifted() -> void:
	var console := _rich_console([])
	var lift := console.get_node("Lift") as SoundCue
	assert_object(lift.stream).is_not_null()
	assert_bool(lift.playing).is_false()
	SaveManager.save.stamped.append("market_intelligence")
	console._process(0.0)
	assert_bool(lift.playing).is_true()
