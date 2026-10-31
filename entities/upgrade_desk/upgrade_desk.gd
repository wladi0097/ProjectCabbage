class_name UpgradeDesk
extends Node3D
## The upgrade cards: one-off requisition forms in a fixed queue (CARDS). The first time the coins
## reach TRAY_COINS an inbox tray drops onto the bottom-left desk and the next three cards sail
## into it. Drag one onto the approval press by the window, grab the press's red handle and crank
## it down: at the bottom the head comes down on the card. Paid from the tally, it is stamped
## APPROVED and takes effect; once the head lifts it goes on the spike file and the next card is
## dealt. Too poor, the head thuds and the card's price blinks red. Cards with currency "findings"
## are paid in Findings (¶) instead of coins. A card let go anywhere else
## flies back. A card with `needs` is only dealt once all the cards it lists are stamped. Further
## hands are hired in the projector tree, not here. Retired ids in old saves (bulk_procurement) are
## skipped (migrate). Sits at the world origin; the positions below are world space.

const CARDS := [
	# The queue (pacing in tools/pace.py, graph in reports/economy_rework_2026-10-31.md). Cards wait on
	# each other (`needs`), so the tray narrows to one or two before the next ones open together.
	{id = "price_slate", price = 12, title = "PRICE SLATE",
		body = "A slate to chalk your own price per unit on."},
	{id = "desk_space", price = 20, title = "DESK SPACE REALLOCATION", needs = ["price_slate"],
		body = "A second unit may now occupy the mat."},
	{id = "junior_associate", price = 35, title = "HIRE A JUNIOR ASSOCIATE", needs = ["price_slate"],
		body = "Unpaid. Moves a unit now and then."},
	{id = "acceptance_meter", price = 40, title = "ACCEPTANCE METER", needs = ["price_slate"],
		body = "A gauge on the slate shows how likely the street buys. Measured, it buys 20% more."},
	{id = "quality_assurance", price = 55, title = "ESTABLISH QUALITY ASSURANCE", needs = ["desk_space", "junior_associate"],
		body = "An inspection bay in the window. Units flicked into it are analysed into Findings."},
	{id = "street_posters", price = 10, currency = "findings", title = "STREET POSTER CAMPAIGN",
		needs = ["quality_assurance"], body = "Findings show the street wants cabbage. Posters remind it."},
	{id = "projector", price = 75, title = "REQUISITION A PROJECTOR", needs = ["quality_assurance", "acceptance_meter"],
		body = "Improvements to the process will now be presented. Attendance is mandatory."},
	# Research directives (`research`): a projector node naming one in its own `research` is shown
	# locked until it is stamped. The id stays performance_review for old saves.
	{id = "research_inspection", price = 10, currency = "findings", research = true, title = "RESEARCH: INSPECTION METHODOLOGY",
		needs = ["projector"], body = "The inspection is inspected. Opens the QA branch of the projector."},
	# Manager + pricing consultant: no effect here, entities/manager/ and entities/consultant/ start
	# once stamped; their small upgrades are projector nodes.
	{id = "pricing_consultant", price = 15, currency = "findings", title = "RETAIN A PRICING CONSULTANT",
		needs = ["projector", "street_posters"], body = "Billed by the hour. Moves your price until every unit sells."},
	# Sales events: no effect here, entities/golden_lamp/, catch_combo/, rotten_bin/ and
	# window_targets/ start once stamped; their small upgrades are projector nodes. Rotten units
	# start coming down the chute as soon as the bin card is offered (RottenBin.rotten_due).
	{id = "catch_combo", price = 15, currency = "findings", title = "INTERCEPTION INCENTIVE SCHEME",
		needs = ["projector"], body = "Units caught in mid-air off the chute raise the price of every sale for a while. Catch again to keep it."},
	{id = "performance_review", price = 25, currency = "findings", research = true, title = "RESEARCH: TIME-AND-MOTION STUDY",
		needs = ["research_inspection", "pricing_consultant"], body = "Every motion is timed. Associates work twice as fast. Opens Hire V+ and Brisk Walk II+."},
	{id = "rotten_bin", price = 10, currency = "findings", title = "REQUISITION A WASTE BIN",
		needs = ["research_inspection", "catch_combo"], body = "Rotten units are fined at the window. Drop them in here instead."},
	{id = "managerial_oversight", price = 30, currency = "findings", title = "REQUEST MANAGERIAL OVERSIGHT",
		needs = ["performance_review"], body = "A manager will look in now and then. Quotas met are rewarded."},
	{id = "regional_billboard", price = 40, currency = "findings", title = "REGIONAL BILLBOARD",
		needs = ["performance_review"], body = "One face, one cabbage, forty feet tall. The street pays 50% more."},
	{id = "window_targets", price = 40, currency = "findings", title = "STREET TARGET PRACTICE",
		needs = ["performance_review", "rotten_bin"], body = "Now and then a crate in the street is lit. A unit sold into it pays ten times over."},
	{id = "research_materials", price = 50, currency = "findings", research = true, title = "RESEARCH: MATERIALS HANDLING",
		needs = ["managerial_oversight", "regional_billboard", "window_targets"], body = "Units are found to be heavy. Opens Pack +5 and the conveyor."},
	# Supply + automation: the console reorders packs on its own (entities/supply_console/), a coin
	# vacuum docks on the mat (entities/vacuum/); their small upgrades are projector nodes.
	{id = "auto_procurement", price = 80, currency = "findings", title = "STANDING PURCHASE ORDER",
		needs = ["research_materials"], body = "Packs are reordered when stock runs low. Nobody signs anything. Switch: AUTO on the console."},
	{id = "coin_collector", price = 100, currency = "findings", title = "AUTOMATED COIN RECOVERY UNIT",
		needs = ["research_materials"], body = "A small machine collects loose coins from the mat. It does not ask why."},
	# No effect here: entities/ledger/ shows the ledger once it is stamped.
	{id = "stats_ledger", price = 120, currency = "findings", title = "REQUISITION A LEDGER",
		needs = ["research_materials"], body = "Every unit is now recorded in ink. Someone may read it."},
	{id = "research_sentiment", price = 300, currency = "findings", research = true, title = "RESEARCH: CONSUMER SENTIMENT",
		needs = ["auto_procurement", "coin_collector", "stats_ledger"], body = "The street is asked how it feels. Opens Slogan IV and beyond."},
	{id = "golden_lamp", price = 700, currency = "findings", title = "REQUISITION A DESK LAMP",
		needs = ["research_sentiment"], body = "Now and then it glows gold. While it does, every sale pays five times. Nobody knows why."},
]
const OFFERED := 3
const TRAY_COINS := 15
## The card slots in the tray and the card's spot on the press pad, in their own node's space.
const SLOTS: Array[Vector3] = [Vector3(0.0, 0.02, -0.24), Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.02, 0.24)]
const PAD := Vector3(0.0, 0.047, 0.0)
## A card let go within this flat distance of the pad goes onto it.
const PRESS_REACH := 0.2
const SPIKE_STEP := 0.006
const DEAL_STAGGER := 0.12
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
## The lever (press space): pivot, handle distance from it, rest angle above level, and how far it
## swings down. Cranked fully down (crank 1) the head has come down HEAD_DROP onto the pad.
const PIVOT := Vector3(0.085, 0.27, -0.12)
const HANDLE_REACH := 0.31
const LEVER_REST := 0.1745
const LEVER_SWING := 0.6109
const HEAD_DROP := 0.08
## The crank follows the hand at most this fast (crank per second): the lever is heavy.
const CRANK_SPEED := 5.0
const BOTTOM := 0.97
## The head must come back up past this before the stamped card leaves for the spike.
const CLEAR := 0.3

## The cards on offer, in slot order (the one on the press included).
var _offered: Array[UpgradeCard] = []
var _on_press: UpgradeCard
## Stamped and waiting for the head to lift.
var _leaving: UpgradeCard
var _crank := 0.0
var _cranking := false
var _bottomed := false
var _springing: Tween
## Cards on the spike file.
var _spiked := 0

@onready var _tray: Node3D = $Tray
@onready var _press: Node3D = $Press
@onready var _spike: Node3D = $Spike
@onready var _skeleton: Skeleton3D = $Press/Model/Armature/Skeleton3D
@onready var _head := _skeleton.find_bone("Head")
@onready var _lever := _skeleton.find_bone("Lever")
@onready var _tray_rest := _tray.position


func _ready() -> void:
	var handle: Interactable = $Press/Handle/Interactable
	# The fist closes round the red ball itself.
	handle.grip_height = 0.03
	handle.reach = true
	handle.grabbed.connect(_grab_lever)
	handle.released.connect(_let_go_lever)
	var save := SaveManager.save
	migrate(save)
	for id in save.stamped:
		if card_data(id).is_empty():
			continue
		var card := UpgradeCard.new(card_data(id))
		add_child(card)
		card.stamp(false)
		card.position = _spike_spot(_spiked)
		card.rotation.y = randf_range(-0.5, 0.5)
		_spiked += 1
	_pose_press()
	if save.tray_unlocked:
		_deal(false)
	else:
		_tray.visible = false
		_tray.position = _tray_rest + Vector3.UP * 10.0


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.tray_unlocked and save.coins >= TRAY_COINS:
		save.tray_unlocked = true
		_drop_tray()
	if _cranking:
		_crank = move_toward(_crank, _crank_under_mouse(), CRANK_SPEED * delta)
		if _crank >= BOTTOM and not _bottomed:
			_bottomed = true
			_bottom_out()
	if _cranking or (_springing != null and _springing.is_running()):
		_pose_press()
	if _leaving != null and _crank < CLEAR:
		_leaving.spike_to(_spike_spot(_spiked), randf_range(-0.5, 0.5))
		_spiked += 1
		_leaving = null
		_deal()


## The next `count` cards in the queue that are not stamped yet and whose `needs` all are.
static func next_cards(stamped: PackedStringArray, count: int) -> Array[String]:
	var out: Array[String] = []
	for card: Dictionary in CARDS:
		var open: bool = card.get("needs", []).all(func(need: String) -> bool: return stamped.has(need))
		if out.size() < count and open and not stamped.has(card.id):
			out.append(card.id)
	return out


static func card_data(id: String) -> Dictionary:
	for card: Dictionary in CARDS:
		if card.id == id:
			return card
	return {}


## Fixes up a save from an older build, once (save.migration): the hands count, the acceptance
## meter's later ×1.2 marketing, the retired bulk_procurement card (now the tree's pack_1, same +3
## pack) and a chalked price above today's cap.
static func migrate(save: SaveGame) -> void:
	if save.hands == 0 and save.stamped.has("junior_associate"):
		save.hands = 1  # A save from before hands were counted.
	if save.migration < 1:
		if save.stamped.has("acceptance_meter") and not meter_logged(save.playtest_log):
			save.marketing *= 1.2
		if save.stamped.has("bulk_procurement") and not save.tree_bought.has("pack_1"):
			save.tree_bought.append("pack_1")
	save.migration = SaveGame.MIGRATION
	save.sale_price = mini(save.sale_price, PriceSlate.max_price(save.marketing))


## The playtest log shows the acceptance meter's stamp raising marketing ×1.2 already (a save from
## the build that added it, before save.migration existed).
static func meter_logged(entries: Array[Dictionary]) -> bool:
	for i in range(1, entries.size()):
		if entries[i].kind == "card" and entries[i].id == "acceptance_meter":
			return entries[i].marketing > entries[i - 1].marketing * 1.15
	return false


## What stamping card `id` does to the save. Quality assurance, the projector, the ledger and the
## research cards (performance_review aside) only need to be in `stamped`.
static func apply(id: String, save: SaveGame) -> void:
	match id:
		"price_slate":
			save.slate_unlocked = true
		"desk_space":
			save.desk_capacity += 1
		"junior_associate":
			save.hands = maxi(save.hands, 1)
		"acceptance_meter":
			save.marketing *= 1.2
		"street_posters":
			save.marketing *= 1.5
		"performance_review":
			save.associate_interval *= 0.5
		"regional_billboard":
			save.marketing *= 1.5
		"coin_collector":
			save.vacuums = maxi(save.vacuums, 1)


## The handle's centre (press space) with the lever cranked `crank` of the way down.
static func handle_at(crank: float) -> Vector3:
	var angle := LEVER_REST - crank * LEVER_SWING
	return PIVOT + Vector3(0.0, sin(angle), cos(angle)) * HANDLE_REACH


func _spike_spot(index: int) -> Vector3:
	return _spike.position + Vector3(0.0, 0.045 + index * SPIKE_STEP, 0.0)


func _slot(index: int) -> Vector3:
	return _tray_rest + SLOTS[index]


func _pad() -> Vector3:
	return _press.transform * PAD


## Fills the free slots from the queue (new cards sail in one after another) and moves the cards
## still on offer up to theirs. `animate` false lays them straight down (loading a save).
func _deal(animate := true) -> void:
	var dealt := 0
	for id in next_cards(SaveManager.save.stamped, OFFERED):
		if _offered.any(func(other: UpgradeCard) -> bool: return other.id == id):
			continue
		var card := UpgradeCard.new(card_data(id))
		add_child(card)
		card.dropped.connect(_on_dropped)
		card.press_at = _pad()
		_offered.append(card)
		var slot := _slot(_offered.size() - 1)
		if not animate:
			card.position = slot
			continue
		card.position = Vector3(0, -10, 0)
		get_tree().create_timer(DEAL_STAGGER * dealt).timeout.connect(card.deal_to.bind(slot))
		dealt += 1
	for i in _offered.size():
		var card := _offered[i]
		if card != _on_press and card.position.y > -1.0 and not card.position.is_equal_approx(_slot(i)):
			card.fly_to(_slot(i))


func _on_dropped(card: UpgradeCard) -> void:
	var pad := _pad()
	var near := Vector2(card.position.x - pad.x, card.position.z - pad.z).length() < PRESS_REACH
	if near and _crank < CLEAR and _leaving == null:
		if _on_press != null and _on_press != card:
			_on_press.fly_to(_slot(_offered.find(_on_press)))
		_on_press = card
		card.fly_to(pad, true, _press.rotation.y)
		return
	if _on_press == card:
		_on_press = null
	card.fly_to(_slot(_offered.find(card)))


func _grab_lever() -> void:
	if _springing != null:
		_springing.kill()
	_cranking = true
	$Lever.cue(_press.global_position)


func _let_go_lever() -> void:
	_cranking = false
	_bottomed = false
	if _crank > CLEAR:
		$Return.cue(_press.global_position)
	_springing = create_tween()
	_springing.tween_property(self, "_crank", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# The last frame of the spring lands after _process stopped posing it.
	_springing.tween_callback(_pose_press)


## Where the mouse is along the handle's swing, 0 (rest) to 1 (fully down), read off the vertical
## plane the handle swings in, so the handle stays under the hand.
func _crank_under_mouse() -> float:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(_press.global_basis.z, _press.to_global(handle_at(0.0)))
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return _crank
	var y: float = (hit as Vector3).y - _press.global_position.y
	return clampf(inverse_lerp(handle_at(0.0).y, handle_at(1.0).y, y), 0.0, 1.0)


## The head is down: a card on the pad gets stamped if the tally can pay, else a dry thud.
func _bottom_out() -> void:
	$Press/Puff.restart()
	var save := SaveManager.save
	var card := _on_press
	if card == null or save.get(card.currency) < card.price:
		$Denied.cue(_pad())
		if card != null:
			card.blink()
		return
	save.set(card.currency, save.get(card.currency) - card.price)
	save.stamped.append(card.id)
	apply(card.id, save)
	SaveManager.log_event("card", card.id, card.price, card.currency)
	$Stamp.cue(_pad())
	card.stamp()
	_on_press = null
	_offered.erase(card)
	_leaving = card
	var squash := create_tween()
	squash.tween_property($Press/Model, "scale", Vector3(1.04, 0.94, 1.04), 0.05)
	squash.tween_property($Press/Model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pose_press() -> void:
	_skeleton.set_bone_pose_position(_head, _skeleton.get_bone_rest(_head).origin + Vector3.DOWN * HEAD_DROP * clampf(_crank, 0.0, 1.0))
	_skeleton.set_bone_pose_rotation(_lever, Quaternion(Vector3.RIGHT, LEVER_SWING * _crank)
			* _skeleton.get_bone_rest(_lever).basis.get_rotation_quaternion())
	$Press/Handle.position = handle_at(_crank)


func _drop_tray() -> void:
	_tray.visible = true
	_tray.position = _tray_rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_tray, "position", _tray_rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		$Tray/Dust.restart()
		$Thud.cue(_tray.global_position)
		_deal())
	tween.tween_property($Tray/Model, "scale", Vector3(1.06, 0.7, 1.06), 0.06)
	tween.tween_property($Tray/Model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
