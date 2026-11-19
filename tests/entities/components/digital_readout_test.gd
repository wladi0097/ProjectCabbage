extends GdUnitTestSuite

const SCENE := "res://entities/components/digital_readout.tscn"
const CABBAGE := Color(0.48, 0.75, 0.26)

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


func _readout() -> DigitalReadout:
	var readout: DigitalReadout = auto_free((load(SCENE) as PackedScene).instantiate())
	readout.mark = "$"
	add_child(readout)
	return readout


func _stamp() -> void:
	SaveManager.save.stamped.append(DigitalReadout.CARD)


func test_the_readout_stays_dark_until_print_larger_numbers_is_stamped() -> void:
	var readout := _readout()
	readout.show_value(1234)
	assert_bool(readout.visible).is_false()
	_stamp()
	readout.show_value(1234)
	assert_bool(readout.visible).is_true()


func test_a_loaded_save_with_the_card_shows_the_readout_at_once() -> void:
	_stamp()
	assert_bool(_readout().visible).is_true()


func test_the_readout_prints_the_value_as_num_text_after_its_sign() -> void:
	_stamp()
	var readout := _readout()
	readout.show_value(1234567)
	assert_str((readout.get_node("Ink") as Label3D).text).is_equal("$" + Num.text(1234567)).is_equal("$1.2M")


func test_the_readout_keeps_counting_past_999_999_999() -> void:
	_stamp()
	var readout := _readout()
	readout.show_value(4500000000)
	assert_str((readout.get_node("Ink") as Label3D).text).is_equal("$4.5B")
	readout.show_value(12000000000000)
	assert_str((readout.get_node("Ink") as Label3D).text).is_equal("$12T")


func test_stamped_live_the_figures_flicker_on_in_about_half_a_second() -> void:
	var total := 0.0
	for span in DigitalReadout.FLICKER:
		total += span
	assert_float(total).is_between(0.4, 0.6)
	var readout := _readout()
	_stamp()
	readout.show_value(5)
	var ink := readout.get_node("Ink") as Label3D
	await get_tree().process_frame
	assert_bool(ink.visible).is_false()
	await await_millis(700)
	assert_bool(ink.visible).is_true()


func test_the_readout_green_is_pale_and_never_as_saturated_as_the_cabbage() -> void:
	assert_float(DigitalReadout.INK.s).is_less(CABBAGE.s * 0.6)
	assert_float(DigitalReadout.INK.v).is_greater(0.8)
	assert_bool((auto_free(load(SCENE).instantiate()).get_node("Ink") as Label3D).modulate.is_equal_approx(DigitalReadout.INK)).is_true()
