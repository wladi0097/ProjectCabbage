class_name ChuteLever
extends Node3D
## The supply interruption lever (desk card chute_control, dealt after off-site storage): a steel flap hangs from an axle across the chute,
## a heavy lever on the axle's front end. Clicked, the lever swings down and the flap drops onto the
## chute (save.chute_blocked): the feeder sends nothing more and stock piles up. Clicked again it
## swings up and the flap is hauled back up, clear of the units rolling under it. Units already on
## the chute or the mat are left alone. Absent until the card is stamped, then drops onto the chute.
## Its own frame: x up the chute, y world up, z across it (front +z); the world scene places it.

const CARD := "chute_control"
## The arm's turn about the hub (rad): up while open, pulled down to level (toward the mat) while
## shut, so it never hangs over the stock counter below.
const OPEN_ANGLE := 0.95
const PULLED_ANGLE := 1.55
const SWING_TIME := 0.3
## The flap's turn about the axle: hanging straight down across the chute while shut; while open
## swung out to the screen's right (up the chute, away from the mat), lying a little above level.
## (It once swung left, over the mat end; the user wants the mat side clear. The old tall growing
## station that made up-chute a problem is now a low collar.)
const FLAP_SHUT := 0.0
const FLAP_OPEN := 1.75
## It falls in DROP_TIME and rebounds BOUNCE (rad); it is hauled up in LIFT_TIME.
const DROP_TIME := 0.22
const BOUNCE := 0.07
const LIFT_TIME := 0.8
const ARRIVE_HEIGHT := 1.6
const ARRIVE_TIME := 0.45

var _tween: Tween

@onready var _arm: Node3D = $Arm
@onready var _flap: Node3D = $Flap
@onready var _rest := position
@onready var _shape: CollisionShape3D = $Arm/Handle/Shape
@onready var _shut_sound: AudioStreamPlayer3D = $Flap/Shut
@onready var _lift_sound: AudioStreamPlayer3D = $Flap/Lift
@onready var _land_sound: AudioStreamPlayer3D = $Land


func _ready() -> void:
	($Arm/Handle/Interactable as Interactable).grabbed.connect(pull)
	var save := SaveManager.save
	_show(bought(save))
	_arm.rotation.z = lever_angle(save.chute_blocked)
	_flap.rotation.z = flap_angle(save.chute_blocked)


func _process(_delta: float) -> void:
	if not visible and bought(SaveManager.save):
		_arrive()


static func bought(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## The arm's turn with the chute `blocked` or open.
static func lever_angle(blocked: bool) -> float:
	return PULLED_ANGLE if blocked else OPEN_ANGLE


## The flap's turn with the chute `blocked` (hanging across it) or open (swung out to the right).
static func flap_angle(blocked: bool) -> float:
	return FLAP_SHUT if blocked else FLAP_OPEN


## Flips the chute: pulled down it shuts, pulled up it opens.
func pull() -> void:
	var save := SaveManager.save
	save.chute_blocked = not save.chute_blocked
	var blocked := save.chute_blocked
	if _tween != null:
		_tween.kill()
	# One file per direction, timed to the tween below: shut = latch at the swing's end, slam at
	# SWING_TIME + DROP_TIME; lift = latch, ratchet while the flap rises, stop at 0.1 + LIFT_TIME.
	_lift_sound.stop()
	_shut_sound.stop()
	(_shut_sound if blocked else _lift_sound).play()
	_tween = create_tween()
	_tween.tween_property(_arm, "rotation:z", lever_angle(blocked), SWING_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if blocked:
		# The latch lets go at the bottom of the swing: the flap falls, slams, settles.
		_tween.tween_property(_flap, "rotation:z", FLAP_SHUT, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# The rebound kicks back toward the side it fell from.
		_tween.tween_property(_flap, "rotation:z", FLAP_SHUT + BOUNCE * signf(FLAP_OPEN), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_flap, "rotation:z", FLAP_SHUT, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		_tween.parallel().tween_property(_flap, "rotation:z", FLAP_OPEN, LIFT_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)


func _arrive() -> void:
	_show(true)
	position = _rest + Vector3.UP * ARRIVE_HEIGHT
	# The file's thunk sits at ARRIVE_TIME, where the fall ends on the chute.
	_land_sound.play()
	create_tween().tween_property(self, "position", _rest, ARRIVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Hidden, its handle must not catch the hand.
func _show(on: bool) -> void:
	visible = on
	_shape.disabled = not on
