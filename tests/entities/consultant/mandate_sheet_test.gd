extends GdUnitTestSuite

const SHEET := preload("res://entities/consultant/mandate_sheet.tscn")
const Slate := preload("res://entities/price_slate/price_slate.gd")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


## The mandate on its own, closed, for a street at marketing 1.5 (mood 1) with $2 chalked.
func _sheet() -> MandateSheet:
	SaveManager.save.slate_unlocked = true
	SaveManager.save.marketing = 1.5
	SaveManager.save.sale_price = 2
	var layer: CanvasLayer = auto_free(SHEET.instantiate())
	add_child(layer)
	var sheet: MandateSheet = layer.get_node("Sheet")
	sheet.set_process(false)
	return sheet


func test_the_mandate_closes_on_x_esc_or_a_click_outside() -> void:
	var sheet := _sheet()
	sheet.open()
	(sheet.get_node("%Close") as Button).pressed.emit()
	assert_bool(sheet.visible).override_failure_message("X").is_false()

	sheet.open()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	sheet._input(esc)
	assert_bool(sheet.visible).override_failure_message("Esc").is_false()

	sheet.open()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	sheet.get_node("Shade").gui_input.emit(click)
	assert_bool(sheet.visible).override_failure_message("a click outside").is_false()


func test_the_mandates_steppers_set_the_bounce_floor_and_ceiling() -> void:
	var sheet := _sheet()
	(sheet.get_node("%BounceUp") as Button).pressed.emit()
	(sheet.get_node("%FloorUp") as Button).pressed.emit()
	(sheet.get_node("%CeilingDown") as Button).pressed.emit()

	var save := SaveManager.save
	assert_int(save.consultant_bounce).is_equal(15)
	assert_int(save.consultant_floor).is_equal(2)
	assert_int(save.consultant_ceiling).is_equal(17)  # One under the slate's $18 top.


func test_every_button_on_the_mandate_clicks_like_the_menus() -> void:
	var sheet := _sheet()
	var click: AudioStreamPlayer = sheet.get_parent().get_node("Click")
	assert_str(click.stream.resource_path).is_equal("res://assets/audio/ui/keyboard_keystroke.wav")
	var buttons := sheet.find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_equal(8)
	for button: Button in buttons:
		assert_bool(button.button_down.is_connected(click.play)).override_failure_message(button.name + " is silent").is_true()


func test_the_mandate_shows_the_price_and_the_refusals_right_now() -> void:
	var sheet := _sheet()
	var save := SaveManager.save
	save.sale_price = 6
	sheet.open()

	assert_str((sheet.get_node("%Price") as Label).text).is_equal("$6")
	assert_str((sheet.get_node("%Refused") as Label).text).is_equal("44%")
	assert_str((sheet.get_node("%Ceiling") as Label).text).is_equal(tr("NONE"))


func test_the_mandates_next_move_shows_the_way_with_reads_the_room_and_the_time_with_the_timetable() -> void:
	var sheet := _sheet()
	var row: Control = sheet.get_node("%ForecastRow")
	var label: Label = sheet.get_node("%Forecast")
	SaveManager.save.mood_next = 0.1
	SaveManager.save.mood_clock = 18.0
	sheet.open()
	assert_bool(row.visible).override_failure_message("neither").is_false()

	for case: Array in [[[Slate.FORECAST], tr("UP")], [[Slate.FORECAST_TIME], tr("IN %s") % "0:42"],
			[[Slate.FORECAST, Slate.FORECAST_TIME], tr("UP IN %s") % "0:42"]]:
		SaveManager.save.tree_bought = PackedStringArray(case[0])
		sheet.open()
		assert_bool(row.visible).override_failure_message(str(case[0])).is_true()
		assert_str(label.text).is_equal(case[1])


func test_the_duty_box_is_as_wide_as_the_rows_below_it() -> void:
	var sheet := _sheet()
	sheet.open()
	await get_tree().process_frame
	var duty: Control = sheet.get_node("%Duty")
	assert_float(duty.size.x).override_failure_message("laid out").is_greater(400.0)
	for row: String in ["BounceRow", "FloorRow", "CeilingRow"]:
		var other: Control = sheet.get_node("Paper/Stack/" + row)
		assert_float(duty.global_position.x).override_failure_message(row + " left").is_equal(other.global_position.x)
		assert_float(duty.size.x).override_failure_message(row + " width").is_equal(other.size.x)


func test_the_duty_box_is_ticked_exactly_while_the_consultant_is_on() -> void:
	var sheet := _sheet()
	var duty: CheckBox = sheet.get_node("%Duty")
	SaveManager.save.consultant_on = false
	sheet.open()
	assert_bool(duty.button_pressed).override_failure_message("off").is_false()
	SaveManager.save.consultant_on = true
	sheet.open()
	assert_bool(duty.button_pressed).override_failure_message("on").is_true()

	duty.toggled.emit(false)
	assert_bool(SaveManager.save.consultant_on).override_failure_message("unticking sends it away").is_false()
