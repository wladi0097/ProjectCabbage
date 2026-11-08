class_name Consultant
extends Node3D
## The pricing consultant (desk card "pricing_consultant"): a ghost hand in a grey suit sleeve.
## Every save.consultant_interval seconds it checks the slate against its target price
## (target_price) and, if they differ, reaches in from the left screen edge and taps the arrow one
## step toward it, then hovers by the slate for the next tap. On target it withdraws off screen.
## The player outranks it: after a press on the slate it backs off for PLAYER_PAUSE seconds.
## save.consultant_skill: 0 aims at the price the street accepts about TARGET_ACCEPTANCE of the time
## at a normal mood (most units sell, a few are refused), 1 the same with the street's mood read,
## 2 aims at the best income per unit after pack costs
## and, with hired hands, throttles: while no unit waits on the mat (the hands are starved, supply is
## the limit) it asks a step more each time, up to THROTTLE × the full-sale price, and gives a step
## back whenever one waits. Not while the player's markup (below) stands.
## The player's word stands: each player step on the slate records how far over (or under) the
## consultant's own target the price now is (save.consultant_markup), and from then on it aims that far
## over its target as the target moves (aim). Left on its target, the markup is 0 again.
## A light switch on the slate's frame (there once the card is stamped) sends it away or back
## (save.consultant_on).

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
## Skills 0 and 1 keep the street's acceptance as near this as whole-dollar prices allow.
const TARGET_ACCEPTANCE := 0.9
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
## The on/off switch lies on the desk right of the slate (price_slate.tscn).
@onready var _switch: LightSwitch = slate.get_node(^"ConsultantSwitch")


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


## The price the consultant steers toward, for `skill` (see the class notes).
static func target_price(save: SaveGame, skill: int) -> int:
	var ref := Slate.ref_price(save.marketing, save.demand_mood if skill >= 1 else 1.0)
	var top := Slate.max_price(save.marketing)
	if skill < 2:
		var near := Slate.MIN_PRICE
		for price in range(Slate.MIN_PRICE, top + 1):
			if absf(Slate.demand(price, ref) - TARGET_ACCEPTANCE) < absf(Slate.demand(near, ref) - TARGET_ACCEPTANCE) - 0.0001:
				near = price
		return near
	# Stage 2 crates cost more (crate_floor); during the wholesalers' squeeze (before its ease) none are
	# bought (the farm feeds the desk).
	var least := 0.0 if save.squeeze_left > Console.LULL_TIME else Console.crate_floor(save)
	var cost := Console.pack_price(save.price_factor, save.pack_size, save.pack_discount, Console.UNIT_COST, least) / float(save.pack_size)
	var best := Slate.MIN_PRICE
	for price in range(Slate.MIN_PRICE, top + 1):
		if income(price, ref, cost) > income(best, ref, cost) + 0.0001:
			best = price
	return best


## Where the consultant actually steers: its target_price, save.consultant_markup over it, on the slate.
static func aim(save: SaveGame, skill: int) -> int:
	return clampi(roundi(target_price(save, skill) * (1.0 + save.consultant_markup)), Slate.MIN_PRICE, Slate.max_price(save.marketing))


## The markup the player set: how far `price` lies over the consultant's `target` (0.2 is 20% over).
static func markup(price: int, target: int) -> float:
	return float(price) / target - 1.0


## The throttle's steps above the `base` target after one decision: up while nothing `waiting`, at
## most to THROTTLE × `ref`, down one when something waits.
static func throttle(extra: int, waiting: bool, base: int, ref: float) -> int:
	if waiting:
		return maxi(extra - 1, 0)
	return clampi(extra + 1, 0, maxi(ceili(ref * THROTTLE) - base, 0))


## Skill 2 with hired hands throttles, unless the player set a markup: their price stands as set,
## so a step down on the slate never comes back as a dearer price.
static func throttles(save: SaveGame) -> bool:
	return save.consultant_skill >= 2 and save.hands > 0 and is_zero_approx(save.consultant_markup)


## Coins per unit offered at `price` (sold with the street's chance) after the unit's `cost`.
static func income(price: int, ref: float, cost: float) -> float:
	return Slate.demand(price, ref) * (price - cost)


func _decide(save: SaveGame) -> void:
	var target := aim(save, save.consultant_skill)
	if throttles(save):
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


## The slate's switch was flicked: the consultant is sent away or called back.
func _flick() -> void:
	SaveManager.save.consultant_on = not SaveManager.save.consultant_on
	_show_switch()


## The switch shows once the card is stamped, up while the consultant is on.
func _show_switch(animate := true) -> void:
	var save := SaveManager.save
	_switch.visible = save.stamped.has(CARD)
	_switch.set_enabled(_switch.visible)
	_switch.show_on(save.consultant_on, animate)


func _back_off() -> void:
	_wait = PLAYER_PAUSE
	_extra = 0
	var save := SaveManager.save
	# Before it is retained the player's pricing is no brief: it starts from its own target.
	if save.stamped.has(CARD):
		save.consultant_markup = markup(save.sale_price, target_price(save, save.consultant_skill))
	if _phase != Phase.AWAY:
		_step = 0
		_phase = Phase.WITHDRAW


## Moves the fingertip toward `to`; true once it is there.
func _move(to: Vector3, delta: float) -> bool:
	_tip = _tip.move_toward(to, REACH_SPEED * delta)
	return _tip.is_equal_approx(to)
