extends GdUnitTestSuite

const Desk := preload("res://entities/upgrade_desk/upgrade_desk.gd")
const Nodes := preload("res://entities/projector/projector.gd")
const Events := preload("res://globalScripts/game_events.gd")
const SALES_CARDS: Array[String] = ["golden_lamp", "catch_combo", "window_targets"]
const SALES_NODES: Array[String] = ["lamp_mult", "lamp_time", "lamp_every", "combo_window", "combo_cap",
		"combo_step", "bin_mouth", "bin_rebate", "bin_rebate_2", "bin_rebate_3", "bin_rebate_4", "bin_rebate_5",
		"hands_bin", "target_size", "target_every", "target_shower"]


func test_every_big_event_starts_from_a_real_desk_card_or_save_flag() -> void:
	for id: String in Events.EVENTS:
		var event: Dictionary = Events.EVENTS[id]
		if event.has("card"):
			assert_dict(Desk.card_data(event.card)).override_failure_message("event " + id).is_not_empty()
		else:
			assert_bool(event.flag in SaveGame.new()).override_failure_message("event " + id).is_true()


func test_a_flag_event_starts_once_its_save_flag_is_set() -> void:
	var slate := SaveGame.new()
	slate.slate_unlocked = true

	assert_bool(Events.due("mood_drift", slate)).is_true()
	assert_bool(Events.due("mood_drift", SaveGame.new())).is_false()


func test_every_sales_event_has_a_desk_card() -> void:
	for id in SALES_CARDS:
		assert_dict(Desk.card_data(id)).override_failure_message("card " + id).is_not_empty()


func test_every_sales_event_tree_node_changes_a_real_save_number() -> void:
	for id in SALES_NODES:
		var save := SaveGame.new()
		var node := Nodes.node_data(id)
		var was := {}
		for stat: String in node.get("mul", {}).keys() + node.get("add", {}).keys():
			was[stat] = save.get(stat)
		Nodes.apply(id, save)

		assert_dict(was).override_failure_message("node " + id).is_not_empty()
		for stat: String in was:
			assert_bool(save.get(stat) != was[stat]).override_failure_message("node %s stat %s" % [id, stat]).is_true()
