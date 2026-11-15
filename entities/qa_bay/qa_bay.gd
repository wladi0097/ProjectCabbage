class_name QaBay
extends Node3D
## Quality Assurance (card 5): an inspection cabinet in the left third of the window gap. A cabbage
## flicked into its open chamber is taken off the mat (one unit of stock) and sucked straight in
## through the back to the lab, a cold scan line sweeping across it left to right as it goes. The
## needle sweeps on for the rest of the save's qa_time, then it ejects a report slip (worth
## findings_per_cabbage) onto the desk in front. Sweeping the empty hand over a slip, like coins,
## sends it into the Findings counter, and only then are its Findings counted. While busy the
## front flap is up and shuts the mouth. Slides in from the street side once the card is stamped, the
## Findings drum row drops into the empty slot above the tally machine's money drums, and from then
## on the SaleWindow only sells through the other two thirds. With more benches (save.qa_slots) it takes
## a new unit while others are analysed; the flap only shuts once every bench is busy. Rotten units
## are refused: the chamber spits them back onto the mat (they are the bin's business). Units still
## being analysed and slips not filed yet are counted when the game quits. The coin vacuums leave
## slips alone. Findings have a limit (SaveGame.findings_limit): a finished cabbage only ejects
## the Findings that still fit beside the slips already out (CoinPile.fitting); the rest is lost and
## the counter reads FULL (TallyMachine.refuse; its buzzer only as it becomes full). A research unit yields research_mult times the Findings, a mini unit a share
## (findings_for); minis are no stock. The tube's research minis appear in the mouth as if thrown in,
## or are thrown back onto the mat when every bench is busy (file_direct). The load gauge on the
## Slips never tower: the desk in front is a grid of patches (SLIP_AREA, SLIP_CELL), each piled at
## most SLIP_REACH high; a slip goes to the patch nearest the mouth with room (slip_cell), so the
## piles spread out over the mat. With every patch full the rest of the Findings is held back
## (_backlog, still pending_findings, never lost), the busy lamp blinks, and it comes out as the
## fewest tokens as soon as slips are picked up. Slips left over a gap drop down (_restack).
## console, left of the busy lamp, is a row of jewel lamps under one chrome bezel, a socket for each of
## the lab's (at most) MAX_BENCHES benches: dark glass while its bench is free, cold cyan while a
## cabbage is on it, and no lens at all (a blanked-off socket) for a bench not bought yet.

const FLAP_TIME := 0.18
## Where the cabbage is sucked to (bay space, behind the back wall) and how long that takes; the
## scan head and its line cross the chamber from SCAN_X0 (bay x) by SCAN_RUN in the same time, its
## light on, then the head glides back in RETURN_TIME.
const SUCK_TO := Vector3(0.15, 0.08, -0.6)
const SUCK_TIME := 0.45
const SCAN_X0 := -0.04
const SCAN_RUN := 0.38
const RETURN_TIME := 0.8
## The console face's normal (bay and needle bone space): the needle turns about it.
const NEEDLE_AXIS := Vector3(0.0, 0.7615, 0.6481)
const LAMP_GLOW := 3.0
## A refused (rotten) unit is thrown back out of the mouth at this speed (bay space: out, up).
const SPIT := Vector2(1.6, 1.4)
## It arrives from this far out in the street.
const DELIVER_FROM := Vector3(0.0, 0.0, -0.6)
const DELIVER_TIME := 0.5
const COUNTER_DROP := 1.0
const COUNTER_DROP_TIME := 0.4
## Report slips: square bakelite Findings tokens (one mesh, a material per denomination, each
## template's scale sets its size and thickness), thrown out of the mouth onto this patch of desk
## (bay space, in front of the flap), arcing SLIP_LIFT high in SLIP_EJECT_TIME, then flying into the
## machine's hopper (the counter's Intake) exactly like a coin. A payout is split like coins
## (CoinPile.coin_values): the fewest ¶1, ¶5, ¶10, ¶50 and ¶100 tokens, a big one also ¶500, ¶1K,
## ¶5K and ¶10K tokens (¶500 and up carry a cold cyan rim), a huge one ¶100Ks drawn as the ¶10K.
## The template is the Slip<n> node of the value's tier (slip_template).
## SLIP_HALF is the token mesh's half thickness at scale 1. SLIP_AREA is cut into patches SLIP_CELL
## wide (7 x 6 of them, on the open mat where the hand and the coin robots reach); a patch is piled
## at most SLIP_REACH above the desk (three of the smallest tokens, one or two big ones), so no more
## than 126 slips ever lie out.
const SLIP_AREA := AABB(Vector3(-0.2, 0.0, 0.44), Vector3(0.7, 0.0, 0.6))
const SLIP_CELL := 0.1
## The desk the bay stands on and SLIP_AREA in front of it (bay space): coins keep clear of it
## (CoinPile.keep_clear), so none lands under the bay and none buries a slip.
const COIN_FREE := AABB(Vector3(-0.52, 0.0, -0.2), Vector3(1.02, 0.0, 1.24))
const SLIP_REACH := 0.05
const SLIP_LIFT := 0.18
const SLIP_EJECT_TIME := 0.45
const SLIP_HALF := 0.008
## Seconds between tries to eject held-back Findings, and the busy lamp's blink while there are some.
const SLIP_RETRY := 0.3
const BLINK := 0.5
const DESK_Y := 0.76
## MICRO-SAMPLE PROTOCOL (desk card micro_samples) multiplies a mini's share (save.mini_value) by
## this: two full units at the base share of 0.25, and the projector's mini value nodes still count.
const MICRO_SAMPLE := 8.0
## Jewel lamp sockets on the load gauge: the lab never has more benches.
const MAX_BENCHES := 5
## The projector node that lets the research light's boost count golden units too (boosted).
const LAB_GOLD := "lab_lamp_gold"
## The desk card that merges the Findings tokens lying on the desk like coins (CoinPile.merge_pick,
## save.merge_every, merge_top): they fly together over the first of them and the next token up
## pops out of the spot onto a patch with room.
const MERGE_CARD := "token_merge"

@export var window: SaleWindow
## Every Findings multiplier running now, by who set it (the research light: "lab_lamp"), applied to a
## unit as it is taken in (boosted).
var boosts := {}
@export var counter: Node3D
## The load gauge's jewel lenses: a free bench, a busy one.
@export var lamp_free: Material
@export var lamp_busy: Material

## Seconds each unit on a bench has been analysed, oldest first.
var _jobs: Array[float] = []
## Findings each unit on a bench will yield (findings_for), same order as _jobs.
var _yields: Array[int] = []
## Fractions of a Finding not yielded yet (minis are worth a share, tally).
var _owed := 0.0
## Slips out of the bay and not filed yet (on their way out, on the desk or homing); value in meta.
var _slips: Array[Node3D] = []
## Findings held back while the desk in front is full, and the seconds until the next try.
var _backlog := 0
var _retry := 0.0
var _time := 0.0
## The empty hand's point on the desk last frame (null while it holds something), as CoinPile's.
var _last_hand: Variant = null
## The end and mouse ray of the last stroke _sweep tested, and whether a slip has come to rest since.
var _swept_to := Vector3.INF
var _swept_rise := Vector3.ZERO
var _landed := false
## Seconds to the next merge (MERGE_CARD).
var _merge_in := 0.0
## What the load gauge shows: (cabbages on the benches, benches).
var _shown := Vector2i(-1, -1)
var _progress := 0.0
var _flap := 0.0
var _flapping: Tween
var _scanning: Tween
var _scan := 0.0:
	set(at):
		_scan = at
		$Scan.position.x = SCAN_X0 + at * SCAN_RUN
		_skeleton.set_bone_pose_position(_head_bone, _skeleton.get_bone_rest(_head_bone).origin + Vector3.RIGHT * at * SCAN_RUN)

@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _flap_bone := _skeleton.find_bone("Flap")
@onready var _needle_bone := _skeleton.find_bone("Needle")
@onready var _head_bone := _skeleton.find_bone("ScanHead")
@onready var _lamp: StandardMaterial3D = $BusyLamp.mesh.material
@onready var _gauge_lamps: Array[Node] = $Gauge/Lamps.get_children()
@onready var _rest := position
@onready var _counter_rest := counter.position


func _ready() -> void:
	add_to_group(&"qa_bay")
	$Chamber.body_entered.connect(_on_entered)
	SaveManager.closing.connect(_file_pending)
	SaveManager.pending_findings = unfiled
	$Scan.visible = false
	_scan = 0.0
	_lamp.emission_energy_multiplier = 0.0
	_pose()
	_show_load()
	if SaveManager.save.stamped.has("quality_assurance"):
		_claim_desk()
	else:
		visible = false
		counter.visible = false
		_set_physics(false)


func _process(delta: float) -> void:
	_show_load()
	if not visible:
		if SaveManager.save.stamped.has("quality_assurance"):
			_deliver()
		return
	if Hand.held == null:
		var now := Hand.point_on_height(DESK_Y)
		_sweep(CoinPile.stroke_start(_last_hand, now), now, Hand.point_on_height(DESK_Y + 1.0) - now)
		_last_hand = now
	else:
		_last_hand = null
	var save := SaveManager.save
	if save.stamped.has(MERGE_CARD):
		_merge_in -= delta
		if _merge_in <= 0.0:
			_merge_in = save.merge_every
			merge_once(save.merge_top)
	if _backlog > 0:
		_time += delta
		_retry -= delta
		if _retry <= 0.0:
			_retry = SLIP_RETRY
			_drop()
		_lamp.emission_energy_multiplier = LAMP_GLOW if _backlog > 0 and fmod(_time, BLINK) < BLINK * 0.5 \
				else LAMP_GLOW if _backlog == 0 and not _jobs.is_empty() else 0.0
	if _jobs.is_empty():
		return
	for i in _jobs.size():
		_jobs[i] += delta
	# The needle shows the oldest unit's analysis.
	_progress = minf(_jobs[0] / SaveManager.save.qa_time, 1.0)
	_pose()
	if _progress >= 1.0:
		_finish()


## The load gauge follows the benches: a lens in the socket of every bench bought, lit while busy;
## the sockets stay put, so a new bench only fills the next blanked-off one. Only redrawn when a
## cabbage comes or goes or a bench is added.
func _show_load() -> void:
	var now := Vector2i(_jobs.size(), SaveManager.save.qa_slots)
	if now == _shown:
		return
	_shown = now
	for i in _gauge_lamps.size():
		var lamp := _gauge_lamps[i] as MeshInstance3D
		lamp.visible = i < now.y
		lamp.set_surface_override_material(0, lamp_busy if i < now.x else lamp_free)


## A bench is free (and the bay is in): a unit flicked or lobbed in now is taken.
func has_room() -> bool:
	return visible and _jobs.size() < SaveManager.save.qa_slots


## The middle of the chamber's mouth (world), where the hired hands aim.
func mouth() -> Vector3:
	return $Chamber/Shape.global_position


func _on_entered(body: Node3D) -> void:
	var cabbage := body as Cabbage
	if not has_room() or cabbage == null or cabbage.sold or cabbage.away:
		return
	if cabbage.rotten:
		cabbage.linear_velocity = global_basis.z * SPIT.x + Vector3.UP * SPIT.y
		$FlapShut.cue(cabbage.global_position)
		return
	_admit(cabbage)


## A unit taken onto a free bench: sucked in through the back, scanned, a slip once qa_time is up.
func _admit(cabbage: Cabbage) -> void:
	_jobs.append(0.0)
	_yields.append(_take(cabbage))
	# Off the mat for good: the feeder rolls the next one in while this one is analysed.
	cabbage.suck_out(to_global(SUCK_TO), SUCK_TIME)
	$Out.cue(cabbage.global_position)
	if not has_room():
		_swing_flap(1.0)
	_lamp.emission_energy_multiplier = LAMP_GLOW
	$ScanSound.cue($Scan.global_position)
	$Scan.visible = true
	if _scanning != null:
		_scanning.kill()
	_scanning = create_tween()
	var scan := _scanning
	scan.tween_property(self, "_scan", 1.0, SUCK_TIME)
	scan.tween_callback($Scan.hide)
	scan.tween_property(self, "_scan", 0.0, RETURN_TIME).set_trans(Tween.TRANS_SINE)


## Findings one analysed unit is worth: a golden unit golden_lab times findings_per_cabbage, a research unit research_mult times findings_per_cabbage,
## a mini mini_value of it (MICRO-SAMPLE PROTOCOL, micro_samples: MICRO_SAMPLE times that), any other
## findings_per_cabbage. A mini's share is exact, not rounded: _take tallies the fractions. Flicked in
## by the player themself (Cabbage.by_player: no lab hand, not the tube), all of it times
## save.own_lab (managerial work), fractions tallied the same way. A condensed cabbage
## (Cabbage.units) is worth each cabbage it holds.
static func findings_for(cabbage: Cabbage, save: SaveGame) -> float:
	var own := (save.own_lab if cabbage.by_player() else 1.0) * cabbage.units
	if cabbage.golden:
		return roundf(save.findings_per_cabbage * save.golden_lab) * own
	if cabbage.research:
		return roundf(save.findings_per_cabbage * save.research_mult) * own
	if cabbage.mini:
		var share := save.mini_value * (MICRO_SAMPLE if save.stamped.has("micro_samples") else 1.0)
		return save.findings_per_cabbage * share * own
	return save.findings_per_cabbage * own


## `worth` Findings times every factor in `factors`, except that a golden unit skips them until the
## projector node LAB_GOLD is bought (like the golden lamp's GOLD STANDARD at the window).
static func boosted(worth: float, is_golden: bool, factors: Dictionary, save: SaveGame) -> float:
	if is_golden and not save.tree_bought.has(LAB_GOLD):
		return worth
	for factor: float in factors.values():
		worth *= factor
	return worth


## The whole Findings a unit worth `worth` yields with `owed` already on the tally, and the tally
## after it: [whole, owed]. Like SaleWindow's owed coins, fractions carry over to the next unit.
static func tally(owed: float, worth: float) -> Array:
	var total := owed + worth
	# The epsilon keeps 3 × 0.333.. from landing a hair under 1.
	var whole := floori(total + 0.0001)
	return [whole, maxf(total - whole, 0.0)]


## A unit taken in: off the stock (minis and grown ones are none), counted if research. Returns its
## whole Findings (a mini's fraction waits on _owed).
func _take(cabbage: Cabbage) -> int:
	var save := SaveManager.save
	cabbage.leave_stock(save)
	if cabbage.research:
		save.research_units += cabbage.units
	save.golden_analysed += cabbage.units * int(cabbage.golden)
	var counted := tally(_owed, boosted(findings_for(cabbage, save), cabbage.golden, boosts, save))
	_owed = counted[1]
	return counted[0]


## Delivered by the tube (hidden, frozen, out of the physics): it appears in the chamber's mouth and
## is taken like one thrown in. With every bench busy the street throws it back onto the mat, as
## after a refused sale (hidden until thrown: throw_in shows it).
func file_direct(cabbage: Cabbage) -> void:
	cabbage.global_position = mouth()
	if has_room():
		cabbage.visible = true
		_admit(cabbage)
		return
	cabbage.away = true
	window._send_back(cabbage, 0.0)


func _finish() -> void:
	_jobs.pop_front()
	_eject(_yields.pop_front())
	$Done.cue($Done.global_position)
	if not _jobs.is_empty():
		# A bench came free: the flap opens again, the lamp stays on.
		if _flap > 0.0:
			_swing_flap(0.0)
		return
	_lamp.emission_energy_multiplier = 0.0
	var reset := create_tween()
	reset.tween_method(func(p: float) -> void:
		_progress = p
		_pose(), 1.0, 0.0, FLAP_TIME * 2.0)
	reset.tween_callback(_swing_flap.bind(0.0))


## Quitting: the units on the benches and the slips not filed yet yield their Findings now (what
## fits under the limit, SaveGame.earn).
func _file_pending() -> void:
	_earn(unfiled())
	_backlog = 0
	_jobs.clear()
	_yields.clear()
	for slip in _slips:
		slip.queue_free()
	_slips.clear()


## Files `amount` Findings: what fits under the limit comes in and counts as earned (as coins:
## CoinPile.bank), the rest is lost.
func _earn(amount: int) -> void:
	var save := SaveManager.save
	save.findings_earned += save.earn(&"findings", amount)


## Every Finding not in the save yet: the units on the benches, the slips out and those held back.
## The autosave writes them into the file (SaveManager.pending_findings), quitting files them.
func unfiled() -> int:
	var total := pending_findings()
	for amount: int in _yields:
		total += amount
	return total


## Findings in slips not filed yet, and those held back while the desk is full.
func pending_findings() -> int:
	var total := _backlog
	for slip in _slips:
		total += slip.get_meta(&"value")
	return total


## A finished unit's report slips (`amount` split like coins, CoinPile.coin_values) fly out onto the desk in front:
## only what the Findings counter still has room for beside the slips already out. The rest is lost.
## What the desk in front has no room for is held back (_drop).
func _eject(amount: int) -> void:
	var fits := CoinPile.fitting(amount, SaveManager.save.room(&"findings"), pending_findings())
	var machine := counter as TallyMachine
	if fits < amount:  # Less fits than was due: the slip jams at the slot (rate-limited on the cue).
		$SlipJam.cue(to_global(Vector3(0.15, 0.08, 0.15)))
	if fits < amount and machine != null:
		machine.refuse()
	_backlog += fits
	_drop()


## Ejects what is held back, as the fewest tokens (smallest first), until one finds no patch with room.
func _drop() -> void:
	var piles := _piles()
	var delay := 0.0
	for value in CoinPile.coin_values(_backlog):
		var thick := SLIP_HALF * 2.0 * (get_node(slip_template(value)) as Node3D).scale.y
		var cell: Variant = slip_cell(piles, thick)
		if cell == null:
			return
		_eject_slip(value, delay, cell, piles.get(cell, 0.0))
		piles[cell] = piles.get(cell, 0.0) + thick
		_backlog -= value
		delay += CoinPile.THROW_STAGGER * 2.0


## How high each patch of the desk is piled (m): the slips lying on it and on their way to it.
func _piles() -> Dictionary:
	var piles := {}
	for slip in _slips:
		if slip.has_meta(&"cell"):
			piles[slip.get_meta(&"cell")] = piles.get(slip.get_meta(&"cell"), 0.0) + slip.get_meta(&"thick")
	return piles


## The patch a token `thick` thick lands on: the one nearest the mouth (the middle of the first row)
## whose pile (`piles`, patch -> height) stays within SLIP_REACH with it. Null when none has room.
static func slip_cell(piles: Dictionary, thick: float) -> Variant:
	var size := slip_cells()
	var best: Variant = null
	var nearest := INF
	for x in size.x:
		for z in size.y:
			var away := Vector2(x + 0.5 - size.x * 0.5, z).length_squared()
			if away < nearest and piles.get(Vector2i(x, z), 0.0) + thick <= SLIP_REACH + 0.0001:
				nearest = away
				best = Vector2i(x, z)
	return best


## How many patches SLIP_AREA has, across and out from the bay.
static func slip_cells() -> Vector2i:
	return Vector2i(roundi(SLIP_AREA.size.x / SLIP_CELL), roundi(SLIP_AREA.size.z / SLIP_CELL))


## The token a slip worth `value` is drawn as: its tier's Slip<n> (¶100K and up look like ¶10K).
static func slip_template(value: int) -> String:
	return "Slip%d" % CoinPile.DENOMINATIONS[CoinPile.tier(value)]


## One merge, if the resting tokens hold one (CoinPile.merge_pick, newest first): they leave their
## patches (the tokens above drop down), wobble once (CoinPile.shake_offset) and fly together over the
## first of them, and the merged token
## pops out of that spot onto the patch nearest the bay with room (or, with none, waits in the backlog).
## True if any.
func merge_once(top: int) -> bool:
	var resting: Array[Node3D] = []
	var values: Array[int] = []
	for i in range(_slips.size() - 1, -1, -1):
		if _slips[i].get_meta(&"resting") and _slips[i].has_meta(&"cell"):
			resting.append(_slips[i])
			values.append(_slips[i].get_meta(&"value"))
	var pick := CoinPile.merge_pick(values, top)
	if pick.is_empty():
		return false
	var group: Array[Node3D] = []
	for at in pick:
		group.append(resting[at])
		resting[at].set_meta(&"resting", false)
		resting[at].remove_meta(&"cell")
	_restack()
	var spot := group[0].global_position + Vector3.UP * CoinPile.MERGE_LIFT
	var value := values[pick[0]] * pick.size()
	var tween := create_tween().set_parallel()
	for slip in group:
		var rest := slip.global_position
		tween.tween_method(func(t: float) -> void:
			slip.global_position = rest + CoinPile.shake_offset(t),
			0.0, 1.0, CoinPile.MERGE_SHAKE)
	tween.chain()
	for slip in group:
		var from := slip.global_position
		tween.tween_method(func(t: float) -> void:
			slip.global_position = from.lerp(spot, ease(t, 2.0)) + Vector3.UP * CoinPile.MERGE_LIFT * 4.0 * t * (1.0 - t),
			0.0, 1.0, CoinPile.MERGE_TIME)
	tween.chain().tween_callback(_merged.bind(group, value, spot))
	return true


## The tokens of a merge have met at `spot`: they go, and one token worth `value` pops out of there.
func _merged(group: Array[Node3D], value: int, spot: Vector3) -> void:
	if not _slips.has(group[0]):
		return  # Filed already: the game quit mid-merge (_file_pending).
	for slip in group:
		_slips.erase(slip)
		slip.queue_free()
	var thick := SLIP_HALF * 2.0 * (get_node(slip_template(value)) as Node3D).scale.y
	var piles := _piles()
	var cell: Variant = slip_cell(piles, thick)
	if cell == null:
		_backlog += value
		return
	_eject_slip(value, 0.0, cell, piles.get(cell, 0.0), spot)


## A slip worth `value` flies out onto patch `cell`, on top of the `below` m already piled there:
## out of the bay's slot, or popped out of `from` (a merge, swelling as it goes).
func _eject_slip(value: int, delay: float, cell: Vector2i, below: float, from := Vector3.INF) -> void:
	var slip: Node3D = get_node(slip_template(value)).duplicate()
	var size := Basis.from_scale(slip.scale)
	slip.top_level = true
	slip.set_meta(&"value", value)
	slip.set_meta(&"resting", false)
	slip.set_meta(&"cell", cell)
	slip.set_meta(&"thick", SLIP_HALF * 2.0 * slip.scale.y)
	add_child(slip)
	_slips.append(slip)
	var popped := from != Vector3.INF
	if not popped:
		from = to_global(Vector3(0.15, 0.08, 0.15))
	# Loosely on its patch (a small token has room to sit off centre).
	var loose := maxf(SLIP_CELL - 0.085 * slip.scale.x, 0.0) * 0.5
	var spot := to_global(SLIP_AREA.position + Vector3(cell.x + 0.5, 0.0, cell.y + 0.5) * SLIP_CELL
			+ Vector3(randf_range(-loose, loose), 0.0, randf_range(-loose, loose)))
	spot.y = DESK_Y + below + SLIP_HALF * slip.scale.y
	var turn := randf_range(-0.6, 0.6)
	slip.global_position = from
	slip.visible = false
	var tween := slip.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(slip.show)
	tween.tween_method(func(t: float) -> void:
		slip.global_position = from.lerp(spot, t) + Vector3.UP * SLIP_LIFT * 4.0 * t * (1.0 - t)
		var swell := CoinPile.pop_scale(CoinPile.MERGE_POP * (1.0 - t)) if popped else 1.0
		slip.global_basis = global_basis * Basis(Vector3.UP, turn * t) * Basis(Vector3.RIGHT, TAU * (1.0 - t)) * size * swell,
		0.0, 1.0, SLIP_EJECT_TIME)
	tween.tween_callback(_settle_slip.bind(slip))


## A slip lands on the desk: from now on the hand and the vacuums can take it.
func _settle_slip(slip: Node3D) -> void:
	slip.set_meta(&"resting", true)
	_landed = true
	_restack()
	$SlipLand.cue(slip.global_position)


## Resting slips under the empty hand's stroke (CoinPile._sweep) fly into the Findings counter,
## the top of the pile (the newest) first.
func _sweep(from: Vector3, to: Vector3, rise: Vector3) -> void:
	# Nothing new to find: no slips, or the hand still where it was tested last and none came to rest since.
	if _slips.is_empty() or (from == to and to == _swept_to and rise == _swept_rise and not _landed):
		return
	_swept_to = to
	_swept_rise = rise
	_landed = false
	var taken: Array[Node3D] = []
	# ponytail: every slip (a few dozen at most, ~0.03 ms); a grid like CoinPile's if they ever pile up in hundreds.
	for i in range(_slips.size() - 1, -1, -1):
		var slip := _slips[i]
		if slip.get_meta(&"resting") and CoinPile.under_hand(from, to, rise, slip.global_position, slip.global_position):
			slip.set_meta(&"resting", false)
			slip.remove_meta(&"cell")
			taken.append(slip)
	for i in taken.size():
		_home(taken[i], CoinPile.home_delay(i, taken.size()))
	if not taken.is_empty():
		_restack()


## The slips resting on each patch lie on the desk and on each other, oldest lowest: one whose
## neighbours below were taken drops onto what is left.
func _restack() -> void:
	var piles := {}
	for slip in _slips:
		if not slip.has_meta(&"cell") or not slip.get_meta(&"resting"):
			continue
		var cell: Vector2i = slip.get_meta(&"cell")
		var thick: float = slip.get_meta(&"thick")
		slip.global_position.y = DESK_Y + piles.get(cell, 0.0) + thick * 0.5
		piles[cell] = piles.get(cell, 0.0) + thick


## Where the slips lying on the desk are (the coin vacuums' goals once token_recovery is stamped).
func resting_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for slip in _slips:
		if slip.get_meta(&"resting"):
			out.append(slip.global_position)
	return out


## A coin vacuum at `point` sucks up the resting slips within `reach`, at most `room` of them: they
## vanish into its bag and are returned, still unfiled (pending_findings counts them).
func vacuum_at(point: Vector3, reach: float, room: int) -> Array[Node3D]:
	var got: Array[Node3D] = []
	for slip in _slips:
		if got.size() < room and slip.get_meta(&"resting") and Vector2(slip.global_position.x - point.x, slip.global_position.z - point.z).length() <= reach:
			slip.set_meta(&"resting", false)
			slip.remove_meta(&"cell")
			slip.hide()
			got.append(slip)
	if not got.is_empty():
		_restack()
	return got


## A coin vacuum empties its bag at `point`: the slips fly from there into the Findings counter, one
## by one, or the whole bag at once with `bulk` (CoinPile.bag_delay).
func file_from(slips: Array[Node3D], point: Vector3, bulk := false) -> void:
	for i in slips.size():
		if not is_instance_valid(slips[i]):
			continue  # Filed already: the game quit while it was in the bag.
		slips[i].global_position = point
		slips[i].show()
		_home(slips[i], CoinPile.bag_delay(i, slips.size(), bulk))


func _home(slip: Node3D, delay: float) -> void:
	var from := slip.global_position
	var start := slip.global_basis
	var intake: Node3D = counter.get_node("Intake")
	var tween := slip.create_tween()
	tween.tween_interval(delay)
	# findings_slip_* is a flutter with the hopper's clack at 0.5 s, when the slip drops in.
	tween.tween_callback(func() -> void: $SlipFiled.cue(intake.global_position))
	# The coins' flight (CoinPile._home): up, over the hopper, straight down into it, spinning,
	# shrinking only inside the funnel.
	tween.tween_method(func(t: float) -> void:
		slip.global_position = CoinPile.home_point(from, intake.global_position, t * t)
		slip.global_basis = (Basis(Vector3.RIGHT, t * CoinPile.HOME_TIME * 18.0) * start).orthonormalized() 				.scaled(Vector3.ONE * maxf(1.0 - smoothstep(0.88, 1.0, t), 0.01)),
		0.0, 1.0, CoinPile.HOME_TIME)
	tween.tween_callback(_file.bind(slip))


func _file(slip: Node3D) -> void:
	_slips.erase(slip)
	_earn(slip.get_meta(&"value"))
	slip.queue_free()


## Slides in through the gap from the street side; the window gives up its left third once it is in.
func _deliver() -> void:
	visible = true
	position = _rest + DELIVER_FROM
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DELIVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_set_physics(true)
		_claim_desk()
		$Thud.cue(global_position))
	counter.visible = true
	counter.position = _counter_rest + Vector3.UP * COUNTER_DROP
	tween.tween_property(counter, "position", _counter_rest, COUNTER_DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Thud.cue(counter.global_position))


## The bay is in: the window gives up its left third, the coins the desk under and in front of it.
func _claim_desk() -> void:
	window.split()
	if window.coins != null:
		window.coins.keep_clear = CoinPile.cells_in(to_global(COIN_FREE.position), to_global(COIN_FREE.end))


func _set_physics(on: bool) -> void:
	for shape: CollisionShape3D in $Body.get_children():
		shape.disabled = not on
	$Chamber/Shape.disabled = not on


func _swing_flap(to: float) -> void:
	if _flapping != null:
		_flapping.kill()
	$Shut/Shape.disabled = to == 0.0
	_flapping = create_tween()
	_flapping.tween_method(func(f: float) -> void:
		_flap = f
		_pose(), _flap, to, FLAP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var clank: SoundCue = $FlapShut if to > 0.0 else $FlapOpen
	_flapping.tween_callback(clank.cue.bind(clank.global_position))


func _pose() -> void:
	_skeleton.set_bone_pose_rotation(_flap_bone, Quaternion(Vector3.RIGHT, flap_angle(_flap))
			* _skeleton.get_bone_rest(_flap_bone).basis.get_rotation_quaternion())
	_skeleton.set_bone_pose_rotation(_needle_bone, Quaternion(NEEDLE_AXIS, PriceSlate.needle_angle(_progress))
			* _skeleton.get_bone_rest(_needle_bone).basis.get_rotation_quaternion())


## The flap's turn about the hinge: 0 lies flat in front as a lip, 1 stands up and shuts the mouth.
static func flap_angle(up: float) -> float:
	return -PI / 2.0 * up
