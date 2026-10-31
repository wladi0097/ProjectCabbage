class_name Cabbage
extends RigidBody3D
## One unit of stock, and heavy: held, it accelerates toward the hand with capped force and
## speed, so a throw needs a deliberate drag. Let go and it keeps the momentum it built up.
## Out through the window gap is a sale; the SaleWindow marks it sold, or sends it out and back
## when the street refuses it (`away` meanwhile). Every cabbage is in the "cabbages" group.
## A rotten one (set before it enters the tree) is grey and slumped: sold, it is fined (SaleWindow);
## binned, it is gone (RottenBin). A mid-air catch calls `caught` on the "catch_combo" group.

signal bumped(speed: float)

const MESHES: Array[Mesh] = [
	preload("res://assets/meshes/Props/cabbage_a.res"),
	preload("res://assets/meshes/Props/cabbage_b.res"),
	preload("res://assets/meshes/Props/cabbage_c.res"),
]
const HOLD_HEIGHT := 0.9
## The held cabbage stays on the room side of the window wall.
const NEAREST_WALL_Z := -0.68
## Each cabbage is up to this much smaller or bigger (mesh, collider and mass).
const SIZE_SPREAD := 0.1
## How flat a grab squashes it (0.18 = 18% lower, wider to match), springing back over SQUISH_TIME.
const SQUISH := 0.18
const SQUISH_TIME := 0.6
const ROTTEN_MATERIAL := preload("res://assets/materials/cabbage_rotten.tres")
## A rotten one sags: this much lower, a little wider.
const SLUMP := Vector3(1.08, 0.78, 1.08)

## How hard it is pulled toward the hand per metre of lag.
@export var follow := 18.0
## Acceleration cap (m/s²): the weight. Lower = heavier.
@export var max_accel := 60.0
## Carry speed cap (m/s). The window needs about 3.5 from the bottom half of the mat.
@export var max_speed := 5.5

var sold := false
var rotten := false
## Out of the window or on its way back after a refusal: the SaleWindow leaves it alone.
var away := false
## Seconds the SaleWindow has seen it off the mat in a row.
var stray_time := 0.0
## Flung off the chute and not yet touching anything: grabbing it now is a catch.
var in_flight := false:
	set(flying):
		in_flight = flying
		$Interactable.catchable = flying
var _held := false
var _look := Basis()
var _squishing: Tween
var _squish := 0.0:
	set(amount):
		_squish = amount
		# Squashed along the world's up (the hand presses from above), however the body is turned.
		var turn := global_basis.orthonormalized()
		$Mesh.basis = turn.inverse() * Basis.from_scale(squish_scale(amount)) * turn * _look


@onready var _layer := collision_layer
@onready var _mask := collision_mask


func _ready() -> void:
	add_to_group(&"cabbages")
	$Mesh.mesh = MESHES.pick_random()
	var size := randf_range(1.0 - SIZE_SPREAD, 1.0 + SIZE_SPREAD)
	_look = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU).scaled(Vector3.ONE * 1.5 * size)
	if rotten:
		$Mesh.material_override = ROTTEN_MATERIAL
		_look = Basis.from_scale(SLUMP) * _look
	$Mesh.basis = _look
	var ball := $Shape.shape.duplicate() as SphereShape3D
	ball.radius *= size
	$Shape.shape = ball
	mass *= size * size * size
	$Interactable.grabbed.connect(_on_grabbed)
	$Interactable.released.connect(_on_released)
	body_entered.connect(func(_body: Node) -> void:
		in_flight = false
		bumped.emit(linear_velocity.length()))
	bumped.connect(func(speed: float) -> void: $Bump.cue(global_position, speed))
	$Interactable.grabbed.connect(func() -> void: $Grab.cue(global_position))


func _physics_process(delta: float) -> void:
	if not _held:
		return
	var target := Hand.point_on_height(HOLD_HEIGHT)
	target.z = maxf(target.z, NEAREST_WALL_Z)
	linear_velocity = carry_velocity(linear_velocity, target - global_position, delta, follow, max_accel, max_speed)


## The grab squash `time` seconds in: pressed flat, springing back past round once, settling.
static func squish_at(time: float) -> float:
	return SQUISH * exp(-5.0 * time) * cos(10.0 * time) if time < SQUISH_TIME else 0.0


## Squashed down by `amount`, bulging sideways to keep roughly the same volume.
static func squish_scale(amount: float) -> Vector3:
	var wide := 1.0 / sqrt(1.0 - amount)
	return Vector3(wide, 1.0 - amount, wide)


static func carry_velocity(velocity: Vector3, to_target: Vector3, delta: float, pull: float,
		accel: float, top_speed: float) -> Vector3:
	return velocity.move_toward((to_target * pull).limit_length(top_speed), accel * delta)


## Sold: the hand lets go, nothing can grab it, and it is pulled out through the gap to `to`
## (out of sight in the street) instead of dropping onto the pavement.
func suck_out(to: Vector3, time: float) -> void:
	sold = true
	_pull_out(to, time).chain().tween_callback(queue_free)


## Refused: pulled out of the window like a sale, but kept (`away`) for throw_in to bring back.
func send_away(to: Vector3, time: float) -> void:
	away = true
	_pull_out(to, time)


## Thrown back in by the street from `from` at `velocity`. It passes through the window wall for
## `clear` seconds, can't be grabbed for a moment, and is the window's again after `landed` seconds.
func throw_in(from: Vector3, velocity: Vector3, clear: float, landed: float) -> void:
	global_position = from
	freeze = false
	gravity_scale = 1.0
	collision_layer = _layer
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	# One tween on the cabbage itself, so nothing fires after it is freed.
	var steps := create_tween().set_parallel()
	steps.tween_callback(func() -> void: collision_mask = _mask).set_delay(clear)
	steps.tween_callback(func() -> void: $Interactable.enabled = true).set_delay(0.3)
	steps.tween_callback(func() -> void: away = false).set_delay(landed)


## Torn from the hand, out of reach and out of the physics, pulled to `to` over `time`.
func _pull_out(to: Vector3, time: float) -> Tween:
	_held = false
	$Interactable.enabled = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", to, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", rotation + Vector3(-TAU, randf_range(-1, 1), 0), time)
	return tween


func _on_grabbed() -> void:
	if _squishing != null:
		_squishing.kill()
	_squishing = create_tween()
	_squishing.tween_method(func(time: float) -> void: _squish = squish_at(time), 0.0, SQUISH_TIME, SQUISH_TIME)
	if in_flight:
		in_flight = false
		SaveManager.save.catches += 1
		get_tree().call_group(&"catch_combo", &"caught", global_position)
	_held = true
	gravity_scale = 0.0
	angular_velocity *= 0.3


func _on_released() -> void:
	_held = false
	gravity_scale = 1.0
