extends GdUnitTestSuite

const DESK_SCENE := preload("res://entities/upgrade_desk/upgrade_desk.tscn")

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
	for start: Array in [[], BEFORE_RADIO]:
		var stamped := PackedStringArray(start)
		while not UpgradeDesk.next_cards(stamped, UpgradeDesk.OFFERED, _warned()).is_empty():
			stamped.append(UpgradeDesk.next_cards(stamped, UpgradeDesk.OFFERED, _warned())[0])

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
		assert_array(["coins", "findings"]).contains([card.get("currency", "coins")])
	assert_str(UpgradeDesk.card_data("junior_associate").get("currency", "coins")).is_equal("coins")
	assert_str(UpgradeDesk.card_data("window_targets").get("currency")).is_equal("findings")
	assert_int(UpgradeDesk.card_data("projector").price).is_equal(75)


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


func test_buying_the_family_farm_after_the_shock_starts_the_wholesalers_squeeze_and_its_ease_back() -> void:
	var save := SaveGame.new()
	save.supply_shock = true
	UpgradeDesk.apply("family_farm", save)
	assert_float(save.squeeze_left).is_equal(SupplyConsole.SQUEEZE_TIME + SupplyConsole.EASE_TIME)


func test_stamping_every_card_once_adds_up_to_the_listed_effects_and_nothing_else() -> void:
	var save := SaveGame.new()
	var interval := save.associate_interval
	for card: Dictionary in UpgradeDesk.CARDS:
		UpgradeDesk.apply(card.id, save)

	assert_bool(save.slate_unlocked).is_true()
	assert_int(save.desk_capacity).is_equal(3)  # desk_space and the mat allowance: one each
	assert_int(save.pack_size).is_equal(SaveGame.new().pack_size)
	assert_int(save.hands).is_equal(1)
	assert_float(save.marketing).is_equal_approx(1.2 * 1.5, 0.0001)
	assert_float(save.associate_interval).is_equal_approx(interval * 0.5, 0.0001)
	assert_int(save.research_hands).is_equal(1)
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
