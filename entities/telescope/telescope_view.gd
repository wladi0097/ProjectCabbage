class_name TelescopeView
extends Control
## What the telescope shows (Telescope, clicked): for now an empty eyepiece over a dark night sky,
## a survey reticle in it (the eyepiece shader in telescope_view.tscn). Its own scene so chapter 4's
## telescope play can be built into it later. TO DESK or Esc leaves; the game keeps running behind it.

const FADE_TIME := 0.35

var _fade: Tween

@onready var _back: Button = %Back


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_back.pressed.connect(close)


func open() -> void:
	if visible:
		return
	visible = true
	_fade_to(1.0)


func close() -> void:
	if not visible:
		return
	_fade_to(0.0).tween_callback(hide)
	visible = modulate.a > 0.0  # Shut at once if it never faded in (a test, a frame-zero close).


func _fade_to(alpha: float) -> Tween:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_TIME * absf(alpha - modulate.a))
	return _fade


## Esc leaves, in _input so it gets Esc before the in-game menu (unhandled) opens.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
