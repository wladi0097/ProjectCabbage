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


func _switch(text: String) -> LightSwitch:
	var switch: LightSwitch = auto_free(LightSwitch.new())
	switch.tooltip = text
	add_child(switch)
	return switch
