extends GdUnitTestSuite

const SALES_NODES: Array[String] = ["combo_window", "combo_cap",
		"combo_step", "bin_mouth", "bin_rebate", "bin_rebate_2", "bin_rebate_3", "bin_rebate_4", "bin_rebate_5",
		"hands_bin", "target_size", "target_every", "target_shower"]

var _demo: Variant
var _locale: String


func before_test() -> void:
	_demo = ProjectSettings.get_setting("game/demo", false)
	ProjectSettings.set_setting("game/demo", false)
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	ProjectSettings.set_setting("game/demo", _demo)
	TranslationServer.set_locale(_locale)


func _save(cards: Array, coins := 0) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(cards)
	save.coins = coins
	return save


func _upgrades() -> Array:
	return Projector.NODES.filter(func(node: Dictionary) -> bool: return not node.get("dept", false))


func test_the_projector_waits_for_its_desk_card() -> void:
	assert_bool(Projector.unlocked(SaveGame.new())).is_false()
	assert_bool(Projector.unlocked(_save(["projector"]))).is_true()


func test_every_node_has_a_unique_id_and_a_known_parent() -> void:
	var ids := {}
	for node: Dictionary in Projector.NODES:
		assert_bool(ids.has(node.id)).override_failure_message("duplicate id %s" % node.id).is_false()
		ids[node.id] = true
		if node.parent != "":
			assert_dict(Projector.node_data(node.parent)).override_failure_message("%s has an unknown parent" % node.id).is_not_empty()


func test_every_number_a_node_changes_is_tracked_by_the_save() -> void:
	var save := SaveGame.new()
	for node: Dictionary in Projector.NODES:
		for stat: String in node.get("mul", {}).keys() + node.get("add", {}).keys():
			assert_bool(save.get(stat) != null).override_failure_message("%s changes %s, which the save doesn't have" % [node.id, stat]).is_true()


func test_every_sales_event_tree_node_changes_a_real_save_number() -> void:
	for id in SALES_NODES:
		var save := SaveGame.new()
		var node := Projector.node_data(id)
		var was := {}
		for stat: String in node.get("mul", {}).keys() + node.get("add", {}).keys():
			was[stat] = save.get(stat)
		Projector.apply(id, save)

		assert_dict(was).override_failure_message("node " + id).is_not_empty()
		for stat: String in was:
			assert_bool(save.get(stat) != was[stat]).override_failure_message("node %s stat %s" % [id, stat]).is_true()


func test_disposal_rebate_tiers_pay_2_3_5_8_12_dollars_each_a_felt_step() -> void:
	var save := SaveGame.new()
	var tiers: Array[int] = []
	for id in ["bin_rebate", "bin_rebate_2", "bin_rebate_3", "bin_rebate_4", "bin_rebate_5"]:
		Projector.apply(id, save)
		tiers.append(save.bin_coins)

	assert_array(tiers).is_equal([2, 3, 5, 8, 12])
	for i in range(1, tiers.size()):
		assert_float(float(tiers[i]) / tiers[i - 1]).is_greater_equal(1.25)


func test_a_node_is_found_by_its_id_and_an_unknown_id_finds_nothing() -> void:
	assert_str(Projector.node_data("slogan_2").parent).is_equal("slogan_1")
	assert_dict(Projector.node_data("no_such_node")).is_empty()
	for node: Dictionary in Projector.NODES:
		assert_bool(Projector.node_data(node.id) == node).override_failure_message(node.id).is_true()


## The lamps' category is the one spoke off the hub that is not a department (2026-11-16: its own
## category, not buried in one).
const HUB_SPOKE: Array[String] = ["lamp_mult", "lab_lamp_mult"]


func test_every_upgrade_hangs_under_one_department_or_the_lamps_own_spoke_and_only_those_sit_on_the_hub() -> void:
	for node: Dictionary in Projector.NODES:
		var top := node
		while top.parent != "":
			top = Projector.node_data(top.parent)
		assert_bool(top.get("dept", false) or top.id in HUB_SPOKE).override_failure_message("%s hangs under no department" % node.id).is_true()
		assert_bool(node.parent == "").override_failure_message(node.id).is_equal(node.get("dept", false) or node.id in HUB_SPOKE)


func test_departments_are_free_and_every_upgrade_costs_coins() -> void:
	for node: Dictionary in Projector.NODES:
		if node.get("dept", false):
			assert_int(node.price).override_failure_message(node.id).is_equal(0)
		else:
			assert_int(node.price).override_failure_message(node.id).is_greater(0)


func test_marketing_slogans_stay_greyed_until_the_street_posters_are_stamped() -> void:
	var save := _save(["projector"])
	assert_bool(Projector.is_reachable("slogan_1", save)).is_false()
	assert_array(Projector.requirement("slogan_1", save)).is_equal(["REQUIRES DESK CARD:", "STREET POSTER CAMPAIGN"])
	save.stamped.append("street_posters")
	assert_bool(Projector.is_reachable("slogan_1", save)).is_true()
	assert_bool(Projector.is_reachable("slogan_2", save)).is_false()


func test_manual_handling_is_open_from_the_start() -> void:
	var save := _save(["projector"])
	assert_bool(Projector.is_reachable("dept_manual", save)).is_true()
	assert_bool(Projector.is_open("dept_manual", save)).is_true()


func test_a_department_opens_with_its_card_and_is_never_bought() -> void:
	var save := _save(["projector", "street_posters"], 1000)
	assert_bool(Projector.is_open("dept_marketing", save)).is_true()
	assert_bool(Projector.can_hold("dept_marketing", save)).is_false()
	assert_bool(Projector.buy("dept_marketing", save)).is_false()
	assert_int(save.coins).is_equal(1000)
	assert_array(save.tree_bought).is_empty()


func test_the_qa_department_waits_for_its_research_then_opens_faster_analysis() -> void:
	var save := _save(["projector", "quality_assurance"])
	assert_bool(Projector.is_open("dept_qa", save)).is_false()
	assert_bool(Projector.is_reachable("qa_time", save)).is_false()
	assert_array(Projector.requirement("qa_time", save)).is_equal(["LOCKED", "RESEARCH: INSPECTION METHODOLOGY", UpgradeTree.FORM_NOT_YET])
	save.stamped.append("research_inspection")
	assert_bool(Projector.is_open("dept_qa", save)).is_true()
	assert_bool(Projector.can_hold("qa_time", save)).is_true()


func test_the_lab_grows_one_bench_at_a_time_to_five_each_waiting_for_the_one_before() -> void:
	var save := _save(["projector", "quality_assurance", "research_inspection"], 100000000)
	assert_bool(Projector.buy("qa_time", save)).is_true()
	assert_bool(Projector.buy("qa_slot_4", save)).is_false()
	for bench: int in [2, 3, 4, 5]:
		assert_bool(Projector.buy("qa_slot_%d" % bench, save)).is_true()
		assert_int(save.qa_slots).is_equal(bench)
	assert_bool(Projector.NODES.any(func(node: Dictionary) -> bool: return node.id == "qa_slot_6")).is_false()


func test_each_further_bench_costs_more_than_the_last_and_the_fifth_is_the_dearest() -> void:
	var prices: Array = ["qa_slot_2", "qa_slot_3", "qa_slot_4", "qa_slot_5"].map(
			func(id: String) -> int: return Projector.node_data(id).price)
	assert_array(prices).is_equal([700, 1800, 4500, 12000])
	for i in range(1, prices.size()):
		assert_int(prices[i]).is_greater(prices[i - 1])


func test_a_node_locked_by_a_form_names_the_form_the_player_must_approve() -> void:
	var save := _save(["projector", "quality_assurance"])
	save.tray_unlocked = true
	assert_array(Projector.requirement("qa_time", save)).is_equal(
			["LOCKED", "RESEARCH: INSPECTION METHODOLOGY", "Needs the form %s, which has not reached your desk yet."])
	save.offered = PackedStringArray(["research_inspection"])  # Now in the tray.
	assert_array(Projector.requirement("qa_time", save)).is_equal(
			["LOCKED", "RESEARCH: INSPECTION METHODOLOGY", "Approve the form %s on your desk."])


func test_an_unlocked_node_shows_its_price_as_before() -> void:
	var save := _save(["projector", "quality_assurance", "research_inspection"])
	assert_array(Projector.requirement("qa_time", save)).is_empty()  # No lock line: the popup draws COST.
	assert_int(Projector.price_of("qa_time", save)).is_greater(0)


func test_the_associate_upgrades_wait_for_the_junior_associate_card() -> void:
	var save := _save(["projector", "street_posters"])
	assert_bool(Projector.is_reachable("associate_1", save)).is_false()
	assert_bool(Projector.is_reachable("hire_associate_2", save)).is_false()
	save.stamped.append("junior_associate")
	assert_bool(Projector.is_reachable("associate_1", save)).is_true()
	assert_bool(Projector.is_reachable("hire_associate_2", save)).is_true()


func test_an_unaffordable_upgrade_is_not_bought_and_costs_nothing() -> void:
	var save := _save(["projector", "street_posters"], 10)
	assert_bool(Projector.buy("slogan_1", save)).is_false()
	assert_int(save.coins).is_equal(10)
	assert_array(save.tree_bought).is_empty()


func test_exactly_the_price_in_coins_is_enough_to_buy() -> void:
	var price: int = Projector.node_data("slogan_1").price
	var save := _save(["projector", "street_posters"], price)
	assert_bool(Projector.buy("slogan_1", save)).is_true()
	assert_int(save.coins).is_equal(0)


func test_buying_slogan_i_pays_its_price_raises_marketing_and_opens_slogan_ii() -> void:
	var save := _save(["projector", "street_posters"], 1000)
	assert_bool(Projector.buy("slogan_1", save)).is_true()
	assert_int(save.coins).is_equal(1000 - Projector.node_data("slogan_1").price)
	assert_float(save.marketing).is_equal_approx(1.25, 0.0001)
	assert_array(save.tree_bought).contains("slogan_1")
	assert_bool(Projector.is_reachable("slogan_2", save)).is_true()


func test_an_upgrade_is_bought_only_once() -> void:
	var save := _save(["projector", "street_posters"], 1000)
	Projector.buy("slogan_1", save)
	var coins := save.coins
	assert_bool(Projector.can_hold("slogan_1", save)).is_false()
	assert_bool(Projector.buy("slogan_1", save)).is_false()
	assert_int(save.coins).is_equal(coins)
	assert_float(save.marketing).is_equal_approx(1.25, 0.0001)


func test_upgrades_change_the_numbers_they_name() -> void:
	var save := SaveGame.new()
	var base := SaveGame.new()
	for id: String in ["pack_1", "associate_1", "qa_time", "qa_findings", "double_findings", "conveyor_1"]:
		Projector.apply(id, save)
	assert_int(save.pack_size).is_equal(base.pack_size + 3)
	assert_float(save.associate_speed).is_equal_approx(base.associate_speed * 1.5, 0.0001)
	assert_float(save.qa_time).is_equal_approx(base.qa_time * 0.75, 0.0001)
	assert_int(save.findings_per_cabbage).is_equal((base.findings_per_cabbage + 1) * 2)
	assert_float(save.dispense_interval).is_equal_approx(base.dispense_interval * 0.5, 0.0001)
	assert_int(save.desk_capacity).is_equal(base.desk_capacity)


func test_a_hire_upgrade_adds_one_hand() -> void:
	var save := SaveGame.new()
	save.hands = 1
	Projector.apply("hire_associate_2", save)
	assert_int(save.hands).is_equal(2)


func test_research_and_mini_upgrades_reach_their_stated_values() -> void:
	var lab := SaveGame.new()
	for id: String in ["research_mult_1", "research_mult_2", "research_mult_3", "research_mult_4", "research_chance_1",
			"research_chance_2", "research_chance_3", "lab_hand_2", "lab_hand_3", "mini_rate_1", "mini_rate_2", "mini_rate_3",
			"mini_value_1", "mini_value_2", "tube_speed_1"]:
		Projector.apply(id, lab)
	assert_float(lab.research_mult).is_equal_approx(20.0, 0.0001)
	assert_float(lab.research_chance).is_equal_approx(0.25, 0.0001)
	assert_int(lab.research_hands).is_equal(2)
	assert_float(lab.mini_value).is_equal_approx(0.5, 0.0001)
	assert_float(lab.mini_every).is_equal_approx(20.0 * 0.7 * 0.7 * 0.7 * 0.8, 0.0001)
	assert_float(lab.tube_speed).is_equal_approx(1.5, 0.0001)


func test_each_research_multiplier_step_lifts_findings_by_at_least_a_quarter() -> void:
	var steps := [3.0]
	for n in 4:
		steps.append(steps[-1] + Projector.node_data("research_mult_%d" % (n + 1)).add.research_mult)
	for n in 4:
		assert_float(steps[n + 1]).override_failure_message("×%.0f to ×%.0f is under +25%%" % [steps[n], steps[n + 1]]) \
				.is_greater_equal(steps[n] * 1.25)


func test_research_lab_and_mini_upgrades_wait_for_their_desk_cards() -> void:
	var save := _save(["projector", "quality_assurance", "research_inspection"])
	for id: String in ["research_mult_1", "mini_rate_1", "lab_hand_2"]:
		assert_bool(Projector.is_reachable(id, save)).override_failure_message(id).is_false()
	save.stamped.append_array(["research_cabbage", "research_assistant", "mini_cabbages"])
	for id: String in ["research_mult_1", "mini_rate_1", "lab_hand_2"]:
		assert_bool(Projector.can_hold(id, save)).override_failure_message(id).is_true()


func test_each_hire_adds_one_hand_and_costs_over_thirty_percent_more_than_the_last() -> void:
	var save := _save(["projector", "junior_associate", "performance_review", "big_ideas", "cash_holding"], 10000000)
	var last := 0
	for n in range(2, 11):
		var id := "hire_associate_%d" % n
		var hands := save.hands
		var price: int = Projector.node_data(id).price
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		assert_int(save.hands).override_failure_message(id).is_equal(hands + 1)
		assert_float(float(price)).override_failure_message(id).is_greater(last * 1.3)
		last = price


func test_every_research_gate_is_a_research_card_on_the_desk() -> void:
	for node: Dictionary in Projector.NODES:
		var card: String = node.get("research", "")
		if card != "":
			assert_bool(UpgradeDesk.card_data(card).get("research", false)) \
					.override_failure_message("%s waits for %s, which is no research card" % [node.id, card]).is_true()


func test_every_research_card_opens_something_on_the_tree() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.get("research", false):
			assert_bool(Projector.NODES.any(func(node: Dictionary) -> bool: return node.get("research", "") == card.id)) \
					.override_failure_message("research card %s opens nothing" % card.id).is_true()


func _gated() -> SaveGame:
	var save := _save(["projector", "junior_associate"], 100000)
	save.tree_bought = PackedStringArray(["hire_associate_2", "hire_associate_3", "hire_associate_4", "pack_1"])
	return save


func test_a_research_gated_upgrade_shows_locked_and_hides_its_children() -> void:
	var save := _gated()
	assert_bool(Projector.is_reachable("hire_associate_5", save)).is_true()
	assert_str(Projector.locked_by("hire_associate_5", save)).is_equal("performance_review")
	assert_bool(Projector.can_hold("hire_associate_5", save)).is_false()
	assert_bool(Projector.buy("hire_associate_5", save)).is_false()
	assert_bool(Projector.is_reachable("hire_associate_6", save)).is_false()
	assert_str(Projector.locked_by("conveyor_1", save)).is_equal("research_materials")
	assert_str(Projector.locked_by("pack_1", save)).is_empty()


func test_stamping_the_research_unlocks_the_gated_upgrade() -> void:
	var save := _gated()
	save.stamped.append("performance_review")
	assert_str(Projector.locked_by("hire_associate_5", save)).is_empty()
	assert_bool(Projector.buy("hire_associate_5", save)).is_true()


func test_a_bought_upgrade_is_never_locked_by_research() -> void:
	var save := SaveGame.new()
	save.tree_bought = PackedStringArray(["conveyor_1"])
	assert_str(Projector.locked_by("conveyor_1", save)).is_empty()


func test_the_popup_names_what_an_upgrade_waits_for() -> void:
	var save := _gated()
	assert_array(Projector.requirement("hire_associate_6", save)).is_equal(["REQUIRES:", "HIRE ASSOCIATE V"])
	assert_str(Projector.requirement("hire_associate_5", save)[0]).is_equal("LOCKED")
	assert_str(Projector.requirement("manager_time", save)[0]).is_equal("REQUIRES DESK CARD:")
	assert_str(Projector.requirement("conveyor_1", save)[0]).is_equal("LOCKED")  # Its research card: a form.
	assert_array(Projector.requirement("discount_1", save)).is_empty()
	assert_bool(Projector.can_hold("discount_1", save)).is_true()


func test_everything_bought_fills_the_mat_to_ten_and_hires_two_hands_more_than_the_desk_shows() -> void:
	var full := SaveGame.new()
	UpgradeDesk.apply("desk_space", full)
	UpgradeDesk.apply("junior_associate", full)
	UpgradeDesk.apply("coin_collector", full)
	UpgradeDesk.apply("mat_allowance", full)
	for node: Dictionary in Projector.NODES:
		Projector.apply(node.id, full)
	assert_int(full.desk_capacity).is_equal(10)
	assert_int(full.hands).is_equal(Associate.MAX_VISIBLE + 2)  # DEPARTMENTAL HEADCOUNT's two speed up the visible ten.
	assert_int(full.hand_trip).is_equal(2)
	assert_int(full.condense).is_equal(91)  # CONDENSE II to V, VII to XII on a save without the cards' own steps (2, 12).
	assert_int(full.research_condense).is_equal(8)
	assert_int(full.golden_condense).is_equal(6)
	assert_float(full.restock_delay).is_equal_approx(SaveGame.new().restock_delay / 4.0, 0.0001)  # CONVEYOR II and III.
	assert_float(full.hand_output).is_equal_approx(2.25, 0.0001)
	assert_int(full.qa_slots).is_equal(5)
	assert_int(full.vacuums).is_equal(5)  # Chapter 3's FOURTH and FIFTH UNIT.
	assert_int(full.auto_reserve).is_equal(10)


func test_the_mat_holds_two_until_the_allowance_card_which_adds_a_third_and_opens_the_chain_at_the_fourth() -> void:
	var save := _save(["projector", "junior_associate", "coin_collector", "quality_assurance", "research_materials"], 100000000)
	UpgradeDesk.apply("desk_space", save)
	for node: Dictionary in Projector.NODES:
		if not node.id.begins_with("mat_"):
			Projector.apply(node.id, save)
	assert_int(save.desk_capacity).is_equal(2)
	assert_bool(Projector.is_shown("mat_4", save)).is_false()
	assert_bool(Projector.buy("mat_4", save)).is_false()
	save.stamped.append("mat_allowance")
	UpgradeDesk.apply("mat_allowance", save)
	assert_int(save.desk_capacity).is_equal(3)
	assert_bool(Projector.buy("mat_5", save)).is_false()
	assert_bool(Projector.buy("mat_4", save)).is_true()
	assert_int(save.desk_capacity).is_equal(4)


func test_the_mat_allowance_card_costs_about_three_thousand_coins() -> void:
	var card := UpgradeDesk.card_data("mat_allowance")
	assert_str(card.get("currency", "coins")).is_equal("coins")
	assert_int(card.price).is_equal(3000)


## The mat chain's ids in order: "mat_<the size the mat reaches>".
func _mat_chain() -> Array[String]:
	var ids: Array[String] = []
	for node: Dictionary in Projector.NODES:
		if node.id.begins_with("mat_"):
			ids.append(node.id)
	return ids


func test_the_mat_chain_is_one_node_per_unit_to_the_tenth_and_stops_there() -> void:
	var sizes: Array[int] = []
	for id in _mat_chain():
		sizes.append(id.trim_prefix("mat_").to_int())
	assert_array(sizes).is_equal([4, 5, 6, 7, 8, 9, 10])
	var last := ""
	for id in _mat_chain():
		var node := Projector.node_data(id)
		assert_str(node.parent).override_failure_message(id).is_equal("dept_manual" if last == "" else last)
		assert_dict(node.add).override_failure_message(id).is_equal({desk_capacity = 1})
		last = id
	assert_int(Projector.MAT_MAX).is_equal(10)


func test_no_projector_step_raises_the_mat_past_ten() -> void:
	for node: Dictionary in Projector.NODES:
		assert_int(int(node.get("add", {}).get("desk_capacity", 0))).override_failure_message(node.id).is_less_equal(1)
		assert_bool(node.get("mul", {}).has("desk_capacity")).override_failure_message(node.id).is_false()
	# Everything bought, twice over, on a mat that is already full.
	var save := _save(["projector", "mat_allowance"])
	save.desk_capacity = Projector.MAT_MAX
	for round_ in 2:
		for node: Dictionary in Projector.NODES:
			Projector.apply(node.id, save)
			assert_int(save.desk_capacity).override_failure_message(node.id).is_less_equal(Projector.MAT_MAX)
	assert_int(save.desk_capacity).is_equal(10)


func test_conveyor_ii_and_iii_each_also_halve_the_chutes_wait_after_a_sale() -> void:
	var save := SaveGame.new()
	var base := SaveGame.new()
	Projector.apply("conveyor_1", save)
	assert_float(save.restock_delay).is_equal(base.restock_delay)
	Projector.apply("conveyor_2", save)
	assert_float(save.restock_delay).is_equal_approx(base.restock_delay * 0.5, 0.0001)
	Projector.apply("conveyor_3", save)
	assert_float(save.restock_delay).is_equal_approx(base.restock_delay * 0.25, 0.0001)
	assert_float(save.dispense_interval).is_equal_approx(base.dispense_interval * 0.5 * 0.67 * 0.67, 0.0001)


func test_conveyor_ii_costs_less_than_the_mats_sixth_cabbage_so_the_cabbages_past_it_are_felt() -> void:
	assert_int(Projector.node_data("conveyor_2").price).is_less(Projector.node_data("mat_6").price)


func test_each_mat_step_costs_more_than_the_last_starting_at_the_old_fourth_unit_price() -> void:
	var save := _save(["projector", "mat_allowance", "big_ideas", "cash_holding"], 1000000000)
	save.desk_capacity = 3
	var last := 0
	for id in _mat_chain():
		var price := Projector.price_of(id, save)
		assert_float(float(price)).override_failure_message("%s at $%d" % [id, price]).is_greater(last * 1.3)
		assert_bool(Projector.buy(id, save)).is_true()
		assert_int(save.desk_capacity).is_equal(id.trim_prefix("mat_").to_int())
		last = price
	assert_int(Projector.price_of("mat_4", save)).is_equal(2100)
	assert_int(Projector.price_of("mat_10", save)).is_equal(15800)


func test_a_bought_mat_step_is_never_bought_again() -> void:
	var save := _save(["projector", "mat_allowance"], 1000000000)
	save.desk_capacity = 3
	assert_bool(Projector.buy("mat_4", save)).is_true()
	var coins := save.coins
	assert_bool(Projector.can_hold("mat_4", save)).is_false()
	assert_bool(Projector.buy("mat_4", save)).is_false()
	assert_int(save.coins).is_equal(coins)
	assert_int(save.desk_capacity).is_equal(4)


## The storage chain in order, from the department down.
func _storage_chain() -> Array[String]:
	var out: Array[String] = []
	for node: Dictionary in Projector.NODES:
		if node.get("add", {}).has("storage_cap"):
			out.append(node.id)
	return out


func test_storage_is_its_own_branch_off_manual_handling_with_its_own_heading_not_under_procurement() -> void:
	var chain := _storage_chain()
	assert_str(Projector.node_data(chain[0]).parent).is_equal("dept_manual")
	for i in range(1, chain.size()):
		assert_str(Projector.node_data(chain[i]).parent).override_failure_message(chain[i]).is_equal(chain[i - 1])
	var heading := UpgradeTree.theme_of(Projector.THEMES, chain[0])
	assert_int(heading).is_greater_equal(0)
	assert_str(Projector.THEMES[heading][0]).is_equal("STORAGE")


func test_storage_grows_from_20_to_999999_in_many_steps_each_at_least_a_quarter_more_room() -> void:
	var save := _save(["projector", "offsite_storage", "big_ideas", "cash_holding"], 1000000000)
	var caps := [save.storage_cap]
	var prices := [0]
	for id: String in _storage_chain().filter(func(id: String) -> bool: return not id.begins_with("lead_lining_")):  # Chapter 4's go on past it.
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		caps.append(save.storage_cap)
		prices.append(Projector.price_of(id, save))
	assert_int(caps.size()).is_greater_equal(16)
	assert_int(caps[1]).is_equal(25)
	assert_int(caps[-1]).is_equal(999999)
	for i in range(1, caps.size()):
		assert_float(float(caps[i]) / caps[i - 1]).override_failure_message("%d to %d" % [caps[i - 1], caps[i]]).is_greater_equal(1.25)
		assert_int(prices[i]).is_greater(prices[i - 1])


func test_the_old_storage_ids_keep_their_room_so_old_saves_keep_their_meaning() -> void:
	var caps := {storage_1 = 75, storage_2 = 200, storage_3 = 500, storage_4 = 1500, storage_5 = 4000, storage_6 = 9999}
	for id: String in caps:
		assert_int(Projector.cap_at(id)).override_failure_message(id).is_equal(caps[id])


func test_each_storage_step_states_its_new_room_and_the_old() -> void:
	for id: String in _storage_chain():
		var node := Projector.node_data(id)
		var old_cap := Projector.cap_at(node.parent)
		var line := "Storage holds %s cabbages instead of %s." % [Num.text(Projector.cap_at(id)), Num.text(old_cap)]
		assert_str(node.body).override_failure_message(id).ends_with(line)
		assert_str(node.body.get_slice("\n", 0)).override_failure_message(id).is_not_equal(line)  # A flavour line first.


func test_storage_past_the_stock_room_shows_with_a_padlock_until_the_off_site_storage_card() -> void:
	var save := _save(["projector", "family_farm"], 1000000)
	save.tree_bought = PackedStringArray(["stock_25", "stock_32", "stock_40", "stock_50", "storage_1"])
	var next: String = _storage_chain()[_storage_chain().find("storage_1") + 1]
	assert_bool(Projector.is_shown(next, save)).is_true()
	assert_bool(Projector.is_reachable(next, save)).is_true()
	assert_str(Projector.locked_by(next, save)).is_equal("offsite_storage")
	assert_bool(Projector.can_hold(next, save)).is_false()
	assert_bool(Projector.buy(next, save)).is_false()
	assert_array(Projector.requirement(next, save)).is_equal(["LOCKED", "REQUISITION OFF-SITE STORAGE", UpgradeTree.FORM_NOT_YET])
	for id: String in ["storage_2", "stock_2000"]:  # The rest of chapter 2's chain shows too, greyed.
		assert_bool(Projector.is_shown(id, save)).override_failure_message(id).is_true()
		assert_bool(Projector.is_reachable(id, save)).override_failure_message(id).is_false()
	save.stamped.append("offsite_storage")
	assert_str(Projector.locked_by(next, save)).is_empty()
	assert_bool(Projector.buy(next, save)).is_true()


func test_the_off_site_lock_sits_between_the_stock_room_and_the_basement_annex() -> void:
	var chain := _storage_chain()
	var locked := chain.filter(func(id: String) -> bool: return Projector.node_data(id).has("lock"))
	assert_array(locked).has_size(1)
	assert_str(Projector.node_data(locked[0]).lock).is_equal("offsite_storage")
	assert_int(chain.find(locked[0])).is_greater(chain.find("storage_1"))
	assert_int(chain.find(locked[0])).is_less_equal(chain.find("storage_2"))
	assert_str(UpgradeDesk.card_data("offsite_storage").tree).is_equal("storage_1")
	assert_bool(UpgradeDesk.card_data("golden_cabbage").has("tree")).is_false()  # It waits for a card, not a node.


func test_container_orders_sit_under_procurement_locked_until_storage_holds_a_53_unit_pack_and_more() -> void:
	var pack_2 := Projector.node_data("pack_2")
	assert_str(pack_2.parent).is_equal("pack_1")
	var pack: int = SaveGame.new().pack_size + Projector.node_data("pack_1").add.pack_size + pack_2.add.pack_size
	assert_int(Projector.cap_at(pack_2.after)).is_greater_equal(pack + 10)  # Room above the safety-stock reserve.
	assert_int(Projector.cap_at(Projector.node_data(pack_2.after).parent)).is_less(pack + 10)  # Not a step sooner.
	var save := _save(["projector"], 100000)
	save.tree_bought = PackedStringArray(["pack_1"])
	assert_bool(Projector.is_reachable("pack_2", save)).is_true()
	assert_str(Projector.locked_by("pack_2", save)).is_equal(pack_2.after)
	assert_bool(Projector.buy("pack_2", save)).is_false()
	assert_array(Projector.requirement("pack_2", save)).is_equal(["REQUIRES:", Projector.node_data(pack_2.after).title])
	save.tree_bought.append(pack_2.after)
	assert_array(Projector.requirement("pack_2", save)).is_empty()  # Open now: its popup shows the price.
	assert_bool(Projector.buy("pack_2", save)).is_true()
	assert_array(Projector.requirement("pack_2", save)).is_empty()


func test_an_old_save_with_container_orders_gets_the_stock_room_and_the_steps_before_it_once() -> void:
	var save := _save(["projector"])
	save.tree_bought = PackedStringArray(["pack_1", "pack_2"])
	Projector.migrate_storage(save)
	Projector.migrate_storage(save)
	assert_int(save.tree_bought.count("storage_1")).is_equal(1)
	assert_int(save.tree_bought.count("stock_25")).is_equal(1)
	assert_int(save.storage_cap).is_equal(75)


func test_an_old_save_holding_a_storage_step_counts_every_earlier_step_bought_and_keeps_its_room() -> void:
	var save := _save(["projector", "offsite_storage"], 1000000000)
	save.tree_bought = PackedStringArray(["pack_1", "storage_1", "storage_2", "storage_3"])
	save.storage_cap = 500
	Projector.migrate_storage(save)
	var chain := _storage_chain()
	for id: String in chain.slice(0, chain.find("storage_3") + 1):
		assert_bool(Projector.is_bought(id, save)).override_failure_message(id).is_true()
	assert_bool(Projector.is_bought(chain[chain.find("storage_3") + 1], save)).is_false()
	assert_int(save.storage_cap).is_equal(500)
	var next: String = chain[chain.find("storage_3") + 1]
	assert_bool(Projector.buy(next, save)).is_true()
	assert_int(save.storage_cap).is_equal(Projector.cap_at(next))


func test_an_old_save_holding_a_dropped_storage_step_gets_the_next_kept_step_and_never_less_room() -> void:
	for dropped: String in Projector.DROPPED_STORAGE:
		var save := _save(["projector", "offsite_storage"])
		save.tree_bought = PackedStringArray(["storage_1", "storage_2", dropped])
		save.storage_cap = {stock_250 = 250, stock_320 = 320, stock_400 = 400, stock_750 = 750}[dropped]
		var had := save.storage_cap
		Projector.migrate_storage(save)
		Projector.migrate_storage(save)
		var kept: String = Projector.DROPPED_STORAGE[dropped]
		assert_array(save.tree_bought).override_failure_message(dropped).not_contains([dropped])
		assert_int(save.tree_bought.count(kept)).override_failure_message(dropped).is_equal(1)
		assert_int(save.storage_cap).override_failure_message(dropped).is_equal(Projector.cap_at(kept))
		assert_int(save.storage_cap).override_failure_message(dropped).is_greater_equal(had)


func test_storage_goes_from_200_to_1000_in_two_big_steps() -> void:
	var chain := _storage_chain()
	var annex := chain.find("storage_2")
	assert_array(chain.slice(annex, annex + 3)).is_equal(["storage_2", "storage_3", "stock_1000"])
	assert_int(Projector.cap_at("stock_1000")).is_equal(1000)
	for id: String in Projector.DROPPED_STORAGE:
		assert_dict(Projector.node_data(id)).override_failure_message(id).is_empty()


func test_a_save_without_storage_keeps_its_twenty() -> void:
	var save := SaveGame.new()
	Projector.migrate_storage(save)
	assert_int(save.storage_cap).is_equal(20)
	assert_bool(save.tree_bought.is_empty()).is_true()


func test_an_old_save_counts_its_mat_units_as_bought_chain_nodes_and_pays_for_the_next_from_there() -> void:
	var save := _save(["projector", "mat_allowance"], 1000000000)
	save.desk_capacity = 8
	Projector.migrate_mat(save)
	assert_int(save.desk_capacity).is_equal(8)
	for unit in range(4, 9):
		assert_bool(Projector.is_bought("mat_%d" % unit, save)).override_failure_message("unit %d" % unit).is_true()
	assert_bool(Projector.is_bought("mat_9", save)).is_false()
	assert_bool(Projector.buy("mat_9", save)).is_true()
	assert_int(save.desk_capacity).is_equal(9)
	Projector.migrate_mat(save)
	assert_int(save.tree_bought.count("mat_9")).is_equal(1)


func test_an_old_save_with_the_allowance_card_and_no_units_gets_the_free_third_unit() -> void:
	var save := _save(["projector", "mat_allowance"])
	save.desk_capacity = 2
	UpgradeDesk.migrate(save)
	assert_int(save.desk_capacity).is_equal(3)
	assert_array(save.tree_bought).not_contains("mat_4")
	var plain := _save(["projector"])
	plain.desk_capacity = 2
	UpgradeDesk.migrate(plain)
	assert_int(plain.desk_capacity).is_equal(2)


func test_an_old_save_with_a_bigger_mat_is_brought_down_to_ten_and_loses_nothing_it_paid_for() -> void:
	var save := _save(["projector", "mat_allowance", "big_ideas", "cash_holding"], 5)
	save.desk_capacity = 20
	save.coin_limit = 1000
	save.tree_bought = PackedStringArray(["mat_4", "mat_5", "mat_6", "mat_7", "mat_8", "mat_9", "mat_10", "mat_11", "mat_14", "mat_17", "mat_20"])
	UpgradeDesk.migrate(save)
	assert_int(save.desk_capacity).is_equal(10)
	# The 11th cabbage and the three steps to 14, 17 and 20 come back in coins, past the coin limit.
	assert_int(save.coins).is_equal(5 + 22150 + 100000 + 300000 + 700000)
	for id in _mat_chain():
		assert_bool(Projector.is_bought(id, save)).override_failure_message(id).is_true()
	UpgradeDesk.migrate(save)  # Again: nothing more.
	assert_int(save.coins).is_equal(5 + 1122150)
	assert_int(save.desk_capacity).is_equal(10)


func test_an_old_mat_between_the_old_steps_gets_a_third_of_a_step_back_for_each_cabbage_past_the_eleventh() -> void:
	for case: Array in [[11, 22150], [12, 55483], [13, 88817], [14, 122150], [16, 322150], [17, 422150], [19, 888817], [20, 1122150]]:
		var save := _save(["projector", "mat_allowance"])
		save.desk_capacity = case[0]
		Projector.migrate_mat(save)
		assert_int(save.coins).override_failure_message("%d cabbages" % case[0]).is_equal(case[1])
		assert_int(save.desk_capacity).is_equal(10)
	assert_int(Projector.mat_refund(10)).is_equal(0)


func test_a_mat_of_ten_or_less_is_left_alone_by_the_migration() -> void:
	for units in range(1, 11):
		var save := _save(["projector"], 7)
		save.desk_capacity = units
		Projector.migrate_mat(save)
		assert_int(save.desk_capacity).is_equal(units)
		assert_int(save.coins).is_equal(7)
		assert_float(save.restock_delay).is_equal(SaveGame.new().restock_delay)


func test_an_old_save_that_bought_conveyor_ii_and_iii_gets_the_halved_waits_they_now_give() -> void:
	var save := _save(["projector", "big_ideas", "cash_holding"])
	save.tree_bought = PackedStringArray(["conveyor_1", "conveyor_2"])
	UpgradeDesk.migrate(save)
	assert_float(save.restock_delay).is_equal_approx(SaveGame.new().restock_delay * 0.5, 0.0001)
	save.tree_bought.append("conveyor_3")
	UpgradeDesk.migrate(save)
	UpgradeDesk.migrate(save)
	assert_float(save.restock_delay).is_equal_approx(SaveGame.new().restock_delay * 0.25, 0.0001)


func test_an_old_save_tops_up_merged_chains_to_what_the_kept_nodes_now_give() -> void:
	var half := SaveGame.new()
	half.tree_bought = PackedStringArray(["pack_2", "desk_1", "vacuum_speed_1", "vacuum_2", "vacuum_bag_1", "associate_3", "associate_4"])
	half.pack_size = 15
	half.desk_capacity = 3
	half.vacuum_capacity = 20
	half.associate_speed = 1.5
	Projector.migrate_merged(half)
	assert_int(half.pack_size).is_equal(50)
	assert_int(half.desk_capacity).is_equal(3)
	assert_int(half.vacuum_capacity).is_equal(20)
	assert_float(half.associate_speed).is_equal_approx(1.5, 0.0001)


func test_an_old_save_never_gets_more_than_the_new_chain_gives() -> void:
	var whole := SaveGame.new()
	whole.tree_bought = PackedStringArray(["desk_1", "desk_2", "desk_3", "desk_4", "desk_5", "desk_6", "discount_1", "discount_2", "discount_3"])
	whole.desk_capacity = 13
	whole.pack_discount = 0.85 * 0.85 * 0.8
	Projector.migrate_merged(whole)
	assert_int(whole.desk_capacity).is_equal(13)
	assert_float(whole.pack_discount).is_equal_approx(0.85 * 0.85 * 0.8, 0.0001)


func test_no_two_nodes_sit_on_the_same_spot_of_the_wheel() -> void:
	for a: Dictionary in Projector.NODES:
		for b: Dictionary in Projector.NODES:
			if a.id < b.id:
				assert_float(a.at.distance_to(b.at)).override_failure_message("%s and %s overlap" % [a.id, b.id]).is_greater_equal(0.2)


## A node straight above or below its parent sits far enough off that its title never touches the
## parent's disc (tools/projector_layout/layout.py's box: a node and its title take 0.355 high).
func test_a_node_straight_under_or_over_its_parent_leaves_room_for_its_title() -> void:
	for node: Dictionary in Projector.NODES:
		if node.parent == "" or node.get("dept", false):
			continue
		var parent := Projector.node_data(node.parent)
		if absf(parent.at.x - node.at.x) < 0.01 and not parent.get("dept", false):
			assert_float(absf(parent.at.y - node.at.y)).override_failure_message("%s under %s" % [node.id, node.parent]).is_greater_equal(0.36)


func test_no_two_edges_of_the_tree_cross() -> void:
	var edges := []
	for node: Dictionary in Projector.NODES:
		edges.append([Vector2.ZERO if node.parent == "" else Projector.node_data(node.parent).at, node.at, node.id])
	for a in edges.size():
		for b in range(a + 1, edges.size()):
			var e: Array = edges[a]
			var f: Array = edges[b]
			if e[0] == f[0] or e[0] == f[1] or e[1] == f[0] or e[1] == f[1]:
				continue
			assert_bool(Geometry2D.segment_intersects_segment(e[0], e[1], f[0], f[1]) == null) \
					.override_failure_message("edges to %s and %s cross" % [e[2], f[2]]).is_true()


func test_the_pull_swings_down_and_settles_under_its_tie_without_stretching_the_cord() -> void:
	var tie := Vector3(0.0, 1.2, 0.0)
	var bob := tie + Vector3(Projector.CORD, 0.0, 0.0)
	var prev := bob
	var longest := 0.0
	for _i in 1200:
		var next := Projector.swing(bob, prev, tie, 1.0 / 60.0)
		prev = bob
		bob = next
		longest = maxf(longest, tie.distance_to(bob))
	assert_float(longest).is_less_equal(Projector.CORD + 0.0001)
	assert_float(bob.distance_to(tie + Vector3.DOWN * Projector.CORD)).is_less_equal(0.01)


func test_a_rope_allows_slack_but_never_stretches() -> void:
	var tie := Vector3.ZERO
	assert_vector(Projector.rope(tie, Vector3(0.0, -0.05, 0.0), 0.15)).is_equal(Vector3(0.0, -0.05, 0.0))
	assert_vector(Projector.rope(tie, Vector3(0.0, -1.0, 0.0), 0.15)).is_equal_approx(Vector3(0.0, -0.15, 0.0), Vector3.ONE * 0.0001)


func test_the_affordable_count_is_the_number_of_upgrades_a_budget_covers_each_in_its_own_currency() -> void:
	var upgrades := _upgrades()
	var budget := SaveGame.new()
	budget.coins = 0
	budget.findings = 0
	assert_int(Projector.affordable(budget)).is_equal(0)
	budget.coins = 1 << 30
	budget.findings = 1 << 30
	assert_int(Projector.affordable(budget)).is_equal(upgrades.size())
	budget.coins = 40
	budget.findings = 0
	assert_int(Projector.affordable(budget)).is_equal(upgrades.filter(func(node: Dictionary) -> bool:
		return UpgradeTree.currency_of(node) == "coins" and node.price <= 40).size())
	budget.coins = 0
	budget.findings = 20000
	assert_int(Projector.affordable(budget)).is_equal(upgrades.filter(func(node: Dictionary) -> bool:
		return UpgradeTree.currency_of(node) == "findings" and node.price <= 20000).size())


func test_a_findings_node_is_paid_in_findings_and_coins_never_buy_it() -> void:
	var save := _stamped_but(["stars"])
	save.tree_bought = PackedStringArray(["stock_25", "stock_32", "stock_40", "stock_50", "storage_1", "stock_100", "stock_125",
			"stock_160", "storage_2", "storage_3"])
	save.coins = 1 << 30
	save.findings = 0
	assert_bool(Projector.can_buy("archive_1", save)).is_false()
	assert_bool(Projector.buy("archive_1", save)).is_false()
	save.findings = 15000
	var limit := save.findings_limit
	assert_bool(Projector.buy("archive_1", save)).is_true()
	assert_int(save.findings).is_equal(5000)
	assert_int(save.coins).is_equal(1 << 30)
	assert_int(save.findings_limit).is_equal(limit + 60000)


func test_the_pull_counts_a_findings_node_only_when_the_findings_cover_it() -> void:
	var save := _stamped_but(["stars"])
	save.tree_bought = PackedStringArray(["stock_25", "stock_32", "stock_40", "stock_50", "storage_1", "stock_100", "stock_125",
			"stock_160", "storage_2", "storage_3"])
	save.coins = 0
	save.findings = 0
	var none_covered := Projector.offers(save).y
	save.findings = 10000
	assert_int(Projector.offers(save).y).is_greater(none_covered)
	var announced := {}
	assert_bool(Projector.announce(save, announced)).is_true()
	assert_bool(announced.has("archive_1")).is_true()


func test_the_lamp_pulse_stays_gentle() -> void:
	for i in 100:
		assert_float(UpgradeTree.pulse(i * 0.37)).is_between(0.94, 1.0)


func test_the_tree_layer_is_a_node2d_so_it_is_not_culled_by_an_empty_rect() -> void:
	var projector: Node = auto_free(load("res://entities/projector/projector.tscn").instantiate())
	assert_object(projector.get_node("Screen/Tree/Layer")).is_instanceof(Node2D)


func test_the_pull_tugs_once_per_upgrade_not_each_time_the_coins_climb_back_over_its_price() -> void:
	var save := SaveGame.new()
	save.stamped.append("projector")
	var announced := {}
	save.coins = 0
	assert_bool(Projector.announce(save, announced)).is_false()
	save.coins = 100000
	assert_bool(Projector.announce(save, announced)).is_true()
	save.coins = 0
	assert_bool(Projector.announce(save, announced)).is_false()
	save.coins = 100000
	assert_bool(Projector.announce(save, announced)).is_false()


func test_the_pull_hangs_a_tenth_right_of_the_middle_of_the_screen() -> void:
	assert_float(Projector.TAB_AT).is_equal(0.6)
	assert_float(Projector.SCREEN.get_center().x).is_equal_approx(0.5, 0.0001)


func test_the_pull_flashes_for_half_a_second_when_an_upgrade_turns_up() -> void:
	assert_float(Projector.FLASH_TIME).is_equal(0.5)


func test_the_pull_shows_how_many_upgrades_can_be_bought_and_nothing_when_none() -> void:
	assert_str(Projector.count_text(0)).is_empty()
	assert_str(Projector.count_text(3)).is_equal("3")
	var save := _save(["projector"])
	assert_str(Projector.count_text(Projector.offers(save).y)).is_empty()
	save.coins = 1000000
	assert_str(Projector.count_text(Projector.offers(save).y)).is_not_empty()


func test_faster_analysis_costs_at_most_150_coins_so_it_comes_early() -> void:
	assert_int(Projector.node_data("qa_time").price).is_less_equal(150)


func test_coins_raise_the_affordable_offers_but_not_what_can_be_held() -> void:
	var save := _save(["projector"])
	var none := Projector.offers(save)
	save.coins = 1000000
	var rich := Projector.offers(save)
	assert_int(rich.x).is_equal(none.x)
	assert_int(rich.y).is_greater(none.y)
	assert_int(rich.y).is_equal(rich.x)


func test_an_unlocked_feature_shows_its_whole_branch_and_a_locked_one_none() -> void:
	var save := _save(["projector", "street_posters"])
	assert_bool(Projector.is_shown("slogan_5", save)).is_true()
	assert_bool(Projector.is_shown("mini_rate_1", save)).is_false()
	assert_bool(Projector.is_shown("lamp_time", save)).is_false()


func test_an_upgrade_needing_two_cards_shows_only_once_both_are_stamped() -> void:
	var save := _save(["projector", "junior_associate"])
	assert_bool(Projector.is_shown("hands_bin", save)).is_false()
	save.stamped.append("catch_combo")
	assert_bool(Projector.is_shown("hands_bin", save)).is_true()


func test_only_newly_reachable_nodes_are_marked_new() -> void:
	var save := _save(["projector", "street_posters"])
	assert_array(Projector.fresh(save)).contains("slogan_1")
	assert_array(Projector.fresh(save)).not_contains("slogan_2")


func test_buying_a_node_marks_its_child_new_and_seen_nodes_are_not() -> void:
	var save := _save(["projector", "street_posters"])
	save.tree_seen = PackedStringArray(Projector.fresh(save))
	save.tree_bought.append("slogan_1")
	assert_array(Projector.fresh(save)).is_equal(["slogan_2"])


func test_theme_headings_show_with_their_first_node() -> void:
	var headings := Projector.themes_shown(SaveGame.new()).count(true)
	assert_int(headings).is_greater(0)
	assert_int(headings).is_less(Projector.THEMES.size())


func test_the_demo_locks_upgrades_dearer_than_its_price_cap() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := _save(["projector", "junior_associate", "research_materials"], 1000000)
	save.tree_bought = PackedStringArray(["conveyor_1"])
	assert_int(Projector.node_data("conveyor_2").price).is_greater(Projector.Events.Demo.NODE_PRICE_CAP)
	assert_str(Projector.locked_by("conveyor_2", save)).is_equal("demo")
	assert_bool(Projector.buy("conveyor_2", save)).is_false()
	assert_array(Projector.requirement("conveyor_2", save)).is_equal(["FULL GAME ONLY:", "Wishlist it on Steam"])


func test_the_demo_keeps_upgrades_at_or_under_its_price_cap_buyable() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := _save(["projector"], 1000000)
	save.tree_bought = PackedStringArray(["pack_1"])
	assert_int(Projector.node_data("discount_1").price).is_less_equal(Projector.Events.Demo.NODE_PRICE_CAP)
	assert_str(Projector.locked_by("discount_1", save)).is_empty()
	assert_bool(Projector.buy("discount_1", save)).is_true()


func test_an_upgrade_bought_in_the_full_game_stays_unlocked_in_the_demo() -> void:
	ProjectSettings.set_setting("game/demo", true)
	var save := SaveGame.new()
	save.tree_bought = PackedStringArray(["conveyor_2"])
	assert_str(Projector.locked_by("conveyor_2", save)).is_empty()


func test_a_department_is_an_info_only_plate_that_is_never_held_and_fits_its_name() -> void:
	var save := _save(["projector", "street_posters", "junior_associate", "quality_assurance", "research_inspection"], 1000000)
	for node: Dictionary in Projector.NODES:
		if not node.get("dept", false):
			continue
		assert_bool(Projector.can_hold(node.id, save)).override_failure_message(node.id).is_false()
		var box := UpgradeTree.plate(node.title, Vector2(100, 50), 30.0)
		assert_vector(box.get_center()).is_equal_approx(Vector2(100, 50), Vector2.ONE * 0.01)
		var text := Projector.FONT.get_string_size(node.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		assert_bool(box.size.x > text and box.size.x > box.size.y).override_failure_message(node.id).is_true()


func test_the_first_open_counts_everything_showing_as_seen_so_nothing_blinks_new() -> void:
	var save := _save(["projector", "street_posters"])
	assert_array(Projector.fresh(save)).is_not_empty()
	Projector.mark_first_open(save)
	assert_bool(save.projector_opened).is_true()
	assert_array(Projector.fresh(save)).is_empty()


func test_after_the_first_open_a_newly_reachable_node_is_still_marked_new() -> void:
	var save := _save(["projector", "street_posters"])
	Projector.mark_first_open(save)
	save.tree_bought.append("slogan_1")
	Projector.mark_first_open(save)
	assert_array(Projector.fresh(save)).is_equal(["slogan_2"])


## Every edge of the tree as [from, to, id, theme] at wheel scale `unit`, as drawn: an edge to a
## theme's first node runs through its heading (theme is that heading's index, else -1).
func _edges(unit: Vector2) -> Array:
	var out := []
	for node: Dictionary in Projector.NODES:
		var from: Vector2 = Vector2.ZERO if node.parent == "" else Projector.node_data(node.parent).at * unit
		var theme := UpgradeTree.theme_of(Projector.THEMES, node.id)
		if theme >= 0:
			var spot: Vector2 = Projector.THEMES[theme][1] * unit
			out.append([from, spot, node.id, theme])
			from = spot
		out.append([from, node.at * unit, node.id, theme])
	return out


## What a node covers at radius `r`: its circle and its name above it, or a department's plate.
func _node_box(node: Dictionary, unit: Vector2, r: float) -> Rect2:
	var at: Vector2 = node.at * unit
	if node.get("dept", false):
		return UpgradeTree.plate(node.title, at, r)
	var font := int(clampf(r * 0.6, 9.0, 34.0))
	var width := Projector.FONT.get_string_size(TranslationServer.translate(node.title), HORIZONTAL_ALIGNMENT_LEFT, -1, font).x
	return Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0).merge(Rect2(at.x - width / 2.0, at.y - r - 8.0 - font, width, font + 8.0))


func _segment_hits_rect(from: Vector2, to: Vector2, box: Rect2) -> bool:
	if box.has_point(from) or box.has_point(to):
		return true
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


func test_theme_heading_plates_cover_no_node_other_edge_or_other_heading_in_english_or_german() -> void:
	var unit := Vector2(480.0, 300.0)
	var r := 30.0
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for i in Projector.THEMES.size():
			var box := UpgradeTree.theme_plate(Projector.THEMES[i], unit, r)
			var theme: String = Projector.THEMES[i][0]
			assert_bool(box.size.x > box.size.y).override_failure_message(theme).is_true()
			assert_bool(box.intersects(Rect2(-Vector2.ONE * r * 1.1, Vector2.ONE * r * 2.2))).override_failure_message("%s covers the hub" % theme).is_false()
			for node: Dictionary in Projector.NODES:
				assert_bool(box.intersects(_node_box(node, unit, r))) \
						.override_failure_message("%s (%s) covers %s" % [theme, locale, node.id]).is_false()
			for edge: Array in _edges(unit):
				if edge[3] == i:
					continue  # Its own branch runs through it.
				assert_bool(_segment_hits_rect(edge[0], edge[1], box)) \
						.override_failure_message("%s (%s) covers the edge to %s" % [theme, locale, edge[2]]).is_false()
			for j in range(i + 1, Projector.THEMES.size()):
				assert_bool(box.intersects(UpgradeTree.theme_plate(Projector.THEMES[j], unit, r))) \
						.override_failure_message("%s and %s overlap" % [theme, Projector.THEMES[j][0]]).is_false()


## The supply/pack nodes: whatever changes what a pack holds or costs, or how auto-buy orders.
func _pack_nodes() -> Array:
	return Projector.NODES.filter(func(node: Dictionary) -> bool:
		var stats: Array = node.get("mul", {}).keys() + node.get("add", {}).keys()
		return stats.any(func(stat: String) -> bool: return stat in ["pack_size", "pack_discount", "auto_reserve", "auto_max_factor"]))


func test_the_pack_branch_is_a_few_cheap_steps_since_packs_stop_paying_after_the_farm() -> void:
	var packs := _pack_nodes()
	assert_int(packs.size()).is_less_equal(5)
	for node: Dictionary in packs:
		assert_int(node.price).override_failure_message("%s at $%d" % [node.id, node.price]).is_less_equal(1000)
		assert_str(node.get("research", "")).override_failure_message(node.id).is_empty()


func test_the_slim_pack_branch_still_gives_bigger_cheaper_packs_and_a_smarter_auto_buy() -> void:
	var save := SaveGame.new()
	var base := SaveGame.new()
	for node: Dictionary in _pack_nodes():
		Projector.apply(node.id, save)
	assert_int(save.pack_size).is_equal(base.pack_size + 43)
	assert_float(save.pack_discount).is_equal_approx(0.7, 0.0001)
	assert_int(save.auto_reserve).is_equal(base.auto_reserve + 7)
	assert_float(save.auto_max_factor).is_equal_approx(base.auto_max_factor - 0.5, 0.0001)


func test_an_old_save_keeps_both_old_discounts_and_one_with_the_first_gets_the_merged_cut() -> void:
	var both := SaveGame.new()
	both.migration = 2
	both.tree_bought = PackedStringArray(["pack_1", "discount_1", "discount_2", "auto_reserve_1", "auto_smart_1", "auto_reserve_2"])
	both.pack_discount = 0.85 * 0.68
	both.auto_reserve = 25
	both.auto_max_factor = 0.8
	UpgradeDesk.migrate(both)
	assert_float(both.pack_discount).is_equal_approx(0.85 * 0.68, 0.0001)
	assert_int(both.auto_reserve).is_equal(25)
	assert_float(both.auto_max_factor).is_equal_approx(0.8, 0.0001)
	var first := SaveGame.new()
	first.migration = 2
	first.tree_bought = PackedStringArray(["pack_1", "discount_1"])
	first.pack_discount = 0.85
	UpgradeDesk.migrate(first)
	assert_float(first.pack_discount).is_equal_approx(0.7, 0.0001)
	UpgradeDesk.migrate(first)
	assert_float(first.pack_discount).is_equal_approx(0.7, 0.0001)


func test_every_popup_body_wraps_to_the_popup_width_in_english_and_german() -> void:
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for node: Dictionary in Projector.NODES:
			var shown := TranslationServer.translate(node.body)
			var lines := UpgradeTree.popup_lines(shown)
			assert_str(" ".join(lines).replace(" ", "")).override_failure_message("%s (%s) lost words" % [node.id, locale]) \
					.is_equal(shown.replace("\n", "").replace(" ", ""))
			for line in lines:
				var wide := Projector.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UpgradeTree.POPUP_BODY).x
				assert_float(wide).override_failure_message("%s (%s): \"%s\" is %d px" % [node.id, locale, line, wide]) \
						.is_less_equal(UpgradeTree.POPUP_TEXT)


func test_the_pull_word_fits_its_pennant_in_english_and_german() -> void:
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		var word := TranslationServer.translate("PULL")
		var wide := Projector.FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, Projector.pull_size(word)).x * Projector.PULL_PIXEL
		assert_float(wide).override_failure_message("%s: %s is %.3f m" % [locale, word, wide]).is_less_equal(Projector.PULL_WIDTH)
	assert_int(Projector.pull_size("PULL")).is_equal(Projector.PULL_SIZE)


func test_an_old_mat_of_four_stamping_the_allowance_keeps_its_units_and_tops_out_at_ten() -> void:
	var save := _save(["projector", "coin_collector", "desk_space", "big_ideas", "cash_holding"], 1000000000)
	save.desk_capacity = 4
	save.stamped.append("mat_allowance")
	UpgradeDesk.apply("mat_allowance", save)
	assert_int(save.desk_capacity).is_equal(4)
	assert_bool(Projector.is_bought("mat_4", save)).is_true()
	for id in _mat_chain().slice(1):
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		assert_int(save.desk_capacity).is_equal(id.trim_prefix("mat_").to_int())
	assert_int(save.desk_capacity).is_equal(Projector.MAT_MAX)


func test_the_allowance_card_fills_a_small_mat_to_three() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("mat_allowance", save)
	assert_int(save.desk_capacity).is_equal(Projector.MAT_FIRST - 1)


func test_a_save_from_before_any_merge_with_the_first_two_old_discounts_gets_the_whole_merged_cut() -> void:
	var both := SaveGame.new()
	both.tree_bought = PackedStringArray(["pack_1", "discount_1", "discount_2"])
	both.pack_discount = 0.85 * 0.85
	UpgradeDesk.migrate(both)
	assert_float(both.pack_discount).is_equal_approx(0.7, 0.0001)
	var first := SaveGame.new()
	first.tree_bought = PackedStringArray(["pack_1", "discount_1"])
	first.pack_discount = 0.85
	UpgradeDesk.migrate(first)
	assert_float(first.pack_discount).is_equal_approx(0.7, 0.0001)


func test_frictionless_handling_takes_all_the_weight_off_a_held_unit() -> void:
	var save := SaveGame.new()
	Projector.apply("free_carry", save)
	assert_float(save.carry_weight).is_equal(0.0)


func test_each_theme_heading_sits_on_its_branch_between_the_parent_and_its_first_nodes() -> void:
	for theme: Array in Projector.THEMES:
		assert_bool(theme[2].is_empty()).override_failure_message(theme[0]).is_false()
		for id: String in theme[2]:
			assert_bool(Projector.node_data(id).is_empty()).override_failure_message("%s: %s" % [theme[0], id]).is_false()
		assert_float(UpgradeTree.heading_bend(Projector, theme)).override_failure_message(theme[0]).is_less_equal(30.5)


func test_an_edge_to_a_branchs_first_node_is_routed_through_its_heading() -> void:
	assert_int(UpgradeTree.theme_of(Projector.THEMES, "mini_rate_1")).is_greater_equal(0)
	assert_int(UpgradeTree.theme_of(Projector.THEMES, "mini_rate_2")).is_equal(-1)


func test_the_golden_value_nodes_wait_for_the_golden_card_and_raise_sale_and_lab_by_at_least_a_quarter_each() -> void:
	var save := _save(["projector", "offsite_storage"], 10000000)
	save.tree_bought = PackedStringArray(["storage_2"])
	assert_bool(Projector.is_shown("gold_sale_1", save)).is_false()
	save.stamped.append("golden_cabbage")
	save.stamped.append("big_ideas")  # The second step of each is late game.
	var sale: Array[float] = [save.golden_sale]
	var lab: Array[float] = [save.golden_lab]
	for id: String in ["gold_sale_1", "gold_sale_2"]:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		sale.append(save.golden_sale)
	for id: String in ["gold_lab_1", "gold_lab_2"]:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		lab.append(save.golden_lab)
	assert_array(sale).is_equal([10.0, 15.0, 20.0])
	assert_array(lab).is_equal([10.0, 15.0, 25.0])


func test_gold_standard_only_shows_once_premium_cabbages_and_the_golden_lamp_exist() -> void:
	var save := _save(["projector", "golden_cabbage", "big_ideas", "cash_holding"], 10000000)
	assert_bool(Projector.is_shown(SaleWindow.GOLD_AGE, save)).is_false()
	save.stamped.append("golden_lamp")
	assert_bool(Projector.is_shown(SaleWindow.GOLD_AGE, save)).is_true()
	# It hangs under REVALUATION, the Golden Age branch's first step.
	assert_bool(Projector.buy(SaleWindow.GOLD_AGE, save)).is_false()
	assert_bool(Projector.buy("lamp_mult", save)).is_true()
	assert_bool(Projector.buy(SaleWindow.GOLD_AGE, save)).is_true()
	assert_bool(save.tree_bought.has(SaleWindow.GOLD_AGE)).is_true()
	assert_bool(Projector.is_shown(SaleWindow.GOLD_AGE, _save(["projector", "golden_lamp", "big_ideas", "cash_holding"]))).is_false()


func test_both_lamps_have_their_own_category_on_a_spoke_of_its_own_off_the_hub() -> void:
	var heading := UpgradeTree.theme_of(Projector.THEMES, "lamp_mult")
	assert_str(Projector.THEMES[heading][0]).is_equal("LIGHTING SCHEDULE")
	assert_int(UpgradeTree.theme_of(Projector.THEMES, "lab_lamp_mult")).is_equal(heading)
	assert_array(UpgradeTree.theme_members(Projector, heading)).contains_exactly_in_any_order(["lamp_mult", "lamp_time", "lamp_every",
			SaleWindow.GOLD_AGE, "lab_lamp_mult", "lab_lamp_time", "lab_lamp_every", QaBay.LAB_GOLD])
	for id: String in ["lamp_mult", "lab_lamp_mult"]:
		assert_str(Projector.node_data(id).parent).override_failure_message(id).is_empty()
	# Neither the sales events, the golden branch nor the research branch still holds them.
	for other: String in ["combo_window", "gold_sale_1", "research_mult_1"]:
		assert_array(UpgradeTree.theme_members(Projector, UpgradeTree.theme_of(Projector.THEMES, other))) 				.override_failure_message(other).not_contains(["lamp_mult", SaleWindow.GOLD_AGE, "lab_lamp_mult", QaBay.LAB_GOLD])


func test_the_golden_age_branch_shows_once_its_cards_are_stamped_with_nothing_to_buy_first() -> void:
	var late := ["projector", "big_ideas", "cash_holding"]
	assert_bool(Projector.is_shown("lamp_mult", _save(late))).is_false()
	var save := _save(late + ["golden_lamp"])
	assert_bool(Projector.is_shown("lamp_mult", save)).is_true()
	assert_bool(Projector.is_reachable("lamp_mult", save)).is_true()
	assert_bool(Projector.themes_shown(save)[UpgradeTree.theme_of(Projector.THEMES, "lamp_mult")]).is_true()


func test_the_research_light_branch_shows_once_the_light_is_stamped_with_nothing_to_buy_first() -> void:
	var late := ["projector", "big_ideas", "cash_holding"]
	assert_bool(Projector.is_shown("lab_lamp_mult", _save(late))).is_false()
	var save := _save(late + ["research_light"])
	assert_bool(Projector.is_shown("lab_lamp_mult", save)).is_true()
	assert_bool(Projector.is_reachable("lab_lamp_mult", save)).is_true()
	assert_bool(Projector.themes_shown(save)[UpgradeTree.theme_of(Projector.THEMES, "lab_lamp_mult")]).is_true()


func test_gold_standard_is_the_dearest_golden_node_and_costs_over_three_times_the_capstones_coins() -> void:
	var price: int = Projector.node_data(SaleWindow.GOLD_AGE).price
	for node: Dictionary in Projector.NODES:
		if node.id != SaleWindow.GOLD_AGE and (str(node.id).begins_with("gold_") or node.get("needs", []).has("golden_cabbage")):
			assert_int(node.price).override_failure_message(node.id).is_less(price)
	assert_int(price).is_greater(UpgradeDesk.card_data("consolidation").also.coins * 3)


func test_the_managerial_chains_wait_for_their_cards_and_raise_own_work_from_a_fifth_to_sixty_percent() -> void:
	for chain: Array in [["own_sales", "own_sale", ["own_sale_1", "own_sale_2", "own_sale_3"]],
			["own_research", "own_lab", ["own_lab_1", "own_lab_2", "own_lab_3"]]]:
		var ids: Array = chain[2]
		assert_bool(Projector.is_shown(ids[0], _save(["projector", "managerial_oversight", "quality_assurance"]))).is_false()
		var save := SaveGame.new()
		UpgradeDesk.apply(chain[0], save)
		var was: float = save.get(chain[1])
		for id: String in ids:
			Projector.apply(id, save)
			assert_float(save.get(chain[1])).override_failure_message(id).is_greater(was)
			was = save.get(chain[1])
		assert_float(was).is_equal_approx(1.6, 0.0001)


## The coin units branch (entities/vacuum/), cheapest first.
func _coin_units() -> Array:
	var out := Projector.NODES.filter(func(node: Dictionary) -> bool: return node.id.begins_with("vacuum_"))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.price < b.price)
	return out


## Every node above `id` on its branch, up to the department.
func _ancestors(id: String) -> Array:
	var out := []
	var step: String = Projector.node_data(id).parent
	while not Projector.node_data(step).get("dept", false):
		out.append(step)
		step = Projector.node_data(step).parent
	return out


func test_the_coin_units_come_in_many_small_steps_the_first_four_a_few_hundred_coins_each() -> void:
	var units := _coin_units()
	assert_int(units.size()).is_greater_equal(10)
	for node: Dictionary in units.slice(0, 4):
		assert_int(node.price).override_failure_message(node.id).is_less_equal(500)


func test_each_robot_is_dearer_than_every_step_before_it_and_far_under_its_old_price() -> void:
	for robot: Array in [["vacuum_2", 5500], ["vacuum_3", 87500]]:
		var price: int = Projector.node_data(robot[0]).price
		assert_int(price).is_less_equal(robot[1] / 5)
		for id: String in _ancestors(robot[0]):
			assert_int(price).override_failure_message(id).is_greater(Projector.node_data(id).price)


func test_every_coin_unit_step_improves_what_it_names_by_at_least_a_quarter() -> void:
	for node: Dictionary in _coin_units():
		var save := SaveGame.new()
		UpgradeDesk.apply("coin_collector", save)
		for id: String in _ancestors(node.id):
			Projector.apply(id, save)
		for stat: String in node.get("mul", {}):
			var gain: float = node.mul[stat]
			assert_float(maxf(gain, 1.0 / gain)).override_failure_message("%s %s" % [node.id, stat]).is_greater_equal(1.25)
		for stat: String in node.get("add", {}):
			var was: float = save.get(stat)
			assert_float((was + node.add[stat]) / was).override_failure_message("%s %s" % [node.id, stat]).is_greater_equal(1.25)


func test_each_bag_step_states_the_coins_per_trip_it_gives_and_had_whatever_else_was_bought() -> void:
	for node: Dictionary in _coin_units():
		if not node.get("add", {}).has("vacuum_capacity"):
			continue
		var save := SaveGame.new()
		for id: String in _ancestors(node.id):
			Projector.apply(id, save)
		var was := save.vacuum_capacity
		Projector.apply(node.id, save)
		assert_str(node.body).override_failure_message(node.id).contains("carries %d coins per trip" % save.vacuum_capacity)
		assert_str(node.body).override_failure_message(node.id).contains("not %d." % was)


func test_the_dock_steps_halve_the_four_second_recharge_twice() -> void:
	var save := SaveGame.new()
	assert_float(save.vacuum_rest).is_equal_approx(4.0, 0.0001)
	Projector.apply("vacuum_dock_1", save)
	assert_float(save.vacuum_rest).is_equal_approx(2.0, 0.0001)
	Projector.apply("vacuum_dock_2", save)
	assert_float(save.vacuum_rest).is_equal_approx(1.0, 0.0001)


func test_the_dock_steps_are_called_recharge_and_bulk_discharge_after_them_empties_the_bag_at_once() -> void:
	assert_str(Projector.node_data("vacuum_dock_1").title).contains("RECHARGE")
	assert_str(Projector.node_data("vacuum_dock_2").title).contains("RECHARGE")
	var bulk := Projector.node_data(CoinVacuums.BULK_DISCHARGE)
	assert_str(bulk.title).is_equal("BULK DISCHARGE")
	assert_str(bulk.parent).is_equal("vacuum_dock_2")


func test_an_old_save_with_the_second_robot_gets_the_larger_bag_on_its_path_once() -> void:
	var save := SaveGame.new()
	save.tree_bought = PackedStringArray(["vacuum_speed_1", "vacuum_2"])
	save.vacuums = 2
	save.vacuum_capacity = 20
	Projector.migrate_vacuums(save)
	Projector.migrate_vacuums(save)
	assert_bool(save.tree_bought.has("vacuum_hopper_1")).is_true()
	assert_int(save.vacuum_capacity).is_equal(24)
	assert_int(save.vacuums).is_equal(2)


func test_an_old_save_with_the_third_robot_gets_both_bag_steps_and_never_less_than_it_had() -> void:
	var save := SaveGame.new()
	save.tree_bought = PackedStringArray(["vacuum_speed_1", "vacuum_2", "vacuum_speed_2", "vacuum_3"])
	save.vacuums = 3
	save.vacuum_capacity = 50
	Projector.migrate_vacuums(save)
	assert_bool(save.tree_bought.has("vacuum_hopper_1") and save.tree_bought.has("vacuum_hopper_2")).is_true()
	assert_int(save.vacuum_capacity).is_equal(66)
	assert_int(save.vacuums).is_equal(3)


const CH3_COIN_UNITS: Array[String] = ["vacuum_hopper_3", "vacuum_4", "vacuum_speed_4", "vacuum_hopper_4", "vacuum_5", "vacuum_nozzle_2"]


func test_chapter_three_brings_a_fourth_and_fifth_coin_robot_only_behind_big_minds() -> void:
	var early := _stamped_but(["big_ideas", "stars"])
	var later := _stamped_but(["stars"])
	assert_array(Projector.node_data("vacuum_hopper_3").needs).contains(["big_ideas"])
	for id: String in CH3_COIN_UNITS:
		assert_bool(Projector.is_shown(id, early)).override_failure_message(id).is_false()
	assert_bool(Projector.is_shown("vacuum_hopper_3", later)).is_true()
	var save := SaveGame.new()
	UpgradeDesk.apply("coin_collector", save)
	for id: String in _ancestors("vacuum_nozzle_2") + ["vacuum_nozzle_2"]:
		Projector.apply(id, save)
	assert_int(save.vacuums).is_equal(5)
	assert_int(save.vacuum_capacity).is_equal(150)


func test_each_chapter_three_coin_unit_step_costs_more_than_the_one_before() -> void:
	var last: int = Projector.node_data("vacuum_speed_3").price
	for id: String in CH3_COIN_UNITS:
		var price: int = Projector.node_data(id).price
		assert_int(price).override_failure_message(id).is_greater(last)
		last = price



## Chapter 3 (desk cards big_ideas, condense). The first node of each late-game run moved behind
## BIG MINDS HAVE BIG IDEAS, and the nodes that only exist on the wide sheet.
const LATE: Array[String] = ["slogan_6", "hire_associate_7", "conveyor_3", "lamp_mult", "bin_rebate_5", "research_mult_4",
		"own_sale_3", "own_lab_3", "research_chance_3", "grow_4", "double_findings", "gold_sale_2", "gold_lab_2", "stock_3000"]
const WIDE_ONLY: Array[String] = ["slogan_7", "slogan_8", "mandatory_consumption", "headcount_2", "two_handed",
		"condense_gold", "condense_gold_3", "condense_gold_4", "condense_gold_6", "condense_2", "condense_3", "condense_4", "condense_5",
		"condense_7", "condense_8", "condense_9"]


## Every desk card stamped but `missing`.
## Every card stamped but `missing`; without stars, none of chapter 4's either (they all wait for it).
func _stamped_but(missing: Array) -> SaveGame:
	var save := SaveGame.new()
	var skip := missing + (_behind("stars") if "stars" in missing else [])
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in skip:
			save.stamped.append(card.id)
	return save


func test_big_ideas_widens_the_projector_screen() -> void:
	var save := _save(["projector"])
	assert_bool(Projector.wide(save)).is_false()
	save.stamped.append("big_ideas")
	assert_bool(Projector.wide(save)).is_true()
	assert_bool(Projector.screen_for(0.0).is_equal_approx(Projector.SCREEN)).is_true()
	assert_bool(Projector.screen_for(1.0).is_equal_approx(Projector.SCREEN_WIDE)).is_true()
	assert_float(Projector.SCREEN_WIDE.size.x).is_greater(Projector.SCREEN.size.x * 1.25)
	assert_float(Projector.SCREEN_WIDE.size.y).is_greater(Projector.SCREEN.size.y)
	# A rim of the overlay stays on both sides and below: a click there still rolls the screen away.
	assert_float(Projector.SCREEN_WIDE.position.x).is_greater_equal(0.02)
	assert_float(Projector.SCREEN_WIDE.end.x).is_less_equal(0.98)
	assert_float(Projector.SCREEN_WIDE.end.y).is_less_equal(0.96)


func _projector(save: SaveGame) -> Projector:
	var real := SaveManager.save
	SaveManager.save = save
	var scene: Node = auto_free(load("res://entities/projector/projector.tscn").instantiate())
	add_child(scene)
	var projector := scene.get_node("Screen") as Projector
	projector.set_process(false)
	SaveManager.save = real
	return projector


func test_the_wide_sheet_is_shown_widening_the_first_time_it_comes_down_and_stays_wide_after() -> void:
	var real := SaveManager.save
	var save := _save(["projector", "big_ideas"])
	var projector := _projector(save)
	assert_float(projector._wide).is_zero()  # Stamped, not yet seen: it still hangs narrow.
	SaveManager.save = save
	projector._settle(true)
	for i in 40:
		projector._settling.custom_step(0.1)
	SaveManager.save = real
	assert_float(projector._wide).is_equal_approx(1.0, 0.0001)
	assert_bool(save.projector_wide).is_true()
	assert_float(_projector(save)._wide).is_equal(1.0)  # A loaded save that has seen it starts wide.


func test_without_big_ideas_the_screen_comes_down_narrow_and_stays_narrow() -> void:
	var real := SaveManager.save
	var save := _save(["projector"])
	var projector := _projector(save)
	SaveManager.save = save
	projector._settle(true)
	for i in 40:
		projector._settling.custom_step(0.1)
	SaveManager.save = real
	assert_float(projector._wide).is_zero()
	assert_bool(save.projector_wide).is_false()


func test_late_game_nodes_stay_hidden_until_big_ideas() -> void:
	var early := _stamped_but(["big_ideas", "stars"])
	var later := _stamped_but(["stars"])
	for id: String in LATE:
		assert_array(Projector.node_data(id).needs).override_failure_message(id).contains(["big_ideas"])
		assert_bool(Projector.is_shown(id, early)).override_failure_message(id).is_false()
		assert_bool(Projector.is_shown(id, later)).override_failure_message(id).is_true()
	# The runs past them go with them.
	for id: String in ["hire_associate_8", "hire_associate_10", "storage_5", "stock_15000"]:
		assert_bool(Projector.is_shown(id, early)).override_failure_message(id).is_false()
		assert_bool(Projector.is_shown(id, later)).override_failure_message(id).is_true()


func test_every_node_dearer_than_the_dearest_chapter_two_buy_waits_for_big_ideas() -> void:
	var early := _stamped_but(["big_ideas", "condense", "stars"])
	for node: Dictionary in _upgrades():
		if node.price > 35000:
			assert_bool(Projector.is_shown(node.id, early)).override_failure_message(node.id).is_false()


## Every desk card that cannot be stamped before `card` is: the card itself is not in it.
func _behind(card: String) -> Array:
	var out := []
	var found := true
	while found:
		found = false
		for other: Dictionary in UpgradeDesk.CARDS:
			if other.id not in out and other.get("needs", []).any(func(need: String) -> bool: return need == card or need in out):
				out.append(other.id)
				found = true
	return out


func test_nothing_on_show_before_chapter_threes_limit_cards_costs_more_than_the_purse_holds() -> void:
	# The purse holds $40,000 until RAISE THE AUTHORISED CASH HOLDING and ¶8,000 until EXTEND THE ARCHIVE.
	var purse := SaveGame.new()
	var most := {coins = purse.coin_limit, findings = purse.findings_limit}
	for raise: Array in [["cash_holding", "coins"], ["archive_capacity", "findings"]]:
		var paid_in: String = raise[1]
		var late := _behind(raise[0])
		var save := _stamped_but(late + [raise[0]])
		save.farms_owned.append("K-1")  # With a farm, where one can be had by then: its nodes show too.
		for card: Dictionary in UpgradeDesk.CARDS:  # The cards dealt by then, the limit card among them.
			if card.id not in late:
				assert_int(UpgradeDesk.costs(card).get(paid_in, 0)).override_failure_message("card %s" % card.id).is_less_equal(most[paid_in])
		for rules: Variant in [Projector, FarmTree]:
			for node: Dictionary in rules.NODES:
				if rules.is_shown(node.id, save) and UpgradeTree.currency_of(node) == paid_in:
					assert_int(node.get("price", 0)).override_failure_message("node %s" % node.id).is_less_equal(most[paid_in])


func test_the_first_treasury_step_waits_for_the_cash_card_so_its_five_times_always_comes_first() -> void:
	assert_bool(Projector.is_shown("coin_limit_1", _stamped_but(["cash_holding", "stars"]))).is_false()
	assert_bool(Projector.is_shown("coin_limit_1", _stamped_but(["stars"]))).is_true()


func test_chapter_twos_last_card_never_needs_a_node_behind_big_ideas() -> void:
	# CONSOLIDATED GROWTH is paid with 1,900 cabbages from storage: the chain up to AIRCRAFT HANGAR (2,000) stays.
	var save := _stamped_but(["consolidation", "market_intelligence", "big_ideas", "condense", "stars"])
	save.coins = 100000000
	for id: String in _storage_chain():
		if not Projector.buy(id, save):
			break
	assert_bool(save.tree_bought.has("stock_2000")).is_true()
	assert_bool(save.tree_bought.has("stock_3000")).is_false()
	assert_int(save.storage_cap).is_greater(UpgradeDesk.card_data("consolidation").price)
	for card: Dictionary in UpgradeDesk.CARDS:  # No card is dealt by a node that moved.
		if card.has("tree"):
			assert_bool(Projector.is_shown(card.tree, _early())).override_failure_message(card.id).is_true()


func _early() -> SaveGame:
	return _stamped_but(["market_intelligence", "big_ideas", "condense", "stars"])


func test_a_save_that_bought_a_late_node_keeps_its_effect_and_its_place_on_the_tree() -> void:
	var save := _stamped_but(["consolidation", "market_intelligence", "big_ideas", "condense", "stars"])
	save.coins = 1000000
	save.tree_bought = PackedStringArray(["conveyor_1", "conveyor_2", "conveyor_3", "hire_associate_2", "hire_associate_3",
			"hire_associate_4", "hire_associate_5", "hire_associate_6", "hire_associate_7"])
	save.dispense_interval = 0.22
	save.hands = 7
	UpgradeDesk.migrate(save)
	assert_float(save.dispense_interval).is_equal(0.22)
	assert_int(save.hands).is_equal(7)
	assert_bool(Projector.is_shown("conveyor_3", save)).is_true()
	assert_bool(Projector.is_bought("conveyor_3", save)).is_true()
	# The run past a bought late node stays buyable; a late node it never bought stays hidden.
	assert_bool(Projector.is_shown("hire_associate_8", save)).is_true()
	assert_bool(Projector.buy("hire_associate_8", save)).is_true()
	assert_int(save.hands).is_equal(8)
	assert_bool(Projector.is_shown("slogan_6", save)).is_false()
	assert_bool(Projector.is_shown("headcount_2", save)).is_false()  # Chapter 3's own node still needs the card.


func test_the_wide_sheets_own_nodes_show_only_with_big_ideas_and_condensation_only_with_condense_too() -> void:
	var none := _stamped_but(["big_ideas", "condense", "stars"])
	var big := _stamped_but(["condense", "stars"])
	var both := _stamped_but(["stars"])
	for id: String in WIDE_ONLY:
		assert_bool(Projector.is_shown(id, none)).override_failure_message(id).is_false()
		assert_bool(Projector.is_shown(id, both)).override_failure_message(id).is_true()
		assert_bool(Projector.is_shown(id, big)).override_failure_message(id).is_equal(not id.begins_with("condense"))
	assert_bool(Projector.is_shown("condense_research", _stamped_but(["big_ideas", "stars"]))).is_false()
	var heading := UpgradeTree.theme_of(Projector.THEMES, "condense_research")
	assert_str(Projector.THEMES[heading][0]).is_equal("CONDENSATION")
	assert_bool(Projector.themes_shown(big)[heading]).is_false()
	assert_bool(Projector.themes_shown(both)[heading]).is_true()


func test_the_wide_sheets_marketing_run_adds_two_quarter_steps_and_ends_in_mandatory_consumption() -> void:
	var save := _stamped_but(["stars"])
	save.coins = 100000000
	save.tree_bought = PackedStringArray(["slogan_1", "slogan_2", "slogan_3", "slogan_4", "slogan_5", "slogan_6"])
	var marketing := save.marketing
	assert_bool(Projector.buy("slogan_7", save)).is_true()
	assert_bool(Projector.buy("slogan_8", save)).is_true()
	assert_float(save.marketing / marketing).is_equal_approx(1.25 * 1.25, 0.0001)
	assert_bool(Projector.buy(PriceSlate.MANDATORY, save)).is_true()
	assert_str(Projector.node_data(PriceSlate.MANDATORY).parent).is_equal("slogan_8")


func test_departmental_headcount_adds_two_hands_at_once_over_a_quarter_more_than_the_seven_before_it() -> void:
	var save := _stamped_but(["stars"])
	save.coins = 100000000
	save.hands = 7
	save.tree_bought = PackedStringArray(["hire_associate_2", "hire_associate_3", "hire_associate_4", "hire_associate_5",
			"hire_associate_6", "hire_associate_7"])
	assert_bool(Projector.buy("headcount_2", save)).is_true()
	assert_int(save.hands).is_equal(9)
	assert_float(9.0 / 7.0).is_greater_equal(1.25)
	assert_str(Projector.node_data("two_handed").parent).is_equal("headcount_2")


func test_the_plain_condense_chain_needs_no_research_switch_and_climbs_to_thirty_two_cabbages_in_one() -> void:
	var save := _stamped_but(["stars"])
	save.coins = 100000000
	UpgradeDesk.apply("condense", save)
	assert_str(Projector.node_data("condense_2").parent).is_equal("dept_manual")
	for id: String in ["condense_2", "condense_3"]:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
	assert_int(save.condense).is_equal(4)
	# Each of II and III is felt: +50%, then +33% on what a condensed cabbage holds.
	assert_float(4.0 / 3.0).is_greater_equal(1.25)
	# IV to IX (the mat stops at ten, so what follows the farm is what a cabbage holds): +50% and +33% in turn.
	# IV to IX (the mat stops at ten, so what follows the farm is what a cabbage holds): +50% and +33% in
	# turn, the annexed grid card taking 8 to 12 between V and VII.
	for step: Array in [["condense_4", 6], ["condense_5", 8], [Projector.GRID_CARD, 12], ["condense_7", 16], ["condense_8", 24], ["condense_9", 32]]:
		var was := save.condense
		if step[0] == Projector.GRID_CARD:
			UpgradeDesk.apply(step[0], save)
		else:
			assert_bool(Projector.buy(step[0], save)).override_failure_message(step[0]).is_true()
		assert_int(save.condense).is_equal(step[1])
		assert_float(float(save.condense) / was).is_greater_equal(1.25)


func test_the_plain_condense_chain_stops_at_eight_until_the_annexed_grid_card_is_stamped() -> void:
	var save := _stamped_but([Projector.GRID_CARD, "stars"])
	save.coins = 100000000
	save.coin_limit = 1000000000
	UpgradeDesk.apply("condense", save)
	for id: String in ["condense_2", "condense_3", "condense_4", "condense_5"]:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
	assert_int(save.condense).is_equal(8)
	assert_bool(Projector.node_data(Projector.CAPPED_CONDENSE).is_empty()).is_true()  # CONDENSE VI is gone.
	for id: String in ["condense_7", "condense_8", "condense_9"]:
		assert_bool(Projector.is_shown(id, save)).override_failure_message(id).is_false()
	assert_bool(Projector.buy("condense_7", save)).is_false()
	assert_int(save.condense).is_equal(8)
	save.stamped.append(Projector.GRID_CARD)
	UpgradeDesk.apply(Projector.GRID_CARD, save)
	assert_int(save.condense).is_equal(12)
	assert_bool(Projector.is_reachable("condense_7", save)).is_true()
	assert_bool(Projector.buy("condense_7", save)).is_true()
	assert_int(save.condense).is_equal(16)


func test_an_old_save_that_bought_condense_six_and_seven_keeps_sixteen_with_the_grid_card_filed_once() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["condense"])
	save.condense = 16
	save.tree_bought = PackedStringArray(["condense_2", "condense_3", "condense_4", "condense_5", "condense_6", "condense_7"])
	UpgradeDesk.migrate(save)
	UpgradeDesk.migrate(save)  # Safe to rerun.
	assert_int(save.condense).is_equal(16)  # Nothing lost, nothing added.
	assert_bool(save.tree_bought.has(Projector.CAPPED_CONDENSE)).is_false()
	assert_bool(save.tree_bought.has("condense_7")).is_true()
	assert_int(Array(save.stamped).count(Projector.GRID_CARD)).is_equal(1)
	assert_bool(Projector.is_reachable("condense_8", save)).is_true()
	# Only CONDENSE VI bought: 12, and VII is next.
	var six := SaveGame.new()
	six.stamped = PackedStringArray(["condense"])
	six.condense = 12
	six.tree_bought = PackedStringArray(["condense_2", "condense_3", "condense_4", "condense_5", "condense_6"])
	UpgradeDesk.migrate(six)
	assert_int(six.condense).is_equal(12)
	assert_bool(six.stamped.has(Projector.GRID_CARD)).is_true()
	assert_bool(Projector.is_reachable("condense_7", six)).is_true()
	# A save that never bought it gets no card.
	var five := SaveGame.new()
	five.condense = 8
	five.tree_bought = PackedStringArray(["condense_5"])
	UpgradeDesk.migrate(five)
	assert_bool(five.stamped.has(Projector.GRID_CARD)).is_false()
	assert_int(five.condense).is_equal(8)


func test_every_wide_sheet_node_is_dearer_than_the_big_ideas_card_itself() -> void:
	var card: int = UpgradeDesk.card_data("big_ideas").price
	for id: String in WIDE_ONLY:
		assert_int(Projector.node_data(id).price).override_failure_message(id).is_greater(card)


func test_zoomed_right_out_the_whole_wheel_fits_the_wide_sheet() -> void:
	assert_float(Projector.ZOOM_WIDE).is_less(UpgradeTree.ZOOM_MIN)
	# The tree's rect on a 1920 x 1080 view (Projector._tree_rect), and the wheel's scale on it (UpgradeTree._wheel).
	var sheet := Vector2(1920.0, 1080.0) * Projector.SCREEN_WIDE.size
	var area := Vector2(sheet.x - 24.0, (sheet.y - Projector.ROLLER_H) * 0.87 - Projector.BAR_H)
	var uy := area.y / 2.0 / 1.25
	var unit := Vector2(minf(area.x / 2.0 / 1.05, uy * UpgradeTree.WIDEN), uy) * Projector.ZOOM_WIDE
	var span := Rect2(Projector.NODES[0].at, Vector2.ZERO)
	for node: Dictionary in Projector.NODES:
		span = span.expand(node.at)
	var room := 60.0  # A node's circle and its name above it.
	assert_float(span.size.x * unit.x + room * 2.0).is_less(area.x)
	assert_float(span.size.y * unit.y + room * 2.0).is_less(area.y)


func test_the_wide_sheet_sounds_when_it_starts_to_run_out_after_the_pause_not_when_it_comes_down() -> void:
	var real := SaveManager.save
	var save := _save(["projector", "big_ideas"])
	var projector := _projector(save)
	var sfx := projector.get_node("Sfx") as AudioStreamPlayer
	assert_object(projector.widen_sound).is_not_null()
	SaveManager.save = save
	projector._settle(true)
	assert_object(sfx.stream).is_same(projector.roll_down_sound)
	for i in 80:
		if projector._wide > 0.0:
			break
		projector._settling.custom_step(0.05)
	SaveManager.save = real
	assert_object(sfx.stream).is_same(projector.widen_sound)
	assert_bool(sfx.playing).is_true()


func test_the_projector_has_no_war_nodes_they_live_in_the_depots_general_programme() -> void:
	for node: Dictionary in Projector.NODES:
		assert_bool(String(node.id).begins_with("war_")).override_failure_message(node.id).is_false()
		assert_bool(node.get("needs", []).has("war_mode")).override_failure_message(node.id).is_false()


func test_the_biggest_store_before_lead_lining_still_fits_the_chutes_stock_counter() -> void:
	var top := 0
	for id: String in _storage_chain():
		if not id.begins_with("lead_lining_"):
			top = maxi(top, Projector.cap_at(id))
	assert_int(top).is_greater(9999)
	assert_int(top).is_less_equal(int(pow(10, Associate.Feeder.DRUMS)) - 1)
	# Past it the store needs the readout PRINT LARGER NUMBERS brings, stamped long before.
	assert_array(Projector.node_data("lead_lining_1").needs).contains(["lead_storage"])
	assert_array(_ahead_of("lead_storage")).contains(["print_numbers"])


## Every desk card that must be stamped before `card` can be (its needs, and theirs).
func _ahead_of(card: String) -> Array:
	var out := []
	var todo: Array = UpgradeDesk.card_data(card).get("needs", []).duplicate()
	while not todo.is_empty():
		var need: String = todo.pop_back()
		if need not in out:
			out.append(need)
			todo += UpgradeDesk.card_data(need).get("needs", [])
	return out


func test_the_merging_chains_wait_for_the_coin_merging_card_and_halve_the_wait_and_raise_the_top_coin_to_ten_thousand() -> void:
	assert_bool(Projector.is_shown("merge_speed_1", _save(["projector", "coin_collector"]))).is_false()
	for id: String in ["merge_speed_1", "merge_top_1"]:  # Chapter 3's only: none shows before the wide sheet.
		assert_bool(Projector.is_shown(id, _stamped_but(["big_ideas", "stars"]))).override_failure_message(id).is_false()
	var save := _save(["projector", "coin_collector", "coin_merge", "big_ideas", "cash_holding"], 1000000000)
	save.tree_bought = PackedStringArray(["vacuum_speed_1", "vacuum_hopper_1", "vacuum_2", "vacuum_nozzle_1"])
	assert_float(save.merge_every).is_equal(2.0)
	assert_int(save.merge_top).is_equal(100)
	for id: String in ["merge_speed_1", "merge_speed_2", "merge_speed_3", "merge_top_1", "merge_top_2", "merge_top_3", "merge_top_4"]:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
	assert_float(save.merge_every).is_equal_approx(0.25, 0.0001)
	assert_int(save.merge_top).is_equal(10000)


func test_the_archive_hangs_on_the_projector_with_its_own_heading_and_is_paid_in_findings() -> void:
	for id: String in ["archive_1", "archive_2", "archive_3", "archive_4", "archive_5"]:
		assert_str(UpgradeTree.currency_of(Projector.node_data(id))).override_failure_message(id).is_equal("findings")
	var heading := UpgradeTree.theme_of(Projector.THEMES, "archive_1")
	assert_str(Projector.THEMES[heading][0]).is_equal("ARCHIVE")


func test_the_money_limit_and_the_golden_nodes_have_their_own_headings_and_storage_is_only_the_store() -> void:
	assert_str(Projector.THEMES[UpgradeTree.theme_of(Projector.THEMES, "coin_limit_1")][0]).is_equal("TREASURY")
	for id: String in ["gold_sale_1", "gold_lab_1"]:
		assert_str(Projector.THEMES[UpgradeTree.theme_of(Projector.THEMES, id)][0]).override_failure_message(id).is_equal("GOLDEN")
	assert_array(Projector.THEMES[UpgradeTree.theme_of(Projector.THEMES, "stock_25")][2]).is_equal(["stock_25"])


## The x span [left, right] of the chain of nodes raising `stat`, but those whose id starts with `skip`.
func _span_of(stat: String, skip := "") -> Vector2:
	var span := Vector2(INF, -INF)
	for node: Dictionary in Projector.NODES:
		if node.get("add", {}).has(stat) and (skip == "" or not node.id.begins_with(skip)):
			span = Vector2(minf(span.x, node.at.x), maxf(span.y, node.at.x))
	return span


func test_the_three_limit_categories_stand_side_by_side_store_then_money_then_findings() -> void:
	# Chapter 3's columns; chapter 4's steps run on from their tops along the top of the sheet.
	var store := _span_of("storage_cap", "lead_lining_")
	var money := _span_of("coin_limit", "capital_")
	var findings := _span_of("findings_limit", "decay_archive_")
	assert_float(money.x).is_greater(store.y)
	assert_float(findings.x).is_greater(money.y)
	assert_float(findings.x - store.y).is_less(2.5)  # Neighbours, not across the sheet.


## The levels a condensing chain reaches from 1, buying from `root` down: [stat after each step].
func _chain_levels(root: String, stat: String) -> Array:
	var save := _stamped_but(["stars"])
	save.coins = 1 << 40
	save.findings = 1 << 40
	UpgradeDesk.apply("condense", save)
	var out := []
	var step := root
	while step != "":
		assert_bool(Projector.buy(step, save)).override_failure_message(step).is_true()
		out.append(save.get(stat))
		var next := ""
		for node: Dictionary in Projector.NODES:
			if node.parent == step and node.get("add", {}).has(stat):
				next = node.id
		step = next
	return out


func test_research_cabbages_have_their_own_condensing_chain_paid_in_findings_from_two_to_eight() -> void:
	assert_array(_chain_levels("condense_research", "research_condense")).is_equal([2, 3, 4, 6, 8])
	for node: Dictionary in Projector.NODES:
		if node.get("add", {}).has("research_condense"):
			assert_str(UpgradeTree.currency_of(node)).override_failure_message(node.id).is_equal("findings")
	assert_str(Projector.node_data("condense_research").parent).is_equal("dept_manual")


func test_golden_cabbages_have_their_own_condensing_chain_in_coins_from_two_to_six() -> void:
	assert_array(_chain_levels("condense_gold", "golden_condense")).is_equal([2, 3, 4, 6])
	for node: Dictionary in Projector.NODES:
		if node.get("add", {}).has("golden_condense"):
			assert_str(UpgradeTree.currency_of(node)).override_failure_message(node.id).is_equal("coins")
	assert_str(Projector.node_data("condense_gold").parent).is_equal("dept_manual")


func test_the_consultants_step_nodes_sit_between_reading_the_room_and_yield_optimisation() -> void:
	assert_str(Projector.node_data("consultant_step_2").parent).is_equal("consultant_mood")
	assert_str(Projector.node_data("consultant_step_5").parent).is_equal("consultant_step_2")
	assert_str(Projector.node_data("consultant_step_10").parent).is_equal("consultant_step_5")
	assert_str(Projector.node_data(Consultant.SMART).parent).is_equal("consultant_step_10")
	for step: Array in [["consultant_step_2", 350], ["consultant_step_5", 700], ["consultant_step_10", 1200]]:
		assert_int(Projector.node_data(step[0]).price).override_failure_message(step[0]).is_equal(step[1])


func test_express_engagement_follows_the_retainer_and_halves_the_consultants_tap_interval_again() -> void:
	assert_str(Projector.node_data(Consultant.EXPRESS).parent).is_equal("consultant_speed_2")
	var save := SaveGame.new()
	for id: String in ["consultant_speed_1", "consultant_speed_2", Consultant.EXPRESS]:
		Projector.apply(id, save)
	assert_float(save.consultant_interval).is_equal_approx(0.5, 0.0001)


func _old_save() -> SaveGame:
	var save := SaveGame.new()
	save.migration = 7
	return save


func test_an_old_saves_archive_steps_move_to_the_projector_without_raising_the_limit_again() -> void:
	var save := _old_save()
	save.farm_bought = PackedStringArray(["hand_2", "archive_1", "archive_2"])
	save.findings_limit = 200000
	UpgradeDesk.migrate(save)
	assert_array(Array(save.farm_bought)).is_equal(["hand_2"])
	assert_bool(save.tree_bought.has("archive_1") and save.tree_bought.has("archive_2")).is_true()
	assert_int(save.findings_limit).is_equal(200000)
	Projector.migrate_round_two(save)  # Safe to rerun.
	assert_int(save.tree_bought.count("archive_1")).is_equal(1)


func test_an_old_save_with_yield_optimisation_gets_the_consultants_steps_free() -> void:
	var save := _old_save()
	save.tree_bought = PackedStringArray(["consultant_speed_1", "consultant_mood", Consultant.SMART])
	save.coins = 123
	UpgradeDesk.migrate(save)
	for id: String in ["consultant_step_2", "consultant_step_5", "consultant_step_10"]:
		assert_bool(save.tree_bought.has(id)).override_failure_message(id).is_true()
	assert_int(save.coins).is_equal(123)
	var without := _old_save()
	without.tree_bought = PackedStringArray(["consultant_speed_1", "consultant_mood"])
	UpgradeDesk.migrate(without)
	assert_bool(without.tree_bought.has("consultant_step_2")).is_false()


func test_an_old_save_condensing_research_and_gold_keeps_each_at_the_plain_level_it_had_even_past_the_chains_top() -> void:
	var save := _old_save()
	save.stamped = PackedStringArray(["condense"])
	save.condense = 6
	save.tree_bought = PackedStringArray(["condense_research", "condense_gold", "condense_2", "condense_3", "condense_4"])
	UpgradeDesk.migrate(save)
	assert_int(save.research_condense).is_equal(6)
	assert_int(save.golden_condense).is_equal(6)
	for id: String in ["condense_research_3", "condense_research_4", "condense_research_6", "condense_gold_3", "condense_gold_4", "condense_gold_6"]:
		assert_bool(save.tree_bought.has(id)).override_failure_message(id).is_true()
	assert_bool(save.tree_bought.has("condense_research_8")).is_false()
	# Past a chain's top the whole chain is bought and the old level stays; a kind never condensed stays single.
	var high := _old_save()
	high.condense = 32
	high.tree_bought = PackedStringArray(["condense_gold"])
	UpgradeDesk.migrate(high)
	assert_int(high.golden_condense).is_equal(32)
	for id: String in ["condense_gold_3", "condense_gold_4", "condense_gold_6"]:
		assert_bool(high.tree_bought.has(id)).override_failure_message(id).is_true()
	assert_int(high.research_condense).is_equal(1)


## The average boost a lamp gives over a whole cycle: `mult` while it glows `time` s of every `every` + `time`.
func _cycle(mult: float, time: float, every: float) -> float:
	return 1.0 + (mult - 1.0) * time / (every + time)


func test_the_golden_lamps_trio_is_back_each_step_lifting_its_average_boost_by_about_a_quarter() -> void:
	var save := SaveGame.new()
	var last := _cycle(save.lamp_mult, save.lamp_time, save.lamp_every)
	for id: String in ["lamp_mult", "lamp_time", "lamp_every"]:
		Projector.apply(id, save)
		var now := _cycle(save.lamp_mult, save.lamp_time, save.lamp_every)
		assert_float(now / last).override_failure_message(id).is_greater_equal(1.18)
		last = now
	assert_float(save.lamp_mult).is_equal(8.0)
	assert_float(save.lamp_time).is_equal(30.0)
	assert_float(save.lamp_every).is_equal_approx(90.0, 0.001)
	assert_array(Projector.node_data("lamp_mult").needs).contains(["golden_lamp"])


func test_the_research_lights_trio_mirrors_the_lamps_and_waits_for_its_card() -> void:
	var save := SaveGame.new()
	var last := _cycle(save.lab_lamp_mult, save.lab_lamp_time, save.lab_lamp_every)
	for id: String in ["lab_lamp_mult", "lab_lamp_time", "lab_lamp_every"]:
		Projector.apply(id, save)
		var now := _cycle(save.lab_lamp_mult, save.lab_lamp_time, save.lab_lamp_every)
		assert_float(now / last).override_failure_message(id).is_greater_equal(1.18)
		last = now
	assert_array(Projector.node_data("lab_lamp_mult").needs).contains(["research_light"])
	assert_bool(Projector.is_shown("lab_lamp_mult", SaveGame.new())).is_false()


func test_golden_cabbages_join_the_research_light_with_its_last_node() -> void:
	var node := Projector.node_data(QaBay.LAB_GOLD)
	assert_str(node.parent).is_equal("lab_lamp_mult")
	assert_bool(node.has("mul") or node.has("add")).is_false()  # The lab reads tree_bought.


func test_the_pull_tab_is_gone_once_the_gun_is_bought() -> void:
	var save := SaveGame.new()
	assert_bool(Projector.pull_shown(true, false, save)).is_true()
	assert_bool(Projector.pull_shown(true, true, save)).is_false()  # At the farm TV.
	save.stamped.append(Projector.Events.GUN_CARD)
	assert_bool(Projector.pull_shown(true, false, save)).is_false()


# ---- Chapter 4, part 0: NUCLEAR ----

## The first node of each of chapter 4's projector chains.
const NUCLEAR_ROOTS: Array[String] = ["capital_1", "decay_archive_1", "lead_lining_1", "condense_10", "merge_top_5", "merge_speed_4",
		"fission_1", "isotope_1", "chain_reaction_1", "decay_sale_1", "decay_lab_1", "tongs_1"]


## The chain from `root` on (each step the child named like it), in order.
func _nuclear_chain(root: String) -> Array[String]:
	var out: Array[String] = [root]
	var found := true
	while found:
		found = false
		for node: Dictionary in Projector.NODES:
			if node.parent == out[-1] and node.id.get_slice("_", 0) == root.get_slice("_", 0):
				out.append(node.id)
				found = true
				break
	return out


## Every card stamped, every node before chapter 4 bought, chapter 3's ends of the chains it goes on
## from as the save holds them then, and coins and Findings without end.
func _rich() -> SaveGame:
	var save := _stamped_but([])
	var nuclear := []
	for root: String in NUCLEAR_ROOTS:
		nuclear += _nuclear_chain(root)
	for node: Dictionary in Projector.NODES:
		if node.id not in nuclear and not node.get("dept", false):
			save.tree_bought.append(node.id)
	save.coins = 1 << 60
	save.findings = 1 << 60
	save.coin_limit = 40000000
	save.findings_limit = 900000
	save.storage_cap = 999999
	save.merge_top = 10000
	save.merge_every = 0.25
	save.condense = 32
	save.research_mult = 20.0
	save.golden_lab = 25.0
	save.golden_sale = 20.0
	save.findings_per_cabbage = 6
	return save


## Buys `ids` in order: `stat` before the first and after each.
func _levels(save: SaveGame, ids: Array, stat: String) -> Array:
	var out := [save.get(stat)]
	for id: String in ids:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		out.append(save.get(stat))
	return out


func test_the_nuclear_rows_have_their_own_heading_and_wait_for_nuclear_research() -> void:
	var without := _stamped_but(["nuclear_research"])
	var stamped := _stamped_but([])
	for id: String in ["fission_1", "isotope_1"]:
		assert_bool(Projector.is_shown(id, without)).override_failure_message(id).is_false()
		assert_bool(Projector.is_shown(id, stamped)).override_failure_message(id).is_true()
	assert_str(Projector.THEMES[UpgradeTree.theme_of(Projector.THEMES, "fission_1")][0]).is_equal("NUCLEAR")
	# The other rows hang off FISSION PRICING I, the first step every nuclear row starts from.
	for root: String in ["isotope_1", "chain_reaction_1", "decay_lab_1", "decay_sale_1", "tongs_1"]:
		assert_str(Projector.node_data(root).parent).override_failure_message(root).is_equal("fission_1")


func test_each_nuclear_chain_waits_for_its_own_card() -> void:
	for pair: Array in [["capital_1", "print_numbers"], ["chain_reaction_1", "half_life"], ["decay_archive_1", "half_life"],
			["decay_lab_1", "half_life"], ["merge_top_5", "critical_mass"], ["merge_speed_4", "critical_mass"],
			["lead_lining_1", "lead_storage"], ["decay_sale_1", "lead_storage"], ["tongs_1", "reactor_machinery"],
			["condense_10", "enrichment_cascade"]]:
		assert_bool(Projector.is_shown(pair[0], _stamped_but([pair[1]]))).override_failure_message(pair[0]).is_false()
		assert_bool(Projector.is_shown(pair[0], _stamped_but([]))).override_failure_message(pair[0]).is_true()


func test_capital_takes_the_money_limit_from_forty_million_to_ten_billion_at_least_doubling_each_step() -> void:
	var save := _rich()
	var chain := _nuclear_chain("capital_1")
	var levels := _levels(save, chain, "coin_limit")
	assert_int(levels[-1]).is_equal(10000000000)
	for i in chain.size():
		assert_float(float(levels[i + 1]) / levels[i]).is_greater_equal(2.0)
		assert_int(Projector.node_data(chain[i]).price).override_failure_message(chain[i]).is_less(levels[i])


func test_the_decay_archive_takes_the_findings_limit_from_nine_hundred_thousand_to_ten_million_paid_in_findings() -> void:
	var save := _rich()
	var chain := _nuclear_chain("decay_archive_1")
	var levels := _levels(save, chain, "findings_limit")
	assert_int(levels[-1]).is_equal(10000000)
	for i in chain.size():
		assert_float(float(levels[i + 1]) / levels[i]).is_greater_equal(1.25)
		assert_str(UpgradeTree.currency_of(Projector.node_data(chain[i]))).is_equal("findings")
		assert_int(Projector.node_data(chain[i]).price).override_failure_message(chain[i]).is_less(levels[i])


func test_lead_lining_takes_storage_from_999999_to_ten_million() -> void:
	var levels := _levels(_rich(), _nuclear_chain("lead_lining_1"), "storage_cap")
	assert_int(levels[-1]).is_equal(10000000)
	for i in range(1, levels.size()):
		assert_float(float(levels[i]) / levels[i - 1]).is_greater_equal(1.25)


func test_merge_top_steps_from_ten_thousand_to_a_billion_each_landing_on_a_minted_coin_and_merges_come_four_times_as_often() -> void:
	var save := _rich()
	var top := _levels(save, _nuclear_chain("merge_top_5"), "merge_top")
	assert_array(top).is_equal([10000, 100000, 500000, 1000000, 10000000, 100000000, 1000000000])
	var every := _levels(save, _nuclear_chain("merge_speed_4"), "merge_every")
	assert_float(every[-1]).is_equal_approx(0.0625, 0.0001)


func test_fission_pricing_and_isotope_analysis_each_lift_a_third_a_step_about_ten_times_in_all() -> void:
	var save := _rich()
	var street := _levels(save, _nuclear_chain("fission_1"), "marketing")
	assert_int(street.size()).is_equal(9)
	assert_float(street[-1] / street[0]).is_between(9.0, 11.0)
	var lab := _levels(save, _nuclear_chain("isotope_1"), "findings_per_cabbage")
	assert_int(lab.size()).is_equal(9)
	for i in range(1, lab.size()):
		assert_float(float(lab[i]) / lab[i - 1]).override_failure_message("isotope step %d" % i).is_greater_equal(1.25)
	assert_float(float(lab[-1]) / lab[0]).is_between(9.0, 11.5)


func test_chain_reaction_and_the_decay_premiums_lift_what_they_name_by_a_quarter_or_more_each_step() -> void:
	var save := _rich()
	assert_bool(Projector.buy("fission_1", save)).is_true()  # Every row but FISSION PRICING hangs off its first step.
	var rows := {"chain_reaction_1": ["research_mult", 20.0, 85.0], "decay_lab_1": ["golden_lab", 25.0, 50.0], "decay_sale_1": ["golden_sale", 20.0, 50.0]}
	for root: String in rows:
		var levels := _levels(save, _nuclear_chain(root), rows[root][0])
		assert_float(levels[0]).override_failure_message(root).is_equal(rows[root][1])
		assert_float(levels[-1]).override_failure_message(root).is_equal(rows[root][2])
		for i in range(1, levels.size()):
			assert_float(levels[i] / levels[i - 1]).override_failure_message("%s step %d" % [root, i]).is_greater_equal(1.25)


func test_handled_with_tongs_multiplies_your_own_sales_and_research_by_half_again_four_times() -> void:
	var save := _rich()
	assert_bool(Projector.buy("fission_1", save)).is_true()
	var sale: float = save.own_sale
	var lab: float = save.own_lab
	_levels(save, _nuclear_chain("tongs_1"), "own_sale")
	assert_float(save.own_sale).is_equal_approx(sale * pow(1.5, 4), 0.001)
	assert_float(save.own_lab).is_equal_approx(lab * pow(1.5, 4), 0.001)


func test_the_enrichment_cascade_condenses_a_cabbage_to_48_64_then_96() -> void:
	assert_array(_levels(_rich(), _nuclear_chain("condense_10"), "condense")).is_equal([32, 48, 64, 96])


func test_every_nuclear_chain_gets_dearer_step_by_step() -> void:
	for root: String in NUCLEAR_ROOTS:
		var chain := _nuclear_chain(root)
		for i in range(1, chain.size()):
			assert_int(Projector.node_data(chain[i]).price).override_failure_message(chain[i]) \
					.is_greater(Projector.node_data(chain[i - 1]).price)
