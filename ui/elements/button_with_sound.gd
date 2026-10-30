extends Button

signal clicked

@export var disabled_after_click := false

@onready var hover_audio: AudioStreamPlayer = $HoverAudio
@onready var click_audio: AudioStreamPlayer = $ClickAudio


func _on_mouse_entered() -> void:
	hover_audio.play()


func _on_button_down() -> void:
	disabled = true
	click_audio.play()
	clicked.emit()
	await click_audio.finished
	disabled = disabled_after_click
