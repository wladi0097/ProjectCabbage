class_name MandateSheet
extends Control
## The pricing consultant's mandate: a form that opens when its switch by the slate is clicked. The
## player sets the consultant on or off duty, the share of cabbages the street may refuse
## (save.consultant_bounce) and its lowest and highest price, and reads the price and the refusals
## right now. With READS THE ROOM bought it also shows when the street next moves and which way.
## Mouse only; X, Esc or a click beside the paper closes it. The game keeps running behind it.

const Slate := preload("res://entities/price_slate/price_slate.gd")
## The forecast line for a move up, down or none (PriceSlate.forecast), with the time.
const WAYS := {1: "UP IN %s", -1: "DOWN IN %s", 0: "NO MOVE IN %s"}

@onready var _duty: Button = %Duty


func _ready() -> void:
	visible = false
	%Close.pressed.connect(close)
	_duty.toggled.connect(func(on: bool) -> void: SaveManager.save.consultant_on = on)
	%BounceDown.pressed.connect(_step.bind(&"consultant_bounce", -1))
	%BounceUp.pressed.connect(_step.bind(&"consultant_bounce", 1))
	%FloorDown.pressed.connect(_step.bind(&"consultant_floor", -1))
	%FloorUp.pressed.connect(_step.bind(&"consultant_floor", 1))
	%CeilingDown.pressed.connect(_step.bind(&"consultant_ceiling", -1))
	%CeilingUp.pressed.connect(_step.bind(&"consultant_ceiling", 1))
	$Shade.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			close())


func open() -> void:
	visible = true
	_show(SaveManager.save)


func close() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_show(SaveManager.save)


## Esc closes it, in _input so it gets Esc before the in-game menu (unhandled) opens.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## A stepper click `dir` on the mandate's `field`.
func _step(field: StringName, dir: int) -> void:
	var save := SaveManager.save
	match field:
		&"consultant_bounce":
			save.consultant_bounce = Consultant.step_bounce(save.consultant_bounce, dir)
		&"consultant_floor":
			save.consultant_floor = Consultant.step_floor(save, dir)
		&"consultant_ceiling":
			save.consultant_ceiling = Consultant.step_ceiling(save, dir)
	_show(save)


func _show(save: SaveGame) -> void:
	_duty.set_pressed_no_signal(save.consultant_on)
	_duty.text = tr("ON DUTY") if save.consultant_on else tr("OFF DUTY")
	%Bounce.text = "%d%%" % save.consultant_bounce
	%Floor.text = "$%d" % save.consultant_floor
	%Ceiling.text = tr("NONE") if save.consultant_ceiling <= 0 else "$%d" % save.consultant_ceiling
	%Price.text = "$%d" % save.sale_price
	%Refused.text = "%d%%" % roundi(100.0 * (1.0 - Slate.acceptance(save)))
	%ForecastRow.visible = save.tree_bought.has(Slate.FORECAST)
	%Forecast.text = tr(WAYS[Slate.forecast(save)]) % Slate.clock(Slate.forecast_seconds(save))
