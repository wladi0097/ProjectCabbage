class_name TallyMachine
extends Node3D
## The coin tally machine. Its nine number drums show the saved coin total. When the total moves,
## the shown value rolls toward it (faster the further behind it is) and carries like a real
## odometer: a drum only turns while every drum to its right rolls from 9 to 0.

## Once per frame in which the ones drum passed a whole number (the tick sound hooks in here).
signal ticked

const DRUMS := 9
## Units per second the drums roll at least, plus this much per unit still to go.
const MIN_RATE := 8.0
const CATCH_UP := 4.0

var _shown := 0.0
var _bones := PackedInt32Array()

@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _tick: SoundCue = $Tick


func _ready() -> void:
	for k in DRUMS:
		_bones.append(_skeleton.find_bone("Drum%d" % k))
	_shown = SaveManager.save.coins
	_pose()


func _process(delta: float) -> void:
	var target := float(SaveManager.save.coins)
	if _shown == target:
		return
	var before := floori(_shown)
	_shown = move_toward(_shown, target, (MIN_RATE + absf(target - _shown) * CATCH_UP) * delta)
	if floori(_shown) != before:
		ticked.emit()
		_tick.cue(_tick.global_position)
	_pose()


func _pose() -> void:
	var positions := drum_positions(_shown, DRUMS)
	for k in DRUMS:
		_skeleton.set_bone_pose_rotation(_bones[k], Quaternion(Vector3.RIGHT, deg_to_rad(positions[k] * 36.0)))


## Digit each drum faces, fractional while rolling (Drum0 = ones). Drum k shows digit d at d * 36°.
static func drum_positions(value: float, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	value = fmod(maxf(value, 0.0), pow(10.0, count))
	for k in count:
		var place := pow(10.0, k)
		var below := fmod(value, place)
		out.append(fmod(floorf(value / place), 10.0) + maxf(below - (place - 1.0), 0.0))
	return out
