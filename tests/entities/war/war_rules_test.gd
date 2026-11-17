extends GdUnitTestSuite


func _save(cards: Array = ["war_mode"], nodes: Array = [], stock := 20000) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(cards)
	save.tree_bought = PackedStringArray(nodes)
	save.stock = stock
	save.storage_cap = maxi(stock, save.storage_cap)
	return save


func test_war_mode_hires_field_associates_only() -> void:
	var save := _save()
	assert_bool(WarRules.unit_unlocked(save, "field_associate")).is_true()
	for unit in ["restructuring_charge", "senior_asset", "pult_crew", "courier"]:
		assert_bool(WarRules.unit_unlocked(save, unit)).is_false()
	assert_bool(WarRules.unit_unlocked(_save([]), "field_associate")).is_false()


func test_each_unit_card_hires_its_unit() -> void:
	var save := _save(["war_mode", "unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	for unit in WarRules.UNITS:
		assert_bool(WarRules.unit_unlocked(save, unit)).is_true()


func test_each_unit_type_waits_for_its_own_card() -> void:
	for unit: String in WarRules.UNITS:
		if unit == "field_associate":
			continue
		var cards := ["war_mode", "unit_charge", "unit_senior", "unit_pult", "unit_courier"]
		cards.erase(WarRules.UNIT_CARD[unit])
		assert_bool(WarRules.unit_unlocked(_save(cards), unit)).override_failure_message(unit).is_false()
		assert_bool(WarRules.unit_unlocked(_save(["war_mode", WarRules.UNIT_CARD[unit]]), unit)).override_failure_message(unit).is_true()
		assert_bool(WarRules.unit_unlocked(_save([WarRules.UNIT_CARD[unit]]), unit)).override_failure_message(unit).is_false()


func test_a_senior_asset_takes_two_places_of_the_army_cap() -> void:
	var save := _save(["war_mode", "unit_senior"], [], 100000)
	assert_int(WarRules.army_cap(save)).is_equal(3)
	assert_bool(WarRules.buy(save, "senior_asset")).is_true()
	assert_int(WarRules.army_size(save)).is_equal(2)
	assert_bool(WarRules.can_buy(save, "senior_asset")).is_false()  # 2 + 2 > 3.
	assert_bool(WarRules.buy(save, "field_associate")).is_true()
	assert_int(WarRules.army_size(save)).is_equal(3)
	WarRules.tick_training(save, 1000.0)
	assert_dict(save.army).is_equal({senior_asset = 1, field_associate = 1})
	assert_int(WarRules.army_size(save)).is_equal(3)  # Ready, it still takes two.


func test_research_raises_only_its_own_units_stats() -> void:
	var all := _save(["war_mode", "unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	for unit: String in WarRules.UNITS:
		all.unit_research = PackedStringArray()
		for node: Dictionary in WarRules.RESEARCH:
			if node.unit == unit:
				all.unit_research.append(node.id)
		for other: String in WarRules.UNITS:
			var changed := WarRules.unit_stats(all, other) != WarRules.unit_stats(_save(), other)
			assert_bool(changed).override_failure_message("%s research, %s stats" % [unit, other]).is_equal(other == unit)


func test_structural_assessment_takes_security_grade_fencing_in_one_blast() -> void:
	var save := _save(["war_mode", "unit_charge"])
	var blast := func() -> float:
		var stats := WarRules.unit_stats(save, "restructuring_charge")
		return float(stats.damage) * float(stats.wall_mult)
	assert_float(blast.call()).is_greater_equal(WarFight.BUILDINGS.wall_stone.hp)
	assert_float(blast.call()).is_less(WarFight.BUILDINGS.wall_steel.hp)
	save.unit_research = PackedStringArray(["rc_wall_0"])  # SITE SURVEY alone: not yet.
	assert_float(blast.call()).is_less(WarFight.BUILDINGS.wall_steel.hp)
	save.unit_research = PackedStringArray(["rc_wall_0", "rc_wall_1"])
	assert_float(blast.call()).is_greater_equal(WarFight.BUILDINGS.wall_steel.hp)


func test_the_army_cap_starts_at_three() -> void:
	assert_int(WarRules.army_cap(_save())).is_equal(3)


func test_bigger_armies_adds_two_to_the_army_cap() -> void:
	assert_int(WarRules.army_cap(_save(["war_mode", "bigger_armies"]))).is_equal(5)


func test_each_war_cap_node_adds_two_more() -> void:
	assert_int(WarRules.army_cap(_save(["war_mode", "bigger_armies"], ["war_cap_1", "war_cap_2", "war_cap_3"]))).is_equal(11)


func test_a_fight_lasts_ninety_seconds_and_war_time_nodes_add_fifteen_each() -> void:
	assert_float(WarRules.fight_seconds(_save())).is_equal(90.0)
	assert_float(WarRules.fight_seconds(_save(["war_mode"], ["war_time_1", "war_time_2"]))).is_equal(120.0)


func test_war_training_nodes_cut_training_by_a_quarter_each() -> void:
	assert_float(WarRules.training_seconds(_save(), "field_associate")).is_equal(15.0)
	assert_float(WarRules.training_seconds(_save(["war_mode"], ["war_training_1"]), "field_associate")).is_equal_approx(11.25, 0.001)
	assert_float(WarRules.training_seconds(_save(["war_mode"], ["war_training_1", "war_training_2", "war_training_3"]), "senior_asset")) \
			.is_equal_approx(45.0 * 0.421875, 0.001)


func test_retreat_saves_nothing_without_the_card() -> void:
	assert_float(WarRules.retreat_share(_save(["war_mode"], ["war_retreat_1"]))).is_equal(0.0)


func test_retreat_saves_thirty_percent_with_the_card() -> void:
	assert_float(WarRules.retreat_share(_save(["war_mode", "retreat"]))).is_equal_approx(0.3, 0.0001)


func test_each_war_retreat_node_saves_ten_percent_more_up_to_eighty() -> void:
	var nodes := ["war_retreat_1", "war_retreat_2"]
	assert_float(WarRules.retreat_share(_save(["war_mode", "retreat"], nodes))).is_equal_approx(0.5, 0.0001)
	nodes = ["war_retreat_1", "war_retreat_2", "war_retreat_3", "war_retreat_4", "war_retreat_5"]
	assert_float(WarRules.retreat_share(_save(["war_mode", "retreat"], nodes))).is_equal_approx(0.8, 0.0001)


func test_tactics_allows_placing_mid_round() -> void:
	assert_bool(WarRules.can_place_mid_round(_save())).is_false()
	assert_bool(WarRules.can_place_mid_round(_save(["war_mode", "tactics"]))).is_true()


func test_buying_a_soldier_takes_its_cabbages_and_queues_its_training() -> void:
	var save := _save()
	assert_bool(WarRules.buy(save, "field_associate")).is_true()
	assert_int(save.stock).is_equal(20000 - WarRules.unit_cabbage_price("field_associate"))
	assert_int(save.army_training.size()).is_equal(1)
	assert_str(save.army_training[0].unit).is_equal("field_associate")
	assert_float(save.army_training[0].left).is_equal(15.0)


func test_a_soldier_cannot_be_bought_past_the_army_cap() -> void:
	var save := _save()
	for i in 3:
		assert_bool(WarRules.buy(save, "field_associate")).is_true()
	assert_bool(WarRules.can_buy(save, "field_associate")).is_false()
	assert_bool(WarRules.buy(save, "field_associate")).is_false()
	assert_int(save.army_training.size()).is_equal(3)


func test_figures_in_training_and_ready_both_count_toward_the_cap() -> void:
	var save := _save()
	save.army = {field_associate = 2}
	WarRules.buy(save, "field_associate")
	assert_int(WarRules.army_size(save)).is_equal(3)
	assert_bool(WarRules.can_buy(save, "field_associate")).is_false()


func test_a_soldier_cannot_be_bought_without_its_cabbages_in_the_store() -> void:
	var price := WarRules.unit_cabbage_price("field_associate")
	var save := _save(["war_mode"], [], price)
	assert_bool(WarRules.can_buy(save, "field_associate", Vector2i(1, 0))).is_false()
	assert_bool(WarRules.buy(save, "field_associate", Vector2i(1, 0))).is_false()
	assert_int(save.stock).is_equal(price)
	assert_bool(WarRules.can_buy(save, "field_associate")).is_true()


func test_a_unit_not_hired_cannot_be_bought() -> void:
	assert_bool(WarRules.can_buy(_save(), "senior_asset")).is_false()


func test_training_finishes_the_front_figure_first() -> void:
	var save := _save(["war_mode", "unit_senior"])
	save.army_training = [{unit = "senior_asset", left = 10.0}, {unit = "field_associate", left = 5.0}]
	WarRules.tick_training(save, 6.0)
	assert_dict(save.army).is_empty()
	assert_float(save.army_training[0].left).is_equal_approx(4.0, 0.0001)
	assert_float(save.army_training[1].left).is_equal(5.0)
	WarRules.tick_training(save, 4.0)
	assert_int(save.army.get("senior_asset", 0)).is_equal(1)
	assert_int(save.army_training.size()).is_equal(1)


func test_leftover_training_time_goes_on_to_the_next_figure() -> void:
	var save := _save()
	save.army_training = [{unit = "field_associate", left = 5.0}, {unit = "field_associate", left = 5.0},
			{unit = "field_associate", left = 5.0}]
	WarRules.tick_training(save, 12.0)
	assert_int(save.army.get("field_associate", 0)).is_equal(2)
	assert_float(save.army_training[0].left).is_equal_approx(3.0, 0.0001)


func test_every_unit_has_a_price_a_training_time_and_stats() -> void:
	for unit in WarRules.UNITS:
		assert_int(WarRules.unit_cabbage_price(unit)).is_greater(0)
		assert_float(WarRules.training_seconds(_save(), unit)).is_greater(0.0)
		var stats := WarRules.unit_stats(_save(), unit)
		for key in ["hp", "damage", "speed", "range", "splash", "target"]:
			assert_bool(stats.has(key)).is_true()


## A unit's research nodes in buying order (each the parent of the next).
func _chain(unit: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parent := ""
	for i in WarRules.RESEARCH.size():
		var next := WarRules.RESEARCH.filter(func(n: Dictionary) -> bool: return n.unit == unit and n.parent == parent)
		if next.is_empty():
			break
		assert_int(next.size()).override_failure_message(unit + " branches").is_equal(1)
		out.append(next[0])
		parent = next[0].id
	return out


func test_every_unit_has_one_research_chain_of_five() -> void:
	for unit in WarRules.UNITS:
		var nodes := WarRules.RESEARCH.filter(func(node: Dictionary) -> bool: return node.unit == unit)
		assert_int(nodes.size()).override_failure_message(unit).is_equal(5)
		assert_int(_chain(unit).size()).override_failure_message(unit).is_equal(5)


func test_each_research_step_raises_its_stat_by_a_tenth_to_under_a_third() -> void:
	var all := _save(["war_mode", "unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	for node in WarRules.RESEARCH:
		var old := float(WarRules.unit_stats(all, node.unit)[node.stat])
		all.unit_research.append(node.id)
		var now := float(WarRules.unit_stats(all, node.unit)[node.stat])
		assert_float(now).override_failure_message(node.id).is_greater_equal(old * 1.1)
		assert_float(now).override_failure_message(node.id).is_less_equal(old * 1.3001)


func test_each_units_research_starts_cheap_and_every_step_costs_more_than_the_one_before() -> void:
	assert_int(int(_chain("field_associate")[0].findings)).is_less_equal(5000)  # Paid from what a player who ignored research holds at war start.
	for unit in WarRules.UNITS:
		var chain := _chain(unit)
		for i in range(1, chain.size()):
			assert_int(int(chain[i].findings)).override_failure_message(chain[i].id).is_greater(int(chain[i - 1].findings))
		# The last step is no wall: at most about forty times the first.
		assert_int(int(chain[-1].findings)).override_failure_message(unit).is_less_equal(int(chain[0].findings) * 40)


func test_a_unit_hired_later_starts_its_research_dearer() -> void:
	var first := 0
	for unit: String in ["field_associate", "restructuring_charge", "senior_asset", "pult_crew", "courier"]:  # The cards' order.
		var price := int(_chain(unit)[0].findings)
		assert_int(price).override_failure_message(unit).is_greater(first)
		first = price


func test_a_split_step_and_its_first_half_together_raise_the_stat_as_much_as_the_old_step() -> void:
	var old := {fa_hp_1 = 1.3, rc_hp_1 = 1.5, rc_wall_1 = 1.5, sa_hp_1 = 1.3, pc_damage_1 = 1.3, cr_speed_1 = 1.25, cr_hp_1 = 1.3}
	assert_int(WarRules.SPLITS.size()).is_equal(old.size())
	for first: String in WarRules.SPLITS:
		var second: String = WarRules.SPLITS[first]
		var above: Array[String] = []  # The second half's ancestors: the first half comes before it.
		var up: String = WarRules.research_node(second).parent
		while up != "":
			above.append(up)
			up = WarRules.research_node(up).parent
		assert_array(above).override_failure_message(second).contains([first])
		var both := float(WarRules.research_node(first).step) * float(WarRules.research_node(second).step)
		assert_float(both).override_failure_message(second).is_greater_equal(float(old[second]))
		assert_float(both).override_failure_message(second).is_less(float(old[second]) * 1.001)


func test_an_old_save_that_bought_a_split_step_gets_its_first_half_filed_once_and_nothing_else() -> void:
	var old := _save(["war_mode", "unit_charge"])
	old.unit_research = PackedStringArray(["fa_hp_1", "fa_damage_1", "rc_wall_1"])
	var hp_before := 150.0 * 1.3
	WarRules.migrate_research(old)
	WarRules.migrate_research(old)
	assert_array(Array(old.unit_research)).contains_exactly_in_any_order(["fa_hp_1", "fa_damage_1", "rc_wall_1", "fa_hp_0", "rc_wall_0"])
	assert_float(float(WarRules.unit_stats(old, "field_associate").hp)).is_equal_approx(hp_before, 0.1)
	assert_float(float(WarRules.unit_stats(old, "restructuring_charge").wall_mult)).is_greater_equal(30.0)  # Security grade still goes in one blast.
	var fresh := _save()
	fresh.unit_research = PackedStringArray(["fa_hp_0"])  # Half bought in play: nothing added.
	WarRules.migrate_research(fresh)
	assert_array(Array(fresh.unit_research)).is_equal(["fa_hp_0"])


func test_research_needs_its_parent_first() -> void:
	var save := _save()
	save.findings = 1000000
	assert_bool(WarRules.buy_research(save, "fa_hp_1")).is_false()
	assert_bool(WarRules.buy_research(save, "fa_hp_0")).is_true()
	assert_bool(WarRules.buy_research(save, "fa_hp_1")).is_true()


func test_research_is_paid_in_findings() -> void:
	var save := _save()
	var price: int = WarRules.research_node("fa_hp_0").findings
	save.findings = price - 1
	assert_bool(WarRules.buy_research(save, "fa_hp_0")).is_false()
	save.findings = price
	assert_bool(WarRules.buy_research(save, "fa_hp_0")).is_true()
	assert_int(save.findings).is_equal(0)
	assert_bool(WarRules.buy_research(save, "fa_hp_0")).is_false()  # Once only.


func test_research_for_a_unit_not_hired_cannot_be_bought() -> void:
	var save := _save()
	save.findings = 1000000
	assert_bool(WarRules.buy_research(save, "sa_hp_0")).is_false()


## A war's cabbages are its soldiers: one figure always fits the biggest store with a full mat of
## condensed cabbages out (the mat's cabbages can't pay).
func test_a_soldiers_cabbages_fit_the_biggest_store_with_a_full_mat_of_condensed_cabbages_out() -> void:
	var biggest := SaveGame.new().storage_cap
	var condensed := 2  # The card CONDENSE CABBAGES.
	for node: Dictionary in Projector.NODES:
		biggest += int(node.get("add", {}).get("storage_cap", 0))
		condensed += int(node.get("add", {}).get("condense", 0))
	assert_int(WarRules.unit_cabbage_price("field_associate") + Projector.MAT_MAX * condensed).is_less_equal(biggest)


func test_dismissing_takes_a_ready_figure_first_frees_its_place_and_pays_nothing_back() -> void:
	var save := _save()
	save.army = {field_associate = 2}
	assert_bool(WarRules.buy(save, "field_associate")).is_true()
	var stock := save.stock
	assert_bool(WarRules.dismiss(save, "field_associate")).is_true()
	assert_int(int(save.army.field_associate)).is_equal(1)
	assert_int(save.army_training.size()).is_equal(1)  # The trainee stays.
	assert_int(save.stock).is_equal(stock)
	assert_int(WarRules.army_size(save)).is_equal(2)


func test_with_none_ready_dismissing_withdraws_the_newest_trainee_of_that_unit() -> void:
	var save := _save(["war_mode", "unit_courier"], [], 50000)
	for unit: String in ["field_associate", "courier", "field_associate"]:
		assert_bool(WarRules.buy(save, unit)).is_true()
	assert_bool(WarRules.dismiss(save, "field_associate")).is_true()
	assert_array(save.army_training.map(func(e: Dictionary) -> String: return e.unit)).is_equal(["field_associate", "courier"])


func test_with_nobody_of_that_unit_there_is_nothing_to_dismiss() -> void:
	var save := _save()
	save.army = {field_associate = 0}
	assert_bool(WarRules.can_dismiss(save, "field_associate")).is_false()
	assert_bool(WarRules.dismiss(save, "field_associate")).is_false()
	assert_bool(WarRules.can_dismiss(save, "courier")).is_false()
