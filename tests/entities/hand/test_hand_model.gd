extends Node
## Run: Godot --headless --path . res://tests/entities/hand/test_hand_model.tscn
## Exit code 1 on failure.

var _failed := false


func _ready() -> void:
	var P := HandModel.Pose
	_check(HandModel.pose_for(false, false) == P.POINT, "idle should point")
	_check(HandModel.pose_for(false, true) == P.OPEN, "hover should open")
	_check(HandModel.pose_for(true, true) == P.GRAB and HandModel.pose_for(true, false) == P.GRAB, "holding should grab")
	_check(HandModel.pose_for(false, true, true) == P.POINT and HandModel.pose_for(true, true, true) == P.POINT, "buttons should be pointed at")
	_check(HandModel.pose_for(false, true, false, true) == P.PINCH and HandModel.pose_for(true, true, false, true) == P.PINCH, "paper should be pinched")
	_check(HandModel.pose_for(false, false, false, true) == P.POINT, "carried only while hovered or held")
	_check(HandModel.pose_for(false, true, false, false, true) == P.REACH and HandModel.pose_for(true, true, false, false, true) == P.GRAB, "handles are half gripped on hover, gripped when held")
	_check(Hand.tap_lift(0.0, false) > Hand.tap_lift(PI / Hand.TAP_SPEED, false), "the fingertip should tap up and down")
	_check(Hand.tap_lift(0.0, true) < 0.0, "a held button should be pressed in")

	# A negative curl bends a finger (pointing -Z) down; spread turns it toward the thumb (-X).
	var tip := HandModel.segment_rotation(0, 1, -90, 0) * Vector3.FORWARD
	_check(tip.is_equal_approx(Vector3.DOWN), "curl should bend down: %s" % tip)
	_check((HandModel.segment_rotation(0, 0, 0, 20) * Vector3.FORWARD).x < 0.0, "spread should open toward the thumb")
	var thumb := Vector3.FORWARD.rotated(Vector3.UP, HandModel.THUMB_YAW)
	_check((HandModel.segment_rotation(HandModel.THUMB, 0, -60, 0) * thumb).y < -0.8, "thumb curl should bend down")

	# Pointing: index out, the rest curled. Holding: every finger wraps.
	var point: Array = HandModel.POSES[P.POINT]
	_check(point[0][0] + point[0][1] + point[0][2] > -60, "index should stay out when pointing")
	for f in [1, 2]:
		_check(point[f][0] + point[f][1] < -120, "finger %d should be curled when pointing" % f)
	for f in HandModel.FINGERS.size():
		var grab: Array = HandModel.POSES[P.GRAB][f]
		var open: Array = HandModel.POSES[P.OPEN][f]
		_check(grab[0] + grab[1] < open[0] + open[1] - 40, "finger %d should close when grabbing" % f)

	# Blending lands on the target; sway leans with motion and is capped.
	_check(HandModel.blend(HandModel.POSES[P.POINT], HandModel.POSES[P.GRAB], 1.0) == HandModel.POSES[P.GRAB].map(
			func(row: Array) -> Array: return row.map(func(v: int) -> float: return float(v))), "blend t=1 should be the target")
	_check(HandModel.sway(Vector3.ZERO) == Vector3.ZERO, "still hand should not lean")
	_check(HandModel.sway(Vector3(2, 0, 0)).z < 0.0, "moving right should roll right")
	_check(HandModel.sway(Vector3(500, 0, -500)).abs().x <= HandModel.MAX_SWAY + 0.001, "sway should be capped")
	_check(HandModel.squash(0.0) == Vector3.ONE, "no punch should leave the hand unscaled")
	_check(HandModel.squash(1.0).y < 1.0 and HandModel.squash(1.0).x > 1.0, "a clench should flatten and widen")
	# The hidden mouse is reined in to the hand: never further than the limit, untouched inside it.
	var a := Vector3(1, 0.9, 0)
	_check(Hand.rein(a, Vector3(1.05, 0.9, 0), 0.1) == Vector3(1.05, 0.9, 0), "a mouse inside the limit stays put")
	_check(Hand.rein(a, Vector3(0, 0.9, 0), 0.1).is_equal_approx(Vector3(0.9, 0.9, 0)), "a mouse past a wall is pulled back")
	print("hand model tests failed" if _failed else "hand model tests passed")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
