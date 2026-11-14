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


func test_the_schedule_is_an_optional_card_dealt_once_a_lab_hand_and_a_hired_hand_are_on_the_desk() -> void:
	var card := UpgradeDesk.card_data(HandSchedule.CARD)
	assert_array(card.needs).contains_exactly(["research_assistant"])
	assert_array(UpgradeDesk.Events.DRY_LEFT).override_failure_message("left unstamped it must not hold stage 2 back").contains([HandSchedule.CARD])
	assert_str(card.get("currency", "coins")).is_equal("coins")
	for other: Dictionary in UpgradeDesk.CARDS:
		assert_bool(other.get("needs", []).has(HandSchedule.CARD)).override_failure_message(other.id + " waits for it").is_false()
	# By the time it can be dealt both kinds of hand are hired.
	var save := SaveGame.new()
	var stamped := PackedStringArray()
	var todo: Array = card.needs.duplicate()
	while not todo.is_empty():
		var id: String = todo.pop_back()
		if not stamped.has(id):
			stamped.append(id)
			UpgradeDesk.apply(id, save)
			todo.append_array(UpgradeDesk.card_data(id).get("needs", []))
	assert_int(save.hands).is_greater_equal(1)
	assert_int(save.research_hands).is_greater_equal(1)


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
