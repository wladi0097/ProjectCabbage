class_name UpgradeCard
extends StaticBody3D
## One requisition form. Its front shows the heading and price, big enough to read in the tray;
## hovered in the tray, it lifts, grows, tips toward the camera and flips over to its back, which says
## what it does; hovered on the press, it tips its left edge up. The hand pinches it by its near
## left corner; held, the card hangs from that pinch, front up at normal size. Let go, it emits `dropped` and the UpgradeDesk
## decides where it goes. Every move is a short paper arc with a flutter, so cards never teleport.
## Cabbages pass through it (its own collision layer).

signal dropped(card: UpgradeCard)

const SIZE := Vector2(0.36, 0.2)
const LAYER := 8
const MATERIAL := preload("res://assets/materials/card_paper.tres")
const DRAG_HEIGHT := 0.9
## Hovered, the face lifts, grows and slides this far toward the screen's middle so it stays in view.
const HOVER_LIFT := 0.2
const HOVER_SCALE := 2.64
const HOVER_SHIFT := Vector3(0.2, 0.0, -0.25)
## It also tips its face up toward the camera (about the game camera's angle from straight down).
const HOVER_TILT := 0.5
## On the press it neither grows nor draws over the press: it slides a little left and tips its left
## edge up this many radians (the right edge stays on the pad), ready to pull out.
const PRESS_NUDGE := Vector3(-0.03, 0.0, 0.0)
const PRESS_TIP := 0.15
const HOVER_TIME := 0.14
const FLIP_TIME := 0.22
## A hovered card within PRESS_NEAR (flat distance) of the press pad gets the press nudge,
## beyond PRESS_FAR it gets the full big flip. Held, it eases back to its front at HOLD_EASE per second.
const PRESS_NEAR := 0.35
const PRESS_FAR := 1.2
const HOLD_EASE := 12.0
## Held, the card rises to DRAG_HEIGHT at this rate (per second); sideways it moves 1:1 with the hand.
const HOLD_RISE := 20.0
## A move takes FLY_TIME and arcs ARC high; dealt cards come from off-screen left, slower and higher.
const FLY_TIME := 0.3
const ARC := 0.12
const DEAL_FROM := Vector3(-1.75, 0.95, 0.6)
const DEAL_TIME := 0.55
const DEAL_ARC := 0.15
## Flutter: the paper rocks this many radians on the way, settling as it lands.
const FLUTTER := 0.35
const BLINK_TIME := 0.12
const SHAKE := 0.012
## Off-white print on dark carbon stock.
const INK := Color(0.9, 0.89, 0.84)
const STAMP_RED := Color(0.85, 0.18, 0.12)
const DENIED_RED := Color(0.9, 0.12, 0.08)
const TITLE_FONT := preload("res://assets/fonts/Oswald.ttf")
const BODY_FONT := preload("res://assets/fonts/NunitoSans.ttf")
## Fine pixels and big font sizes keep the text crisp when the card is enlarged.
const PIXEL := 0.0003
## The corner the hand pinches, in the card's look space (near left, a little in from the edges).
const PINCH_AT := Vector3(-0.165, 0.0, 0.085)

var id := ""
var price := 0
## The SaveGame field it is paid from: "coins" ($) or "findings" (¶).
var currency := "coins"
## The press pad (world space), set by the desk; hovered cards stay small near it.
var press_at := Vector3.INF

var _held := false
## Held: where the pinch sits relative to the mouse (flat), fixed at the grab so neither jumps.
var _grip := Vector3.ZERO
var _look := Node3D.new()
## Turned PI about X to show the back; the face turned away is hidden.
var _flip := Node3D.new()
var _front := Node3D.new()
var _back := Node3D.new()
var _heading: Label3D
var _price: Label3D
var _front_price: Label3D
var _stamp: Label3D
var _interactable := Interactable.new()
var _lifting: Tween
var _flipping: Tween
## The flip angle, kept here: rotation.x reads back as another Euler angle past 90 degrees.
var _flipped := 0.0
var _flying: Tween
var _blinking: Tween


func _init(card: Dictionary) -> void:
	id = card.id
	price = card.price
	currency = card.get("currency", "coins")
	collision_layer = LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(SIZE.x, 0.02, SIZE.y)
	add_child(shape)
	add_child(_look)
	_look.add_child(_flip)
	_flip.add_child(_front)
	_flip.add_child(_back)
	_back.rotation.x = PI
	_back.visible = false
	for face: Node3D in [_front, _back]:
		var paper := MeshInstance3D.new()
		paper.mesh = PlaneMesh.new()
		(paper.mesh as PlaneMesh).size = SIZE
		paper.material_override = MATERIAL
		face.add_child(paper)
		_text(face, "FORM 7-R  RESEARCH DIRECTIVE" if card.get("research", false) else "FORM 7-B  REQUISITION",
				Vector3(0, 0.002, -0.0825), 60, TITLE_FONT)
	# Long titles get a smaller face so they stay on two lines under the form header.
	_heading = _text(_front, card.title, Vector3(0, 0.002, -0.005), 150 if card.title.length() <= 20 else 118, TITLE_FONT, 0.33)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(_back, card.title, Vector3(-0.01, 0.002, -0.04), 64, TITLE_FONT, 0.29)
	var body := _text(_back, card.body, Vector3(-0.04, 0.002, 0.035), 72, BODY_FONT, 0.25)
	# The thin body face needs a same-colour outline to read at desk distance.
	body.outline_size = 8
	body.outline_modulate = INK
	_price = _text(_back, price_text(price, currency), Vector3(0.125, 0.002, 0.07), 140, TITLE_FONT)
	_front_price = _text(_front, price_text(price, currency), Vector3(0.135, 0.002, 0.075), 110, TITLE_FONT)
	_stamp = _text(_front, "APPROVED", Vector3(0.0, 0.003, 0.005), 220, TITLE_FONT)
	_stamp.modulate = STAMP_RED
	_stamp.rotation.z = 0.35
	_stamp.visible = false
	_interactable.carried = true
	add_child(_interactable)
	_interactable.hovered.connect(_hover.bind(true))
	_interactable.unhovered.connect(_hover.bind(false))
	_interactable.grabbed.connect(func() -> void:
		_held = true
		var pinch := position + _pinch_offset() - Hand.point_on_height(DRAG_HEIGHT)
		_grip = Vector3(pinch.x, 0.0, pinch.z)
		for tween in [_lifting, _flipping]:
			if tween != null:
				tween.kill()
		_cue(&"Pickup"))
	_interactable.released.connect(func() -> void:
		_held = false
		_hover(false)
		dropped.emit(self))


func _process(delta: float) -> void:
	if _held:
		_ease_held(delta)
		# The pinch stays where the hand took it; the card shrinks back toward it.
		var corner := _pinch_offset()
		var moved := Hand.point_on_height(DRAG_HEIGHT) + _grip - Vector3(corner.x, 0.0, corner.z)
		moved.y = lerpf(position.y, DRAG_HEIGHT, 1.0 - exp(-HOLD_RISE * delta))
		# A little sway against the drag direction, like paper in the air.
		var sway := (moved - position) / maxf(delta, 0.001) * 0.1
		position = moved
		_look.rotation = Vector3(clampf(sway.z, -0.3, 0.3), 0.0, clampf(-sway.x, -0.3, 0.3))
	# The hand's pinch follows the corner wherever the hover or the sway puts it.
	_interactable.carry_offset = basis * (_look.transform * PINCH_AT)


## The pinched corner from the card's origin with the hover lift and growth, but not the sway.
func _pinch_offset() -> Vector3:
	return basis * (_look.position + _look.scale * PINCH_AT)


## 0 at the press pad, 1 from PRESS_FAR away: how much of the big, turned-over hover look the card gets.
func _away() -> float:
	if press_at == Vector3.INF:
		return 1.0
	return clampf(inverse_lerp(PRESS_NEAR, PRESS_FAR, Vector2(position.x - press_at.x, position.z - press_at.z).length()), 0.0, 1.0)


## Held: eases back from the hover look to normal size, front up.
func _ease_held(delta: float) -> void:
	var k := 1.0 - exp(-HOLD_EASE * delta)
	_look.scale = _look.scale.lerp(Vector3.ONE, k)
	_look.position = _look.position.lerp(Vector3.ZERO, k)
	_turn(lerpf(_flipped, 0.0, k))


## Arcs from where it is to `to` (turned `yaw`), out of reach on the way; `grabbable` says whether
## the hand may take it once there.
func fly_to(to: Vector3, grabbable := true, yaw := 0.0, time := FLY_TIME, arc := ARC) -> Tween:
	_interactable.enabled = false
	if _flying != null:
		_flying.kill()
	var start := position
	var start_yaw := rotation.y
	_flying = create_tween()
	_flying.tween_method(func(p: float) -> void:
		var eased := ease(p, -1.8)
		position = start.lerp(to, eased) + Vector3.UP * arc * sin(PI * p)
		rotation.y = lerp_angle(start_yaw, yaw, eased)
		_look.rotation = Vector3(flutter_at(p) * 0.6, 0.0, flutter_at(p)), 0.0, 1.0, time)
	_flying.tween_callback(func() -> void:
		_look.rotation = Vector3.ZERO
		_interactable.enabled = grabbable
		_cue(&"Land"))
	return _flying


## Dealt into the tray: sails in from off-screen left.
func deal_to(to: Vector3) -> Tween:
	position = DEAL_FROM + Vector3(0, 0, to.z - 0.6)
	rotation.y = PI * 0.5
	return fly_to(to, true, 0.0, DEAL_TIME, DEAL_ARC)


## Pushed onto the spike file: lifts over the spike, then drops down onto it.
func spike_to(to: Vector3, yaw: float) -> void:
	var tween := fly_to(to + Vector3.UP * 0.2, false, yaw)
	tween.tween_property(self, "position", to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_cue.bind(&"Impale"))


## The paper's rock `p` of the way through a move: swinging, gone by the landing.
static func flutter_at(p: float) -> float:
	return FLUTTER * sin(p * TAU * 1.5) * (1.0 - p)


## Stamped: APPROVED thumps onto the paper in red.
func stamp(animate := true) -> void:
	_stamp.visible = true
	_interactable.enabled = false
	# Never picked up again: no hand pinch or drag to keep up with.
	set_process(false)
	if animate:
		_stamp.scale = Vector3.ONE * 1.6
		create_tween().tween_property(_stamp, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Too poor: the card shudders and its heading and prices flash red twice.
func blink() -> void:
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	var labels: Array[Label3D] = [_heading, _price, _front_price]
	for colour: Color in [DENIED_RED, INK, DENIED_RED, INK]:
		_blinking.tween_callback(func() -> void:
			for label in labels:
				label.modulate = colour)
		_blinking.tween_interval(BLINK_TIME)
	var shake := create_tween()
	for x in [SHAKE, -SHAKE, SHAKE * 0.5, 0.0]:
		shake.tween_property(_look, "position:x", x, 0.04)


func _hover(on: bool) -> void:
	# By the press a hovered card stays small, front up and under the press, tipping up instead.
	var away := _away()
	# The hovered card lifts clear instead of drawing over everything, so the hand shows on it.
	var grown := lerpf(1.0, HOVER_SCALE, away) if on else 1.0
	var press_lift := Vector3.UP * SIZE.x * 0.5 * sin(PRESS_TIP)
	var raised := (HOVER_SHIFT + Vector3.UP * HOVER_LIFT) * away + (PRESS_NUDGE + press_lift) * (1.0 - away) if on else Vector3.ZERO
	var tipped := Vector3(HOVER_TILT * away, 0.0, -PRESS_TIP * (1.0 - away)) if on else Vector3.ZERO
	if _lifting != null:
		_lifting.kill()
	_lifting = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lifting.tween_property(_look, "position", raised, HOVER_TIME)
	_lifting.tween_property(_look, "scale", Vector3.ONE * grown, HOVER_TIME)
	_lifting.tween_property(_look, "rotation", tipped, HOVER_TIME)
	if _flipping != null:
		_flipping.kill()
	_flipping = create_tween()
	_flipping.tween_method(_turn, _flipped, PI if on and away > 0.5 else 0.0, FLIP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if on:
		_cue(&"Hover")


## Turns the card `angle` about its width, showing whichever face is up.
func _turn(angle: float) -> void:
	_flipped = angle
	_flip.basis = Basis(Vector3.RIGHT, angle)
	_front.visible = angle < PI * 0.5
	_back.visible = not _front.visible


## Plays the desk's sound `sound` (a SoundCue on the UpgradeDesk) at the card.
func _cue(sound: StringName) -> void:
	var cue := get_parent().get_node_or_null(NodePath(sound)) as SoundCue
	if cue != null:
		cue.cue(global_position)


func _text(face: Node3D, text: String, at: Vector3, size: int, font: Font, width := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.pixel_size = PIXEL
	label.modulate = INK
	label.outline_size = 0
	label.shaded = true
	# Shaded glyphs that cast shadows speckle themselves under the lamp.
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.rotation.x = -PI / 2
	label.position = at
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = width / PIXEL
	face.add_child(label)
	return label


## "$130" or "¶10": the price with its currency's sign, as on the tally machine's plates.
static func price_text(amount: int, paid_in: String) -> String:
	return ("¶%d" if paid_in == "findings" else "$%d") % amount
