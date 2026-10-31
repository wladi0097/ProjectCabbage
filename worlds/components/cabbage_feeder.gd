extends Node3D
## The metal ramp in the bottom-right corner. This node sits at the ramp's lip. While there is
## stock left that isn't on the mat yet, and the mat holds fewer than the save's desk_capacity,
## it rolls the next cabbage down the ramp every dispense_interval and flings it off the lip
## onto the bottom half of the mat; after a sale the next one waits restock_wait first. The drum bar
## on its front rail rolls to the stock.

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

## Where the ramp starts, off-screen, relative to the lip.
@export var ramp_top := Vector3(0.65, 0.3, 0.12)
@export var landing_area := AABB(Vector3(0.2, 0.85, 0.3), Vector3(0.8, 0.0, 0.45))

var _on_desk: Array[Cabbage] = []
var _cooldown := 0.0
var _shown := 0.0
var _drums := PackedInt32Array()

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
	var before := _on_desk.size()
	_on_desk = _on_desk.filter(func(c: Cabbage) -> bool: return is_instance_valid(c) and not c.sold)
	_cooldown -= delta
	if _on_desk.size() < before:
		_cooldown = maxf(_cooldown, restock_wait(save.restock_delay, randf()))
	if _cooldown > 0.0 or not should_dispense(_on_desk.size(), save.desk_capacity, save.stock):
		return
	_cooldown = save.dispense_interval
	_roll()


## The wait after a sale: `roll` (0..1) spreads it over 0.5..1.5 of the save's mean `delay`.
static func restock_wait(delay: float, roll: float) -> float:
	return delay * (0.5 + roll)


## Room on the mat, and stock that isn't on it yet.
static func should_dispense(on_desk: int, capacity: int, stock: int) -> bool:
	return on_desk < capacity and on_desk < stock


func _roll() -> void:
	var cabbage := CABBAGE.instantiate() as Cabbage
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
	roll.chain().tween_callback(_fling.bind(cabbage, interactable))
	$Roll.cue($Roll.global_position)


func _fling(cabbage: Cabbage, interactable: Interactable) -> void:
	if not is_instance_valid(cabbage):
		return
	interactable.enabled = true
	cabbage.in_flight = true
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
