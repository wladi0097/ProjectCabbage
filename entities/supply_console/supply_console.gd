class_name SupplyConsole
extends Node3D
## The supply chain's console: an amber ticker with the current pack price and the buy-pack button
## (a crate icon, no text). Pressing it pays the price from the tally and adds pack_size to the stock.
## A pack's cabbage costs PACK_SHARE of the full-sale price (PriceSlate.BASE_REF_PRICE × marketing),
## so packs stay a steady share of what a sale brings as marketing grows.
## Every minute the price moves: around the base, ±50%, pushed up by the packs bought in the
## minute before, plus noise. It drops onto the desk once the first UNLOCK_SALES are sold.
## Sold out and unable to pay for a pack for BAILOUT_WAIT seconds, the price drops to the coins
## left (a bailout) until the next pack is bought or the minute turns.
## Once the auto_procurement card is stamped an AUTO lamp lights on the screen: pressed, it switches
## automatic buying on or off (save.auto_buy). On, a pack is bought whenever should_auto_buy says so.

const Slate := preload("res://entities/price_slate/price_slate.gd")

const UNLOCK_SALES := 10
const PACK_SHARE := 0.35
const PRICE_PERIOD := 60.0
const PRESSURE_PER_PACK := 0.12
## Share of the pressure left after each price change.
const PRESSURE_KEEP := 0.5
const NOISE := 0.25
const HISTORY := 12
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
## How far the button sinks along the slope normal (Godot space) when pressed.
const PRESS_DEPTH := Vector3(0, -0.0115, -0.0034)
const BAILOUT_WAIT := 10.0
const AMBER := Color(1, 0.62, 0.18, 1)
const DENIED_RED := Color(1, 0.12, 0.08, 1)
const BLINK_TIME := 0.12
## Seconds between two automatic buys, and the AUTO lamp's colour when switched off.
const AUTO_COOLDOWN := 1.0
const AUTO_OFF := Color(0.3, 0.27, 0.22, 1)

## Coins still on the mat or in the air count as money when deciding on a bailout.
@export var coins: CoinPile

var _clock := 0.0
var _broke_for := 0.0
## The bailout price while one is on offer, else -1.
var _bailout := -1
var _blinking: Tween
var _auto_wait := 0.0
## The cost the ticker shows, so it is only reformatted when it changes.
var _shown_cost := -1

@onready var _button: Interactable = $Button/Interactable
@onready var _auto: Label3D = $Auto
@onready var _auto_switch: Interactable = $AutoSwitch/Interactable
@onready var _price: Label3D = $Price
@onready var _spark: MeshInstance3D = $Sparkline
@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _plunger := _skeleton.find_bone("Plunger")
@onready var _rest := position


func _ready() -> void:
	_button.grabbed.connect(_press)
	_button.grabbed.connect(_push.bind(true))
	_button.released.connect(_push.bind(false))
	_auto_switch.grabbed.connect(_toggle_auto)
	_show_auto()
	var save := SaveManager.save
	if save.price_history.size() < 2:
		var steps := PackedFloat32Array()
		for i in HISTORY - 1:
			steps.append(randf_range(-NOISE, NOISE))
		save.price_history = walk_back(save.price_factor, steps)
	_show_price()
	if not save.buy_unlocked:
		visible = false
		_button.enabled = false
		position = _rest + Vector3.UP * 10.0


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.buy_unlocked and save.sold >= UNLOCK_SALES:
		save.buy_unlocked = true
		_drop()
	_clock += delta
	if _clock >= PRICE_PERIOD:
		_clock -= PRICE_PERIOD
		_tick_price()
	# Only out of stock is the mat's coin pile worth counting.
	_broke_for = _broke_for + delta if save.buy_unlocked and _bailout < 0 and save.stock <= 0 and is_broke(save.stock, save.coins + (coins.pending_value() if coins != null else 0), _cost()) else 0.0
	if _broke_for >= BAILOUT_WAIT:
		_bailout = save.coins
		_show_price()
	if _auto.visible != save.stamped.has("auto_procurement"):
		_show_auto()
	_auto_wait -= delta
	if _auto.visible and save.auto_buy and save.buy_unlocked and _auto_wait <= 0.0 \
			and should_auto_buy(save.stock, save.auto_reserve, save.price_factor, save.auto_max_factor, save.coins, _cost()):
		_auto_wait = AUTO_COOLDOWN
		_press()
		_push(true)
		get_tree().create_timer(0.12).timeout.connect(_push.bind(false))
	# Marketing and pack size change between ticks; the ticker follows at once.
	if _cost() != _shown_cost:
		_shown_cost = _cost()
		_price.text = "$%d" % _shown_cost


func _cost() -> int:
	var save := SaveManager.save
	return _bailout if _bailout >= 0 else pack_price(save.price_factor, save.pack_size, save.marketing, save.pack_discount)


func _tick_price() -> void:
	var save := SaveManager.save
	_bailout = -1
	save.price_factor = next_factor(save.price_pressure, randf_range(-NOISE, NOISE))
	save.price_pressure *= PRESSURE_KEEP
	save.price_history.append(save.price_factor)
	if save.price_history.size() > HISTORY:
		save.price_history = save.price_history.slice(-HISTORY)
	_show_price()


func _press() -> void:
	var save := SaveManager.save
	var cost := _cost()
	if save.coins < cost:
		$Denied.cue($Button.global_position)
		_blink()
		return
	save.coins -= cost
	if _bailout >= 0:
		_bailout = -1
		_show_price()
	save.stock += save.pack_size
	save.price_pressure += PRESSURE_PER_PACK
	$Press.cue($Button.global_position)


## Not enough coins: the price flashes red twice.
func _blink() -> void:
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	for i in 2:
		_blinking.tween_callback(func() -> void: _price.modulate = DENIED_RED)
		_blinking.tween_interval(BLINK_TIME)
		_blinking.tween_callback(func() -> void: _price.modulate = AMBER)
		_blinking.tween_interval(BLINK_TIME)


## The AUTO lamp: there once the card is stamped, amber while on, dark while off.
func _show_auto() -> void:
	var save := SaveManager.save
	_auto.visible = save.stamped.has("auto_procurement")
	_auto_switch.enabled = _auto.visible
	_auto.modulate = AMBER if save.auto_buy else AUTO_OFF


func _toggle_auto() -> void:
	SaveManager.save.auto_buy = not SaveManager.save.auto_buy
	$Press.cue($AutoSwitch.global_position)
	_show_auto()


func _push(down: bool) -> void:
	var rest := _skeleton.get_bone_rest(_plunger).origin
	create_tween().tween_method(func(at: Vector3) -> void: _skeleton.set_bone_pose_position(_plunger, at),
			_skeleton.get_bone_pose_position(_plunger), rest + (PRESS_DEPTH if down else Vector3.ZERO), 0.05)


func _drop() -> void:
	visible = true
	position = _rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_button.enabled = true
		$Dust.restart()
		$Thud.cue(global_position))
	tween.tween_property($Model, "scale", Vector3(1.08, 0.86, 1.08), 0.06)
	tween.tween_property($Model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_price() -> void:
	var save := SaveManager.save
	_shown_cost = _cost()
	_price.text = "$%d" % _shown_cost
	var mesh := ImmediateMesh.new()
	var points := sparkline(save.price_history, HISTORY, Vector2(0.14, 0.03))
	if points.size() >= 2:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in points:
			mesh.surface_add_vertex(Vector3(p.x, p.y, 0.0))
		mesh.surface_end()
	_spark.mesh = mesh


## A made-up price history that ends at `last`: each earlier minute is the later one minus a
## step, kept to the same ±50% band. So the ticker has a line from the moment it arrives.
static func walk_back(last: float, steps: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([last])
	for step in steps:
		out.insert(0, clampf(out[0] - step, 0.5, 1.5))
	return out


## The next minute's price factor: base 1, pushed up by recent buys, plus noise, kept to ±50%.
static func next_factor(pressure: float, noise: float) -> float:
	return clampf(1.0 + pressure + noise, 0.5, 1.5)


## No cabbages left to sell and not enough coins for the next pack: stuck without a bailout.
static func is_broke(stock: int, money: int, cost: int) -> bool:
	return stock <= 0 and money < cost


static func pack_price(factor: float, size: int, marketing: float, discount := 1.0) -> int:
	return maxi(roundi(factor * PACK_SHARE * Slate.BASE_REF_PRICE * marketing * size * discount), 1)


## Automatic buying: stock is down to the reserve and the tally can pay; while stock is left it
## also waits for the price factor to come down to `max_factor`.
static func should_auto_buy(stock: int, reserve: int, factor: float, max_factor: float, money: int, cost: int) -> bool:
	return stock <= reserve and money >= cost and (stock <= 0 or factor <= max_factor + 0.001)


## Points of the price history in a `size` box (factor 0.5 at the bottom, 1.5 at the top),
## the newest at the right edge of `slots` slots.
static func sparkline(history: PackedFloat32Array, slots: int, size: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var first := slots - history.size()
	for i in history.size():
		out.append(Vector2(size.x * (first + i) / float(slots - 1), size.y * (history[i] - 0.5)))
	return out
