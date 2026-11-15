extends GdUnitTestSuite

const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const SCHEDULE := preload("res://entities/hand_schedule/hand_schedule.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


## A save with the schedule stamped, `cards` stamped too and `nodes` bought on the projector.
func _stamped(cards: Array = [], nodes: Array = []) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray([HandSchedule.CARD] + cards)
	save.tree_bought = PackedStringArray(nodes)
	return save


func _cabbage(rotten := false, research := false, golden := false, mini_one := false) -> Cabbage:
	var cabbage := CABBAGE.instantiate() as Cabbage
	cabbage.rotten = rotten
	cabbage.research = research
	cabbage.golden = golden
	cabbage.mini = mini_one
	add_child(auto_free(cabbage))
	return cabbage


func test_stamping_the_schedule_forbids_nothing_by_itself() -> void:
	var save := SaveGame.new()
	assert_array(save.hands_forbidden).is_empty()
	assert_array(save.lab_hands_forbidden).is_empty()
	UpgradeDesk.apply(HandSchedule.CARD, save)
	save.stamped.append(HandSchedule.CARD)

	assert_array(HandSchedule.forbidden(save, false)).is_empty()
	assert_array(HandSchedule.forbidden(save, true)).is_empty()
	assert_bool(HandSchedule.any_struck(save)).is_false()


func test_plain_cabbages_are_listed_with_the_card_and_minis_once_their_card_is_stamped() -> void:
	var save := _stamped()
	assert_bool(HandSchedule.listed(save, "regular")).is_true()
	assert_bool(HandSchedule.listed(save, "mini")).is_false()
	save.stamped.append("mini_cabbages")
	assert_bool(HandSchedule.listed(save, "mini")).is_true()


func test_blue_is_listed_once_lab_priority_is_stamped() -> void:
	var save := _stamped(["research_cabbage"])
	assert_bool(HandSchedule.seen(save, "research")).is_true()
	assert_bool(HandSchedule.listed(save, "research")).override_failure_message("met, no memo: padlocked").is_false()
	save.stamped.append(HandSchedule.LAB_CARD)
	assert_bool(HandSchedule.listed(save, "research")).is_true()


func test_gold_is_listed_once_its_node_under_the_bullion_clearance_is_bought() -> void:
	var save := _stamped(["golden_cabbage"])
	assert_bool(HandSchedule.listed(save, "golden")).override_failure_message("met, no node: padlocked").is_false()
	save.tree_bought.append(HandSchedule.GOLD_NODE)
	assert_bool(HandSchedule.listed(save, "golden")).is_true()


func test_a_kind_counts_as_met_once_its_card_is_stamped_and_an_unmet_one_is_never_listed() -> void:
	var save := _stamped([HandSchedule.LAB_CARD], [HandSchedule.GOLD_NODE])
	assert_bool(HandSchedule.seen(save, "regular")).is_true()
	for kind: String in ["research", "mini", "golden"]:
		assert_bool(HandSchedule.seen(save, kind)).override_failure_message(kind).is_false()
		assert_bool(HandSchedule.listed(save, kind)).override_failure_message(kind).is_false()
		save.stamped.append(HandSchedule.SEEN[kind])
		assert_bool(HandSchedule.seen(save, kind)).override_failure_message(kind + " met").is_true()


func test_without_the_schedule_card_no_kind_is_listed_whatever_else_is_stamped() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(HandSchedule.SEEN.values() + [HandSchedule.LAB_CARD])
	save.tree_bought = PackedStringArray([HandSchedule.GOLD_NODE])
	for kind: String in HandSchedule.KINDS:
		assert_bool(HandSchedule.listed(save, kind)).override_failure_message(kind).is_false()


func test_the_schedule_cannot_be_changed_for_a_kind_it_does_not_list() -> void:
	var save := _stamped(["research_cabbage", "golden_cabbage"])
	assert_bool(HandSchedule.toggle(save, false, "research")).is_false()
	assert_bool(HandSchedule.toggle(save, true, "golden")).is_false()
	assert_array(save.hands_forbidden).is_empty()
	assert_array(save.lab_hands_forbidden).is_empty()


func test_stamping_lab_priority_strikes_blue_for_hired_hands_and_the_schedule_can_clear_it() -> void:
	var save := _stamped(["research_cabbage"])
	UpgradeDesk.apply(HandSchedule.LAB_CARD, save)
	save.stamped.append(HandSchedule.LAB_CARD)
	assert_array(HandSchedule.forbidden(save, false)).contains_exactly(["research"])
	assert_array(HandSchedule.forbidden(save, true)).override_failure_message("lab hands take blue first").is_empty()
	assert_bool(HandSchedule.toggle(save, false, "research")).is_true()
	assert_array(HandSchedule.forbidden(save, false)).is_empty()


func test_without_the_schedule_lab_priority_still_keeps_hired_hands_off_blue() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["research_cabbage", HandSchedule.LAB_CARD])
	assert_array(HandSchedule.forbidden(save, false)).contains_exactly(["research"])
	assert_array(HandSchedule.forbidden(save, true)).is_empty()


func test_the_schedule_stamped_after_lab_priority_shows_blue_already_struck_for_hired_hands() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["research_cabbage", HandSchedule.LAB_CARD])
	UpgradeDesk.apply(HandSchedule.LAB_CARD, save)
	save.stamped.append(HandSchedule.CARD)
	assert_array(HandSchedule.forbidden(save, false)).contains_exactly(["research"])


func test_a_click_strikes_a_kind_for_one_half_only_and_a_second_click_clears_it() -> void:
	var save := _stamped()
	assert_bool(HandSchedule.toggle(save, true, "regular")).is_true()
	assert_array(HandSchedule.forbidden(save, true)).contains_exactly(["regular"])
	assert_array(HandSchedule.forbidden(save, false)).override_failure_message("the hired hands' half is its own").is_empty()

	HandSchedule.toggle(save, true, "regular")
	assert_array(HandSchedule.forbidden(save, true)).is_empty()


func test_plain_cabbages_may_be_struck_for_both_kinds_of_hand_at_once() -> void:
	var save := _stamped()
	HandSchedule.toggle(save, true, "regular")
	HandSchedule.toggle(save, false, "regular")
	assert_array(HandSchedule.forbidden(save, true)).contains_exactly(["regular"])
	assert_array(HandSchedule.forbidden(save, false)).contains_exactly(["regular"])


func test_a_save_without_the_card_ignores_struck_kinds_left_in_it() -> void:
	var save := SaveGame.new()
	save.hands_forbidden.append("regular")
	assert_array(HandSchedule.forbidden(save, false)).is_empty()


func test_a_cabbage_is_golden_before_blue_before_mini_before_plain_and_a_rotten_one_is_not_on_the_schedule() -> void:
	assert_str(HandSchedule.kind_of(_cabbage())).is_equal("regular")
	assert_str(HandSchedule.kind_of(_cabbage(false, true))).is_equal("research")
	assert_str(HandSchedule.kind_of(_cabbage(false, false, true))).is_equal("golden")
	assert_str(HandSchedule.kind_of(_cabbage(false, false, false, true))).is_equal("mini")
	assert_str(HandSchedule.kind_of(_cabbage(true))).is_equal("")


func test_a_condensed_or_grown_cabbage_counts_as_a_plain_one() -> void:
	var condensed := CABBAGE.instantiate() as Cabbage
	condensed.units = 2
	add_child(auto_free(condensed))
	assert_str(HandSchedule.kind_of(condensed)).is_equal("regular")
	var grown := _cabbage(false, false, false, true)
	grown.grow()
	assert_str(HandSchedule.kind_of(grown)).is_equal("regular")


func test_the_handling_schedule_is_an_optional_chapter_1_card_dealt_with_the_lab_assistant() -> void:
	var card := UpgradeDesk.card_data(HandSchedule.CARD)
	var ids: Array = UpgradeDesk.CARDS.map(func(each: Dictionary) -> String: return each.id)
	assert_array(card.needs).contains_exactly(["research_assistant"])  # Both kinds of hand exist by then.
	assert_int(ids.find(HandSchedule.CARD)).is_less(ids.find("family_farm"))
	assert_dict(UpgradeDesk.costs(card)).is_equal({coins = 150})
	assert_str(card.body).not_contains("Needs")
	assert_array(UpgradeDesk.Events.DRY_LEFT).contains([HandSchedule.CARD])


func test_nothing_waits_on_the_handling_schedule_but_the_gold_annex() -> void:
	for other: Dictionary in UpgradeDesk.CARDS:
		assert_bool(other.get("needs", []).has(HandSchedule.CARD)).override_failure_message(other.id + " waits for it").is_false()
	for node: Dictionary in Projector.NODES:
		if node.get("needs", []).has(HandSchedule.CARD):
			assert_str(node.id).is_equal(HandSchedule.GOLD_NODE)


func test_the_blue_and_mini_annexes_are_gone_and_the_gold_one_sits_under_the_bullion_clearance() -> void:
	for id: String in UpgradeDesk.RETIRED_ANNEXES:
		assert_dict(Projector.node_data(id)).override_failure_message(id).is_empty()
	var node := Projector.node_data(HandSchedule.GOLD_NODE)
	assert_str(node.parent).is_equal(Associate.GOLD_SALE)
	assert_array(node.needs).contains(["golden_cabbage", HandSchedule.CARD])
	assert_int(int(node.price)).is_between(3000, 7000)


func test_the_gold_annex_is_not_on_show_before_the_schedule_is_stamped() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(UpgradeDesk.CARDS.map(func(each: Dictionary) -> String: return each.id))
	save.stamped.remove_at(save.stamped.find(HandSchedule.CARD))
	save.tree_bought = PackedStringArray(["storage_2", "gold_sale_1", Associate.GOLD_SALE])
	save.coins = 100000
	assert_bool(Projector.is_shown(HandSchedule.GOLD_NODE, save)).is_false()
	save.stamped.append(HandSchedule.CARD)
	assert_bool(Projector.is_shown(HandSchedule.GOLD_NODE, save)).is_true()
	assert_bool(Projector.buy(HandSchedule.GOLD_NODE, save)).is_true()


func test_an_old_save_with_lab_priority_gets_blue_struck_once_and_keeps_its_chapter_3_schedule() -> void:
	var save := SaveGame.new()
	save.migration = 8
	save.stamped = PackedStringArray(["research_cabbage", "research_assistant", HandSchedule.LAB_CARD, HandSchedule.CARD])
	UpgradeDesk.migrate(save)
	assert_bool(save.stamped.has(HandSchedule.CARD)).is_true()
	assert_array(HandSchedule.forbidden(save, false)).contains_exactly(["research"])
	HandSchedule.toggle(save, false, "research")  # Cleared by the player: a later load leaves it cleared.
	UpgradeDesk.migrate(save)
	assert_array(HandSchedule.forbidden(save, false)).is_empty()


func test_an_old_save_with_the_blue_and_mini_annexes_gets_their_price_back_and_drops_them() -> void:
	var save := SaveGame.new()
	save.migration = 8
	save.coins = 1000
	save.coin_limit = 1000000
	save.stamped = PackedStringArray(["research_cabbage", HandSchedule.CARD])
	save.tree_bought = PackedStringArray(["schedule_research", "schedule_mini", HandSchedule.GOLD_NODE])
	save.lab_hands_forbidden = PackedStringArray(["research", "regular"])  # Blue struck through the annex, no memo.
	UpgradeDesk.migrate(save)
	assert_array(save.tree_bought).contains_exactly([HandSchedule.GOLD_NODE])
	assert_int(save.coins).is_equal(1000 + 15000 + 25000 + 35000)  # Gold: bought at $40,000, now $5,000.
	assert_array(save.lab_hands_forbidden).contains_exactly(["regular"])


func test_an_old_saves_annex_refunds_are_paid_past_a_full_coin_limit() -> void:
	var save := SaveGame.new()
	save.migration = 8
	save.coin_limit = 40000
	save.coins = 40000
	save.tree_bought = PackedStringArray(["schedule_research", "schedule_mini", HandSchedule.GOLD_NODE])
	UpgradeDesk.migrate(save)
	assert_int(save.coins).is_equal(40000 + 15000 + 25000 + 35000)


func test_an_old_saves_golden_annex_without_its_clearance_stays_bought_and_only_the_price_difference_comes_back() -> void:
	var save := SaveGame.new()
	save.migration = 8
	save.tree_bought = PackedStringArray([HandSchedule.GOLD_NODE])
	UpgradeDesk.migrate(save)
	assert_array(save.tree_bought).contains_exactly([HandSchedule.GOLD_NODE])
	assert_bool(save.tree_bought.has("gold_hands")).is_false()
	assert_int(save.coins).is_equal(SaveGame.new().coins + 35000)


func test_the_switch_is_on_the_desk_only_once_the_schedule_is_stamped_and_its_lamp_is_lit_while_anything_is_struck() -> void:
	var schedule: HandSchedule = auto_free(SCHEDULE.instantiate())
	add_child(schedule)
	var switch: CogSwitch = schedule.get_node("Switch")
	assert_bool(switch.visible).override_failure_message("before the card").is_false()

	SaveManager.save.stamped.append(HandSchedule.CARD)
	schedule._process(0.0)
	assert_bool(switch.visible).override_failure_message("stamped").is_true()
	var lamp: StandardMaterial3D = (switch.get_node("Lamp") as MeshInstance3D).material_override
	assert_float(lamp.emission_energy_multiplier).override_failure_message("nothing struck").is_equal(0.0)

	HandSchedule.toggle(SaveManager.save, false, "regular")
	schedule._process(0.0)
	assert_float(lamp.emission_energy_multiplier).override_failure_message("something struck").is_greater(0.0)


func test_a_click_on_the_switch_brings_up_the_paper() -> void:
	SaveManager.save.stamped.append(HandSchedule.CARD)
	var schedule: HandSchedule = auto_free(SCHEDULE.instantiate())
	add_child(schedule)
	var sheet: Control = schedule.get_node("Schedule/Sheet")
	assert_bool(sheet.visible).is_false()
	(schedule.get_node("Switch") as CogSwitch).flicked.emit()
	assert_bool(sheet.visible).is_true()
