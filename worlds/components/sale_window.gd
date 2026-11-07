class_name SaleWindow
extends Area3D
## The window gap, from the sill outward. A cabbage that reaches it is bought with the chance
## PriceSlate.demand gives for the chalked price: it is let go and sucked out into the street, and
## after a beat the street throws the price in coins back in. Otherwise it is pulled out all the
## same, and after AWAY_TIME the street throws it back onto the mat. Checked every physics tick, so
## one pushed out by another or left in the gap is judged too; and one off the mat (fallen, or
## hidden behind the press and ramp) for STRAY_TIME is thrown back in, so no cabbage is ever lost.

## `coins`: what the street throws back for it, every boost included.
signal sold(cabbage: Cabbage, coins: int)
signal refused(cabbage: Cabbage)
## A refused cabbage is thrown back in through the window (AWAY_TIME after `refused`).
signal thrown_back(cabbage: Cabbage)
## A rotten unit went out: `fine` coins were taken from the tally (all of it if it was short).
signal fined(cabbage: Cabbage, fine: int)

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
const Slate := preload("res://entities/price_slate/price_slate.gd")
const GAP_X := Vector2(-0.4, 1.8)
## Once the QA bay fills the gap's left third, the window only sells right of this x.
const SPLIT_X := 0.33
const THROW_DELAY := 0.45
const SUCK_TIME := 0.35
## How far past the wall a sold cabbage is pulled (out of sight behind the crates).
const SUCK_TO_Z := -1.9
const GAP_MID_Y := 0.92
## Selling a rotten unit costs this many times the chalked price.
const FINE := 10

## A refused cabbage stays out for AWAY_TIME (seconds, min..max), then is thrown from just outside
## the window (x follows it) to somewhere in REFUSE_TO, taking REFUSE_TIME. It passes the window wall
## for its first CLEAR_TIME.
const AWAY_TIME := Vector2(0.6, 1.2)
const REFUSE_FROM := Vector2(0.92, -1.1)
const REFUSE_TO := AABB(Vector3(0.0, 0.9, -0.2), Vector3(1.2, 0.0, 0.6))
const REFUSE_TIME := 0.7
const CLEAR_TIME := 0.25
## Past OUTSIDE_Z a cabbage is out of the window. Where it may be (x, z): over the mat, minus the
## corner behind the press and the ramp; anywhere else for STRAY_TIME it is thrown back in. MAT reaches
## past the PlayArea's LeftBar (x -0.564) and ScreenBottom (z 1.22), so one resting against a bar stays.
const OUTSIDE_Z := -0.95
const MAT := Rect2(-0.6, -0.6, 2.45, 1.85)
const HIDDEN := Rect2(1.45, -0.8, 1.0, 1.45)
const STRAY_TIME := 1.5

@export var coins: CoinPile
## Where thrown-back coins start, hidden below the sill outside (x follows the sold cabbage).
@export var throw_from := Vector3(0.0, 0.42, -1.12)

## Running tally of sales owed: each cabbage adds its chance, and a sale happens each time it
## reaches a whole one. Exact odds without unlucky streaks, and a new price counts at once.
var _owed := randf()
var _gap_x := GAP_X
## Every sale multiplier running now, by who set it (the golden lamp, the catch combo): each
## effect sets and erases its own entry, payout() multiplies them all into the price.
var boosts := {}
var _bubble: RefusalBubble


func _ready() -> void:
	add_to_group(&"sale_window")
	var layer := CanvasLayer.new()
	add_child(layer)
	_bubble = RefusalBubble.new()
	layer.add_child(_bubble)


## Coins for one sale at `price` with every factor in `boosts`; never below 1.
static func payout(price: int, factors: Dictionary) -> int:
	var total := float(price)
	for factor: float in factors.values():
		total *= factor
	return maxi(1, roundi(total))


## Coins taken for selling a rotten unit at `price`, out of `available`: FINE times the price, at most all.
static func fine_for(price: int, available: int) -> int:
	return mini(FINE * price, available)


## The gap's x span a sale can go out through (narrower once the QA bay is in).
func sell_span() -> Vector2:
	return _gap_x


## The QA bay is in: the sale zone shrinks to the gap's right two thirds.
func split() -> void:
	_gap_x.x = SPLIT_X
	var zone: CollisionShape3D = $Zone
	var box := zone.shape.duplicate() as BoxShape3D
	var right := zone.position.x + box.size.x / 2.0
	box.size.x = right - SPLIT_X
	zone.shape = box
	zone.position.x = (right + SPLIT_X) / 2.0


## Each rescue is printed to the verbose log (--verbose) with where the cabbage was.
func _physics_process(delta: float) -> void:
	for cabbage: Cabbage in get_tree().get_nodes_in_group(&"cabbages"):
		if cabbage.sold or cabbage.away or cabbage.freeze:
			continue
		var at := cabbage.global_position
		var inside := overlaps_body(cabbage)
		if inside or at.z < OUTSIDE_Z:
			if not inside:
				print_verbose("SaleWindow: cabbage past the window at %s, judged" % at)
			_judge(cabbage)
			continue
		var held := Hand.held != null and Hand.held.get_parent() == cabbage
		cabbage.stray_time = cabbage.stray_time + delta if not held and is_stray(at) else 0.0
		if cabbage.stray_time > STRAY_TIME:
			print_verbose("SaleWindow: cabbage strayed to %s, thrown back in" % at)
			cabbage.stray_time = 0.0
			cabbage.send_away(at, 0.01)
			_send_back(cabbage, 0.0)


## Off the mat at `at`, or hidden behind the press and ramp.
static func is_stray(at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
	return not MAT.has_point(flat) or HIDDEN.has_point(flat)


func _judge(cabbage: Cabbage) -> void:
	var save := SaveManager.save
	var price := save.sale_price
	var x := clampf(cabbage.global_position.x, _gap_x.x, _gap_x.y)
	var out := Vector3(x, GAP_MID_Y, SUCK_TO_Z)
	$Suck.cue(cabbage.global_position)
	if cabbage.rotten:
		# Inspected at the window and confiscated: no refusal, no coins, a fine.
		cabbage.suck_out(out, SUCK_TIME)
		save.stock -= 1
		var fine := fine_for(price, save.coins)
		save.coins -= fine
		save.fines += 1
		fined.emit(cabbage, fine)
		return
	if not _buys(Slate.acceptance(save)):
		cabbage.send_away(out, SUCK_TIME)
		refused.emit(cabbage)
		_bubble.say(price, out)
		_send_back(cabbage, SUCK_TIME + randf_range(AWAY_TIME.x, AWAY_TIME.y), true)
		return
	cabbage.suck_out(out, SUCK_TIME)
	SaveManager.save.stock -= 1
	SaveManager.save.sold += 1
	var paid := payout(price, boosts)
	sold.emit(cabbage, paid)
	coins.throw_in_after(THROW_DELAY, Vector3(x, throw_from.y, throw_from.z), paid)


## After `wait` seconds the street throws `cabbage` back in through the window (`refused`: emits thrown_back).
func _send_back(cabbage: Cabbage, wait: float, refused_unit := false) -> void:
	get_tree().create_timer(wait, false).timeout.connect(func() -> void:
		if not is_instance_valid(cabbage):
			return
		var x := clampf(cabbage.global_position.x, _gap_x.x, _gap_x.y)
		var from := Vector3(x, REFUSE_FROM.x, REFUSE_FROM.y)
		var to := REFUSE_TO.position + REFUSE_TO.size * Vector3(randf(), 0.0, randf())
		cabbage.throw_in(from, Feeder.ballistic_velocity(from, to, REFUSE_TIME), CLEAR_TIME, REFUSE_TIME)
		$Refuse.cue(from)
		if refused_unit:
			thrown_back.emit(cabbage))


func _buys(chance: float) -> bool:
	_owed += chance
	if _owed < 1.0:
		return false
	_owed -= 1.0
	return true
