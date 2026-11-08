extends GdUnitTestSuite

const SCENE := preload("res://entities/farm_tree/farm_tree.tscn")
## The farm's old one-off upgrades whose effects FarmScreen reads from farm_bought.
const CARRIED := ["seed_contract", "fertiliser", "irrigation", "greenhouse"]
const WORKER_NUMBERS := ["farm_hands", "farm_tractors", "farm_hand_speed", "farm_tractor_speed",
		"farm_hand_shift", "farm_tractor_shift"]
const ROUTES := ["farm_hand_route", "farm_tractor_route"]

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


func _save(cards: Array, coins := 0, findings := 0) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(cards)
	save.coins = coins
	save.findings = findings
	return save


func test_every_node_has_a_unique_id_and_a_known_parent() -> void:
	var ids := FarmTree.NODES.map(func(node: Dictionary) -> String: return node.id)
	for node: Dictionary in FarmTree.NODES:
		assert_int(ids.count(node.id)).override_failure_message(node.id).is_equal(1)
		assert_bool(node.parent == "" or ids.has(node.parent)).override_failure_message(node.id).is_true()


func test_the_old_farm_upgrades_keep_their_ids_on_the_tree() -> void:
	for id: String in CARRIED:
		assert_dict(FarmTree.node_data(id)).override_failure_message(id).is_not_empty()


func test_coins_buy_more_workers_and_speed_and_findings_buy_their_routes() -> void:
	for node: Dictionary in FarmTree.NODES:
		var stats: Array = node.get("add", {}).keys() + node.get("mul", {}).keys()
		for stat: String in stats:
			assert_bool(stat in WORKER_NUMBERS or stat in ROUTES).override_failure_message("%s: %s" % [node.id, stat]).is_true()
			var want := "findings" if stat in ROUTES else "coins"
			assert_str(UpgradeTree.currency_of(node)).override_failure_message(node.id).is_equal(want)


func test_every_number_a_node_changes_is_tracked_by_the_save() -> void:
	var save := SaveGame.new()
	for node: Dictionary in FarmTree.NODES:
		for stat: String in node.get("add", {}).keys() + node.get("mul", {}).keys():
			assert_bool(stat in save).override_failure_message("%s: %s" % [node.id, stat]).is_true()


func test_hand_nodes_wait_for_the_seasonal_workforce_and_tractor_nodes_for_mechanisation() -> void:
	var save := _save(["farm_terminal"], 1000000, 100000)
	assert_bool(FarmTree.is_shown("hand_2", save)).is_false()
	assert_bool(FarmTree.is_shown("hand_route", save)).is_false()
	assert_bool(FarmTree.is_shown("tractor_2", save)).is_false()
	save.stamped.append("seasonal_workforce")
	assert_bool(FarmTree.is_shown("hand_route", save)).is_true()
	assert_bool(FarmTree.can_buy("hand_2", save)).is_true()
	assert_bool(FarmTree.is_shown("tractor_3", save)).is_false()
	save.stamped.append("mechanisation")
	assert_bool(FarmTree.can_buy("tractor_2", save)).is_true()


func test_nothing_is_bought_before_the_farm_terminal_is_stamped() -> void:
	var save := _save(["seasonal_workforce"], 1000000)
	assert_bool(FarmTree.buy("fertiliser", save)).is_false()
	assert_int(save.coins).is_equal(1000000)


func test_a_farm_tree_node_bought_with_coins_adds_a_farm_hand_and_goes_into_farm_bought() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce"], 10000)
	save.farm_hands = 1
	assert_bool(FarmTree.buy("hand_2", save)).is_true()
	assert_int(save.farm_hands).is_equal(2)
	assert_int(save.coins).is_equal(10000 - FarmTree.price_of("hand_2", save))
	assert_array(Array(save.farm_bought)).is_equal(["hand_2"])
	assert_bool(save.tree_bought.is_empty()).is_true()


func test_a_farm_tree_node_bought_with_findings_sets_the_tractor_route() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation"], 0, 1000)
	save.farm_bought = PackedStringArray(["tractor_2"])
	assert_bool(FarmTree.buy("tractor_route", save)).is_true()
	assert_int(save.farm_tractor_route).is_equal(1)
	assert_int(save.findings).is_equal(1000 - FarmTree.price_of("tractor_route", save))


func test_overtime_and_double_shift_let_hands_and_tractors_do_one_more_job_a_trip() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation"], 1000000)
	save.farm_bought = PackedStringArray(["hand_2", "tractor_2"])
	assert_bool(FarmTree.buy("hand_shift", save)).is_true()
	assert_bool(FarmTree.buy("tractor_shift", save)).is_true()
	assert_int(save.farm_hand_shift).is_equal(2)
	assert_int(save.farm_tractor_shift).is_equal(2)


func test_findings_do_not_pay_for_a_coin_node_nor_coins_for_a_findings_node() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce"], 0, 1000000)
	assert_bool(FarmTree.buy("hand_2", save)).is_false()
	save = _save(["farm_terminal", "seasonal_workforce"], 1000000, 0)
	save.farm_bought = PackedStringArray(["hand_2"])
	assert_bool(FarmTree.buy("hand_route", save)).is_false()


func test_a_node_waits_for_its_parent_and_is_bought_only_once() -> void:
	var save := _save(["farm_terminal"], 1000000)
	assert_bool(FarmTree.buy("greenhouse", save)).is_false()
	assert_array(FarmTree.requirement("greenhouse", save)).is_equal(["REQUIRES:", "FERTILISER"])
	assert_bool(FarmTree.buy("fertiliser", save)).is_true()
	assert_bool(FarmTree.buy("fertiliser", save)).is_false()
	assert_bool(FarmTree.buy("greenhouse", save)).is_true()


func test_every_node_costs_something_and_coin_prices_stay_near_the_old_farm_list() -> void:
	for node: Dictionary in FarmTree.NODES:
		assert_int(node.price).override_failure_message(node.id).is_greater(0)
		if UpgradeTree.currency_of(node) == "coins":
			assert_int(node.price).override_failure_message(node.id).is_between(2500, 30000)


func test_no_two_nodes_sit_on_the_same_spot_and_every_heading_names_real_first_nodes() -> void:
	for a: Dictionary in FarmTree.NODES:
		assert_float(a.at.length()).override_failure_message("%s on the hub" % a.id).is_greater(0.4)
		for b: Dictionary in FarmTree.NODES:
			if a.id != b.id:
				assert_float(a.at.distance_to(b.at)).override_failure_message("%s / %s" % [a.id, b.id]).is_greater(0.35)
	for heading: Array in FarmTree.THEMES:
		for id: String in heading[2]:
			assert_dict(FarmTree.node_data(id)).override_failure_message(heading[0]).is_not_empty()


func test_channel_two_is_locked_until_the_farm_terminal_is_stamped() -> void:
	var save := SaveGame.new()
	SaveManager.save = save
	var screen: FarmTree = auto_free(SCENE.instantiate())
	add_child(screen)
	screen._process(0.0)
	assert_bool(screen.get_node("Locked").visible).is_true()
	assert_bool(screen.get_node("Tree").visible).is_false()
	save.stamped.append("farm_terminal")
	screen._process(0.0)
	assert_bool(screen.get_node("Locked").visible).is_false()
	assert_bool(screen.get_node("Tree").visible).is_true()


func test_the_farm_tree_is_drawn_in_the_screens_green_phosphor() -> void:
	var screen: FarmTree = auto_free(SCENE.instantiate())
	var tree: UpgradeTree = screen.get_node("Tree")
	assert_object(tree.ink).is_equal(Color(0.88, 0.94, 0.89))
	assert_object(tree.ground).is_equal(Color(0.05, 0.07, 0.06))


func test_each_farm_heading_sits_on_its_branch_between_the_hub_and_its_first_node() -> void:
	for heading: Array in FarmTree.THEMES:
		assert_float(UpgradeTree.heading_bend(FarmTree, heading)).override_failure_message(heading[0]).is_less_equal(30.5)
