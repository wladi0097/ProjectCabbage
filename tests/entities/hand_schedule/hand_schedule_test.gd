extends GdUnitTestSuite

const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const SCHEDULE := preload("res://entities/hand_schedule/hand_schedule.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


## A save with the schedule stamped and `nodes` bought on the projector.
func _stamped(nodes: Array = []) -> SaveGame:
	var save := SaveGame.new()
	save.stamped.append(HandSchedule.CARD)
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


func test_the_schedule_card_lists_plain_cabbages_and_each_other_kind_comes_with_its_projector_node() -> void:
	var save := _stamped()
	assert_bool(HandSchedule.listed(save, "regular")).is_true()
	for kind: String in ["research", "mini", "golden"]:
		assert_bool(HandSchedule.listed(save, kind)).override_failure_message(kind + " without its node").is_false()
		save.tree_bought.append(HandSchedule.NODES[kind])
		assert_bool(HandSchedule.listed(save, kind)).override_failure_message(kind + " with its node").is_true()


func test_without_the_schedule_card_no_kind_is_listed_whatever_the_projector_holds() -> void:
	var save := SaveGame.new()
	save.tree_bought = PackedStringArray(HandSchedule.NODES.values())
	for kind: String in HandSchedule.KINDS:
		assert_bool(HandSchedule.listed(save, kind)).override_failure_message(kind).is_false()


func test_the_schedule_cannot_be_changed_for_a_kind_whose_node_is_not_bought() -> void:
	var save := _stamped()
	assert_bool(HandSchedule.toggle(save, false, "research")).is_false()
	assert_bool(HandSchedule.toggle(save, true, "golden")).is_false()
	assert_array(save.hands_forbidden).is_empty()
	assert_array(save.lab_hands_forbidden).is_empty()


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


func test_the_handling_schedule_is_offered_in_chapter_3_and_asks_for_two_farms() -> void:
	var card := UpgradeDesk.card_data(HandSchedule.CARD)
	var ids: Array = UpgradeDesk.CARDS.map(func(each: Dictionary) -> String: return each.id)
	assert_int(ids.find(HandSchedule.CARD)).is_greater(ids.find("market_intelligence"))
	# Dealt once NEGOTIATION is stamped: from then on a second farm can be bought.
	assert_array(card.needs).contains_exactly(["negotiation"])
	assert_str(FarmRegister.GATES[1]).is_equal("negotiation")
	assert_dict(UpgradeDesk.costs(card)).is_equal({farms = 2, coins = int(card.price)})
	var save := SaveGame.new()
	save.coins = int(card.price)
	save.farms_owned = PackedStringArray(["K-1"])
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(card))).is_false()
	save.farms_owned.append("K-2")
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(card))).is_true()
	# Priced for chapter 3, within the purse the cash card gives.
	assert_int(card.price).is_greater(SaveGame.new().coin_limit)
	assert_int(card.price).is_less_equal(SaveGame.new().coin_limit * UpgradeDesk.LIMIT_RAISE)


func test_nothing_waits_on_the_handling_schedule() -> void:
	assert_array(UpgradeDesk.Events.DRY_LEFT).contains([HandSchedule.CARD])
	for other: Dictionary in UpgradeDesk.CARDS:
		assert_bool(other.get("needs", []).has(HandSchedule.CARD)).override_failure_message(other.id + " waits for it").is_false()
	# Only its own annexes on the projector name it.
	for node: Dictionary in Projector.NODES:
		if node.get("needs", []).has(HandSchedule.CARD):
			assert_array(HandSchedule.NODES.values()).override_failure_message(node.id).contains([node.id])


func test_an_old_save_that_stamped_the_schedule_before_chapter_3_keeps_it() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["research_assistant", HandSchedule.CARD])
	UpgradeDesk.migrate(save)
	assert_bool(save.stamped.has(HandSchedule.CARD)).is_true()
	assert_bool(HandSchedule.listed(save, "regular")).is_true()


func test_no_annex_is_on_show_or_for_sale_before_the_schedule_is_stamped() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(UpgradeDesk.CARDS.map(func(each: Dictionary) -> String: return each.id))
	save.stamped.remove_at(save.stamped.find(HandSchedule.CARD))
	save.tree_bought.append(Associate.GOLD_SALE)
	save.coins = 100000000
	for kind: String in ["research", "mini", "golden"]:
		assert_bool(Projector.is_shown(HandSchedule.NODES[kind], save)).override_failure_message(kind).is_false()
		assert_bool(Projector.buy(HandSchedule.NODES[kind], save)).override_failure_message(kind).is_false()
	save.stamped.append(HandSchedule.CARD)
	assert_bool(Projector.is_shown(HandSchedule.NODES.research, save)).is_true()
	assert_bool(Projector.buy(HandSchedule.NODES.research, save)).is_true()


func test_the_annexes_are_priced_for_chapter_3_and_fit_the_purse_the_cash_card_gives() -> void:
	var purse := SaveGame.new().coin_limit * UpgradeDesk.LIMIT_RAISE
	for kind: String in ["research", "mini", "golden"]:
		var price := int(Projector.node_data(HandSchedule.NODES[kind]).price)
		assert_int(price).override_failure_message(kind).is_greater_equal(10000)  # Chapter 1 sold them for $120 to $6,000.
		assert_int(price).override_failure_message(kind).is_less_equal(purse)


func test_every_kind_past_the_plain_one_has_one_projector_node_in_a_chain_under_the_research_lab() -> void:
	assert_array(HandSchedule.NODES.keys()).contains_exactly_in_any_order(["research", "mini", "golden"])
	var parent := "dept_qa"
	for kind: String in ["research", "mini", "golden"]:
		var node := Projector.node_data(HandSchedule.NODES[kind])
		assert_str(node.parent).override_failure_message(kind).is_equal(parent)
		assert_int(int(node.price)).is_greater(0)
		parent = node.id
	assert_array(Projector.node_data(HandSchedule.NODES.research).needs).contains([HandSchedule.CARD])


func test_the_golden_annex_waits_for_golden_cabbages_and_the_hired_hands_clearance() -> void:
	var node := Projector.node_data(HandSchedule.NODES.golden)
	assert_array(node.needs).contains(["golden_cabbage"])
	assert_str(node.after).is_equal(Associate.GOLD_SALE)


func test_each_annex_costs_more_than_the_one_before() -> void:
	var last := 0
	for kind: String in ["research", "mini", "golden"]:
		var price := int(Projector.node_data(HandSchedule.NODES[kind]).price)
		assert_int(price).override_failure_message(kind).is_greater(last)
		last = price


func test_the_switch_is_on_the_desk_only_once_the_schedule_is_stamped_and_its_lamp_is_lit_while_anything_is_struck() -> void:
	var schedule: HandSchedule = auto_free(SCHEDULE.instantiate())
	add_child(schedule)
	var switch: LightSwitch = schedule.get_node("Switch")
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
	(schedule.get_node("Switch") as LightSwitch).flicked.emit()
	assert_bool(sheet.visible).is_true()
