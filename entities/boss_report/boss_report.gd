class_name BossReport
extends CanvasLayer
## The boss's reports: the WELCOME note on a new game, and one for each big event when it starts
## (GameEvents.EVENTS, `due`; its `report`: a headline `re` and a `body`). It drops in from the top
## to the middle of the screen, big, and stays until signed: the mouse is a pen over the signature field
## and draws ink there; once SIGN_INK px are drawn an OK button shows, and clicked the report flies
## into the FILES folder (the memo's) and the next one, if any, comes. The game keeps running, but
## only the paper takes the mouse: a grey Backdrop under it blocks the rest of the screen. Signed ids go into save.reports (one up or queued at quit comes again).
## In a save from before the reports, what had already happened is filed without the paper.

const Events := preload("res://globalScripts/game_events.gd")
const Memo := preload("res://entities/milestone/milestone_memo.gd")

const WELCOME := {re = "WELCOME TO DESK 4",
	body = "You have been given a desk, a window and a supply of cabbages. Throw cabbages out of the window to sell them. The street pays in coins. Move your hand over the coins on the mat to collect them. Further instructions will follow in writing. Sign below to confirm you have understood."}
## The demo's last report, Demo.END_AFTER seconds of farming after the family farm (save.farm_seconds).
## No signature (`buttons`): WISHLIST opens the store page (STORE_URL), DONE files it.
const DEMO_END := {re = "END OF THE TRIAL PERIOD", buttons = true,
	body = "You have reached the end of the demo. Your performance has been noted. Go and wishlist the game on Steam now: the full version continues your career at Desk 4."}
## The game's Steam store page (the app id goes here once the page exists).
const STORE_URL := "https://store.steampowered.com/"
const WISH_BOX := Rect2(30, 318, 260, 50)
const STEAM_GREEN := Color(0.4, 0.6, 0.1)
const STEAM_TEXT := Color(0.84, 0.94, 0.66)
const SIZE := Vector2(640, 400)
## The signature field and the OK button (paper px), and how much ink (px of stroke) counts as signed.
const SIGN_BOX := Rect2(30, 300, 330, 74)
const OK_BOX := Rect2(470, 318, 140, 50)
const SIGN_INK := 120.0
const INK := Color(0.1, 0.12, 0.2)
const CHECK_EVERY := 0.5
## Seconds to drop in and the flight into the folder.
const IN_TIME := 0.45
const FLY_TIME := 0.55
const FLY_SCALE := 0.08
const TILT := -1.5
## The paper's size on screen, × SIZE: big, in the middle of the screen.
const ZOOM := 1.45
## The text's room: from TEXT_TOP (under the header rule) to TEXT_GAP above the signature or the
## buttons. The headline shrinks from RE_SIZE to fit RE_LINES lines, then the body from BODY_SIZE
## down to BODY_MIN to fit what is left.
const TEXT_TOP := 78.0
const TEXT_GAP := 10.0
const RE_SIZE := 34
const RE_LINES := 2
const BODY_SIZE := 18
const BODY_MIN := 13
## The grey veil behind an open report (its alpha at full; it fades in with the drop, out with the flight).
const VEIL := 0.55
## Event reports held back for the alpha: chapter 3's paper describes a chapter not built yet, so the
## alpha's end popup (ui/sub/alpha_end, AlphaEnd) comes instead. Not filed: empty this to bring it back.
const HELD := ["invest_in_growth"]

## The memo layer: its FILES folder is where filed reports fly.
@export var memo: CanvasLayer

## Whether a report is up (FarmTv lets the mouse through to it then).
static var up := false

var _queue: Array[String] = []
var _id := ""
var _t := 0.0
## Seconds since OK was clicked, or -1 while it is up.
var _leaving := -1.0
var _check_in := 0.0
## The signature: strokes of paper px, and whether the pen is down.
var _strokes: Array[PackedVector2Array] = []
var _pen_down := false
## layout() of the report up, and the "id|locale" it was computed for.
var _fit := {}
var _fit_key := ""

@onready var _paper: Control = $Paper
## Behind the paper, over the whole screen: nothing in the game takes the mouse while a report is up.
@onready var _backdrop: ColorRect = $Backdrop
@onready var _alpha_end: AlphaEnd = $AlphaEnd


func _ready() -> void:
	up = false
	_paper.size = SIZE
	_paper.pivot_offset = SIZE / 2.0
	_paper.visible = false
	_paper.draw.connect(_draw_paper)
	_paper.gui_input.connect(_on_paper_input)
	# Over the signature field the OS cursor is a pen: the cross shape, re-skinned game-wide (nothing
	# else uses CURSOR_CROSS).
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(pen_image()), Input.CURSOR_CROSS, Vector2(1, 30))
	# A save from before the reports: what has happened already is filed without the paper.
	var save := SaveManager.save
	if save.reports.is_empty() and save.sold > 0:
		save.reports = PackedStringArray(due(save))


func _process(delta: float) -> void:
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = CHECK_EVERY
		for id in due(SaveManager.save):
			if id != _id and not _queue.has(id):
				_queue.append(id)
	if _id.is_empty():
		if _alpha_end.visible:
			return
		if _queue.is_empty():
			if AlphaEnd.due(SaveManager.save):
				_alpha_end.open()
			return
		_id = _queue.pop_front()
		_t = 0.0
		_leaving = -1.0
		_strokes.clear()
		_pen_down = false
		_paper.visible = true
		_backdrop.visible = true
		up = true
		$Land.play()
	_t += delta
	var view := get_viewport().get_visible_rect().size
	var rest := view * 0.5
	var centre := rest.lerp(Vector2(rest.x, -SIZE.y * ZOOM), 1.0 - Memo.slide_at(_t * Memo.IN_TIME / IN_TIME))
	var p := 0.0
	if _leaving >= 0.0:
		_leaving += delta
		p = clampf(_leaving / FLY_TIME, 0.0, 1.0)
		centre = Memo.fly_at(p, rest, _folder_at(view))
	_backdrop.color.a = VEIL * clampf(_t / IN_TIME, 0.0, 1.0) * (1.0 - p)
	var size := lerpf(ZOOM, FLY_SCALE, ease(p, 2.0))
	_paper.scale = Vector2(size, size)
	_paper.rotation = deg_to_rad(lerpf(TILT, 14.0, p))
	_paper.position = centre - SIZE * 0.5
	if p >= 1.0:
		SaveManager.save.reports.append(_id)  # Filed only once signed: quit before, it comes again.
		_id = ""
		_paper.visible = false
		_backdrop.visible = false
		up = false
		$Rustle.play()


## The reports due in `save` and not shown yet: the welcome first, then started events in EVENTS order.
static func due(save: SaveGame) -> Array[String]:
	var out: Array[String] = []
	if not save.reports.has("welcome"):
		out.append("welcome")
	for id: String in Events.EVENTS:
		if not save.reports.has(id) and id not in HELD and Events.due(id, save):
			out.append(id)
	if Events.Demo.active() and save.farm_seconds >= Events.Demo.END_AFTER and not save.reports.has("demo_end"):
		out.append("demo_end")
	return out


## The report with id `id`: the welcome, the demo's end or an event's.
static func report(id: String) -> Dictionary:
	if id == "welcome":
		return WELCOME
	return DEMO_END if id == "demo_end" else Events.EVENTS[id].report


## How report `r`'s text fits its paper in the current language: {re, body} font sizes and `body_y`,
## the top of the body. `fits` is false only if the body overflows even at BODY_MIN.
static func layout(r: Dictionary) -> Dictionary:
	var width := SIZE.x - 60.0
	var re := TranslationServer.translate(r.re) + "!"
	var body := TranslationServer.translate(r.body)
	var re_size := RE_SIZE
	while re_size > BODY_SIZE and _height(Memo.FONT, re, width, re_size) > RE_LINES * Memo.FONT.get_height(re_size) + 0.5:
		re_size -= 1
	var body_y := TEXT_TOP + _height(Memo.FONT, re, width, re_size) + 6.0
	var room := (WISH_BOX if r.get("buttons", false) else SIGN_BOX).position.y - TEXT_GAP - body_y
	var body_size := BODY_SIZE
	while body_size > BODY_MIN and _height(Memo.BODY_FONT, body, width, body_size) > room:
		body_size -= 1
	return {re = re_size, body = body_size, body_y = body_y, fits = _height(Memo.BODY_FONT, body, width, body_size) <= room}


static func _height(font: Font, text: String, width: float, size: int) -> float:
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y


## The ink a stroke through `points` adds: its length in px.
static func ink_of(points: PackedVector2Array) -> float:
	var out := 0.0
	for i in range(1, points.size()):
		out += points[i].distance_to(points[i - 1])
	return out


## A 32 px fountain pen pointing down-left, its nib at (1, 30).
static func pen_image() -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for i in 32:
		for j in 32:
			# Distance from the pen's axis (the diagonal from the nib up-right) and how far along it.
			var along := (i + (31 - j)) / 2.0
			var off := absf(i - (31 - j)) / 1.4
			var width := 0.6 + clampf(along / 6.0, 0.0, 1.0) * 2.4
			if off <= width + 1.0 and along <= 29.0:
				var body := Color(0.16, 0.17, 0.2) if along > 7.0 else Color(0.62, 0.6, 0.52)
				image.set_pixel(i, j, Color(0.93, 0.93, 0.9) if off > width else body)
	return image


## Where a filed report flies: the FILES folder on screen, or the bottom-right corner without one.
func _folder_at(view: Vector2) -> Vector2:
	var folder: Node3D = memo.get_node("Folder") if memo != null else null
	if folder == null or not folder.visible or FarmTv.away:
		return view - Vector2(120, 80)
	return get_viewport().get_camera_3d().unproject_position(folder.global_position)


func _signed() -> bool:
	if report(_id).get("buttons", false):
		return true  # Nothing to sign: DONE shows at once.
	return _strokes.reduce(func(ink: float, stroke: PackedVector2Array) -> float: return ink + ink_of(stroke), 0.0) >= SIGN_INK


func _on_paper_input(event: InputEvent) -> void:
	if _leaving >= 0.0 or _t < IN_TIME:
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var at := mouse.position
	var buttons: bool = report(_id).get("buttons", false)
	var in_box := not buttons and SIGN_BOX.grow(-4.0).has_point(at)
	var on_ok := _signed() and OK_BOX.has_point(at)
	var on_wish := buttons and WISH_BOX.has_point(at)
	_paper.mouse_default_cursor_shape = Control.CURSOR_CROSS if in_box else (Control.CURSOR_POINTING_HAND if on_ok or on_wish else Control.CURSOR_ARROW)
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and on_wish:
			OS.shell_open(STORE_URL)
		if button.pressed and on_ok:
			_leaving = 0.0
			$Stamp.play()
		_pen_down = button.pressed and in_box
		if _pen_down:
			_strokes.append(PackedVector2Array([at]))
		_paper.accept_event()
		_paper.queue_redraw()
	elif event is InputEventMouseMotion and _pen_down:
		if not in_box:
			_pen_down = false
			return
		var stroke := _strokes[-1]
		stroke.append(at)
		_strokes[-1] = stroke
		_paper.queue_redraw()


func _draw_paper() -> void:
	if _id.is_empty():
		return
	var r := report(_id)
	var w := SIZE.x
	var ink := Memo.INK
	_paper.draw_rect(Rect2(Vector2(12, 12), SIZE), Color(0, 0, 0, 0.45))
	_paper.draw_rect(Rect2(Vector2.ZERO, SIZE), Memo.PAPER)
	_paper.draw_string(Memo.FONT, Vector2(30, 50), tr("OFFICE OF THE DIRECTOR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
	_paper.draw_line(Vector2(30, 64), Vector2(w - 30, 64), ink, 3.0)
	_paper.draw_line(Vector2(30, 70), Vector2(w - 30, 70), ink, 1.0)
	# The fit runs shrink loops: once per report and language, not on every redraw (each pen move).
	var key := _id + "|" + TranslationServer.get_locale()
	if key != _fit_key:
		_fit_key = key
		_fit = layout(r)
	var fit := _fit
	_paper.draw_multiline_string(Memo.FONT, Vector2(30, TEXT_TOP + Memo.FONT.get_ascent(fit.re)), tr(r.re) + "!", HORIZONTAL_ALIGNMENT_LEFT, w - 60, fit.re, RE_LINES, ink)
	_paper.draw_multiline_string(Memo.BODY_FONT, Vector2(30, fit.body_y + Memo.BODY_FONT.get_ascent(fit.body)), tr(r.body), HORIZONTAL_ALIGNMENT_LEFT, w - 60, fit.body, -1, Color(ink, 0.9))
	if r.get("buttons", false):
		# WISHLIST and DONE instead of a signature.
		# Steam's own green button (the one deliberate break from the palette: it is Steam's, not ours).
		_paper.draw_rect(WISH_BOX, STEAM_GREEN)
		_paper.draw_rect(Rect2(WISH_BOX.position, Vector2(WISH_BOX.size.x, WISH_BOX.size.y * 0.5)), Color(1, 1, 1, 0.08))
		_paper.draw_string(Memo.FONT, Vector2(WISH_BOX.position.x, WISH_BOX.position.y + 35), tr("WISHLIST ON STEAM"), HORIZONTAL_ALIGNMENT_CENTER, WISH_BOX.size.x, 24, STEAM_TEXT)
		_paper.draw_rect(OK_BOX, Color(ink, 0.9))
		_paper.draw_string(Memo.FONT, Vector2(OK_BOX.position.x, OK_BOX.position.y + 35), tr("DONE"), HORIZONTAL_ALIGNMENT_CENTER, OK_BOX.size.x, 28, Memo.PAPER)
	else:
		_draw_signature(ink)


## The signature field: a line to sign on, the ink, and OK once signed.
func _draw_signature(ink: Color) -> void:
	_paper.draw_rect(SIGN_BOX, Color(ink, 0.06))
	_paper.draw_line(Vector2(SIGN_BOX.position.x + 10, SIGN_BOX.end.y - 14), Vector2(SIGN_BOX.end.x - 10, SIGN_BOX.end.y - 14), Color(ink, 0.5), 1.5)
	_paper.draw_string(Memo.FONT, Vector2(SIGN_BOX.position.x + 10, SIGN_BOX.end.y - 2), tr("SIGNATURE OF EMPLOYEE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.55))
	if _strokes.is_empty():
		_paper.draw_string(Memo.FONT, Vector2(SIGN_BOX.position.x + 14, SIGN_BOX.position.y + 32), tr("Sign here"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ink, 0.35))
	for stroke in _strokes:
		if stroke.size() >= 2:
			_paper.draw_polyline(stroke, INK, 2.5, true)
	if _signed():
		_paper.draw_rect(OK_BOX, Color(ink, 0.9))
		_paper.draw_string(Memo.FONT, Vector2(OK_BOX.position.x, OK_BOX.position.y + 35), "OK", HORIZONTAL_ALIGNMENT_CENTER, OK_BOX.size.x, 28, Memo.PAPER)
