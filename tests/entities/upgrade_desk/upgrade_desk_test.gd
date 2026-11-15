extends GdUnitTestSuite

const DESK_SCENE := preload("res://entities/upgrade_desk/upgrade_desk.tscn")
const WorldRegister := preload("res://entities/map_table/world_register.gd")

const BEFORE_RADIO := ["price_slate", "desk_space", "junior_associate", "acceptance_meter"]
const THROUGH_QA := ["price_slate", "radio", "desk_space", "acceptance_meter", "junior_associate", "quality_assurance"]
const THROUGH_MINI_TUBE := ["price_slate", "radio", "desk_space", "acceptance_meter", "junior_associate", "quality_assurance",
		"mini_cabbages", "street_posters", "projector", "research_inspection", "pricing_consultant", "catch_combo",
		"research_cabbage", "mini_tube"]


var _real_save: SaveGame
var _demo_was: bool


func before_test() -> void:
	_real_save = SaveManager.save
	_demo_was = ProjectSettings.get_setting("game/demo", false)
	ProjectSettings.set_setting("game/demo", false)


func after_test() -> void:
	SaveManager.save = _real_save
	ProjectSettings.set_setting("game/demo", _demo_was)


func _next(stamped: Array, count := UpgradeDesk.OFFERED, save: SaveGame = null) -> Array[String]:
	return UpgradeDesk.next_cards(PackedStringArray(stamped), count, save)


func _warned() -> SaveGame:
	var save := SaveGame.new()
	save.supply_warning = true
	return save


func _all_ids() -> Array:
	return UpgradeDesk.CARDS.map(func(card: Dictionary) -> String: return card.id)


func test_only_the_price_slate_is_offered_on_a_fresh_desk() -> void:
	assert_array(_next([])).is_equal(["price_slate"])


func test_the_price_slate_is_affordable_the_moment_the_tray_drops() -> void:
	assert_int(UpgradeDesk.card_data("price_slate").price).is_less_equal(UpgradeDesk.TRAY_COINS)


func test_the_price_slate_opens_the_radio_alone() -> void:
	assert_array(_next(["price_slate"])).is_equal(["radio"])


func test_the_radio_opens_desk_space_the_junior_associate_and_the_meter() -> void:
	assert_array(_next(["price_slate", "radio"])).is_equal(["desk_space", "junior_associate", "acceptance_meter"])


func test_a_stamped_card_leaves_the_offer_and_quality_assurance_waits_for_the_junior() -> void:
	assert_array(_next(["price_slate", "radio", "desk_space"])).is_equal(["junior_associate", "acceptance_meter"])


func test_the_junior_opens_quality_assurance_and_the_minis_and_no_hire_card_follows() -> void:
	assert_array(_next(["price_slate", "radio", "desk_space", "acceptance_meter", "junior_associate"])) \
			.is_equal(["quality_assurance", "mini_cabbages"])


func test_quality_assurance_opens_the_posters_and_the_projector() -> void:
	assert_array(_next(THROUGH_QA)).is_equal(["mini_cabbages", "street_posters", "projector"])


func test_the_projector_opens_the_inspection_research() -> void:
	assert_array(_next(THROUGH_QA + ["projector", "street_posters"])).contains(["research_inspection"])


func test_inspection_consultant_and_combo_open_the_review_the_spoilage_memo_and_the_lab_assistant() -> void:
	assert_array(_next(THROUGH_MINI_TUBE)).is_equal(["performance_review", "spoilage_memo", "research_assistant"])


func test_the_waste_bin_is_never_a_card_to_buy() -> void:
	assert_array(_all_ids()).not_contains(["rotten_bin"])
	assert_dict(UpgradeDesk.card_data("rotten_bin")).is_empty()


func test_the_desk_never_offers_more_cards_than_asked_for() -> void:
	assert_array(_next(["price_slate", "radio"], 1)).is_equal(["desk_space"])
	assert_array(_next(["price_slate", "radio"], 0)).is_empty()


func test_the_family_farm_is_never_dealt_before_the_boss_warns_of_the_supply_shock() -> void:
	var everything_else := _all_ids().filter(func(id: String) -> bool: return id != "family_farm")

	assert_array(_next(everything_else, UpgradeDesk.OFFERED, SaveGame.new())).is_empty()
	assert_array(_next(everything_else)).is_empty()


func test_once_the_boss_warns_the_farm_card_is_dealt_before_the_rest() -> void:
	assert_array(_next([], UpgradeDesk.OFFERED, _warned())).is_equal(["family_farm", "price_slate"])
	assert_array(_next(THROUGH_QA, UpgradeDesk.OFFERED, _warned())).is_equal(["family_farm", "mini_cabbages", "street_posters"])


func test_stamping_whatever_is_dealt_first_eventually_deals_every_card() -> void:
	var due := _warned()  # Every timed card due: the warning given, the storage it waits for bought, every farm owned.
	due.tree_bought = PackedStringArray(["storage_1"])
	for i in UpgradeDesk.Events.FARMS:
		due.farms_owned.append("F-%d" % i)
	for start: Array in [[], BEFORE_RADIO]:
		var stamped := PackedStringArray(start)
		due.stamped = stamped  # Card-started events (the promotion) see what is stamped.
		while not UpgradeDesk.next_cards(stamped, UpgradeDesk.OFFERED, due).is_empty():
			stamped.append(UpgradeDesk.next_cards(stamped, UpgradeDesk.OFFERED, due)[0])
			due.stamped = stamped

		assert_int(stamped.size()).override_failure_message("softlocked from %s" % [start]).is_equal(UpgradeDesk.CARDS.size())


func test_an_old_save_that_stamped_cards_before_the_radio_existed_is_dealt_the_radio_first() -> void:
	assert_str(_next(BEFORE_RADIO)[0]).is_equal("radio")


func test_every_card_only_needs_cards_earlier_in_the_queue() -> void:
	for i in UpgradeDesk.CARDS.size():
		var earlier := _all_ids().slice(0, i)
		for need: String in UpgradeDesk.CARDS[i].get("needs", []):
			assert_array(earlier).override_failure_message("%s needs %s, which is not before it" % [UpgradeDesk.CARDS[i].id, need]) \
					.contains([need])


func test_every_card_has_its_own_id_a_title_a_body_and_a_positive_price() -> void:
	var ids := _all_ids()
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_int(ids.count(card.id)).override_failure_message("%s is not unique" % card.id).is_equal(1)
		assert_str(card.title).is_not_empty()
		assert_str(card.body).is_not_empty()
		assert_int(card.price).is_greater(0)


func test_cards_are_paid_in_coins_unless_marked_findings() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_array(["coins", "findings", "stock"]).contains([card.get("currency", "coins")])
	assert_str(UpgradeDesk.card_data("junior_associate").get("currency", "coins")).is_equal("coins")
	assert_str(UpgradeDesk.card_data("window_targets").get("currency")).is_equal("findings")
	assert_int(UpgradeDesk.card_data("projector").price).is_equal(75)


func test_stage_two_cards_are_paid_in_findings_the_farm_in_coins_and_the_farms_big_steps_in_units() -> void:
	for id: String in ["chute_control", "farm_terminal", "farm_readout", "mini_thinning", "micro_samples", "mini_station"]:
		assert_str(UpgradeDesk.card_data(id).get("currency", "coins")).override_failure_message(id).is_equal("findings")
	assert_str(UpgradeDesk.card_data("family_farm").get("currency", "coins")).is_equal("coins")
	for id: String in ["offsite_storage", "green_thumb", "seasonal_workforce", "golden_cabbage", "mechanisation"]:
		assert_str(UpgradeDesk.card_data(id).get("currency", "coins")).override_failure_message(id).is_equal("stock")


func test_the_farm_terminal_is_the_cheapest_findings_card_of_stage_two_after_the_chute_lever_so_it_comes_next() -> void:
	var terminal: int = UpgradeDesk.card_data("farm_terminal").price
	assert_int(UpgradeDesk.card_data("chute_control").price).is_less(terminal)
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.get("currency") == "findings" and card.get("needs", []).has("family_farm") and card.id != "chute_control":
			assert_int(card.price).override_failure_message(card.id).is_greater_equal(terminal)


func test_the_first_farm_hand_costs_more_cabbages_than_the_off_site_locker_holds_and_fits_the_corridor_overflow() -> void:
	var price: int = UpgradeDesk.card_data("seasonal_workforce").price
	assert_int(price).is_greater(Projector.cap_at("stock_100"))
	assert_int(price).is_less_equal(Projector.cap_at("stock_125") - 12)  # A full mat's units on top can't pay.
	assert_int(price).is_less(UpgradeDesk.card_data("golden_cabbage").price)  # Before the golden card, which waits for it.


func test_research_directives_are_paid_in_findings_and_titled_research() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.get("research", false):
			assert_str(card.get("currency", "coins")).is_equal("findings")
			assert_str(card.title).starts_with("RESEARCH: ")


func test_the_ledger_is_a_findings_card_but_not_research() -> void:
	var ledger := UpgradeDesk.card_data("stats_ledger")

	assert_str(ledger.get("currency", "coins")).is_equal("findings")
	assert_bool(ledger.get("research", false)).is_false()


func test_retired_and_unknown_cards_have_no_entry() -> void:
	for id in ["regional_billboard", "bulk_procurement", "hire_associate", "no_such_card"]:
		assert_dict(UpgradeDesk.card_data(id)).is_empty()


func test_the_price_slate_card_unlocks_the_slate() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("price_slate", save)
	assert_bool(save.slate_unlocked).is_true()


func test_desk_space_lets_the_chute_keep_one_more_unit_on_the_mat() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("desk_space", save)
	assert_int(save.desk_capacity).is_equal(2)


func test_the_junior_associate_hires_one_hand_but_never_takes_hands_away() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("junior_associate", save)
	assert_int(save.hands).is_equal(1)

	save.hands = 3
	UpgradeDesk.apply("junior_associate", save)
	assert_int(save.hands).is_equal(3)


func test_the_meter_and_the_posters_raise_marketing_and_stack_multiplicatively() -> void:
	var save := SaveGame.new()
	save.marketing = 1.25
	UpgradeDesk.apply("acceptance_meter", save)
	UpgradeDesk.apply("street_posters", save)
	assert_float(save.marketing).is_equal_approx(1.25 * 1.2 * 1.5, 0.0001)


func test_the_time_and_motion_study_halves_the_hands_interval() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("performance_review", save)
	assert_float(save.associate_interval).is_equal_approx(4.0, 0.0001)


func test_the_coin_recovery_card_docks_one_robot_and_the_lab_card_hires_one_lab_hand() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("coin_collector", save)
	UpgradeDesk.apply("research_assistant", save)
	assert_int(save.vacuums).is_equal(1)
	assert_int(save.research_hands).is_equal(1)

	save.vacuums = 2
	UpgradeDesk.apply("coin_collector", save)
	assert_int(save.vacuums).is_equal(2)


func test_buying_the_family_farm_after_the_shock_starts_the_wholesalers_squeeze_for_good() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	save.stamped.append("family_farm")
	UpgradeDesk.apply("family_farm", save)
	assert_bool(SupplyConsole.squeezing(save)).is_true()


func test_stamping_every_card_once_adds_up_to_the_listed_effects_and_nothing_else() -> void:
	var save := SaveGame.new()
	var interval := save.associate_interval
	for card: Dictionary in UpgradeDesk.CARDS:
		UpgradeDesk.apply(card.id, save)

	assert_bool(save.slate_unlocked).is_true()
	assert_int(save.desk_capacity).is_equal(3)  # desk_space and the mat allowance: one each
	assert_int(save.pack_size).is_equal(SaveGame.new().pack_size)
	assert_int(save.hands).is_equal(1)
	assert_float(save.marketing).is_equal_approx(1.2 * 1.5 * UpgradeDesk.TAX_FREE, 0.0001)  # The meter, the posters, no taxes.
	assert_float(save.associate_interval).is_equal_approx(interval * 0.5, 0.0001)
	assert_int(save.research_hands).is_equal(1)
	assert_int(save.farm_hands).is_equal(1)
	assert_int(save.farm_tractors).is_equal(1)
	assert_float(save.own_sale).is_equal_approx(1.2, 0.0001)
	assert_float(save.own_lab).is_equal_approx(1.2, 0.0001)
	assert_int(save.coins).is_equal(0)
	assert_int(save.findings).is_equal(0)


func test_migrating_an_old_save_restores_the_hand_the_meter_bonus_the_pack_and_caps_the_price() -> void:
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["price_slate", "junior_associate", "acceptance_meter", "bulk_procurement"])
	old.sale_price = 999
	UpgradeDesk.migrate(old)

	assert_int(old.hands).is_equal(1)
	assert_float(old.marketing).is_equal_approx(1.2, 0.0001)
	assert_array(Array(old.tree_bought)).contains(["pack_1"])
	assert_int(old.sale_price).is_equal(PriceSlate.max_price(1.2))
	assert_int(old.migration).is_equal(SaveGame.MIGRATION)


func test_migration_runs_only_once() -> void:
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["acceptance_meter", "bulk_procurement"])
	UpgradeDesk.migrate(old)
	UpgradeDesk.migrate(old)

	assert_float(old.marketing).is_equal_approx(1.2, 0.0001)
	assert_int(old.tree_bought.size()).is_equal(1)


func test_a_meter_stamp_the_log_shows_already_paid_out_gets_no_second_bonus() -> void:
	var logged := SaveGame.new()
	logged.stamped = PackedStringArray(["acceptance_meter"])
	logged.playtest_log.append(logged.log_entry(10, "session"))
	logged.marketing = 1.2
	logged.playtest_log.append(logged.log_entry(20, "card", "acceptance_meter", 40, "coins"))
	UpgradeDesk.migrate(logged)

	assert_float(logged.marketing).is_equal_approx(1.2, 0.0001)


func test_a_logged_meter_stamp_that_left_marketing_flat_still_counts_as_unpaid() -> void:
	var save := SaveGame.new()
	save.playtest_log.append(save.log_entry(10, "session"))
	save.playtest_log.append(save.log_entry(20, "card", "acceptance_meter", 40, "coins"))

	assert_bool(UpgradeDesk.meter_logged(save.playtest_log)).is_false()


func test_migration_leaves_a_price_under_the_cap_alone() -> void:
	var save := SaveGame.new()
	save.sale_price = 5
	UpgradeDesk.migrate(save)
	assert_int(save.sale_price).is_equal(5)


func test_the_spike_shows_a_few_some_or_many_sheets_under_the_top_paper() -> void:
	assert_array([1, 2, 4, 5, 11, 12, 40].map(UpgradeDesk.sheets_under)).is_equal([0, 2, 2, 5, 5, 10, 10])


func test_the_spike_stack_mesh_is_built_once_per_sheet_count_and_none_for_zero() -> void:
	assert_object(UpgradeDesk.stack_mesh(0)).is_null()
	assert_object(UpgradeDesk.stack_mesh(5)).is_same(UpgradeDesk.stack_mesh(5))


func test_the_approved_list_on_the_spike_shows_the_newest_card_first_and_skips_retired_ones() -> void:
	var save := SaveGame.new()
	save.stamped.append("price_slate")
	save.stamped.append("retired_card")
	save.stamped.append("radio")
	assert_array(UpgradeDesk.approved_newest_first(save)).is_equal(["radio", "price_slate"])


func test_the_supply_shock_switches_the_standing_order_off_and_the_player_may_switch_it_back_on() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["auto_procurement"])
	UpgradeDesk.start_warning(save)
	assert_bool(save.auto_buy).is_true()
	UpgradeDesk.start_shock(save)
	assert_bool(save.auto_buy).is_false()
	save.auto_buy = true
	UpgradeDesk.migrate(save)
	assert_bool(save.auto_buy).is_true()


func test_a_shock_before_the_standing_order_is_stamped_leaves_it_on_for_when_it_is() -> void:
	var save := SaveGame.new()
	UpgradeDesk.start_warning(save)
	UpgradeDesk.start_shock(save)
	assert_bool(save.auto_buy).is_true()


func test_the_mat_allowance_card_waits_for_desk_space() -> void:
	assert_array(UpgradeDesk.card_data("mat_allowance").needs).contains(["desk_space", "coin_collector"])


func test_in_the_demo_a_full_tray_makes_room_for_the_farm_card_in_its_last_slot() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.sold = UpgradeDesk.Events.Demo.WARNING_SOLD
	save.stamped = PackedStringArray(["price_slate", "radio"])
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	var first := _ids(desk._offered)

	desk._process(0.0)

	assert_bool(save.supply_warning).is_true()
	assert_array(_ids(desk._offered)).is_equal([first[0], first[1], "family_farm"])


func test_the_tray_never_shows_more_cards_than_offered_however_many_are_open() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp", "mat_allowance", "stats_ledger", "spoilage_memo", "lab_priority"])
	save.tray_unlocked = true
	assert_int(_next(save.stamped, UpgradeDesk.CARDS.size(), save).size()).is_greater(UpgradeDesk.OFFERED)
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	assert_int(desk._offered.size()).is_equal(UpgradeDesk.OFFERED)

	desk._deal(false)

	assert_int(desk._offered.size()).is_equal(UpgradeDesk.OFFERED)


func test_a_stamped_cards_slot_goes_to_the_farm_card_once_the_warning_is_ready() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp", "mat_allowance", "stats_ledger"])
	save.tray_unlocked = true
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	desk._shock_in = INF  # Only the stamp may start the warning here.
	var stamped := desk._offered[0]
	var kept := _ids(desk._offered).slice(1)
	assert_bool(UpgradeDesk.Events.warning_ready(save)).is_true()
	# What the press does on a stamp (_bottom_out), then the card has been shown long enough.
	save.stamped.append(stamped.id)
	desk._offered.erase(stamped)
	desk._leaving = stamped
	desk._shown = UpgradeDesk.SHOW_TIME

	desk._process(0.0)

	assert_bool(save.supply_warning).is_true()
	assert_array(_ids(desk._offered)).is_equal(kept + ["family_farm"])


func test_every_sales_event_has_a_desk_card() -> void:
	for id: String in ["golden_lamp", "catch_combo", "window_targets"]:
		assert_dict(UpgradeDesk.card_data(id)).override_failure_message("card " + id).is_not_empty()


func _ids(cards: Array[UpgradeCard]) -> Array:
	return cards.map(func(card: UpgradeCard) -> String: return card.id)


func _all_stamped_but(ids: Array) -> SaveGame:
	var save := SaveGame.new()
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in ids:
			save.stamped.append(card.id)
	return save


func test_a_double_click_right_after_dropping_a_card_stamps_it_free_only_in_a_debug_build() -> void:
	assert_bool(UpgradeDesk.debug_free(true, 0.3)).is_true()
	assert_bool(UpgradeDesk.debug_free(true, UpgradeDesk.DEBUG_DOUBLE + 0.5)).is_false()
	assert_bool(UpgradeDesk.debug_free(false, 0.3)).is_false()


func test_a_save_that_bought_grace_period_as_a_timer_gets_its_new_half_kept_on_a_miss() -> void:
	var save := SaveGame.new()
	save.tree_bought.append("combo_window")
	UpgradeDesk.migrate(save)
	assert_float(save.miss_keep).is_equal(0.5)


func _farmed(first_harvest: float, seconds: float) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm"])
	save.farm_first_harvest = first_harvest
	save.farm_seconds = seconds
	return save


func test_the_chute_lever_then_the_farm_terminal_are_dealt_right_after_the_farm_is_bought() -> void:
	assert_array(_next([], UpgradeDesk.CARDS.size())).not_contains(["farm_terminal"])
	# Every card up to the farm stamped, no harvest yet: the lever, then the terminal, are next in the row.
	var save := _farmed(-1.0, 0.0)
	for card: Dictionary in UpgradeDesk.CARDS:
		save.stamped.append(card.id)
		if card.id == "family_farm":
			break
	assert_array(_next(save.stamped, 2, save)).is_equal(["chute_control", "farm_terminal"])


func test_the_workforce_waits_for_off_site_storage_and_green_thumb_and_the_golden_card_wait_for_the_workforce() -> void:
	assert_array(_next(["family_farm"], UpgradeDesk.CARDS.size())).not_contains(["seasonal_workforce", "green_thumb"])
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm", "farm_terminal", "chute_control"])
	save.tree_bought = PackedStringArray(["storage_1"])
	# The lever alone is not enough: without off-site storage the store never holds the hand's 110.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["seasonal_workforce", "green_thumb"])
	save.stamped.append("offsite_storage")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["seasonal_workforce"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["green_thumb", "golden_cabbage"])
	save.stamped.append("seasonal_workforce")  # GREEN THUMB and the golden card come after the first farm hand.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["green_thumb", "golden_cabbage"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["mechanisation"])
	save.overripe = true  # The rot alone deals nothing.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["mechanisation"])
	save.overripe = false
	save.stamped.append("golden_cabbage")  # Dealt right after the golden card, before the rot starts.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["mechanisation"])


func test_no_upgrade_card_waits_on_a_timer() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_bool(card.has("after_harvest")).override_failure_message("%s waits on farm time" % card.id).is_false()
		if card.has("event"):
			assert_array(UpgradeDesk.UNTIMED_EVENTS).override_failure_message("%s waits on the event %s" % [card.id, card.event]) 					.contains([card.event])
	assert_array(UpgradeDesk.UNTIMED_EVENTS).is_equal(["supply_warning", "promotion", "invest_in_growth", "no_more_sellers", "bigger_armies_memo"])
	# The promotions start on a stamp alone, never on a flag a clock could set.
	assert_bool(UpgradeDesk.Events.EVENTS.promotion.has("flag")).is_false()
	assert_bool(UpgradeDesk.Events.EVENTS.invest_in_growth.has("flag")).is_false()


func test_the_farm_telemetry_card_is_dealt_once_the_farm_is_bought_before_any_harvest() -> void:
	var save := _farmed(-1.0, 0.0)
	save.stamped.append("farm_terminal")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["farm_readout"])


func test_the_standing_seed_order_comes_after_mechanisation_and_is_paid_in_units_the_annex_holds() -> void:
	var save := _all_stamped_but(["standing_seed_order", "mechanisation"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["standing_seed_order"])
	save.stamped.append("mechanisation")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["standing_seed_order"])
	var card := UpgradeDesk.card_data("standing_seed_order")
	assert_str(card.currency).is_equal("stock")
	assert_int(card.price).is_less(Projector.cap_at("storage_2"))  # Below the cap: a full store still has the mat's units on top.


func test_green_thumb_is_paid_in_units_that_fit_the_stock_room() -> void:
	var card := UpgradeDesk.card_data("green_thumb")
	assert_int(card.price).is_greater(0)
	assert_int(card.price).is_less_equal(Projector.cap_at("storage_1"))


func test_the_golden_card_waits_for_the_workforce_not_a_projector_node_and_costs_more_than_the_stock_room_holds() -> void:
	var save := _all_stamped_but(["golden_cabbage", "seasonal_workforce"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["golden_cabbage"])
	save.stamped.append("seasonal_workforce")  # No storage node bought: the card alone deals it.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["golden_cabbage"])
	# The workforce's 110 took CORRIDOR OVERFLOW: by then the store holds the golden card's units.
	assert_int(UpgradeDesk.card_data("golden_cabbage").price).is_less_equal(Projector.cap_at("stock_125"))
	assert_int(UpgradeDesk.card_data("seasonal_workforce").price).is_greater(Projector.cap_at("stock_100"))
	var stock_room := Projector.cap_at("storage_1")
	var annex := Projector.cap_at("storage_2")
	for id: String in ["golden_cabbage", "mechanisation"]:
		assert_int(UpgradeDesk.card_data(id).price).override_failure_message(id).is_greater(stock_room)
		assert_int(UpgradeDesk.card_data(id).price).override_failure_message(id).is_less_equal(annex)


func test_the_overripe_event_starts_a_minute_of_farm_time_after_the_golden_card() -> void:
	var save := SaveGame.new()
	save.farm_seconds = 500.0
	assert_bool(UpgradeDesk.Events.overripe_due(save)).is_false()
	UpgradeDesk.apply("golden_cabbage", save)
	assert_float(save.golden_at).is_equal(500.0)
	save.farm_seconds = 559.0
	assert_bool(UpgradeDesk.Events.overripe_due(save)).is_false()
	save.farm_seconds = 560.0
	assert_bool(UpgradeDesk.Events.overripe_due(save)).is_true()
	save.overripe = true
	assert_bool(UpgradeDesk.Events.overripe_due(save)).is_false()
	assert_bool(UpgradeDesk.Events.due("overripe", save)).is_true()


func test_a_save_with_the_golden_card_but_no_clock_gets_the_overripe_event_a_minute_after_loading() -> void:
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["golden_cabbage"])
	old.farm_seconds = 900.0
	UpgradeDesk.migrate(old)
	assert_float(old.golden_at).is_equal(900.0)


func test_an_old_save_that_stamped_mechanisation_before_the_rot_keeps_it_and_its_tractor() -> void:
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["family_farm", "farm_terminal", "mechanisation"])
	old.farm_tractors = 1
	UpgradeDesk.migrate(old)
	assert_bool(old.stamped.has("mechanisation")).is_true()
	assert_int(old.farm_tractors).is_equal(1)
	assert_array(_next(old.stamped, UpgradeDesk.CARDS.size(), old)).not_contains(["mechanisation"])


func test_paying_a_card_in_units_spends_plain_units_before_golden_ones() -> void:
	var save := SaveGame.new()
	save.stock = 150
	save.golden_stock = 12
	UpgradeDesk.pay(save, "stock", 120)
	assert_int(save.stock).is_equal(30)
	assert_int(save.golden_stock).is_equal(12)
	UpgradeDesk.pay(save, "stock", 25)
	assert_int(save.golden_stock).is_equal(5)


func test_units_on_the_mat_cannot_pay_a_card_only_the_ones_still_in_the_store() -> void:
	var save := SaveGame.new()
	save.stock = 62
	assert_int(UpgradeDesk.spendable(save, "stock", Vector2i(3, 0))).is_equal(59)
	assert_int(UpgradeDesk.spendable(save, "coins", Vector2i(3, 0))).is_equal(int(save.coins))


func test_paying_in_units_leaves_the_mat_its_units_and_their_gold() -> void:
	var save := SaveGame.new()
	save.stock = 10  # 3 on the mat (1 golden), 7 in the store (2 golden).
	save.golden_stock = 3
	UpgradeDesk.pay(save, "stock", 7, Vector2i(3, 1))
	assert_int(save.stock).is_equal(3)
	assert_int(save.golden_stock).is_equal(1)


func test_only_stock_units_still_in_stock_count_as_out_of_the_chute() -> void:
	var save := SaveGame.new()
	var plain: Cabbage = auto_free(Cabbage.new())
	var gold: Cabbage = auto_free(Cabbage.new())
	gold.golden = true
	var tiny: Cabbage = auto_free(Cabbage.new())
	tiny.mini = true
	var sold: Cabbage = auto_free(Cabbage.new())
	sold.leave_stock(save)
	assert_that(UpgradeDesk.units_out([plain, gold, tiny, sold])).is_equal(Vector2i(2, 1))


func test_no_card_is_dealt_before_the_dropping_tray_has_landed() -> void:
	var save := SaveGame.new()
	save.coins = UpgradeDesk.TRAY_COINS
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)

	desk._process(0.0)

	assert_bool(save.tray_unlocked).is_true()
	assert_array(_ids(desk._offered)).is_empty()


func test_a_card_dealt_by_a_projector_node_comes_into_a_free_slot_as_soon_as_the_node_is_bought() -> void:
	var save := _all_stamped_but(["offsite_storage", "seasonal_workforce", "green_thumb", "golden_cabbage", "mechanisation",
			"standing_seed_order", "own_sales", "own_research", "consolidation"])
	save.tray_unlocked = true
	save.supply_warning = true
	save.supply_shock = true
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	assert_array(_ids(desk._offered)).is_empty()

	save.tree_bought.append("storage_1")
	desk._process(0.0)

	assert_array(_ids(desk._offered)).is_equal(["offsite_storage"])


func test_the_consolidation_card_waits_for_the_golden_card_even_on_an_old_save_with_mechanisation() -> void:
	var save := _all_stamped_but(["golden_cabbage", "consolidation"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["consolidation"])


func test_the_workforce_card_sends_one_farm_hand_and_mechanisation_one_tractor_never_fewer() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("seasonal_workforce", save)
	UpgradeDesk.apply("mechanisation", save)
	assert_int(save.farm_hands).is_equal(1)
	assert_int(save.farm_tractors).is_equal(1)
	save.farm_hands = 3
	UpgradeDesk.apply("seasonal_workforce", save)
	assert_int(save.farm_hands).is_equal(3)


func test_an_old_save_with_the_farm_hand_and_tractor_gets_their_cards_and_workers() -> void:
	var old := SaveGame.new()
	old.migration = 3
	old.stamped = PackedStringArray(["family_farm"])
	old.farm_bought = PackedStringArray(["seed_contract", "farm_hand", "tractor"])
	UpgradeDesk.migrate(old)
	UpgradeDesk.migrate(old)
	assert_int(old.stamped.count("seasonal_workforce")).is_equal(1)
	assert_int(old.stamped.count("mechanisation")).is_equal(1)
	assert_int(old.farm_hands).is_equal(1)
	assert_int(old.farm_tractors).is_equal(1)
	assert_bool(old.farm_bought.has("seed_contract")).is_true()


func test_an_old_save_with_only_the_farm_hand_gets_no_tractor() -> void:
	var old := SaveGame.new()
	old.migration = 3
	old.farm_bought = PackedStringArray(["farm_hand"])
	UpgradeDesk.migrate(old)
	assert_bool(old.stamped.has("mechanisation")).is_false()
	assert_int(old.farm_tractors).is_equal(0)


func test_the_chute_lever_is_dealt_with_the_farm_and_paid_in_findings() -> void:
	assert_array(_next(THROUGH_QA, 10)).not_contains(["chute_control"])
	assert_array(_next(["family_farm"], UpgradeDesk.CARDS.size())).contains(["chute_control"])
	assert_str(UpgradeDesk.card_data("chute_control").currency).is_equal("findings")


func test_every_card_paid_in_cabbages_waits_for_the_chute_lever_and_the_lever_is_not_paid_in_cabbages() -> void:
	# Only units in storage pay a card in cabbages, and an open chute keeps emptying storage onto the mat.
	assert_bool(UpgradeDesk.costs(UpgradeDesk.card_data("chute_control")).has("stock")).is_false()
	for card: Dictionary in UpgradeDesk.CARDS:
		if not UpgradeDesk.costs(card).has("stock"):  # Paid in units, alone or with other currencies.
			continue
		var reached := {}
		var open: Array = card.get("needs", []).duplicate()
		while not open.is_empty():
			var id: String = open.pop_back()
			if not reached.has(id):
				reached[id] = true
				open.append_array(UpgradeDesk.card_data(id).get("needs", []))
		assert_bool(reached.has("chute_control")).override_failure_message(card.id).is_true()


func test_no_card_paid_in_cabbages_is_dealt_before_storage_for_its_price_can_be_bought() -> void:
	# Only the cards it needs (and theirs) are sure to be stamped when it is dealt: they alone must
	# unlock enough of the storage chain, or the tray can freeze on a card nobody can pay.
	for card: Dictionary in UpgradeDesk.CARDS:
		if not UpgradeDesk.costs(card).has("stock"):
			continue
		var stamped := {}
		var open: Array = card.get("needs", []).duplicate()
		while not open.is_empty():
			var id: String = open.pop_back()
			stamped[id] = true
			open.append_array(UpgradeDesk.card_data(id).get("needs", []))
		var cap := SaveGame.new().storage_cap
		for node: Dictionary in Projector.NODES:  # The storage chain, in order: it stops at the first lock.
			if not node.get("add", {}).has("storage_cap"):
				continue
			if [node.get("lock", ""), node.get("research", "")].any(func(lock: String) -> bool: return lock != "" and not stamped.has(lock)):
				break
			cap = Projector.cap_at(node.id)
		assert_int(UpgradeDesk.costs(card).stock).override_failure_message("%s costs more cabbages than storage can reach" % card.id) \
				.is_less_equal(cap)


class MemoSpy extends Node:
	var posted: Array[Dictionary] = []

	func post(m: Dictionary) -> void:
		posted.append(m)


func _desk_with_spy(save: SaveGame) -> Array:
	SaveManager.save = save
	var memo: MemoSpy = auto_free(MemoSpy.new())
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	desk.memo = memo
	add_child(desk)
	return [desk, memo]


func _file_new(desk: UpgradeDesk, id: String) -> void:
	SaveManager.save.stamped.append(id)
	var card := UpgradeCard.create(UpgradeDesk.card_data(id))
	desk.add_child(card)
	desk._count_spiked(card)
	desk._file(card)


func test_the_first_card_ever_filed_posts_one_memo_that_the_spike_holds_every_approval_and_the_pile_hops() -> void:
	var save := SaveGame.new()
	var made := _desk_with_spy(save)
	var desk: UpgradeDesk = made[0]
	var memo: MemoSpy = made[1]

	_file_new(desk, "price_slate")

	assert_array(memo.posted).is_equal([UpgradeDesk.SPIKE_MEMO])
	assert_bool(desk._riffling.is_running()).is_true()  # Every landing hops the pile.
	_file_new(desk, "radio")
	assert_int(memo.posted.size()).is_equal(1)
	assert_bool(desk._riffling.is_running()).is_true()


func test_a_loaded_save_with_approved_cards_never_posts_the_spike_memo_again() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["price_slate"])
	var memo: MemoSpy = _desk_with_spy(save)[1]
	assert_array(memo.posted).is_empty()


func test_an_old_save_with_off_site_storage_but_no_chute_lever_is_still_dealt_the_lever() -> void:
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["family_farm", "offsite_storage"])
	old.tree_bought = PackedStringArray(["storage_1"])
	UpgradeDesk.migrate(old)
	assert_array(UpgradeDesk.next_cards(old.stamped, UpgradeDesk.OFFERED, old)).contains(["chute_control"])


func test_an_old_save_with_the_first_three_bin_rebates_gets_five_dollars_a_rotten_unit() -> void:
	var old := SaveGame.new()
	old.tree_bought = PackedStringArray(["bin_mouth", "bin_rebate", "bin_rebate_2", "bin_rebate_3"])
	UpgradeDesk.migrate(old)
	assert_int(old.bin_coins).is_equal(5)


func test_off_site_storage_is_dealt_only_once_the_stock_room_is_bought() -> void:
	var save := _all_stamped_but(["offsite_storage"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["offsite_storage"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size())).not_contains(["offsite_storage"])
	save.tree_bought.append("storage_1")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["offsite_storage"])


func test_off_site_storage_costs_more_units_than_the_start_holds_but_fits_the_stock_room() -> void:
	var card := UpgradeDesk.card_data("offsite_storage")
	assert_str(card.currency).is_equal("stock")
	assert_int(card.price).is_greater(Projector.cap_at(Projector.node_data("storage_1").parent))
	assert_int(card.price).is_less_equal(Projector.cap_at("storage_1"))


func test_the_storage_past_the_stock_room_shows_but_waits_for_off_site_storage() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector"])
	save.tree_bought = PackedStringArray(["stock_25", "stock_32", "stock_40", "stock_50", "storage_1"])
	assert_bool(Projector.is_shown("stock_100", save)).is_true()
	assert_str(Projector.locked_by("stock_100", save)).is_equal("offsite_storage")
	save.stamped.append("offsite_storage")
	assert_str(Projector.locked_by("stock_100", save)).is_empty()


func test_an_old_save_past_the_stock_room_gets_off_site_storage_stamped() -> void:
	var old := SaveGame.new()
	old.tree_bought = PackedStringArray(["pack_1", "storage_1", "storage_2"])
	UpgradeDesk.migrate(old)
	assert_bool(old.stamped.has("offsite_storage")).is_true()


func test_a_loaded_save_never_holds_more_stock_than_storage_allows() -> void:
	var old := SaveGame.new()
	old.stock = 500
	UpgradeDesk.migrate(old)
	assert_int(old.stock).is_equal(old.storage_cap)
	assert_int(UpgradeDesk.clamp_stock(12, 20)).is_equal(12)


func test_the_chute_lever_comes_with_the_family_farm_and_off_site_storage_after_the_lever() -> void:
	var save := _all_stamped_but(["offsite_storage", "chute_control", "family_farm"])
	save.tree_bought = PackedStringArray(["pack_1", "storage_1"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["offsite_storage", "chute_control"])
	save.stamped.append("family_farm")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).contains(["chute_control"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["offsite_storage"])
	save.stamped.append("chute_control")
	assert_str(_next(save.stamped, UpgradeDesk.CARDS.size(), save)[0]).is_equal("offsite_storage")


func test_an_old_save_that_stamped_off_site_storage_before_the_farm_keeps_it() -> void:
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["offsite_storage"])
	old.tree_bought = PackedStringArray(["pack_1", "storage_1"])
	UpgradeDesk.migrate(old)
	assert_bool(old.stamped.has("offsite_storage")).is_true()


## Chapter 2's cards (the mini cards aside: they need optional stage-1 cards).
const CHAPTER_2 := ["family_farm", "offsite_storage", "chute_control", "farm_terminal", "farm_readout", "green_thumb",
	"seasonal_workforce", "golden_cabbage", "mechanisation", "standing_seed_order"]


func test_chapter_twos_last_card_is_dealt_only_once_every_other_chapter_two_card_is_stamped() -> void:
	# Its needs, and theirs, reach every chapter-2 card: none can be left unstamped when it is dealt.
	var reached := {}
	var open: Array = UpgradeDesk.card_data("consolidation").needs.duplicate()
	while not open.is_empty():
		var id: String = open.pop_back()
		reached[id] = true
		open.append_array(UpgradeDesk.card_data(id).get("needs", []))
	for id: String in CHAPTER_2:
		assert_bool(reached.has(id)).override_failure_message(id).is_true()
	for id: String in UpgradeDesk.card_data("consolidation").needs:
		var missing := _all_stamped_but([id, "consolidation"])
		assert_array(_next(missing.stamped, UpgradeDesk.CARDS.size())).override_failure_message(id).not_contains(["consolidation"])
	var save := _all_stamped_but(["consolidation", "mini_thinning", "micro_samples", "mini_station"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size())).contains(["consolidation"])


func test_chapter_twos_last_card_costs_more_cabbages_than_the_regional_depot_holds_and_fits_the_aircraft_hangar() -> void:
	var card := UpgradeDesk.card_data("consolidation")
	assert_str(card.currency).is_equal("stock")
	assert_int(card.price).is_greater(Projector.cap_at(Projector.node_data("stock_2000").parent))
	# A harvest only goes in whole, and the mat's cabbages can't pay: a hangar one hand harvest short
	# of full, with a full mat, still pays it (else the chapter never ends).
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["green_thumb"])
	save.farm_bought = PackedStringArray(["irrigation"])
	save.hand_yield = 3.0  # GREEN THUMB with EMPLOYEE OF THE MONTH
	var room := Projector.cap_at("stock_2000") - FarmScreen.harvest_yield(save, true) - Projector.MAT_MAX
	assert_int(card.price).is_less_equal(room)


func test_nothing_waits_on_the_golden_age_card_but_gold_standard() -> void:
	# DECLARE A GOLDEN AGE is the last of its line: no card, farm node or event needs it, and no projector
	# node but GOLD STANDARD (optional, it only extends the Golden Age to golden cabbages).
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_array(card.get("needs", [])).override_failure_message(card.id).not_contains(["golden_lamp"])
	for node: Dictionary in Projector.NODES + FarmTree.NODES:
		if node.id != SaleWindow.GOLD_AGE:
			assert_array(node.get("needs", [])).override_failure_message(node.id).not_contains(["golden_lamp"])
		for key: String in ["lock", "research", "after", "parent"]:
			assert_str(str(node.get(key, ""))).override_failure_message(node.id).is_not_equal("golden_lamp")
	for event: String in UpgradeDesk.Events.EVENTS:
		assert_str(str(UpgradeDesk.Events.EVENTS[event].get("card", ""))).override_failure_message(event).is_not_equal("golden_lamp")


func test_chapter_twos_last_card_is_the_dearest_card_paid_in_units_up_to_it() -> void:
	for card: Dictionary in UpgradeDesk.CARDS.slice(0, _all_ids().find("consolidation")):  # Chapter 3's world map card costs more.
		if card.get("currency") == "stock":
			assert_int(card.price).override_failure_message(card.id).is_less(UpgradeDesk.card_data("consolidation").price)


func test_stamping_chapter_twos_last_card_starts_the_invest_in_growth_event_and_chapter_3() -> void:
	var save := _all_stamped_but(["consolidation"])
	assert_bool(UpgradeDesk.Events.due("invest_in_growth", save)).is_false()
	assert_bool(UpgradeDesk.Events.chapter_3(save)).is_false()
	save.stamped.append("consolidation")
	assert_bool(UpgradeDesk.Events.due("invest_in_growth", save)).is_true()
	assert_bool(UpgradeDesk.Events.chapter_3(save)).is_true()


func test_the_promotion_deals_both_managerial_cards_paid_in_cabbages_only_once_mechanisation_is_stamped() -> void:
	var save := _all_stamped_but(["mechanisation", "standing_seed_order", "own_sales", "own_research", "consolidation"])
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["own_sales", "own_research"])
	save.stamped.append("mechanisation")
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save).slice(0, 2)).is_equal(["own_sales", "own_research"])
	for id: String in ["own_sales", "own_research"]:
		assert_str(UpgradeDesk.card_data(id).currency).is_equal("stock")
		assert_str(UpgradeDesk.card_data(id).event).is_equal("promotion")


func test_the_managerial_cards_raise_the_players_own_sales_and_research_by_a_fifth() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("own_sales", save)
	assert_float(save.own_sale).is_equal_approx(1.2, 0.0001)
	assert_float(save.own_lab).is_equal(1.0)
	UpgradeDesk.apply("own_research", save)
	assert_float(save.own_lab).is_equal_approx(1.2, 0.0001)


func test_chapter_twos_last_card_costs_1900_cabbages_4000_findings_and_20000_coins_at_once() -> void:
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("consolidation"))).is_equal({coins = 20000, findings = 4000, stock = 1900})
	# A card in one currency costs just that.
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("projector"))).is_equal({coins = 75})
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("street_posters"))).is_equal({findings = 10})


func test_a_card_in_several_currencies_is_affordable_only_when_every_one_is_covered_units_from_the_store() -> void:
	var bill := UpgradeDesk.costs(UpgradeDesk.card_data("consolidation"))
	var save := SaveGame.new()
	save.stock = 1900
	save.findings = 4000
	save.coins = 20000
	assert_bool(UpgradeDesk.affords(save, bill)).is_true()
	assert_bool(UpgradeDesk.affords(save, bill, Vector2i(1, 0))).override_failure_message("one unit on the mat").is_false()
	for short: String in ["coins", "findings", "stock"]:
		var poorer := save.duplicate() as SaveGame
		poorer.set(short, int(poorer.get(short)) - 1)
		assert_bool(UpgradeDesk.affords(poorer, bill)).override_failure_message(short).is_false()


func test_the_press_refuses_a_card_in_several_currencies_one_short_and_pays_them_all_at_once_when_covered() -> void:
	var save := _all_stamped_but(["consolidation"])
	save.tray_unlocked = true
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	save.storage_cap = Projector.cap_at("stock_2000")
	save.stock = 1950  # After loading: the desk's migrate clamps stock to storage.
	save.findings = 4100
	save.coins = 19999
	var card := desk._offered[0]
	assert_str(card.id).is_equal("consolidation")
	desk._on_press = card

	desk._bottom_out()  # A coin short: refused, nothing paid.

	assert_bool(save.stamped.has("consolidation")).is_false()
	assert_array([save.stock, save.findings, save.coins]).is_equal([1950, 4100, 19999])
	save.coins = 20100
	desk._bottom_out()

	assert_bool(save.stamped.has("consolidation")).is_true()
	assert_array([save.stock, save.findings, save.coins]).is_equal([50, 100, 100])


## A desk with a tray of affordable forms (cards dealt after the slate and the radio, coins to spare).
func _progress_desk() -> UpgradeDesk:
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.stamped = PackedStringArray(["price_slate", "radio"])
	save.coins = 1000000
	save.findings = 1000000
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	desk.set_process(false)
	return desk


func _tick(desk: UpgradeDesk, seconds: float) -> void:
	for i in roundi(seconds / 0.5):
		desk._tick_progress(SaveManager.save, 0.5)


func test_a_form_left_affordable_on_the_desk_for_five_minutes_warns_that_progress_is_required() -> void:
	var desk := _progress_desk()
	_tick(desk, UpgradeDesk.Events.PROGRESS_AFTER - 1.0)
	assert_bool(SaveManager.save.progress_warned).is_false()
	_tick(desk, 1.0)
	assert_bool(SaveManager.save.progress_warned).is_true()


## Plays `seconds` through the desk's own frame (_process), as the game does, in ordinary uneven
## frames (a 0.1 s one, then 1/60 s ones), never a frame past it.
func _play(desk: UpgradeDesk, seconds: float) -> void:
	var played := 0.0
	var i := 0
	while true:
		var frame := 0.1 if i % 4 == 0 else 1.0 / 60.0
		if played + frame > seconds + 0.0001:
			break
		desk._process(frame)
		played += frame
		i += 1


func test_the_five_minutes_run_while_the_player_plays() -> void:
	var desk := _progress_desk()
	_play(desk, 60.0)
	assert_float(SaveManager.save.progress_wait).is_equal_approx(60.0, 0.5)
	_play(desk, UpgradeDesk.Events.PROGRESS_AFTER - 61.0)
	assert_bool(SaveManager.save.progress_warned).is_false()  # Not a second early...
	_play(desk, 1.5)
	assert_bool(SaveManager.save.progress_warned).is_true()  # ...nor late.


func test_the_five_minutes_stand_still_while_a_boss_report_is_up_or_the_menu_is_open() -> void:
	var menu: Control = auto_free(Control.new())
	menu.name = "InGameMenu"
	menu.visible = false
	add_child(menu)
	var desk := _progress_desk()
	var report_was := BossReport.up
	_play(desk, 30.0)
	var wait := SaveManager.save.progress_wait
	assert_float(wait).is_greater(0.0)

	BossReport.up = true
	_play(desk, 60.0)
	BossReport.up = report_was
	assert_float(SaveManager.save.progress_wait).is_equal(wait)

	menu.visible = true
	_play(desk, 60.0)
	assert_float(SaveManager.save.progress_wait).is_equal(wait)

	menu.visible = false
	_play(desk, 30.0)
	assert_float(SaveManager.save.progress_wait).is_greater(wait)


func test_approving_any_form_on_the_desk_restarts_the_five_minutes() -> void:
	var desk := _progress_desk()
	_tick(desk, 200.0)
	SaveManager.save.stamped.append("desk_space")
	_tick(desk, 200.0)
	assert_bool(SaveManager.save.progress_warned).is_false()
	assert_float(SaveManager.save.progress_wait).is_less(200.0)


func test_the_progress_clock_does_not_run_while_no_form_on_the_desk_is_affordable() -> void:
	var desk := _progress_desk()
	SaveManager.save.coins = 0
	SaveManager.save.findings = 0
	_tick(desk, 600.0)
	assert_float(SaveManager.save.progress_wait).is_equal(0.0)
	assert_bool(SaveManager.save.progress_warned).is_false()


func test_no_progress_warning_after_the_chapters_last_form() -> void:
	var desk := _progress_desk()
	SaveManager.save.stamped.append(UpgradeDesk.Events.EVENTS.invest_in_growth.card)
	_tick(desk, 600.0)
	assert_bool(SaveManager.save.progress_warned).is_false()


func test_the_warning_changes_nothing_but_the_paperwork() -> void:
	var desk := _progress_desk()
	var save := SaveManager.save
	var skip := ["progress_wait", "progress_warned", "playtest_log"]
	var was := {}
	for property in save.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in skip:
			was[property.name] = str(save.get(property.name))
	_tick(desk, UpgradeDesk.Events.PROGRESS_AFTER + 30.0)
	assert_bool(save.progress_warned).is_true()
	for field: String in was:
		assert_str(str(save.get(field))).override_failure_message(field).is_equal(was[field])


func test_the_reminder_slip_appears_on_the_tray_once_the_progress_warning_is_signed() -> void:
	var desk := _progress_desk()
	_tick(desk, UpgradeDesk.Events.PROGRESS_AFTER + 1.0)
	desk._process(1.0)
	assert_bool(desk._slip.visible).is_false()  # Warned, but the note is still up, unsigned.

	SaveManager.save.reports.append("progress_required")
	desk._process(1.0)
	assert_bool(desk._slip.visible).is_true()


func test_a_save_that_already_signed_the_warning_shows_the_slip_on_load() -> void:
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.progress_warned = true
	save.reports = PackedStringArray(["welcome", "progress_required"])
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	assert_bool(desk._slip.visible).is_true()


func test_a_desk_that_never_got_the_warning_has_no_slip() -> void:
	var desk := _progress_desk()
	desk._process(1.0)
	assert_bool(desk._slip.visible).is_false()
	assert_bool(UpgradeDesk.slip_shown(SaveGame.new())).is_false()


func test_the_reminder_slips_big_word_stays_inside_the_slip_in_english_and_german() -> void:
	var locale := TranslationServer.get_locale()
	var desk := _progress_desk()
	var word: Label3D = desk.get_node("Tray/Slip/Word")
	var slip: Vector2 = (desk._slip.mesh as PlaneMesh).size
	for lang in ["en", "de"]:
		TranslationServer.set_locale(lang)
		var drawn := UpgradeCard.TITLE_FONT.get_string_size(tr(word.text), HORIZONTAL_ALIGNMENT_LEFT, -1, word.font_size) * word.pixel_size
		assert_float(drawn.x).override_failure_message(lang).is_less_equal(UpgradeDesk.SLIP_BOX.x)
		# Capitals only: they stand within the font's ascent.
		assert_float(UpgradeCard.TITLE_FONT.get_ascent(word.font_size) * word.pixel_size).override_failure_message(lang).is_less_equal(UpgradeDesk.SLIP_BOX.y)
	TranslationServer.set_locale(locale)
	assert_float(UpgradeDesk.SLIP_BOX.x).is_less(slip.x)
	assert_float(UpgradeDesk.SLIP_BOX.y).is_less(slip.y)


func test_hovering_the_reminder_slip_opens_the_same_paper_as_a_form_does_explaining_that_every_form_must_be_approved_to_progress() -> void:
	var desk := _progress_desk()
	var hover: Interactable = desk.get_node("Tray/Slip/Hit/Interactable")
	var shape: CollisionShape3D = desk.get_node("Tray/Slip/Hit/Shape")
	assert_bool(hover.enabled).is_false()
	assert_bool(shape.disabled).is_true()

	SaveManager.save.reports.append("progress_required")
	desk._process(1.0)
	assert_bool(hover.enabled).is_true()
	assert_bool(shape.disabled).is_false()
	assert_str(hover.tooltip).is_empty()  # No hand tooltip: the form's own paper.
	hover.hovered.emit()
	var paper: PaperNote = desk.get_node("Note/Center/Paper")
	assert_str(paper._title).is_equal(tr("NOTICE"))
	assert_str(paper._form).is_equal(tr(UpgradeDesk.NOTICE.form))
	assert_bool(paper._bill.is_empty()).is_true()
	assert_str(UpgradeDesk.NOTICE.body).contains("Every form on this desk must be approved")
	assert_str(UpgradeDesk.NOTICE.body).contains("projector is optional")
	# Only a paper to read: nothing to press.
	assert_bool(hover.pressable).is_false()
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	for key: String in [UpgradeDesk.NOTICE.form, UpgradeDesk.NOTICE.title, UpgradeDesk.NOTICE.body]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
	TranslationServer.set_locale(locale)


func test_the_pad_asks_for_a_form_until_the_first_form_is_ever_stamped() -> void:
	assert_int(UpgradeDesk.first_stamp_hint(false, true, false, false)).is_equal(UpgradeDesk.Hint.NUDGE)


func test_the_affordable_form_stops_nudging_while_the_hand_holds_something_but_the_pad_still_asks() -> void:
	assert_int(UpgradeDesk.first_stamp_hint(false, true, false, true)).is_equal(UpgradeDesk.Hint.PAD)


func test_the_stamp_asks_to_be_pressed_once_a_form_lies_on_the_pad() -> void:
	assert_int(UpgradeDesk.first_stamp_hint(false, true, true, false)).is_equal(UpgradeDesk.Hint.STAMP)
	assert_int(UpgradeDesk.first_stamp_hint(false, true, true, true)).is_equal(UpgradeDesk.Hint.STAMP)


func test_no_hint_shows_while_no_form_is_affordable() -> void:
	assert_int(UpgradeDesk.first_stamp_hint(false, false, false, false)).is_equal(UpgradeDesk.Hint.NONE)


func test_no_hint_shows_once_any_form_has_been_stamped() -> void:
	for on_pad: bool in [false, true]:
		for holding: bool in [false, true]:
			assert_int(UpgradeDesk.first_stamp_hint(true, true, on_pad, holding)).is_equal(UpgradeDesk.Hint.NONE)


## A fresh desk with the tray down and the price slate dealt, `coins` on the tally.
func _first_desk(coins: int) -> UpgradeDesk:
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.coins = coins
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	desk.set_process(false)
	return desk


func test_a_fresh_desk_shows_the_ghost_form_on_the_pad_once_the_first_form_is_affordable() -> void:
	var desk := _first_desk(0)
	desk._hint(SaveManager.save)
	assert_bool(desk._ghost.visible).is_false()
	SaveManager.save.coins = UpgradeDesk.TRAY_COINS
	desk._hint(SaveManager.save)
	assert_bool(desk._ghost.visible).is_true()
	assert_bool(desk._tag.visible).is_false()


func test_a_form_on_the_pad_swaps_the_ghost_for_the_stamp_tag_and_taking_it_off_brings_the_ghost_back() -> void:
	var desk := _first_desk(UpgradeDesk.TRAY_COINS)
	var card := desk._offered[0]
	card.position = desk._pad()
	desk._on_dropped(card)
	assert_array([desk._ghost.visible, desk._tag.visible]).is_equal([false, true])
	card.position = desk._slot(0)
	desk._on_dropped(card)
	assert_array([desk._ghost.visible, desk._tag.visible]).is_equal([true, false])


func test_the_first_stamp_hides_the_hint_for_good() -> void:
	var desk := _first_desk(UpgradeDesk.TRAY_COINS)
	desk._on_press = desk._offered[0]
	desk._hint(SaveManager.save)
	desk._bottom_out()
	assert_array([desk._ghost.visible, desk._tag.visible, desk._hinting]).is_equal([false, false, false])


func test_a_loaded_save_with_a_stamped_form_never_looks_at_the_hint() -> void:
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.coins = 1000
	save.stamped = PackedStringArray(["price_slate"])
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	assert_array([desk._hinting, desk._ghost.visible, desk._tag.visible]).is_equal([false, false, false])


func test_the_ghost_form_draws_its_outline_on_from_nothing_the_moment_it_appears() -> void:
	var desk := _first_desk(UpgradeDesk.TRAY_COINS)
	var ink := desk._ghost.mesh.surface_get_material(0) as ShaderMaterial
	ink.set_shader_parameter(&"draw", 1.0)
	desk._hint(SaveManager.save)
	assert_float(ink.get_shader_parameter(&"draw")).is_equal(0.0)
	await await_millis(roundi((UpgradeDesk.GHOST_DRAW + 0.15) * 1000.0))
	assert_float(ink.get_shader_parameter(&"draw")).is_equal(1.0)


func test_the_nudged_form_lifts_and_slides_toward_the_pad_then_settles_back() -> void:
	var desk := _first_desk(UpgradeDesk.TRAY_COINS)
	var card := desk._offered[0]
	var toward := desk._pad() - card.position
	card.nudge(toward)
	await await_millis(roundi(UpgradeCard.NUDGE_OUT * 1000.0))
	var look: Node3D = card.get_node("Look")
	assert_float(look.position.y).is_greater(UpgradeCard.HOVER_LIFT)
	assert_float(Vector2(look.position.x, look.position.z).dot(Vector2(toward.x, toward.z))).is_greater(0.0)
	await await_millis(roundi((UpgradeCard.NUDGE_OUT * 2.0 + UpgradeCard.NUDGE_STEP * 4.0) * 1000.0))
	assert_vector(look.position).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.001)


func test_the_stamp_tag_tells_the_player_to_pull_the_handle() -> void:
	var desk := _first_desk(UpgradeDesk.TRAY_COINS)
	assert_str((desk._tag as Label3D).text).is_equal("PULL TO STAMP")


const CHAPTER_3 := ["market_intelligence", "cash_holding", "big_ideas", "archive_capacity", "map_readout", "condense", "structured_farm", "negotiation", "rejected_goods", "hand_schedule", "bribery", "war_mode", "world_map", "no_taxes", "sea_lanes", "route_planning", "unit_charge", "bigger_armies", "tactics", "unit_senior", "unit_pult", "retreat", "unit_courier", "stars", "farm_shortcut"]
## Chapter 3's chain as it is dealt: each entry arrives once the one before it is stamped, a group all at once.
const CHAPTER_3_DEALS := [["market_intelligence"], ["cash_holding", "big_ideas", "archive_capacity"], ["condense", "structured_farm"],
		["negotiation"], ["rejected_goods"], ["bribery"], ["war_mode"], ["world_map"], ["no_taxes"], ["sea_lanes"], ["stars"]]
## Its optional cards, beside the chain: nothing waits for them.
const CHAPTER_3_OPTIONAL := ["map_readout", "hand_schedule", "farm_shortcut"]
## The war line, beside the main line from the first law on, one card after the other; stars waits for it.
const CHAPTER_3_WAR := ["route_planning", "unit_charge", "tactics", "unit_senior", "unit_pult", "retreat", "unit_courier"]
## The war line's card dealt by the boss's paper.
const WAR_EVENT_CARD := "bigger_armies"


func test_the_market_intelligence_card_comes_only_after_chapter_twos_last_card_and_first_in_the_tray() -> void:
	var save := _all_stamped_but(["consolidation"] + CHAPTER_3)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(CHAPTER_3)
	save.stamped.append("consolidation")
	assert_str(_next(save.stamped, UpgradeDesk.OFFERED, save)[0]).is_equal("market_intelligence")
	var card := UpgradeDesk.card_data("market_intelligence")
	assert_str(card.event).is_equal("invest_in_growth")  # Dealt by the promotion paper's event.
	assert_dict(UpgradeDesk.costs(card)).is_equal({findings = 1500})


func test_a_card_that_needs_five_farms_cannot_be_stamped_with_four() -> void:
	var bill := UpgradeDesk.costs({id = "x", price = 10, farms = 5})
	assert_dict(bill).is_equal({farms = 5, coins = 10})
	var save := SaveGame.new()
	save.coins = 10
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4"])
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()
	save.farms_owned.append("K-5")
	assert_bool(UpgradeDesk.affords(save, bill)).is_true()
	save.coins = 9  # The farms alone do not pay its price.
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()


func test_the_press_refuses_the_stars_card_one_farm_short_and_stamping_it_takes_the_price_but_no_farm() -> void:
	var save := _all_stamped_but(["stars"])
	save.tray_unlocked = true
	var price: int = UpgradeDesk.card_data("stars").price
	save.coin_limit = price * 2
	save.coins = price + 100000
	for i in UpgradeDesk.Events.FARMS:
		save.farms_owned.append("F-%d" % i)
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	var card := desk._offered[0]
	assert_str(card.id).is_equal("stars")  # Dealt with every farm owned.
	desk._on_press = card
	save.farms_owned.remove_at(0)  # One lost again (nothing does that in play): the press still counts them.

	desk._bottom_out()  # 23 farms: refused, nothing paid.

	assert_bool(save.stamped.has("stars")).is_false()
	assert_int(save.coins).is_equal(price + 100000)
	save.farms_owned.append("F-last")
	desk._bottom_out()

	assert_bool(save.stamped.has("stars")).is_true()
	assert_int(save.coins).is_equal(100000)
	assert_int(save.farms_owned.size()).is_equal(UpgradeDesk.Events.FARMS)



func test_big_minds_is_dealt_with_the_cash_holding_card_and_costs_coins() -> void:
	var save := _all_stamped_but(CHAPTER_3)
	save.stamped.append("market_intelligence")
	assert_array(_next(save.stamped, UpgradeDesk.OFFERED, save)).contains(["cash_holding", "big_ideas"])
	save.stamped.append("big_ideas")  # Stamped first: the cash card stays on offer.
	assert_array(_next(save.stamped, UpgradeDesk.OFFERED, save)).contains(["cash_holding"])
	assert_str(UpgradeDesk.card_data("big_ideas").title).is_equal("BIG MINDS HAVE BIG IDEAS")
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("big_ideas"))).is_equal({coins = 40000})


func test_the_world_map_card_needs_five_farms_and_its_cabbages_and_nothing_else() -> void:
	var card := UpgradeDesk.card_data("world_map")
	var bill := UpgradeDesk.costs(card)
	assert_dict(bill).is_equal({farms = UpgradeDesk.Events.HOME_SELLERS, stock = 13000})
	var save := SaveGame.new()
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	save.storage_cap = 15000
	save.stock = 12999
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()
	save.stock = 13000
	assert_bool(UpgradeDesk.affords(save, bill)).is_true()
	save.farms_owned.remove_at(0)  # The cabbages alone do not do it.
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()


func test_the_world_map_cards_cabbages_fit_the_biggest_store_with_a_full_mat_of_condensed_cabbages_out() -> void:
	var biggest := SaveGame.new().storage_cap
	for node: Dictionary in Projector.NODES:
		biggest += int(node.get("add", {}).get("storage_cap", 0))
	assert_int(biggest).is_equal(15000)
	# A full mat of ten cabbages holding 32 each cannot pay (UpgradeDesk.spendable).
	assert_int(Projector.MAT_MAX).is_equal(10)
	assert_int(int(UpgradeDesk.card_data("world_map").price) + Projector.MAT_MAX * 32).is_less_equal(biggest)


func test_stamping_the_world_map_card_takes_its_cabbages_and_no_farm() -> void:
	var save := _all_stamped_but(["world_map", "stars"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	save.storage_cap = 15000
	save.stock = 13500
	var bill := UpgradeDesk.costs(UpgradeDesk.card_data("world_map"))
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in])
	assert_int(save.stock).is_equal(500)
	assert_int(save.farms_owned.size()).is_equal(5)


func test_stamping_condense_cabbages_makes_a_dropped_cabbage_hold_two() -> void:
	var save := SaveGame.new()
	assert_int(save.condense).is_equal(1)
	UpgradeDesk.apply("condense", save)
	assert_int(save.condense).is_equal(2)
	UpgradeDesk.apply("condense", save)  # Never more from the card itself.
	assert_int(save.condense).is_equal(2)


func test_a_condensed_cabbage_out_of_the_chute_counts_as_two_cabbages_that_cannot_pay_a_card() -> void:
	var dense: Cabbage = auto_free(Cabbage.new())
	dense.units = 2
	var gold: Cabbage = auto_free(Cabbage.new())
	gold.golden = true
	gold.units = 3
	assert_that(UpgradeDesk.units_out([dense, gold, auto_free(Cabbage.new())])).is_equal(Vector2i(6, 3))


func _home_farms(count: int) -> PackedStringArray:
	var out := PackedStringArray()
	for n in count:
		out.append("%s%d" % [UpgradeDesk.Events.HOME_PREFIX, n + 1])
	return out


func test_chapter_threes_cards_come_one_after_the_other_but_for_two_groups_that_arrive_together_from_the_fifth_farm_on() -> void:
	var at := _all_ids().find("consolidation")
	assert_array(_all_ids().slice(at + 1)).is_equal(CHAPTER_3)  # Every card after chapter 2's last one, in order.
	var chain := []
	for deal: Array in CHAPTER_3_DEALS:
		chain.append_array(deal)
	assert_array(chain + CHAPTER_3_OPTIONAL + CHAPTER_3_WAR + [WAR_EVENT_CARD]).contains_exactly_in_any_order(CHAPTER_3)
	assert_array(CHAPTER_3_DEALS.filter(func(deal: Array) -> bool: return deal.size() > 1)).is_equal(
			[["cash_holding", "big_ideas", "archive_capacity"], ["condense", "structured_farm"]])
	for farms: int in [UpgradeDesk.Events.HOME_SELLERS, UpgradeDesk.Events.FARMS]:  # The war card waits for the fifth (its event).
		var save := _all_stamped_but(chain)  # The optional cards and the war line out of the way.
		for i in farms:
			save.farms_owned.append("F-%d" % i)
		for deal: Array in CHAPTER_3_DEALS:
			var left := deal.duplicate()
			while not left.is_empty():  # Stamped last one first: any order, and nothing new until all are.
				assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).override_failure_message("%s with %d farms" % [left, farms]).is_equal(left)
				save.stamped.append(left.pop_back())
		assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_empty()


func test_the_three_cards_after_market_intelligence_fill_the_tray_together_and_any_of_them_can_be_stamped_first() -> void:
	var save := _all_stamped_but(CHAPTER_3)
	save.stamped.append("market_intelligence")
	assert_array(_next(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["cash_holding", "big_ideas", "archive_capacity"])
	for id: String in ["cash_holding", "big_ideas", "archive_capacity"]:
		assert_array(UpgradeDesk.card_data(id).needs).override_failure_message(id).is_equal(["market_intelligence"])
		# Each is paid under the limits the desk starts with, so none has to wait for another.
		var bill := UpgradeDesk.costs(UpgradeDesk.card_data(id))
		assert_int(bill.get("coins", 0)).override_failure_message(id).is_less_equal(SaveGame.new().coin_limit)
		assert_int(bill.get("findings", 0)).override_failure_message(id).is_less_equal(SaveGame.new().findings_limit)


func test_the_holdings_indicator_is_requisitioned_after_the_map_arrives() -> void:
	var card := UpgradeDesk.card_data("map_readout")
	assert_str(card.title).is_equal("REQUISITION A HOLDINGS INDICATOR")
	assert_array(card.needs).is_equal(["market_intelligence"])  # The card that brings the map table.
	assert_bool(UpgradeDesk.timed(card)).is_false()
	var save := _all_stamped_but(CHAPTER_3)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["map_readout"])
	save.stamped.append("market_intelligence")
	assert_bool(MapTable.unlocked(save)).is_true()
	# Open with the three cards, behind them in the queue: it takes the first slot one of them frees.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["cash_holding", "big_ideas", "archive_capacity", "map_readout"])
	save.stamped.append("big_ideas")
	assert_array(_next(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["cash_holding", "archive_capacity", "map_readout"])
	# A comfort: coins only, no farm, and within the purse the desk starts with.
	assert_dict(UpgradeDesk.costs(card)).is_equal({coins = int(card.price)})
	assert_int(card.price).is_less_equal(SaveGame.new().coin_limit)
	var stamped := SaveGame.new()
	UpgradeDesk.apply("map_readout", stamped)  # No number changes: the map table reads the stamp.
	assert_int(stamped.coin_limit).is_equal(SaveGame.new().coin_limit)


func test_an_old_save_already_at_the_map_table_keeps_its_holdings_indicator() -> void:
	var old := SaveGame.new()  # From before the tally was a card: it stood at the map table from the start.
	old.migration = 4
	old.stamped = PackedStringArray(["consolidation", "market_intelligence"])
	UpgradeDesk.migrate(old)
	UpgradeDesk.migrate(old)
	assert_int(Array(old.stamped).count("map_readout")).is_equal(1)
	var early := SaveGame.new()  # Not at the map table yet: the card comes like for anyone.
	early.migration = 4
	early.stamped = PackedStringArray(["consolidation"])
	UpgradeDesk.migrate(early)
	assert_bool(early.stamped.has("map_readout")).is_false()
	var fresh := SaveGame.new()  # A save of this build that has just stamped the map's card pays for its tally.
	fresh.migration = SaveGame.MIGRATION
	fresh.stamped = PackedStringArray(["consolidation", "market_intelligence"])
	UpgradeDesk.migrate(fresh)
	assert_bool(fresh.stamped.has("map_readout")).is_false()


func test_nothing_waits_on_the_holdings_indicator() -> void:
	assert_array(UpgradeDesk.Events.DRY_LEFT).contains(["map_readout"])
	for other: Dictionary in UpgradeDesk.CARDS:
		assert_bool(other.get("needs", []).has("map_readout")).override_failure_message(other.id + " waits for it").is_false()
	for node: Dictionary in Projector.NODES + FarmTree.NODES:
		assert_bool(node.get("needs", []).has("map_readout")).override_failure_message(node.id + " waits for it").is_false()
	# Left in the tray to the end, the chain still runs through beside it.
	var save := _all_stamped_but(CHAPTER_3)
	save.stamped.append_array(CHAPTER_3_WAR + [WAR_EVENT_CARD])  # The war line beside the chain, out of the way.
	save.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SELLERS)  # The war card's event.
	for deal: Array in CHAPTER_3_DEALS:
		for id: String in deal:
			assert_array(_next(save.stamped, UpgradeDesk.OFFERED, save)).override_failure_message(id).contains([id])
			save.stamped.append(id)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(CHAPTER_3_OPTIONAL)


func test_only_chapter_threes_first_card_the_war_card_and_the_workforce_card_are_dealt_by_an_event() -> void:
	for id: String in CHAPTER_3:
		var card := UpgradeDesk.card_data(id)
		assert_bool(card.has("event")).override_failure_message(id).is_equal(id in ["market_intelligence", "war_mode", WAR_EVENT_CARD])
		assert_bool(card.has("tree")).override_failure_message(id).is_false()


func test_the_stars_card_reaches_the_tray_only_once_the_first_law_and_the_sea_lanes_are_stamped() -> void:
	var save := _all_stamped_but(["no_taxes", "sea_lanes", "stars"])
	for i in UpgradeDesk.Events.FARMS:
		save.farms_owned.append("F-%d" % i)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["no_taxes"])
	save.stamped.append("no_taxes")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["sea_lanes"])
	save.stamped.append("sea_lanes")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["stars"])
	# The chain's last card; only an optional card (which nothing waits for) may come after it.
	var chain := UpgradeDesk.CARDS.filter(func(c: Dictionary) -> bool: return not c.id in UpgradeDesk.Events.DRY_LEFT)
	assert_dict(chain[-1]).is_equal(UpgradeDesk.card_data("stars"))


func test_only_chapter_changing_cards_are_priority_forms() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_bool(card.get("priority", false)).override_failure_message(card.id).is_equal(card.id in ["family_farm", "consolidation", "stars"])


func test_sea_lanes_needs_almost_all_farms_of_the_starting_continent() -> void:
	var card := UpgradeDesk.card_data("sea_lanes")
	assert_str(card.title).is_equal("SEA LANES")
	assert_str(WorldRegister.SEA_CARD).is_equal("sea_lanes")
	# The starting continent: the home country and the three it reaches by land.
	var continent := 0
	var least := 99
	for country: StringName in [&"kohlmark", &"ostrevia", &"veldmark", &"sulvania"]:
		continent += int(WorldRegister.COUNTRIES[country].farms)
		least = mini(least, int(WorldRegister.COUNTRIES[country].farms))
	assert_int(continent).is_equal(15)
	# Almost all: one of the small neighbours may be left for later, Sulvania (where the lanes start) may not.
	assert_int(card.farms).is_equal(continent - least)
	assert_int(card.farms).is_greater(continent - int(WorldRegister.COUNTRIES[&"sulvania"].farms))
	# Paid in Findings and coins, the farms only needed.
	assert_array(UpgradeDesk.costs(card).keys()).is_equal(["farms", "coins", "findings"])


func test_a_card_that_needs_farms_waits_in_the_tray_until_they_are_owned() -> void:
	var save := _all_stamped_but(["condense", "world_map", "no_taxes", "stars"])
	save.tray_unlocked = true
	save.coins = 150000
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	var card := desk._offered[0]
	assert_str(card.id).is_equal("condense")  # In the tray with no farm owned.
	assert_dict(card.costs).is_equal({farms = 1, coins = 150000})
	desk._on_press = card

	desk._bottom_out()  # No farm: refused, nothing paid.

	assert_bool(save.stamped.has("condense")).is_false()
	assert_int(save.coins).is_equal(150000)
	save.farms_owned.append("K-1")
	desk._bottom_out()

	assert_bool(save.stamped.has("condense")).is_true()
	assert_int(save.coins).is_equal(0)
	assert_int(save.farms_owned.size()).is_equal(1)


func test_the_world_map_card_needs_as_many_farms_as_are_sold_at_home_and_the_war_card() -> void:
	assert_int(UpgradeDesk.card_data("world_map").farms).is_equal(UpgradeDesk.Events.HOME_SELLERS)
	assert_array(UpgradeDesk.card_data("world_map").needs).is_equal([FarmRegister.WAR_CARD])  # Abroad nothing is bought.
	assert_array(UpgradeDesk.card_data("stars").needs).contains(["war_mode", "world_map", "no_taxes"])


func test_the_war_card_is_dealt_once_nobody_at_home_sells_any_more() -> void:
	var card := UpgradeDesk.card_data(FarmRegister.WAR_CARD)
	assert_str(card.title).is_equal("AUTHORISE HOSTILE ACQUISITIONS")
	assert_str(card.event).is_equal("no_more_sellers")
	assert_array(card.needs).is_equal(["bribery"])
	assert_dict(UpgradeDesk.costs(card)).is_equal({farms = UpgradeDesk.Events.HOME_SELLERS, coins = int(card.price)})
	var save := _all_stamped_but(["war_mode", "world_map", "no_taxes", "sea_lanes", "stars"])
	save.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SELLERS - 1)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_empty()
	save.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SELLERS)  # The fifth: THEY WILL NOT SELL ANY MORE.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["war_mode"])


func test_an_old_save_past_the_war_card_before_it_existed_has_it_filed_and_keeps_its_farms() -> void:
	for owned: Array in [["world_map"], []]:
		var old := SaveGame.new()
		old.migration = 5
		old.stamped = PackedStringArray(["negotiation", "bribery"] + owned)
		old.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SELLERS + (0 if owned else 1))
		UpgradeDesk.migrate(old)
		UpgradeDesk.migrate(old)
		assert_int(Array(old.stamped).count(FarmRegister.WAR_CARD)).is_equal(1)
		assert_int(old.farms_owned.size()).is_greater_equal(UpgradeDesk.Events.HOME_SELLERS)
	var due := SaveGame.new()  # Five farms and no further: the card comes like for anyone.
	due.migration = 5
	due.stamped = PackedStringArray(["negotiation", "bribery"])
	due.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SELLERS)
	UpgradeDesk.migrate(due)
	assert_bool(due.stamped.has(FarmRegister.WAR_CARD)).is_false()


func test_the_no_taxes_card_needs_every_farm_of_the_home_country_not_just_eight_farms() -> void:
	var card := UpgradeDesk.card_data("no_taxes")
	var bill := UpgradeDesk.costs(card)
	assert_dict(bill).is_equal({home_farms = UpgradeDesk.Events.HOME_SITES, coins = int(card.price)})
	var save := SaveGame.new()
	save.coins = int(card.price)
	save.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SITES - 1)
	save.farms_owned.append_array(["W-1", "W-2", "W-3"])  # Ten farms, but one at home is missing.
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()
	save.farms_owned.append("%s%d" % [UpgradeDesk.Events.HOME_PREFIX, UpgradeDesk.Events.HOME_SITES])
	assert_bool(UpgradeDesk.affords(save, bill)).is_true()
	save.coins -= 1  # The farms alone do not pay it.
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()
	# The same farms the boss's THE COUNTRY IS OURS paper waits for.
	assert_int(UpgradeDesk.Events.EVENTS.home_country.home_farms).is_equal(card.home_farms)


func test_paying_the_no_taxes_card_takes_its_coins_and_no_farm() -> void:
	var card := UpgradeDesk.card_data("no_taxes")
	var save := SaveGame.new()
	save.coins = int(card.price) + 5
	save.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SITES)
	var bill := UpgradeDesk.costs(card)
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in])
	assert_int(save.coins).is_equal(5)
	assert_int(save.farms_owned.size()).is_equal(UpgradeDesk.Events.HOME_SITES)


func test_with_no_taxes_a_cabbage_sells_for_19_percent_more_and_as_easily_as_before() -> void:
	var save := SaveGame.new()
	save.marketing = 40.0
	save.sale_price = 100
	var chance := PriceSlate.acceptance(save)
	var full := PriceSlate.ref_price(save.marketing, 1.0)

	UpgradeDesk.apply("no_taxes", save)

	assert_int(save.sale_price).is_equal(119)  # The chalked price: what a sale pays.
	assert_float(PriceSlate.ref_price(save.marketing, 1.0)).is_equal_approx(full * 1.19, 0.001)
	assert_float(PriceSlate.acceptance(save)).is_equal_approx(chance, 0.01)  # The street buys as before.
	assert_float(UpgradeDesk.TAX_FREE).is_equal(1.19)


func test_with_no_taxes_the_chalked_price_never_goes_past_the_slates_top_price() -> void:
	var save := SaveGame.new()
	save.sale_price = PriceSlate.max_price(save.marketing)
	UpgradeDesk.apply("no_taxes", save)
	assert_int(save.sale_price).is_less_equal(PriceSlate.max_price(save.marketing))
	assert_int(save.sale_price).is_greater(PriceSlate.max_price(save.marketing / 1.19) - 1)


func test_condense_cabbages_and_structured_farm_are_dealt_together_once_the_three_cards_before_them_are_stamped() -> void:
	var trio := ["cash_holding", "big_ideas", "archive_capacity"]
	var save := _all_stamped_but(trio + ["condense", "structured_farm", "negotiation", "rejected_goods", "hand_schedule", "bribery", "war_mode", "world_map", "no_taxes", "sea_lanes", "stars"])
	for last: String in trio:  # Whichever of the three is still missing holds both back.
		var two := save.duplicate(true) as SaveGame
		two.stamped.append_array(trio.filter(func(id: String) -> bool: return id != last))
		assert_array(_next(two.stamped, UpgradeDesk.CARDS.size(), two)).override_failure_message(last).is_equal([last])
	save.stamped.append_array(trio)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["condense", "structured_farm"])
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("archive_capacity"))).is_equal({findings = 2000})
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("condense"))).is_equal({farms = 1, coins = 150000})
	assert_dict(UpgradeDesk.costs(UpgradeDesk.card_data("structured_farm"))).is_equal({farms = 1, findings = 12000})


func test_negotiation_follows_condense_cabbages_and_structured_farm_and_needs_the_first_farm() -> void:
	var save := _all_stamped_but(["condense", "structured_farm", "negotiation", "rejected_goods", "hand_schedule", "bribery", "war_mode", "world_map", "no_taxes", "stars"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["condense", "structured_farm"])
	save.stamped.append("structured_farm")  # Either first: the other one is still needed.
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["condense"])
	save.stamped.append("condense")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["negotiation"])
	var card := UpgradeDesk.card_data("negotiation")
	assert_array(card.needs).contains_exactly_in_any_order(["condense", "structured_farm"])
	assert_dict(UpgradeDesk.costs(card)).is_equal({farms = 1, coins = int(card.price)})


func test_bribery_follows_negotiation_and_needs_four_farms() -> void:
	var save := _all_stamped_but(["bribery", "war_mode", "world_map", "no_taxes", "stars"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["bribery"])
	var card := UpgradeDesk.card_data("bribery")
	var bill := UpgradeDesk.costs(card)
	assert_dict(bill).is_equal({farms = 4, coins = int(card.price)})
	save.coins = int(card.price)
	save.farms_owned = _home_farms(3)
	assert_bool(UpgradeDesk.affords(save, bill)).is_false()
	save.farms_owned = _home_farms(4)
	assert_bool(UpgradeDesk.affords(save, bill)).is_true()


func test_recover_rejected_goods_comes_between_negotiation_and_bribery_and_needs_two_farms() -> void:
	var save := _all_stamped_but(["rejected_goods", "bribery", "war_mode", "world_map", "no_taxes", "sea_lanes", "stars"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["rejected_goods"])
	var card := UpgradeDesk.card_data("rejected_goods")
	assert_dict(UpgradeDesk.costs(card)).is_equal({farms = 2, coins = int(card.price)})
	assert_int(card.price).is_less_equal(SaveGame.new().coin_limit * UpgradeDesk.LIMIT_RAISE)  # The purse the cash card gives holds it.
	save.coins = int(card.price)
	save.farms_owned = _home_farms(1)
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(card))).is_false()
	save.farms_owned = _home_farms(2)
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(card))).is_true()
	# A save that stamped BRIBERY before this card existed has it filed.
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["negotiation", "bribery"])
	UpgradeDesk.migrate(old)
	UpgradeDesk.migrate(old)
	assert_int(Array(old.stamped).count("rejected_goods")).is_equal(1)


func test_the_war_card_comes_after_bribery_and_the_world_map_after_the_war_card() -> void:
	var save := _all_stamped_but(["negotiation", "rejected_goods", "bribery", "war_mode", "world_map", "no_taxes", "stars"])
	save.farms_owned = _home_farms(5)  # Even with the five farms owned.
	for id: String in ["negotiation", "rejected_goods", "bribery", "war_mode", "world_map"]:
		assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal([id])
		save.stamped.append(id)


func test_the_cards_that_open_the_farms_cost_coins_and_no_farm() -> void:
	for id: String in ["negotiation", "bribery"]:
		var card := UpgradeDesk.card_data(id)
		var save := SaveGame.new()
		save.coins = int(card.price) + 7
		save.farms_owned = _home_farms(4)
		var bill := UpgradeDesk.costs(card)
		for paid_in: String in bill:
			UpgradeDesk.pay(save, paid_in, bill[paid_in])
		assert_int(save.coins).is_equal(7)
		assert_int(save.farms_owned.size()).is_equal(4)


func test_an_old_save_that_bought_farms_before_their_cards_existed_has_those_cards_filed() -> void:
	var two := SaveGame.new()
	two.farms_owned = _home_farms(2)
	UpgradeDesk.migrate(two)
	assert_bool(two.stamped.has("negotiation")).is_true()
	assert_bool(two.stamped.has("bribery")).is_false()
	assert_bool(FarmRegister.for_sale(two, &"K-8")).is_true()  # It goes on buying.
	var five := SaveGame.new()
	five.farms_owned = _home_farms(5)
	UpgradeDesk.migrate(five)
	UpgradeDesk.migrate(five)
	assert_int(Array(five.stamped).count("negotiation")).is_equal(1)
	assert_int(Array(five.stamped).count("bribery")).is_equal(1)
	var one := SaveGame.new()
	one.farms_owned = _home_farms(1)
	UpgradeDesk.migrate(one)
	assert_bool(one.stamped.has("negotiation")).is_false()  # The first farm needed no card.


func test_structured_farm_is_dealt_with_condense_and_costs_findings_and_one_farm() -> void:
	var card := UpgradeDesk.card_data("structured_farm")
	assert_str(card.title).is_equal("STRUCTURED FARM")
	assert_array(card.needs).is_equal(UpgradeDesk.card_data("condense").needs)
	assert_array(UpgradeDesk.card_data("negotiation").needs).contains(["structured_farm"])
	assert_dict(UpgradeDesk.costs(card)).is_equal({farms = 1, findings = 12000})
	# Stamping it changes no number: the farm tree reads the stamp (FarmTree.wide).
	var save := SaveGame.new()
	var slots := save.farm_slots
	UpgradeDesk.apply("structured_farm", save)
	assert_int(save.farm_slots).is_equal(slots)
	assert_bool(FarmTree.wide(save)).is_false()
	save.stamped.append("structured_farm")
	assert_bool(FarmTree.wide(save)).is_true()


func test_structured_farm_is_affordable_under_the_findings_limit_the_archive_card_gives() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("archive_capacity", save)
	assert_int(UpgradeDesk.card_data("structured_farm").price).is_less_equal(save.findings_limit)


func test_faster_to_our_farms_is_dealt_with_negotiation_as_a_comfort_paid_in_coins() -> void:
	var card := UpgradeDesk.card_data("farm_shortcut")
	assert_str(card.title).is_equal("FASTER TO OUR FARMS")
	assert_array(card.needs).is_equal(["negotiation"])  # Farms are bought with cabbages: map and farm in turn.
	assert_dict(UpgradeDesk.costs(card)).is_equal({coins = int(card.price)})
	assert_str(MapTable.SHORTCUT_CARD).is_equal("farm_shortcut")
	var save := _all_stamped_but(CHAPTER_3)
	save.stamped.append_array(["market_intelligence", "cash_holding", "big_ideas", "archive_capacity", "map_readout", "condense", "structured_farm"])
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).not_contains(["farm_shortcut"])
	save.stamped.append("negotiation")
	assert_array(_next(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["rejected_goods", "hand_schedule", "farm_shortcut"])
	var stamped := SaveGame.new()
	UpgradeDesk.apply("farm_shortcut", stamped)  # No number changes: the map table and the TV read the stamp.
	assert_int(stamped.coin_limit).is_equal(SaveGame.new().coin_limit)


func test_nothing_waits_on_faster_to_our_farms() -> void:
	assert_array(UpgradeDesk.Events.DRY_LEFT).contains(["farm_shortcut"])
	for other: Dictionary in UpgradeDesk.CARDS:
		assert_bool(other.get("needs", []).has("farm_shortcut")).override_failure_message(other.id + " waits for it").is_false()
	for node: Dictionary in Projector.NODES + FarmTree.NODES:
		assert_bool(node.get("needs", []).has("farm_shortcut")).override_failure_message(node.id + " waits for it").is_false()


## The war line: from the world map on (the home farms 6 to 8 are fought with field associates alone),
## one card after the other beside the first law and the sea lanes, never behind them, each needing
## more farms; stars waits for its end.
func test_the_war_line_starts_with_the_world_map_and_deals_one_card_at_a_time_without_waiting_for_the_first_law() -> void:
	var save := _all_stamped_but(["no_taxes", "sea_lanes", "stars", WAR_EVENT_CARD] + CHAPTER_3_WAR)
	save.farms_owned = _home_farms(UpgradeDesk.Events.HOME_SITES)  # Every home farm: no paper for bigger armies yet.
	for id: String in CHAPTER_3_WAR:  # NO MORE TAXES left on the desk: the war line goes on without it.
		assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).override_failure_message(id).is_equal(["no_taxes", id])
		save.stamped.append(id)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["no_taxes"])
	save.stamped.append("no_taxes")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["sea_lanes"])
	save.stamped.append("sea_lanes")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_empty()  # stars waits for the workforce card.
	var farms := 0
	for id: String in CHAPTER_3_WAR:  # Spread over the farms taken by war, the home ones' tutorials past.
		var card := UpgradeDesk.card_data(id)
		assert_int(card.farms).override_failure_message(id).is_greater(farms)
		assert_array(UpgradeDesk.costs(card).keys()).override_failure_message(id).is_equal(["farms", "coins"])
		farms = card.farms
	assert_int(farms).is_less(UpgradeDesk.Events.FARMS)
	# The route overlay comes first and early (the sixth farm); the first unit card needs every home
	# farm: the tutorials (6 to 8) are fought with field associates alone.
	assert_int(UpgradeDesk.card_data(CHAPTER_3_WAR[0]).farms).is_less_equal(6)
	assert_int(UpgradeDesk.card_data(CHAPTER_3_WAR[1]).farms).is_greater_equal(UpgradeDesk.Events.HOME_SITES)
	assert_array(UpgradeDesk.card_data("stars").needs).contains([CHAPTER_3_WAR[-1], WAR_EVENT_CARD])


## Each unit card can land before the country whose maps teach it (research/war-maps.md, in the
## countries' order: home 8, Veldmark 2, Ostrevia 2, Sulvania 3, Grauland 2, the Lower Provinces 2).
func test_each_unit_card_is_due_before_the_country_that_teaches_it() -> void:
	assert_int(UpgradeDesk.card_data("unit_charge").farms).is_less_equal(8)  # Veldmark's masonry ring.
	assert_int(UpgradeDesk.card_data("unit_senior").farms).is_less_equal(12)  # Sulvania's gun line.
	assert_int(UpgradeDesk.card_data("unit_pult").farms).is_less_equal(15)  # Grauland's shredders, across the sea.
	assert_int(UpgradeDesk.card_data("unit_courier").farms).is_less_equal(19)  # Morrow.
	for id: String in CHAPTER_3_WAR:
		for card: String in ["no_taxes", "sea_lanes"]:
			assert_array(UpgradeDesk.card_data(id).needs).override_failure_message(id + " waits for " + card).not_contains([card])

func test_each_unit_card_hires_the_unit_type_the_war_rules_give_it() -> void:
	for unit: String in WarRules.UNITS:
		var card := UpgradeDesk.card_data(WarRules.UNIT_CARD[unit])
		assert_dict(card).override_failure_message(unit).is_not_empty()
		if unit != "field_associate":
			assert_array(CHAPTER_3_WAR).override_failure_message(unit).contains([card.id])


func test_the_bigger_armies_memo_deals_the_workforce_card() -> void:
	var card := UpgradeDesk.card_data(WAR_EVENT_CARD)
	assert_str(card.title).is_equal("EXPAND THE FIELD WORKFORCE")
	assert_str(card.event).is_equal("bigger_armies_memo")
	assert_dict(UpgradeDesk.costs(card)).is_equal({farms = UpgradeDesk.Events.BIGGER_ARMIES, coins = int(card.price)})
	var save := _all_stamped_but([WAR_EVENT_CARD, "stars"])
	for i in UpgradeDesk.Events.BIGGER_ARMIES - 1:
		save.farms_owned.append("F-%d" % i)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_empty()  # One farm short: no paper, no card.
	save.farms_owned.append("F-last")
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal([WAR_EVENT_CARD])
	save.stamped.append(WAR_EVENT_CARD)
	assert_array(_next(save.stamped, UpgradeDesk.CARDS.size(), save)).is_equal(["stars"])


func test_the_war_cards_are_forms_with_no_effect_of_their_own_the_war_rules_read_the_stamps() -> void:
	for id: String in CHAPTER_3_WAR + [WAR_EVENT_CARD]:
		var save := SaveGame.new()
		var untouched := inst_to_dict(save)
		UpgradeDesk.apply(id, save)
		assert_dict(inst_to_dict(save)).override_failure_message(id).is_equal(untouched)
		assert_bool(UpgradeDesk.card_data(id).get("priority", false)).override_failure_message(id).is_false()


func test_every_war_card_and_its_paper_have_english_and_german_text() -> void:
	var german := _german()
	for id: String in CHAPTER_3_WAR + [WAR_EVENT_CARD]:
		var card := UpgradeDesk.card_data(id)
		for text: String in [card.title, card.body]:
			assert_bool(german.has(text)).override_failure_message("%s: no German for %s" % [id, text]).is_true()
			assert_bool(text.to_lower().contains("unit")).override_failure_message("%s says units" % id).is_false()
	var paper: Dictionary = UpgradeDesk.Events.EVENTS.bigger_armies_memo.report
	assert_bool(german.has(paper.re) and german.has(paper.body)).is_true()


## English key -> German, from the translation table.
func _german() -> Dictionary:
	var out := {}
	var table := FileAccess.open("res://ressources/translations/game.csv", FileAccess.READ)
	while not table.eof_reached():
		var row := table.get_csv_line()
		if row.size() >= 3 and not row[2].is_empty():
			out[row[0]] = row[2]
	return out


func test_esc_closes_the_approved_list_before_the_pause_menu_can_take_it() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["price_slate"])
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(DESK_SCENE.instantiate())
	add_child(desk)
	desk._open_approved()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	desk._input(esc)  # _input runs before any _unhandled_input, so the menu never sees this Esc.
	assert_bool(get_viewport().is_input_handled()).is_true()
	assert_bool(desk.get_node("Approved").visible).is_false()


func test_migrating_drops_figures_of_retired_unit_types_from_the_army_training_and_a_war_under_way() -> void:
	var old := SaveGame.new()
	old.migration = 6
	old.army = {field_associate = 2, compliance_officer = 1}
	old.army_training = [{unit = "compliance_officer", left = 4.0}, {unit = "field_associate", left = 5.0}]
	old.war_pending = {compliance_officer = 2, courier = 1}
	UpgradeDesk.migrate(old)
	assert_dict(old.army).is_equal({field_associate = 2})
	assert_array(old.army_training).is_equal([{unit = "field_associate", left = 5.0}])
	assert_dict(old.war_pending).is_equal({courier = 1})
