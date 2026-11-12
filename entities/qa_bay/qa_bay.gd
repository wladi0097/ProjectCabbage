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
## slips alone. A research unit yields research_mult times the Findings, a mini unit a share
## (findings_for); minis are no stock. The tube's research minis appear in the mouth as if thrown in,
## or are thrown back onto the mat when every bench is busy (file_direct). The load gauge on the
## console, left of the busy lamp, shows one cell per bench (lit while a cabbage is on it) and the
## count beside it ("1/3").

const FLAP_TIME := 0.18
## Where the cabbage is sucked to (bay space, behind the back wall) and how long that takes; the
## scan head and its line cross the chamber from SCAN_X0 (bay x) by SCAN_RUN in the same time, its
## light on, then the head glides back in RETURN_TIME.
const SUCK_TO := Vector3(0.135, 0.08, -0.6)
const SUCK_TIME := 0.45
const SCAN_X0 := -0.04
const SCAN_RUN := 0.35
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
## machine's hopper (the counter's Intake) exactly like a coin. A payout comes as the fewest ¶1, ¶5
## and ¶10 tokens (CoinPile.coin_values: a huge one as ¶100s and up, drawn as the ¶10 token like coins).
## SLIP_HALF is the token mesh's half thickness at scale 1; layers stack SLIP_LAYER apart.
const SLIP_AREA := AABB(Vector3(-0.1, 0.0, 0.46), Vector3(0.47, 0.0, 0.16))
const SLIP_LIFT := 0.18
## Slips land side by side, this many in a row.
const SLIP_ROW := 3
const SLIP_EJECT_TIME := 0.45
const SLIP_HALF := 0.008
const SLIP_LAYER := 0.022
const DESK_Y := 0.76
## MICRO-SAMPLE PROTOCOL (desk card micro_samples): a mini is read as this many full units.
const MICRO_SAMPLE := 2.0
## The load gauge's count: a dim grey-cyan while a bench is free, bright once every bench is busy.
const GAUGE_FREE := Color(0.45, 0.68, 0.74)
const GAUGE_FULL := Color(0.8, 1.0, 1.0)

@export var window: SaleWindow
@export var counter: Node3D

## Seconds each unit on a bench has been analysed, oldest first.
var _jobs: Array[float] = []
## Findings each unit on a bench will yield (findings_for), same order as _jobs.
var _yields: Array[int] = []
## Fractions of a Finding not yielded yet (minis are worth a share, tally).
var _owed := 0.0
## Slips out of the bay and not filed yet (on their way out, on the desk or homing); value in meta.
var _slips: Array[Node3D] = []
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
@onready var _gauge_cells: MeshInstance3D = $Gauge/Cells
@onready var _gauge_count: Label3D = $Gauge/Count
@onready var _rest := position
@onready var _counter_rest := counter.position


func _ready() -> void:
	add_to_group(&"qa_bay")
	$Chamber.body_entered.connect(_on_entered)
	SaveManager.closing.connect(_file_pending)
	$Scan.visible = false
	_scan = 0.0
	_lamp.emission_energy_multiplier = 0.0
	_pose()
	_show_load()
	if SaveManager.save.stamped.has("quality_assurance"):
		window.split()
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
		_sweep(Hand.point_on_height(DESK_Y))
	if _jobs.is_empty():
		return
	for i in _jobs.size():
		_jobs[i] += delta
	# The needle shows the oldest unit's analysis.
	_progress = minf(_jobs[0] / SaveManager.save.qa_time, 1.0)
	_pose()
	if _progress >= 1.0:
		_finish()


## The load gauge follows the benches: every bench a cell, the busy ones lit, the count beside them.
## Only redrawn when a cabbage comes or goes or a bench is added.
func _show_load() -> void:
	var now := Vector2i(_jobs.size(), SaveManager.save.qa_slots)
	if now == _shown:
		return
	_shown = now
	_gauge_cells.set_instance_shader_parameter(&"filled", float(now.x))
	_gauge_cells.set_instance_shader_parameter(&"cells", float(now.y))
	_gauge_count.text = load_text(now.x, now.y)
	_gauge_count.modulate = GAUGE_FULL if now.x >= now.y else GAUGE_FREE


## The gauge's count: cabbages on the benches / benches.
static func load_text(busy: int, benches: int) -> String:
	return "%d/%d" % [busy, benches]


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
## a mini mini_value of it (MICRO-SAMPLE PROTOCOL, micro_samples: MICRO_SAMPLE times it), any other
## findings_per_cabbage. A mini's share is exact, not rounded: _take tallies the fractions. Flicked in
## by the player themself (Cabbage.by_player: no lab hand, not the tube), all of it times
## save.own_lab (managerial work), fractions tallied the same way.
static func findings_for(cabbage: Cabbage, save: SaveGame) -> float:
	var own := save.own_lab if cabbage.by_player() else 1.0
	if cabbage.golden:
		return roundf(save.findings_per_cabbage * save.golden_lab) * own
	if cabbage.research:
		return roundf(save.findings_per_cabbage * save.research_mult) * own
	if cabbage.mini:
		var share := MICRO_SAMPLE if save.stamped.has("micro_samples") else save.mini_value
		return save.findings_per_cabbage * share * own
	return save.findings_per_cabbage * own


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
		save.research_units += 1
	save.golden_analysed += int(cabbage.golden)
	var counted := tally(_owed, findings_for(cabbage, save))
	_owed = counted[1]
	save.findings_earned += counted[0]
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


## Quitting: the units on the benches and the slips not filed yet yield their Findings now.
func _file_pending() -> void:
	for amount in _yields:
		SaveManager.save.findings += amount
	SaveManager.save.findings += pending_findings()
	_jobs.clear()
	_yields.clear()
	for slip in _slips:
		slip.queue_free()
	_slips.clear()


## Findings in slips not filed yet.
func pending_findings() -> int:
	var total := 0
	for slip in _slips:
		total += slip.get_meta(&"value")
	return total


## A finished unit's report slips (`amount` in the fewest ¶1/¶5/¶10) fly out onto the desk in front.
func _eject(amount: int) -> void:
	var delay := 0.0
	for value in CoinPile.coin_values(amount):
		_eject_slip(value, delay)
		delay += CoinPile.THROW_STAGGER * 2.0


func _eject_slip(value: int, delay: float) -> void:
	var slip: Node3D = (get_node("Slip10") if value >= 10 else get_node("Slip%d" % value)).duplicate()
	var size := Basis.from_scale(slip.scale)
	slip.top_level = true
	slip.set_meta(&"value", value)
	slip.set_meta(&"resting", false)
	add_child(slip)
	_slips.append(slip)
	var from := to_global(Vector3(0.135, 0.08, 0.15))
	# Side by side across the patch, then a layer on top of them.
	var n := _slips.size() - 1
	var spot := to_global(SLIP_AREA.position + Vector3((n % SLIP_ROW + randf_range(0.2, 0.8)) / SLIP_ROW, 0.0, randf()) * SLIP_AREA.size)
	@warning_ignore("integer_division")
	spot.y = DESK_Y + SLIP_HALF * slip.scale.y + (n / SLIP_ROW) * SLIP_LAYER + (n % SLIP_ROW) * 0.002
	var turn := randf_range(-0.6, 0.6)
	slip.global_position = from
	slip.visible = false
	var tween := slip.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(slip.show)
	tween.tween_method(func(t: float) -> void:
		slip.global_position = from.lerp(spot, t) + Vector3.UP * SLIP_LIFT * 4.0 * t * (1.0 - t)
		slip.global_basis = global_basis * Basis(Vector3.UP, turn * t) * Basis(Vector3.RIGHT, TAU * (1.0 - t)) * size,
		0.0, 1.0, SLIP_EJECT_TIME)
	tween.tween_callback(func() -> void:
		slip.set_meta(&"resting", true)
		$SlipLand.cue(slip.global_position))


## Resting slips under the empty hand fly into the Findings counter.
func _sweep(point: Vector3) -> void:
	var order := 0
	for slip in _slips:
		if slip.get_meta(&"resting") and Vector2(slip.global_position.x - point.x, slip.global_position.z - point.z).length() <= CoinPile.PICKUP_RADIUS:
			slip.set_meta(&"resting", false)
			_home(slip, order * CoinPile.HOME_STAGGER)
			order += 1


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
			slip.hide()
			got.append(slip)
	return got


## A coin vacuum empties its bag at `point`: the slips fly from there into the Findings counter.
func file_from(slips: Array[Node3D], point: Vector3) -> void:
	for i in slips.size():
		if not is_instance_valid(slips[i]):
			continue  # Filed already: the game quit while it was in the bag.
		slips[i].global_position = point
		slips[i].show()
		_home(slips[i], i * CoinPile.HOME_STAGGER)


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
	SaveManager.save.findings += slip.get_meta(&"value")
	slip.queue_free()


## Slides in through the gap from the street side; the window gives up its left third once it is in.
func _deliver() -> void:
	visible = true
	position = _rest + DELIVER_FROM
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DELIVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_set_physics(true)
		window.split()
		$Thud.cue(global_position))
	counter.visible = true
	counter.position = _counter_rest + Vector3.UP * COUNTER_DROP
	tween.tween_property(counter, "position", _counter_rest, COUNTER_DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Thud.cue(counter.global_position))


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
