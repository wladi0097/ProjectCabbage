class_name PriceSlate
extends Node3D
## The chalked price per cabbage, with a chalk < and > beside it: click one to rewrite the price a
## coin down or up (held, it keeps stepping). The street's hidden demand falls with the price: at
## the full-sale price or below every cabbage sells, above it more and more are thrown back in
## through the window. The full-sale price is BASE_REF_PRICE times the save's marketing, times a
## mood that drifts each minute (MOOD_STEP at most) within MOOD_RANGE. A progression item: it drops onto the desk once its upgrade card is stamped;
## until then cabbages sell at the save's starting price. With the acceptance meter card stamped, a
## gauge clamps onto the slate's corner and its needle shows the chance the street buys at the price.

const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
const MIN_PRICE := 1
## The highest price the slate takes is MAX_PRICE times the save's marketing (see max_price).
const MAX_PRICE := 12
const BASE_REF_PRICE := 3.0
const MOOD_RANGE := Vector2(0.75, 1.25)
const MOOD_STEP := 0.1
const MOOD_PERIOD := 60.0
## Sets how fast sales fall above the full-sale price: at 2, a price a third over it sells 56%.
const ELASTICITY := 2.0
## Held on an arrow: the first repeat comes after HOLD_DELAY, then one every HOLD_REPEAT.
const HOLD_DELAY := 0.4
const HOLD_REPEAT := 0.12
const CHALK := Color(0.9, 0.89, 0.84, 0.75)
const CHALK_LIT := Color(1.0, 1.0, 0.96, 1.0)
const HOVER_SCALE := 1.35
## A refused cabbage thrown back makes the price wiggle: this many radians at first, dying out over WIGGLE_TIME.
const WIGGLE := 0.18
const WIGGLE_TIME := 0.5
## The price flushes this red when it wiggles, fading back to chalk.
const REFUSED_RED := Color(0.95, 0.32, 0.26, 0.95)
## The gauge needle is a spring toward the acceptance (0..1): underdamped, so it swings past and
## settles. A refused cabbage knocks it down by NEEDLE_KICK per second; it never leaves NEEDLE_STOPS.
const NEEDLE_STIFF := 120.0
const NEEDLE_DAMP := 10.0
const NEEDLE_KICK := 1.5
const NEEDLE_STOPS := Vector2(-0.02, 1.02)
## Below this (speed and distance to the acceptance) the needle is at rest and isn't re-posed.
const NEEDLE_REST := 0.001
const GAUGE_DROP := 0.6
## What hovering the slate and the gauge explains; the gauge's dial (its own space) is hoverable.
const BOARD_TIP := "Your price per cabbage. Click \"<\" or \">\" to change it by $1. Higher pays more per sale, but the street refuses more cabbages."
const GAUGE_TIP := "Acceptance meter: how likely the street buys a cabbage at your price right now. Left is never, right is always."
const GAUGE_BOX := AABB(Vector3(-0.068, -0.08, -0.056), Vector3(0.136, 0.148, 0.092))
## The pricing consultant's tap lights its arrow this long.
const NUDGE_LIGHT := 0.15

## The player stepped the price, by a press or a held arrow's repeat (the pricing consultant backs off
## for a while and keeps the player's markup).
signal player_rewrote

var _step := 0
var _wait := 0.0
var _clock := 0.0
var _needle := 0.0
var _needle_speed := 0.0

@onready var _price: Label3D = $Price
@onready var _rest := position
@onready var _price_basis := _price.basis
@onready var _price_colour := _price.modulate
@onready var _gauge: Node3D = $Gauge
@onready var _gauge_rest := _gauge.position
@onready var _gauge_size := _gauge.scale
@onready var _skeleton: Skeleton3D = $Gauge/Armature/Skeleton3D
@onready var _needle_bone := _skeleton.find_bone("Needle")


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
	var board := Interactable.new()
	board.tooltip = BOARD_TIP
	$Board.add_child(board)
	Interactable.hover_box(_gauge, GAUGE_BOX, GAUGE_TIP)
	_gauge.visible = SaveManager.save.stamped.has("acceptance_meter")
	_needle = acceptance(SaveManager.save)
	_pose_needle()
	if not SaveManager.save.slate_unlocked:
		visible = false
		_set_arrows(false)
		position = _rest + Vector3.UP * 10.0


func _process(delta: float) -> void:
	var save := SaveManager.save
	if save.slate_unlocked and not visible:
		_drop()
	if not _gauge.visible and save.stamped.has("acceptance_meter"):
		_drop_gauge()
	var target := acceptance(save)
	if _gauge.visible and (absf(_needle_speed) > NEEDLE_REST or absf(target - _needle) > NEEDLE_REST):
		_needle_speed += (NEEDLE_STIFF * (target - _needle) - NEEDLE_DAMP * _needle_speed) * delta
		_needle += _needle_speed * delta
		if _needle < NEEDLE_STOPS.x or _needle > NEEDLE_STOPS.y:
			_needle = clampf(_needle, NEEDLE_STOPS.x, NEEDLE_STOPS.y)
			_needle_speed = 0.0
		_pose_needle()
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
		player_rewrote.emit()


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


## Bought with the acceptance meter card: the gauge drops onto the slate's corner and clamps on.
func _drop_gauge() -> void:
	_gauge.visible = true
	_gauge.position = _gauge_rest + Vector3.UP * GAUGE_DROP
	var tween := create_tween()
	tween.tween_property(_gauge, "position", _gauge_rest, DROP_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Thud.cue(_gauge.global_position))
	tween.tween_property(_gauge, "scale", _gauge_size * Vector3(1.1, 0.85, 1.0), 0.05)
	tween.tween_property(_gauge, "scale", _gauge_size, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The chance the street buys at the save's price right now: what the gauge shows and the window uses.
static func acceptance(save: SaveGame) -> float:
	return demand(save.sale_price, ref_price(save.marketing, save.demand_mood))


func _pose_needle() -> void:
	_skeleton.set_bone_pose_rotation(_needle_bone, Quaternion(Vector3.BACK, needle_angle(_needle))
			* _skeleton.get_bone_rest(_needle_bone).basis.get_rotation_quaternion())


## The needle's turn about the face normal for acceptance `p`: 0 points lower left, 1 lower right.
static func needle_angle(p: float) -> float:
	return deg_to_rad(120.0 - 240.0 * p)


func _press(step: int) -> void:
	_step = step
	_wait = HOLD_DELAY
	_rewrite(step)
	player_rewrote.emit()


## The pricing consultant taps arrow `step` (-1 down, 1 up): it lights briefly and the price moves.
func nudge(step: int) -> void:
	var label: Label3D = ($Down if step < 0 else $Up).get_node("Label")
	_light(label, true)
	get_tree().create_timer(NUDGE_LIGHT).timeout.connect(_light.bind(label, false))
	_rewrite(step)


## Where arrow `step` sits (world), for the consultant's finger.
func arrow_at(step: int) -> Vector3:
	return ($Down if step < 0 else $Up).global_position


func _rewrite(step: int) -> void:
	var save := SaveManager.save
	var price := clampi(save.sale_price + step, MIN_PRICE, max_price(save.marketing))
	if price == save.sale_price:
		return
	save.sale_price = price
	_price.text = "$%d" % price
	$Tap.cue(_price.global_position)


## The street threw a refused cabbage back onto the desk: the price shakes a little and blushes red, as if it knows, and
## the gauge needle twitches down.
func wiggle() -> void:
	_needle_speed -= NEEDLE_KICK
	create_tween().tween_method(func(time: float) -> void:
		_price.basis = _price_basis * Basis(Vector3.BACK, wiggle_at(time))
		_price.modulate = REFUSED_RED.lerp(_price_colour, time / WIGGLE_TIME), 0.0, WIGGLE_TIME, WIGGLE_TIME)


## The wiggle's angle `time` seconds in: a fast shake dying out to rest by WIGGLE_TIME.
static func wiggle_at(time: float) -> float:
	return WIGGLE * exp(-6.0 * time) * sin(40.0 * time) if time < WIGGLE_TIME else 0.0


## The chance a cabbage flicked out at `price` is bought, when `ref` is the full-sale price.
static func demand(price: int, ref: float) -> float:
	return minf(1.0, pow(ref / price, ELASTICITY))


## The slate's top price: it grows with marketing, so the best price never hits the ceiling.
static func max_price(marketing: float) -> int:
	return roundi(MAX_PRICE * marketing)


static func ref_price(marketing: float, mood: float) -> float:
	return BASE_REF_PRICE * marketing * mood


## Next minute's mood: a step from the last one, kept within MOOD_RANGE so it never runs away.
static func next_mood(mood: float, step: float) -> float:
	return clampf(mood + step, MOOD_RANGE.x, MOOD_RANGE.y)
