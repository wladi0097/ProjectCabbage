class_name Associate
extends Node3D
## A hired hand: an intern's hand in a grey office sleeve. Every save.associate_interval seconds it
## reaches in from its spot on the bottom screen edge, takes the
## nearest cabbage resting on the mat, lifts it clear of the others and lobs it, not very well, at the sale
## part of the window gap, then withdraws. The SaleWindow sells or refuses it as usual. It is slow
## on purpose, and never fights the player: if the player grabs its cabbage, on the mat or out of its
## fist mid-carry, it flinches and goes back empty-handed.
## The Associate in the world is hand 0 and staffs the rest: it spawns one sibling per hired hand
## (save.hands) up to MAX_VISIBLE, each with its own entry point and timing. Past that the visible
## hands work faster instead. Hands never go for a cabbage another hand has claimed.

enum Phase { IDLE, REACH, TAKE, CARRY, FOLLOW, FLINCH, WITHDRAW }

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
const SLEEVE := preload("res://assets/materials/associate_hand.tres")

## Off screen below the bottom-right edge, in front of the console and clear of the ramp.
const ENTRY := Vector3(1.15, 1.2, 1.75)
## Hand n enters ENTRY_X[n] to the side of ENTRY, so the sleeves fan out along the bottom edge.
const ENTRY_X: Array[float] = [0.0, -0.4, 0.35, -0.8, -0.2, -1.2, 0.6, -0.6, -1.0, 0.15]
const MAX_VISIBLE := 10
## Half the player's hand.
const SIZE := 0.5
## Hand n's first trip waits FIRST_WAIT + n * STAGGER, and every wait varies by ±WAIT_JITTER.
const FIRST_WAIT := 2.0
const STAGGER := 1.5
const WAIT_JITTER := 0.15
## Speeds of the fingertip (m/s): reaching in, lowering onto the cabbage, carrying, and leaving.
## Slow on purpose; each is times save.associate_speed, which tree nodes raise.
const REACH_SPEED := 0.45
const TAKE_SPEED := 0.22
const CARRY_SPEED := 0.4
const WITHDRAW_SPEED := 0.55
## It hovers this high over its cabbage before lowering onto it, and holds it this far below the
## knuckles (the cabbage Interactable's grip_height).
const HOVER := 0.12
const GRIP := 0.135
## Taken, the cabbage is first lifted straight up until its centre is this high, over the others.
const LIFT_Y := 1.12
## The lob: released from RELEASE_Y / RELEASE_Z (x a little off the aim), it lands on AIM_Y / AIM_Z
## at a random x in AIM_X after about LOB_TIME. AIM_JITTER (x, y) and LOB_JITTER are its clumsiness.
const RELEASE_Y := 1.0
const RELEASE_Z := -0.1
const AIM_X := Vector2(0.45, 1.6)
const AIM_Y := 0.9
const AIM_Z := -0.9
const AIM_JITTER := Vector2(0.06, 0.03)
const LOB_TIME := 0.33
## A lob into the QA bay: released this high over its mouth and at this z, this fast.
const QA_RELEASE := Vector2(0.03, -0.3)
const QA_LOB := 0.12
const LOB_JITTER := 0.03
## After letting go the hand follows through this far toward the window.
const FOLLOW_THROUGH := 0.12
## A cabbage moving slower than this counts as resting.
const REST_SPEED := 0.3
## No cabbage to take: look again after this many seconds.
const RETRY := 1.0
## Hand wobble (m) while it is out.
const WOBBLE := 0.012
## Snatched from: the hand jerks back this far, trembles for FLINCH_TIME, then withdraws.
const FLINCH := Vector3(0.0, 0.08, 0.14)
const FLINCH_TIME := 0.4
const TREMBLE := 0.008
## A carried cabbage sits on this layer (the cards' one): the player's ray finds it, nothing collides.
const CARRIED_LAYER := UpgradeCard.LAYER

## Which hand this is (0 is the one placed in the world).
var index := 0
## Trips set off by all hands together, for the QA intake rota.
static var _trips := 0
var _phase := Phase.IDLE
var _wait := FIRST_WAIT
var _entry := ENTRY
var _tip := ENTRY
var _target: Cabbage
var _release := Vector3.ZERO
var _aim := Vector3.ZERO
var _lob := LOB_TIME
var _lifted := false
## The carried cabbage's collision layer and mask, off while it is carried so it shoves nothing.
var _layers := Vector2i.ZERO
var _time := 0.0
var _flinch_left := 0.0
## Hand 0: how many hands are on the desk, so _staff only looks again once save.hands grows.
var _staffed := 0

@onready var _model: HandModel = $Hand


func _ready() -> void:
	add_to_group(&"associates")
	_entry = ENTRY + Vector3.RIGHT * ENTRY_X[index]
	_tip = _entry
	_wait = FIRST_WAIT + index * STAGGER
	_time = index * 1.7
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = SLEEVE
	_model.visible = false
	_model.size = SIZE


func _process(delta: float) -> void:
	if index == 0:
		_staff()
	if index >= SaveManager.save.hands:
		return
	_time += delta
	_wait -= delta
	match _phase:
		Phase.IDLE:
			if _wait <= 0.0:
				_set_off()
			return
		Phase.REACH, Phase.TAKE, Phase.CARRY when snatched(_target, Hand.held):
			_flinch()
		Phase.REACH, Phase.TAKE:
			if gives_up(_target, Hand.held):
				_withdraw()
			elif _phase == Phase.REACH and _move(_target.global_position + Vector3.UP * (GRIP + HOVER), REACH_SPEED, delta):
				_phase = Phase.TAKE
			elif _phase == Phase.TAKE and _move(_target.global_position + Vector3.UP * GRIP, TAKE_SPEED, delta):
				_take()
		Phase.CARRY:
			var goal := _release if _lifted else Vector3(_tip.x, LIFT_Y, _tip.z)
			var arrived := _move(goal + Vector3.UP * GRIP, CARRY_SPEED, delta)
			if not is_instance_valid(_target):
				_withdraw()
			elif arrived and not _lifted:
				_lifted = true
			elif arrived:
				_throw()
			else:
				_target.global_position = _tip + _wobble() - Vector3.UP * GRIP
		Phase.FLINCH:
			_flinch_left -= delta
			if _flinch_left <= 0.0:
				_withdraw()
			_model.move_to(_tip + Vector3.RIGHT * sin(_time * 45.0) * TREMBLE, delta)
			return
		Phase.FOLLOW:
			if _move(_release + Vector3(0.0, GRIP, -FOLLOW_THROUGH), CARRY_SPEED, delta):
				_withdraw()
		Phase.WITHDRAW:
			if _move(_entry, WITHDRAW_SPEED, delta):
				_phase = Phase.IDLE
				_model.visible = false
				return
	_model.move_to(_tip + _wobble(), delta)


## Whether trip number `trip` goes to the QA bay: the rota is on (`every` > 0), it is that trip's
## turn and the bay has a free bench.
static func feeds_qa(trip: int, every: int, room: bool) -> bool:
	return every > 0 and room and trip % every == 0


## The one place a hand is added (the projector tree's HIRE ASSOCIATE nodes); hand 0 spawns it.
static func add_hand(save: SaveGame) -> void:
	save.hands += 1


## The nearest cabbage to `from` that rests on the mat and nobody has: not held by the player, not
## claimed by another hand, not sold, out of the window or frozen (rolling down the ramp, carried),
## not flying, not stray.
static func pick_target(cabbages: Array, from: Vector3, held: Interactable, claimed: Array = []) -> Cabbage:
	var best: Cabbage = null
	for cabbage: Cabbage in cabbages:
		var interactable := cabbage.get_node("Interactable") as Interactable
		if claimed.has(cabbage) or cabbage.sold or cabbage.away or cabbage.freeze or cabbage.in_flight or not interactable.enabled \
				or held == interactable or cabbage.linear_velocity.length() > REST_SPEED \
				or SaleWindow.is_stray(cabbage.global_position) \
				or (cabbage.rotten and SaveManager.save.hands_bin == 0):  # sales events: rotten units
			continue
		if best == null or from.distance_to(cabbage.global_position) < from.distance_to(best.global_position):
			best = cabbage
	return best


## The player has the cabbage this hand is after or carrying.
static func snatched(target: Cabbage, held: Interactable) -> bool:
	return is_instance_valid(target) and held != null and held == target.get_node("Interactable")


## The player took it, it left, or it is no longer on the mat.
static func gives_up(target: Cabbage, held: Interactable) -> bool:
	return not is_instance_valid(target) or target.sold or target.away or target.freeze \
			or held == target.get_node("Interactable") or SaleWindow.is_stray(target.global_position)


## Where the lob is aimed for a `roll` (0..1 across AIM_X) and clumsiness `jitter` (each -1..1).
static func aim_at(roll: float, jitter: Vector2) -> Vector3:
	return Vector3(lerpf(AIM_X.x, AIM_X.y, roll) + jitter.x * AIM_JITTER.x, AIM_Y + jitter.y * AIM_JITTER.y, AIM_Z)


## Spawns the hired hands that are not on the desk yet (up to MAX_VISIBLE) next to this one.
func _staff() -> void:
	if _staffed >= mini(SaveManager.save.hands, MAX_VISIBLE):
		return
	var count := get_tree().get_nodes_in_group(&"associates").size()
	while count < mini(SaveManager.save.hands, MAX_VISIBLE):
		var hand: Associate = load(scene_file_path).instantiate()
		hand.index = count
		add_sibling(hand)
		count += 1
	_staffed = count


func _set_off() -> void:
	var hands := SaveManager.save.hands
	# Past MAX_VISIBLE the visible hands share the extra hands' trips.
	_wait = SaveManager.save.associate_interval * minf(1.0, float(MAX_VISIBLE) / hands) / SaveManager.save.hand_output \
			* randf_range(1.0 - WAIT_JITTER, 1.0 + WAIT_JITTER)
	var claimed := []
	for other: Associate in get_tree().get_nodes_in_group(&"associates"):
		if other != self and is_instance_valid(other._target):
			claimed.append(other._target)
	_target = pick_target(get_tree().get_nodes_in_group(&"cabbages"), _entry, Hand.held, claimed)
	if _target == null:
		_wait = RETRY
		return
	_aim = aim_at(randf(), Vector2(randf_range(-1, 1), randf_range(-1, 1)))
	if _target.rotten:  # sales events: rotten units go in the bin
		_aim = RottenBin.HAND_AIM
	# The intake rota: every qa_feed_every-th trip (all hands together) goes to a QA bay with room.
	var bay := get_tree().get_first_node_in_group(&"qa_bay") as QaBay
	_trips += 1
	if not _target.rotten and feeds_qa(_trips, SaveManager.save.qa_feed_every, bay != null and bay.has_room()):
		# The bay's mouth is barely taller than a unit: low, close and almost flat, or it hits the lip.
		_aim = bay.mouth() + Vector3(randf_range(-1, 1) * AIM_JITTER.x * 0.5, 0.0, 0.0)
		_release = Vector3(_aim.x, _aim.y + QA_RELEASE.x, QA_RELEASE.y)
		_lob = QA_LOB
	else:
		_release = Vector3(_aim.x + randf_range(-0.1, 0.1), RELEASE_Y, RELEASE_Z)
		_lob = LOB_TIME + randf_range(-LOB_JITTER, LOB_JITTER)
	_tip = _entry
	_model.pose = HandModel.Pose.OPEN
	_model.visible = true
	_phase = Phase.REACH


## Closes on it: the cabbage is out of the physics while carried, but the player can still grab it.
func _take() -> void:
	_target.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_target.freeze = true
	_layers = Vector2i(_target.collision_layer, _target.collision_mask)
	_target.collision_layer = CARRIED_LAYER
	_target.collision_mask = 0
	_lifted = false
	_model.pose = HandModel.Pose.GRAB
	$Grab.cue(_target.global_position)
	_phase = Phase.CARRY


func _throw() -> void:
	var from := _target.global_position
	_let_go()
	_target.linear_velocity = Feeder.ballistic_velocity(from, _aim, _lob)
	_target.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	_target = null
	_model.pose = HandModel.Pose.OPEN
	_phase = Phase.FOLLOW


## The player took its cabbage: let go, jerk back and tremble, then withdraw empty-handed.
func _flinch() -> void:
	if _phase == Phase.CARRY:
		_let_go()
	_target = null
	_model.pose = HandModel.Pose.OPEN
	_tip += FLINCH
	_flinch_left = FLINCH_TIME
	_phase = Phase.FLINCH


func _withdraw() -> void:
	if is_instance_valid(_target) and _phase == Phase.CARRY:
		_let_go()
	_target = null
	_model.pose = HandModel.Pose.OPEN
	_phase = Phase.WITHDRAW


func _let_go() -> void:
	_target.freeze = false
	_target.collision_layer = _layers.x
	_target.collision_mask = _layers.y


## Moves the fingertip toward `to`; true once it is there.
func _move(to: Vector3, speed: float, delta: float) -> bool:
	_tip = _tip.move_toward(to, speed * SaveManager.save.associate_speed * delta)
	return _tip.is_equal_approx(to)


func _wobble() -> Vector3:
	return Vector3(sin(_time * 3.1), 0.5 * sin(_time * 4.3), cos(_time * 2.7)) * WOBBLE
