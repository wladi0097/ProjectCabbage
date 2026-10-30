class_name Cabbage
extends RigidBody3D
## One unit of stock, and heavy: held, it accelerates toward the hand with capped force and
## speed, so a throw needs a deliberate drag. Let go and it keeps the momentum it built up.
## Out through the window gap is a sale; the SaleWindow marks it sold.

signal flicked(speed: float)
signal bumped(speed: float)

const MESHES: Array[Mesh] = [
	preload("res://assets/meshes/Props/cabbage_a.res"),
	preload("res://assets/meshes/Props/cabbage_b.res"),
	preload("res://assets/meshes/Props/cabbage_c.res"),
]
const HOLD_HEIGHT := 0.9
## The held cabbage stays on the room side of the window wall.
const NEAREST_WALL_Z := -0.68

## How hard it is pulled toward the hand per metre of lag.
@export var follow := 18.0
## Acceleration cap (m/s²): the weight. Lower = heavier.
@export var max_accel := 60.0
## Carry speed cap (m/s). The window needs about 3.5 from the bottom half of the mat.
@export var max_speed := 5.5

var sold := false
var _held := false


func _ready() -> void:
	$Mesh.mesh = MESHES.pick_random()
	$Mesh.basis = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU).scaled(Vector3.ONE * 1.5)
	$Interactable.grabbed.connect(_on_grabbed)
	$Interactable.released.connect(_on_released)
	body_entered.connect(func(_body: Node) -> void: bumped.emit(linear_velocity.length()))
	bumped.connect(func(speed: float) -> void: $Bump.cue(global_position, speed))
	$Interactable.grabbed.connect(func() -> void: $Grab.cue(global_position))


func _physics_process(delta: float) -> void:
	if not _held:
		return
	var target := Hand.point_on_height(HOLD_HEIGHT)
	target.z = maxf(target.z, NEAREST_WALL_Z)
	linear_velocity = carry_velocity(linear_velocity, target - global_position, delta, follow, max_accel, max_speed)


static func carry_velocity(velocity: Vector3, to_target: Vector3, delta: float, pull: float,
		accel: float, top_speed: float) -> Vector3:
	return velocity.move_toward((to_target * pull).limit_length(top_speed), accel * delta)


## Sold: the hand lets go, nothing can grab it, and it is pulled out through the gap to `to`
## (out of sight in the street) instead of dropping onto the pavement.
func suck_out(to: Vector3, time: float) -> void:
	sold = true
	_held = false
	$Interactable.enabled = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_mask = 0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", to, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", rotation + Vector3(-TAU, randf_range(-1, 1), 0), time)
	tween.chain().tween_callback(queue_free)


func _on_grabbed() -> void:
	_held = true
	gravity_scale = 0.0
	angular_velocity *= 0.3


func _on_released() -> void:
	_held = false
	gravity_scale = 1.0
	flicked.emit(linear_velocity.length())
