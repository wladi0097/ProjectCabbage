extends GdUnitTestSuite

const Combo := preload("res://entities/catch_combo/catch_combo.gd")
const SCENE := preload("res://entities/catch_combo/catch_combo.tscn")

var _save: SaveGame


func before_test() -> void:
	_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _save


func spawn(stamped := true) -> CatchCombo:
	if stamped:
		SaveManager.save.stamped.append(Combo.CARD)
	var combo := SCENE.instantiate() as CatchCombo
	add_child(auto_free(combo))
	return combo


func catch_times(combo: CatchCombo, count: int) -> void:
	for i in count:
		combo.caught(Vector3.ZERO)


func test_no_catches_pay_no_bonus() -> void:
	assert_float(Combo.multiplier(0, 0.1, 1.5)).is_equal(1.0)


func test_every_catch_step_adds_its_step_to_the_sale_multiplier() -> void:
	assert_float(Combo.multiplier(3, 0.1, 1.5)).is_equal_approx(1.3, 0.0001)


func test_the_sale_multiplier_stops_at_the_combo_cap() -> void:
	assert_float(Combo.multiplier(20, 0.1, 1.5)).is_equal_approx(1.5, 0.0001)


func test_a_cap_below_one_never_makes_a_catch_cost_money() -> void:
	assert_float(Combo.multiplier(3, 0.1, 0.5)).is_equal(1.0)


func test_the_combo_joins_the_group_cabbages_report_catches_to() -> void:
	assert_bool(spawn().is_in_group(&"catch_combo")).is_true()


func test_catches_count_nothing_before_the_combo_card_is_stamped() -> void:
	var combo := spawn(false)
	catch_times(combo, 3)

	assert_int(combo.steps).is_equal(0)


func test_each_catch_adds_a_combo_step() -> void:
	var combo := spawn()
	catch_times(combo, 3)

	assert_int(combo.steps).is_equal(3)


func test_catches_past_the_cap_add_no_more_steps() -> void:
	var save: SaveGame = SaveManager.save
	var combo := spawn()
	catch_times(combo, 20)

	assert_int(combo.steps).is_equal(roundi((save.combo_cap - 1.0) / save.combo_step))


func test_the_combo_holds_for_its_whole_window_without_a_catch() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	combo._process(SaveManager.save.combo_window - 0.1)

	assert_int(combo.steps).is_equal(3)


func test_past_its_window_the_combo_loses_one_step_per_decay_step() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	combo._process(SaveManager.save.combo_window + 0.05)

	assert_int(combo.steps).is_equal(2)

	combo._process(Combo.DECAY_STEP - 0.1)

	assert_int(combo.steps).is_equal(2)

	combo._process(0.1)

	assert_int(combo.steps).is_equal(1)


func test_a_catch_restarts_the_combo_window() -> void:
	var combo := spawn()
	catch_times(combo, 2)
	combo._process(SaveManager.save.combo_window - 0.1)
	combo.caught(Vector3.ZERO)
	combo._process(SaveManager.save.combo_window - 0.1)

	assert_int(combo.steps).is_equal(3)


func test_a_combo_decays_all_the_way_to_nothing() -> void:
	var combo := spawn()
	catch_times(combo, 2)
	for i in 100:
		combo._process(0.5)

	assert_int(combo.steps).is_equal(0)


func test_the_streak_counts_every_catch_in_a_row_past_the_cap() -> void:
	var combo := spawn()
	catch_times(combo, 9)

	assert_int(combo.streak).is_equal(9)


func test_a_price_refusal_does_not_break_the_catch_streak() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	combo._process(SaveManager.save.combo_window - 0.1)
	combo.hold()
	combo._process(Combo.HOLD_LIMIT - 0.1)
	combo.unhold()
	combo._process(0.05)

	assert_int(combo.streak).is_equal(3)
	assert_int(combo.steps).is_equal(3)


func test_a_price_refusal_pauses_the_window_rather_than_refilling_it() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	combo._process(SaveManager.save.combo_window - 0.1)
	combo.hold()
	combo.unhold()
	combo._process(0.2)

	assert_int(combo.steps).is_equal(2)


func test_a_refused_unit_never_thrown_back_pauses_the_window_only_so_long() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	combo.hold()
	combo._process(Combo.HOLD_LIMIT + 0.1)
	combo._process(SaveManager.save.combo_window + 0.05)

	assert_int(combo.steps).is_equal(2)


func test_the_streak_ends_once_the_combo_has_decayed_to_nothing() -> void:
	var combo := spawn()
	catch_times(combo, 2)
	for i in 100:
		combo._process(0.5)
	combo.caught(Vector3.ZERO)

	assert_int(combo.streak).is_equal(1)


func test_the_world_wires_price_refusals_to_the_combo_hold_and_release() -> void:
	var world := (load("res://worlds/MainStoryWorld.tscn") as PackedScene).get_state()
	var wired := []
	for i in world.get_connection_count():
		if world.get_connection_target(i) == NodePath("CatchCombo"):
			wired.append([world.get_connection_signal(i), world.get_connection_method(i)])

	assert_array(wired).contains([[&"refused", &"hold"], [&"thrown_back", &"unhold"]])


func test_a_missed_unit_resets_the_streak_and_the_multiplier() -> void:
	var combo := spawn()
	catch_times(combo, 4)
	combo.missed()

	assert_int(combo.streak).is_equal(0)
	assert_int(combo.steps).is_equal(0)
	assert_float(Combo.multiplier(combo.steps, SaveManager.save.combo_step, SaveManager.save.combo_cap)).is_equal(1.0)


func test_after_a_miss_the_next_catch_starts_a_new_streak() -> void:
	var combo := spawn()
	catch_times(combo, 4)
	combo.missed()
	combo.caught(Vector3.ZERO)

	assert_int(combo.streak).is_equal(1)
	assert_int(combo.steps).is_equal(1)


func test_the_combo_stencil_is_faded_paint_never_fully_opaque() -> void:
	var combo := spawn()
	combo.caught(Vector3.ZERO)

	var label := combo.get_node("Label") as Label3D
	assert_bool(label.visible).is_true()
	assert_float(label.modulate.a).is_less_equal(Combo.PAINT + 0.001)
	assert_float(Combo.PAINT).is_less(1.0)


func test_a_miss_counts_only_when_the_player_could_have_caught_it() -> void:
	assert_bool(Combo.missed_counts(false, false, false)).is_true()
	assert_bool(Combo.missed_counts(true, false, false)).is_false()
	assert_bool(Combo.missed_counts(false, true, false)).is_false()
	assert_bool(Combo.missed_counts(false, false, true)).is_false()


func test_a_unit_landing_while_the_camera_is_at_the_farm_tv_keeps_the_streak() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	FarmTv.away = true
	combo.missed()
	FarmTv.away = false

	assert_int(combo.streak).is_equal(3)
