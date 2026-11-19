extends GdUnitTestSuite

const WorldSheet := preload("res://entities/map_table/world_register.gd")
const War := preload("res://entities/map_table/war_sheet.gd")
const Clock := preload("res://entities/map_table/props/unrest_clock.gd")


func _save(card := true) -> SaveGame:
	var save := SaveGame.new()
	save.created = 1234
	save.coin_limit = 2000000000
	save.findings_limit = 20000000
	save.storage_cap = 5000000
	if card:
		save.stamped = PackedStringArray([BanditCamp.CARD])
	return save


## `minutes` of output at these rates a minute, sampled as the game does.
func _earn(save: SaveGame, minutes: int, coins: int, findings: int, cabbages: int) -> void:
	for m in minutes:
		for s in 60:
			save.coins_earned += floori(coins / 60.0)
			save.findings_earned += floori(findings / 60.0)
			save.tractor_harvested += floori(cabbages / 60.0)
			BanditCamp.sample(save, 1.0)


func test_no_camp_comes_before_the_card() -> void:
	var save := _save(false)
	BanditCamp.tick(save, 5000.0)
	assert_bool(BanditCamp.is_open(save)).is_false()
	assert_float(BanditCamp.countdown(save)).is_equal(-1.0)


func test_the_first_camp_comes_the_moment_the_card_is_stamped() -> void:
	var save := _save()
	BanditCamp.tick(save, 0.016)
	assert_bool(BanditCamp.is_open(save)).is_true()
	assert_float(BanditCamp.countdown(save)).is_equal_approx(BanditCamp.EVERY, 0.1)


func test_a_camp_left_standing_for_ten_minutes_is_gone_and_a_new_one_takes_its_place() -> void:
	var save := _save()
	BanditCamp.tick(save, 0.016)
	var first := save.bandit_camp
	BanditCamp.tick(save, BanditCamp.EVERY - 1.0)
	assert_int(save.bandit_camp).is_equal(first)
	BanditCamp.tick(save, 2.0)
	assert_int(save.bandit_camp).is_not_equal(first)
	assert_bool(BanditCamp.is_open(save)).is_true()  # One at a time: never a backlog.
	assert_int(save.camps_spawned).is_equal(2)


func test_after_a_camp_is_recovered_the_map_stays_empty_until_the_clock_runs_out() -> void:
	var save := _save()
	BanditCamp.tick(save, 0.016)
	BanditCamp.tick(save, 100.0)
	BanditCamp.win(save)
	assert_bool(BanditCamp.is_open(save)).is_false()
	BanditCamp.tick(save, BanditCamp.EVERY - 101.0)
	assert_bool(BanditCamp.is_open(save)).is_false()
	BanditCamp.tick(save, 2.0)
	assert_bool(BanditCamp.is_open(save)).is_true()


func test_the_clock_waits_for_a_camp_fight_under_way_before_the_camp_goes() -> void:
	var save := _save()
	BanditCamp.tick(save, 0.016)
	var camp := save.bandit_camp
	BanditCamp.tick(save, BanditCamp.EVERY + 30.0, true)
	assert_int(save.bandit_camp).is_equal(camp)
	BanditCamp.tick(save, 0.016)
	assert_int(save.bandit_camp).is_not_equal(camp)


func test_only_a_win_raises_the_level_never_a_loss_or_a_camp_gone() -> void:
	var save := _save()
	BanditCamp.tick(save, 0.016)
	assert_int(BanditCamp.level(save)).is_equal(1)
	BanditCamp.lose(save)
	BanditCamp.tick(save, BanditCamp.EVERY + 1.0)  # Gone, and a new one.
	assert_int(BanditCamp.level(save)).is_equal(1)
	BanditCamp.win(save)
	assert_int(BanditCamp.level(save)).is_equal(2)


func test_the_level_stops_at_the_maximum() -> void:
	var save := _save()
	save.camps_recovered = BanditCamp.MAX_LEVEL + 5
	assert_int(BanditCamp.level(save)).is_equal(BanditCamp.MAX_LEVEL)


func test_a_lost_camp_stands_on_the_same_and_can_be_tried_again() -> void:
	var save := _save()
	save.coins = 1000000
	save.army = {field_associate = 3}
	BanditCamp.tick(save, 0.016)
	var was := BanditCamp.current(save)
	BanditCamp.lose(save)
	assert_dict(BanditCamp.current(save)).is_equal(was)
	assert_bool(BanditCamp.declare(save, {field_associate = 2})).is_true()


func test_every_level_makes_each_maps_defences_stronger_from_its_low_to_its_top() -> void:
	for source: String in BanditCamp.SOURCES:
		assert_float(BanditCamp.buff_at(source, 1)).is_equal_approx(BanditCamp.LOW[source], 0.0001)
		assert_float(BanditCamp.buff_at(source, BanditCamp.MAX_LEVEL)).is_equal_approx(BanditCamp.TOP[source], 0.0001)
		for at in range(2, BanditCamp.MAX_LEVEL + 1):
			assert_float(BanditCamp.buff_at(source, at)).is_greater(BanditCamp.buff_at(source, at - 1))
		assert_float(BanditCamp.buff_at(source, BanditCamp.MAX_LEVEL + 3)).is_equal(BanditCamp.buff_at(source, BanditCamp.MAX_LEVEL))


func test_even_the_first_camp_is_stronger_than_the_hardest_chapter_3_war() -> void:
	for camp in range(1, 40):
		assert_float(BanditCamp.plan(camp * 7919, 1).k).is_greater(3.42)


func test_the_same_seed_and_level_always_give_the_same_camp() -> void:
	assert_dict(BanditCamp.plan(424242, 3)).is_equal(BanditCamp.plan(424242, 3))


func test_every_camp_map_is_a_valid_fighting_map_clear_of_the_title_block() -> void:
	var save := _save()
	var mirrored := 0
	for n in 24:
		save.bandit_camp = (n * 104729) | 1
		var map: WarMap = auto_free(BanditCamp.map_for(save))
		var layout := map.layout()
		mirrored += int(BanditCamp.current(save).mirror)
		assert_array(Array(WarFight.problems(layout))).is_empty()
		assert_bool(layout.any(func(p: Dictionary) -> bool: return p.kind == "farmhouse")).is_true()
		assert_bool(layout.any(func(p: Dictionary) -> bool: return p.kind == "zone")).is_true()
		for piece: Dictionary in layout:
			var rect := Rect2i(piece.cell, piece.size)
			assert_bool(Rect2i(Vector2i.ZERO, map.grid_size).encloses(rect)).is_true()
			assert_bool(rect.intersects(War.TITLE_CELLS)).override_failure_message("%s on the title block" % piece.kind).is_false()
	assert_int(mirrored).is_greater(0)


func test_the_reward_is_five_minutes_of_the_last_five_minutes_output() -> void:
	var save := _save()
	_earn(save, 3, 6000000, 600000, 60000)  # Older output drops out of the window.
	_earn(save, 5, 60000000, 1200000, 120000)
	var r := BanditCamp.reward(save)
	assert_int(r.coins).is_between(int(60000000 * BanditCamp.REWARD_MINUTES * 0.97), int(60000000 * BanditCamp.REWARD_MINUTES * 1.01))
	assert_int(r.findings).is_between(int(1200000 * BanditCamp.REWARD_MINUTES * 0.97), int(1200000 * BanditCamp.REWARD_MINUTES * 1.01))
	assert_int(r.stock).is_between(int(120000 * BanditCamp.REWARD_MINUTES * 0.97), int(120000 * BanditCamp.REWARD_MINUTES * 1.01))
	assert_int(save.output_samples.size()).is_equal(BanditCamp.WINDOW)


func test_a_win_pays_only_what_fits_under_each_limit() -> void:
	var save := _save()
	save.coins = save.coin_limit - 1000
	save.findings = 0
	save.stock = save.storage_cap - 10
	var paid := BanditCamp.pay(save, {coins = 50000, findings = 500, stock = 300})
	assert_dict(paid).is_equal({coins = 1000, findings = 500, stock = 10})
	assert_int(save.coins).is_equal(save.coin_limit)
	assert_int(save.stock).is_equal(save.storage_cap)


func test_the_operation_costs_its_fee_and_an_abort_gives_it_back() -> void:
	var save := _save()
	_earn(save, 5, 40000000, 0, 0)
	BanditCamp.tick(save, 0.016)
	save.coins = save.bandit_fee + 5
	save.army = {field_associate = 4}
	assert_int(save.bandit_fee).is_between(int(40000000 * BanditCamp.FEE_MINUTES * 0.97), int(40000000 * BanditCamp.FEE_MINUTES * 1.01))
	assert_bool(BanditCamp.declare(save, {field_associate = 4})).is_true()
	assert_int(save.coins).is_equal(5)
	assert_dict(save.war_pending).is_equal({field_associate = 4})
	BanditCamp.refund(save)
	assert_int(save.coins).is_equal(save.bandit_fee + 5)


func test_resurvey_needs_its_depot_node_and_its_coins() -> void:
	var save := _save()
	_earn(save, 5, 30000000, 0, 0)
	BanditCamp.tick(save, 0.016)
	save.coins = 10000000000
	assert_bool(BanditCamp.resurvey(save)).is_false()
	save.tree_bought = PackedStringArray([BanditCamp.RESURVEY_NODE])
	save.coins = BanditCamp.resurvey_price(save) - 1
	assert_bool(BanditCamp.resurvey(save)).is_false()


func test_a_resurvey_keeps_the_level_draws_a_new_camp_and_starts_the_clock_over() -> void:
	var save := _save()
	_earn(save, 5, 30000000, 0, 0)
	save.camps_recovered = 3
	save.tree_bought = PackedStringArray([BanditCamp.RESURVEY_NODE])
	BanditCamp.tick(save, 0.016)
	BanditCamp.tick(save, 400.0)
	var was := save.bandit_camp
	var price := BanditCamp.resurvey_price(save)
	assert_int(price).is_equal(roundi(BanditCamp.rates(save).coins * BanditCamp.RESURVEY_MINUTES))
	save.coins = price + 7
	assert_bool(BanditCamp.resurvey(save)).is_true()
	assert_int(save.coins).is_equal(7)
	assert_int(save.bandit_camp).is_not_equal(was)
	assert_int(BanditCamp.level(save)).is_equal(4)
	assert_float(BanditCamp.countdown(save)).is_equal_approx(BanditCamp.EVERY, 0.01)


func test_the_camp_card_is_optional_and_the_star_programme_does_not_need_it() -> void:
	assert_array(UpgradeDesk.Events.DRY_LEFT).contains([BanditCamp.CARD])
	assert_array(UpgradeDesk.card_data("star_programme").needs).not_contains([BanditCamp.CARD])
	assert_array(UpgradeDesk.card_data(BanditCamp.CARD).needs).is_equal(["half_life"])
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_array(card.get("needs", [])).override_failure_message(card.id).not_contains([BanditCamp.CARD])


func test_the_camp_hint_names_its_level_and_never_its_country() -> void:
	var save := _save()
	save.camps_recovered = 4
	for n in 20:
		save.bandit_camp = (n * 7907) | 1
		var hint := WorldSheet.camp_hint(save)
		assert_str(hint).contains("5")
		for country: StringName in WorldSheet.COUNTRIES:
			assert_str(hint.to_lower()).not_contains(String(country).replace("_", " "))


func test_the_clock_counts_minutes_and_seconds() -> void:
	assert_str(Clock.clock_text(600.0)).is_equal("10:00")
	assert_str(Clock.clock_text(61.2)).is_equal("01:02")
	assert_str(Clock.clock_text(-1.0)).is_equal("--:--")


func test_camp_fights_are_stronger_and_chapter_3_wars_are_not_buffed() -> void:
	var save := _save()
	assert_float(BanditCamp.buff(save)).is_equal(1.0)  # No camp: nothing buffed.
	BanditCamp.tick(save, 0.016)
	assert_float(BanditCamp.buff(save)).is_greater(1.0)


## Whether `army` wins on map `source` with its defences `k` times as strong and `level`'s research,
## set down by the calculator (BattleSim.plan_for) in any of the map's zone choices.
func _wins(source: String, army: Dictionary, k: float, level: String) -> bool:
	var map: WarMap = auto_free(load(WarMap.path_of(source)).instantiate())
	var layout := map.layout()
	for use: Array in BattleSim.zone_choices(layout):
		if BattleSim.trial(layout, map.grid_size, army, use, {research = BattleSim.research_for(level), k = k}).won:
			return true
	return false


func test_the_first_level_is_won_by_a_chapter_3_army_under_its_cap() -> void:
	# tools/_camp_ladder.gd's cheapest winner on morrow-2 with chapter 3's research and cap 11.
	var army := {pult_crew = 4, senior_asset = 2}
	assert_int(BattleSim.army_cost(army).places).is_less_equal(BattleSim.cap_for("full"))
	assert_bool(_wins("morrow-2", army, BanditCamp.buff_at("morrow-2", 1), "full")).is_true()


func test_the_top_level_is_won_only_with_every_war_upgrade_and_lost_without_them() -> void:
	# The calculator's winner on morrow-2 at the strongest buff it still takes with everything (cap 15).
	var army := {senior_asset = 2, field_associate = 5, pult_crew = 4}
	var top := BanditCamp.buff_at("morrow-2", BanditCamp.MAX_LEVEL)
	assert_int(BattleSim.army_cost(army).places).is_less_equal(BattleSim.cap_for("nuclear"))
	assert_bool(_wins("morrow-2", army, top, "nuclear")).is_true()
	assert_bool(_wins("morrow-2", army, top, "full")).is_false()
	assert_bool(_wins("morrow-2", army, top * 1.15, "nuclear")).is_false()  # Barely: a little more and it falls.
