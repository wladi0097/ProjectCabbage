extends GdUnitTestSuite

const SCENE := preload("res://entities/war/fight/war_control.tscn")
const S := WarControl.State


func _control() -> WarControl:
	var c: WarControl = auto_free(SCENE.instantiate())
	add_child(c)
	return c


func test_the_timer_shows_minutes_and_two_digit_seconds() -> void:
	assert_str(WarControl.time_text(90.0)).is_equal("1:30")
	assert_str(WarControl.time_text(65.0)).is_equal("1:05")
	assert_str(WarControl.time_text(9.0)).is_equal("0:09")


func test_the_timer_rounds_up_and_stops_at_zero() -> void:
	assert_str(WarControl.time_text(59.2)).is_equal("1:00")
	assert_str(WarControl.time_text(0.4)).is_equal("0:01")
	assert_str(WarControl.time_text(-3.0)).is_equal("0:00")


func test_the_flaps_show_the_time_given() -> void:
	var c := _control()
	c.set_time(83.0)
	var shown := ""
	for n in ["Min", "Colon", "Sec10", "Sec1"]:
		shown += (c.get_node("Panel/Digits/" + n) as Label3D).text
	assert_str(shown).is_equal("1:23")


func test_start_can_t_be_pressed_while_it_is_disabled() -> void:
	assert_bool(WarControl.can_press(WarControl.START, S.READY, false, false)).is_false()
	assert_bool(WarControl.can_press(WarControl.START, S.READY, true, false)).is_true()
	var c := _control()
	c.set_start_enabled(false)
	var fired := [false]
	c.start_pressed.connect(func() -> void: fired[0] = true)
	assert_bool(c.press(WarControl.START)).is_false()
	assert_bool(fired[0]).is_false()


func test_start_is_dead_once_the_fight_runs_and_after_it() -> void:
	assert_bool(WarControl.can_press(WarControl.START, S.RUNNING, true, true)).is_false()
	assert_bool(WarControl.can_press(WarControl.START, S.ENDED, true, true)).is_false()


func test_a_live_start_press_fires_start_pressed() -> void:
	var c := _control()
	var fired := [false]
	c.start_pressed.connect(func() -> void: fired[0] = true)
	assert_bool(c.press(WarControl.START)).is_true()
	assert_bool(fired[0]).is_true()


func test_abort_can_be_pressed_before_the_fight() -> void:
	assert_bool(WarControl.can_press(WarControl.ABORT, S.READY, false, false)).is_true()


func test_abort_is_dead_during_a_fight_unless_flee_is_allowed() -> void:
	assert_bool(WarControl.can_press(WarControl.ABORT, S.RUNNING, true, false)).is_false()
	assert_bool(WarControl.can_press(WarControl.ABORT, S.RUNNING, true, true)).is_true()
	assert_bool(WarControl.can_press(WarControl.ABORT, S.ENDED, true, true)).is_false()
	var c := _control()
	c.set_state(S.RUNNING)
	var fired := [0]
	c.abort_pressed.connect(func() -> void: fired[0] += 1)
	assert_bool(c.press(WarControl.ABORT)).is_false()
	c.set_flee_allowed(true)
	assert_bool(c.press(WarControl.ABORT)).is_true()
	assert_int(fired[0]).is_equal(1)


func test_abort_reads_retreat_while_it_is_the_flee_button() -> void:
	var c := _control()
	var plate: Label3D = c.get_node("Panel/AbortPlate")
	c.set_flee_allowed(true)
	assert_str(plate.text).is_equal(WarControl.ABORT_WORD)
	c.set_state(S.RUNNING)
	assert_str(plate.text).is_equal(WarControl.FLEE_WORD)


func test_the_timer_blinks_red_only_in_a_fight_s_last_ten_seconds() -> void:
	assert_bool(WarControl.last_seconds(S.RUNNING, 10.0)).is_true()
	assert_bool(WarControl.last_seconds(S.RUNNING, 11.0)).is_false()
	assert_bool(WarControl.last_seconds(S.READY, 5.0)).is_false()


func test_a_ray_down_onto_a_button_finds_it_and_a_ray_beside_finds_nothing() -> void:
	var c := _control()
	var start: Vector3 = c.get_node("Panel/StartCap").global_position
	var abort: Vector3 = c.get_node("Panel/AbortCap").global_position
	assert_str(c.part_at(start + Vector3.UP, Vector3.DOWN)).is_equal(WarControl.START)
	assert_str(c.part_at(abort + Vector3.UP, Vector3.DOWN)).is_equal(WarControl.ABORT)
	var timer: Vector3 = c.get_node("Panel/Digits/Min").global_position
	assert_str(c.part_at(timer + Vector3.UP, Vector3.DOWN)).is_equal("")


func test_the_timer_sits_above_start_and_abort_which_stand_side_by_side() -> void:
	var c := _control()
	var timer: Vector3 = c.get_node("Panel/Digits/Min").global_position
	var start: Vector3 = c.get_node("Panel/StartCap").global_position
	var abort: Vector3 = c.get_node("Panel/AbortCap").global_position
	assert_float(timer.z).is_less(start.z)  # Up the screen (towards the wall) is -z.
	assert_float(start.z).is_equal_approx(abort.z, 0.001)
	assert_float(start.x).is_less(abort.x)
