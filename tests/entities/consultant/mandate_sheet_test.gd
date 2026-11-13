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


func test_the_mandate_shows_the_forecast_only_once_reads_the_room_is_bought() -> void:
	var sheet := _sheet()
	var row: Control = sheet.get_node("%ForecastRow")
	sheet.open()
	assert_bool(row.visible).is_false()

	SaveManager.save.tree_bought.append(Slate.FORECAST)
	SaveManager.save.mood_next = 0.1
	SaveManager.save.mood_clock = 18.0
	sheet.open()
	assert_bool(row.visible).is_true()
	assert_str((sheet.get_node("%Forecast") as Label).text).is_equal(tr("UP IN %s") % "0:42")
