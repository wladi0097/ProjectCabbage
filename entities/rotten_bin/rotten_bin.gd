class_name RottenBin
extends Node3D
## Rotten units and the bin. From the moment the "rotten_bin" card is first offered in the tray,
## save.rotten_unlocked is set and the chute sends one rotten unit in CabbageFeeder.ROTTEN_EVERY
## (the player meets the problem before the fix is for sale). Selling one is fined by the
## SaleWindow; this node shows the fine notice (FineNotice). Once the card is stamped a steel
## waste bin drops in at the bottom screen edge: a rotten unit let go over its mouth falls in and
## is gone (stock −1, rebate save.bin_rebate × the chalked price). Fresh units are not taken.
## The mouth grows with save.bin_mouth. Hired hands leave rotten units alone unless save.hands_bin.

const CARD := "rotten_bin"
## Mouth radius at bin_mouth 1, and how far past it a cabbage's centre may be and still drop in.
const MOUTH := 0.12
## The model is drawn this much smaller than built (its mouth then is MOUTH at bin_mouth 1).
const MODEL_SCALE := 0.85
const SLACK := 0.11
## Only below this height: one carried high over the bin is not in it yet.
const TOP_Y := 1.15
const FALL_TIME := 0.22
const DROP_HEIGHT := 1.0
const DROP_TIME := 0.35
## Hired hands lob rotten units at this point over the mouth.
const HAND_AIM := Vector3(0.95, 0.96, 1.17)
## Seconds between looks over the mouth for rotten units.
const CHECK_EVERY := 0.1

var _rest := Vector3.ZERO
## The stamped count rotten_due was last checked at (it only changes with a stamp or the tray).
var _due_checked := -1
var _check := 0.0


func _ready() -> void:
	_rest = position
	visible = SaveManager.save.stamped.has(CARD)
	$Model.scale = Vector3.ONE * MODEL_SCALE * SaveManager.save.bin_mouth
	_connect_window.call_deferred()


func _connect_window() -> void:
	var window := get_tree().get_first_node_in_group(&"sale_window") as SaleWindow
	if window != null:
		window.fined.connect(func(_cabbage: Cabbage, fine: int) -> void: $Notice.show_fine(fine))


func _process(delta: float) -> void:
	var save := SaveManager.save
	var key := save.stamped.size() * 2 + int(save.tray_unlocked)
	if not save.rotten_unlocked and key != _due_checked:
		_due_checked = key
		save.rotten_unlocked = rotten_due(save)
	if not visible:
		if save.stamped.has(CARD):
			_arrive()
		return
	var mouth := Vector3.ONE * MODEL_SCALE * save.bin_mouth
	if not $Model.scale.is_equal_approx(mouth):
		$Model.scale = $Model.scale.move_toward(mouth, delta)


func _physics_process(delta: float) -> void:
	_check -= delta
	if not visible or _check > 0.0:
		return
	_check = CHECK_EVERY
	var reach := MOUTH * SaveManager.save.bin_mouth + SLACK
	for cabbage: Cabbage in get_tree().get_nodes_in_group(&"cabbages"):
		if cabbage.rotten and not cabbage.sold and not cabbage.away and not cabbage.freeze \
				and (Hand.held == null or Hand.held.get_parent() != cabbage) \
				and in_mouth(global_position, cabbage.global_position, reach):
			_take(cabbage)


## Rotten units start coming once the bin card is in the tray (or stamped).
static func rotten_due(save: SaveGame) -> bool:
	return save.stamped.has(CARD) or (save.tray_unlocked
			and UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED).has(CARD))


## A cabbage at `at` is over the bin standing at `bin` (mouth `reach` wide) and low enough to fall in.
static func in_mouth(bin: Vector3, at: Vector3, reach: float) -> bool:
	return at.y < TOP_Y and Vector2(at.x - bin.x, at.z - bin.z).length() < reach


## The rebate for one binned unit: `rebate` chalked prices.
static func rebate_for(rebate: float, price: int) -> int:
	return roundi(rebate * price)


func _take(cabbage: Cabbage) -> void:
	var save := SaveManager.save
	cabbage.suck_out(global_position + Vector3.UP * 0.06, FALL_TIME)
	save.stock -= 1
	save.binned += 1
	save.coins += rebate_for(save.bin_rebate, save.sale_price)
	get_tree().create_timer(FALL_TIME * 0.8).timeout.connect(func() -> void:
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
