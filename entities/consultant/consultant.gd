class_name Consultant
extends Node3D
## The pricing consultant (desk card "pricing_consultant"): a ghost hand in a grey suit sleeve.
## Every save.consultant_interval seconds it checks the slate against its target price
## (target_price) and, if they differ, reaches in from the left screen edge and taps the arrow one
## step toward it, then hovers by the slate for the next tap. On target it withdraws off screen.
## The player outranks it: after a press on the slate it backs off for PLAYER_PAUSE seconds.
## save.consultant_skill: 0 aims at the textbook full-sale price (mood ignored, every unit sells at
## a normal mood), 1 reads the street's mood, 2 aims at the best income per unit after pack costs
## and, with hired hands, throttles: while no unit waits on the mat (the hands are starved, supply is
## the limit) it asks a step more each time, up to THROTTLE × the full-sale price, and gives a step
## back whenever one waits.

enum Phase { AWAY, REACH, TAP, HOVER, WITHDRAW }

const Slate := preload("res://entities/price_slate/price_slate.gd")
const Console := preload("res://entities/supply_console/supply_console.gd")
const SLEEVE := preload("res://assets/materials/associate_hand.tres")
const CARD := "pricing_consultant"
## Off screen past the left edge, at the slate's depth.
const ENTRY := Vector3(-2.6, 1.25, -0.3)
const SIZE := 0.9
const PLAYER_PAUSE := 15.0
const THROTTLE := 1.6
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
## Steps above target_price while throttling (skill 2).
var _extra := 0

@onready var _model: HandModel = $Hand


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


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.stamped.has(CARD) or not save.slate_unlocked or not slate.visible:
		return
	_time += delta
	_wait -= delta
	match _phase:
		Phase.AWAY, Phase.HOVER:
			if _wait <= 0.0:
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


## The price the consultant steers toward, for `skill` (see the class notes).
static func target_price(save: SaveGame, skill: int) -> int:
	var ref := Slate.ref_price(save.marketing, save.demand_mood if skill >= 1 else 1.0)
	var top := Slate.max_price(save.marketing)
	if skill < 2:
		return clampi(floori(ref + 0.0001), Slate.MIN_PRICE, top)
	var cost := Console.pack_price(save.price_factor, save.pack_size, save.pack_discount) / float(save.pack_size)
	var best := Slate.MIN_PRICE
	for price in range(Slate.MIN_PRICE, top + 1):
		if income(price, ref, cost) > income(best, ref, cost) + 0.0001:
			best = price
	return best


## The throttle's steps above the `base` target after one decision: up while nothing `waiting`, at
## most to THROTTLE × `ref`, down one when something waits.
static func throttle(extra: int, waiting: bool, base: int, ref: float) -> int:
	if waiting:
		return maxi(extra - 1, 0)
	return clampi(extra + 1, 0, maxi(ceili(ref * THROTTLE) - base, 0))


## Coins per unit offered at `price` (sold with the street's chance) after the unit's `cost`.
static func income(price: int, ref: float, cost: float) -> float:
	return Slate.demand(price, ref) * (price - cost)


func _decide(save: SaveGame) -> void:
	var target := target_price(save, save.consultant_skill)
	if save.consultant_skill >= 2 and save.hands > 0:
		var waiting := Associate.pick_target(get_tree().get_nodes_in_group(&"cabbages"), Vector3.ZERO, Hand.held) != null
		_extra = throttle(_extra, waiting, target, Slate.ref_price(save.marketing, save.demand_mood))
		target = mini(target + _extra, Slate.max_price(save.marketing))
	if target == save.sale_price:
		_wait = save.consultant_interval
		if _phase == Phase.HOVER:
			_phase = Phase.WITHDRAW
		return
	if _phase == Phase.AWAY:
		_tip = ENTRY
		_model.visible = true
	_step = signi(target - save.sale_price)
	_phase = Phase.REACH


func _back_off() -> void:
	_wait = PLAYER_PAUSE
	if _phase != Phase.AWAY:
		_step = 0
		_phase = Phase.WITHDRAW


## Moves the fingertip toward `to`; true once it is there.
func _move(to: Vector3, delta: float) -> bool:
	_tip = _tip.move_toward(to, REACH_SPEED * delta)
	return _tip.is_equal_approx(to)
