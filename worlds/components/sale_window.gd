extends Area3D
## The window gap, from the sill outward. A cabbage that reaches it is bought with the chance
## PriceSlate.demand gives for the chalked price: it is let go and sucked out into the street, and
## after a beat the street throws the price in coins back in. Otherwise it is pulled out all the
## same, and after AWAY_TIME the street throws it back onto the mat. Checked every physics tick, so
## one pushed out by another or left in the gap is judged too; and one off the mat (fallen, or
## hidden behind the press and ramp) for STRAY_TIME is thrown back in, so no cabbage is ever lost.

signal sold(cabbage: Cabbage)
signal refused(cabbage: Cabbage)

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
const Slate := preload("res://entities/price_slate/price_slate.gd")
const GAP_X := Vector2(-0.4, 1.8)
const THROW_DELAY := 0.45
const SUCK_TIME := 0.35
## How far past the wall a sold cabbage is pulled (out of sight behind the crates).
const SUCK_TO_Z := -1.9
const GAP_MID_Y := 0.92

## A refused cabbage stays out for AWAY_TIME (seconds, min..max), then is thrown from just outside
## the window (x follows it) to somewhere in REFUSE_TO, taking REFUSE_TIME. It passes the window wall
## for its first CLEAR_TIME.
const AWAY_TIME := Vector2(0.6, 1.2)
const REFUSE_FROM := Vector2(0.92, -1.1)
const REFUSE_TO := AABB(Vector3(0.0, 0.9, -0.2), Vector3(1.2, 0.0, 0.6))
const REFUSE_TIME := 0.7
const CLEAR_TIME := 0.25
## Past OUTSIDE_Z a cabbage is out of the window. Where it may be (x, z): over the mat, minus the
## corner behind the press and the ramp; anywhere else for STRAY_TIME it is thrown back in.
const OUTSIDE_Z := -0.95
const MAT := Rect2(-0.45, -0.6, 2.3, 1.7)
const HIDDEN := Rect2(1.45, -0.8, 1.0, 1.45)
const STRAY_TIME := 1.5

@export var coins: CoinPile
## Where thrown-back coins start, hidden below the sill outside (x follows the sold cabbage).
@export var throw_from := Vector3(0.0, 0.42, -1.12)

## Running tally of sales owed: each cabbage adds its chance, and a sale happens each time it
## reaches a whole one. Exact odds without unlucky streaks, and a new price counts at once.
var _owed := randf()


## Each rescue is printed to the log with where the cabbage was.
func _physics_process(delta: float) -> void:
	for cabbage: Cabbage in get_tree().get_nodes_in_group(&"cabbages"):
		if cabbage.sold or cabbage.away or cabbage.freeze:
			continue
		var at := cabbage.global_position
		var inside := overlaps_body(cabbage)
		if inside or at.z < OUTSIDE_Z:
			if not inside:
				print("SaleWindow: cabbage past the window at %s, judged" % at)
			_judge(cabbage)
			continue
		var held := Hand.held != null and Hand.held.get_parent() == cabbage
		cabbage.stray_time = cabbage.stray_time + delta if not held and is_stray(at) else 0.0
		if cabbage.stray_time > STRAY_TIME:
			print("SaleWindow: cabbage strayed to %s, thrown back in" % at)
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
	var x := clampf(cabbage.global_position.x, GAP_X.x, GAP_X.y)
	var out := Vector3(x, GAP_MID_Y, SUCK_TO_Z)
	$Suck.cue(cabbage.global_position)
	if not _buys(Slate.acceptance(save)):
		cabbage.send_away(out, SUCK_TIME)
		refused.emit(cabbage)
		_send_back(cabbage, SUCK_TIME + randf_range(AWAY_TIME.x, AWAY_TIME.y))
		return
	cabbage.suck_out(out, SUCK_TIME)
	SaveManager.save.stock -= 1
	SaveManager.save.sold += 1
	sold.emit(cabbage)
	get_tree().create_timer(THROW_DELAY).timeout.connect(
			coins.throw_in.bind(Vector3(x, throw_from.y, throw_from.z), price))


## After `wait` seconds the street throws `cabbage` back in through the window.
func _send_back(cabbage: Cabbage, wait: float) -> void:
	get_tree().create_timer(wait, false).timeout.connect(func() -> void:
		if not is_instance_valid(cabbage):
			return
		var x := clampf(cabbage.global_position.x, GAP_X.x, GAP_X.y)
		var from := Vector3(x, REFUSE_FROM.x, REFUSE_FROM.y)
		var to := REFUSE_TO.position + REFUSE_TO.size * Vector3(randf(), 0.0, randf())
		cabbage.throw_in(from, Feeder.ballistic_velocity(from, to, REFUSE_TIME), CLEAR_TIME, REFUSE_TIME)
		$Refuse.cue(from))


func _buys(chance: float) -> bool:
	_owed += chance
	if _owed < 1.0:
		return false
	_owed -= 1.0
	return true
