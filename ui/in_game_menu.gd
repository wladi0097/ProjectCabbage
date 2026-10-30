extends Control

@onready var quit_confirm: Control = %QuitConfirm
@onready var page: Control = $Page
@onready var settings_ui: Control = $SettingsUi


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			show()
	else:
		return
	get_viewport().set_input_as_handled()


func close() -> void:
	settings_ui.go_back()
	quit_confirm.hide()
	hide()


func _toggle_fullscreen() -> void:
	var settings := SaveManager.settings
	settings.screen_mode = SettingsResource.toggled_screen_mode(settings.screen_mode)
	SaveManager.write_settings()


func _on_continue_clicked() -> void:
	close()


func _on_settings_clicked() -> void:
	page.hide()
	settings_ui.enable()


func _on_quit_confirmed() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
