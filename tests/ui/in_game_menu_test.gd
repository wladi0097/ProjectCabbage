extends GdUnitTestSuite

const SCENE := preload("res://ui/in_game_menu.tscn")


# Pushed through the viewport like a real key press. gdUnit's scene_runner also
# calls the root's _unhandled_input directly, which skips "input handled".
func escape_from(open_page: StringName) -> Control:
	var menu: Control = auto_free(SCENE.instantiate())
	add_child(menu)
	menu.show()
	menu.call(open_page)
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	get_tree().root.push_input(event)
	return menu


func test_escape_on_the_settings_returns_to_the_menu_instead_of_closing_it() -> void:
	var menu := escape_from(&"_on_settings_clicked")
	assert_bool(menu.settings_ui.visible).is_false()
	assert_bool(menu.page.visible).is_true()
	assert_bool(menu.visible).is_true()


func test_escape_on_the_credits_returns_to_the_menu_instead_of_closing_it() -> void:
	var menu := escape_from(&"_on_credits_clicked")
	assert_bool(menu.credits_ui.visible).is_false()
	assert_bool(menu.page.visible).is_true()
	assert_bool(menu.visible).is_true()
