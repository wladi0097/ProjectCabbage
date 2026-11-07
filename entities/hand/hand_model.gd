class_name HandModel
extends Node3D
## The player's hand on screen, a cartoon clerk's glove in cold grey (three fingers and a
## thumb). Points when idle, opens over something grabbable, closes on what it holds, pinches
## paper by its corner, and leans after the mouse.
## The Hand autoload says where and which pose.

enum Pose { POINT, OPEN, GRAB, PINCH, REACH }

const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Thumb"]
const THUMB := 3
## Per finger: curl of segments 1..3 (degrees, negative bends down toward the palm side) and
## the spread of segment 1 (degrees about up, positive toward the thumb).
const POSES := {
	Pose.POINT: [[-12, -5, -3, 4], [-75, -65, -35, 0], [-75, -65, -35, -4], [-35, -30, -20, -40]],
	Pose.OPEN: [[-14, -12, -8, 16], [-10, -12, -8, 0], [-14, -14, -8, -16], [-12, -6, 0, 28]],
	Pose.GRAB: [[-55, -40, -28, 12], [-55, -40, -28, 0], [-55, -40, -28, -12], [-55, -30, -20, 10]],
	Pose.PINCH: [[-75, -68, -45, 6], [-80, -70, -40, 0], [-85, -72, -42, -6], [-20, -12, -6, -45]],
	Pose.REACH: [[-32, -22, -14, 14], [-32, -22, -14, 0], [-32, -22, -14, -14], [-34, -18, -10, 20]],
}
## The thumb's rest direction in the Blender build: forward and out to the left.
const THUMB_YAW := deg_to_rad(40.0)
## The point of the hand that sits on the target, per pose (model space): the index tip
## when pointing, the underside of the palm when open, the knuckles when holding (so the
## fingers wrap the far side of the cabbage), where index and thumb tips meet when pinching.
const ANCHORS := {
	Pose.POINT: Vector3(-0.034, -0.012, -0.160),
	Pose.OPEN: Vector3(0.0, -0.021, -0.055),
	Pose.GRAB: Vector3(0.0, -0.021, -0.066),
	Pose.PINCH: Vector3(-0.037, -0.036, -0.090),
	Pose.REACH: Vector3(0.0, -0.021, -0.066),
}
## Whole-hand pitch per pose (radians, negative tips the fingers down toward the desk).
## The pointing finger stays shallower than the camera's 61 deg look-down, or the knuckles hide it.
const PITCH := { Pose.POINT: deg_to_rad(-22.0) }
## Whole-hand yaw per pose (0 if not listed): pinching comes in from the lower left, fingers up and right.
const YAW := { Pose.PINCH: deg_to_rad(-35.0) }
const POSE_SPEED := 16.0
const SWAY_SPEED := 9.0
## Radians of lean per m/s of hand speed, and the most it ever leans.
const SWAY_GAIN := 0.14
const MAX_SWAY := 0.6
## Cartoon squash when the hand changes pose: how hard per pose, and how fast it settles.
const PUNCH := { Pose.POINT: 0.3, Pose.OPEN: -0.5, Pose.GRAB: 1.0, Pose.PINCH: 0.6, Pose.REACH: 0.4 }
const PUNCH_SPEED := 10.0
## Seconds after a pose change until the blend is done (exp(-POSE_SPEED * 1.5) ~ 4e-11): the fingers
## then snap to the pose exactly and the skeleton is left alone until the next change.
const SETTLE_TIME := 1.5

var pose := Pose.POINT:
	set(value):
		if value != pose:
			_punch = PUNCH[value]
			_settling = SETTLE_TIME
		pose = value
## Uniform scale about the anchor (the hired hands are half size).
var size := 1.0
var _punch := 0.0
var _angles: Array = POSES[Pose.POINT].duplicate(true)
var _anchor: Vector3 = ANCHORS[Pose.POINT]
var _pitch: float = PITCH.get(Pose.POINT, 0.0)
var _yaw := 0.0
var _sway := Vector3.ZERO
var _last_target := Vector3.ZERO
var _bones: Array[PackedInt32Array] = []
var _sleeve := -1
## Seconds of pose blend left (SETTLE_TIME); 0 once the fingers sit exactly on the pose.
var _settling := 0.0

@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D


func _ready() -> void:
	for finger in FINGERS:
		_bones.append(PackedInt32Array([1, 2, 3].map(func(i: int) -> int:
				return _skeleton.find_bone("%s%d" % [finger, i]))))
	_sleeve = _skeleton.find_bone("Sleeve")
	_apply_angles()


## Puts `anchor` of the current pose on `target`, leaning with the motion since last frame.
func move_to(target: Vector3, delta: float) -> void:
	if delta > 0.0:
		var velocity := (target - _last_target) / delta if _last_target != Vector3.ZERO else Vector3.ZERO
		_sway = _sway.lerp(sway(velocity), 1.0 - exp(-SWAY_SPEED * delta))
		if _settling > 0.0:
			_settling -= delta
			# Done blending: land on the pose exactly (one last skeleton update).
			var t := 1.0 if _settling <= 0.0 else 1.0 - exp(-POSE_SPEED * delta)
			_anchor = _anchor.lerp(ANCHORS[pose], t)
			_pitch = lerpf(_pitch, PITCH.get(pose, 0.0), t)
			_yaw = lerpf(_yaw, YAW.get(pose, 0.0), t)
			_angles = blend(_angles, POSES[pose], t)
			_apply_angles()
		_punch *= exp(-PUNCH_SPEED * delta)
	_last_target = target
	basis = Basis.from_euler(_sway + Vector3(_pitch, _yaw, 0.0)) * Basis.from_scale(squash(_punch) * size)
	global_position = target - basis * _anchor


## Buttons (`pressing`) are pointed at and pressed with the index, never grabbed; paper
## (`carrying`) is pinched by a corner, and handles (`reaching`) are already half gripped
## while hovered.
static func pose_for(holding: bool, hovering: bool, pressing := false, carrying := false, reaching := false) -> Pose:
	if carrying and (holding or hovering):
		return Pose.PINCH
	if reaching and hovering and not holding:
		return Pose.REACH
	return Pose.POINT if pressing else Pose.GRAB if holding else Pose.OPEN if hovering else Pose.POINT


## Lean as Euler angles: moving forward tips the fingers down, sideways rolls the hand
## and turns it a little into the motion, like a hand dragged by its wrist.
static func sway(velocity: Vector3) -> Vector3:
	var lean := Vector3(velocity.z, -velocity.x * 0.5, -velocity.x) * SWAY_GAIN
	return lean.clamp(-Vector3.ONE * MAX_SWAY, Vector3.ONE * MAX_SWAY)


## Volume-ish squash: positive flattens and widens (a clench), negative stretches (a pop).
static func squash(punch: float) -> Vector3:
	return Vector3(1.0 + 0.08 * punch, 1.0 - 0.14 * punch, 1.0 + 0.04 * punch)


## Rotation of one finger segment for a curl and (segment 0 only) a spread, in degrees.
static func segment_rotation(finger: int, segment: int, curl: float, spread: float) -> Quaternion:
	var side := Vector3.RIGHT.rotated(Vector3.UP, THUMB_YAW) if finger == THUMB else Vector3.RIGHT
	var q := Quaternion(side, deg_to_rad(curl))
	if segment == 0:
		q = Quaternion(Vector3.UP, deg_to_rad(spread)) * q
	return q


static func blend(from: Array, to: Array, t: float) -> Array:
	var out := []
	for f in from.size():
		out.append(range(4).map(func(k: int) -> float: return lerpf(from[f][k], to[f][k], t)))
	return out


func _apply_angles() -> void:
	# the sleeve stays level while the glove pitches
	_skeleton.set_bone_pose_rotation(_sleeve, Quaternion(Vector3.RIGHT, -_pitch))
	for f in FINGERS.size():
		for s in 3:
			var bone := _bones[f][s]
			var rest := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			_skeleton.set_bone_pose_rotation(bone, segment_rotation(f, s, _angles[f][s], _angles[f][3]) * rest)
