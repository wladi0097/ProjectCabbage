class_name FarmDeed
extends Node3D
## The deed of transfer for one farm site (FORM 3-D), laid on the country sheet beside the farm it
## is for (FarmRegister lays it out, moves it and decides what a click does; the deed only shows).
## A paper of SIZE m, built like a map sheet: `Page` is a 2D SubViewport with the form's lettering at
## 1 px = 1 mm, printed on `Paper` (assets/shaders/map_sheet.gdshader, so it can roll itself up).
## Its origin is the middle of its top edge; the paper runs along +Z, right is +X.
## The form, top to bottom: the form line, the farm's name and site, the PURCHASE PRICE in coins and
## cabbages (print_price: reprinted whenever the price changes, what is short marked beside it), the
## negotiation's band (print_haggle; empty on a deed nobody haggles over), then the small print and
## the stamp box (STAMP_BOX). A farm nobody sells gets the NOT FOR SALE strip across it, a line
## saying why, and no stamp box.
## The negotiation's band (FarmRegister has the rules): left, `Page/Form/Offer`: what is offered (a
## dial: the `<` and `>` boxes, LESS_BOX and MORE_BOX, around the typed amount), which round it is
## and the SUBMIT OFFER box (OFFER_BOX); right, `Page/Form/Mood`: the owner's mood after the last
## offer, stamped (MOODS: the only clue, the number he has in mind is never printed). The price
## line reprints with every offer, ASKED beside its head once it has moved, and the small print
## gives way to the list of offers made, each with its mood. A bribe is the same band in coins.
## The stamp (`Stamp`: a cast-iron head on a knob) comes down on the box (strike), prints ACQUIRED
## (imprint: the desk press's thunk, a ring, the paper gives) and lifts away (lift_stamp).
## Sound moments, one cue each: Slide (it slides in or away), Strike (the stamp lands), Denied (the
## stamp refused, an offer that missed: the desk press's dry thud), Roll (it rolls itself up), Dial
## (the dial turned a notch), MoodStamp (the mood stamped), Agreed (an offer that landed).

const SIZE := Vector2(0.82, 1.04)
const PIXELS_PER_METRE := 1000.0
## The stamp box on the form (px from its top left corner): where a click stamps.
const STAMP_BOX := Rect2(500, 790, 280, 210)
## The negotiation's boxes on the form (px): the dial's two and SUBMIT OFFER; BOXES names all four
## (box_at: the spots FarmRegister takes clicks on). The mood stamp lands on MOOD_AT.
const LESS_BOX := Rect2(44, 614, 80, 80)
const MORE_BOX := Rect2(404, 614, 80, 80)
const OFFER_BOX := Rect2(44, 702, 440, 64)
const BOXES := {&"deed_stamp": STAMP_BOX, &"deed_less": LESS_BOX, &"deed_more": MORE_BOX, &"deed_offer": OFFER_BOX}
const MOOD_AT := Vector2(638, 682)
## The small print of a deed nobody haggles over.
const SMALL_PRINT := "The seller confirms that the transfer is voluntary."
## The paper's other forms (letter; translation keys): a home farm nobody sells is taken by a
## SEIZURE ORDER (FarmRegister.seizure), a country by an ANNEXATION ORDER (WorldRegister). Each has
## its form line, the head over its price, its small print and what the stamp prints.
const FORMS := {
	&"seizure": {form = "FORM 3-S  SEIZURE ORDER", head = "COST OF THE OPERATION", note = "The owner's signature is not required.", seal = "SEIZED"},
	&"annexation": {form = "FORM 7-A  ANNEXATION ORDER", head = "COST OF THE OPERATION", note = "The population has been informed in writing.", seal = "ANNEXED"},
}
## The owner's five moods as stamped (FarmRegister.Mood, worst first), by what is offered: cabbages
## from stock, or coins in an envelope.
const MOODS := {
	"stock": ["INSULTED", "UNIMPRESSED", "LISTENING", "INTRIGUED", "DELIGHTED"],
	"coins": ["UNSEEN", "WEIGHED", "CONSIDERED", "UNDERSTOOD", "GRATEFUL"],
}
const INK := Color(0.11, 0.125, 0.118)
const DENIED_RED := Color(0.9, 0.12, 0.08)
const BLINK_TIME := 0.12
## The stamp waits this high over the box (m), out of the camera's sight.
const STAMP_FROM := 1.6
## The ring of the stamp's hit spreads to this many times its size while it fades.
const RING_TO := 1.8
const RING_TIME := 0.32
## Sliding, the paper is turned this far (rad) and squares up as it arrives.
const SLIDE_TURN := 0.22

## The stamp box's frame while the mouse is on it.
@export var hot_box: StyleBox

## The site the deed is for, its price as printed ({currency: amount}, UpgradeDesk.costs; empty when
## nobody sells), and whether it has been stamped.
var site := &""
var bill := {}
var stamped := false
## 1 lies flat, 0 is all rolled up at its top edge.
var open := 1.0:
	set(value):
		open = value
		_paper.set_shader_parameter(&"open", value)

var _moving: Tween
var _stamping: Tween
var _blinking: Tween

@onready var _page: SubViewport = $Page
@onready var _paper: ShaderMaterial = $Paper.material_override
@onready var _title: Label = $Page/Form/Title
@onready var _site: Label = $Page/Form/Site
@onready var _coins: Label = $Page/Form/Coins
@onready var _coins_short: Label = $Page/Form/CoinsShort
@onready var _cabbages: Label = $Page/Form/Cabbages
@onready var _cabbages_short: Label = $Page/Form/CabbagesShort
@onready var _small_print: Label = $Page/Form/SmallPrint
@onready var _reason: Label = $Page/Form/Reason
@onready var _box: Panel = $Page/Form/Box
@onready var _box_line: StyleBox = _box.get_theme_stylebox(&"panel")
@onready var _asked: Label = $Page/Form/Asked
@onready var _log: Label = $Page/Form/Log
@onready var _offer: Control = $Page/Form/Offer
@onready var _offer_head: Label = $Page/Form/Offer/Head
@onready var _round: Label = $Page/Form/Offer/Round
@onready var _number: Label = $Page/Form/Offer/Value/Number
@onready var _submit_word: Label = $Page/Form/Offer/Submit/Word
@onready var _closed: Label = $Page/Form/Offer/Closed
@onready var _mood: Control = $Page/Form/Mood
@onready var _divider: Control = $Page/Form/Divider
@onready var _mood_imprint: Control = $Page/Form/Mood/Imprint
@onready var _mood_word: Label = $Page/Form/Mood/Imprint/Word
## The boxes a click takes, by spot (BOXES).
@onready var _boxes: Dictionary[StringName, Panel] = {&"deed_stamp": _box, &"deed_less": $Page/Form/Offer/Less,
		&"deed_more": $Page/Form/Offer/More, &"deed_offer": $Page/Form/Offer/Submit}
@onready var _imprint: Control = $Page/Form/Imprint
@onready var _strip: Control = $Page/Form/Strip
@onready var _stamp: Node3D = $Stamp
@onready var _stamp_rest := _stamp.position
@onready var _ring: MeshInstance3D = $Ring
@onready var _slide_sound: SoundCue = $Slide
@onready var _strike_sound: SoundCue = $Strike
@onready var _denied_sound: SoundCue = $Denied
@onready var _roll_sound: SoundCue = $Roll
@onready var _dial_sound: SoundCue = $Dial
@onready var _mood_sound: SoundCue = $MoodStamp
@onready var _agreed_sound: SoundCue = $Agreed


func _ready() -> void:
	_paper.set_shader_parameter(&"sheet_tex", _page.get_texture())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		reprint()  # The form's fixed lettering changed.


## Prints the form onto the paper again: after any of its lettering changed.
func reprint() -> void:
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE


## Whether form pixel `pixel` (from the deed's top left corner) is in the stamp box.
static func in_stamp_box(pixel: Vector2) -> bool:
	return STAMP_BOX.has_point(pixel)


## The spot of BOXES that form pixel `pixel` is in, or &"".
static func box_at(pixel: Vector2) -> StringName:
	for spot: StringName in BOXES:
		if (BOXES[spot] as Rect2).has_point(pixel):
			return spot
	return &""


## `amount` of what an offer is made in, as the form types it: "250", "$150,000".
static func amount_text(paid_in: String, amount: int) -> String:
	return ("$" if paid_in == "coins" else "") + FarmScreen._thousands(amount)


## A fresh, unstamped deed for the farm called `called` on site `at`: its `price` with what is
## short of it (print_price), or, for a farm nobody sells (`price` empty), the NOT FOR SALE strip
## and `reason`.
func fill(called: String, at: StringName, price: Dictionary, lacks := {}, reason := "") -> void:
	site = at
	stamped = false
	_title.text = called
	_site.text = tr("FARM SITE %s") % at
	_imprint.hide()
	_strip.visible = price.is_empty()
	_reason.visible = price.is_empty()
	_reason.text = reason
	_box.visible = not price.is_empty()
	_small_print.visible = not price.is_empty()
	($Page/Form/PriceHead as Label).visible = not price.is_empty()
	hot(&"")
	print_price(price, lacks)
	print_haggle()


## Letters the filled paper as another form (`kind`: FORMS) instead of the deed of transfer: its form
## line, price head, small print and stamp; `strip` is what the strip of one that cannot be stamped
## says (a key; "": as it is), `line` replaces the site line under the name ("": as fill set it).
func letter(kind: StringName, strip := "", line := "") -> void:
	var form: Dictionary = FORMS[kind]
	($Page/Form/FormLine as Label).text = form.form
	($Page/Form/PriceHead as Label).text = form.head
	($Page/Form/Imprint/Word as Label).text = form.seal
	_small_print.text = form.note
	if strip != "":
		($Page/Form/Strip/Word as Label).text = strip
	if line != "":
		_site.text = line
	reprint()


## Prints `price` ({currency: amount}: coins, cabbages from stock) as the deed's price, and beside
## each amount what is short of it (`lacks`, FarmRegister.short). Called again whenever either changes.
func print_price(price: Dictionary, lacks := {}) -> void:
	bill = price
	_coins.text = "$" + FarmScreen._thousands(price.coins) if price.has("coins") else ""
	_cabbages.text = tr("%s cabbages") % FarmScreen._thousands(price.stock) if price.has("stock") else ""
	_coins_short.text = tr("SHORT %s") % ("$" + FarmScreen._thousands(lacks.coins)) if lacks.has("coins") else ""
	_cabbages_short.text = tr("SHORT %s") % FarmScreen._thousands(lacks.stock) if lacks.has("stock") else ""
	reprint()


## Prints the negotiation's band: what is offered (`paid_in`: "stock" cabbages, "coins" a bribe; "":
## nobody haggles over this deed, the band stays empty), the `amount` on the dial, the `offers` made
## so far with the owner's mood after each (`moods`, FarmRegister.Mood), how many more he hears
## (`left`; 0: the dial and SUBMIT OFFER give way to NO FURTHER OFFERS), the coin price first
## `asked` (printed once the price has moved) and the small print's `note` (a key; until the first offer).
func print_haggle(paid_in := "", amount := 0, offers := PackedInt32Array(), moods: Array[int] = [], left := 0, asked := 0, note := SMALL_PRINT) -> void:
	var on := paid_in != ""
	_small_print.text = note  # The label translates it.
	_offer.visible = on
	_mood.visible = on
	_divider.visible = on
	_log.visible = on and not offers.is_empty()
	_asked.visible = on and bill.get("coins", asked) != asked
	if not on:
		return
	_small_print.visible = offers.is_empty()
	_asked.text = tr("ASKED %s") % ("$" + FarmScreen._thousands(asked))
	_offer_head.text = tr("CABBAGES OFFERED" if paid_in == "stock" else "IN THE ENVELOPE")
	_round.text = "%d / %d" % [offers.size() + mini(left, 1), offers.size() + left]
	_number.text = amount_text(paid_in, amount)
	_submit_word.text = tr("SUBMIT OFFER" if paid_in == "stock" else "PASS THE ENVELOPE")
	_closed.visible = left <= 0
	for part: String in ["Less", "Value", "More", "Submit"]:
		(_offer.get_node(part) as Control).visible = left > 0
	_mood_imprint.visible = not moods.is_empty()
	var lines := PackedStringArray()
	for i in offers.size():
		lines.append("%s  %s" % [amount_text(paid_in, offers[i]), tr(MOODS[paid_in][moods[i]])])
	_log.text = "\n".join(lines)
	if not moods.is_empty():
		_mood_word.text = tr(MOODS[paid_in][moods[-1]])
	reprint()


## The box under the mouse (`spot` of BOXES; &"": none): its frame goes heavy and oxblood.
func hot(spot: StringName) -> void:
	for box: StringName in _boxes:
		_boxes[box].add_theme_stylebox_override(&"panel", hot_box if box == spot else _box_line)
	reprint()


## The dial turned a notch.
func tick() -> void:
	_dial_sound.cue(global_position)


## The stamp refused: what is short flashes red twice, to the desk press's dry thud.
func blink() -> void:
	_denied_sound.cue(global_position)
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	for colour: Color in [INK, DENIED_RED, INK, DENIED_RED]:
		_blinking.tween_callback(_ink_short.bind(colour))
		_blinking.tween_interval(BLINK_TIME)


## Slides flat over the sheet from `from` to `to` (in the parent's space) in `time` s, squaring up
## as it arrives; `away` slides it off instead and hides it at the end.
func slide(from: Vector3, to: Vector3, time: float, away := false) -> void:
	_still()
	open = 1.0
	show()
	_slide_sound.cue(global_position)
	var turn := SLIDE_TURN * signf(from.x - to.x if not away else to.x - from.x)
	_moving = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN if away else Tween.EASE_OUT)
	_moving.tween_property(self, "position", to, time).from(from)
	_moving.tween_property(self, "rotation:y", turn if away else 0.0, time).from(0.0 if away else turn)
	if away:
		_moving.chain().tween_callback(hide)


## The stamp comes down on form pixel `on` (the stamp box; MOOD_AT for a mood) in `time` s, from
## STAMP_FROM above it.
func strike(time: float, on := STAMP_BOX.get_center()) -> void:
	if _stamping != null:
		_stamping.kill()
	var at := Vector3(on.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0, on.y / PIXELS_PER_METRE)
	_stamp.position = at + Vector3.UP * _stamp_rest.y
	_ring.position = at + Vector3.UP * _ring.position.y
	_stamp.scale = Vector3.ONE
	_stamp.show()
	_stamping = create_tween()
	_stamping.tween_property(_stamp, "position:y", _stamp_rest.y, time).from(_stamp_rest.y + STAMP_FROM) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The stamp has landed: ACQUIRED is on the paper, the thunk, a ring from the box, the head squashed.
func imprint() -> void:
	stamped = true
	_box.hide()
	_imprint.show()
	reprint()
	_strike_sound.cue(_stamp.global_position)
	_hit()


## The stamp has landed on the mood (print_haggle has it on the paper): its thump, and whether the
## offer `landed` (the coins saved rattle) or missed (the dry thud).
func stamp_mood(landed: bool) -> void:
	_mood_sound.cue(_stamp.global_position)
	(_agreed_sound if landed else _denied_sound).cue(_stamp.global_position)
	_hit()


## The stamp's hit: the head squashed, a ring from under it.
func _hit() -> void:
	_stamp.scale = Vector3(1.12, 0.8, 1.12)
	var ink := _ring.get_surface_override_material(0) as StandardMaterial3D
	_ring.show()
	var burst := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	burst.tween_property(_ring, "scale", Vector3(RING_TO, 1.0, RING_TO), RING_TIME).from(Vector3(0.5, 1.0, 0.5))
	burst.tween_property(ink, "albedo_color:a", 0.0, RING_TIME).from(0.8)
	burst.chain().tween_callback(_ring.hide)


## The stamp lifts off the paper in `time` s and is gone.
func lift_stamp(time: float) -> void:
	if _stamping != null:
		_stamping.kill()
	_stamping = create_tween()
	_stamping.tween_property(_stamp, "scale", Vector3.ONE, 0.08)
	_stamping.parallel().tween_property(_stamp, "position:y", _stamp_rest.y + STAMP_FROM, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamping.tween_callback(_stamp.hide)


## Rolls itself up to its top edge in `roll_time` s, then drops off the map towards `to` (in the
## parent's space) in `drop_time` s and is gone.
func roll_away(to: Vector3, roll_time: float, drop_time: float) -> void:
	_still()
	_roll_sound.cue(global_position)
	_moving = create_tween()
	_moving.tween_property(self, "open", 0.0, roll_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_moving.tween_property(self, "position", to, drop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_moving.tween_callback(hide)


func _ink_short(colour: Color) -> void:
	for label: Label in [_coins_short, _cabbages_short]:
		label.add_theme_color_override(&"font_color", colour)
	reprint()


func _still() -> void:
	if _moving != null:
		_moving.kill()
