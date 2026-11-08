extends Node3D
## The metal ramp in the bottom-right corner. This node sits at the ramp's lip. While there is
## stock left that isn't on the mat yet, and the mat holds fewer than the save's desk_capacity,
## it rolls the next cabbage down the ramp every dispense_interval and flings it off the lip
## onto the bottom half of the mat; after a sale the next one waits restock_wait first. The drum bar
## on its front rail rolls to the stock. Once rotten units are in (save.rotten_unlocked), one in
## ROTTEN_EVERY comes down rotten. Rotten units don't take up desk_capacity (the player may leave
## them on the mat, they must not stall the chute); while MAX_ROTTEN lie on the mat the chute
## sends fresh ones only, so they never pile up. Once the research_cabbage card is stamped, a fresh
## unit comes down a research unit with the save's research_chance (still stock, sold as usual).
## When that share grows (the card stamped, a sampling quota bought) a research unit comes down at
## once, even onto a full mat. While the chute lever is pulled (save.chute_blocked, card
## chute_control, entities/chute_lever/) nothing comes down: stock just piles up.

const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const PLAY_AREA_LAYER := 2
const ROLL_TIME := 0.4
const FLIGHT_TIME := 0.8
## Until then a tossed cabbage ignores the screen-edge walls (the ramp starts off-screen).
const ENTER_TIME := 0.3
const DRUMS := 4
## The drums lie along the chute's front wall and turn around its direction.
const DRUM_AXIS := Vector3(0.9062, 0.4122, 0.0943)
## Drum roll speed, as on the tally machine: units per second plus this much per unit to go.
const ROLL_RATE := 8.0
const CATCH_UP := 4.0
const ROTTEN_EVERY := 8
const MAX_ROTTEN := 2

## Where the ramp starts, off-screen, relative to the lip.
@export var ramp_top := Vector3(0.65, 0.3, 0.12)
@export var landing_area := AABB(Vector3(0.2, 0.85, 0.3), Vector3(0.8, 0.0, 0.45))

var _on_desk: Array[Cabbage] = []
var _rotten_on_desk := 0
var _cooldown := 0.0
var _shown := 0.0
var _drums := PackedInt32Array()
## The research share last seen (research_share); a rise owes the mat a research unit now.
var _research_share := research_share(SaveManager.save)
var _research_due := false

@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D


func _ready() -> void:
	for k in DRUMS:
		_drums.append(_skeleton.find_bone("Drum%d" % k))
	_shown = SaveManager.save.stock
	_pose_drums()


func _process(delta: float) -> void:
	var target := float(SaveManager.save.stock)
	if _shown != target:
		var before := floori(_shown)
		_shown = move_toward(_shown, target, (ROLL_RATE + absf(target - _shown) * CATCH_UP) * delta)
		if floori(_shown) != before:
			$Tick.cue($Tick.global_position)
		_pose_drums()


func _pose_drums() -> void:
	var positions := TallyMachine.drum_positions(_shown, DRUMS)
	for k in DRUMS:
		_skeleton.set_bone_pose_rotation(_drums[k], Quaternion(DRUM_AXIS.normalized(), deg_to_rad(positions[k] * 36.0)))


func _physics_process(delta: float) -> void:
	var save := SaveManager.save
	var gone := false
	_rotten_on_desk = 0
	for i in range(_on_desk.size() - 1, -1, -1):
		var cabbage := _on_desk[i]
		if not is_instance_valid(cabbage) or cabbage.sold:
			_on_desk.remove_at(i)
			gone = true
		elif cabbage.rotten:
			_rotten_on_desk += 1
	_cooldown -= delta
	if gone:
		_cooldown = maxf(_cooldown, restock_wait(save.restock_delay, randf()))
	var share := research_share(save)
	if share > _research_share:
		_research_due = true
		_cooldown = 0.0
	_research_share = share
	# A research unit owed comes down even onto a full mat (one over desk_capacity).
	var capacity := save.desk_capacity + (1 if _research_due else 0)
	if _cooldown > 0.0 or not should_dispense(_on_desk.size() - _rotten_on_desk, _on_desk.size(), capacity, save.stock, save.chute_blocked):
		return
	_cooldown = save.dispense_interval
	_roll()


## The wait after a sale: `roll` (0..1) spreads it over 0.5..1.5 of the save's mean `delay`.
static func restock_wait(delay: float, roll: float) -> float:
	return delay * (0.5 + roll)


## Whether the next unit comes down rotten: `rotten` already lie on the mat, `roll` is 0..1.
static func is_rotten(unlocked: bool, roll: float, rotten := 0) -> bool:
	return unlocked and rotten < MAX_ROTTEN and roll < 1.0 / ROTTEN_EVERY


## Whether the next (fresh) unit is a research unit: the card is `stamped`, `roll` is 0..1.
static func is_research(stamped: bool, roll: float, chance: float) -> bool:
	return stamped and roll < chance


## The share of units that come down research units: research_chance once the card is stamped, else 0.
static func research_share(save: SaveGame) -> float:
	return save.research_chance if save.stamped.has("research_cabbage") else 0.0


## Room on the mat for `fresh` units (rotten ones don't count), and stock that isn't on it yet
## (`on_desk` counts every unit there); never while the chute is `blocked`.
static func should_dispense(fresh: int, on_desk: int, capacity: int, stock: int, blocked := false) -> bool:
	return not blocked and fresh < capacity and on_desk < stock


func _roll() -> void:
	var cabbage := CABBAGE.instantiate() as Cabbage
	var save := SaveManager.save
	cabbage.rotten = not _research_due and is_rotten(save.rotten_unlocked, randf(), _rotten_on_desk)
	var owed := _research_due
	cabbage.research = owed or (not cabbage.rotten and is_research(save.stamped.has("research_cabbage"), randf(), save.research_chance))
	_research_due = false
	get_parent().add_child(cabbage)
	_on_desk.append(cabbage)
	var interactable := cabbage.get_node("Interactable") as Interactable
	interactable.enabled = false
	cabbage.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	cabbage.freeze = true
	cabbage.global_position = global_position + ramp_top
	var roll := create_tween().set_parallel()
	roll.tween_property(cabbage, "global_position", global_position, ROLL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	roll.tween_property(cabbage, "rotation", cabbage.rotation + Vector3(0, 0, TAU), ROLL_TIME)
	roll.chain().tween_callback(_fling.bind(cabbage, interactable, not owed))
	$Roll.cue($Roll.global_position)


## `catchable`: false for a research unit owed by a purchase (the player was busy paying for it), so
## it lands without counting as a miss.
func _fling(cabbage: Cabbage, interactable: Interactable, catchable := true) -> void:
	if not is_instance_valid(cabbage):
		return
	interactable.enabled = true
	cabbage.in_flight = catchable
	cabbage.collision_mask &= ~PLAY_AREA_LAYER
	cabbage.freeze = false
	var target := landing_area.position + Vector3(randf(), 0.0, randf()) * landing_area.size
	cabbage.linear_velocity = ballistic_velocity(global_position, target, FLIGHT_TIME)
	cabbage.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	get_tree().create_timer(ENTER_TIME, true, true).timeout.connect(func() -> void:
		if is_instance_valid(cabbage):
			cabbage.collision_mask |= PLAY_AREA_LAYER)


## The launch velocity that lands a body thrown from `from` on `to` after `time` under the project's gravity.
static func ballistic_velocity(from: Vector3, to: Vector3, time: float) -> Vector3:
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	return (to - from) / time - 0.5 * gravity * time
