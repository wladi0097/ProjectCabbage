class_name FieldLine
extends Node3D
## The FIELD LINE (chapter 3, on the supply console's plinth): a switchboard box with a jewel lamp
## for every farm of the district (LAMPS, lit dull oxblood for the farms the company holds), a
## count window ("7/24") on the front slope, and a telephone handset in a cradle on the deck behind
## them (the far side, up the screen: where the hand comes from). Lifting the handset opens the line
## (line_opened: the game goes to the maps); the game hangs it up again (hang_up) when it is back.
## It only shows and reports: it knows nothing of the save, the camera or the map table.
## Sound moments, one cue each (streams in the scene): Lift (the handset leaves the cradle),
## LineOpen (it is up: the line clicks open), HangUp (it lands back in the rings), Relay (one per
## lamp that lights) and Land (the machine drops onto the desk; the old console's drop, higher).

## The handset is up and the line open, once per lift: at the top of the lift, not at the click.
signal line_opened

const LAMPS := 24
## Seconds between two lamps lighting when the count rises: a relay clicking through.
const RELAY_STEP := 0.09
## The lifted handset, from its cradle (Godot space, m and rad about up): it rises straight up and
## swings its left end forward, baring the rings and the hook switch. It does not come toward the
## player: the lamps lie in front of it and it would hang over them.
const LIFT := Vector3(-0.012, 0.05, 0.0)
const SWING := 0.35
## How much of the lift a hovering hand already gives it (it stirs in the cradle, and half as much of the swing).
const HOVER := 0.4
const RISE_TIME := 0.28
const SWING_TIME := 0.36
## The swing starts this long after the rise, so the two overlap instead of moving as one block.
const SWING_LAG := 0.07
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45

## 0 in the cradle, 1 lifted (above 1 while it overshoots); the same for the swing.
var _rise := 0.0:
	set(value):
		_rise = value
		_pose()
var _swing := 0.0:
	set(value):
		_swing = value
		_pose()
var _open := false
var _lit := 0
var _moving: Tween
var _relay: Tween

@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _receiver := _skeleton.find_bone("Receiver")
@onready var _lamps: MeshInstance3D = $Model/Lamps
@onready var _count: Label3D = $Count
@onready var _handset: Interactable = $Model/Armature/Skeleton3D/ReceiverMount/Handset/Interactable
@onready var _rest := position
@onready var _lift_sound: SoundCue = $Lift
@onready var _open_sound: SoundCue = $LineOpen
@onready var _hang_sound: SoundCue = $HangUp
@onready var _relay_sound: SoundCue = $Relay
@onready var _land_sound: SoundCue = $Land


func _ready() -> void:
	_handset.grabbed.connect(lift)
	_handset.hovered.connect(_stir.bind(HOVER))
	_handset.unhovered.connect(_stir.bind(0.0))
	_pose()
	_light(_lit)


## How many of the lamps glow with `owned` farms: one each, never more than there are lamps.
static func lamps_lit(owned: int) -> int:
	return clampi(owned, 0, LAMPS)


## The count window's text.
static func count_text(owned: int, total: int) -> String:
	return "%d/%d" % [owned, total]


## Where the handset is, from its cradle, at `rise` and `swing` (0 down, 1 lifted).
static func handset_offset(rise: float, swing: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, SWING * swing), LIFT * rise)


## Shows `owned` of `total` farms: the window reads "owned/total" and the first `owned` lamps glow.
## A rising count lights its new lamps one after the other; a loaded save passes `animate` false.
func show_farms(owned: int, total: int, animate := true) -> void:
	_count.text = count_text(owned, total)
	var target := lamps_lit(owned)
	if _relay != null:
		_relay.kill()
	if not animate or target <= _lit:
		_light(target)
		return
	_relay = create_tween()
	for n in range(_lit + 1, target + 1):
		_relay.tween_callback(_light.bind(n))
		_relay.tween_callback(_relay_sound.cue.bind(global_position))
		_relay.tween_interval(RELAY_STEP)


## The lamps glowing now.
func lit() -> int:
	return _lit


## Whether the handset is off the cradle.
func is_open() -> bool:
	return _open


## The handset comes off the cradle (a click on it); the line opens when it is up.
func lift() -> void:
	if _open:
		return
	_open = true
	_lift_sound.cue(global_position)
	_move()
	_moving.tween_property(self, "_rise", 1.0, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_moving.tween_property(self, "_swing", 1.0, SWING_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(SWING_LAG)
	_moving.chain().tween_callback(func() -> void:
		_open_sound.cue(global_position)
		line_opened.emit())


## Puts the handset back in its cradle: it squares up, drops into the rings and settles.
func hang_up() -> void:
	if not _open:
		return
	_open = false
	_move()
	_moving.tween_property(self, "_swing", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_moving.tween_property(self, "_rise", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_moving.chain().tween_callback(_hang_sound.cue.bind(global_position))
	_moving.tween_property(self, "_rise", 0.07, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_moving.chain().tween_property(self, "_rise", 0.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## The machine falls onto the desk from above and lands with a squash (its arrival in chapter 3).
func drop_in() -> void:
	position = _rest + Vector3.UP * DROP_HEIGHT
	var fall := create_tween()
	fall.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(_land_sound.cue.bind(global_position))
	fall.tween_property($Model, "scale", Vector3(1.08, 0.86, 1.08), 0.06)
	fall.tween_property($Model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A hovering hand makes the handset stir in its cradle; a lifted one stays where it is.
func _stir(rise: float) -> void:
	if _open:
		return
	_move()
	_moving.tween_property(self, "_rise", rise, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_moving.tween_property(self, "_swing", rise * 0.5, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _move() -> void:
	if _moving != null:
		_moving.kill()
	_moving = create_tween().set_parallel()


func _light(lamps: int) -> void:
	_lit = lamps
	_lamps.set_instance_shader_parameter(&"lit", float(lamps))


func _pose() -> void:
	if not is_node_ready():
		return
	var rest := _skeleton.get_bone_rest(_receiver)
	var offset := handset_offset(_rise, _swing)
	_skeleton.set_bone_pose_position(_receiver, rest.origin + offset.origin)
	_skeleton.set_bone_pose_rotation(_receiver, offset.basis.get_rotation_quaternion() * rest.basis.get_rotation_quaternion())
