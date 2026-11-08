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
	assert_int(MiniDrop.minis_out(units)).is_equal(2)


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
