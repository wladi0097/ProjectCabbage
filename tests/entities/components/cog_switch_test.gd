extends GdUnitTestSuite


func test_a_switch_is_a_button_that_shows_what_it_switches() -> void:
	var switch := _switch("Desk lamp")
	var hover := Interactable.of(switch)
	assert_object(hover).is_not_null()
	assert_bool(hover.pressable).is_true()
	assert_str(hover.tooltip).is_equal("Desk lamp")


func test_pressing_a_switch_flicks_it() -> void:
	var switch := _switch("Desk lamp")
	var flicks: Array[int] = [0]
	switch.flicked.connect(func() -> void: flicks[0] += 1)
	Interactable.of(switch).grabbed.emit()
	assert_int(flicks[0]).is_equal(1)


func test_a_disabled_switch_does_not_catch_the_hand() -> void:
	var switch := _switch("Desk lamp")
	switch.set_enabled(false)
	assert_object(Interactable.of(switch)).is_null()
	switch.set_enabled(true)
	assert_object(Interactable.of(switch)).is_not_null()


func test_a_switch_that_is_on_lights_its_own_lamp_only() -> void:
	var on := _switch("Desk lamp")
	var off := _switch("Radio")
	on.show_on(true, false)
	off.show_on(false, false)
	assert_float(_glow(on)).is_greater(0.0)
	assert_float(_glow(off)).is_equal(0.0)


func test_the_cog_turns_while_hovered_and_stops_when_left() -> void:
	var switch := _switch("Desk lamp")
	var cog: Node3D = switch.get_node("Pivot/Cog")
	Interactable.of(switch).hovered.emit()
	for i in 30:
		switch._process(0.05)
	var turned := cog.rotation.z
	assert_float(absf(turned)).is_greater(0.1)
	switch._process(0.05)
	assert_float(absf(cog.rotation.z - turned)).is_greater(0.01)
	Interactable.of(switch).unhovered.emit()
	for i in 60:
		switch._process(0.05)
	var stopped := cog.rotation.z
	switch._process(0.05)
	assert_float(cog.rotation.z).is_equal_approx(stopped, 0.0001)


func test_the_cog_eases_in_and_out_rather_than_jumping_to_speed() -> void:
	var first := CogSwitch.eased_speed(0.0, true, 0.05)
	assert_float(first).is_greater(0.0)
	assert_float(first).is_less(CogSwitch.SPIN_SPEED * 0.5)
	var slowing := CogSwitch.eased_speed(CogSwitch.SPIN_SPEED, false, 0.05)
	assert_float(slowing).is_greater(CogSwitch.SPIN_SPEED * 0.5)
	assert_float(CogSwitch.eased_speed(CogSwitch.SPIN_SPEED * 0.005, false, 0.05)).is_equal(0.0)


func test_a_hovered_cog_lifts_and_settles_back_when_left() -> void:
	var switch := _switch("Desk lamp")
	var pivot: Node3D = switch.get_node("Pivot")
	var rest := pivot.position
	switch.set_hovered(true)
	for i in 20:
		switch._process(0.05)
	assert_float(pivot.position.z).is_greater(rest.z)
	switch.set_hovered(false)
	for i in 40:
		switch._process(0.05)
	assert_float(pivot.position.z).is_equal_approx(rest.z, 0.0001)


func test_the_cog_still_tells_its_owner_when_clicked_and_gives_a_quarter_turn() -> void:
	var switch := _switch("Desk lamp")
	var cog: Node3D = switch.get_node("Pivot/Cog")
	var flicks: Array[int] = [0]
	switch.flicked.connect(func() -> void: flicks[0] += 1)
	Interactable.of(switch).grabbed.emit()
	assert_int(flicks[0]).is_equal(1)
	switch._kicking.custom_step(CogSwitch.FLICK_TIME + 0.05)  # Played to its end, whatever the machine's load.
	switch._process(0.0)
	assert_float(cog.rotation.z).is_equal_approx(PI / 2.0, 0.01)


func test_its_lamp_shows_whether_the_setting_is_on() -> void:
	var switch := _switch("Desk lamp")
	switch.show_on(true)
	assert_float(_glow(switch)).is_equal_approx(CogSwitch.LAMP_ON, 0.001)
	switch.show_on(false)
	assert_float(_glow(switch)).is_equal(0.0)


func _glow(switch: CogSwitch) -> float:
	return ((switch.get_node("Lamp") as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier


func _switch(text: String) -> CogSwitch:
	var switch: CogSwitch = auto_free(load("res://entities/components/cog_switch.tscn").instantiate())
	switch.tooltip = text
	add_child(switch)
	return switch
