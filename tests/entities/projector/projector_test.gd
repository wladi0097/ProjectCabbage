extends GdUnitTestSuite

const SALES_NODES: Array[String] = ["lamp_mult", "lamp_time", "lamp_every", "combo_window", "combo_cap",
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
	assert_str(Projector.requirement("qa_time", save)[0]).is_equal("REQUIRES RESEARCH:")
	save.stamped.append("research_inspection")
	assert_bool(Projector.is_open("dept_qa", save)).is_true()
	assert_bool(Projector.can_hold("qa_time", save)).is_true()


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
	var save := _save(["projector", "junior_associate", "performance_review"], 10000000)
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
	assert_str(Projector.requirement("hire_associate_5", save)[0]).is_equal("REQUIRES RESEARCH:")
	assert_str(Projector.requirement("manager_time", save)[0]).is_equal("REQUIRES DESK CARD:")
	assert_str(Projector.requirement("conveyor_1", save)[0]).starts_with("REQUIRES")
	assert_array(Projector.requirement("discount_1", save)).is_empty()
	assert_bool(Projector.can_hold("discount_1", save)).is_true()


func test_everything_bought_fills_the_mat_to_twenty_and_hires_every_visible_hand() -> void:
	var full := SaveGame.new()
	UpgradeDesk.apply("desk_space", full)
	UpgradeDesk.apply("junior_associate", full)
	UpgradeDesk.apply("coin_collector", full)
	UpgradeDesk.apply("mat_allowance", full)
	for node: Dictionary in Projector.NODES:
		Projector.apply(node.id, full)
	assert_int(full.desk_capacity).is_equal(20)
	assert_int(full.hands).is_equal(Associate.MAX_VISIBLE)
	assert_float(full.hand_output).is_equal_approx(2.25, 0.0001)
	assert_int(full.qa_slots).is_equal(3)
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


func test_the_mat_chain_is_one_node_per_unit_from_the_fourth_to_the_twentieth_each_under_the_last() -> void:
	for unit in range(Projector.MAT_FIRST, Projector.MAT_MAX + 1):
		var node := Projector.node_data("mat_%d" % unit)
		assert_dict(node).override_failure_message("unit %d" % unit).is_not_empty()
		assert_str(node.parent).is_equal("dept_manual" if unit == Projector.MAT_FIRST else "mat_%d" % (unit - 1))
		assert_dict(node.add).is_equal({desk_capacity = 1})
	assert_dict(Projector.node_data("mat_%d" % (Projector.MAT_MAX + 1))).is_empty()


func test_each_mat_step_adds_one_and_costs_more_than_the_last_starting_at_the_old_fourth_unit_price() -> void:
	var save := _save(["projector", "mat_allowance"], 1000000000)
	save.desk_capacity = 3
	var last := 0
	for unit in range(Projector.MAT_FIRST, Projector.MAT_MAX + 1):
		var id := "mat_%d" % unit
		var price := Projector.price_of(id, save)
		assert_float(float(price)).override_failure_message("unit %d at $%d" % [unit, price]).is_greater(last * 1.3)
		assert_bool(Projector.buy(id, save)).is_true()
		assert_int(save.desk_capacity).is_equal(unit)
		last = price
	assert_int(Projector.price_of("mat_4", save)).is_equal(2100)
	assert_int(Projector.price_of("mat_20", save)).is_equal(457350)


func test_a_bought_mat_step_is_never_bought_again() -> void:
	var save := _save(["projector", "mat_allowance"], 1000000000)
	save.desk_capacity = 3
	assert_bool(Projector.buy("mat_4", save)).is_true()
	var coins := save.coins
	assert_bool(Projector.can_hold("mat_4", save)).is_false()
	assert_bool(Projector.buy("mat_4", save)).is_false()
	assert_int(save.coins).is_equal(coins)
	assert_int(save.desk_capacity).is_equal(4)


func test_storage_grows_from_20_to_9999_in_six_steps_each_at_least_doubling() -> void:
	var save := _save(["projector"], 1000000000)
	var caps := [save.storage_cap]
	assert_bool(Projector.buy("pack_1", save)).is_true()
	for step in range(1, 7):
		assert_bool(Projector.buy("storage_%d" % step, save)).override_failure_message("step %d" % step).is_true()
		caps.append(save.storage_cap)
	assert_array(caps).is_equal([20, 75, 200, 500, 1500, 4000, 9999])
	for i in range(1, caps.size()):
		assert_float(float(caps[i]) / caps[i - 1]).is_greater_equal(2.0)


func test_container_orders_wait_for_the_stock_room_since_53_units_would_not_fit_in_20() -> void:
	assert_str(Projector.node_data("pack_2").parent).is_equal("storage_1")
	var cap: int = SaveGame.new().storage_cap + Projector.node_data("storage_1").add.storage_cap
	var pack: int = SaveGame.new().pack_size + Projector.node_data("pack_1").add.pack_size + Projector.node_data("pack_2").add.pack_size
	assert_int(cap).is_greater_equal(pack + 10)  # Room for the pack above the safety-stock reserve.


func test_an_old_save_with_container_orders_gets_the_stock_room_once() -> void:
	var save := _save(["projector"])
	save.tree_bought = PackedStringArray(["pack_1", "pack_2"])
	Projector.migrate_storage(save)
	Projector.migrate_storage(save)
	assert_int(save.tree_bought.count("storage_1")).is_equal(1)
	assert_int(save.storage_cap).is_equal(75)


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


func test_an_old_full_mat_keeps_twenty_and_has_nothing_left_to_buy() -> void:
	var save := _save(["projector", "mat_allowance"], 1000000000)
	save.desk_capacity = 20
	Projector.migrate_mat(save)
	assert_int(save.desk_capacity).is_equal(20)
	assert_bool(Projector.can_hold("mat_20", save)).is_false()


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
	assert_bool(Projector.is_shown("slogan_6", save)).is_true()
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


func test_an_old_mat_of_four_stamping_the_allowance_keeps_its_units_and_tops_out_at_twenty() -> void:
	var save := _save(["projector", "coin_collector", "desk_space"], 1000000000)
	save.desk_capacity = 4
	save.stamped.append("mat_allowance")
	UpgradeDesk.apply("mat_allowance", save)
	assert_int(save.desk_capacity).is_equal(4)
	assert_bool(Projector.is_bought("mat_4", save)).is_true()
	for unit in range(Projector.MAT_FIRST + 1, Projector.MAT_MAX + 1):
		assert_bool(Projector.buy("mat_%d" % unit, save)).override_failure_message("unit %d" % unit).is_true()
		assert_int(save.desk_capacity).is_equal(unit)
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
