class_name PaperNote
extends Control
## An upgrade card as flat 2D paper, cut from the 3D card's own texture: the form line and title in
## the green header band, then the body written on the ruled lines, one texture row per wrapped
## line, so every line of text sits on a ruling. Never takes the mouse, so the hand under it keeps going.
## The body's first line is flavour (deadpan, no rules in it): it is slanted (italic) and a touch darker, the rest upright.

const PAPER := preload("res://assets/textures/card_paper/card_paper_albedo.png")
const TITLE_FONT := preload("res://assets/fonts/Oswald.ttf")
const BODY_FONT := preload("res://assets/fonts/NunitoSans.ttf")
const INK := Color(0.9, 0.89, 0.84)
## The flavour line's ink: a touch darker, so it reads as an aside.
const FLAVOUR_INK := Color(0.68, 0.68, 0.64)
## Pieces of the texture (px): the header band with its rule, one ruled row with its line RULE_AT
## from the row's top (the texture rules every 80 px), a blank strip of a row for the price, and the
## foot. The right edge leaves out the card's own price box.
const HEAD := Rect2(0, 0, 870, 116)
const ROW := Rect2(0, 384, 870, 80)
const RULE_AT := 76.0
const BLANK := Rect2(0, 386, 870, 70)
const FOOT := Rect2(0, 600, 870, 40)
## Texture px to screen px.
const SCALE := 0.92
## Where the writing starts and ends (texture px), inside the ruling.
const TEXT_LEFT := 84.0
const TEXT_RIGHT := 840.0
## In the band (texture px from its top): the form line's and the title's baselines.
const FORM_AT := 36.0
const TITLE_AT := 98.0
const FORM_SIZE := 20
const TITLE_SIZE := 46
const BODY_SIZE := 30
## The price (in the blank strip, at the bottom right): its size, and its ruled box's padding and line.
const PRICE_SIZE := 34
const PRICE_PAD := Vector2(14, 6)
const PRICE_RULE := Color(0.5, 0.5, 0.49)

var _form := ""
var _title := ""
var _price := ""
var _currency := "coins"
## The card paper's dye (UpgradeCard.paper_tint): a priority form is oxblood here too.
var _tint := Color.WHITE
var _body := TextParagraph.new()
## Characters of _body that are the flavour line.
var _flavour_len := 0
static var _italics := {}


## Shows card `card` (an UpgradeDesk.CARDS entry).
func set_card(card: Dictionary) -> void:
	_form = tr(UpgradeCard.form_of(card))
	_tint = UpgradeCard.paper_tint(card)
	_title = tr(card.title)
	_currency = card.get("currency", "coins")
	_price = UpgradeCard.price_text(card.price, _currency)
	_body.clear()
	_body.width = (TEXT_RIGHT - TEXT_LEFT) * SCALE
	var parts := flavour_split(tr(card.body))
	_flavour_len = parts[0].length()
	if parts[0] != "":
		_body.add_string(parts[0] + ("\n" if parts[1] != "" else ""), italic(BODY_FONT), BODY_SIZE)
	_body.add_string(parts[1], BODY_FONT, BODY_SIZE)
	custom_minimum_size = Vector2(HEAD.size.x, HEAD.size.y + ROW.size.y * _body.get_line_count() + BLANK.size.y + FOOT.size.y) * SCALE
	queue_redraw()


## An upgrade body split into its flavour line (the first, before a line break) and the
## description; a body without a line break is all description.
static func flavour_split(body: String) -> PackedStringArray:
	var at := body.find("\n")
	return PackedStringArray(["", body]) if at < 0 else PackedStringArray([body.left(at), body.substr(at + 1)])


## The ink of a body line starting at character `start`, the flavour line `flavour_len` long.
static func line_ink(start: int, flavour_len: int) -> Color:
	return FLAVOUR_INK if start < flavour_len else INK


## `font` slanted like italic (one FontVariation per font, shared).
static func italic(font: Font) -> Font:
	if not _italics.has(font):
		var slanted := FontVariation.new()
		slanted.base_font = font
		slanted.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
		_italics[font] = slanted
	return _italics[font]


func _draw() -> void:
	var x := TEXT_LEFT * SCALE
	var y := _piece(HEAD, 0.0)
	draw_string(TITLE_FONT, Vector2(x, FORM_AT * SCALE), _form, HORIZONTAL_ALIGNMENT_LEFT, -1, FORM_SIZE, Color(INK, 0.7))
	# A long title steps down until it fits the band's width.
	var font_size := TITLE_SIZE
	while font_size > 24 and TITLE_FONT.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _body.width:
		font_size -= 2
	draw_string(TITLE_FONT, Vector2(x, TITLE_AT * SCALE), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	for line in _body.get_line_count():
		# The baseline sits just above the row's ruled line.
		var baseline := y + (RULE_AT - 6.0) * SCALE
		y = _piece(ROW, y)
		_body.draw_line(get_canvas_item(), Vector2(x, baseline - _body.get_line_ascent(line)), line, line_ink(_body.get_line_range(line).x, _flavour_len))
	var strip := y
	y = _piece(BLANK, y)
	_piece(FOOT, y)
	# The price in a ruled box like the card's, right-aligned to the writing.
	var text := Vector2(UpgradeCard.price_width(_price, _currency, PRICE_SIZE, 1.0), TITLE_FONT.get_height(PRICE_SIZE))
	var box := Rect2(Vector2.ZERO, text + PRICE_PAD * 2.0)
	box.position = Vector2(TEXT_RIGHT * SCALE - box.size.x, strip + (BLANK.size.y * SCALE - box.size.y) * 0.5)
	draw_rect(box, PRICE_RULE, false, 2.0)
	UpgradeCard.draw_price(self, TITLE_FONT, Vector2(box.end.x - PRICE_PAD.x, box.position.y + PRICE_PAD.y + TITLE_FONT.get_ascent(PRICE_SIZE)),
			_price, _currency, PRICE_SIZE, INK)


## Draws texture piece `region` across the paper's width at height `y`; returns where it ends.
func _piece(region: Rect2, y: float) -> float:
	draw_texture_rect_region(PAPER, Rect2(Vector2(0.0, y), region.size * SCALE), region, _tint)
	return y + region.size.y * SCALE
