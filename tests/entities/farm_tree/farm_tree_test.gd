extends GdUnitTestSuite

const SCENE := preload("res://entities/farm_tree/farm_tree.tscn")
## The farm's old one-off upgrades whose effects FarmScreen reads from farm_bought.
const CARRIED := ["seed_contract", "fertiliser", "irrigation", "greenhouse"]
const WORKER_NUMBERS := ["farm_hands", "farm_tractors", "farm_hand_speed", "farm_tractor_speed",
		"farm_hand_shift", "farm_tractor_shift"]
const ROUTES := ["farm_hand_route", "farm_tractor_route"]
## The hand harvest (GREEN THUMB) and how often a square grows golden.
const HARVEST_NUMBERS := ["hand_yield", "hand_replant", "golden_chance"]
## When the standing seed order buys and which pack.
const SEED_ORDER := ["farm_seed_reserve", "farm_seed_pack"]
## How long a ripe square waits before it rots (COLD CHAIN).
const ROT := ["rot_after"]

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


func test_every_farm_node_is_paid_in_findings_so_coins_stay_for_the_projector() -> void:
	for node: Dictionary in FarmTree.NODES:
		assert_str(UpgradeTree.currency_of(node)).override_failure_message(node.id).is_equal("findings")


func test_farm_nodes_only_change_worker_numbers_routes_the_hand_harvest_the_golden_chance_the_seed_order_and_the_rot_delay() -> void:
	for node: Dictionary in FarmTree.NODES:
		for stat: String in node.get("add", {}).keys() + node.get("mul", {}).keys():
			assert_bool(stat in WORKER_NUMBERS or stat in ROUTES or stat in HARVEST_NUMBERS or stat in SEED_ORDER or stat in ROT).override_failure_message("%s: %s" % [node.id, stat]).is_true()


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
	var save := _save(["seasonal_workforce"], 0, 1000000)
	assert_bool(FarmTree.buy("fertiliser", save)).is_false()
	assert_int(save.findings).is_equal(1000000)


func test_a_farm_tree_node_bought_with_findings_adds_a_farm_hand_and_goes_into_farm_bought() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce"], 0, 10000)
	save.farm_hands = 1
	assert_bool(FarmTree.buy("hand_2", save)).is_true()
	assert_int(save.farm_hands).is_equal(2)
	assert_int(save.findings).is_equal(10000 - FarmTree.price_of("hand_2", save))
	assert_array(Array(save.farm_bought)).is_equal(["hand_2"])
	assert_bool(save.tree_bought.is_empty()).is_true()


func test_a_farm_tree_node_bought_with_findings_sets_the_tractor_route() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation"], 0, 1000)
	save.farm_bought = PackedStringArray(["tractor_2"])
	assert_bool(FarmTree.buy("tractor_route", save)).is_true()
	assert_int(save.farm_tractor_route).is_equal(1)
	assert_int(save.findings).is_equal(1000 - FarmTree.price_of("tractor_route", save))


func test_overtime_and_double_shift_let_hands_and_tractors_do_one_more_job_a_trip() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation"], 0, 1000000)
	save.farm_bought = PackedStringArray(["hand_2", "tractor_2"])
	assert_bool(FarmTree.buy("hand_shift", save)).is_true()
	assert_bool(FarmTree.buy("tractor_shift", save)).is_true()
	assert_int(save.farm_hand_shift).is_equal(2)
	assert_int(save.farm_tractor_shift).is_equal(2)


func test_coins_do_not_pay_for_a_farm_node() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce"], 1000000, 0)
	assert_bool(FarmTree.buy("hand_2", save)).is_false()
	assert_int(save.coins).is_equal(1000000)


func test_a_node_waits_for_its_parent_and_is_bought_only_once() -> void:
	var save := _save(["farm_terminal"], 0, 1000000)
	assert_bool(FarmTree.buy("greenhouse", save)).is_false()
	assert_array(FarmTree.requirement("greenhouse", save)).is_equal(["REQUIRES:", "FERTILISER"])
	assert_bool(FarmTree.buy("fertiliser", save)).is_true()
	assert_bool(FarmTree.buy("fertiliser", save)).is_false()
	assert_bool(FarmTree.buy("greenhouse", save)).is_true()


func test_a_node_an_old_save_bought_without_its_parent_still_shows_as_bought() -> void:
	var save := _save(["farm_terminal"])
	save.farm_bought.append("greenhouse")  # From the old flat farm list, no fertiliser.
	assert_array(FarmTree.requirement("greenhouse", save)).is_empty()


func test_every_node_costs_something() -> void:
	for node: Dictionary in FarmTree.NODES:
		assert_int(node.price).override_failure_message(node.id).is_greater(0)


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


## Oswald at weight 700: the face the Findings counter's drums are printed in.
func _is_counter_face(font: Font) -> bool:
	var face := font as FontVariation
	return face != null and face.base_font.resource_path == "res://assets/fonts/Oswald.ttf" \
			and face.variation_opentype.get(TextServerManager.get_primary_interface().name_to_tag("wght")) == 700


func test_findings_on_channel_two_read_in_the_findings_counters_face_while_the_rest_stays_terminal() -> void:
	var save := SaveGame.new()
	save.coins = 120
	save.findings = 345
	SaveManager.save = save
	var screen: FarmTree = auto_free(SCENE.instantiate())
	add_child(screen)
	screen._process(0.0)
	var budget: RichTextLabel = screen.get_node("BudgetLine")
	# The figure, and only the figure, is the bold span: bold is the counter's face, normal the terminal's.
	assert_str(budget.text).ends_with("]¶345[/color][/b]")
	assert_bool(budget.text.get_slice("[b]", 0).contains("¶")).is_false()
	assert_bool(_is_counter_face(budget.get_theme_font("bold_font"))).is_true()
	assert_bool(_is_counter_face(budget.get_theme_font("normal_font"))).is_false()
	var tree: UpgradeTree = screen.get_node("Tree")
	assert_bool(_is_counter_face(tree.price_font)).is_true()
	assert_bool(_is_counter_face(tree.font)).is_false()


func test_the_findings_number_and_its_word_sit_on_one_baseline_level_with_the_title() -> void:
	var save := SaveGame.new()
	save.coins = 9000
	SaveManager.save = save
	var screen: FarmTree = auto_free(SCENE.instantiate())
	add_child(screen)
	var budget: RichTextLabel = screen.get_node("BudgetLine")
	var title: Label = screen.get_node("Title")
	# One rich text line lays every span on the tallest font's ascent: that is its baseline.
	var baseline := budget.position.y + maxf(
			budget.get_theme_font("normal_font").get_ascent(budget.get_theme_font_size("normal_font_size")),
			budget.get_theme_font("bold_font").get_ascent(budget.get_theme_font_size("bold_font_size")))
	var title_baseline := title.position.y + title.get_theme_font("font").get_ascent(title.get_theme_font_size("font_size"))
	assert_float(baseline).is_equal_approx(title_baseline, 1.0)
	var was := TranslationServer.get_locale()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for findings: int in [7, 950, 12400]:
			save.findings = findings
			screen._process(0.0)
			var said := "%s %d" % [locale, findings]
			assert_int(budget.get_line_count()).override_failure_message(said).is_equal(1)
			assert_str(budget.get_parsed_text()).override_failure_message(said) \
					.ends_with(" %s ¶%d" % ["FINDINGS" if locale == "en" else "BEFUNDE", findings])
	TranslationServer.set_locale(was)


func test_each_farm_heading_sits_on_its_branch_between_the_hub_and_its_first_node() -> void:
	for heading: Array in FarmTree.THEMES:
		assert_float(UpgradeTree.heading_bend(FarmTree, heading)).override_failure_message(heading[0]).is_less_equal(30.5)


func test_the_golden_chance_lives_on_the_farm_tree_and_climbs_from_one_in_forty_to_one_in_ten() -> void:
	var save := _save(["farm_terminal", "golden_cabbage"], 0, 1000000)
	var odds: Array[int] = [roundi(1.0 / save.golden_chance)]
	for id: String in ["gold_chance_1", "gold_chance_2", "gold_chance_3"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
		odds.append(roundi(1.0 / save.golden_chance))
	assert_array(odds).is_equal([40, 25, 15, 10])
	for node: Dictionary in Projector.NODES:
		assert_bool(node.get("add", {}).has("golden_chance") or node.get("mul", {}).has("golden_chance")).override_failure_message(node.id).is_false()


func test_golden_nodes_wait_for_the_golden_card_and_hand_nodes_for_green_thumb() -> void:
	var save := _save(["farm_terminal"], 0, 1000000)
	assert_bool(FarmTree.is_shown("gold_chance_1", save)).is_false()
	assert_bool(FarmTree.is_shown("thumb_yield", save)).is_false()
	save.stamped.append("golden_cabbage")
	save.stamped.append("green_thumb")
	assert_bool(FarmTree.can_buy("gold_chance_1", save)).is_true()
	assert_bool(FarmTree.can_buy("thumb_yield", save)).is_true()


func test_employee_of_the_month_makes_a_hand_harvest_triple_and_one_in_one_out_replants() -> void:
	var save := _save(["farm_terminal", "green_thumb"], 0, 1000000)
	FarmTree.buy("thumb_yield", save)
	FarmTree.buy("thumb_replant", save)
	assert_float(save.hand_yield).is_equal(3.0)
	assert_int(save.hand_replant).is_equal(1)


func test_the_seed_order_nodes_wait_for_its_card_then_reorder_at_twenty_and_buy_the_fifty_pack() -> void:
	var save := _save(["farm_terminal"], 0, 100000)
	save.farm_bought.append("seed_contract")
	assert_bool(FarmTree.is_shown("seed_reserve", save)).is_false()
	save.stamped.append(FarmScreen.AUTO_CARD)
	assert_bool(FarmTree.can_buy("seed_bulk", save)).is_false()  # Its parent first.
	assert_int(FarmTree.price_of("seed_bulk", save)).is_greater(FarmTree.price_of("seed_reserve", save) * 2)  # A step up.
	# Comfort, not growth: both together cost less than the second tractor.
	assert_int(FarmTree.price_of("seed_reserve", save) + FarmTree.price_of("seed_bulk", save)).is_less(FarmTree.price_of("tractor_2", save))
	assert_bool(FarmTree.buy("seed_reserve", save)).is_true()
	assert_int(save.farm_seed_reserve).is_equal(20)
	assert_bool(FarmTree.buy("seed_bulk", save)).is_true()
	assert_int(FarmScreen.SEED_PACKS[save.farm_seed_pack][0]).is_equal(50)


func test_the_cold_chain_waits_for_the_golden_card_and_stretches_the_rot_from_three_to_twelve_minutes() -> void:
	var save := _save(["farm_terminal"], 0, 1000000)
	assert_bool(FarmTree.is_shown("cold_frames", save)).is_false()
	save.stamped.append("golden_cabbage")  # A minute before the rot starts.
	var waits: Array[float] = [save.rot_after]
	for id: String in ["cold_frames", "refrigerated_tarpaulin", "shelf_life_review"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
		waits.append(save.rot_after)
	assert_array(waits).is_equal([180.0, 300.0, 480.0, 720.0])
