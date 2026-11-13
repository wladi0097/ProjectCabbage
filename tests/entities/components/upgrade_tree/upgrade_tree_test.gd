extends GdUnitTestSuite

const TREE := preload("res://entities/components/upgrade_tree/upgrade_tree.tscn")

var _real_save: SaveGame
var _demo: Variant


func before_test() -> void:
	_real_save = SaveManager.save
	_demo = ProjectSettings.get_setting("game/demo", false)
	ProjectSettings.set_setting("game/demo", false)


func after_test() -> void:
	SaveManager.save = _real_save
	ProjectSettings.set_setting("game/demo", _demo)


## A lit tree on `rules`, laid out, with SaveManager.save = `save`.
func _tree(rules: Variant, save: SaveGame) -> UpgradeTree:
	SaveManager.save = save
	var tree: UpgradeTree = auto_free(TREE.instantiate())
	tree.rules = rules
	add_child(tree)
	tree.size = Vector2(1200, 700)
	tree._process(0.0)
	return tree


## A press on node `id`, then the mouse held still for `seconds`.
func _hold(tree: UpgradeTree, id: String, seconds: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = tree._wheel()[0] + tree.rules.node_data(id).at * tree._wheel()[1]
	tree._gui_input(press)
	tree._process(seconds)


func test_the_projector_tree_still_buys_with_coins() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	save.coins = 100
	var tree := _tree(Projector, save)
	var paid := []
	tree.bought.connect(func(id: String, price: int) -> void: paid.append([id, price]))
	_hold(tree, "slogan_1", UpgradeTree.HOLD_TIME + 0.05)
	assert_bool(save.tree_bought.has("slogan_1")).is_true()
	assert_int(save.coins).is_equal(100 - Projector.price_of("slogan_1", save))
	assert_array(paid).is_equal([["slogan_1", Projector.price_of("slogan_1", save)]])


func test_a_short_hold_buys_nothing() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	save.coins = 100
	var tree := _tree(Projector, save)
	_hold(tree, "slogan_1", UpgradeTree.HOLD_TIME * 0.5)
	assert_bool(save.tree_bought.has("slogan_1")).is_false()
	assert_int(save.coins).is_equal(100)


func test_holding_a_node_the_save_cannot_pay_for_is_refused() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	var tree := _tree(Projector, save)
	var refusals := [0]
	tree.denied.connect(func() -> void: refusals[0] += 1)
	_hold(tree, "slogan_1", UpgradeTree.HOLD_TIME + 0.05)
	assert_bool(save.tree_bought.has("slogan_1")).is_false()
	assert_int(refusals[0]).is_equal(1)


func test_the_farm_tree_buys_a_findings_node_with_findings() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["farm_terminal", "seasonal_workforce"])
	save.farm_bought = PackedStringArray(["hand_2"])
	save.coins = 100000
	save.findings = 1000
	var tree := _tree(FarmTree, save)
	_hold(tree, "hand_route", UpgradeTree.HOLD_TIME + 0.05)
	assert_int(save.farm_hand_route).is_equal(1)
	assert_int(save.findings).is_equal(1000 - FarmTree.price_of("hand_route", save))
	assert_int(save.coins).is_equal(100000)


func test_closing_the_tree_hands_back_the_nodes_marked_new_once() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	save.projector_opened = true
	var tree := _tree(Projector, save)
	assert_array(Array(tree.close())).is_equal(Projector.fresh(save))
	assert_array(Array(tree.close())).is_empty()


func test_a_node_is_paid_in_coins_unless_it_says_findings() -> void:
	assert_str(UpgradeTree.currency_of({})).is_equal("coins")
	assert_str(UpgradeTree.currency_of({currency = "findings"})).is_equal("findings")


func test_an_effect_multiplies_and_adds_the_save_numbers_it_names_keeping_whole_numbers_whole() -> void:
	var save := SaveGame.new()
	var speed := save.farm_hand_speed
	UpgradeTree.apply_effect({mul = {farm_hand_speed = 1.5}, add = {farm_hands = 2}}, save)
	assert_float(save.farm_hand_speed).is_equal_approx(speed * 1.5, 0.0001)
	assert_int(save.farm_hands).is_equal(2)


func test_on_the_projector_and_farm_tree_the_description_shines_brighter_than_the_flavour_line() -> void:
	assert_float(UpgradeTree.BODY_ALPHA).is_greater(UpgradeTree.FLAVOUR_ALPHA)
	assert_float(UpgradeTree.BODY_ALPHA).is_equal(1.0)


func test_a_form_in_the_tray_is_to_be_approved_on_the_desk() -> void:
	var save := SaveGame.new()
	save.tray_unlocked = true
	var dealt: String = UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)[0]
	save.offered = PackedStringArray([dealt])
	assert_array(UpgradeTree.form_lock(dealt, save)).is_equal(["LOCKED", UpgradeDesk.card_data(dealt).title, UpgradeTree.FORM_ON_DESK])


## Every form stamped but OFF-SITE STORAGE (waiting for the STORAGE node) and more than a tray of others.
func _full_tray_save() -> SaveGame:
	var save := SaveGame.new()
	save.tray_unlocked = true
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in ["offsite_storage", "golden_lamp", "mat_allowance", "stats_ledger", "spoilage_memo", "lab_priority"]:
			save.stamped.append(card.id)
	return save


func test_a_locked_node_only_says_its_form_is_on_the_desk_when_that_form_is_really_in_the_tray() -> void:
	var save := _full_tray_save()
	# A full tray, dealt before the STORAGE node was bought.
	save.offered = PackedStringArray(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save))
	assert_int(save.offered.size()).is_equal(UpgradeDesk.OFFERED)
	save.tree_bought = PackedStringArray(["storage_1"])
	# The queue now puts OFF-SITE STORAGE first, but it waits for a free slot...
	var queue := UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)
	assert_str(queue[0]).is_equal("offsite_storage")
	assert_str(UpgradeTree.form_lock("offsite_storage", save)[2]).is_equal(UpgradeTree.FORM_NOT_YET)
	# ...while the form it pushed out of the queue's first three is still in the tray.
	var pushed_out: String = save.offered[-1]
	assert_bool(queue.has(pushed_out)).is_false()
	assert_str(UpgradeTree.form_lock(pushed_out, save)[2]).is_equal(UpgradeTree.FORM_ON_DESK)


func test_the_desk_keeps_the_forms_in_its_tray_in_the_save_for_the_locked_nodes_to_read() -> void:
	var save := _full_tray_save()
	SaveManager.save = save
	var desk: UpgradeDesk = auto_free(preload("res://entities/upgrade_desk/upgrade_desk.tscn").instantiate())
	add_child(desk)
	desk.set_process(false)
	var tray := func() -> Array: return desk._offered.map(func(card: UpgradeCard) -> String: return card.id)
	assert_array(Array(save.offered)).is_equal(tray.call())
	save.tree_bought = PackedStringArray(["storage_1"])
	desk._deal()  # A full tray: OFF-SITE STORAGE waits for a slot.
	assert_str(UpgradeTree.form_lock("offsite_storage", save)[2]).is_equal(UpgradeTree.FORM_NOT_YET)
	desk._stamp_free(desk._offered[0])  # A slot comes free and the form is dealt into it.
	assert_array(Array(save.offered)).is_equal(tray.call())
	assert_str(UpgradeTree.form_lock("offsite_storage", save)[2]).is_equal(UpgradeTree.FORM_ON_DESK)

func test_a_form_not_dealt_yet_is_named_but_said_not_to_have_reached_the_desk() -> void:
	var save := SaveGame.new()
	save.tray_unlocked = true
	var last: Dictionary = UpgradeDesk.CARDS[-1]
	assert_array(UpgradeTree.form_lock(last.id, save)).is_equal(["LOCKED", last.title, UpgradeTree.FORM_NOT_YET])
	save.tray_unlocked = false  # No tray on the desk yet: nothing is on it.
	var first: String = UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)[0]
	assert_str(UpgradeTree.form_lock(first, save)[2]).is_equal(UpgradeTree.FORM_NOT_YET)


func test_the_form_lock_sentence_fits_the_popup_for_every_form_in_english_and_german() -> void:
	var locale := TranslationServer.get_locale()
	for lang: String in ["en", "de"]:
		TranslationServer.set_locale(lang)
		for card: Dictionary in UpgradeDesk.CARDS:
			for sentence: String in [UpgradeTree.FORM_ON_DESK, UpgradeTree.FORM_NOT_YET]:
				var text := TranslationServer.translate(sentence) % TranslationServer.translate(card.title)
				assert_str(TranslationServer.translate(sentence)).override_failure_message("%s untranslated" % lang).contains("%s")
				if lang == "de":
					assert_str(TranslationServer.translate(sentence)).is_not_equal(sentence)
				for face: Font in [UpgradeTree.FONT, FARM_FONT]:  # The projector's face and CH 2's.
					var lines := UpgradeTree.popup_lines(text, face)
					assert_int(lines.size()).override_failure_message("%s %s: %s" % [lang, card.id, text]).is_less_equal(4)
					for line: String in lines:
						assert_float(face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UpgradeTree.POPUP_BODY).x).override_failure_message("%s %s: %s" % [lang, card.id, line]).is_less_equal(UpgradeTree.POPUP_TEXT)
	TranslationServer.set_locale(locale)


func _theme(tree: Script, title: String) -> int:
	for i in tree.THEMES.size():
		if tree.THEMES[i][0] == title:
			return i
	return -1


func _rich(cards: Array, coins: int) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(cards)
	save.coins = coins
	return save


func test_hovering_a_category_names_the_cheapest_upgrade_you_can_afford_in_it() -> void:
	var save := _rich(["projector", "managerial_oversight"], 900)
	var management := UpgradeTree.theme_members(Projector, _theme(Projector, "MANAGEMENT"))
	assert_dict(UpgradeTree.next_pick(Projector, management, save)).is_equal({id = "manager_time", state = "buy"})
	save.tree_bought = PackedStringArray(["manager_time"])
	assert_dict(UpgradeTree.next_pick(Projector, management, save)).is_equal({id = "manager_reward_1", state = "buy"})


func test_with_nothing_affordable_a_category_names_its_cheapest_upgrade_and_its_price_in_red() -> void:
	var save := _rich(["projector", "managerial_oversight"], 100)
	save.tree_bought = PackedStringArray(["manager_time"])
	var management := UpgradeTree.theme_members(Projector, _theme(Projector, "MANAGEMENT"))
	var pick := UpgradeTree.next_pick(Projector, management, save)
	assert_dict(pick).is_equal({id = "manager_reward_1", state = "short"})
	var cost: Array = _tree(Projector, save)._pick_rows(pick, save)[-1]
	assert_bool(cost[3]).is_true()  # The cost row...
	assert_bool(cost[2]).is_true()  # ...drawn in the warning red.


func test_a_category_whose_upgrades_all_wait_behind_unapproved_forms_says_more_comes_later() -> void:
	var save := _rich(["projector"], 1000000)
	var management := UpgradeTree.theme_members(Projector, _theme(Projector, "MANAGEMENT"))
	for id: String in management:
		assert_bool(Projector.is_shown(id, save)).override_failure_message(id).is_false()
	assert_dict(UpgradeTree.next_pick(Projector, management, save)).is_equal({state = "later"})


func test_a_finished_category_says_everything_in_it_is_approved() -> void:
	var save := _rich(["projector", "managerial_oversight"], 0)
	var management := UpgradeTree.theme_members(Projector, _theme(Projector, "MANAGEMENT"))
	save.tree_bought = PackedStringArray(management)
	assert_dict(UpgradeTree.next_pick(Projector, management, save)).is_equal({state = "done"})


func test_a_category_never_points_at_an_upgrade_behind_an_unapproved_form_as_buyable() -> void:
	var save := _rich(["projector", "junior_associate", "auto_procurement"], 1000000)
	save.tree_bought = PackedStringArray(["auto_reserve_1", "auto_smart_1"])
	var chain := UpgradeTree.theme_members(Projector, _theme(Projector, "SUPPLY CHAIN"))
	assert_dict(UpgradeTree.next_pick(Projector, chain, save)).is_equal({id = "conveyor_1", state = "locked"})
	assert_int(Projector.requirement("conveyor_1", save).size()).is_equal(3)  # Its popup line: the form to approve.
	# Whatever the save, a pick offered as payable or merely too dear is one a hold could buy.
	for tree: Script in [Projector, FarmTree]:
		for cards: Array in [[], ["projector", "junior_associate", "farm_terminal"], UpgradeDesk.CARDS.map(func(c: Dictionary) -> String: return c.id)]:
			var other := _rich(["projector", "farm_terminal"] + cards, 1000000)
			other.findings = 1000000
			for i in tree.THEMES.size():
				var pick := UpgradeTree.next_pick(tree, UpgradeTree.theme_members(tree, i), other)
				if pick.get("state", "") in ["buy", "short"]:
					assert_bool(tree.can_hold(pick.id, other)).override_failure_message("%s: %s" % [tree.THEMES[i][0], pick.id]).is_true()


func test_a_category_holds_its_branch_up_to_where_the_next_heading_starts() -> void:
	var research := UpgradeTree.theme_members(Projector, _theme(Projector, "RESEARCH"))
	assert_bool(research.has("research_mult_1") and research.has("research_chance_3")).is_true()
	assert_bool(research.has("lab_hand_2")).is_false()
	var lab := UpgradeTree.dept_members(Projector, "dept_qa")
	assert_bool(lab.has("research_mult_1") and lab.has("lab_hand_3") and lab.has("qa_slot_5")).is_true()
	assert_bool(lab.has("dept_qa")).is_false()
	for tree: Script in [Projector, FarmTree]:
		var seen := {}
		for i in tree.THEMES.size():
			for id: String in UpgradeTree.theme_members(tree, i):
				assert_bool(seen.has(id)).override_failure_message("%s in two categories" % id).is_false()
				seen[id] = true


func test_the_farm_tree_categories_point_at_upgrades_paid_in_findings() -> void:
	var save := _rich(["farm_terminal"], 0)
	save.findings = 260
	var soil := UpgradeTree.theme_members(FarmTree, _theme(FarmTree, "SOIL"))
	assert_dict(UpgradeTree.next_pick(FarmTree, soil, save)).is_equal({id = "fertiliser", state = "buy"})
	save.findings = 100
	assert_dict(UpgradeTree.next_pick(FarmTree, soil, save)).is_equal({id = "fertiliser", state = "short"})


## The farm tree's popups draw in CH 2's terminal face (farm_tree.tscn), not Oswald.
const FARM_FONT := preload("res://assets/fonts/terminal_font.tres")


func test_every_category_popup_fits_in_english_and_german() -> void:
	var locale := TranslationServer.get_locale()
	var measure := func(text: String, font_size: int, face: Font) -> float:
		return face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var size := func(text: String, font_size: int) -> float:  # Lines both trees draw: the wider face.
		return maxf(measure.call(text, font_size, UpgradeTree.FONT), measure.call(text, font_size, FARM_FONT))
	for lang: String in ["en", "de"]:
		TranslationServer.set_locale(lang)
		for tree: Script in [Projector, FarmTree]:
			var face: Font = (FARM_FONT as Font) if tree == FarmTree else (UpgradeTree.FONT as Font)  # Each tree in the face it draws with.
			for heading: Array in tree.THEMES:
				var shown := TranslationServer.translate(heading[3])
				if lang == "de":
					assert_str(shown).override_failure_message("%s untranslated" % heading[0]).is_not_equal(heading[3])
				var lines := UpgradeTree.popup_lines(shown, face)
				assert_int(lines.size()).override_failure_message("%s %s" % [lang, heading[0]]).is_less_equal(4)
				for line: String in lines:
					assert_float(measure.call(line, UpgradeTree.POPUP_BODY, face)).override_failure_message("%s: %s" % [lang, line]).is_less_equal(UpgradeTree.POPUP_TEXT)
				assert_float(measure.call(TranslationServer.translate(heading[0]), 30, face)) \
						.override_failure_message("%s: %s" % [lang, heading[0]]).is_less_equal(UpgradeTree.POPUP_TEXT)
			for node: Dictionary in tree.NODES:  # Its own popup heads it at 30 (a category's pick: 24), on one line.
				assert_float(measure.call(TranslationServer.translate(node.title), 30, face)) \
						.override_failure_message("%s: %s" % [lang, node.title]).is_less_equal(UpgradeTree.POPUP_TEXT)
		for state: String in UpgradeTree.PICK_HEADING:
			var line := TranslationServer.translate(UpgradeTree.PICK_HEADING[state])
			assert_float(size.call(line, 21)).override_failure_message("%s: %s" % [lang, line]).is_less_equal(UpgradeTree.POPUP_TEXT)
			if lang == "de":
				assert_str(line).is_not_equal(UpgradeTree.PICK_HEADING[state])
		for dry: String in [UpgradeTree.PICK_DONE, UpgradeTree.PICK_LATER]:
			assert_int(UpgradeTree.popup_lines(TranslationServer.translate(dry), FARM_FONT).size()).is_less_equal(2)
			if lang == "de":
				assert_str(TranslationServer.translate(dry)).is_not_equal(dry)
	TranslationServer.set_locale(locale)
