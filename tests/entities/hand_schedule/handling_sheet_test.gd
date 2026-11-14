extends GdUnitTestSuite

const SHEET := preload("res://entities/hand_schedule/handling_sheet.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()
	SaveManager.save.stamped.append(HandSchedule.CARD)


func after_test() -> void:
	SaveManager.save = _real_save


## The paper on its own, closed.
func _sheet() -> HandlingSheet:
	var layer: CanvasLayer = auto_free(SHEET.instantiate())
	add_child(layer)
	var sheet: HandlingSheet = layer.get_node("Sheet")
	sheet.set_process(false)
	return sheet


func _cell(sheet: HandlingSheet, half: String, kind: String) -> ScheduleCell:
	return sheet.get_node("Paper/Stack/Halves/%s/Row/%s" % [half, kind.capitalize()])


func test_the_paper_has_a_lab_hands_half_on_the_left_and_a_hired_hands_half_on_the_right_with_a_picture_per_kind() -> void:
	var sheet := _sheet()
	sheet.open()
	await get_tree().process_frame
	var lab: Control = sheet.get_node("Paper/Stack/Halves/Lab")
	var hired: Control = sheet.get_node("Paper/Stack/Halves/Hired")
	assert_float(lab.global_position.x).is_less(hired.global_position.x)
	for half: String in ["Lab", "Hired"]:
		var kinds := sheet.get_node("Paper/Stack/Halves/%s/Row" % half).get_children().map(func(cell: ScheduleCell) -> String: return cell.kind)
		assert_array(kinds).override_failure_message(half).contains_exactly(HandSchedule.KINDS)
		for kind: String in HandSchedule.KINDS:
			assert_bool(_cell(sheet, half, kind).research).override_failure_message(half + " " + kind).is_equal(half == "Lab")


func test_a_click_on_a_picture_stamps_it_not_to_be_handled_and_a_second_click_clears_it() -> void:
	var sheet := _sheet()
	sheet.open()
	var cell := _cell(sheet, "Hired", "regular")
	var stamp: Control = cell.get_node("Stamp")
	assert_bool(stamp.visible).is_false()

	cell.pressed.emit()
	assert_bool(stamp.visible).override_failure_message("struck").is_true()
	assert_array(SaveManager.save.hands_forbidden).contains_exactly(["regular"])
	assert_bool((_cell(sheet, "Lab", "regular").get_node("Stamp") as Control).visible).override_failure_message("the other half").is_false()

	cell.pressed.emit()
	assert_bool(stamp.visible).override_failure_message("cleared").is_false()
	assert_array(SaveManager.save.hands_forbidden).is_empty()


func test_a_kind_not_listed_yet_is_padlocked_and_takes_no_click_until_its_node_is_bought() -> void:
	var sheet := _sheet()
	sheet.open()
	var cell := _cell(sheet, "Lab", "research")
	assert_bool(cell.disabled).is_true()
	assert_bool((cell.get_node("Lock") as Control).visible).is_true()
	assert_bool(_cell(sheet, "Lab", "regular").disabled).override_failure_message("plain comes with the card").is_false()

	SaveManager.save.tree_bought.append(HandSchedule.NODES.research)
	sheet.open()
	assert_bool(cell.disabled).is_false()
	assert_bool((cell.get_node("Lock") as Control).visible).is_false()


func test_the_paper_closes_on_x_esc_or_a_click_outside() -> void:
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


func test_the_paper_fits_a_1920_by_1080_screen_in_english_and_german() -> void:
	var sheet := _sheet()
	var was := TranslationServer.get_locale()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		sheet.open()
		await get_tree().process_frame
		await get_tree().process_frame
		var paper: Control = sheet.get_node("Paper")
		assert_float(paper.size.x).override_failure_message(locale + " width").is_less(1500.0)
		assert_float(paper.size.y).override_failure_message(locale + " height").is_less(700.0)
	TranslationServer.set_locale(was)
