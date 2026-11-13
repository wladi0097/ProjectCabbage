class_name PriceSlate
extends Node3D
## The chalked price per cabbage, with a chalk < and > beside it: click one to rewrite the price a
## coin down or up (held, it keeps stepping). The street's hidden demand falls with the price: at
## the full-sale price or below every cabbage sells, above it more and more are thrown back in
## through the window. The full-sale price is BASE_REF_PRICE times the save's marketing, times a
## mood that drifts each minute (MOOD_STEP at most) within MOOD_RANGE, and once the street turns
## volatile (save.street_volatile, after the promotion) jumps up to WILD_STEP within WILD_RANGE. The
## next move is rolled a minute ahead (save.mood_next, save.mood_clock): a chalk forecast under the
## price shows which way it goes (READS THE ROOM) and when it comes (STREET TIMETABLE). A progression item: it drops onto the desk once its upgrade card is stamped;
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
## The volatile street (GameEvents "street_volatility"): its step a minute and its range. Centred on 1
## so the average full-sale price stays as before; at its floor a price at the normal full-sale price
## still sells 36% (never a street that buys nothing).
const WILD_RANGE := Vector2(0.6, 1.4)
const WILD_STEP := 0.3
## The projector nodes that show the forecast: READS THE ROOM the way, STREET TIMETABLE the time.
## Each works alone; a lone half sits centred under the price.
const FORECAST := "consultant_mood"
const FORECAST_TIME := "consultant_clock"
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
## The slate's tip by the forecast halves bought, at 2 * way + time: none, time, way, both.
const FORECAST_TIPS := [BOARD_TIP,
	"Your price per cabbage. Click \"<\" or \">\" to change it by $1. Under it: when the street's mood next moves.",
	"Your price per cabbage. Click \"<\" or \">\" to change it by $1. Under it: which way the street's mood moves next.",
	"Your price per cabbage. Click \"<\" or \">\" to change it by $1. Under it: when the street's mood next moves, and which way."]
const GAUGE_TIP := "Acceptance meter: how likely the street buys a cabbage at your price right now. Left is never, right is always."
const GAUGE_BOX := AABB(Vector3(-0.068, -0.08, -0.056), Vector3(0.136, 0.148, 0.092))
## The pricing consultant's tap lights its arrow this long.
const NUDGE_LIGHT := 0.15
const Events := preload("res://globalScripts/game_events.gd")

## The player stepped the price, by a press or a held arrow's repeat (the pricing consultant backs off
## for a while).
signal player_rewrote

var _step := 0
var _wait := 0.0
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
@onready var _forecast: Node3D = $Forecast
@onready var _forecast_arrow: Label3D = $Forecast/Arrow
@onready var _forecast_time: Label3D = $Forecast/Time
@onready var _arrow_basis := _forecast_arrow.basis
@onready var _arrow_x := _forecast_arrow.position.x
@onready var _time_x := _forecast_time.position.x
@onready var _board: Interactable = $Board/Interactable


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
	Interactable.hover_box(_gauge, GAUGE_BOX, GAUGE_TIP)
	_gauge.visible = SaveManager.save.stamped.has("acceptance_meter")
	_needle = acceptance(SaveManager.save)
	_pose_needle()
	if is_zero_approx(SaveManager.save.mood_next):
		SaveManager.save.mood_next = roll_mood(SaveManager.save.street_volatile)
	_show_forecast(SaveManager.save)
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
		tick_mood(save, delta, roll_mood(save.street_volatile))
	if save.reports.has("promotion") and not save.street_volatile:
		save.volatile_wait += delta
		save.street_volatile = Events.volatile_due(save)
	_show_forecast(save)
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


## The mood's range: MOOD_RANGE, or WILD_RANGE once the street is `volatile`.
static func mood_range(volatile: bool) -> Vector2:
	return WILD_RANGE if volatile else MOOD_RANGE


## Next minute's mood: a step from the last one, kept within the range so it never runs away.
static func next_mood(mood: float, step: float, volatile := false) -> float:
	var range_ := mood_range(volatile)
	return clampf(mood + step, range_.x, range_.y)


## A random step for the next move: up to MOOD_STEP either way, WILD_STEP once `volatile`.
static func roll_mood(volatile: bool) -> float:
	var most := WILD_STEP if volatile else MOOD_STEP
	return randf_range(-most, most)


## Advances the save's mood clock by `delta`: each MOOD_PERIOD the mood takes the step rolled ahead
## (save.mood_next) and `rolled` becomes the next one. True when the mood moved.
static func tick_mood(save: SaveGame, delta: float, rolled: float) -> bool:
	save.mood_clock += delta
	if save.mood_clock < MOOD_PERIOD:
		return false
	save.mood_clock -= MOOD_PERIOD
	save.demand_mood = next_mood(save.demand_mood, save.mood_next, save.street_volatile)
	save.mood_next = rolled
	return true


## Which way the street's next move goes, as it will really land: 1 up, -1 down, 0 none (at its edge).
static func forecast(save: SaveGame) -> int:
	var change := next_mood(save.demand_mood, save.mood_next, save.street_volatile) - save.demand_mood
	return 0 if absf(change) < 0.005 else (1 if change > 0.0 else -1)


## Whole seconds until the street's next move.
static func forecast_seconds(save: SaveGame) -> int:
	return ceili(MOOD_PERIOD - save.mood_clock)


## "0:42" for 42 seconds.
static func clock(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]


## The chalk forecast under the price: with READS THE ROOM a chevron up or down (a dash when the
## street sits at its edge), with STREET TIMETABLE the time to the move. A lone half sits centred.
func _show_forecast(save: SaveGame) -> void:
	var way_on := save.tree_bought.has(FORECAST)
	var time_on := save.tree_bought.has(FORECAST_TIME)
	_forecast.visible = way_on or time_on
	_forecast_arrow.visible = way_on
	_forecast_time.visible = time_on
	_board.tooltip = FORECAST_TIPS[2 * int(way_on) + int(time_on)]
	_forecast_arrow.position.x = _arrow_x if time_on else 0.0
	_forecast_time.position.x = _time_x if way_on else 0.0
	if way_on:
		var way := forecast(save)
		_forecast_arrow.text = ">" if way != 0 else "-"
		_forecast_arrow.basis = _arrow_basis * Basis(Vector3.BACK, way * PI / 2.0)
	if time_on:
		_forecast_time.text = clock(forecast_seconds(save))
