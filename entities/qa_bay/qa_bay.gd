class_name QaBay
extends Node3D
## Quality Assurance (card 5): an inspection cabinet in the left third of the window gap. A cabbage
## flicked into its open chamber is taken off the mat (one unit of stock) and sucked straight in
## through the back to the lab, a cold scan line sweeping across it left to right as it goes. The
## needle sweeps on for the rest of the save's qa_time, then its Findings go up by findings_per_cabbage. While busy the
## front flap is up and shuts the mouth. Slides in from the street side once the card is stamped, the
## Findings drum row drops into the empty slot above the tally machine's money drums, and from then
## on the SaleWindow only sells through the other two thirds. With more benches (save.qa_slots) it takes
## a new unit while others are analysed; the flap only shuts once every bench is busy. Rotten units
## are refused: the chamber spits them back onto the mat (they are the bin's business). Units still
## being analysed when the game quits are filed at once.

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

@export var window: SaleWindow
@export var counter: Node3D

## Seconds each unit on a bench has been analysed, oldest first.
var _jobs: Array[float] = []
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
	if SaveManager.save.stamped.has("quality_assurance"):
		window.split()
	else:
		visible = false
		counter.visible = false
		_set_physics(false)


func _process(delta: float) -> void:
	if not visible:
		if SaveManager.save.stamped.has("quality_assurance"):
			_deliver()
		return
	if _jobs.is_empty():
		return
	for i in _jobs.size():
		_jobs[i] += delta
	# The needle shows the oldest unit's analysis.
	_progress = minf(_jobs[0] / SaveManager.save.qa_time, 1.0)
	_pose()
	if _progress >= 1.0:
		_finish()


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
	_jobs.append(0.0)
	# Off the mat for good: the feeder rolls the next one in while this one is analysed.
	cabbage.suck_out(to_global(SUCK_TO), SUCK_TIME)
	$Out.cue(cabbage.global_position)
	SaveManager.save.stock -= 1
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


func _finish() -> void:
	_jobs.pop_front()
	SaveManager.save.findings += SaveManager.save.findings_per_cabbage
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


## Quitting: the units on the benches yield their Findings now instead of being lost.
func _file_pending() -> void:
	SaveManager.save.findings += _jobs.size() * SaveManager.save.findings_per_cabbage
	_jobs.clear()


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
