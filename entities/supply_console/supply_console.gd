class_name SupplyConsole
extends Node3D
## The supply chain's console: an amber ticker with the current pack price and the buy-pack button
## (a crate icon, no text). Pressing it pays the price from the tally and adds pack_size to the stock.
## Every minute the price moves: around the base, ±50%, pushed up by the packs bought in the
## minute before, plus noise. It drops onto the desk once the first UNLOCK_SALES are sold.
## Sold out and unable to pay for a pack for BAILOUT_WAIT seconds, the price drops to the coins
## left (a bailout) until the next pack is bought or the minute turns.

const UNLOCK_SALES := 10
const BASE_PRICE_PER_CABBAGE := 0.6
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

## Coins still on the mat or in the air count as money when deciding on a bailout.
@export var coins: CoinPile

var _clock := 0.0
var _broke_for := 0.0
## The bailout price while one is on offer, else -1.
var _bailout := -1
var _blinking: Tween

@onready var _button: Interactable = $Button/Interactable
@onready var _price: Label3D = $Price
@onready var _spark: MeshInstance3D = $Sparkline
@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _plunger := _skeleton.find_bone("Plunger")
@onready var _rest := position


func _ready() -> void:
	_button.grabbed.connect(_press)
	_button.grabbed.connect(_push.bind(true))
	_button.released.connect(_push.bind(false))
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
	_broke_for = _broke_for + delta if save.buy_unlocked and _bailout < 0 and is_broke(save.stock, save.coins + (coins.pending_value() if coins != null else 0), _cost()) else 0.0
	if _broke_for >= BAILOUT_WAIT:
		_bailout = save.coins
		_show_price()


func _cost() -> int:
	var save := SaveManager.save
	return _bailout if _bailout >= 0 else pack_price(save.price_factor, save.pack_size)


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
	_price.text = "$%d" % _cost()
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


static func pack_price(factor: float, size: int) -> int:
	return maxi(roundi(factor * BASE_PRICE_PER_CABBAGE * size), 1)


## Points of the price history in a `size` box (factor 0.5 at the bottom, 1.5 at the top),
## the newest at the right edge of `slots` slots.
static func sparkline(history: PackedFloat32Array, slots: int, size: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var first := slots - history.size()
	for i in history.size():
		out.append(Vector2(size.x * (first + i) / float(slots - 1), size.y * (history[i] - 0.5)))
	return out
