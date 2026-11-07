class_name UpgradeCard
extends StaticBody3D
## One requisition form, showing its heading and price. Hovered, it emits `hover_changed` and the
## UpgradeDesk decides whether it lifts (`lift`) and shows its full text on screen (only in the tray).
## The hand pinches it by its near left corner; held, the card hangs from that pinch. Let go, it emits
## `dropped` and the UpgradeDesk decides where it goes. Every move is a short paper arc with a
## flutter, so cards never teleport. Cabbages pass through it (its own collision layer).

signal dropped(card: UpgradeCard)
## Hovered or not; `instant` when it was picked up, so its text goes at once instead of fading.
signal hover_changed(card: UpgradeCard, on: bool, instant: bool)

const SIZE := Vector2(0.36, 0.2)
const LAYER := 8
const MATERIAL := preload("res://assets/materials/card_paper.tres")
const DRAG_HEIGHT := 0.9
## Hovered in the tray, the paper lifts this far off the stack over HOVER_TIME.
const HOVER_LIFT := 0.035
const HOVER_TIME := 0.14
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
## The impression lands this much oversized, then settles.
const STAMP_SLAM := 1.35
const TITLE_FONT := preload("res://assets/fonts/Oswald.ttf")
## Fine pixels and big font sizes keep the text crisp.
const PIXEL := 0.0003
## The corner the hand pinches, in the card's look space (near left, a little in from the edges).
const PINCH_AT := Vector3(-0.165, 0.0, 0.085)

var id := ""
var price := 0
## The SaveGame field it is paid from: "coins" ($) or "findings" (¶).
var currency := "coins"

var _held := false
## Held: where the pinch sits relative to the mouse (flat), fixed at the grab so neither jumps.
var _grip := Vector3.ZERO
var _look := Node3D.new()
var _heading: Label3D
var _price: Label3D
var _stamp: Node3D
var _interactable := Interactable.new()
var _lifting: Tween
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
	var paper := MeshInstance3D.new()
	paper.mesh = PlaneMesh.new()
	(paper.mesh as PlaneMesh).size = SIZE
	paper.material_override = MATERIAL
	_look.add_child(paper)
	_text(form_of(card), Vector3(0, 0.002, -0.0825), 60, TITLE_FONT)
	# Long titles get a smaller face so they stay on two lines under the form header.
	_heading = _text(card.title, Vector3(0, 0.002, -0.005), 150 if card.title.length() <= 20 else 118, TITLE_FONT, 0.33)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price = _text(price_text(price, currency), Vector3(0.135, 0.002, 0.075), 110, TITLE_FONT)
	_build_stamp()
	_interactable.carried = true
	add_child(_interactable)
	_interactable.hovered.connect(func() -> void: hover_changed.emit(self, true, false))
	_interactable.unhovered.connect(func() -> void: hover_changed.emit(self, false, false))
	_interactable.grabbed.connect(func() -> void:
		_held = true
		var pinch := position + _pinch_offset() - Hand.point_on_height(DRAG_HEIGHT)
		_grip = Vector3(pinch.x, 0.0, pinch.z)
		hover_changed.emit(self, false, true)
		_cue(&"Pickup"))
	_interactable.released.connect(func() -> void:
		_held = false
		dropped.emit(self))


func _process(delta: float) -> void:
	if _held:
		# The pinch stays where the hand took it.
		var corner := _pinch_offset()
		var moved := Hand.point_on_height(DRAG_HEIGHT) + _grip - Vector3(corner.x, 0.0, corner.z)
		moved.y = lerpf(position.y, DRAG_HEIGHT, 1.0 - exp(-HOLD_RISE * delta))
		# A little sway against the drag direction, like paper in the air.
		var sway := (moved - position) / maxf(delta, 0.001) * 0.1
		position = moved
		_look.rotation = Vector3(clampf(sway.z, -0.3, 0.3), 0.0, clampf(-sway.x, -0.3, 0.3))
	# The hand's pinch follows the corner wherever the lift or the sway puts it.
	_interactable.carry_offset = basis * (_look.transform * PINCH_AT)


## The pinched corner from the card's origin with the lift, but not the sway.
func _pinch_offset() -> Vector3:
	return basis * (_look.position + PINCH_AT)


## Hovered in the tray: lifts a little off the stack to mark it, or settles back.
func lift(on: bool) -> void:
	if _lifting != null:
		_lifting.kill()
	_lifting = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lifting.tween_property(_look, "position:y", HOVER_LIFT if on else 0.0, HOVER_TIME)
	if on:
		_cue(&"Hover")


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
func spike_to(to: Vector3, yaw: float) -> Tween:
	var tween := fly_to(to + Vector3.UP * 0.2, false, yaw)
	tween.tween_property(self, "position", to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_cue.bind(&"Impale"))
	return tween


## The paper's rock `p` of the way through a move: swinging, gone by the landing.
static func flutter_at(p: float) -> float:
	return FLUTTER * sin(p * TAU * 1.5) * (1.0 - p)


## Stamped: a boxed red APPROVED slams onto the paper a little oversized and settles, and the
## paper gives under the head.
func stamp(animate := true) -> void:
	_stamp.visible = true
	_interactable.enabled = false
	# Never picked up again: no hand pinch or drag to keep up with.
	set_process(false)
	if not animate:
		return
	var slam := create_tween()
	_stamp.scale = Vector3.ONE * STAMP_SLAM
	slam.tween_property(_stamp, "scale", Vector3.ONE * 0.95, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(_stamp, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var squash := create_tween()
	squash.tween_property(_look, "scale", Vector3(1.04, 1.0, 1.04), 0.04)
	squash.tween_property(_look, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The rubber-stamp impression, hidden until stamped: APPROVED in a ruled box, turned on the paper.
func _build_stamp() -> void:
	_stamp = Node3D.new()
	_stamp.position = Vector3(-0.02, 0.003, 0.045)
	_stamp.rotation.y = 0.12
	_stamp.visible = false
	_look.add_child(_stamp)
	var label := _text("APPROVED", Vector3.ZERO, 150, TITLE_FONT)
	label.modulate = STAMP_RED
	label.reparent(_stamp, false)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = STAMP_RED
	var text := TITLE_FONT.get_string_size("APPROVED", HORIZONTAL_ALIGNMENT_LEFT, -1, 150) * PIXEL
	var box := Vector2(text.x + 0.024, text.y * 0.78)
	const RULE := 0.005
	for side in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var bar := MeshInstance3D.new()
		bar.mesh = PlaneMesh.new()
		(bar.mesh as PlaneMesh).size = Vector2(RULE, box.y + RULE) if side.x != 0 else Vector2(box.x + RULE, RULE)
		bar.material_override = ink
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.position = Vector3(side.x * box.x, 0.0, side.z * box.y) * 0.5
		_stamp.add_child(bar)


## Too poor: the card shudders and its heading and prices flash red twice.
func blink() -> void:
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	var labels: Array[Label3D] = [_heading, _price]
	for colour: Color in [DENIED_RED, INK, DENIED_RED, INK]:
		_blinking.tween_callback(func() -> void:
			for label in labels:
				label.modulate = colour)
		_blinking.tween_interval(BLINK_TIME)
	var shake := create_tween()
	for x in [SHAKE, -SHAKE, SHAKE * 0.5, 0.0]:
		shake.tween_property(_look, "position:x", x, 0.04)


## Plays the desk's sound `sound` (a SoundCue on the UpgradeDesk) at the card.
func _cue(sound: StringName) -> void:
	var cue := get_parent().get_node_or_null(NodePath(sound)) as SoundCue
	if cue != null:
		cue.cue(global_position)


func _text(text: String, at: Vector3, size: int, font: Font, width := 0.0) -> Label3D:
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
	_look.add_child(label)
	return label


## "$130" or "¶10": the price with its currency's sign, as on the tally machine's plates.
static func price_text(amount: int, paid_in: String) -> String:
	return ("¶%d" if paid_in == "findings" else "$%d") % amount


## The form line printed across the top of card `card` (a CARDS entry).
static func form_of(card: Dictionary) -> String:
	return "FORM 7-R  RESEARCH DIRECTIVE" if card.get("research", false) else "FORM 7-B  REQUISITION"
