extends GdUnitTestSuite

const SCENE := preload("res://entities/telescope/telescope_view.tscn")


func _view() -> TelescopeView:
	var layer: CanvasLayer = auto_free(SCENE.instantiate())
	add_child(layer)
	return layer.get_node("View") as TelescopeView


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	return esc


func test_the_telescope_view_starts_closed() -> void:
	assert_bool(_view().visible).is_false()


func test_esc_leaves_the_telescope_view_before_the_pause_menu_can_take_it() -> void:
	var view := _view()
	view.open()
	view._input(_esc())
	await await_millis(int(TelescopeView.FADE_TIME * 1000) + 100)
	assert_bool(view.visible).is_false()


func test_the_to_desk_button_leaves_the_telescope_view() -> void:
	var view := _view()
	view.open()
	(view.get_node("%Back") as Button).pressed.emit()
	await await_millis(int(TelescopeView.FADE_TIME * 1000) + 100)
	assert_bool(view.visible).is_false()


func test_the_view_hides_the_desk_hand_while_open() -> void:
	assert_bool(_view().is_in_group(&"blocks_hand")).is_true()
