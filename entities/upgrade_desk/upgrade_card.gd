class_name UpgradeCard
extends StaticBody3D
## One requisition form, showing its heading and price. Hovered, it emits `hover_changed` and the
## UpgradeDesk decides whether it lifts (`lift`) and shows its full text on screen (only in the tray).
## The hand pinches it by its near left corner; held, the card hangs from that pinch. Let go, it emits
## `dropped` and the UpgradeDesk decides where it goes. Every move is a short paper arc with a
## flutter, so cards never teleport. Cabbages pass through it (its own collision layer).
## A stage-changing card (an UpgradeDesk.CARDS entry with `priority`: the family farm, a chapter's last card) is a
## priority form: the same stock dyed oxblood (PRIORITY_TINT), so it stands out in the tray.

signal dropped(card: UpgradeCard)
## Hovered or not; `instant` when it was picked up, so its text goes at once instead of fading.
signal hover_changed(card: UpgradeCard, on: bool, instant: bool)

const SIZE := Vector2(0.36, 0.2)
const LAYER := 8
const MATERIAL := preload("res://assets/materials/card_paper.tres")
## The priority form's dye, multiplied into the card paper (above 1 to lift the dark stock).
const PRIORITY_TINT := Color(1.3, 0.86, 0.8)
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
const DENIED_RED := Color(0.9, 0.12, 0.08)
const TITLE_FONT := preload("res://assets/fonts/Oswald.ttf")
## Fine pixels and big font sizes keep the text crisp.
const PIXEL := 0.0003
## The corner the hand pinches, in the card's look space (near left, a little in from the edges).
const PINCH_AT := Vector3(-0.165, 0.0, 0.085)
## The price sits in the ruled box at the bottom right (the texture's box: x 0.096-0.168, z 0.047-0.088),
## in PRICE_SIZE print, smaller when it would not fit PRICE_WIDTH.
const PRICE_AT := Vector3(0.1316, 0.002, 0.0672)
const PRICE_WIDTH := 0.064
const PRICE_SIZE := 110
## A price paid in cabbages (currency "stock") has ICON before its number: ICON_EM of the font size
## high (about the digits' height), ICON_GAP of that from the digits.
const ICON := preload("res://assets/sprites/icons/cabbage_icon.svg")
const ICON_EM := 0.9
const ICON_GAP := 0.12
## The heading wraps in HEADING_BOX (width, height in metres) under the form line, printed in
## HEADING_SIZE or smaller (fit_size, never under MIN_SIZE). The form line keeps to one line in FORM_BOX.
const HEADING_BOX := Vector2(0.33, 0.11)
const HEADING_SIZE := 150
const FORM_BOX := Vector2(0.33, 0.03)
const FORM_SIZE := 60
const MIN_SIZE := 40

var id := ""
var price := 0
## The SaveGame field it is paid from: "coins" ($) or "findings" (¶).
var currency := "coins"

var _held := false
## Held: where the pinch sits relative to the mouse (flat), fixed at the grab so neither jumps.
var _grip := Vector3.ZERO
@onready var _look: Node3D = $Look
@onready var _heading: Label3D = $Look/Heading
@onready var _price: Label3D = $Look/Price
@onready var _price_icon: Sprite3D = $Look/PriceIcon
@onready var _interactable: Interactable = $Interactable
var _lifting: Tween
var _flying: Tween
var _blinking: Tween
## The card paper dyed PRIORITY_TINT, built once.
static var _priority_material: StandardMaterial3D


## A card for `card` (an UpgradeDesk.CARDS entry), its print fitted to the paper.
static func create(card: Dictionary) -> UpgradeCard:
	var made := (load("res://entities/upgrade_desk/upgrade_card.tscn") as PackedScene).instantiate() as UpgradeCard
	made._fill(card)
	return made


func _fill(card: Dictionary) -> void:
	id = card.id
	price = card.price
	currency = card.get("currency", "coins")
	if paper_tint(card) != Color.WHITE:
		($Look/Paper as MeshInstance3D).material_override = _priority()
	var form := $Look/Form as Label3D
	form.text = form_of(card)
	form.font_size = fit_size(tr(form.text), FORM_SIZE, FORM_BOX)
	# Long titles (German ones above all) print smaller so they stay between the form line and the price box.
	var heading := $Look/Heading as Label3D
	heading.text = card.title
	heading.font_size = fit_size(tr(card.title), HEADING_SIZE, HEADING_BOX)
	var shown := price_text(price, currency)
	var label := $Look/Price as Label3D
	label.text = shown
	label.font_size = price_size(shown, currency)
	# The icon and the number sit centred in the price box together.
	var icon := $Look/PriceIcon as Sprite3D
	icon.visible = shows_icon(currency)
	var em := label.font_size * PIXEL
	var text := TITLE_FONT.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * PIXEL
	var left := PRICE_AT.x - price_width(shown, currency, label.font_size) * 0.5
	label.position.x = left + price_width(shown, currency, label.font_size) - text * 0.5
	icon.pixel_size = em * ICON_EM / ICON.get_height()
	icon.position = Vector3(left + em * ICON_EM * 0.5, PRICE_AT.y, PRICE_AT.z)


func _ready() -> void:
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


## Stamped: the paper gives under the head and the card is done (no more pinching).
func stamp(animate := true) -> void:
	_interactable.enabled = false
	# Never picked up again: no hand pinch or drag to keep up with.
	set_process(false)
	if not animate:
		return
	var squash := create_tween()
	squash.tween_property(_look, "scale", Vector3(1.04, 1.0, 1.04), 0.04)
	squash.tween_property(_look, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Too poor: the card shudders and its heading and prices flash red twice.
func blink() -> void:
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	var labels: Array[Node3D] = [_heading, _price, _price_icon]
	for colour: Color in [DENIED_RED, INK, DENIED_RED, INK]:
		_blinking.tween_callback(func() -> void:
			for label in labels:
				label.set(&"modulate", colour))
		_blinking.tween_interval(BLINK_TIME)
	var shake := create_tween()
	for x in [SHAKE, -SHAKE, SHAKE * 0.5, 0.0]:
		shake.tween_property(_look, "position:x", x, 0.04)


## Plays the desk's sound `sound` (a SoundCue on the UpgradeDesk) at the card.
func _cue(sound: StringName) -> void:
	var cue := get_parent().get_node_or_null(NodePath(sound)) as SoundCue
	if cue != null:
		cue.cue(global_position)


## "$130", "¶10" or "60" (paid from stock: the cabbage ICON is its sign, see shows_icon): the price
## with its currency's sign, as on the tally machine's plates.
static func price_text(amount: int, paid_in: String) -> String:
	if paid_in == "stock":
		return str(amount)
	return ("¶%d" if paid_in == "findings" else "$%d") % amount


## A price in `paid_in` is printed with the cabbage ICON before its number (paid in cabbages).
static func shows_icon(paid_in: String) -> bool:
	return paid_in == "stock"


## How wide price text `shown` in `paid_in` prints in TITLE_FONT at font size `size` (ICON
## included), times `unit` (PIXEL on the card, 1 in 2D).
static func price_width(shown: String, paid_in: String, size: int, unit := PIXEL) -> float:
	var icon := size * ICON_EM * (1.0 + ICON_GAP) if shows_icon(paid_in) else 0.0
	return (TITLE_FONT.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + icon) * unit


## The font size that fits price text `shown` in `paid_in` into the price box: PRICE_SIZE, or smaller.
static func price_size(shown: String, paid_in := "coins") -> int:
	var size := PRICE_SIZE
	while size > 40 and price_width(shown, paid_in, size) > PRICE_WIDTH:
		size -= 2
	return size


## Draws price text `shown` in `paid_in` on `item` in `font` at `size`, ending at `right` (its
## baseline), the cabbage ICON before it when it has one, all inked `ink`.
static func draw_price(item: CanvasItem, font: Font, right: Vector2, shown: String, paid_in: String, size: int, ink: Color) -> void:
	var text := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	item.draw_string(font, Vector2(right.x - text, right.y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	if shows_icon(paid_in):
		var side := size * ICON_EM
		# Centred on the digits' height (about 0.7 of the font size above the baseline).
		var at := Vector2(right.x - text - side * ICON_GAP - side, right.y - size * 0.37 - side * 0.5)
		item.draw_texture_rect(ICON, Rect2(at, Vector2(side, side)), false, ink)


## The biggest font size from `size` down (in steps of 4, not under MIN_SIZE) at which `shown`,
## word-wrapped to `box`.x, fits `box` (metres). No word is broken: one too long shrinks the print.
static func fit_size(shown: String, size: int, box: Vector2) -> int:
	while size > MIN_SIZE and not fits(shown, size, box):
		size = maxi(size - 4, MIN_SIZE)
	return size


static func fits(shown: String, size: int, box: Vector2) -> bool:
	var drawn := TITLE_FONT.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_CENTER, box.x / PIXEL, size) * PIXEL
	return drawn.x <= box.x and drawn.y <= box.y


## The form line printed across the top of card `card` (a CARDS entry).
static func form_of(card: Dictionary) -> String:
	if card.get("priority", false):
		return "FORM 0-P  PRIORITY ACQUISITION"
	return "FORM 7-R  RESEARCH DIRECTIVE" if card.get("research", false) else "FORM 7-B  REQUISITION"


## What card `card`'s paper is dyed with: PRIORITY_TINT for a stage-changing card (`priority`: the
## family farm, a chapter's last card), else white (the plain stock).
static func paper_tint(card: Dictionary) -> Color:
	return PRIORITY_TINT if card.get("priority", false) else Color.WHITE


static func _priority() -> StandardMaterial3D:
	if _priority_material == null:
		_priority_material = MATERIAL.duplicate()
		_priority_material.albedo_color = PRIORITY_TINT
	return _priority_material
