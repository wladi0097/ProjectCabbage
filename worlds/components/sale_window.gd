extends Area3D
## The window gap, from the sill outward. A cabbage that reaches it is bought with the chance
## PriceSlate.demand gives for the chalked price: it is let go and sucked out into the street, and
## after a beat the street throws the price in coins back in. Otherwise the street throws the
## cabbage itself back onto the mat.

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

## A refused cabbage flies back to somewhere in here, taking REFUSE_TIME.
const REFUSE_TO := AABB(Vector3(0.0, 0.9, -0.2), Vector3(1.2, 0.0, 0.6))
const REFUSE_TIME := 0.7

@export var coins: CoinPile
## Where thrown-back coins start, hidden below the sill outside (x follows the sold cabbage).
@export var throw_from := Vector3(0.0, 0.42, -1.12)

## Running tally of sales owed: each cabbage adds its chance, and a sale happens each time it
## reaches a whole one. Exact odds without unlucky streaks, and a new price counts at once.
var _owed := randf()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var cabbage := body as Cabbage
	if cabbage == null or cabbage.sold:
		return
	var save := SaveManager.save
	var price := save.sale_price
	if not _buys(Slate.demand(price, Slate.ref_price(save.marketing, save.demand_mood))):
		var to := REFUSE_TO.position + REFUSE_TO.size * Vector3(randf(), 0.0, randf())
		var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		cabbage.throw_back(Feeder.ballistic_velocity(cabbage.global_position, to, REFUSE_TIME, gravity))
		$Refuse.cue(cabbage.global_position)
		refused.emit(cabbage)
		return
	var x := clampf(cabbage.global_position.x, GAP_X.x, GAP_X.y)
	cabbage.suck_out(Vector3(x, GAP_MID_Y, SUCK_TO_Z), SUCK_TIME)
	$Suck.cue(cabbage.global_position)
	SaveManager.save.stock -= 1
	SaveManager.save.sold += 1
	sold.emit(cabbage)
	get_tree().create_timer(THROW_DELAY).timeout.connect(
			coins.throw_in.bind(Vector3(x, throw_from.y, throw_from.z), price))


func _buys(chance: float) -> bool:
	_owed += chance
	if _owed < 1.0:
		return false
	_owed -= 1.0
	return true
