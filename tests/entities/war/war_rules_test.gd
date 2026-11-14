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
	for unit in ["compliance_officer", "senior_asset", "pult_crew"]:
		assert_bool(WarRules.unit_unlocked(save, unit)).is_false()
	assert_bool(WarRules.unit_unlocked(_save([]), "field_associate")).is_false()


func test_each_unit_card_hires_its_unit() -> void:
	var save := _save(["war_mode", "unit_compliance", "unit_senior", "unit_pult"])
	for unit in WarRules.UNITS:
		assert_bool(WarRules.unit_unlocked(save, unit)).is_true()


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


func test_every_unit_has_a_small_research_tree() -> void:
	for unit in WarRules.UNITS:
		var nodes := WarRules.RESEARCH.filter(func(node: Dictionary) -> bool: return node.unit == unit)
		assert_int(nodes.size()).is_between(3, 4)
		for node: Dictionary in nodes:
			if node.parent != "":
				assert_str(WarRules.research_node(node.parent).unit).is_equal(unit)


func test_each_research_step_raises_its_stat_by_at_least_a_quarter() -> void:
	var all := _save(["war_mode", "unit_compliance", "unit_senior", "unit_pult"])
	for node in WarRules.RESEARCH:
		var old := float(WarRules.unit_stats(all, node.unit)[node.stat])
		all.unit_research.append(node.id)
		assert_float(float(WarRules.unit_stats(all, node.unit)[node.stat])).is_greater_equal(old * 1.25)


func test_research_needs_its_parent_first() -> void:
	var save := _save()
	save.findings = 1000000
	assert_bool(WarRules.buy_research(save, "fa_damage_1")).is_false()
	assert_bool(WarRules.buy_research(save, "fa_hp_1")).is_true()
	assert_bool(WarRules.buy_research(save, "fa_damage_1")).is_true()


func test_research_is_paid_in_findings() -> void:
	var save := _save()
	var price: int = WarRules.research_node("fa_hp_1").findings
	save.findings = price - 1
	assert_bool(WarRules.buy_research(save, "fa_hp_1")).is_false()
	save.findings = price
	assert_bool(WarRules.buy_research(save, "fa_hp_1")).is_true()
	assert_int(save.findings).is_equal(0)
	assert_bool(WarRules.buy_research(save, "fa_hp_1")).is_false()  # Once only.


func test_research_for_a_unit_not_hired_cannot_be_bought() -> void:
	var save := _save()
	save.findings = 1000000
	assert_bool(WarRules.buy_research(save, "sa_hp_1")).is_false()


## A war's cabbages are its soldiers: one figure always fits the biggest store with a full mat of
## condensed cabbages out (the mat's cabbages can't pay).
func test_a_soldiers_cabbages_fit_the_biggest_store_with_a_full_mat_of_condensed_cabbages_out() -> void:
	var biggest := SaveGame.new().storage_cap
	var condensed := 2  # The card CONDENSE CABBAGES.
	for node: Dictionary in Projector.NODES:
		biggest += int(node.get("add", {}).get("storage_cap", 0))
		condensed += int(node.get("add", {}).get("condense", 0))
	assert_int(WarRules.unit_cabbage_price("field_associate") + Projector.MAT_MAX * condensed).is_less_equal(biggest)
