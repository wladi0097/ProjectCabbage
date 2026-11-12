extends GdUnitTestSuite

const Events := preload("res://globalScripts/game_events.gd")
const Report := preload("res://entities/boss_report/boss_report.gd")

var _demo_was: bool


func before_test() -> void:
	_demo_was = ProjectSettings.get_setting("game/demo", false)
	ProjectSettings.set_setting("game/demo", false)


func after_test() -> void:
	ProjectSettings.set_setting("game/demo", _demo_was)


func test_every_event_starts_on_a_saved_flag_or_a_real_desk_card() -> void:
	for id: String in Events.EVENTS:
		var event: Dictionary = Events.EVENTS[id]
		assert_bool(event.has("flag") or event.has("card")).override_failure_message(id).is_true()
		if event.has("flag"):
			assert_bool(event.flag in SaveGame.new()).override_failure_message(id).is_true()
		if event.has("card"):
			assert_dict(UpgradeDesk.card_data(event.card)).override_failure_message(id).is_not_empty()


func test_a_flag_event_starts_with_its_flag() -> void:
	var save := SaveGame.new()
	assert_bool(Events.due("mood_drift", save)).is_false()
	save.slate_unlocked = true
	assert_bool(Events.due("mood_drift", save)).is_true()


func test_an_old_save_that_stamped_the_retired_bin_card_keeps_its_rotten_units() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["catch_combo", "rotten_bin"])
	assert_bool(Events.due("rotten_units", save)).is_true()
	save.reports = PackedStringArray(["welcome", "rotten_units"])
	assert_array(Report.due(save)).not_contains(["rotten_units"])


func test_a_stamped_event_waits_for_the_stamp_not_the_offer() -> void:
	var save := _all_stamped_but(["quality_assurance", "family_farm"])
	save.tray_unlocked = true
	assert_bool(Events.due("window_split", save)).is_false()
	save.stamped.append("quality_assurance")
	assert_bool(Events.due("window_split", save)).is_true()


func test_the_warning_waits_until_the_tray_has_nothing_left_but_the_desk_lamp() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp", "research_sentiment"])
	save.tray_unlocked = true
	assert_bool(Events.tray_dry(save)).is_false()
	assert_bool(Events.warning_due(save)).is_false()
	save.stamped.append("research_sentiment")
	assert_bool(Events.tray_dry(save)).is_true()
	assert_bool(Events.warning_due(save)).is_true()


func test_a_tray_with_every_card_stamped_counts_as_run_dry() -> void:
	assert_bool(Events.tray_dry(_all_stamped_but(["family_farm"]))).is_true()


func test_a_fresh_desk_has_not_run_dry() -> void:
	assert_bool(Events.tray_dry(SaveGame.new())).is_false()


func test_the_warning_starts_only_once() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp"])
	save.tray_unlocked = true
	save.supply_warning = true
	assert_bool(Events.warning_due(save)).is_false()


func test_the_warning_deals_the_farm_card_first_but_leaves_crate_prices_alone() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp"])
	save.tray_unlocked = true
	save.marketing = 5.0
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)).not_contains("family_farm")
	UpgradeDesk.start_warning(save)
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["family_farm", "golden_lamp"])
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED)).not_contains("family_farm")
	assert_float(SupplyConsole.crate_floor(save)).is_equal(0.0)


func test_prices_explode_after_the_set_number_of_units_sold_since_the_warning() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp"])
	save.tray_unlocked = true
	save.sold = 500
	UpgradeDesk.start_warning(save)
	save.sold = 500 + Events.shock_after() - 1
	assert_bool(Events.shock_due(save)).is_false()
	save.sold = 500 + Events.shock_after()
	assert_bool(Events.shock_due(save)).is_true()
	UpgradeDesk.start_shock(save)
	assert_bool(Events.shock_due(save)).is_false()


func test_no_shock_without_the_warning_however_many_units_are_sold() -> void:
	var save := SaveGame.new()
	save.sold = 100000
	assert_bool(Events.shock_due(save)).is_false()


func test_prices_explode_forty_units_after_the_family_farm_is_stamped_if_that_comes_first() -> void:
	var save := SaveGame.new()
	save.sold = 500
	UpgradeDesk.start_warning(save)
	save.sold = 520
	UpgradeDesk.apply("family_farm", save)
	save.stamped.append("family_farm")
	save.sold = 520 + Events.SHOCK_AFTER_FARM - 1
	assert_bool(Events.shock_due(save)).is_false()
	save.sold = 520 + Events.SHOCK_AFTER_FARM
	assert_bool(Events.shock_due(save)).is_true()


func test_a_farm_bought_late_never_holds_back_the_shock_the_warning_already_counts_down() -> void:
	var save := SaveGame.new()
	UpgradeDesk.start_warning(save)
	save.sold = Events.shock_after() - 10
	UpgradeDesk.apply("family_farm", save)
	save.sold = Events.shock_after()
	assert_bool(Events.shock_due(save)).is_true()


func test_an_old_save_with_the_farm_and_no_shock_yet_counts_the_farm_clock_from_its_load() -> void:
	var save := SaveGame.new()
	UpgradeDesk.start_warning(save)
	save.stamped.append("family_farm")
	save.sold = 100
	UpgradeDesk.migrate(save)
	assert_int(save.farm_sold).is_equal(100)
	save.sold = 100 + Events.SHOCK_AFTER_FARM
	assert_bool(Events.shock_due(save)).is_true()


func test_a_full_tray_holds_the_warning_back_and_the_farm_card_comes_first_after_a_stamp() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp", "mat_allowance", "stats_ledger"])
	save.tray_unlocked = true
	assert_bool(Events.warning_ready(save)).is_true()
	assert_bool(Events.warning_due(save)).is_false()
	UpgradeDesk.start_warning(save)
	assert_str(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)[0]).is_equal("family_farm")


func test_the_demo_never_holds_its_warning_back_for_a_full_tray() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.sold = Events.Demo.WARNING_SOLD
	save.stamped = PackedStringArray(["price_slate", "radio"])
	assert_bool(Events.warning_due(save)).is_true()


func test_skipping_the_optional_memos_and_the_ledger_never_blocks_stage_two() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp", "mat_allowance", "spoilage_memo", "lab_priority", "stats_ledger"])
	assert_bool(Events.tray_dry(save)).is_true()


func test_no_card_another_card_needs_counts_as_optional_for_the_dry_tray() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		for need: String in card.get("needs", []):
			assert_array(Events.DRY_LEFT).override_failure_message(card.id).not_contains([need])


func test_a_farm_bought_before_the_shock_starts_the_squeeze_at_the_shock() -> void:
	var save := SaveGame.new()
	UpgradeDesk.start_warning(save)
	save.stamped.append("family_farm")
	UpgradeDesk.apply("family_farm", save)
	assert_bool(SupplyConsole.squeezing(save)).is_false()
	UpgradeDesk.start_shock(save)
	assert_bool(SupplyConsole.squeezing(save)).is_true()


func test_a_farm_bought_after_the_shock_starts_the_squeeze_at_once() -> void:
	var save := SaveGame.new()
	UpgradeDesk.start_warning(save)
	UpgradeDesk.start_shock(save)
	assert_bool(SupplyConsole.squeezing(save)).is_false()
	save.stamped.append("family_farm")
	UpgradeDesk.apply("family_farm", save)
	assert_bool(SupplyConsole.squeezing(save)).is_true()


func test_an_old_save_past_the_shock_files_the_warning_unread_and_keeps_its_farm_card() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp"])
	save.reports = PackedStringArray(["welcome", "supply_shock"])
	save.supply_shock = true
	UpgradeDesk.migrate(save)
	assert_bool(save.supply_warning).is_true()
	assert_array(Report.due(save)).not_contains(["supply_warning"])
	assert_str(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)[0]).is_equal("family_farm")


func test_an_old_save_before_the_shock_gets_the_warning_once_its_tray_runs_dry() -> void:
	var save := _all_stamped_but(["family_farm", "golden_lamp", "research_sentiment"])
	save.tray_unlocked = true
	save.sold = 2000
	UpgradeDesk.migrate(save)
	assert_bool(Events.warning_due(save)).is_false()
	assert_bool(Events.shock_due(save)).is_false()
	save.stamped.append("research_sentiment")
	assert_bool(Events.warning_due(save)).is_true()


func test_crates_cost_nothing_extra_before_the_shock_and_the_shock_share_after() -> void:
	assert_float(SupplyConsole.crate_share(false, false)).is_equal(0.0)
	assert_float(SupplyConsole.crate_share(true, false)).is_equal(SupplyConsole.SHOCK_SHARE)


func test_the_farm_squeeze_never_falls_back_to_the_shock_share() -> void:
	assert_float(SupplyConsole.crate_share(true, true)).is_equal(SupplyConsole.SQUEEZE_SHARE)
	assert_float(SupplyConsole.SQUEEZE_SHARE).is_greater(1.0)


func test_a_shocked_unit_still_sells_at_a_profit_until_the_farm_squeeze_makes_it_a_loss() -> void:
	var save := SaveGame.new()
	assert_float(SupplyConsole.crate_floor(save)).is_equal(0.0)
	save.supply_shock = true
	save.marketing = 5.0
	# Full-sale price at marketing 5 is $15.
	assert_float(SupplyConsole.crate_floor(save)).is_equal_approx(SupplyConsole.SHOCK_SHARE * 15.0, 0.0001)
	assert_float(SupplyConsole.crate_floor(save)).is_less(15.0)
	save.stamped.append("family_farm")
	UpgradeDesk.apply("family_farm", save)
	assert_float(SupplyConsole.crate_floor(save)).is_greater(15.0)


func test_a_pack_costs_its_units_at_the_price_factor() -> void:
	assert_int(SupplyConsole.pack_price(1.0, 10, 1.0, 9.0)).is_equal(90)
	assert_int(SupplyConsole.pack_price(1.0, 10)).is_equal(11)


func test_a_new_game_starts_with_the_welcome_report() -> void:
	assert_array(Report.due(SaveGame.new())).is_equal(["welcome"])


func test_reports_come_for_started_events_in_order_and_each_only_once() -> void:
	var save := SaveGame.new()
	save.reports.append("welcome")
	save.slate_unlocked = true
	save.buy_unlocked = true
	assert_array(Report.due(save)).is_equal(["mood_drift", "pack_pressure"])
	save.reports.append("mood_drift")
	assert_array(Report.due(save)).is_equal(["pack_pressure"])


func test_every_event_has_a_report_with_a_headline_and_a_body() -> void:
	assert_str(Report.report("welcome").re).is_equal(Report.WELCOME.re)
	assert_dict(Report.report("supply_shock")).is_equal(Events.EVENTS.supply_shock.report)
	for id: String in Events.EVENTS:
		var report: Dictionary = Events.EVENTS[id].get("report", {})
		assert_str(report.get("re", "")).override_failure_message(id).is_not_empty()
		assert_str(report.get("body", "")).override_failure_message(id).is_not_empty()


func test_signing_a_report_takes_ink_as_long_as_the_stroke() -> void:
	var stroke := PackedVector2Array([Vector2.ZERO, Vector2(30, 40), Vector2(30, 0)])
	assert_float(Report.ink_of(stroke)).is_equal_approx(90.0, 0.0001)


func test_the_pen_cursor_has_its_nib_at_the_bottom_left() -> void:
	var pen := Report.pen_image()
	assert_vector(pen.get_size()).is_equal(Vector2i(32, 32))
	assert_float(pen.get_pixel(1, 30).a).is_greater(0.0)
	assert_float(pen.get_pixel(30, 1).a).is_equal(0.0)


func test_the_demo_ends_after_three_minutes_of_farming() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var farm := SaveGame.new()
	farm.reports = PackedStringArray(["welcome"])
	farm.farm_seconds = Events.Demo.END_AFTER - 1.0
	assert_array(Report.due(farm)).not_contains("demo_end")
	farm.farm_seconds = Events.Demo.END_AFTER
	assert_array(Report.due(farm)).contains("demo_end")
	assert_dict(Report.report("demo_end")).is_equal(Report.DEMO_END)


func test_the_demo_locks_only_the_dear_projector_upgrades() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := SaveGame.new()
	var dear := _dear_node()
	assert_str(Projector.locked_by(dear, save)).is_equal("demo")
	assert_bool(Projector.can_hold(dear, save)).is_false()
	assert_str(Projector.locked_by("slogan_1", save)).is_empty()


func test_the_demo_warns_after_its_units_sold_and_shocks_sooner_with_a_cheaper_farm() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := SaveGame.new()
	save.tray_unlocked = true
	save.sold = Events.Demo.WARNING_SOLD - 1
	assert_bool(Events.warning_ready(save)).is_false()
	save.sold = Events.Demo.WARNING_SOLD
	assert_bool(Events.warning_ready(save)).is_true()
	assert_int(Events.shock_after()).is_equal(Events.Demo.SHOCK_AFTER)
	assert_int(UpgradeDesk.card_data("family_farm").price).is_equal(Events.Demo.CARD_PRICES.family_farm)


func test_the_full_game_has_its_own_stage_two_and_no_demo_end_or_lock() -> void:
	var farm := SaveGame.new()
	farm.reports = PackedStringArray(["welcome"])
	farm.farm_seconds = Events.Demo.END_AFTER
	farm.tray_unlocked = true
	farm.sold = Events.Demo.WARNING_SOLD
	assert_bool(Events.warning_ready(farm)).is_false()
	assert_int(Events.shock_after()).is_equal(Events.SHOCK_AFTER)
	assert_int(UpgradeDesk.card_data("family_farm").price).is_equal(1600)
	assert_array(Report.due(farm)).not_contains("demo_end")
	assert_str(Projector.locked_by(_dear_node(), farm)).is_not_equal("demo")


func _all_stamped_but(ids: Array) -> SaveGame:
	var save := SaveGame.new()
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in ids:
			save.stamped.append(card.id)
	return save


func _dear_node() -> String:
	for node: Dictionary in Projector.NODES:
		if node.get("price", 0) > Events.Demo.NODE_PRICE_CAP:
			return node.id
	return ""


func test_the_invest_in_growth_event_starts_only_once_chapter_twos_last_card_is_stamped() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm", "standing_seed_order"])
	assert_bool(Events.due("invest_in_growth", save)).is_false()
	save.stamped.append("consolidation")
	assert_bool(Events.due("invest_in_growth", save)).is_true()
	# Its paper is held back for the alpha (BossReport.HELD, ui/sub/alpha_end) but kept for chapter 3.
	assert_str(Report.report("invest_in_growth").re).is_equal("WE SHOULD INVEST IN GROWTH")


func test_stamping_mechanisation_promotes_the_player_to_manager_and_not_before() -> void:
	var save := _all_stamped_but(["mechanisation", "standing_seed_order", "own_sales", "own_research", "consolidation"])
	assert_bool(Events.due("promotion", save)).is_false()
	save.stamped.append("mechanisation")
	assert_bool(Events.due("promotion", save)).is_true()
	assert_str(Report.report("promotion").re).is_equal("YOU ARE NOW A MANAGER")


func test_an_old_save_that_stamped_mechanisation_gets_the_promotion_paper_once() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["mechanisation"])
	save.reports = PackedStringArray(["welcome"])
	assert_array(Report.due(save)).contains(["promotion"])
	save.reports.append("promotion")
	assert_array(Report.due(save)).not_contains(["promotion"])
