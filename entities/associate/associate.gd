class_name Associate
extends Node3D
## A hired hand: an intern's hand in a grey office sleeve. Every save.associate_interval seconds it
## reaches in from its parking spot on the bottom screen edge (where it rests, always in view), takes the
## nearest cabbage resting on the mat, lifts it clear of the others and lobs it, not very well, at the
## right of the window gap (the street; never the QA bay on the left), then goes back to its spot. The SaleWindow sells or refuses it as usual. It is slow
## on purpose, and never fights the player: if the player grabs its cabbage, on the mat or out of its
## fist mid-carry, it flinches and goes back empty-handed.
## The Associate in the world is hand 0 and staffs the rest: it spawns one sibling per hired hand
## (save.hands) up to MAX_VISIBLE, each with its own parking spot and timing. Past that the visible
## hands work faster instead. Hands never go for a cabbage another hand has claimed.
## Rotten units are lobbed out of the window like the rest (and fined there) until the desk card
## spoilage_memo, after which hands leave them on the mat; once the tree's WASTE HANDLING PROTOCOL
## (save.hands_bin) is bought they go into the waste bin instead.

enum Phase { IDLE, REACH, TAKE, CARRY, FOLLOW, FLINCH, WITHDRAW }

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
const SLEEVE := preload("res://assets/materials/associate_hand.tres")
## Solid enough to read clearly at the screen edge; the shared material stays a ghost for the consultant.
const OPACITY := Vector2(0.9, 1.0)

## Where an idle hand rests: palm down and still on the desk top (y 0.76), just inside the bottom
## screen edge (the camera's 16:9 frame bottom is z ~1.23 there), its sleeve running off the edge. Hand n parks at x PARK_X[n], 0.2 apart
## so no two overlap, the first ones in front of the mat.
const PARK := Vector3(0.0, 0.765, 1.15)
## None within BIN_CLEAR of the waste bin (x 0.95): the 10th parks right of it, by the console.
const PARK_X: Array[float] = [0.6, 0.4, 0.2, 0.0, -0.2, -0.4, -0.6, -0.8, -1.0, 1.3]
const BIN_CLEAR := 0.3
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
## at a random x in AIM_X (the right ~30% of the gap, SaleWindow.GAP_X) after about LOB_TIME. AIM_JITTER (x, y) and LOB_JITTER are its clumsiness.
const RELEASE_Y := 1.0
const RELEASE_Z := -0.1
const AIM_X := Vector2(1.2, 1.6)
const AIM_Y := 0.9
const AIM_Z := -0.9
const AIM_JITTER := Vector2(0.06, 0.03)
const LOB_TIME := 0.33
const LOB_JITTER := 0.03
## A rotten unit for the bin is let go this far from it (over the mat), so the lob drops in from above.
const BIN_RELEASE := Vector3(-0.1, 0.0, -0.45)
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
var _phase := Phase.IDLE
var _wait := FIRST_WAIT
var _entry := PARK
var _tip := PARK
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
	_entry = PARK + Vector3.RIGHT * PARK_X[index]
	_tip = _entry
	_wait = FIRST_WAIT + index * STAGGER
	_time = index * 1.7
	var sleeve := SLEEVE.duplicate() as ShaderMaterial
	sleeve.set_shader_parameter(&"opacity", OPACITY.x)
	sleeve.set_shader_parameter(&"edge_opacity", OPACITY.y)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = sleeve
	_model.pose = HandModel.Pose.OPEN
	_model.visible = false
	_model.size = SIZE


func _process(delta: float) -> void:
	if index == 0:
		_staff()
	if index >= SaveManager.save.hands:
		return
	_model.visible = true
	_time += delta
	_wait -= delta
	match _phase:
		Phase.IDLE:
			if _wait <= 0.0:
				_set_off()
			_move(_entry, WITHDRAW_SPEED, delta)
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
	# Parked, it lies still on the desk; out working, it wobbles.
	_model.move_to(_tip + (Vector3.ZERO if _phase == Phase.IDLE else _wobble()), delta)


## The one place a hand is added (the projector tree's HIRE ASSOCIATE nodes); hand 0 spawns it.
static func add_hand(save: SaveGame) -> void:
	save.hands += 1


## The nearest cabbage to `from` that rests on the mat and nobody has: not held by the player, not
## claimed by another hand, not sold, out of the window or frozen (rolling down the ramp, carried),
## not flying, not stray; and not rotten while `skip_rotten` (the spoilage memo, before hands bin).
static func pick_target(cabbages: Array, from: Vector3, held: Interactable, claimed: Array = [], skip_rotten := false) -> Cabbage:
	var best: Cabbage = null
	for cabbage: Cabbage in cabbages:
		var interactable := cabbage.get_node("Interactable") as Interactable
		if claimed.has(cabbage) or (skip_rotten and cabbage.rotten) or cabbage.sold or cabbage.away or cabbage.freeze or cabbage.in_flight or not interactable.enabled \
				or held == interactable or cabbage.linear_velocity.length() > REST_SPEED \
				or SaleWindow.is_stray(cabbage.global_position):
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


## The bin a hand throws `target` into: only a rotten unit, once hands_bin is bought and the bin is
## on the desk. Otherwise null, and the unit goes out of the window (a rotten one is fined there).
static func bin_for(target: Cabbage, hands_bin: int, bin: RottenBin) -> RottenBin:
	return bin if target.rotten and hands_bin > 0 and bin != null and bin.visible else null


## Hands leave rotten units alone: the spoilage memo is stamped and they don't bin them yet.
static func skips_rotten(save: SaveGame) -> bool:
	return save.stamped.has("spoilage_memo") and save.hands_bin == 0


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
	var save := SaveManager.save
	_target = pick_target(get_tree().get_nodes_in_group(&"cabbages"), _entry, Hand.held, claimed, skips_rotten(save))
	if _target == null:
		_wait = RETRY
		return
	var bin := bin_for(_target, SaveManager.save.hands_bin, get_tree().get_first_node_in_group(&"rotten_bin") as RottenBin)
	if bin != null:
		_aim = bin.hand_aim()
		_release = Vector3(_aim.x + BIN_RELEASE.x + randf_range(-0.05, 0.05), RELEASE_Y, _aim.z + BIN_RELEASE.z)
	else:
		_aim = aim_at(randf(), Vector2(randf_range(-1, 1), randf_range(-1, 1)))
		_release = Vector3(_aim.x + randf_range(-0.1, 0.1), RELEASE_Y, RELEASE_Z)
	_lob = LOB_TIME + randf_range(-LOB_JITTER, LOB_JITTER)
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
