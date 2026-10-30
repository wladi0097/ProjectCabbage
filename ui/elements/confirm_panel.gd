extends PanelContainer

signal confirmed
signal cancelled

@export var message := ""
@export var confirm_text := ""

func _ready() -> void:
	%Message.text = message
	%Confirm.text = confirm_text

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() && event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()

func _on_confirm_clicked() -> void:
	confirmed.emit()

func _on_cancel_clicked() -> void:
	cancelled.emit()
