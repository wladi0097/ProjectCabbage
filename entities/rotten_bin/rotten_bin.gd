class_name RottenBin
extends Node3D
## Rotten units and the bin (the "rotten_units" big event in globalScripts/game_events.gd). From
## the moment the catch_combo card is stamped, save.rotten_unlocked is set, the chute sends one
## rotten unit in CabbageFeeder.ROTTEN_EVERY and the boss's note announces them. Selling one is
## fined by the SaleWindow; this node shows the fine notice (FineNotice). At the same moment a steel
## waste bin drops in for free at the mat's bottom edge, just inside the screen, beside the supply
## console: a unit the player lets go of (or a hired hand lobs) near its mouth is
## lifted over the rim and dropped in (Cabbage.drop_into), and is gone (stock −1). One that only
## rolled or was bumped in (Cabbage.meant_for_bin false) is popped back out onto the desk. A rotten one pays
## a rebate once DISPOSAL REBATE is bought: save.bin_coins dollars, whatever the price, popped out of
## the mouth as coins onto the mat (counted in save.binned); a fresh one is simply
## wasted, for nothing. The mouth grows with save.bin_mouth. Hired hands sell rotten units too
## (fined) until save.hands_bin, then lob them at hand_aim(); they never bin fresh ones (bin_for).

const Events := preload("res://globalScripts/game_events.gd")
## Mouth radius at bin_mouth 1, and how far past it a cabbage's centre may be and still drop in.
const MOUTH := 0.132
## The model is drawn at this scale of what was built (its mouth then is MOUTH at bin_mouth 1).
const MODEL_SCALE := 0.935
## The built model's rim height; a binned cabbage's centre clears it by CLEAR on its way in.
const RIM := 0.262
## The bin is sunk this share of its height into the desk (the node stays at desk level); a black
## disc at desk level inside the mouth hides the desk top, so it reads as going on down.
const SINK := 0.5
const CLEAR := 0.16
const SLACK := 0.11
## A unit let go this far (m) past the mouth's reach still counts as aimed at the bin (let_go_over).
const AIM_SLACK := 0.12
## Only below this height: one carried high over the bin is not in it yet.
const TOP_Y := 1.15
const FALL_TIME := 0.4
const DROP_HEIGHT := 1.0
const DROP_TIME := 0.35
## Hired hands lob rotten units at this height over the mouth.
const HAND_AIM_Y := 0.3
## Seconds between looks over the mouth for rotten units.
const CHECK_EVERY := 0.1
## A unit that only rolled in is popped back out this fast (m/s) sideways and up.
const REJECT_SPEED := 1.2
const REJECT_LIFT := 1.5

## Where the rebate's coins go.
@export var coins: CoinPile

var _rest := Vector3.ZERO
## The stamped count rotten_due was last checked at (it only changes with a stamp).
var _due_checked := -1
var _check := 0.0


func _ready() -> void:
	add_to_group(&"rotten_bin")
	_rest = position
	visible = SaveManager.save.rotten_unlocked
	_size(Vector3.ONE * MODEL_SCALE * SaveManager.save.bin_mouth)
	_connect_window.call_deferred()


## Scales the model to `to` and keeps it sunk SINK of its height into the desk.
func _size(to: Vector3) -> void:
	$Model.scale = to
	$Model.position.y = -RIM * SINK * to.y


func _connect_window() -> void:
	var window := get_tree().get_first_node_in_group(&"sale_window") as SaleWindow
	if window != null:
		window.fined.connect(func(_cabbage: Cabbage, fine: int) -> void: $Notice.show_fine(fine))


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.rotten_unlocked and save.stamped.size() != _due_checked:
		_due_checked = save.stamped.size()
		save.rotten_unlocked = rotten_due(save)
	if not visible:
		if save.rotten_unlocked:
			_arrive()
		return
	var mouth := Vector3.ONE * MODEL_SCALE * save.bin_mouth
	if not $Model.scale.is_equal_approx(mouth):
		_size($Model.scale.move_toward(mouth, delta))


func _physics_process(delta: float) -> void:
	_check -= delta
	if not visible or _check > 0.0:
		return
	_check = CHECK_EVERY
	var reach := mouth_reach()
	for cabbage: Cabbage in get_tree().get_nodes_in_group(&"cabbages"):
		if not cabbage.sold and not cabbage.away and not cabbage.freeze \
				and (Hand.held == null or Hand.held.get_parent() != cabbage) \
				and in_mouth(global_position, cabbage.global_position, reach):
			if cabbage.meant_for_bin():
				_take(cabbage)
			else:
				cabbage.linear_velocity = reject_velocity(global_position, cabbage.global_position)


## Rolled or bumped into the mouth, not put there: the rim pops the unit back out onto the desk,
## away from the bin's middle but never toward the screen's bottom edge (straight up the desk when
## dead centre).
static func reject_velocity(bin: Vector3, at: Vector3) -> Vector3:
	var out := Vector3(at.x - bin.x, 0.0, minf(at.z - bin.z, 0.0))
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	return out * REJECT_SPEED + Vector3.UP * REJECT_LIFT


## Rotten units (and the bin) start coming once catch_combo is stamped.
static func rotten_due(save: SaveGame) -> bool:
	return Events.due("rotten_units", save)


## Where a hired hand lobs a rotten unit: over the mouth, once the bin is on the desk.
func hand_aim() -> Vector3:
	return global_position + Vector3.UP * HAND_AIM_Y


## How far from the bin's middle a cabbage's centre may be and still drop in.
func mouth_reach() -> float:
	return MOUTH * SaveManager.save.bin_mouth + SLACK


## A unit let go at `at` was aimed at the bin standing at `bin` (mouth `reach` wide): over the mouth
## or within AIM_SLACK of it (a short toss), at any height.
static func let_go_over(bin: Vector3, at: Vector3, reach: float) -> bool:
	return Vector2(at.x - bin.x, at.z - bin.z).length() < reach + AIM_SLACK


## A cabbage at `at` is over the bin standing at `bin` (mouth `reach` wide) and low enough to fall in.
static func in_mouth(bin: Vector3, at: Vector3, reach: float) -> bool:
	return at.y < TOP_Y and Vector2(at.x - bin.x, at.z - bin.z).length() < reach


## The rebate tiers bought in `bought` (projector ids), summed: what save.bin_coins should be.
static func bin_coins_for(bought: PackedStringArray) -> int:
	var total := 0
	for id in bought:
		total += Projector.node_data(id).get("add", {}).get("bin_coins", 0)
	return total


func _take(cabbage: Cabbage) -> void:
	var save := SaveManager.save
	var rim: float = global_position.y + RIM * (1.0 - SINK) * $Model.scale.y
	cabbage.drop_into(global_position + Vector3.DOWN * 0.06, rim + CLEAR, FALL_TIME)
	if cabbage.is_stock():
		save.stock -= 1  # Minis (and grown ones) are free: no stock.
	if cabbage.rotten:
		save.binned += 1
		if save.bin_coins > 0 and coins != null:
			var mouth := global_position + Vector3.UP * RIM * (1.0 - SINK)
			var spot := global_position + Vector3(randf_range(-0.3, 0.0), 0.0, randf_range(-0.32, -0.22))
			coins.pop_out_after(FALL_TIME, mouth, spot, save.bin_coins)
	get_tree().create_timer(FALL_TIME * 0.9).timeout.connect(func() -> void:
		$Drop.cue(global_position)
		var wobble := create_tween()
		wobble.tween_property($Model, "rotation:x", 0.08, 0.06)
		wobble.tween_property($Model, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


func _arrive() -> void:
	visible = true
	position = _rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback($Thud.play)
