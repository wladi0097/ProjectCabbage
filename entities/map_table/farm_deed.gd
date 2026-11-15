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
## A deed that is haggled over (FarmRegister has the rules) has one box in its band, START HAGGLING
## (HAGGLE_BOX), which lays the negotiation letter over it: `Haggle` (NegotiationLetter, its own
## scene: the owner, the reply slips, the offer and the crate), lying HAGGLE_LIFT over the deed,
## turned HAGGLE_TURN, its top left corner at deed pixel HAGGLE_AT (page: deed pixel to its own).
## The stamp (`Stamp`: a cast-iron head on a knob) comes down on the box (strike), prints ACQUIRED
## (imprint: its own heavy slam, a ring, the paper gives) and lifts away (lift_stamp).
## A DECLARATION OF WAR (the paper of a farm taken by war that can be attacked: FarmRegister) prints
## the war's coin price, under STAFF COMMITTED one row per unit type hired (up to five: print_staff,
## declaration_row.tscn): the figure standing on the paper in 3D (`Figures`), how many are ready,
## and the [-] n [+] boxes (staff_box_at) that choose how many go; beside them ASSESSED RESISTANCE
## (print_resistance): the map's rating in words and five pips, and the staff it is estimated to
## take. No small print: the rows run down to the stamp box's foot. With nobody trained at all the
## rows give way to the NO STAFF notice (`NoStaff`), and the stamp is refused. Under the farm's name
## it prints the map's site name and its briefing in place of the site's code (print_site); the
## campaign's last war (Endmark Isle) gets an oxblood border and a heavier stamp. A declaration lies
## WAR_SCALE times the deed's size on the sheet (FarmRegister scales the whole paper, figures and
## stamp with it) so it reads at 720p; its form is the same 1 px = 1 mm page.
## Sound moments, one cue each: Slide (it slides in or away), Strike (the stamp lands), Denied (the
## stamp refused, an offer that missed: a jammed lever's dead clunk), Roll (it rolls itself up), Dial
## (unused), MoodStamp (the mood stamped), Agreed (an offer that landed), PriceUp
## (an offer that missed: the price retyped upward), Envelope (a bribe passed across).

const SIZE := Vector2(0.82, 1.04)
const PIXELS_PER_METRE := 1000.0
## The stamp box on the form (px from its top left corner): where a click stamps; START HAGGLING.
const STAMP_BOX := Rect2(500, 790, 280, 210)
const HAGGLE_BOX := Rect2(44, 596, 732, 140)
## The boxes a click takes (box_at: the spots FarmRegister takes clicks on): on the deed, and on the
## record while it lies over it.
const DEED_BOXES := {&"deed_stamp": STAMP_BOX, &"deed_haggle": HAGGLE_BOX}
const HAGGLE_BOXES := NegotiationLetter.BOXES
## Where the record lies on the deed (`Haggle`'s transform says the same): its top left corner (deed
## px), turned this far (rad, clockwise seen from above) and this high over it (m).
const HAGGLE_AT := Vector2(36, 24)
const HAGGLE_TURN := 0.03
const HAGGLE_LIFT := 0.006
## The record's page to the deed's pixels.
const HAGGLE_PAGE := Transform2D(HAGGLE_TURN, HAGGLE_AT)
## The small print of a deed nobody haggles over.
const SMALL_PRINT := "The seller confirms that the transfer is voluntary."
## The paper's forms (letter; translation keys): the deed of transfer, and the WAR ORDER for a farm
## nobody sells (FarmRegister.war_ready: its stamp starts the war, nothing is paid on it; the price
## it prints is what the war is expected to cost). Each has its form line, the head over its price,
## its small print, what the stamp prints and what the strip of one that cannot be stamped says.
const FORMS := {
	&"deed": {form = "FORM 3-D  DEED OF TRANSFER", head = "PURCHASE PRICE", note = SMALL_PRINT, seal = "ACQUIRED", strip = "NOT FOR SALE"},
	&"war": {form = "FORM 9-W  DECLARATION OF WAR", head = "COST OF WAR", note = "The owner's signature is not required.", seal = "WAR", strip = "NOT FOR SALE"},
}
## The owner's five moods as stamped (FarmRegister.Mood, worst first), by what is offered: cabbages
## from stock, or coins in an envelope.
## A declaration's staff rows (declaration_row.tscn): the first one's top left corner on the form
## (px), each this high (MAX_ROWS of them fit down to the frame), and its [-] and [+] boxes in the
## row. A figure stands FIGURE_SCALE times its fighting size on the row's `Stand` point, a small
## one scaled up to FIGURE_FOOT px across (figure_scale) so every type reads.
const STAFF_AT := Vector2(44, 506)
const ROW_HEIGHT := 98.0
const MAX_ROWS := 5
const LESS_IN_ROW := Rect2(262, 46, 52, 52)
const MORE_IN_ROW := Rect2(398, 46, 52, 52)
const FIGURE_SCALE := 0.5
const FIGURE_FOOT := 80.0
## A declaration of war lies this many times a deed's SIZE on the sheet.
const WAR_SCALE := 1.5
const STAFF_ROW := preload("res://entities/map_table/declaration_row.tscn")
const SOLDIER := "res://entities/war/soldiers/%s.tscn"
## A declaration's spots (box_at): "staff_less:<unit>", "staff_more:<unit>".
const STAFF_LESS := "staff_less:"
const STAFF_MORE := "staff_more:"
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
## The ring lies this high over what the stamp hits (m).
const RING_Y := 0.004
## Sliding, the paper is turned this far (rad) and squares up as it arrives.
const SLIDE_TURN := 0.22
## A heavy stamp (the last war's declaration) squashes and rings this much more.
const HEAVY := 1.6

## The stamp box's frame while the mouse is on it.
@export var hot_box: StyleBox

## The site the deed is for, its price as printed ({currency: amount}, UpgradeDesk.costs; empty when
## nobody sells), and whether it has been stamped.
var site := &""
var bill := {}
var stamped := false
## The negotiation record lies over the deed (its boxes take the clicks).
var haggling := false
## The campaign's last war: the stamp comes down heavier (HEAVY).
var heavy := false
## 1 lies flat, 0 is all rolled up at its top edge.
var open := 1.0:
	set(value):
		open = value
		_paper.set_shader_parameter(&"open", value)

var _moving: Tween
var _stamping: Tween
var _blinking: Tween
var _haggle_moving: Tween

@onready var _page: SubViewport = $Page
@onready var _paper: ShaderMaterial = $Paper.material_override
@onready var _title: Label = $Page/Form/Title
@onready var _site: Label = $Page/Form/Site
@onready var _site_name: Label = $Page/Form/SiteName
@onready var _briefing: Label = $Page/Form/Briefing
@onready var _final_frame: Control = $Page/Form/FinalFrame
@onready var _coins: Label = $Page/Form/Coins
@onready var _coins_short: Label = $Page/Form/CoinsShort
@onready var _cabbages: Label = $Page/Form/Cabbages
@onready var _cabbages_short: Label = $Page/Form/CabbagesShort
@onready var _small_print: Label = $Page/Form/SmallPrint
@onready var _reason: Label = $Page/Form/Reason
@onready var _box: Panel = $Page/Form/Box
@onready var _box_line: StyleBox = _box.get_theme_stylebox(&"panel")
@onready var _asked: Label = $Page/Form/Asked
@onready var _start: Control = $Page/Form/Start
@onready var _start_word: Label = $Page/Form/Start/Word
@onready var _haggle: Node3D = $Haggle
@onready var _haggle_rest := _haggle.position
## The negotiation letter (its own scene) lying over the deed.
@onready var negotiation: NegotiationLetter = _haggle
## The boxes a click takes on the deed, by spot (DEED_BOXES; the letter has its own).
@onready var _boxes: Dictionary[StringName, Panel] = {&"deed_stamp": _box, &"deed_haggle": $Page/Form/Start}
@onready var _imprint: Control = $Page/Form/Imprint
@onready var _strip: Control = $Page/Form/Strip
@onready var _staff_head: Label = $Page/Form/StaffHead
@onready var _staff: Control = $Page/Form/Staff
@onready var _no_staff: Control = $Page/Form/NoStaff
## What flashes when the staff refuse the stamp (blink), and the ink each is printed in.
@onready var _staff_inks: Dictionary[Label, Color] = {}
@onready var _figures: Node3D = $Figures
@onready var _resistance: Control = $Page/Form/Resistance
@onready var _stamp: Node3D = $Stamp
@onready var _stamp_rest := _stamp.position
@onready var _ring: MeshInstance3D = $Ring
@onready var _slide_sound: SoundCue = $Slide
@onready var _strike_sound: SoundCue = $Strike
@onready var _denied_sound: SoundCue = $Denied
@onready var _roll_sound: SoundCue = $Roll
@onready var _mood_sound: SoundCue = $MoodStamp
@onready var _agreed_sound: SoundCue = $Agreed
@onready var _envelope_sound: SoundCue = $Envelope
@onready var _price_up_sound: SoundCue = $PriceUp


func _ready() -> void:
	_paper.set_shader_parameter(&"sheet_tex", _page.get_texture())
	for label: Label in [_staff_head, $Page/Form/Box/Word, $Page/Form/NoStaff/Head, $Page/Form/NoStaff/Line]:
		_staff_inks[label] = label.get_theme_color(&"font_color")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		reprint()  # The form's fixed lettering changed.


## Prints the form onto the paper again: after any of its lettering changed.
func reprint() -> void:
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE
	negotiation.reprint()


## Whether form pixel `pixel` (from the deed's top left corner) is in the stamp box.
static func in_stamp_box(pixel: Vector2) -> bool:
	return STAMP_BOX.has_point(pixel)


## The spot that deed pixel `pixel` (from the deed's top left corner) is in, or &"": a box of the
## negotiation record while it lies over the deed (`record`) and the pixel is on it, else a box of
## the deed.
static func box_at(pixel: Vector2, record := false) -> StringName:
	var on_record := record and on_paper(page(pixel))
	var boxes: Dictionary = HAGGLE_BOXES if on_record else DEED_BOXES
	var at := page(pixel) if on_record else pixel
	for spot: StringName in boxes:
		if (boxes[spot] as Rect2).has_point(at):
			return spot
	return &""


## The declaration's [-] or [+] box at deed pixel `pixel` (STAFF_LESS / STAFF_MORE + the unit), with
## a row for each of `units` in order; &"" off them.
static func staff_box_at(pixel: Vector2, units: Array[String]) -> StringName:
	for i in units.size():
		var row := STAFF_AT + Vector2(0.0, i * ROW_HEIGHT)
		if Rect2(row + LESS_IN_ROW.position, LESS_IN_ROW.size).has_point(pixel):
			return StringName(STAFF_LESS + units[i])
		if Rect2(row + MORE_IN_ROW.position, MORE_IN_ROW.size).has_point(pixel):
			return StringName(STAFF_MORE + units[i])
	return &""


## How many times its fighting size `figure` stands in a staff row: FIGURE_SCALE, or more for a small
## one, to FIGURE_FOOT px across seen from above.
static func figure_scale(figure: Node3D) -> float:
	var box := AABB()
	for mesh: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
		box = box.merge(mesh.transform * mesh.get_aabb())
	return maxf(FIGURE_SCALE, FIGURE_FOOT / PIXELS_PER_METRE / maxf(box.size.x, box.size.z))


## Deed pixel `pixel` on the negotiation record's own page.
static func page(pixel: Vector2) -> Vector2:
	return HAGGLE_PAGE.affine_inverse() * pixel


## Whether `pixel` of a paper of SIZE (from its top left corner) is on it.
static func on_paper(pixel: Vector2) -> bool:
	return Rect2(Vector2.ZERO, SIZE * PIXELS_PER_METRE).has_point(pixel)


## Whether deed pixel `pixel` is on the deed, or on the record lying over it (`record`).
static func covers(pixel: Vector2, record := false) -> bool:
	return on_paper(pixel) or (record and on_paper(page(pixel)))


## Farm `at` as a form prints it: "K-3" at home, the country's initial abroad ("ostrevia-1": "O-1").
static func code(at: String) -> String:
	return at if at.rfind("-") <= 1 else at.left(1).to_upper() + at.substr(at.rfind("-"))


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
	_site.text = tr("FARM SITE %s") % code(at)
	_imprint.hide()
	_strip.visible = price.is_empty()
	_reason.visible = price.is_empty()
	_reason.text = reason
	_box.visible = not price.is_empty()
	_small_print.visible = not price.is_empty()
	($Page/Form/PriceHead as Label).visible = not price.is_empty()
	print_staff([])
	print_resistance({})
	print_site({})
	hot(&"")
	print_price(price, lacks)
	print_haggle()


## Letters the filled paper as form `kind` (FORMS): its form line, price head, small print and
## stamp; `strip` is what the strip of one that cannot be stamped says (a key; "": the form's own).
func letter(kind: StringName, strip := "") -> void:
	var form: Dictionary = FORMS[kind]
	($Page/Form/FormLine as Label).text = form.form
	($Page/Form/PriceHead as Label).text = form.head
	($Page/Form/Imprint/Word as Label).text = form.seal
	_small_print.text = form.note
	($Page/Form/Strip/Word as Label).text = strip if strip != "" else form.strip
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


## Prints a declaration's staff: one row per `rows` entry ({unit, name, have, take}, in order), its
## figure standing on the row; none (empty) hides the whole section. Nobody trained in any row: the
## NO STAFF notice instead of the rows.
func print_staff(rows: Array) -> void:
	var war := not rows.is_empty()
	var nobody := war and rows.all(func(row: Dictionary) -> bool: return int(row.have) <= 0)
	_staff_head.visible = war
	_staff.visible = war and not nobody
	_figures.visible = war and not nobody
	_no_staff.visible = nobody
	($Page/Form/Rule2 as Control).visible = not war
	($Page/Form/Rule3 as Control).visible = not war
	if war:
		_small_print.hide()
	else:
		reprint()
		return
	var units := rows.map(func(row: Dictionary) -> String: return row.unit)
	for old in _staff.get_children():  # A type no longer on the paper.
		if not units.has(String(old.name)):
			old.free()
	for figure in _figures.get_children():
		if not units.has(String(figure.name)):
			figure.free()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var line := _staff.get_node_or_null(NodePath(row.unit)) as Control
		if line == null:
			line = STAFF_ROW.instantiate()
			line.name = row.unit
			_staff.add_child(line)
			var figure: Node3D = (load(SOLDIER % row.unit) as PackedScene).instantiate()
			figure.name = row.unit
			figure.scale = Vector3.ONE * figure_scale(figure)
			_figures.add_child(figure)
		line.position = Vector2(0.0, i * ROW_HEIGHT)
		(line.get_node("Name") as Label).text = row.name
		(line.get_node("Have") as Label).text = tr("HAVE %d") % row.have
		(line.get_node("Take") as Label).text = str(row.take)
		var stand := STAFF_AT + line.position + (line.get_node("Stand") as Control).position
		(_figures.get_node(NodePath(row.unit)) as Node3D).position = Vector3(stand.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0, stand.y / PIXELS_PER_METRE)
	reprint()


## Prints ASSESSED RESISTANCE from `rating` (WarMap.difficulty_for: its band 1 .. 5 lights as many
## pips, band_name in words, and the field associates estimated to take it; -1: more than the army
## cap allows); {} hides it.
func print_resistance(rating: Dictionary) -> void:
	_resistance.visible = not rating.is_empty()
	if rating.is_empty():
		reprint()
		return
	($Page/Form/Resistance/Rating as Label).text = tr(rating.band_name)
	for k in WarMap.BAND_NAMES.size():
		($Page/Form/Resistance/Pips.get_node("Pip%d/Fill" % k) as Control).visible = k < int(rating.band)
	var associates := int(rating.associates)
	($Page/Form/Resistance/Estimate as Label).text = tr("Estimated staff required: %d field associates.") % associates \
			if associates > 0 else tr("Estimated staff required: exceeds current headcount.")
	reprint()


## Prints the war's site under the farm's name from `brief` (WarMap.brief_for: site_name and briefing,
## keys, "" unfilled; final: the campaign's last war, an oxblood border and a heavier stamp); {} or
## an unfilled map prints none and the name has its two lines back.
func print_site(brief: Dictionary) -> void:
	var shown: bool = brief.get("site_name", "") != ""
	_site_name.visible = shown
	_briefing.visible = shown
	_site.visible = not shown  # The site's name says where; its code would crowd the briefing.
	_site_name.text = tr(brief.get("site_name", ""))
	_briefing.text = tr(brief.get("briefing", ""))
	_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP if shown else VERTICAL_ALIGNMENT_CENTER
	_title.max_lines_visible = 1 if shown else -1
	heavy = brief.get("final", false)
	_final_frame.visible = heavy
	reprint()


## A declaration's count of staff turned a notch: the dial's click.
func count_tick() -> void:
	($Count as SoundCue).cue(global_position)


## Prints the negotiation: what is offered (`paid_in`: "stock" cabbages, "coins" a bribe; "": nobody
## haggles over this deed, its band stays empty), a bundle's size, the owner's name, his replies so
## far (`replies`: each {offered, mood, line} in words, NegotiationLetter.print_letter), how many more
## offers he hears (`left`), the coin price first `asked` (ASKED beside the price once it has moved),
## what is in stock or the purse (`have`) and the letter's small print, `note` (a key). The deed's
## band says START HAGGLING, after an offer how it stands. Call it after print_price: the letter
## prints the price as it stands.
func print_haggle(paid_in := "", size := 0, owner_name := "", replies: Array = [], left := 0, asked := 0, have := 0, note := "Cabbages offered are not returned.") -> void:
	var on := paid_in != ""
	_start.visible = on
	var moved: bool = on and bill.get("coins", asked) != asked
	_asked.visible = moved
	if not on:
		return
	_start_word.text = tr("START HAGGLING" if replies.is_empty() else ("RESUME HAGGLING" if left > 0 else "NEGOTIATION RECORD"))
	_asked.text = tr("ASKED %s") % ("$" + FarmScreen._thousands(asked))
	negotiation.print_letter(paid_in, size, owner_name, bill, replies, left, have, note)
	reprint()


## The box under the mouse (`spot` of DEED_BOXES or HAGGLE_BOXES; &"": none): its frame goes heavy and oxblood.
func hot(spot: StringName) -> void:
	for box: StringName in _boxes:
		_boxes[box].add_theme_stylebox_override(&"panel", hot_box if box == spot else _box_line)
	negotiation.hot(spot)
	for row in _staff.get_children():
		for side: String in ["Less", "More"]:
			var key := (STAFF_LESS if side == "Less" else STAFF_MORE) + String(row.name)
			(row.get_node(side) as Panel).add_theme_stylebox_override(&"panel", hot_box if spot == StringName(key) else _box_line)
	reprint()


## The stamp refused: what is short flashes red twice, to a jammed lever's dead clunk; `staff`:
## STAFF COMMITTED, the NO STAFF notice and STAMP HERE flash instead (nobody chosen, nobody trained).
func blink(staff := false) -> void:
	_denied_sound.cue(global_position)
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	for colour: Color in [INK, DENIED_RED, INK, DENIED_RED]:
		_blinking.tween_callback(_ink_short.bind(colour, staff))
		_blinking.tween_interval(BLINK_TIME)
	_blinking.tween_callback(_ink_short.bind(DENIED_RED, false))  # The staff's lettering goes back to ink.


## Slides flat over the sheet from `from` to `to` (in the parent's space) in `time` s, squaring up
## as it arrives; `away` slides it off instead and hides it at the end.
func slide(from: Vector3, to: Vector3, time: float, away := false) -> void:
	_still()
	if not away:
		shut_haggle()  # A deed comes in on its own; the record waits for START HAGGLING.
	open = 1.0
	show()
	_slide_sound.cue(global_position)
	var turn := SLIDE_TURN * signf(from.x - to.x if not away else to.x - from.x)
	_moving = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN if away else Tween.EASE_OUT)
	_moving.tween_property(self, "position", to, time).from(from)
	_moving.tween_property(self, "rotation:y", turn if away else 0.0, time).from(0.0 if away else turn)
	if away:
		_moving.chain().tween_callback(hide)


## The negotiation record slides over the deed (`up`) from `from` m to the deed's side (along its
## x), or off it that way and is gone, in `time` s, to the deed's slide.
func lay_haggle(up: bool, from: float, time: float) -> void:
	haggling = up
	if _haggle_moving != null:
		_haggle_moving.kill()
	_haggle.show()
	_slide_sound.cue(global_position)
	var off := _haggle_rest + Vector3.RIGHT * from
	_haggle.position = off if up else _haggle_rest
	_haggle_moving = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if up else Tween.EASE_IN)
	_haggle_moving.tween_property(_haggle, "position", _haggle_rest if up else off, time)
	if not up:
		negotiation.clear()  # What lay on the offer goes back to the crate.
		_haggle_moving.tween_callback(_haggle.hide)


## Where the negotiation letter rests on the deed (the deed's own space).
func letter_rest() -> Transform3D:
	return Transform3D(_haggle.basis, _haggle_rest)


## The record is gone at once.
func shut_haggle() -> void:
	haggling = false
	if _haggle_moving != null:
		_haggle_moving.kill()
	_haggle.hide()
	_haggle.position = _haggle_rest
	negotiation.clear()


## The stamp comes down on the owner's newest reply slip on the letter in `time` s.
func strike_mood(time: float) -> void:
	strike(time, HAGGLE_PAGE * negotiation.stamp_spot(), HAGGLE_LIFT)


## The stamp comes down on deed pixel `on` (the stamp box), `lift` m over the deed, in `time` s, from
## STAMP_FROM above it.
func strike(time: float, on := STAMP_BOX.get_center(), lift := 0.0) -> void:
	if _stamping != null:
		_stamping.kill()
	var at := Vector3(on.x / PIXELS_PER_METRE - SIZE.x / 2.0, lift, on.y / PIXELS_PER_METRE)
	_stamp.position = at + Vector3.UP * _stamp_rest.y
	_ring.position = at + Vector3.UP * RING_Y
	_stamp.scale = Vector3.ONE
	_stamp.show()
	_stamping = create_tween()
	_stamping.tween_property(_stamp, "position:y", at.y + _stamp_rest.y, time).from(at.y + _stamp_rest.y + STAMP_FROM) \
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
## offer `landed` (the coins saved rattle) or missed (the price is typed over, upward).
func stamp_mood(landed: bool) -> void:
	_mood_sound.cue(_stamp.global_position)
	(_agreed_sound if landed else _price_up_sound).cue(_stamp.global_position)
	_hit()


## An envelope is passed across (a bribe offered).
func envelope() -> void:
	_envelope_sound.cue(global_position)


## The stamp's hit: the head squashed, a ring from under it.
func _hit() -> void:
	var weight := HEAVY if heavy else 1.0
	_stamp.scale = Vector3(1.0 + 0.12 * weight, 1.0 - 0.2 * weight, 1.0 + 0.12 * weight)
	var ink := _ring.get_surface_override_material(0) as StandardMaterial3D
	_ring.show()
	var burst := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	burst.tween_property(_ring, "scale", Vector3(RING_TO * weight, 1.0, RING_TO * weight), RING_TIME * weight).from(Vector3(0.5, 1.0, 0.5))
	burst.tween_property(ink, "albedo_color:a", 0.0, RING_TIME * weight).from(0.8)
	burst.chain().tween_callback(_ring.hide)


## The stamp lifts off the paper in `time` s and is gone.
func lift_stamp(time: float) -> void:
	if _stamping != null:
		_stamping.kill()
	_stamping = create_tween()
	_stamping.tween_property(_stamp, "scale", Vector3.ONE, 0.08)
	_stamping.parallel().tween_property(_stamp, "position:y", _stamp.position.y + STAMP_FROM, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamping.tween_callback(_stamp.hide)


## Rolls itself up to its top edge in `roll_time` s, then drops off the map towards `to` (in the
## parent's space) in `drop_time` s and is gone.
func roll_away(to: Vector3, roll_time: float, drop_time: float) -> void:
	_still()
	shut_haggle()
	_figures.hide()  # They would stand in the air over the rolled paper.
	_roll_sound.cue(global_position)
	_moving = create_tween()
	_moving.tween_property(self, "open", 0.0, roll_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_moving.tween_property(self, "position", to, drop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_moving.tween_callback(hide)


func _ink_short(colour: Color, staff := false) -> void:
	for label: Label in [_coins_short, _cabbages_short]:
		label.add_theme_color_override(&"font_color", colour)
	for label: Label in _staff_inks:
		label.add_theme_color_override(&"font_color", colour if staff and colour != INK else _staff_inks[label])
	reprint()


func _still() -> void:
	if _moving != null:
		_moving.kill()
