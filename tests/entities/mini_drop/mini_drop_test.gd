extends GdUnitTestSuite

const SCENE := preload("res://entities/mini_drop/mini_drop.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


func _routes(split: float, count: int) -> String:
	var owed := 0.0
	var routes := ""
	for i in count:
		var research := MiniDrop.goes_to_research(owed, split)
		owed = MiniDrop.owed_after(owed, split, research)
		routes += "R" if research else "S"
	return routes


func test_the_sales_setting_never_routes_a_mini_to_research() -> void:
	assert_str(_routes(0.0, 6)).is_equal("SSSSSS")


func test_the_split_setting_alternates_sales_and_research_starting_with_sales() -> void:
	assert_str(_routes(0.5, 6)).is_equal("SRSRSR")


func test_the_research_setting_routes_every_mini_to_research() -> void:
	assert_str(_routes(1.0, 6)).is_equal("RRRRRR")


func test_every_lever_setting_has_its_own_notch() -> void:
	for split: float in [0.0, 0.5, 1.0]:
		assert_float(MiniDrop.split_at(MiniDrop.lever_angle(split))).is_equal(split)


func test_the_lever_turns_right_for_sales_and_left_for_research() -> void:
	assert_float(MiniDrop.lever_angle(0.0)).is_greater(0.0)
	assert_float(MiniDrop.lever_angle(0.5)).is_equal(0.0)
	assert_float(MiniDrop.lever_angle(1.0)).is_less(0.0)


func test_a_lever_let_go_between_notches_snaps_to_the_nearest() -> void:
	assert_float(MiniDrop.split_at(MiniDrop.SWING * 0.6)).is_equal(0.0)
	assert_float(MiniDrop.split_at(MiniDrop.SWING * 0.4)).is_equal(0.5)
	assert_float(MiniDrop.split_at(-MiniDrop.SWING * 0.6)).is_equal(1.0)


func test_a_lever_turned_past_its_ends_stays_on_the_end_notch() -> void:
	assert_float(MiniDrop.split_at(-5.0)).is_equal(1.0)
	assert_float(MiniDrop.split_at(5.0)).is_equal(0.0)


func test_a_click_steps_the_lever_from_sales_to_split_to_research_and_round() -> void:
	assert_float(MiniDrop.next_split(0.0)).is_equal(0.5)
	assert_float(MiniDrop.next_split(0.5)).is_equal(1.0)
	assert_float(MiniDrop.next_split(1.0)).is_equal(0.0)


func test_a_mini_enters_and_leaves_the_glass_pipe_on_its_floor_and_bounces_between() -> void:
	assert_vector(MiniDrop.zip_at(0.0)).is_equal_approx(MiniDrop.GLASS_FROM, Vector3.ONE * 0.0001)
	assert_vector(MiniDrop.zip_at(1.0)).is_equal_approx(MiniDrop.GLASS_TO, Vector3.ONE * 0.0001)
	assert_float(MiniDrop.zip_at(0.25).y).is_greater(MiniDrop.GLASS_FROM.y)


func test_only_unsold_minis_count_toward_the_cap() -> void:
	var units: Array = []
	for flags: Array in [[true, false], [true, true], [false, false], [true, false]]:
		var cabbage: Cabbage = auto_free(Cabbage.new())
		cabbage.mini = flags[0]
		cabbage.sold = flags[1]
		units.append(cabbage)
	assert_int(MiniDrop.minis_out(units, false)).is_equal(2)


func _minis(count: int, thinned: bool) -> Array:
	var units: Array = []
	for i in count:
		var cabbage: Cabbage = auto_free(Cabbage.new())
		cabbage.mini = true
		if thinned:
			cabbage.add_to_group(MiniDrop.THINNED)
		units.append(cabbage)
	return units


func test_the_faster_tube_still_drops_more_minis_after_thinning_is_ordered() -> void:
	# A desk full of harvest minis leaves the timed drop (MINIATURISATION, PNEUMATIC PRESSURE) its own room.
	var desk := _minis(MiniDrop.MAX_MINIS, true)
	assert_int(MiniDrop.minis_out(desk, false)).is_equal(0)
	assert_int(MiniDrop.minis_out(desk, true)).is_equal(MiniDrop.MAX_MINIS)


func test_timed_minis_never_hold_back_the_harvest_minis() -> void:
	var desk := _minis(MiniDrop.MAX_MINIS, false)
	assert_int(MiniDrop.minis_out(desk, true)).is_equal(0)


func test_the_desk_never_holds_more_than_two_full_pools_of_minis() -> void:
	var desk := _minis(MiniDrop.MAX_MINIS, true) + _minis(MiniDrop.MAX_MINIS, false)
	assert_int(MiniDrop.minis_out(desk, true) + MiniDrop.minis_out(desk, false)).is_equal(2 * MiniDrop.MAX_MINIS)


func test_the_levers_plate_is_lettered_mini_across_its_full_width() -> void:
	SaveManager.save = SaveGame.new()
	SaveManager.save.stamped = PackedStringArray(["mini_tube", "tube_lever"])
	var drop: MiniDrop = auto_free(SCENE.instantiate())
	add_child(drop)
	var lettering: Label3D = drop._heading
	assert_str(lettering.text).is_equal("MINI")
	assert_array(drop._labels.map(func(l: Label3D) -> String: return l.text)).is_equal(["SALES", "SPLIT", "RESEARCH"])
	# Flat on the plate (it faces where the plate faces), a few mm proud of the pivot's plane, upright
	# on the plate's centre line.
	var off := lettering.position - MiniDrop.PIVOT
	assert_vector(lettering.basis.z.normalized()).is_equal_approx(-MiniDrop.LEVER_AXIS, Vector3.ONE * 0.001)
	assert_vector(lettering.basis.y.normalized()).is_equal_approx(MiniDrop.ARM, Vector3.ONE * 0.001)
	assert_float(absf(off.dot(MiniDrop.LEVER_AXIS))).is_less(0.01)
	assert_float(absf(off.dot(MiniDrop.RIGHT))).is_less(0.002)
	# Its letters fill most of the plate's inset face (a 0.162 m fan, 43° each side) and stay on it.
	var up := off.dot(MiniDrop.ARM)
	var width := lettering.font.get_string_size(lettering.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lettering.font_size).x * lettering.pixel_size
	var caps := lettering.font.get_ascent(lettering.font_size) * 0.78 * lettering.pixel_size
	var face := 2.0 * up * sin(deg_to_rad(43.0))
	assert_float(width).is_greater(0.7 * face)
	assert_float(width / 2.0).is_less((up - caps / 2.0) * tan(deg_to_rad(43.0)))
	assert_float(Vector2(width / 2.0, up + caps / 2.0).length()).is_less(0.162)


func test_only_the_slot_the_lever_points_at_is_lit_and_the_heading_stays_dimmer() -> void:
	SaveManager.save = SaveGame.new()
	SaveManager.save.stamped = PackedStringArray(["mini_tube", "tube_lever"])
	SaveManager.save.tube_split = 0.5
	var drop: MiniDrop = auto_free(SCENE.instantiate())
	add_child(drop)
	assert_array(drop._labels.map(func(l: Label3D) -> Color: return l.modulate)).is_equal(
			[MiniDrop.LABEL_DIM, MiniDrop.LABEL_LIT, MiniDrop.LABEL_DIM])
	assert_float(drop._heading.modulate.a).is_less(MiniDrop.LABEL_LIT.a)


## Lever, pedestal, labels and both colliders: all shown, or all absent.
func _lever_parts_shown(drop: MiniDrop) -> Array:
	var shown := [drop.get_node("Tube/Model/Lever").visible, drop.get_node("Tube/Model/LeverBase").visible,
			not drop.get_node("Tube/Pedestal/Shape").disabled, not drop.get_node("Tube/Handle/Shape").disabled,
			drop.get_node("Tube/Handle/Interactable").enabled]
	for child in drop.get_node("Tube").get_children():
		if child is Label3D:
			shown.append(child.visible)
	return shown


func test_the_mini_levers_only_appear_once_the_switch_lever_is_bought() -> void:
	SaveManager.save = SaveGame.new()
	SaveManager.save.stamped = PackedStringArray(["mini_tube"])
	var drop: MiniDrop = auto_free(SCENE.instantiate())
	add_child(drop)
	await await_idle_frame()
	assert_array(_lever_parts_shown(drop)).not_contains([true])

	SaveManager.save.stamped.append("tube_lever")
	await await_idle_frame()
	await await_idle_frame()
	assert_array(_lever_parts_shown(drop)).not_contains([false])


func test_a_save_that_already_has_the_switch_lever_loads_with_the_lever_in_place() -> void:
	SaveManager.save = SaveGame.new()
	SaveManager.save.stamped = PackedStringArray(["mini_tube", "tube_lever"])
	var drop: MiniDrop = auto_free(SCENE.instantiate())
	add_child(drop)
	assert_array(_lever_parts_shown(drop)).not_contains([false])


func test_every_farm_harvest_sends_a_mini_down_the_tube_once_thinning_is_stamped() -> void:
	assert_int(MiniDrop.thinned_after(0, 3, true)).is_equal(3)
	assert_int(MiniDrop.thinned_after(2, 1, true)).is_equal(3)


func test_farm_harvests_send_no_minis_without_the_thinning_card() -> void:
	assert_int(MiniDrop.thinned_after(0, 3, false)).is_equal(0)


func test_thinning_queues_at_most_max_minis_and_skips_the_rest() -> void:
	assert_int(MiniDrop.thinned_after(4, 10, true)).is_equal(MiniDrop.MAX_MINIS)


func test_a_harvest_count_that_goes_down_queues_nothing() -> void:
	assert_int(MiniDrop.thinned_after(1, -5, true)).is_equal(1)


func _research_save(micro: bool) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["mini_cabbages", "mini_tube", "mini_station"] + (["micro_samples"] if micro else []))
	save.mini_grow_chance = 1.0
	return save


func test_a_research_mini_is_not_grown_once_the_micro_sample_protocol_pays_more_for_it_small() -> void:
	var save := _research_save(true)
	assert_float(save.mini_value * QaBay.MICRO_SAMPLE).is_greater(1.0)  # Small beats a full unit's Findings.
	assert_bool(MiniDrop.grows_in_tube(save, 0.0, true)).is_false()


func test_before_the_protocol_a_research_mini_still_grows() -> void:
	assert_bool(MiniDrop.grows_in_tube(_research_save(false), 0.0, true)).is_true()


func test_a_sales_mini_still_grows_either_way() -> void:
	assert_bool(MiniDrop.grows_in_tube(_research_save(false), 0.0, false)).is_true()
	assert_bool(MiniDrop.grows_in_tube(_research_save(true), 0.0, false)).is_true()


## A real drop in the tree on `save`, its lab-free tube or mat sending minis into this suite.
func _drop(save: SaveGame) -> MiniDrop:
	SaveManager.save = save
	var drop: MiniDrop = auto_free(SCENE.instantiate())
	add_child(drop)
	drop.set_process(false)
	return drop


func _minis_sent() -> Array:
	var sent := get_children().filter(func(node: Node) -> bool: return node is Cabbage)
	for cabbage: Node in sent:
		auto_free(cabbage)
	return sent


func test_a_mini_from_the_harvest_is_counted_in_the_harvest_pool_not_the_tubes() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["mini_tube", "mini_thinning"])
	var drop := _drop(save)
	save.farm_harvests += 1
	drop._process(0.01)
	var sent := _minis_sent()
	assert_int(sent.size()).is_equal(1)
	assert_int(MiniDrop.minis_out(sent, true)).is_equal(1)
	assert_int(MiniDrop.minis_out(sent, false)).is_equal(0)


func test_six_harvest_minis_on_the_desk_do_not_stop_the_tubes_timed_drop() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["mini_cabbages", "mini_tube", "mini_thinning"])
	var drop := _drop(save)
	for i in MiniDrop.MAX_MINIS:
		drop._spawn(true)
	drop._wait = 0.0
	drop._process(0.01)
	var sent := _minis_sent()
	assert_int(MiniDrop.minis_out(sent, true)).is_equal(MiniDrop.MAX_MINIS)
	assert_int(MiniDrop.minis_out(sent, false)).is_equal(1)
