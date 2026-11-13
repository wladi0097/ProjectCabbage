class_name SupplyConsole
extends Node3D
## The supply chain's console: an amber ticker with the current pack price and the buy-pack button
## (a "$" and a green cabbage, no text). Pressing it pays the price from the tally and adds pack_size to the stock.
## A pack that would not fit under save.storage_cap is refused: the ticker reads FULL meanwhile.
## A pack's cabbage costs UNIT_COST times the price factor. Marketing does not touch it: it only
## raises what a sale brings, so every marketing upgrade is pure margin (see pack_price).
## Every minute the price moves: around the base, ±50%, pushed up by the packs bought in the
## minute before, plus noise. It drops onto the desk once the first UNLOCK_SALES are sold.
## Sold out and unable to pay for a pack for BAILOUT_WAIT seconds, the price drops to the coins
## left (a bailout) until the next pack is bought or the minute turns. Only before the minis: once
## mini_cabbages is stamped the free minis are the way out (bails_out).
## Once the auto_procurement card is stamped an AUTO lamp lights on the screen with a light switch
## beside it: a click on the lamp or the switch (one hit box, AutoSwitch, over both: the switch's own
## is off) switches automatic buying on or off (save.auto_buy). On, a pack is bought whenever should_auto_buy says so.
## Stage 2 (GameEvents "supply_shock"): a pack unit costs at least crate_share of the street's
## full-sale price (crate_floor), whatever the ticker or the pack discount. The standing order then skips packs that would sell at a loss, and
## while the family farm has seeds or crops the bailout is off (the farm on the TV feeds the desk).
## Once the farm is in too, the squeeze: crates cost more than a sale brings, for good, and no bailout.

const Slate := preload("res://entities/price_slate/price_slate.gd")

const UNLOCK_SALES := 10
## A pack cabbage at price factor 1: 35% of the textbook $3 sale, before any marketing.
const UNIT_COST := 1.05
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
## A short beat, so the price drop reads as the desk answering, not a glitch. Checked every frame.
const BAILOUT_WAIT := 1.2
const AMBER := Color(1, 0.62, 0.18, 1)
const DENIED_RED := Color(1, 0.12, 0.08, 1)
const BLINK_TIME := 0.12
## Seconds between two automatic buys, and the AUTO lamp's colour when switched off.
const AUTO_COOLDOWN := 1.0
const AUTO_OFF := Color(0.3, 0.27, 0.22, 1)
## Stage 2 crate prices as a share of the full-sale price (crate_share): after the shock; and for
## good once the wholesalers' squeeze is on (squeezing: the shock and the farm both in), so crates
## never pay again and the farm is the supply.
const SHOCK_SHARE := 0.6
const SQUEEZE_SHARE := 1.25
## Overstock: from OVERSTOCK units in stock on, a pack costs OVERSTOCK_MUL times as much, at once
## (the ticker jumps), so hoarding packs never pays. The farm's harvests are not charged.
const OVERSTOCK := 130
const OVERSTOCK_MUL := 5

## Coins still on the mat or in the air count as money when deciding on a bailout.
@export var coins: CoinPile

var _clock := 0.0
var _broke_for := 0.0
## The bailout price while one is on offer, else -1.
var _bailout := -1
var _blinking: Tween
var _auto_wait := 0.0
## The auto_buy the lamp and switch show.
var _auto_on := true

@onready var _button: Interactable = $Button/Interactable
@onready var _auto: Label3D = $Auto
@onready var _auto_switch: Interactable = $AutoSwitch/Interactable
@onready var _toggle: LightSwitch = $Auto/Toggle
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
	_show_auto(false)
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
	_broke_for = _broke_for + delta if save.buy_unlocked and _bailout < 0 and save.stock <= 0 and bails_out(save) and is_broke(save.stock, save.coins + (coins.pending_value() if coins != null else 0), _cost()) else 0.0
	if _broke_for >= BAILOUT_WAIT:
		_bailout = save.coins
		_show_price()
	# The shock switches the standing order off from the desk (UpgradeDesk.start_shock): the switch follows.
	if _auto.visible != save.stamped.has("auto_procurement") or _auto_on != save.auto_buy:
		_show_auto()
	_auto_wait -= delta
	if _auto.visible and save.auto_buy and save.buy_unlocked and _auto_wait <= 0.0 \
			and fits(save.stock, save.pack_size, save.storage_cap) \
			and should_auto_buy(save.stock, save.auto_reserve, save.price_factor, save.auto_max_factor, save.coins, _cost()) \
			and not (save.supply_shock and _cost() / float(save.pack_size) >= save.sale_price):
		_auto_wait = AUTO_COOLDOWN
		_press(true)
		_push(true)
		get_tree().create_timer(0.12).timeout.connect(_push.bind(false))
	# Pack size and discount change between ticks; the ticker follows at once.
	if _price.text != _price_text():
		_price.text = _price_text()


## The ticker: the pack price, or FULL while a pack would not fit in storage.
func _price_text() -> String:
	var save := SaveManager.save
	return "$%d" % _cost() if fits(save.stock, save.pack_size, save.storage_cap) else tr("FULL")


## Whether a pack of `pack` units fits on top of `stock` under the storage cap `cap`.
static func fits(stock: int, pack: int, cap: int) -> bool:
	return stock + pack <= cap


func _cost() -> int:
	var save := SaveManager.save
	return _bailout if _bailout >= 0 else pack_cost(save)


## What the next pack costs now, without a bailout: the ticker's price, overstock included.
static func pack_cost(save: SaveGame) -> int:
	return overstock_price(pack_price(save.price_factor, save.pack_size, save.pack_discount, UNIT_COST, crate_floor(save)), save.stock)


func _tick_price() -> void:
	var save := SaveManager.save
	_bailout = -1
	save.price_factor = next_factor(save.price_pressure, randf_range(-NOISE, NOISE))
	save.price_pressure *= PRESSURE_KEEP
	save.price_history.append(save.price_factor)
	if save.price_history.size() > HISTORY:
		save.price_history = save.price_history.slice(-HISTORY)
	_show_price()


## A pack bought, by the standing order when `auto` (counted in save.packs_auto, else packs_manual).
func _press(auto := false) -> void:
	var save := SaveManager.save
	var cost := _cost()
	if save.coins < cost or not fits(save.stock, save.pack_size, save.storage_cap):
		$Denied.cue($Button.global_position)
		_blink()
		return
	save.coins -= cost
	if _bailout >= 0:
		_bailout = -1
		_show_price()
	save.stock += save.pack_size
	if auto:
		save.packs_auto += 1
	else:
		save.packs_manual += 1
	save.price_pressure += PRESSURE_PER_PACK
	$Press.cue($Button.global_position)


## A pack's `price` with `stock` units already in stock: OVERSTOCK_MUL times it from OVERSTOCK on.
static func overstock_price(price: int, stock: int) -> int:
	return price * OVERSTOCK_MUL if stock >= OVERSTOCK else price


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


## The AUTO lamp and its light switch: there once the card is stamped; the lamp amber while on,
## dark while off, the toggle up (on) or down, flicked there unless `animate` is false.
func _show_auto(animate := true) -> void:
	var save := SaveManager.save
	_auto.visible = save.stamped.has("auto_procurement")
	_auto_switch.enabled = _auto.visible
	_auto_on = save.auto_buy
	_auto.modulate = AMBER if save.auto_buy else AUTO_OFF
	_toggle.show_on(save.auto_buy, animate)


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
	_price.text = _price_text()
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


## What a pack costs: `size` cabbages at `unit`, times the minute's price factor and the
## cheaper-pack discount; never under $1, nor under `least` a cabbage (stage 2's crate_floor, which
## neither the ticker nor the discount moves).
static func pack_price(factor: float, size: int, discount := 1.0, unit := UNIT_COST, least := 0.0) -> int:
	return maxi(maxi(roundi(factor * unit * size * discount), roundi(least * size)), 1)


## Stage 2's least a crate unit costs: crate_share of the full-sale price (normal mood); 0 before the shock.
static func crate_floor(save: SaveGame) -> float:
	return crate_share(save.supply_shock, squeezing(save)) * Slate.ref_price(save.marketing, 1.0)


## Stage 2's crate price as a share of the full-sale price: 0 before the shock, SHOCK_SHARE after,
## SQUEEZE_SHARE (dearer than the street pays) for good once `squeeze` is on.
static func crate_share(shock: bool, squeeze: bool) -> float:
	if not shock:
		return 0.0
	return SQUEEZE_SHARE if squeeze else SHOCK_SHARE


## The wholesalers' squeeze: on for good once both the shock and the family farm are in.
static func squeezing(save: SaveGame) -> bool:
	return save.supply_shock and save.stamped.has("family_farm")


## Whether a broke desk may get a bailout pack: not once minis exist (they drop for free and sell),
## not while the farm feeds it (seeds or crops), and never in the squeeze (the wholesalers hand out
## no cheap crates; the farm is the supply).
static func bails_out(save: SaveGame) -> bool:
	return not save.stamped.has("mini_cabbages") and not FarmScreen.feeds(save) and not squeezing(save)


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
