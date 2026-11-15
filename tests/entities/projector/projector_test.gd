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


func test_every_upgrade_hangs_under_exactly_one_department_and_only_departments_sit_on_the_hub() -> void:
	for node: Dictionary in Projector.NODES:
		var top := node
		while top.parent != "":
			top = Projector.node_data(top.parent)
		assert_bool(top.get("dept", false)).override_failure_message("%s hangs under no department" % node.id).is_true()
		assert_bool(node.parent == "").override_failure_message(node.id).is_equal(node.get("dept", false))


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
	assert_int(full.condense).is_equal(31)  # CONDENSE II to IX on a save without the card's own step.
	assert_float(full.restock_delay).is_equal_approx(SaveGame.new().restock_delay / 4.0, 0.0001)  # CONVEYOR II and III.
	assert_float(full.hand_output).is_equal_approx(2.25, 0.0001)
	assert_int(full.qa_slots).is_equal(5)
	assert_int(full.vacuums).is_equal(3)
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


func test_storage_grows_from_20_to_15000_in_many_small_steps_each_at_least_a_quarter_more_room() -> void:
	var save := _save(["projector", "offsite_storage", "big_ideas"], 1000000000)
	var caps := [save.storage_cap]
	var prices := [0]
	for id: String in _storage_chain():
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
		caps.append(save.storage_cap)
		prices.append(Projector.price_of(id, save))
	assert_int(caps.size()).is_greater_equal(16)
	assert_int(caps[1]).is_equal(25)
	assert_int(caps[-1]).is_equal(15000)
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
		var line := "Storage holds %s cabbages instead of %s." % [_grouped(Projector.cap_at(id)), _grouped(old_cap)]
		assert_str(node.body).override_failure_message(id).ends_with(line)
		assert_str(node.body.get_slice("\n", 0)).override_failure_message(id).is_not_equal(line)  # A flavour line first.


func _grouped(n: int) -> String:
	return "%d,%03d" % [floori(n / 1000.0), n % 1000] if n >= 1000 else str(n)


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


func test_the_affordable_count_is_the_number_of_upgrades_a_budget_covers() -> void:
	var upgrades := _upgrades()
	assert_int(Projector.affordable(0)).is_equal(0)
	assert_int(Projector.affordable(1 << 30)).is_equal(upgrades.size())
	assert_int(Projector.affordable(40)).is_equal(upgrades.filter(func(node: Dictionary) -> bool: return node.price <= 40).size())


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
	var save := _save(["projector", "offsite_storage", "golden_cabbage", "big_ideas", "cash_holding"], 10000000)
	save.tree_bought = PackedStringArray(["storage_2", "gold_sale_1"])
	assert_bool(Projector.is_shown(SaleWindow.GOLD_AGE, save)).is_false()
	save.stamped.append("golden_lamp")
	assert_bool(Projector.is_shown(SaleWindow.GOLD_AGE, save)).is_true()
	assert_bool(Projector.buy(SaleWindow.GOLD_AGE, save)).is_true()
	assert_bool(save.tree_bought.has(SaleWindow.GOLD_AGE)).is_true()


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


## Chapter 3 (desk cards big_ideas, condense). The first node of each late-game run moved behind
## BIG MINDS HAVE BIG IDEAS, and the nodes that only exist on the wide sheet.
const LATE: Array[String] = ["slogan_6", "hire_associate_7", "conveyor_3", "gold_age", "bin_rebate_5", "research_mult_4",
		"own_sale_3", "own_lab_3", "research_chance_3", "grow_4", "double_findings", "gold_sale_2", "gold_lab_2", "stock_3000"]
const WIDE_ONLY: Array[String] = ["slogan_7", "slogan_8", "mandatory_consumption", "headcount_2", "two_handed",
		"condense_research", "condense_gold", "condense_2", "condense_3", "condense_4", "condense_5",
		"condense_6", "condense_7", "condense_8", "condense_9"]


## Every desk card stamped but `missing`.
func _stamped_but(missing: Array) -> SaveGame:
	var save := SaveGame.new()
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in missing:
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


func test_the_condensation_branch_opens_with_condensed_samples_and_climbs_to_thirty_two_cabbages_in_one() -> void:
	var save := _stamped_but(["stars"])
	save.coins = 100000000
	UpgradeDesk.apply("condense", save)
	assert_bool(Projector.can_buy("condense_2", save)).is_false()  # Samples first.
	for id: String in ["condense_research", "condense_gold", "condense_2", "condense_3"]:
		assert_bool(Projector.buy(id, save)).override_failure_message(id).is_true()
	assert_int(save.condense).is_equal(4)
	# Each of II and III is felt: +50%, then +33% on what a condensed cabbage holds.
	assert_float(4.0 / 3.0).is_greater_equal(1.25)
	# IV to IX (the mat stops at ten, so what follows the farm is what a cabbage holds): +50% and +33% in turn.
	for step: Array in [["condense_4", 6], ["condense_5", 8], ["condense_6", 12], ["condense_7", 16], ["condense_8", 24], ["condense_9", 32]]:
		var was := save.condense
		assert_bool(Projector.buy(step[0], save)).override_failure_message(step[0]).is_true()
		assert_int(save.condense).is_equal(step[1])
		assert_float(float(save.condense) / was).is_greater_equal(1.25)


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
