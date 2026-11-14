extends GdUnitTestSuite

const SCENE := preload("res://entities/field_line/field_line.tscn")
const HANDSET := "Model/Armature/Skeleton3D/ReceiverMount/Handset"
## Long enough for the handset to be fully up.
const LIFTED := FieldLine.SWING_LAG + FieldLine.SWING_TIME + 0.2


func _machine() -> FieldLine:
	var machine: FieldLine = auto_free(SCENE.instantiate())
	add_child(machine)
	return machine


func _handset_at(machine: FieldLine) -> Vector3:
	return machine.to_local((machine.get_node(HANDSET) as Node3D).global_position)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_a_lamp_is_lit_for_every_farm_owned_and_no_more() -> void:
	assert_int(FieldLine.lamps_lit(0)).is_equal(0)
	assert_int(FieldLine.lamps_lit(5)).is_equal(5)
	assert_int(FieldLine.lamps_lit(24)).is_equal(24)
	var machine := _machine()
	machine.show_farms(5, 24, false)
	assert_int(machine.lit()).is_equal(5)
	assert_float((machine.get_node("Model/Lamps") as MeshInstance3D).get_instance_shader_parameter(&"lit")).is_equal(5.0)


func test_the_district_has_a_lamp_for_each_of_its_24_farms_and_never_lights_more() -> void:
	assert_int(FieldLine.LAMPS).is_equal(24)
	assert_int(FieldLine.lamps_lit(30)).is_equal(24)
	assert_int(FieldLine.lamps_lit(-1)).is_equal(0)


func test_the_window_shows_the_farms_owned_and_the_total() -> void:
	assert_str(FieldLine.count_text(7, 24)).is_equal("7/24")
	var machine := _machine()
	machine.show_farms(7, 24)
	assert_str((machine.get_node("Count") as Label3D).text).is_equal("7/24")


func test_new_farms_light_their_lamps_one_after_the_other_like_relays() -> void:
	var machine := _machine()
	machine.show_farms(2, 24, false)
	machine.show_farms(5, 24)
	await _wait(FieldLine.RELAY_STEP * 1.5)
	assert_int(machine.lit()).is_between(3, 4)
	await _wait(FieldLine.RELAY_STEP * 3)
	assert_int(machine.lit()).is_equal(5)


func test_farms_lost_put_their_lamps_out_at_once() -> void:
	var machine := _machine()
	machine.show_farms(9, 24, false)
	machine.show_farms(4, 24)
	assert_int(machine.lit()).is_equal(4)


func test_lifting_the_handset_opens_the_line_once_until_it_is_hung_up() -> void:
	var machine := _machine()
	var opened := [0]
	machine.line_opened.connect(func() -> void: opened[0] += 1)
	machine.lift()
	machine.lift()
	await _wait(LIFTED)
	machine.lift()
	assert_int(opened[0]).is_equal(1)
	assert_bool(machine.is_open()).is_true()
	machine.hang_up()
	machine.lift()
	await _wait(LIFTED)
	assert_int(opened[0]).is_equal(2)


func test_the_line_opens_when_the_handset_is_up_not_at_the_click() -> void:
	var machine := _machine()
	var opened := [0]
	machine.line_opened.connect(func() -> void: opened[0] += 1)
	machine.lift()
	assert_int(opened[0]).is_equal(0)


func test_a_click_on_the_handset_lifts_it() -> void:
	var machine := _machine()
	(machine.get_node(HANDSET + "/Interactable") as Interactable).grabbed.emit()
	assert_bool(machine.is_open()).is_true()


func test_the_lifted_handset_rises_out_of_its_cradle_and_swings() -> void:
	var lifted := FieldLine.handset_offset(1.0, 1.0)
	assert_float(lifted.origin.y).is_greater(0.04)
	assert_float(absf(lifted.basis.get_euler().y)).is_greater(0.25)
	assert_bool(FieldLine.handset_offset(0.0, 0.0).is_equal_approx(Transform3D.IDENTITY)).is_true()
	var machine := _machine()
	var cradle := _handset_at(machine)
	machine.lift()
	await _wait(LIFTED)
	assert_vector(_handset_at(machine) - cradle).is_equal_approx(FieldLine.LIFT, Vector3.ONE * 0.005)


func test_hanging_up_puts_the_handset_back_in_its_cradle() -> void:
	var machine := _machine()
	var cradle := _handset_at(machine)
	machine.lift()
	await _wait(LIFTED)
	machine.hang_up()
	assert_bool(machine.is_open()).is_false()
	await _wait(0.8)
	assert_vector(_handset_at(machine)).is_equal_approx(cradle, Vector3.ONE * 0.001)


func test_a_hovering_hand_stirs_the_handset_but_does_not_open_the_line() -> void:
	var machine := _machine()
	var cradle := _handset_at(machine)
	(machine.get_node(HANDSET + "/Interactable") as Interactable).hovered.emit()
	await _wait(0.3)
	assert_float(_handset_at(machine).y - cradle.y).is_between(0.005, 0.03)
	assert_bool(machine.is_open()).is_false()


func test_every_sound_moment_of_the_machine_has_its_sound() -> void:
	var machine := _machine()
	for cue: String in ["Lift", "LineOpen", "HangUp", "Relay", "Land"]:
		assert_object((machine.get_node(cue) as SoundCue).stream).override_failure_message(cue).is_not_null()


func test_the_handset_sounds_as_it_leaves_the_cradle_and_the_line_clicks_open_once_it_is_up() -> void:
	var machine := _machine()
	var open := machine.get_node("LineOpen") as SoundCue
	machine.lift()
	assert_bool((machine.get_node("Lift") as SoundCue).playing).is_true()
	assert_bool(open.playing).is_false()
	await _wait(LIFTED)
	assert_bool(open.playing).is_true()


func test_the_handset_clacks_when_it_lands_in_the_cradle_not_when_it_starts_down() -> void:
	var machine := _machine()
	var clack := machine.get_node("HangUp") as SoundCue
	machine.lift()
	await _wait(LIFTED)
	machine.hang_up()
	assert_bool(clack.playing).is_false()
	await _wait(0.3)
	assert_bool(clack.playing).is_true()


func test_a_lamp_that_lights_ticks_its_relay_and_a_loaded_save_lights_them_silently() -> void:
	var machine := _machine()
	var relay := machine.get_node("Relay") as SoundCue
	machine.show_farms(3, 24, false)
	assert_bool(relay.playing).is_false()
	machine.show_farms(4, 24)
	machine._relay.custom_step(0.01)
	assert_bool(relay.playing).is_true()


func test_the_machine_thuds_when_it_lands_on_the_desk_not_when_it_starts_to_fall() -> void:
	var machine := _machine()
	var land := machine.get_node("Land") as SoundCue
	machine.drop_in()
	assert_bool(land.playing).is_false()
	await _wait(FieldLine.DROP_TIME + 0.1)
	assert_bool(land.playing).is_true()
