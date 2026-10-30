extends Area3D
## The window gap, from the sill outward. A cabbage that reaches it is sold: it is let go and
## sucked out into the street, and after a beat the street throws coins back in.

signal sold(cabbage: Cabbage)

const GAP_X := Vector2(-0.4, 1.8)
const THROW_DELAY := 0.45
const SUCK_TIME := 0.35
## How far past the wall a sold cabbage is pulled (out of sight behind the crates).
const SUCK_TO_Z := -1.9
const GAP_MID_Y := 0.92

@export var coins: CoinPile
@export var coins_per_cabbage := 1
## Where thrown-back coins start, hidden below the sill outside (x follows the sold cabbage).
@export var throw_from := Vector3(0.0, 0.42, -1.12)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var cabbage := body as Cabbage
	if cabbage == null or cabbage.sold:
		return
	var x := clampf(cabbage.global_position.x, GAP_X.x, GAP_X.y)
	cabbage.suck_out(Vector3(x, GAP_MID_Y, SUCK_TO_Z), SUCK_TIME)
	$Suck.cue(cabbage.global_position)
	sold.emit(cabbage)
	get_tree().create_timer(THROW_DELAY).timeout.connect(
			coins.throw_in.bind(Vector3(x, throw_from.y, throw_from.z), coins_per_cabbage))
