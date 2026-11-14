class_name NegotiationLetter
extends Node3D
## The negotiation with one farm's owner (FORM 3-N), a paper laid over his farm's deed (FarmDeed
## `Haggle`: START HAGGLING lays it there, BACK TO THE DEED takes it away). FarmRegister has the
## rules and decides what a click does; the letter only shows, and holds the bundles on it.
## Its page (`Page`, 1 px = 1 mm, printed on `Paper` as the deed's), top to bottom: the form line,
## the owner's name, the price as it stands; then the conversation: before the first offer how it
## works and the small print, after it one typed reply slip per offer (reply_slip.tscn, `Slips`),
## each below the one before (SLIP_STEP), every line in full: his line, what it answered ("re: 60 cabbages") and his mood stamped on it.
## At the bottom, left, YOUR OFFER (PILE_BOX): the bundles on the paper and their total; under it
## SEND OFFER (SEND_BOX); right, the crate of stock (CRATE_BOX, `Crate`: up to four bundles in it)
## with how much is in stock, and BACK TO THE DEED (RETURN_BOX).
## A bundle (OfferBundle) is `bundle` cabbages (FarmRegister.bundle; coins for a bribe: a stack of
## coins). grab() takes one out of the crate and it follows the mouse (drag_to) until it is let go
## (drop): on the offer it lies there in the next free place (PILE_PLACES), anywhere else it goes
## back. take_back() lifts the one nearest the click off the offer into the crate. send() carries
## the pile off the paper the way the deed came; the reply slip comes with the next print.
## Sounds: Thud (a cabbage set down or taken back; Clink for coins), Slide (the pile goes, a slip
## arrives).

const SIZE := Vector2(0.82, 1.04)
const PIXELS_PER_METRE := 1000.0
## The boxes on the page (px): what a click takes (BOXES, box_at).
const PILE_BOX := Rect2(44, 630, 476, 282)
const SEND_BOX := Rect2(44, 922, 476, 80)
const CRATE_BOX := Rect2(540, 630, 236, 222)
const RETURN_BOX := Rect2(540, 912, 236, 90)
const BOXES := {&"deed_pile": PILE_BOX, &"deed_send": SEND_BOX, &"deed_crate": CRATE_BOX, &"deed_return": RETURN_BOX}
## Where bundles lie on the offer (px): five across, three deep, the first top left.
const PILE_FIRST := Vector2(96, 744)
const PILE_STEP := Vector2(92, 64)
const PILE_ACROSS := 5
const MOST := 15
## The reply slips: the first one's top left corner (px), each next one this much lower (all five
## fit between the rules, none covers another's line), turned a little the other way (rad); the mood stamp lands on SLIP_STAMP of the newest.
const SLIP_AT := Vector2(44, 200)
const SLIP_STEP := 84.0
const SLIP_TURN := 0.012
const SLIP_STAMP := Vector2(103, 24)
## A held bundle rides this high over the paper (m); one let go settles in SETTLE_TIME s.
const HOLD_LIFT := 0.06
const SETTLE_TIME := 0.16
## Moved less than this (px) between grab and drop, it was a click on the crate: onto the offer.
const CLICK := 30.0
const SLIP := preload("res://entities/map_table/reply_slip.tscn")
const BUNDLE := preload("res://entities/map_table/offer_bundle.tscn")

## The box frame while the mouse is on it, and its frame otherwise.
@export var hot_box: StyleBox
@export var box_line: StyleBox

## Bundles on the offer, and how many cabbages (coins) each is.
var count := 0
var bundle := 0
## What is offered: "stock" (cabbages) or "coins" (a bribe).
var paid_in := "stock"

var _pile: Array[OfferBundle] = []
var _held: OfferBundle
var _held_from := Vector2.ZERO
var _held_moved := 0.0
## What is in stock (or the purse) as last printed.
var _have := 0

@onready var _page: SubViewport = $Page
@onready var _owner: Label = $Page/Form/Owner
@onready var _price: Label = $Page/Form/Price
@onready var _opening: Label = $Page/Form/Opening
@onready var _note: Label = $Page/Form/Note
@onready var _slips: Control = $Page/Form/Slips
@onready var _head: Label = $Page/Form/Pile/Head
@onready var _total: Label = $Page/Form/Pile/Total
@onready var _closed: Label = $Page/Form/Pile/Closed
@onready var _send_word: Label = $Page/Form/Send/Word
@onready var _stock: Label = $Page/Form/Stock
@onready var _crate: Node3D = $Crate
@onready var _crate_bundles: Array[Node] = $Crate/Bundles.get_children()
@onready var _bundles: Node3D = $Bundles
@onready var _boxes: Dictionary[StringName, Panel] = {&"deed_pile": $Page/Form/Pile, &"deed_send": $Page/Form/Send,
		&"deed_crate": $Page/Form/Crate, &"deed_return": $Page/Form/Return}
@onready var _thud: SoundCue = $Thud
@onready var _clink: SoundCue = $Clink
@onready var _slide: SoundCue = $Slide


func _ready() -> void:
	($Paper.material_override as ShaderMaterial).set_shader_parameter(&"sheet_tex", _page.get_texture())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		reprint()


## Prints the page onto the paper again.
func reprint() -> void:
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE


## The box at page pixel `pixel`, or &"".
static func box_at(pixel: Vector2) -> StringName:
	for spot: StringName in BOXES:
		if (BOXES[spot] as Rect2).has_point(pixel):
			return spot
	return &""


## Where the `i`-th bundle on the offer lies (page px).
static func pile_place(i: int) -> Vector2:
	return PILE_FIRST + Vector2(i % PILE_ACROSS, floori(i / float(PILE_ACROSS))) * PILE_STEP


## Page pixel `pixel` on the paper, `lift` m over it (the letter's own space).
static func point(pixel: Vector2, lift := 0.0) -> Vector3:
	return Vector3(pixel.x / PIXELS_PER_METRE, lift, pixel.y / PIXELS_PER_METRE)


## Prints the negotiation with `owner_name`'s farm: what is offered (`what`: "stock" or "coins"), a
## bundle's size, the price as it stands (`price`: {coins, stock}), the replies so far (`replies`:
## each {offered, mood, line} in order, `mood` and `line` already in words), how many more offers he
## hears (`left`; 0: NO FURTHER OFFERS), what is in stock (`have`) and the small print `note` (a key;
## until the first reply).
func print_letter(what: String, size: int, owner_name: String, price: Dictionary, replies: Array, left: int, have: int, note: String) -> void:
	if what != paid_in or size != bundle:
		clear()  # Another tender: the pile was of the other kind.
	paid_in = what
	bundle = size
	_owner.text = tr("Owner: %s") % owner_name
	_price.text = "$%s + %s" % [FarmScreen._thousands(price.get("coins", 0)), tr("%s cabbages") % FarmScreen._thousands(price.get("stock", 0))]
	_opening.text = tr("Drag cabbages from the crate onto your offer, then send it. Too few raise the price. Enough lower it."
			if what == "stock" else "Put coins from the purse in the envelope, then pass it. Too little raises the price. Enough lowers it.")
	_opening.visible = replies.is_empty()
	_note.text = note  # The label translates it.
	_note.visible = replies.is_empty()
	while _slips.get_child_count() < replies.size():
		var slip := SLIP.instantiate() as Control
		var i := _slips.get_child_count()
		slip.position = Vector2(0.0, SLIP_STEP * i)
		slip.rotation = SLIP_TURN * (1.0 if i % 2 == 0 else -1.0)
		_slips.add_child(slip)
	while _slips.get_child_count() > replies.size():
		var gone := _slips.get_child(-1)
		_slips.remove_child(gone)
		gone.queue_free()
	for i in replies.size():
		var slip := _slips.get_child(i)
		(slip.get_node("Line") as Label).text = replies[i].line
		(slip.get_node("Imprint/Word") as Label).text = replies[i].mood
		(slip.get_node("About") as Label).text = tr("re: %s") % amount_text(what, replies[i].offered)
	_closed.visible = left <= 0
	_head.text = tr("OFFER %d OF %d") % [replies.size() + 1, replies.size() + left] if left > 0 else tr("YOUR OFFER")
	_total.visible = left > 0
	_send_word.text = tr("SEND OFFER" if what == "stock" else "PASS THE ENVELOPE")
	(_boxes[&"deed_send"] as Control).visible = left > 0
	_crate.visible = left > 0
	(_boxes[&"deed_crate"] as Control).visible = left > 0
	_stock.visible = left > 0
	_stock.text = tr("IN STOCK %s") % FarmScreen._thousands(have) if what == "stock" else tr("IN THE PURSE %s") % ("$" + FarmRegister.short_coins(have))
	_have = have
	for shown: OfferBundle in _crate_bundles:
		shown.coins = what == "coins"
		shown.restyle()
		shown.label(size)
	if left <= 0:
		clear()
	_print_total()


## `amount` of what is offered as the letter types it: "60 cabbages", "$150,000".
static func amount_text(what: String, amount: int) -> String:
	return "$" + FarmScreen._thousands(amount) if what == "coins" else TranslationServer.translate("%s cabbages") % FarmScreen._thousands(amount)


## What is on the offer now (cabbages, or coins).
func offered() -> int:
	return count * bundle


## A bundle comes out of the crate into the hand (page px `at`). False when the offer is full.
func grab(at: Vector2) -> bool:
	if count >= MOST or _held != null:
		return false
	_held = _new_bundle()
	_held.position = point(CRATE_BOX.get_center(), HOLD_LIFT)
	_held_from = at
	_held_moved = 0.0
	drag_to(at)
	_sound()
	return true


## Whether a bundle is in the hand.
func holding() -> bool:
	return _held != null


## The bundle in the hand follows the mouse to page pixel `at`.
func drag_to(at: Vector2) -> void:
	if _held == null:
		return
	_held_moved = maxf(_held_moved, at.distance_to(_held_from))
	_held.position = point(at, HOLD_LIFT)


## The bundle in the hand is let go: on the offer (`on_pile`), or a click on the crate (it hardly
## moved), it lies on the offer; anywhere else it goes back into the crate. Whether it was added.
func drop(on_pile: bool) -> bool:
	if _held == null:
		return false
	var bundle_now := _held
	_held = null
	if on_pile or _held_moved < CLICK:
		_pile.append(bundle_now)
		count = _pile.size()
		_settle(bundle_now, point(pile_place(count - 1)))
		_sound()
		_print_total()
		return true
	_settle(bundle_now, point(CRATE_BOX.get_center()), true)
	return false


## The bundle on the offer nearest page pixel `at` goes back into the crate; the rest close up.
func take_back(at: Vector2) -> void:
	if _pile.is_empty():
		return
	var nearest := 0
	for i in _pile.size():
		if pile_place(i).distance_to(at) < pile_place(nearest).distance_to(at):
			nearest = i
	var bundle_now: OfferBundle = _pile.pop_at(nearest)
	count = _pile.size()
	_settle(bundle_now, point(CRATE_BOX.get_center()), true)
	for i in _pile.size():
		_settle(_pile[i], point(pile_place(i)))
	_sound()
	_print_total()


## The pile is carried off the paper along x by `away` m in `time` s and is gone: the offer is sent.
func send(away: float, time: float) -> void:
	_slide.cue(global_position)
	for bundle_now in _pile:
		var tween := bundle_now.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(bundle_now, "position", bundle_now.position + Vector3(away, HOLD_LIFT, 0.0), time)
		tween.tween_callback(bundle_now.queue_free)
	_pile.clear()
	count = 0
	_print_total()


## A reply slip has arrived (the next print has it): its paper sound.
func slip_arrives() -> void:
	_slide.cue(global_position)


## Where the stamp lands on the newest reply slip (page px).
func stamp_spot() -> Vector2:
	var i := maxi(_slips.get_child_count() - 1, 0)
	return SLIP_AT + Vector2(0.0, SLIP_STEP * i) + SLIP_STAMP


## Every bundle off the paper at once (the letter is put away, or no offer is heard any more).
func clear() -> void:
	for bundle_now in _pile:
		bundle_now.queue_free()
	_pile.clear()
	if _held != null:
		_held.queue_free()
		_held = null
	count = 0
	if is_node_ready():
		_print_total()


## The box under the mouse (`spot` of BOXES; &"": none): its frame goes heavy and oxblood.
func hot(spot: StringName) -> void:
	for box: StringName in _boxes:
		_boxes[box].add_theme_stylebox_override(&"panel", hot_box if box == spot else box_line)
	reprint()


## The total on the offer, and the crate shows as many bundles (up to four) as stock is left for.
func _print_total() -> void:
	_total.text = amount_text(paid_in, offered())
	for i in _crate_bundles.size():
		(_crate_bundles[i] as Node3D).visible = bundle > 0 and _have >= (count + i + 1) * bundle
	reprint()


func _new_bundle() -> OfferBundle:
	var made := BUNDLE.instantiate() as OfferBundle
	made.coins = paid_in == "coins"
	_bundles.add_child(made)
	made.label(bundle)
	return made


## `which` slides to `to` and settles; `gone` frees it there (back in the crate).
func _settle(which: OfferBundle, to: Vector3, gone := false) -> void:
	var tween := which.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(which, "position", to, SETTLE_TIME)
	if gone:
		tween.tween_callback(which.queue_free)


func _sound() -> void:
	(_clink if paid_in == "coins" else _thud).cue(global_position)
