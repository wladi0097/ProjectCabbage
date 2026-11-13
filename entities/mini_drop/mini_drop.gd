class_name MiniDrop
extends Node3D
## Mini units (desk card mini_cabbages): free quarter-price units sent down from upstairs. Every
## save.mini_every seconds or so (0.5..1.5 of it) one falls from just under the ceiling onto a
## random spot of the mat, in flight, so grabbing it mid-air is a catch; never more than MAX_MINIS
## at once. With the mini tube (mini_tube) the desk and mat are swapped for their tube variant
## (table_tube.blend: a square intake well right of the mat above the feeder ramp, beyond the play
## area's right wall; a trench from the mat's notch to the desk's back edge) and the steel trims and the trench's flush glass lid drop in. Minis then fall
## into the intake instead, travel unseen under the desk, roll along the trench under the glass and
## hop out of its end into the window gap, where the SaleWindow judges them like any unit (a refused
## one is thrown back onto the mat). With the tube lever (tube_lever) a points lever and its pedestal
## pop up at the desk's front edge, left of the waste bin (absent before: no pedestal, no labels, no
## collider): SALES / SPLIT / RESEARCH
## (save.tube_split 0 / 0.5 / 1). Minis routed to research travel under the desk and appear in the
## QA bay's mouth as if thrown in, or are thrown back onto the mat if it is full (QaBay.file_direct); SPLIT alternates, counted like SaleWindow._owed. The lever is dragged
## left/right, or clicked to step to the next position. FIELD THINNING PROGRAMME (mini_thinning): every
## farm harvest (save.farm_harvests going up) also sends one mini, queued THIN_GAP apart; at most
## MAX_MINIS wait in the queue (harvests past that are skipped) and the queue waits while MAX_MINIS
## thinning minis are out. The timed drop has its own MAX_MINIS, so the two add up (minis_out). The growing station (mini_station, entities/growing_station/) sits on the intake:
## out of sight in the tube, a mini passing it may grow into a full-size unit (GrowingStation.grows).
## Built in world space: the node stays at the world origin.

const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
const MAX_MINIS := 6
## FIELD THINNING minis (one per farm harvest) are in this group and counted apart from the timed ones.
const THINNED := &"thinned_minis"
## Minis fall from this height (just under the PlayArea ceiling) onto a random spot in LANDING.
const DROP_Y := 2.1
const LANDING := AABB(Vector3(-0.3, 0.85, -0.3), Vector3(1.7, 0.0, 1.1))
const FALL_SPEED := 0.5
## With the tube: they fall into the intake well (world, from mini_tube_geo.py) down to INTAKE_Y in
## INTO_TIME, travel UNDER metres unseen under the desk, then roll along the trench from GLASS_FROM to
## GLASS_TO, hop up to HOP_TO in HOP_TIME and are let go there at POP, into the gap.
const INTAKE := Vector3(1.99, 0.75, -0.07)
const INTAKE_Y := 0.6
const INTO_TIME := 0.55
const UNDER := 1.6
const GLASS_FROM := Vector3(0.48, 0.655, -0.49)
const GLASS_TO := Vector3(0.48, 0.655, -0.76)
const HOP_TO := Vector3(0.48, 0.92, -0.9)
const HOP_TIME := 0.18
const POP := Vector3(0.0, 0.0, -1.2)
## Metres per second in the tube at save.tube_speed 1 (through the glass pipe it bounces BOUNCES
## times, BOUNCE high), and how far a mini rolls per turn.
const TUBE_SPEED := 0.9
const BOUNCES := 2
const BOUNCE := 0.006
const ROLL_PER_TURN := 0.45
## The trims and the glass lid drop into place from this far above, the lever pops in.
const DROP := 0.9
const DROP_TIME := 0.45
const POP_TIME := 0.35
## The lever (world, from mini_tube_geo.py): pivot, swing axis, the arm's rest direction ("up" on
## screen), screen right in its plane, the knob from the pivot at rest, and the swing each side (rad).
## A positive turn is to the right, toward SALES.
const PIVOT := Vector3(0.58, 0.825, 1.16)
const LEVER_AXIS := Vector3(0.1354, -0.9742, -0.1805)
const ARM := Vector3(0.0442, 0.1879, -0.9812)
const RIGHT := Vector3(0.9898, 0.1248, 0.0688)
const KNOB := Vector3(0.0046, 0.0428, -0.1445)
const SWING := 0.6632
## The lever follows the hand at most this fast (rad/s), springs to a notch in SNAP_TIME; a hold
## that moves it less than CLICK counts as a click (next position).
const LEVER_RATE := 9.0
const SNAP_TIME := 0.18
const CLICK := 0.08
const LABEL_LIT := Color(0.86, 0.85, 0.8, 0.95)
const LABEL_DIM := Color(0.5, 0.52, 0.5, 0.6)
## Seconds between two thinning minis (a tractor's sweep harvests several at once).
const THIN_GAP := 0.35

## The world's plain desk and mat (table.blend's Table and cabbage_mat), hidden while the tube
## variant is shown.
@export var desk: Node3D
@export var mat: Node3D

var _wait := 0.0
## Research tally: each tube mini adds save.tube_split, one goes to the lab per whole one.
var _owed := 0.0
var _angle := 0.0
var _held_from := 0.0
var _dragging := false
var _snapping: Tween
## Farm harvests already answered with a thinning mini, the minis still queued, seconds to the next.
var _harvests_seen := 0
var _thinned := 0
var _thin_wait := 0.0

@onready var _tube: Node3D = $Tube
@onready var _lever: Node3D = $Tube/Model/Lever
@onready var _lever_base: Node3D = $Tube/Model/LeverBase
@onready var _lever_rest := _lever.basis
@onready var _handle: StaticBody3D = $Tube/Handle
@onready var _tube_rest := _tube.position
@onready var _station: GrowingStation = $Tube/GrowingStation
## The lever's slot labels SALES / SPLIT / RESEARCH (on an arc round PIVOT, in the .tscn) and MINI
## stencilled across its plate (under the arm, which may cover part of it), so the lever reads as
## the minis' points.
@onready var _labels: Array[Label3D] = [$Tube/Sales, $Tube/Split, $Tube/Research]
@onready var _heading: Label3D = $Tube/Heading


func _ready() -> void:
	var save := SaveManager.save
	_wait = Feeder.restock_wait(save.mini_every, randf())
	_harvests_seen = save.farm_harvests
	var handle: Interactable = $Tube/Handle/Interactable
	handle.grip_height = 0.03
	handle.reach = true
	handle.grabbed.connect(_grab_lever)
	handle.released.connect(_let_go_lever)
	_angle = lever_angle(save.tube_split)
	_pose_lever()
	_show_tube(save.stamped.has("mini_tube"))
	_show_lever(save.stamped.has("tube_lever"))


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not _tube.visible and save.stamped.has("mini_tube"):
		_deliver()
	if not _lever.visible and _tube.visible and save.stamped.has("tube_lever"):
		_pop_lever()
	if _dragging:
		_angle = move_toward(_angle, _angle_under_mouse(), LEVER_RATE * delta)
		_pose_lever()
	_thin(delta)
	if not save.stamped.has("mini_cabbages"):
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = Feeder.restock_wait(save.mini_every, randf())
	if minis_out(get_tree().get_nodes_in_group(&"cabbages"), false) >= MAX_MINIS:
		return
	_send_one(false)


## One mini down the tube (or onto the mat without it); `thinned`: a FIELD THINNING one.
func _send_one(thinned: bool) -> void:
	if _tube.visible and _tube.position == _tube_rest:
		_send_down_tube(thinned)
	else:
		_drop_on_mat(thinned)


## FIELD THINNING PROGRAMME: new farm harvests queue minis, sent THIN_GAP apart while there is room.
func _thin(delta: float) -> void:
	var save := SaveManager.save
	_thinned = thinned_after(_thinned, save.farm_harvests - _harvests_seen, save.stamped.has("mini_thinning"))
	_harvests_seen = save.farm_harvests
	_thin_wait -= delta
	if _thinned <= 0 or _thin_wait > 0.0:
		return
	if minis_out(get_tree().get_nodes_in_group(&"cabbages"), true) >= MAX_MINIS:
		return
	_thinned -= 1
	_thin_wait = THIN_GAP
	_send_one(true)


## The thinning queue after `harvests` new farm harvests on top of `queued` (`on`: the card is
## stamped): one mini each, MAX_MINIS at most (the rest are skipped); nothing without the card.
static func thinned_after(queued: int, harvests: int, on: bool) -> int:
	return mini(queued + maxi(harvests, 0), MAX_MINIS) if on else 0


## Minis on the desk or on their way (not sold yet), of one pool: the FIELD THINNING ones
## (`thinned`, group THINNED) or the timed ones. Each pool has its own MAX_MINIS, so the thinning
## card's harvest minis never crowd out the timed drop the projector's MINIATURISATION and
## PNEUMATIC PRESSURE nodes speed up: the two stack (at most 2 x MAX_MINIS minis out).
static func minis_out(cabbages: Array, thinned: bool) -> int:
	var count := 0
	for cabbage: Cabbage in cabbages:
		if cabbage.mini and not cabbage.sold and cabbage.is_in_group(THINNED) == thinned:
			count += 1
	return count


## Whether the next tube mini goes to research, with `owed` on the tally and `split` of each owed.
static func goes_to_research(owed: float, split: float) -> bool:
	return owed + split >= 1.0


## Whether a tube mini passing the growing station grows (GrowingStation.grows, for `roll`), bound
## for the lab if `research`. A research mini stays small once the lab pays more for it small than
## for a full unit (QaBay.findings_for: mini_value times QaBay.MICRO_SAMPLE with MICRO-SAMPLE
## PROTOCOL), so the station never undoes that card.
static func grows_in_tube(save: SaveGame, roll: float, research: bool) -> bool:
	var share := save.mini_value * (QaBay.MICRO_SAMPLE if save.stamped.has("micro_samples") else 1.0)
	return GrowingStation.grows(save, roll) and not (research and share > 1.0)


## The tally after routing one more mini (`research`: it went to the lab).
static func owed_after(owed: float, split: float, research: bool) -> float:
	return owed + split - (1.0 if research else 0.0)


## The lever's turn for `split` (0 SALES, right .. 1 RESEARCH, left).
static func lever_angle(split: float) -> float:
	return SWING * (1.0 - 2.0 * split)


## The notch nearest to the lever's turn `angle`, as a split (0, 0.5 or 1).
static func split_at(angle: float) -> float:
	return clampf(roundf(1.0 - angle / SWING), 0.0, 2.0) / 2.0


## A click steps the lever SALES -> SPLIT -> RESEARCH -> SALES.
static func next_split(split: float) -> float:
	return 0.0 if split >= 1.0 else split + 0.5


## Where a mini is `t` (0..1) of the way through the glass pipe: straight along it, hopping off the
## pipe's floor BOUNCES times.
static func zip_at(t: float) -> Vector3:
	return GLASS_FROM.lerp(GLASS_TO, t) + Vector3.UP * BOUNCE * absf(sin(t * PI * BOUNCES))


func _spawn(thinned: bool) -> Cabbage:
	var cabbage := CABBAGE.instantiate() as Cabbage
	cabbage.mini = true
	if thinned:
		cabbage.add_to_group(THINNED)
	get_parent().add_child(cabbage)
	return cabbage


func _drop_on_mat(thinned: bool) -> void:
	var cabbage := _spawn(thinned)
	var spot := LANDING.position + Vector3(randf(), 0.0, randf()) * LANDING.size
	cabbage.global_position = Vector3(spot.x, DROP_Y, spot.z)
	cabbage.in_flight = true
	cabbage.linear_velocity = Vector3.DOWN * FALL_SPEED
	cabbage.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))


## Into the intake, unseen under the desk, then along the glass and out (or to the lab).
func _send_down_tube(thinned: bool) -> void:
	var save := SaveManager.save
	var lab := _lab()
	# No lab to take them (yet): every mini is sold and the tally waits.
	var split := save.tube_split if lab != null else 0.0
	var research := goes_to_research(_owed, split)
	_owed = owed_after(_owed, split, research)
	var cabbage := _spawn(thinned)
	cabbage.tubed = true
	cabbage.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	cabbage.freeze = true
	var layer := cabbage.collision_layer
	var mask := cabbage.collision_mask
	cabbage.collision_layer = 0
	cabbage.collision_mask = 0
	var interactable := cabbage.get_node("Interactable") as Interactable
	interactable.enabled = false
	var speed := TUBE_SPEED * maxf(save.tube_speed, 0.01)
	var glass := GLASS_FROM.distance_to(GLASS_TO)
	cabbage.global_position = Vector3(INTAKE.x, DROP_Y, INTAKE.z)
	var ride := cabbage.create_tween()
	ride.tween_property(cabbage, "global_position:y", INTAKE_Y, INTO_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ride.tween_callback(func() -> void:
		cabbage.visible = false
		$Whoosh.cue(INTAKE)
		if _station.visible and grows_in_tube(save, randf(), research):
			cabbage.grow()
			_station.pulse())
	ride.tween_interval(UNDER / speed)
	if research:
		ride.tween_callback(lab.file_direct.bind(cabbage))
		return
	ride.tween_callback(func() -> void:
		cabbage.global_position = GLASS_FROM
		cabbage.visible = true)
	ride.tween_method(func(t: float) -> void: cabbage.global_position = zip_at(t), 0.0, 1.0, glass / speed)
	ride.parallel().tween_property(cabbage, "rotation:x", cabbage.rotation.x - TAU * glass / ROLL_PER_TURN, glass / speed)
	ride.tween_property(cabbage, "global_position", HOP_TO, HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ride.tween_callback(func() -> void:
		cabbage.collision_layer = layer
		cabbage.collision_mask = mask
		cabbage.freeze = false
		interactable.enabled = true
		cabbage.linear_velocity = POP)


## The QA bay, if it is in and can take tube deliveries.
func _lab() -> Node:
	var bay := get_tree().get_first_node_in_group(&"qa_bay") as Node3D
	return bay if bay != null and bay.visible and bay.has_method(&"file_direct") else null


## The tube variant of the desk and mat in, the plain ones out (one swap, never both drawn); the
## trims and glass follow `on`.
func _show_tube(on: bool) -> void:
	_tube.visible = on
	$TubeDesk.visible = on
	for plain: Node3D in [desk, mat]:
		if plain != null:
			plain.visible = not on


## The desks swap, the trims and the glass lid drop into place from above.
func _deliver() -> void:
	_show_tube(true)
	_tube.position = _tube_rest + Vector3.UP * DROP
	var tween := create_tween()
	tween.tween_property(_tube, "position", _tube_rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		$Thud.cue(INTAKE)
		$Thud.cue(GLASS_FROM))


func _pop_lever() -> void:
	_show_lever(true)
	var tween := create_tween().set_parallel()
	for part: Node3D in [_lever, _lever_base, _heading] + _labels:
		part.scale = Vector3.ONE * 0.01
		tween.tween_property(part, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_callback(func() -> void: $Clunk.cue(PIVOT))


## The lever, its pedestal, labels and colliders: all there with `on`, all absent without.
func _show_lever(on: bool) -> void:
	_lever.visible = on
	_lever_base.visible = on
	$Tube/Pedestal/Shape.disabled = not on
	for label in _labels:
		label.visible = on
	_heading.visible = on
	$Tube/Handle/Shape.disabled = not on
	$Tube/Handle/Interactable.enabled = on


func _grab_lever() -> void:
	if _snapping != null:
		_snapping.kill()
	_dragging = true
	_held_from = _angle


func _let_go_lever() -> void:
	_dragging = false
	var save := SaveManager.save
	var before := save.tube_split
	save.tube_split = next_split(before) if absf(_angle - _held_from) < CLICK else split_at(_angle)
	_snapping = create_tween()
	_snapping.tween_method(func(a: float) -> void:
		_angle = a
		_pose_lever(), _angle, lever_angle(save.tube_split), SNAP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if save.tube_split != before:
		$Clunk.cue(PIVOT)


## The lever's turn under the mouse, read off the plane it swings in.
func _angle_under_mouse() -> float:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var pivot := _tube.to_global(PIVOT)
	var hit: Variant = Plane(LEVER_AXIS, pivot).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return _angle
	var d: Vector3 = (hit as Vector3) - pivot
	return clampf(atan2(d.dot(RIGHT), d.dot(ARM)), -SWING, SWING)


func _pose_lever() -> void:
	var turn := Basis(LEVER_AXIS, _angle)
	_lever.basis = turn * _lever_rest
	_handle.position = PIVOT + turn * KNOB
	var lit := roundi(split_at(_angle) * 2.0)
	for i in _labels.size():
		_labels[i].modulate = LABEL_LIT if i == lit else LABEL_DIM
