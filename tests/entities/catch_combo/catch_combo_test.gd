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


func test_the_combo_never_runs_down_on_its_own_however_long_without_a_catch() -> void:
	var combo := spawn()
	catch_times(combo, 5)
	for i in 100:
		combo._process(1.0)

	assert_int(combo.steps).is_equal(5)
	assert_int(combo.streak).is_equal(5)


func test_at_the_cap_a_catch_after_a_long_pause_still_shows_max() -> void:
	var combo := spawn()
	catch_times(combo, 5)
	for i in 30:
		combo._process(1.0)
	combo.caught(Vector3.ZERO)

	assert_str((combo.get_node("Label") as Label3D).text).contains("MAX")


func test_the_streak_counts_every_catch_in_a_row_past_the_cap() -> void:
	var combo := spawn()
	catch_times(combo, 9)

	assert_int(combo.streak).is_equal(9)


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


func test_a_fresh_catch_shows_its_multiplier_first_over_the_units() -> void:
	var combo := spawn()
	combo.caught(Vector3.ZERO)

	var label := combo.get_node("Label") as Label3D
	assert_bool(label.no_depth_test).is_true()
	assert_str(label.text).starts_with("×1.10")


func test_the_combo_is_always_shown_once_its_card_is_stamped_even_at_no_combo() -> void:
	var combo := spawn()
	combo._process(0.1)

	var label := combo.get_node("Label") as Label3D
	assert_bool(label.visible).is_true()
	assert_str(label.text).starts_with("×1.00")


func test_the_combo_is_hidden_before_its_card_is_stamped() -> void:
	var combo := spawn(false)
	combo._process(0.1)

	assert_bool((combo.get_node("Label") as Label3D).visible).is_false()


func test_with_grace_period_a_miss_halves_the_combo_steps_instead_of_ending_them() -> void:
	assert_int(Combo.kept_steps(5, 0.0)).is_equal(0)
	assert_int(Combo.kept_steps(5, 0.5)).is_equal(2)
	assert_int(Combo.kept_steps(4, 0.5)).is_equal(2)
	var combo := spawn()
	SaveManager.save.miss_keep = 0.5
	catch_times(combo, 4)
	combo.missed()

	assert_int(combo.steps).is_equal(2)
	assert_int(combo.streak).is_equal(0)
	combo.missed()
	assert_int(combo.steps).is_equal(1)


func test_a_miss_counts_only_when_the_player_could_have_caught_it() -> void:
	assert_bool(Combo.missed_counts(false, false, false)).is_true()
	assert_bool(Combo.missed_counts(true, false, false)).is_false()
	assert_bool(Combo.missed_counts(false, true, false)).is_false()
	assert_bool(Combo.missed_counts(false, false, true)).is_false()


func test_holding_a_cabbage_is_no_excuse_but_working_the_desk_is() -> void:
	var cabbage := preload("res://entities/cabbage/cabbage.tscn").instantiate()
	var arrow := auto_free(Node3D.new()) as Node3D
	var arrow_grip := Interactable.new()
	arrow.add_child(arrow_grip)

	assert_bool(Combo.at_the_desk(null)).is_false()
	assert_bool(Combo.at_the_desk(cabbage.get_node("Interactable") as Interactable)).is_false()
	assert_bool(Combo.at_the_desk(arrow_grip)).is_true()
	var grip := cabbage.get_node("Interactable")
	cabbage.free()
	assert_bool(Combo.at_the_desk(grip)).is_false()  # A held cabbage freed (sold) is not desk work.


func test_a_cabbage_landing_while_you_hold_another_one_breaks_the_streak() -> void:
	var combo := spawn()
	var cabbage := preload("res://entities/cabbage/cabbage.tscn").instantiate()
	catch_times(combo, 3)
	var was_held := Hand.held
	Hand.held = cabbage.get_node("Interactable") as Interactable
	combo.missed()
	Hand.held = was_held
	cabbage.free()

	assert_int(combo.streak).is_equal(0)
	assert_int(combo.steps).is_equal(0)


func test_a_cabbage_landing_while_you_turn_the_price_arrow_keeps_the_streak() -> void:
	var combo := spawn()
	var arrow := auto_free(Node3D.new()) as Node3D
	var grip := Interactable.new()
	arrow.add_child(grip)
	catch_times(combo, 3)
	var was_held := Hand.held
	Hand.held = grip
	combo.missed()
	Hand.held = was_held

	assert_int(combo.streak).is_equal(3)


func test_a_unit_landing_while_the_camera_is_at_the_farm_tv_keeps_the_streak() -> void:
	var combo := spawn()
	catch_times(combo, 3)
	FarmTv.away = true
	combo.missed()
	FarmTv.away = false

	assert_int(combo.streak).is_equal(3)


func test_every_fifth_catch_in_a_row_plays_the_combo_sting_rising_a_little_each_time() -> void:
	assert_bool(Combo.milestone(4)).is_false()
	assert_bool(Combo.milestone(5)).is_true()
	assert_bool(Combo.milestone(10)).is_true()
	assert_bool(Combo.milestone(0)).is_false()
	assert_float(Combo.sting_pitch(5)).is_equal(1.0)
	assert_float(Combo.sting_pitch(10)).is_greater(Combo.sting_pitch(5))
	assert_float(Combo.sting_pitch(500)).is_equal(Combo.COMBO_PITCH_MAX)


func test_every_fifth_catch_in_a_row_plays_the_combo_sting() -> void:
	var combo := spawn()
	catch_times(combo, 4)
	assert_bool((combo.get_node("Combo") as AudioStreamPlayer).playing).is_false()
	catch_times(combo, 1)
	assert_bool((combo.get_node("Combo") as AudioStreamPlayer).playing).is_true()
