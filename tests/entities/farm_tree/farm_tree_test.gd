extends GdUnitTestSuite

const SCENE := preload("res://entities/farm_tree/farm_tree.tscn")
## The farm's old one-off upgrades whose effects FarmScreen reads from farm_bought.
const CARRIED := ["seed_contract", "fertiliser", "irrigation", "greenhouse"]
const WORKER_NUMBERS := ["farm_hands", "farm_tractors", "farm_hand_speed", "farm_tractor_speed",
		"farm_hand_shift", "farm_tractor_shift"]
const ROUTES := ["farm_hand_route", "farm_tractor_route"]
## The hand harvest (GREEN THUMB) and how often a square grows golden.
const HARVEST_NUMBERS := ["hand_yield", "hand_replant", "golden_chance", "farm_hand_share"]
## When the standing seed order buys and which pack.
const SEED_ORDER := ["farm_seed_reserve", "farm_seed_pack"]
## How long a ripe square waits before it rots (COLD CHAIN).
const ROT := ["rot_after"]
## What a farm square harvests, times a plain square (FARM OUTPUT).
const FARM_OUTPUT := ["farm_square_mult"]
## Seeds a farm square holds (SEED BEDS).
const SEED_BEDS := ["farm_slots"]
## FIELD THINNING minis out at once (THINNING).
const THINNING := ["thinning_cap"]
## How long a square takes to ripen (chapter 4's ACCELERATED RIPENING).
const GROWTH := ["farm_grow_mult"]
## Chapter 4's NUCLEAR cards, which open the farm tree's furthest runs.
const NUCLEAR_CARDS := ["nuclear_research", "isotope_seed", "reactor_machinery", "nuclear_family"]
## The outer ring: what only shows once the desk card STRUCTURED FARM is stamped. Its own nodes, and
## the late steps that moved behind it.
const RING: Array[String] = ["farm_slots_1", "farm_slots_2", "farm_slots_3", "hand_route_2", "hand_shift_2"]
const MOVED: Array[String] = ["farm_mult_2", "farm_mult_3"]

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


func test_farm_nodes_only_change_worker_numbers_routes_the_hand_harvest_the_golden_chance_the_seed_order_the_rot_delay_farm_output_seed_beds_the_thinning_cap_and_the_ripening_time() -> void:
	for node: Dictionary in FarmTree.NODES:
		for stat: String in node.get("add", {}).keys() + node.get("mul", {}).keys():
			assert_bool(stat in WORKER_NUMBERS or stat in ROUTES or stat in HARVEST_NUMBERS or stat in SEED_ORDER or stat in ROT or stat in FARM_OUTPUT or stat in SEED_BEDS or stat in THINNING or stat in GROWTH).override_failure_message("%s: %s" % [node.id, stat]).is_true()


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
					.ends_with(" %s ¶%s" % ["FINDINGS" if locale == "en" else "BEFUNDE", Num.text(findings)])
	TranslationServer.set_locale(was)


func test_each_farm_heading_sits_on_its_branch_between_the_hub_and_its_first_node() -> void:
	for heading: Array in FarmTree.THEMES:
		assert_float(UpgradeTree.heading_bend(FarmTree, heading)).override_failure_message(heading[0]).is_less_equal(30.5)


func test_the_golden_chance_lives_on_the_farm_tree_and_climbs_from_one_in_forty_to_one_in_ten() -> void:
	var save := _save(["farm_terminal", "golden_cabbage", "archive_capacity"], 0, 1000000)  # GILDED STRAIN (¶9,000) waits for the archive card.
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


func test_green_thumb_on_farm_squares_waits_for_a_farm_then_climbs_from_a_quarter_to_a_half_to_all_of_it_once_the_archive_grows() -> void:
	var save := _save(["farm_terminal", "green_thumb"], 0, 1000000)
	FarmTree.buy("thumb_yield", save)
	assert_bool(FarmTree.is_shown("farm_hand_1", save)).is_false()
	save.farms_owned.append("site_a")
	assert_bool(FarmTree.is_shown("farm_hand_1", save)).is_true()
	assert_bool(FarmTree.is_shown("farm_hand_2", save)).is_false()  # ¶12,000 passes the ¶8,000 archive.
	save.stamped.append("archive_capacity")
	assert_bool(FarmTree.is_shown("farm_hand_2", save)).is_true()
	var shares: Array[float] = [save.farm_hand_share]
	for id: String in ["farm_hand_1", "farm_hand_2", "farm_hand_3"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
		shares.append(save.farm_hand_share)
	assert_array(shares).is_equal([0.0, 0.25, 0.5, 1.0])


func test_each_green_thumb_farm_step_is_felt_on_a_hand_pulled_farm_square() -> void:
	var save := _save(["farm_terminal", "green_thumb", "archive_capacity"], 0, 1000000)
	save.farms_owned.append("site_a")
	save.farm_squares.append(0)
	FarmTree.buy("thumb_yield", save)  # EMPLOYEE OF THE MONTH (×3), the chain's parent.
	var was := FarmScreen.hand_factor(save, 0)
	assert_float(was).is_equal(1.0)
	for id: String in ["farm_hand_1", "farm_hand_2", "farm_hand_3"]:
		FarmTree.buy(id, save)
		var now := FarmScreen.hand_factor(save, 0)
		assert_float(now / was).override_failure_message(id).is_greater_equal(1.25)
		was = now


func test_farm_squares_grow_golden_only_after_the_estate_seed_node_under_the_golden_chance() -> void:
	var save := _save(["farm_terminal", "golden_cabbage"], 0, 1000000)
	assert_str(FarmTree.node_data(FarmScreen.FARM_GOLD).parent).is_equal("gold_chance_1")
	FarmTree.buy("gold_chance_1", save)
	assert_bool(FarmTree.is_shown(FarmScreen.FARM_GOLD, save)).is_false()  # No farm yet.
	save.farms_owned.append("site_a")
	assert_bool(FarmTree.buy(FarmScreen.FARM_GOLD, save)).is_true()
	assert_bool(save.farm_bought.has(FarmScreen.FARM_GOLD)).is_true()


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


func test_the_farm_output_branch_shows_only_once_a_farm_is_owned() -> void:
	var save := _save(["farm_terminal", "archive_capacity"], 0, 1000000)  # ¶15,000: more than the first purse holds.
	assert_bool(FarmTree.is_shown("farm_mult_1", save)).is_false()
	assert_bool(FarmTree.can_buy("farm_mult_1", save)).is_false()
	var heading := FarmTree.THEMES.map(func(theme: Array) -> String: return theme[0]).find("FARM OUTPUT")
	assert_bool(FarmTree.themes_shown(save)[heading]).is_false()
	save.farms_owned.append("site_a")
	assert_bool(FarmTree.is_shown("farm_mult_1", save)).is_true()
	assert_bool(FarmTree.is_shown("farm_mult_3", save)).is_false()  # x20 and x30 wait for STRUCTURED FARM.
	assert_bool(FarmTree.can_buy("farm_mult_1", save)).is_true()
	save.stamped.append("structured_farm")
	assert_bool(FarmTree.is_shown("farm_mult_3", save)).is_true()


func test_farm_output_nodes_raise_every_farm_squares_multiplier_from_ten_to_fifteen_twenty_then_thirty() -> void:
	var save := _save(["farm_terminal", "archive_capacity", "structured_farm"], 0, 1000000)
	save.farms_owned.append("site_a")
	assert_float(save.farm_square_mult).is_equal(10.0)
	for step: Array in [["farm_mult_1", 15.0], ["farm_mult_2", 20.0], ["farm_mult_3", 30.0]]:
		assert_bool(FarmTree.buy(step[0], save)).override_failure_message(step[0]).is_true()
		assert_float(save.farm_square_mult).is_equal(step[1])


func test_farm_output_nodes_are_paid_in_research() -> void:
	for id: String in ["farm_mult_1", "farm_mult_2", "farm_mult_3"]:
		assert_str(UpgradeTree.currency_of(FarmTree.node_data(id))).is_equal("findings")
	var save := _save(["farm_terminal"], 1000000, FarmTree.price_of("farm_mult_1", SaveGame.new()) - 1)
	save.farms_owned.append("site_a")
	assert_bool(FarmTree.buy("farm_mult_1", save)).is_false()


func test_a_farm_bought_redraws_channel_two_so_its_branch_appears() -> void:
	var save := _save(["farm_terminal"])
	var no_farm := FarmTree.drawn_key(save)
	save.farms_owned.append("site_a")
	assert_array(FarmTree.drawn_key(save)).is_not_equal(no_farm)


## STRUCTURED FARM (desk card structured_farm): the tree opens up and its outer ring shows.
func _ring_save(cards: Array = []) -> SaveGame:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation", "archive_capacity"] + cards, 0, 100000000)
	save.findings_limit = 1000000000
	save.farms_owned.append("site_a")
	for id: String in ["hand_2", "hand_route", "estate_permit", "hand_shift", "farm_mult_1"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
	return save


func test_structured_farm_opens_the_dearer_ring_of_the_farm_tree() -> void:
	var save := _ring_save()
	assert_bool(FarmTree.wide(save)).is_false()
	for id: String in RING + MOVED:
		assert_bool(FarmTree.is_shown(id, save)).override_failure_message(id).is_false()
		assert_bool(FarmTree.can_buy(id, save)).override_failure_message(id).is_false()
	save.stamped.append("structured_farm")
	assert_bool(FarmTree.wide(save)).is_true()
	for id: String in RING + MOVED:
		assert_bool(FarmTree.is_shown(id, save)).override_failure_message(id).is_true()
	# Every node of the ring costs more than the card that opens it.
	var card: int = UpgradeDesk.card_data("structured_farm").price
	for id: String in RING + MOVED:
		assert_int(FarmTree.node_data(id).price).override_failure_message(id).is_greater(card)


func test_the_first_node_of_each_ring_run_names_structured_farm() -> void:
	for id: String in ["farm_slots_1", "hand_route_2", "hand_shift_2", "farm_mult_2"]:
		assert_array(FarmTree.node_data(id).needs).override_failure_message(id).contains(["structured_farm"])


func test_an_old_save_keeps_a_farm_tree_node_that_moved_behind_structured_farm() -> void:
	var save := _ring_save()
	save.farm_bought.append("farm_mult_2")  # Bought before the card existed.
	save.farm_square_mult = 20.0
	assert_bool(FarmTree.is_shown("farm_mult_2", save)).is_true()
	assert_bool(FarmTree.is_bought("farm_mult_2", save)).is_true()
	assert_float(save.farm_square_mult).is_equal(20.0)
	# And the run past it stays open: x30 shows and can be bought without the card.
	assert_bool(FarmTree.is_shown("farm_mult_3", save)).is_true()
	assert_bool(FarmTree.buy("farm_mult_3", save)).is_true()
	assert_float(save.farm_square_mult).is_equal(30.0)
	assert_bool(FarmTree.is_shown("farm_slots_1", save)).is_false()  # The ring's own nodes still wait.


func test_seed_beds_raise_a_farm_squares_seeds_from_two_to_three_four_then_six() -> void:
	var save := _ring_save(["structured_farm"])
	assert_int(save.farm_slots).is_equal(2)
	for step: Array in [["farm_slots_1", 3], ["farm_slots_2", 4], ["farm_slots_3", 6]]:
		var was := save.farm_slots
		assert_bool(FarmTree.buy(step[0], save)).override_failure_message(step[0]).is_true()
		assert_int(save.farm_slots).is_equal(step[1])
		assert_float(float(save.farm_slots) / was).override_failure_message(step[0]).is_greater_equal(1.25)  # Each step felt.


func test_farm_rounds_send_farm_hands_to_farm_squares_first_and_satchels_add_two_seeds_a_trip() -> void:
	var save := _ring_save(["structured_farm"])
	assert_int(save.farm_hand_route).is_equal(1)
	assert_int(save.farm_hand_shift).is_equal(2)
	assert_bool(FarmTree.buy("hand_route_2", save)).is_true()
	assert_bool(FarmTree.buy("hand_shift_2", save)).is_true()
	assert_int(save.farm_hand_route).is_equal(2)  # FarmScreen.target_for: farm squares first.
	assert_int(FarmScreen.shift(save, false)).is_equal(4)


func test_farm_rounds_wait_for_the_planting_roster_and_the_estate_planting_permit_and_satchels_for_overtime() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "structured_farm"], 0, 100000000)
	save.farms_owned.append("site_a")
	FarmTree.buy("hand_2", save)
	assert_bool(FarmTree.can_buy("hand_route_2", save)).is_false()
	assert_bool(FarmTree.can_buy("hand_shift_2", save)).is_false()
	FarmTree.buy("hand_route", save)
	FarmTree.buy("hand_shift", save)
	assert_bool(FarmTree.can_buy("hand_route_2", save)).is_false()
	FarmTree.buy("estate_permit", save)
	assert_bool(FarmTree.can_buy("hand_route_2", save)).is_true()
	assert_bool(FarmTree.can_buy("hand_shift_2", save)).is_true()


func test_the_tree_opens_up_with_the_widening_sound_the_first_time_it_shows_after_structured_farm() -> void:
	var save := _save(["farm_terminal"])
	SaveManager.save = save
	var screen: FarmTree = auto_free(SCENE.instantiate())
	add_child(screen)
	var tree := screen.get_node("Tree") as UpgradeTree
	var sfx := screen.get_node("Sfx") as AudioStreamPlayer
	screen._process(0.0)
	assert_float(tree.zoom_home).is_equal(1.0)  # Without the card it stays as it was.
	assert_bool(save.farm_tree_wide).is_false()
	save.stamped.append("structured_farm")
	screen._process(0.0)
	assert_float(tree.zoom_home).is_equal(FarmTree.ZOOM_WIDE)
	assert_float(tree.zoom_min).is_equal(FarmTree.ZOOM_MIN_WIDE)
	assert_float(FarmTree.ZOOM_MIN_WIDE).is_less(UpgradeTree.ZOOM_MIN)
	assert_object(screen.widen_sound).is_not_null()
	assert_object(sfx.stream).is_same(screen.widen_sound)
	assert_bool(sfx.playing).is_true()
	assert_bool(save.farm_tree_wide).is_true()
	assert_float(tree._zoom).is_equal(1.0)  # It eases out from where it was, not in a jump.


func test_a_save_that_has_seen_the_tree_open_up_starts_opened_without_the_sound() -> void:
	var save := _save(["farm_terminal", "structured_farm"])
	save.farm_tree_wide = true
	SaveManager.save = save
	var screen: FarmTree = auto_free(SCENE.instantiate())
	add_child(screen)
	screen._process(0.0)
	var tree := screen.get_node("Tree") as UpgradeTree
	assert_float(tree._zoom).is_equal(FarmTree.ZOOM_WIDE)
	assert_bool((screen.get_node("Sfx") as AudioStreamPlayer).playing).is_false()


## Whether node `id` or one of its ancestors waits for a chapter 4 card.
func _nuclear(id: String) -> bool:
	var node := FarmTree.node_data(id)
	return node.get("needs", []).any(func(card: String) -> bool: return card in NUCLEAR_CARDS) \
			or (node.parent != "" and _nuclear(node.parent))


func test_opened_up_the_whole_ring_fits_the_screen_at_the_view_it_settles_on_and_the_nuclear_runs_once_it_settles_further_out() -> void:
	# The Tree's rect on the glass (farm_tree.tscn) and the wheel's scale on it (UpgradeTree._wheel).
	var area := Vector2(1440.0, 620.0)
	var uy := area.y / 2.0 / 1.25
	var centre := area / 2.0 + Vector2(0.0, uy * 0.06)
	for zoom: float in [FarmTree.ZOOM_WIDE, FarmTree.ZOOM_NUCLEAR]:
		var unit := Vector2(minf(area.x / 2.0 / 1.05, uy * UpgradeTree.WIDEN), uy) * zoom
		for node: Dictionary in FarmTree.NODES:
			if zoom == FarmTree.ZOOM_WIDE and _nuclear(node.id):
				continue
			var at: Vector2 = centre + node.at * unit
			assert_bool(Rect2(Vector2.ZERO, area).grow(-15.0).has_point(at)).override_failure_message(node.id).is_true()
	assert_float(FarmTree.home_zoom(_save(["structured_farm"]))).is_equal(FarmTree.ZOOM_WIDE)
	assert_float(FarmTree.home_zoom(_save(["structured_farm", FarmTree.NUCLEAR_CARD]))).is_equal(FarmTree.ZOOM_NUCLEAR)


func test_the_archive_is_no_longer_on_the_farm_tree_it_moved_to_the_projector() -> void:
	for id: String in ["archive_1", "archive_2", "archive_3", "archive_4", "archive_5"]:
		assert_dict(FarmTree.node_data(id)).override_failure_message(id).is_empty()
		assert_dict(Projector.node_data(id)).override_failure_message(id).is_not_empty()
	assert_bool(FarmTree.THEMES.any(func(theme: Array) -> bool: return theme[0] == "ARCHIVE")).is_false()


## ESTATE PLANTING PERMIT / HARVEST LICENCE: the workers' way onto farm squares, bought once a farm is owned.
func test_the_estate_permit_and_licence_show_only_once_a_farm_is_owned_and_let_the_workers_onto_farm_squares() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation"], 0, 100000)
	for id: String in ["hand_2", "hand_route", "tractor_2", "tractor_route"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
	for id: String in ["estate_permit", "estate_licence"]:
		assert_bool(FarmTree.is_shown(id, save)).override_failure_message(id).is_false()
	save.farms_owned.append("site_a")  # An old save that owns a farm still pays for them.
	assert_bool(save.farm_bought.has(FarmScreen.PLANT_PERMIT)).is_false()
	assert_bool(FarmTree.buy("estate_permit", save)).is_true()
	assert_bool(FarmTree.buy("estate_licence", save)).is_true()
	assert_bool(save.farm_bought.has(FarmScreen.PLANT_PERMIT)).is_true()
	assert_bool(save.farm_bought.has(FarmScreen.HARVEST_LICENCE)).is_true()


func test_compost_detail_waits_for_the_cold_frames_and_puts_the_farm_hands_on_rotten_squares() -> void:
	var save := _save(["farm_terminal", "seasonal_workforce", "golden_cabbage"], 0, 100000)
	assert_bool(FarmTree.can_buy("compost_detail", save)).is_false()
	FarmTree.buy("cold_frames", save)
	assert_bool(FarmTree.buy("compost_detail", save)).is_true()
	assert_bool(save.farm_bought.has(FarmScreen.COMPOST)).is_true()


func test_the_estate_rotation_policy_waits_for_one_in_one_out_and_a_farm() -> void:
	var save := _save(["farm_terminal", "green_thumb"], 0, 100000)
	FarmTree.buy("thumb_yield", save)
	FarmTree.buy("thumb_replant", save)
	assert_bool(FarmTree.is_shown("farm_replant", save)).is_false()
	save.farms_owned.append("site_a")
	assert_bool(FarmTree.buy("farm_replant", save)).is_true()
	assert_bool(save.farm_bought.has(FarmScreen.FARM_REPLANT)).is_true()


func test_the_fourth_and_fifth_farm_hand_and_tractor_wait_for_structured_farm_then_make_five_of_each() -> void:
	var save := _ring_save()
	for id: String in ["hand_speed", "hand_3", "tractor_2", "tractor_speed", "tractor_3"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
	for id: String in ["hand_4", "tractor_4"]:
		assert_bool(FarmTree.is_shown(id, save)).override_failure_message(id).is_false()
		assert_bool(FarmTree.can_buy(id, save)).override_failure_message(id).is_false()
	save.stamped.append("structured_farm")
	save.farm_hands = 3
	save.farm_tractors = 3
	for id: String in ["hand_4", "hand_5", "tractor_4", "tractor_5"]:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
	assert_int(save.farm_hands).is_equal(5)
	assert_int(save.farm_tractors).is_equal(5)


func test_the_thinning_quota_nodes_wait_for_the_thinning_card_and_raise_the_cap_from_six_to_eight_then_ten() -> void:
	var save := _save(["farm_terminal"], 0, 100000)
	assert_int(save.thinning_cap).is_equal(MiniDrop.MAX_MINIS)
	assert_bool(FarmTree.is_shown("thinning_cap_1", save)).is_false()
	assert_bool(FarmTree.buy("thinning_cap_1", save)).is_false()
	save.stamped.append("mini_thinning")
	for step: Array in [["thinning_cap_1", 8], ["thinning_cap_2", 10]]:
		var was := save.thinning_cap
		assert_bool(FarmTree.buy(step[0], save)).override_failure_message(step[0]).is_true()
		assert_int(save.thinning_cap).is_equal(step[1])
		assert_float(float(save.thinning_cap) / was).override_failure_message(step[0]).is_greater_equal(1.25)  # Each step felt.


# ---- Chapter 4, part 0: NUCLEAR ----

## A save with every card and every farm tree node before chapter 4, and Findings without end.
func _nuclear_save() -> SaveGame:
	var save := _save(["farm_terminal", "seasonal_workforce", "mechanisation", "golden_cabbage", "green_thumb", "archive_capacity",
			"structured_farm", "mini_thinning", "standing_seed_order"] + NUCLEAR_CARDS, 0, 1 << 60)
	save.findings_limit = 1 << 61
	save.farms_owned.append("site_a")
	for node: Dictionary in FarmTree.NODES:
		if not _nuclear(node.id):
			save.farm_bought.append(node.id)
			UpgradeTree.apply_effect(node, save)
	save.farm_hands += 1  # The first of each came with its card.
	save.farm_tractors += 1
	return save


## Buys `ids` in order: `stat` before the first and after each.
func _levels(save: SaveGame, ids: Array, stat: String) -> Array:
	var out := [save.get(stat)]
	for id: String in ids:
		assert_bool(FarmTree.buy(id, save)).override_failure_message(id).is_true()
		out.append(save.get(stat))
	return out


func test_each_nuclear_run_waits_for_its_card() -> void:
	for pair: Array in [["soil_1", "nuclear_research"], ["ripening_1", "isotope_seed"], ["mutation_1", "isotope_seed"],
			["hand_drive_1", "reactor_machinery"], ["tractor_drive_1", "reactor_machinery"], ["hand_6", "nuclear_family"], ["tractor_6", "nuclear_family"]]:
		var save := _nuclear_save()
		assert_bool(FarmTree.can_buy(pair[0], save)).override_failure_message(pair[0]).is_true()
		save.stamped.remove_at(save.stamped.find(pair[1]))
		assert_bool(FarmTree.can_buy(pair[0], save)).override_failure_message(pair[0]).is_false()
		assert_bool(FarmTree.is_shown(pair[0], save)).override_failure_message(pair[0]).is_false()


func test_enriched_soil_takes_a_farm_square_from_thirty_to_293_times_a_plain_square_in_sixteen_steps() -> void:
	var levels := _levels(_nuclear_save(), _run("soil", 16), "farm_square_mult")
	assert_float(levels[0]).is_equal(30.0)
	assert_float(levels[-1]).is_equal(293.0)
	for i in range(1, levels.size()):
		assert_float(levels[i] / levels[i - 1]).override_failure_message("step %d" % i).is_greater_equal(1.1)  # Small steps (user 2026-11-19).


func test_accelerated_ripening_takes_a_square_from_fifteen_seconds_to_under_four() -> void:
	var save := _nuclear_save()
	assert_float(FarmScreen.grow_time(save)).is_equal(15.0)
	_levels(save, _run("ripening", 10), "farm_grow_mult")
	assert_float(FarmScreen.grow_time(save)).is_equal_approx(15.0 * pow(0.75, 5), 0.01)
	assert_float(FarmScreen.grow_time(save)).is_less(3.6)


func test_mutation_takes_the_golden_chance_from_one_in_ten_to_one_in_four_in_eight_steps() -> void:
	var levels := _levels(_nuclear_save(), _run("mutation", 8), "golden_chance")
	assert_float(levels[0]).is_equal_approx(0.1, 0.0001)
	assert_float(levels[-1]).is_equal_approx(0.25, 0.0001)
	for i in range(1, levels.size()):
		assert_float(levels[i] / levels[i - 1]).override_failure_message("step %d" % i).is_greater_equal(1.1)


func test_reactor_drives_make_farm_hands_and_tractors_about_four_times_as_fast_in_eight_steps() -> void:
	var save := _nuclear_save()
	var hands := _levels(save, _run("hand_drive", 8), "farm_hand_speed")
	var tractors := _levels(save, _run("tractor_drive", 8), "farm_tractor_speed")
	assert_float(hands[-1] / hands[0]).is_equal_approx(pow(1.4, 4), 0.01)
	assert_float(tractors[-1] / tractors[0]).is_equal_approx(pow(1.4, 4), 0.01)


func test_the_nuclear_family_brings_the_sixth_to_eighth_farm_hand_and_tractor_filling_the_yard() -> void:
	var save := _nuclear_save()
	assert_int(save.farm_hands).is_equal(5)
	assert_array(_levels(save, ["hand_6", "hand_7", "hand_8"], "farm_hands")).is_equal([5, 6, 7, 8])
	assert_array(_levels(save, ["tractor_6", "tractor_7", "tractor_8"], "farm_tractors")).is_equal([5, 6, 7, 8])
	assert_int(save.farm_hands).is_equal(FarmScreen.SLOTS)
	assert_int(save.farm_tractors).is_equal(FarmScreen.SLOTS)


## The ids of run `prefix` from its first step to step `count`.
func _run(prefix: String, count: int) -> Array:
	var out := []
	for i in range(1, count + 1):
		out.append("%s_%d" % [prefix, i])
	assert_dict(FarmTree.node_data("%s_%d" % [prefix, count + 1])).override_failure_message(prefix).is_empty()  # And no further.
	return out
