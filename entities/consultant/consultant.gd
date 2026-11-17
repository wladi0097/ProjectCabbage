class_name Consultant
extends Node3D
## The pricing consultant (desk card "pricing_consultant"): a ghost hand in a grey suit sleeve.
## Every save.consultant_interval seconds it checks the slate against its target price
## (target_price) and, if they differ, reaches in from the left screen edge and taps the arrow one
## step toward it ($1, or $2, $5, $10 with the projector's STEP nodes; with YIELD OPTIMISATION, SMART,
## it chalks the whole way in one tap), then hovers
## by the slate for the next tap. On target it withdraws off screen.
## Its mandate (save.consultant_bounce, consultant_floor, consultant_ceiling) is the player's word:
## it holds the whole-dollar price whose refusals at the street's current mood come nearest the share
## allowed, within the floor and ceiling (and squeeze_cap). The player outranks it: a price chalked by
## hand becomes the mandate (adopt), so it never fights a press or a held arrow and keeps the player's
## refusal share as the mood moves.
## A light switch on the slate's frame (there once the card is stamped) opens the mandate sheet
## (mandate_sheet.tscn); its lamp shows whether the consultant is on duty (save.consultant_on).

enum Phase { AWAY, REACH, TAP, HOVER, WITHDRAW }

const Slate := preload("res://entities/price_slate/price_slate.gd")
const Console := preload("res://entities/supply_console/supply_console.gd")
const SLEEVE := preload("res://assets/materials/associate_hand.tres")
const CARD := "pricing_consultant"
## Off screen past the left edge, at the slate's depth.
const ENTRY := Vector3(-2.6, 1.25, -0.3)
const SIZE := 0.9
## The mandate's refusals allowed (percent): stepped by BOUNCE_STEP from 0 to BOUNCE_MAX (a share
## adopted from the player's own price may sit above it).
const BOUNCE_STEP := 5
const BOUNCE_MAX := 50
## The projector node with which it chalks its target in one tap.
const SMART := "consultant_smart"
## The projector nodes STEP 2, 5 and 10 (step size -> node): a tap moves the price by the biggest bought
## that doesn't overshoot the target, $1 without.
const STEPS := {2: "consultant_step_2", 5: "consultant_step_5", 10: "consultant_step_10"}
## The projector node (EXPRESS ENGAGEMENT, after RETAINER) with which its hand crosses the desk
## EXPRESS_SPEED times as fast (its tap interval halves through the node's own `mul`).
const EXPRESS := "consultant_express"
const EXPRESS_SPEED := 2.0
## Fingertip distances off an arrow along the slate face's normal (FACE): hovering, and pressed.
## From the front, so the finger is not hidden behind the tilted slate.
const FACE := Vector3(0.0, 0.875, 0.485)
const HOVER := 0.1
const PRESS := 0.012
const REACH_SPEED := 1.2
const TAP_TIME := 0.09
const WOBBLE := 0.01
## A mid-grey suit (it must show against the dark wood), grey glove, a starched cuff.
const SUIT := Color(0.3, 0.31, 0.32)
const GLOVE := Color(0.5, 0.5, 0.49)
## Firmer than the interns' ghosts: it is billed, so it is seen.
const OPACITY := 0.6

@export var slate: PriceSlate

var _phase := Phase.AWAY
var _wait := 2.0
var _tip := ENTRY
var _step := 0
var _t := 0.0
var _tapped := false
var _time := 0.0
## What the switch's toggle and lamp show (on duty or not).
var _shown_on := true

@onready var _model: HandModel = $Hand
## The on/off switch lies on the desk right of the slate (price_slate.tscn).
@onready var _switch: CogSwitch = slate.get_node(^"ConsultantSwitch")
@onready var _sheet: MandateSheet = $Mandate/Sheet


func _ready() -> void:
	var material := SLEEVE.duplicate() as ShaderMaterial
	material.set_shader_parameter("sleeve", SUIT)
	material.set_shader_parameter("glove", GLOVE)
	material.set_shader_parameter("opacity", OPACITY)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	_model.size = SIZE
	# Turned to point right, in profile: it comes in from the left edge.
	rotation.y = -PI / 2.0
	_model.pose = HandModel.Pose.POINT
	_model.visible = false
	slate.player_rewrote.connect(_back_off)
	_switch.flicked.connect(_flick)
	_show_switch(false)


func _process(delta: float) -> void:
	var save := SaveManager.save
	if _switch.visible != save.stamped.has(CARD):
		_show_switch(false)
	elif _shown_on != save.consultant_on:
		_show_switch()
	if not save.stamped.has(CARD) or not save.slate_unlocked or not slate.visible:
		return
	if not save.consultant_on and _phase not in [Phase.AWAY, Phase.WITHDRAW]:
		_step = 0
		_phase = Phase.WITHDRAW
	_time += delta
	_wait -= delta
	match _phase:
		Phase.AWAY, Phase.HOVER:
			if _wait <= 0.0 and save.consultant_on:
				_decide(save)
		Phase.REACH:
			if _move(slate.arrow_at(_step) + FACE * HOVER, delta):
				_phase = Phase.TAP
				_tapped = false
				_t = 0.0
		Phase.TAP:
			_t += delta
			var down := slate.arrow_at(_step) + FACE * PRESS
			_tip = (slate.arrow_at(_step) + FACE * HOVER).lerp(down, sin(PI * minf(_t / (2.0 * TAP_TIME), 1.0)))
			if _t >= TAP_TIME and not _tapped:
				_tapped = true
				slate.nudge(_step)
			if _t >= 2.0 * TAP_TIME:
				_phase = Phase.HOVER
				_wait = save.consultant_interval
		Phase.WITHDRAW:
			if _move(ENTRY, delta):
				_phase = Phase.AWAY
				_model.visible = false
				return
	if _phase == Phase.AWAY:
		return
	var wobble := Vector3(sin(_time * 2.3), 0.4 * sin(_time * 3.1), cos(_time * 1.9)) * WOBBLE
	# HandModel offsets its anchor in its parent's space: undo this node's turn on that offset.
	var anchor: Vector3 = _model.basis * HandModel.ANCHORS[_model.pose]
	var tip := _tip + (wobble if _phase in [Phase.HOVER, Phase.REACH] else Vector3.ZERO)
	_model.move_to(tip + anchor - global_basis * anchor, delta)


## The price the consultant holds: the whole-dollar price whose refusals at the street's current
## mood come nearest save.consultant_bounce (the dearer on a tie), within the floor and ceiling, and
## never over squeeze_cap.
static func target_price(save: SaveGame) -> int:
	var ref := Slate.ref_price(save.marketing, Slate.street_mood(save))
	var want := save.consultant_bounce / 100.0
	var near := Slate.MIN_PRICE
	for price in range(Slate.MIN_PRICE, Slate.max_price(save.marketing) + 1):
		if absf(bounce(price, ref) - want) <= absf(bounce(near, ref) - want) + 0.0001:
			near = price
	return mini(clampi(near, save.consultant_floor, ceiling_of(save)), squeeze_cap(save))


## The share of cabbages the street refuses at `price` when `ref` is the full-sale price.
static func bounce(price: int, ref: float) -> float:
	return 1.0 - Slate.demand(price, ref)


## The ceiling the mandate sets: save.consultant_ceiling, or the slate's top when none is set (0).
static func ceiling_of(save: SaveGame) -> int:
	return Slate.max_price(save.marketing) if save.consultant_ceiling <= 0 else save.consultant_ceiling


## The mandate's refusals allowed after a stepper click `dir` (-1, 1): BOUNCE_STEP a click onto the
## next multiple of it, 0..BOUNCE_MAX (or the adopted share, if that is higher).
static func step_bounce(allowed: float, dir: int) -> float:
	return clampf(snappedf(allowed + dir * BOUNCE_STEP, BOUNCE_STEP), 0.0, maxf(BOUNCE_MAX, allowed))


## The player chalked the price by hand: it becomes the mandate. The refusals allowed are the share
## refused at that price at the current mood; the floor and ceiling widen to take it in, and a price
## under the dearest that sells every cabbage becomes the ceiling (else a share of 0 would raise it).
static func adopt(save: SaveGame) -> void:
	var price := save.sale_price
	save.consultant_bounce = 100.0 * bounce(price, Slate.ref_price(save.marketing, Slate.street_mood(save)))
	save.consultant_floor = mini(save.consultant_floor, price)
	if price > ceiling_of(save) or target_price(save) > price:
		save.consultant_ceiling = price


## The floor after a click `dir`: $1 a click, from the slate's lowest price up to the ceiling.
static func step_floor(save: SaveGame, dir: int) -> int:
	return clampi(save.consultant_floor + dir, Slate.MIN_PRICE, ceiling_of(save))


## The ceiling after a click `dir`: $1 a click, never under the floor; up past the slate's top it is
## none (0).
static func step_ceiling(save: SaveGame, dir: int) -> int:
	if save.consultant_ceiling <= 0 and dir > 0:
		return 0
	var at := ceiling_of(save) + dir
	return 0 if at > Slate.max_price(save.marketing) else maxi(at, save.consultant_floor)


## The dearest price the consultant ever sets: once the wholesalers' squeeze is on, the crate's unit
## cost (so crates never turn profitable and the standing order keeps out of the squeeze); else the slate's top.
static func squeeze_cap(save: SaveGame) -> int:
	var top := Slate.max_price(save.marketing)
	if not Console.squeezing(save):
		return top
	return clampi(floori(Console.crate_floor(save)), Slate.MIN_PRICE, top)


func _decide(save: SaveGame) -> void:
	var target := target_price(save)
	if target == save.sale_price:
		_wait = save.consultant_interval
		if _phase == Phase.HOVER:
			_phase = Phase.WITHDRAW
		return
	if _phase == Phase.AWAY:
		_tip = ENTRY
		_model.visible = true
	_step = tap(save, target)
	_phase = Phase.REACH


## The price change one tap makes toward `target`: the whole way with SMART bought, else the biggest
## step bought (STEPS, $1 without) that doesn't overshoot it.
static func tap(save: SaveGame, target: int) -> int:
	var gap := target - save.sale_price
	if save.tree_bought.has(SMART):
		return gap
	var step := 1
	for size: int in STEPS:
		if save.tree_bought.has(STEPS[size]) and size <= absi(gap):
			step = maxi(step, size)
	return signi(gap) * step


## The slate's switch was clicked: the mandate sheet opens (its duty switch sends the consultant away).
func _flick() -> void:
	_sheet.open()


## The switch shows once the card is stamped, up while the consultant is on.
func _show_switch(animate := true) -> void:
	var save := SaveManager.save
	_switch.visible = save.stamped.has(CARD)
	_switch.set_enabled(_switch.visible)
	_shown_on = save.consultant_on
	_switch.show_on(save.consultant_on, animate)


## A press (or a held arrow's repeat) on the slate: the price becomes the mandate (adopt) and a hand
## on its way withdraws; with nothing left to change it stays away until the mood moves.
func _back_off() -> void:
	if SaveManager.save.stamped.has(CARD):
		adopt(SaveManager.save)
	if _phase != Phase.AWAY:
		_step = 0
		_phase = Phase.WITHDRAW


## How fast the hand crosses the desk (m/s): REACH_SPEED, EXPRESS_SPEED times that with EXPRESS.
static func reach_speed(save: SaveGame) -> float:
	return REACH_SPEED * (EXPRESS_SPEED if save.tree_bought.has(EXPRESS) else 1.0)


## Moves the fingertip toward `to`; true once it is there.
func _move(to: Vector3, delta: float) -> bool:
	_tip = _tip.move_toward(to, reach_speed(SaveManager.save) * delta)
	return _tip.is_equal_approx(to)
