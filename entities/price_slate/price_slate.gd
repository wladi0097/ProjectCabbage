class_name PriceSlate
extends Node3D
## The chalked price per cabbage, with a chalk < and > beside it: click one to rewrite the price a
## coin down or up (held, it keeps stepping). The street's hidden demand falls with the price: at
## the full-sale price or below every cabbage sells, above it more and more are thrown back in
## through the window. The full-sale price is BASE_REF_PRICE times the save's marketing, times a
## mood that drifts each minute (MOOD_STEP at most) within MOOD_RANGE. A progression item: it drops onto the desk the first time the coins reach UNLOCK_COINS;
## until then cabbages sell at the save's starting price.

const UNLOCK_COINS := 32
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
const MIN_PRICE := 1
const MAX_PRICE := 20
const BASE_REF_PRICE := 3.0
const MOOD_RANGE := Vector2(0.75, 1.25)
const MOOD_STEP := 0.1
const MOOD_PERIOD := 60.0
## Sets how fast sales fall above the full-sale price: at 1.25, a price a third over it sells 70%.
const ELASTICITY := 1.25
## Held on an arrow: the first repeat comes after HOLD_DELAY, then one every HOLD_REPEAT.
const HOLD_DELAY := 0.4
const HOLD_REPEAT := 0.12
const CHALK := Color(0.9, 0.89, 0.84, 0.75)
const CHALK_LIT := Color(1.0, 1.0, 0.96, 1.0)
const HOVER_SCALE := 1.35
## A refused cabbage makes the price wiggle: this many radians at first, dying out over WIGGLE_TIME.
const WIGGLE := 0.18
const WIGGLE_TIME := 0.5
## The price flushes this red when it wiggles, fading back to chalk.
const REFUSED_RED := Color(0.95, 0.32, 0.26, 0.95)

var _step := 0
var _wait := 0.0
var _clock := 0.0

@onready var _price: Label3D = $Price
@onready var _rest := position
@onready var _price_basis := _price.basis
@onready var _price_colour := _price.modulate


func _ready() -> void:
	for arrow: Array in [[$Down, -1], [$Up, 1]]:
		var body: StaticBody3D = arrow[0]
		var label: Label3D = body.get_node("Label")
		var interactable: Interactable = body.get_node("Interactable")
		interactable.hovered.connect(_light.bind(label, true))
		interactable.unhovered.connect(_light.bind(label, false))
		interactable.grabbed.connect(_press.bind(arrow[1]))
		interactable.released.connect(func() -> void: _step = 0)
		label.modulate = CHALK
	_price.text = "$%d" % SaveManager.save.sale_price
	if not SaveManager.save.slate_unlocked:
		visible = false
		_set_arrows(false)
		position = _rest + Vector3.UP * 10.0


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.slate_unlocked and save.coins >= UNLOCK_COINS:
		save.slate_unlocked = true
		_drop()
	if save.slate_unlocked:
		_clock += delta
		if _clock >= MOOD_PERIOD:
			_clock -= MOOD_PERIOD
			save.demand_mood = next_mood(save.demand_mood, randf_range(-MOOD_STEP, MOOD_STEP))
	if _step == 0:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = HOLD_REPEAT
		_rewrite(_step)


func _light(label: Label3D, lit: bool) -> void:
	label.modulate = CHALK_LIT if lit else CHALK
	label.scale = Vector3.ONE * (HOVER_SCALE if lit else 1.0)


func _set_arrows(on: bool) -> void:
	$Down/Interactable.enabled = on
	$Up/Interactable.enabled = on


func _drop() -> void:
	visible = true
	position = _rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_set_arrows(true)
		$Dust.restart()
		$Thud.cue(global_position))
	tween.tween_property($Model, "scale", Vector3(1.08, 0.86, 1.08), 0.06)
	tween.tween_property($Model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _press(step: int) -> void:
	_step = step
	_wait = HOLD_DELAY
	_rewrite(step)


func _rewrite(step: int) -> void:
	var save := SaveManager.save
	var price := clampi(save.sale_price + step, MIN_PRICE, MAX_PRICE)
	if price == save.sale_price:
		return
	save.sale_price = price
	_price.text = "$%d" % price
	$Tap.cue(_price.global_position)


## The street threw a cabbage back: the price shakes a little and blushes red, as if it knows.
func wiggle() -> void:
	create_tween().tween_method(func(time: float) -> void:
		_price.basis = _price_basis * Basis(Vector3.BACK, wiggle_at(time))
		_price.modulate = REFUSED_RED.lerp(_price_colour, time / WIGGLE_TIME), 0.0, WIGGLE_TIME, WIGGLE_TIME)


## The wiggle's angle `time` seconds in: a fast shake dying out to rest by WIGGLE_TIME.
static func wiggle_at(time: float) -> float:
	return WIGGLE * exp(-6.0 * time) * sin(40.0 * time) if time < WIGGLE_TIME else 0.0


## The chance a cabbage flicked out at `price` is bought, when `ref` is the full-sale price.
static func demand(price: int, ref: float) -> float:
	return minf(1.0, pow(ref / price, ELASTICITY))


static func ref_price(marketing: float, mood: float) -> float:
	return BASE_REF_PRICE * marketing * mood


## Next minute's mood: a step from the last one, kept within MOOD_RANGE so it never runs away.
static func next_mood(mood: float, step: float) -> float:
	return clampf(mood + step, MOOD_RANGE.x, MOOD_RANGE.y)

