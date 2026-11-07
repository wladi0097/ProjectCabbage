extends GdUnitTestSuite

const SCENE := preload("res://ui/elements/confirm_panel.tscn")

var _panel: Control
var _heard: Array[String] = []


func before_test() -> void:
	_heard.clear()
	_panel = auto_free(SCENE.instantiate())
	add_child(_panel)
	_panel.confirmed.connect(func() -> void: _heard.append("confirmed"))
	_panel.cancelled.connect(func() -> void: _heard.append("cancelled"))


func cancel_key() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_the_confirm_button_confirms() -> void:
	_panel.get_node("%Confirm").clicked.emit()
	assert_array(_heard).is_equal(["confirmed"])


func test_the_cancel_button_cancels() -> void:
	_panel.get_node("%Cancel").clicked.emit()
	assert_array(_heard).is_equal(["cancelled"])


func test_escape_cancels_an_open_panel() -> void:
	_panel._unhandled_input(cancel_key())
	assert_array(_heard).is_equal(["cancelled"])


func test_escape_does_nothing_while_the_panel_is_hidden() -> void:
	_panel.hide()
	_panel._unhandled_input(cancel_key())
	assert_array(_heard).is_empty()
