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
## A research hand (`research`, save.research_hands, a lab-coat cuff) is the same hand working for the
## QA bay: it rests at the left end of the bottom edge, and only while the bay has room
## takes a unit (never a rotten one; minis are fine, they yield little) and tosses it into the bay's
## mouth. Hand 0 staffs both kinds. After the desk card lab_priority research hands go for research
## units first, and money hands leave them alone while the schedule strikes them (HandSchedule.forbidden:
## the memo's stamp strikes them, the schedule can clear it).
## Golden units are the player's: no hand touches one until the projector node for its kind is bought
## (GOLD_SALE for money hands, GOLD_LAB for research hands; takes_golden).
## With TWO-HANDED POLICY (save.hand_trip 2) a money hand that has thrown goes straight for a second
## cabbage from where it stands, and only then back to its spot (throws_again).
## The HANDLING ASSIGNMENT SCHEDULE (entities/hand_schedule/) can strike cabbage kinds for either
## kind of hand: a hand never takes a struck kind (pick_target `forbidden`, struck).

enum Phase { IDLE, REACH, TAKE, CARRY, FOLLOW, FLINCH, WITHDRAW }

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
const SLEEVE := preload("res://assets/materials/associate_hand.tres")
## Solid enough to read clearly at the screen edge; the shared material stays a ghost for the consultant.
const OPACITY := Vector2(0.9, 1.0)

## Where an idle hand rests: palm down and still on the desk top (y 0.76), just inside the bottom
## screen edge (the camera's 16:9 frame bottom is z ~1.23 there), its sleeve running off the edge.
## Idle hands lie in two loose piles (park_spot): money hands around PILE_X in front of the mat (the
## tube lever and the bin to their right), research hands around RESEARCH_PILE_X on the QA bay's
## side, so the lanes fan out to the street and the bay
## without crossing. Hand n sits a deterministic jumble off the pile's middle (up to PILE_SPREAD across,
## PILE_TURN turned), and every PILE_ROW hands start a new layer PILE_LAYER higher, resting on the ones
## before. Leaving or coming back, a hand simply passes through the others (they are ghosts).
const PARK := Vector3(0.0, 0.765, 1.15)
const PILE_X := 0.15
const RESEARCH_PILE_X := -0.25
const PILE_SPREAD := 0.09
const PILE_ROW := 4
const PILE_LAYER := 0.025
const PILE_TURN := deg_to_rad(12.0)
## At most this many research hands are on the desk; past that the visible ones work faster.
const MAX_RESEARCH := 3
## The lab coat: sleeve and shirt cuff light blue (a pale echo of the research units' cyan); the hand
## itself stays the money hands' glove.
const LAB_COAT := {sleeve = Color(0.45, 0.66, 0.78), shirt = Color(0.66, 0.8, 0.88)}
## A research hand lets go RESEARCH_RELEASE from the bay's mouth (in front of it, at mouth height) and
## tosses it flat into the chamber: at the mouth plus (±BAY_JITTER, BAY_DROP, 0) after BAY_LOB.
const RESEARCH_RELEASE := Vector3(0.0, 0.0, 0.4)
const BAY_JITTER := 0.04
const BAY_DROP := -0.03
const BAY_LOB := 0.15
## Under lab_priority a research hand takes any research unit before any other (this many m nearer).
const PREFER := 100.0
## No hand parks within BIN_CLEAR of the waste bin (x 0.95).
const BIN_CLEAR := 0.3
## The projector nodes that let money hands sell, and research hands analyse, golden units (no number:
## tree_bought, like CoinVacuums.STABILISER).
const GOLD_SALE := "gold_hands"
const GOLD_LAB := "gold_lab_hands"
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

## Which hand this is (0 is the one placed in the world), counted per kind.
var index := 0
## A research hand: lobs into the QA bay instead of the window.
var research := false
var _phase := Phase.IDLE
var _wait := FIRST_WAIT
var _entry := PARK
var _tip := PARK
var _target: Cabbage
var _release := Vector3.ZERO
var _aim := Vector3.ZERO
## This trip's lob goes into the RottenBin (marked so the bin takes it).
var _binning := false
var _lob := LOB_TIME
var _lifted := false
## Cabbages thrown on this trip (save.hand_trip of them before it goes home).
var _thrown := 0
## The carried cabbage's collision layer and mask, off while it is carried so it shoves nothing.
var _layers := Vector2i.ZERO
var _time := 0.0
var _flinch_left := 0.0
## Hand 0: how many money (x) and research (y) hands are on the desk, so _staff only looks again
## once save.hands or save.research_hands grows.
var _staffed := Vector2i.ZERO

## sleeve_for's materials by kind (false: money, true: research).
static var _sleeves := {}

@onready var _model: HandModel = $Hand


func _ready() -> void:
	add_to_group(&"associates")
	_entry = park_spot(index, research)
	rotation.y = park_turn(index)
	_tip = _entry
	_wait = FIRST_WAIT + index * STAGGER
	_time = index * 1.7
	var sleeve := sleeve_for(research)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = sleeve
	_model.pose = HandModel.Pose.OPEN
	_model.visible = false
	_model.size = SIZE


func _process(delta: float) -> void:
	if index == 0 and not research:
		_staff()
	if index >= _hired():
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
			if gives_up(_target, Hand.held) or struck(_target, SaveManager.save, research):
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
			_place(_tip + Vector3.RIGHT * sin(_time * 45.0) * TREMBLE, delta)
			return
		Phase.FOLLOW:
			if _move(_release + Vector3(0.0, GRIP, -FOLLOW_THROUGH), CARRY_SPEED, delta):
				# TWO-HANDED POLICY: on for the next cabbage from here; none to take, it goes home.
				if not throws_again(_thrown, SaveManager.save.hand_trip, research) or not _pick(_tip):
					_withdraw()
		Phase.WITHDRAW:
			if _move(_entry, WITHDRAW_SPEED, delta):
				_phase = Phase.IDLE
	# Parked, it lies still on the desk; out working, it wobbles.
	_place(_tip + (Vector3.ZERO if _phase == Phase.IDLE else _wobble()), delta)


## The sleeve material of every money hand, or (`for_research`) of every research hand: made once each.
static func sleeve_for(for_research: bool) -> ShaderMaterial:
	if not _sleeves.has(for_research):
		var sleeve := SLEEVE.duplicate() as ShaderMaterial
		sleeve.set_shader_parameter(&"opacity", OPACITY.x)
		sleeve.set_shader_parameter(&"edge_opacity", OPACITY.y)
		if for_research:
			for part: String in LAB_COAT:
				sleeve.set_shader_parameter(part, LAB_COAT[part])
		_sleeves[for_research] = sleeve
	return _sleeves[for_research]


## The one place a hand is added (the projector tree's HIRE ASSOCIATE nodes); hand 0 spawns it.
static func add_hand(save: SaveGame) -> void:
	save.hands += 1


## The nearest cabbage to `from` that rests on the mat and nobody has: not held by the player, not
## claimed by another hand, not sold, out of the window or frozen (rolling down the ramp, carried),
## not flying, not stray; and not rotten while `skip_rotten` (the spoilage memo, before hands bin).
## A `for_research` hand never takes a rotten one. Under `lab` (desk card lab_priority) research hands
## take research units first. A golden one only while `golden` (takes_golden).
## Never one whose kind is in `forbidden` (the handling schedule's list for this kind of hand,
## HandSchedule.forbidden): the schedule only takes away, on top of every rule above.
static func pick_target(cabbages: Array, from: Vector3, held: Interactable, claimed: Array = [], skip_rotten := false,
		for_research := false, lab := false, golden := false, forbidden := PackedStringArray()) -> Cabbage:
	var best: Cabbage = null
	var best_score := INF
	for cabbage: Cabbage in cabbages:
		var interactable := cabbage.get_node("Interactable") as Interactable
		if claimed.has(cabbage) or ((skip_rotten or for_research) and cabbage.rotten) \
				or (cabbage.golden and not golden) or forbidden.has(HandSchedule.kind_of(cabbage)) \
				or cabbage.sold or cabbage.away or cabbage.freeze or cabbage.in_flight or not interactable.enabled \
				or held == interactable or cabbage.linear_velocity.length() > REST_SPEED \
				or SaleWindow.is_stray(cabbage.global_position):
			continue
		var score := from.distance_to(cabbage.global_position) + (PREFER if for_research and lab and not cabbage.research else 0.0)
		if score < best_score:
			best = cabbage
			best_score = score
	return best


## The player has the cabbage this hand is after or carrying. `target` is untyped: it may have been
## freed mid-reach (sold, binned), and a freed object passed into a typed parameter is a script error.
static func snatched(target: Variant, held: Interactable) -> bool:
	return is_instance_valid(target) and held != null and held == (target as Cabbage).get_node("Interactable")


## The player took it, it left (or was freed), or it is no longer on the mat.
static func gives_up(target: Variant, held: Interactable) -> bool:
	if not is_instance_valid(target):
		return true
	var cabbage := target as Cabbage
	return cabbage.sold or cabbage.away or cabbage.freeze \
			or held == cabbage.get_node("Interactable") or SaleWindow.is_stray(cabbage.global_position)


## The handling schedule now forbids this kind of hand (`for_research`: a lab hand) the cabbage it is
## reaching for: struck on the paper while the hand was on its way. It lets it lie.
static func struck(target: Variant, save: SaveGame, for_research: bool) -> bool:
	return is_instance_valid(target) and HandSchedule.forbidden(save, for_research).has(HandSchedule.kind_of(target as Cabbage))


## The bin a hand throws `target` into: only a rotten unit, once hands_bin is bought and the bin is
## on the desk. Otherwise null, and the unit goes out of the window (a rotten one is fined there).
static func bin_for(target: Cabbage, hands_bin: int, bin: RottenBin) -> RottenBin:
	return bin if target.rotten and hands_bin > 0 and bin != null and bin.visible else null


## Hands leave rotten units alone: the spoilage memo is stamped and they don't bin them yet. The
## quarantine card (Cabbage.SHIELD_CARD) changes nothing here: it only stops collisions.
static func skips_rotten(save: SaveGame) -> bool:
	return save.stamped.has("spoilage_memo") and save.hands_bin == 0


## Hands of this kind may take golden units: their projector node (GOLD_SALE / GOLD_LAB) is bought.
static func takes_golden(save: SaveGame, for_research: bool) -> bool:
	return save.tree_bought.has(GOLD_LAB if for_research else GOLD_SALE)


## Where the lob is aimed for a `roll` (0..1 across AIM_X) and clumsiness `jitter` (each -1..1).
static func aim_at(roll: float, jitter: Vector2) -> Vector3:
	return Vector3(lerpf(AIM_X.x, AIM_X.y, roll) + jitter.x * AIM_JITTER.x, AIM_Y + jitter.y * AIM_JITTER.y, AIM_Z)


## Where hand `i` of its kind lies idle in its pile: a fixed jumble around the pile's middle, a
## layer up every PILE_ROW hands. The few research hands pile tighter: half the spread, each one a layer up.
static func park_spot(i: int, for_research: bool) -> Vector3:
	var spread := PILE_SPREAD * (0.5 if for_research else 1.0)
	var row := 1 if for_research else PILE_ROW
	var jumble := Vector3(((i * 7) % 5 - 2) * 0.5 * spread, floorf(i / float(row)) * PILE_LAYER, -(i % 3) * 0.02)
	return PARK + Vector3.RIGHT * (RESEARCH_PILE_X if for_research else PILE_X) + jumble


## How far hand `i` is turned (yaw), so the pile looks dropped rather than lined up.
static func park_turn(i: int) -> float:
	return ((i * 5) % 7 - 3) / 3.0 * PILE_TURN


## Where a research hand's toss into the bay's `mouth` lands for clumsiness `jitter` (-1..1).
static func bay_aim(mouth: Vector3, jitter: float) -> Vector3:
	return mouth + Vector3(jitter * BAY_JITTER, BAY_DROP, 0.0)


## Hands of this kind on the payroll (money or research).
func _hired() -> int:
	return SaveManager.save.research_hands if research else SaveManager.save.hands


## Spawns the hired hands of both kinds that are not on the desk yet (up to MAX_VISIBLE money hands
## and MAX_RESEARCH research hands) next to this one.
func _staff() -> void:
	var save := SaveManager.save
	var want := Vector2i(mini(save.hands, MAX_VISIBLE), mini(save.research_hands, MAX_RESEARCH))
	if _staffed.x >= want.x and _staffed.y >= want.y:
		return
	var have := Vector2i.ZERO
	for hand: Associate in get_tree().get_nodes_in_group(&"associates"):
		have += Vector2i(0, 1) if hand.research else Vector2i(1, 0)
	for kind in 2:
		while have[kind] < want[kind]:
			var hand: Associate = load(scene_file_path).instantiate()
			hand.index = have[kind]
			hand.research = kind == 1
			add_sibling(hand)
			have[kind] += 1
	_staffed = have


## Whether a hand that has `thrown` cabbages on this trip takes another before going home: a money
## hand, until it has thrown `per_trip` (save.hand_trip). Research hands always go home.
static func throws_again(thrown: int, per_trip: int, for_research: bool) -> bool:
	return not for_research and thrown < per_trip


func _set_off() -> void:
	var save := SaveManager.save
	var visible_hands := MAX_RESEARCH if research else MAX_VISIBLE
	# Past the visible ones the visible hands share the extra hands' trips.
	_wait = save.associate_interval * minf(1.0, float(visible_hands) / _hired()) / save.hand_output \
			* randf_range(1.0 - WAIT_JITTER, 1.0 + WAIT_JITTER)
	_thrown = 0
	if not _pick(_entry):
		_wait = RETRY


## Goes for the nearest cabbage to `from` it may take (pick_target): aims and starts reaching. False
## if there is none, or a research hand has no free bench.
func _pick(from: Vector3) -> bool:
	var save := SaveManager.save
	var claimed := []
	var lab_trips := 0
	for other: Associate in get_tree().get_nodes_in_group(&"associates"):
		if other != self and is_instance_valid(other._target):
			claimed.append(other._target)
			lab_trips += int(other.research)
	var bay := get_tree().get_first_node_in_group(&"qa_bay") as QaBay
	# A research hand only sets off for a free bench nobody else is already carrying a unit to.
	if research and (bay == null or not bay.has_room() or lab_trips >= save.qa_slots):
		return false
	_target = pick_target(get_tree().get_nodes_in_group(&"cabbages"), from, Hand.held, claimed, skips_rotten(save),
			research, save.stamped.has("lab_priority"), takes_golden(save, research), HandSchedule.forbidden(save, research))
	if _target == null:
		return false
	if research:
		_aim = bay_aim(bay.mouth(), randf_range(-1, 1))
		_release = bay.mouth() + RESEARCH_RELEASE
		_lob = BAY_LOB
		_phase = Phase.REACH
		return true
	var bin := bin_for(_target, save.hands_bin, get_tree().get_first_node_in_group(&"rotten_bin") as RottenBin)
	_binning = bin != null
	if bin != null:
		_aim = bin.hand_aim()
		_release = Vector3(_aim.x + BIN_RELEASE.x + randf_range(-0.05, 0.05), RELEASE_Y, _aim.z + BIN_RELEASE.z)
	else:
		_aim = aim_at(randf(), Vector2(randf_range(-1, 1), randf_range(-1, 1)))
		_release = Vector3(_aim.x + randf_range(-0.1, 0.1), RELEASE_Y, RELEASE_Z)
	_lob = LOB_TIME + randf_range(-LOB_JITTER, LOB_JITTER)
	_phase = Phase.REACH
	return true


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
	_target.lobbed = true
	_thrown += 1
	_target.linear_velocity = Feeder.ballistic_velocity(from, _aim, _lob)
	if _binning:
		_target.aim_for_bin(_lob + 0.5)
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


## Puts the hand's anchor on `at`. HandModel places its anchor as if this node were unturned, so a
## turned hand (park_turn) shifts the target by the turned part of the anchor.
func _place(at: Vector3, delta: float) -> void:
	var anchor := _model.basis * (HandModel.ANCHORS[_model.pose] as Vector3)
	_model.move_to(at + anchor - global_basis * anchor, delta)


## Moves the fingertip toward `to`; true once it is there.
func _move(to: Vector3, speed: float, delta: float) -> bool:
	_tip = _tip.move_toward(to, speed * SaveManager.save.associate_speed * delta)
	return _tip.is_equal_approx(to)


func _wobble() -> Vector3:
	return Vector3(sin(_time * 3.1), 0.5 * sin(_time * 4.3), cos(_time * 2.7)) * WOBBLE
