class_name Ledger
extends Control
## The stats ledger, there once the "stats_ledger" desk card is stamped: a bound grey-green binder
## (the Binder node, 3D) drops onto the desk's left side. Hovered it lifts a little; clicked, the
## book slides in from the screen's left edge, lands and flips open. A click on the left page turns
## back, on the right page forward; the X beside it, a click anywhere else or Esc shuts and stows it.
## The game keeps running behind it.
##
## The pages (pages()) are built from the save once a frame while it is open: a performance summary,
## a chart of the coins over time from the playtest log, personnel, then every requisition approved,
## by play time. The log-derived rows are only rescanned when the log changes.
## The open book is drawn in 2D like the projector (the camera looks steeply down, a 3D book would
## read as a strip); while it is out it takes every click.

## Requisition lines per page.
const REQ_PER_PAGE := 12
## The binder's drop onto the desk (m, s), and how far it lifts hovered (m, s).
const DROP_HEIGHT := 1.2
const DROP_TIME := 0.45
const HOVER_LIFT := 0.045
## Hovered, the binder also tips its front edge up toward the camera (rad).
const HOVER_TILT := 0.09
const HOVER_TIME := 0.15
## The close button beside the open book's top-right corner (px square).
const CLOSE := 40.0
## Page height as a share of the view, page width per height, the spread's top and left margin.
const PAGE_H := 0.84
const PAGE_ASPECT := 0.68
const TOP := 0.08
const LEFT := 40.0
const FONT := preload("res://assets/fonts/Oswald.ttf")
const PAPER := Color(0.78, 0.78, 0.72)
const RULE := Color(0.42, 0.5, 0.55, 0.35)
const MARGIN := Color(0.55, 0.25, 0.22, 0.35)
const INK := Color(0.13, 0.14, 0.14)
const BOARD := Color(0.2, 0.23, 0.21)

@export var latch_sound: AudioStream
@export var thud_sound: AudioStream
@export var page_sound: AudioStream

## How far the book is out, 0 (stowed) to 1 (out), and how far its cover is flipped open.
var _out := 0.0
var _open := 0.0
var _spread := 0
var _settling: Tween
var _lifting: Tween
var _hover_side := 0
## Typewriter face for the entries; falls back to the default font where none of these exist.
var _type := SystemFont.new()
## Cached from the playtest log (_refresh_log), and this frame's pages (_pages).
var _log_size := -1
var _log_save: SaveGame
var _reqs := []
var _points := PackedVector2Array()
var _cached_pages := []
var _pages_frame := -1

@onready var _binder: Node3D = $"../Binder"
@onready var _binder_rest := _binder.position


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_type.font_names = PackedStringArray(["Courier New", "Courier Prime", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
	_type.font_weight = 600
	var hit: Interactable = $"../Binder/Hit/Interactable"
	hit.grabbed.connect(func() -> void:
		_play(latch_sound)
		_settle(true))
	hit.hovered.connect(_lift.bind(HOVER_LIFT))
	hit.unhovered.connect(_lift.bind(0.0))
	_binder.visible = unlocked(SaveManager.save)
	hit.enabled = _binder.visible


func _process(_delta: float) -> void:
	if not _binder.visible and unlocked(SaveManager.save):
		_drop()
	if _out > 0.0 or _settling != null and _settling.is_running():
		queue_redraw()


## The binder drops onto the desk from above and settles with a thud.
func _drop() -> void:
	_binder.visible = true
	_binder.position = _binder_rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_binder, "position", _binder_rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_play(thud_sound)
		$"../Binder/Hit/Interactable".enabled = true)


## Lifts the binder `height` above where it lies (hover), eased.
func _lift(height: float) -> void:
	if _lifting != null:
		_lifting.kill()
	_lifting = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lifting.tween_property(_binder, "position", _binder_rest + Vector3.UP * height, HOVER_TIME)
	_lifting.parallel().tween_property($"../Binder/Model", "rotation:x", -HOVER_TILT * height / HOVER_LIFT, HOVER_TIME)


static func unlocked(save: SaveGame) -> bool:
	return save.stamped.has("stats_ledger")


## "1:02:03" for 3723 seconds.
static func clock(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]


static func money(amount: int, currency: String) -> String:
	return UpgradeCard.price_text(amount, currency)


## The performance summary: [label, value] rows.
static func summary_rows(save: SaveGame, seconds: int) -> Array:
	return [
		["CABBAGES MOVED", str(save.sold)],
		["CABBAGES INTERCEPTED MID-AIR", str(save.catches)],
		["INTERCEPTION RATE", "%d%%" % roundi(100.0 * save.catches / maxi(save.sold, 1))],
		["CABBAGES IN INVENTORY", "%d / %d" % [save.stock, save.storage_cap]],
		["COINS ON HAND", "$%d" % save.coins],
		["FINDINGS FILED", "¶%d" % save.findings],
		["PRICE PER CABBAGE", "$%d" % save.sale_price],
		["MARKETING MULTIPLIER", "x%.2f" % save.marketing],
		["HANDS EMPLOYED", str(save.hands)],
		["TIME ON SHIFT", clock(seconds)],
	]


## Every card and tree node bought, newest first: [play time, what, price, currency].
static func requisitions(save: SaveGame) -> Array:
	var rows := []
	for entry: Dictionary in save.playtest_log:
		var data: Dictionary = UpgradeDesk.card_data(entry.id) if entry.kind == "card" \
				else Projector.node_data(entry.id) if entry.kind == "node" else {}
		if entry.kind in ["card", "node"]:
			rows.push_front(["T+" + clock(entry.t), data.get("title", str(entry.id).to_upper()),
					money(entry.price, entry.currency), entry.currency])
	return rows


## Coins over play time from the log, plus now: (seconds, coins).
static func coin_points(save: SaveGame, seconds: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for entry: Dictionary in save.playtest_log:
		points.append(Vector2(entry.t, entry.coins))
	points.append(Vector2(seconds, save.coins))
	return points


static func personnel_rows(save: SaveGame) -> Array:
	var rows := [["HEADCOUNT", str(save.hands + 1)], ["YOU", "UNDER REVIEW"]]
	for i in mini(save.hands, 7):
		rows.append([TranslationServer.translate("ASSOCIATE No. %03d") % (i + 1), "ACTIVE"])
	if save.hands > 7:
		rows.append(["FURTHER ASSOCIATES", str(save.hands - 7)])
	if save.hands > 0:
		rows.append(["TRIP INTERVAL", "%.1f s" % save.associate_interval])
		rows.append(["WALKING SPEED", "x%.2f" % save.associate_speed])
	return rows


## Every page, an even count: {title, form, kind ("rows", "chart", "list" or "blank"), rows}.
static func pages(save: SaveGame, seconds: int) -> Array:
	return pages_from(save, seconds, requisitions(save))


## pages() with the requisition rows already worked out.
static func pages_from(save: SaveGame, seconds: int, reqs: Array) -> Array:
	var list := [
		{title = "QUARTERLY PERFORMANCE SUMMARY", form = "FORM QP-1", kind = "rows", rows = summary_rows(save, seconds)},
		{title = "LIQUIDITY OVER TIME", form = "FORM QP-2", kind = "chart", rows = []},
		{title = "PERSONNEL", form = "FORM HR-4", kind = "rows", rows = personnel_rows(save)},
	]
	for start in range(0, maxi(reqs.size(), 1), REQ_PER_PAGE):
		list.append({title = "REQUISITIONS APPROVED", form = "FORM RQ-9", kind = "list",
				rows = reqs.slice(start, start + REQ_PER_PAGE)})
	if list.size() % 2 == 1:
		list.append({title = "", form = "", kind = "blank", rows = []})
	return list


func _now() -> int:
	return SaveManager.played_now()


## Rescans the playtest log only when it changed (a new game empties it, so any size change).
func _refresh_log(save: SaveGame) -> void:
	if save.playtest_log.size() == _log_size and save == _log_save:
		return
	_log_size = save.playtest_log.size()
	_log_save = save
	_reqs = requisitions(save)
	_points = coin_points(save, 0)
	_points.resize(_points.size() - 1)


## This frame's pages, built once however often they are asked for.
func _pages() -> Array:
	if _pages_frame != Engine.get_process_frames():
		_pages_frame = Engine.get_process_frames()
		_refresh_log(SaveManager.save)
		_cached_pages = pages_from(SaveManager.save, _now(), _reqs)
	return _cached_pages


# --- Input ---

## While the book is out it takes the whole screen: pages turn it, anywhere else stows it.
func _has_point(_point: Vector2) -> bool:
	return _out > 0.0


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			var side := _side_at(button.position)
			if _close_rect().has_point(button.position) or not _book_rect().has_point(button.position):
				_settle(false)
			elif _open >= 1.0 and side != 0:
				@warning_ignore("integer_division")
				var last := (_pages().size() - 1) / 2
				var next := clampi(_spread + side, 0, last)
				if next != _spread:
					_spread = next
					_play(page_sound)
		accept_event()
	elif event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		_hover_side = _side_at(at) if _open >= 1.0 else 0
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if _hover_side != 0 or _close_rect().has_point(at) else CURSOR_ARROW


## Esc closes it, in _input so it gets Esc before the in-game menu (later in the tree, unhandled) opens.
func _input(event: InputEvent) -> void:
	if _out > 0.0 and event.is_action_pressed("ui_cancel"):
		_settle(false)
		get_viewport().set_input_as_handled()


## -1 over the left page, 1 over the right page, 0 elsewhere.
func _side_at(point: Vector2) -> int:
	var book := _book_rect()
	if not book.has_point(point):
		return 0
	return -1 if point.x < book.get_center().x else 1


func _settle(out: bool) -> void:
	if _settling != null:
		_settling.kill()
	_settling = create_tween()
	if out:
		_settling.tween_property(self, "_out", 1.0, 0.3 * (1.0 - _out) + 0.05).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_settling.tween_callback(_play.bind(thud_sound))
		_settling.tween_callback(_play.bind(page_sound))
		_settling.tween_property(self, "_open", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_settling.tween_property(self, "_open", 0.0, 0.15 * _open)
		_settling.tween_property(self, "_out", 0.0, 0.25 * _out + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_settling.tween_callback(_play.bind(thud_sound))


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


# --- Layout ---

func _page_size() -> Vector2:
	var h := size.y * PAGE_H
	return Vector2(h * PAGE_ASPECT, h)


## How far the book's front edge travels from the screen edge (px).
func _travel() -> float:
	return LEFT + _page_size().x * 2.0


## The open spread: two pages, sliding in from the left screen edge as it comes out.
func _book_rect() -> Rect2:
	var page := _page_size()
	return Rect2(Vector2(_out * _travel() - page.x * 2.0, size.y * TOP), Vector2(page.x * 2.0, page.y))


func _close_rect() -> Rect2:
	var book := _book_rect()
	return Rect2(Vector2(book.end.x + 24.0, book.position.y), Vector2(CLOSE, CLOSE))


# --- Drawing ---

func _draw() -> void:
	var book := _book_rect()
	var page := _page_size()
	var spine := book.position.x + page.x
	var right := Rect2(Vector2(spine, book.position.y), page)
	# The cover swings over the spine: over the right page (closed) to over the left (open).
	var swing := cos(PI * _open) * page.x
	if _out > 0.0:
		var under := right if _open <= 0.0 else book
		draw_rect(Rect2(under.position + Vector2(10, 12), under.size), Color(0, 0, 0, 0.4))
		draw_rect(under.grow(8.0), BOARD)
		if _open > 0.0:
			_draw_page(right, 2 * _spread + 1, 1)
		if swing < 0.0:
			# The left page unfolds with the cover.
			var left := Rect2(Vector2(spine + swing, book.position.y), Vector2(-swing, page.y))
			if _open >= 1.0:
				_draw_page(left, 2 * _spread, -1)
			else:
				draw_rect(left, PAPER.darkened(0.15))
		else:
			_draw_cover(Rect2(Vector2(spine, book.position.y), Vector2(swing, page.y)).grow(8.0))
		draw_line(Vector2(spine, book.position.y), Vector2(spine, book.end.y), Color(0, 0, 0, 0.5), 4.0)
		# The close button: a dark stamped square with an X, as on the projector.
		var close := _close_rect()
		draw_rect(close, Color(INK, 0.9))
		var x := close.grow(-12.0)
		draw_line(x.position, x.end, PAPER, 3.0, true)
		draw_line(Vector2(x.end.x, x.position.y), Vector2(x.position.x, x.end.y), PAPER, 3.0, true)


func _draw_cover(cover: Rect2) -> void:
	draw_rect(cover, BOARD.lightened(0.05))
	if cover.size.x < 200.0:
		return
	# Spine cloth, then the pasted label.
	draw_rect(Rect2(cover.position, Vector2(cover.size.x * 0.1, cover.size.y)), BOARD.darkened(0.3))
	var label := Rect2(cover.position + cover.size * Vector2(0.22, 0.2), cover.size * Vector2(0.66, 0.24))
	draw_rect(label, PAPER)
	draw_rect(label.grow(-6.0), INK, false, 2.0)
	draw_string(FONT, Vector2(label.position.x, label.position.y + label.size.y * 0.45), tr("LEDGER"),
			HORIZONTAL_ALIGNMENT_CENTER, label.size.x, int(label.size.y * 0.32), INK)
	draw_string(FONT, Vector2(label.position.x, label.position.y + label.size.y * 0.72), tr("PERFORMANCE RECORDS"),
			HORIZONTAL_ALIGNMENT_CENTER, label.size.x, int(label.size.y * 0.12), INK)
	draw_string(FONT, Vector2(label.position.x, label.position.y + label.size.y * 0.88), tr("FORM L-1   |   NOT FOR CIRCULATION"),
			HORIZONTAL_ALIGNMENT_CENTER, label.size.x, int(label.size.y * 0.08), Color(INK, 0.7))


func _draw_page(rect: Rect2, index: int, side: int) -> void:
	var save: SaveGame = SaveManager.save
	var seconds := _now()
	var all := _pages()
	draw_rect(rect, PAPER if _hover_side != side else PAPER.lightened(0.05))
	# Ruled lines, the red margin, a darker gutter toward the spine.
	var line_h := rect.size.y / 20.0
	for i in range(3, 20):
		var y := rect.position.y + i * line_h
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), RULE, 1.5)
	var margin_x := rect.position.x + rect.size.x * 0.12
	draw_line(Vector2(margin_x, rect.position.y), Vector2(margin_x, rect.end.y), MARGIN, 2.0)
	var gutter := rect.end.x - 18.0 if side < 0 else rect.position.x
	draw_rect(Rect2(Vector2(gutter, rect.position.y), Vector2(18.0, rect.size.y)), Color(0, 0, 0, 0.12))
	if index >= all.size():
		return
	var page: Dictionary = all[index]
	var x := margin_x + 14.0
	var w := rect.end.x - x - rect.size.x * 0.07
	var text := int(line_h * 0.5)
	draw_string(FONT, Vector2(x, rect.position.y + line_h * 1.5), tr(page.title), HORIZONTAL_ALIGNMENT_LEFT, w, int(line_h * 0.72), INK)
	draw_string(_type, Vector2(x, rect.position.y + line_h * 2.6), tr(page.form), HORIZONTAL_ALIGNMENT_LEFT, w, int(line_h * 0.4), Color(INK, 0.7))
	draw_string(_type, Vector2(x, rect.position.y + line_h * 2.6), tr("PAGE %d OF %d") % [index + 1, all.size()],
			HORIZONTAL_ALIGNMENT_RIGHT, w, int(line_h * 0.4), Color(INK, 0.7))
	var row_y := func(i: int) -> float: return rect.position.y + (i + 4) * line_h - line_h * 0.25
	match page.kind:
		"rows":
			for i in page.rows.size():
				draw_string(_type, Vector2(x, row_y.call(i)), tr(page.rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, w, text, INK)
				draw_string(_type, Vector2(x, row_y.call(i)), tr(page.rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, w, text, INK)
		"list":
			if page.rows.is_empty():
				draw_string(_type, Vector2(x, row_y.call(0)), tr("NO REQUISITIONS ON FILE."), HORIZONTAL_ALIGNMENT_LEFT, w, text, INK)
			for i in page.rows.size():
				var row: Array = page.rows[i]
				draw_string(_type, Vector2(x, row_y.call(i)), row[0], HORIZONTAL_ALIGNMENT_LEFT, w, int(text * 0.8), Color(INK, 0.75))
				draw_string(_type, Vector2(x + w * 0.27, row_y.call(i)), tr(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.58, int(text * 0.8), INK)
				UpgradeCard.draw_price(self, _type, Vector2(x + w, row_y.call(i)), row[2], row[3], int(text * 0.8), INK)
			draw_string(_type, Vector2(x, row_y.call(REQ_PER_PAGE) + line_h), tr("%d REQUISITIONS APPROVED IN TOTAL.") % _reqs.size(),
					HORIZONTAL_ALIGNMENT_LEFT, w, int(text * 0.8), Color(INK, 0.7))
		"chart":
			_draw_chart(Rect2(Vector2(x + 40.0, rect.position.y + line_h * 4.0), Vector2(w - 50.0, line_h * 11.0)),
					_points + PackedVector2Array([Vector2(seconds, save.coins)]), line_h)
		"blank":
			draw_string(_type, Vector2(rect.position.x, rect.get_center().y), tr("THIS PAGE INTENTIONALLY LEFT BLANK."),
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(text * 0.8), Color(INK, 0.6))
	# The dog-eared corner to turn by, where there is a page to turn to.
	if index + side < 0 or index + side >= all.size():
		return
	var corner := Vector2(rect.end.x if side > 0 else rect.position.x, rect.end.y)
	var ear := line_h * (1.4 if _hover_side == side else 1.0)
	draw_colored_polygon(PackedVector2Array([corner, corner - Vector2(side * ear, 0.0), corner - Vector2(0.0, ear)]), PAPER.darkened(0.25))
	draw_string(FONT, Vector2(corner.x - (w * 0.3 if side > 0 else -ear), corner.y - line_h * 0.35),
			tr("NEXT >") if side > 0 else tr("< PREVIOUS"), HORIZONTAL_ALIGNMENT_RIGHT if side > 0 else HORIZONTAL_ALIGNMENT_LEFT,
			w * 0.3 - ear, int(line_h * 0.42), Color(INK, 0.55 if _hover_side == side else 0.35))


## Coins over play time, pencilled in with a slightly unsteady hand.
func _draw_chart(area: Rect2, points: PackedVector2Array, line_h: float) -> void:
	var pencil := Color(INK, 0.8)
	var small := int(line_h * 0.38)
	draw_line(area.position, Vector2(area.position.x, area.end.y), pencil, 2.5)
	draw_line(Vector2(area.position.x, area.end.y), area.end, pencil, 2.5)
	var top := 1.0
	for p in points:
		top = maxf(top, p.y)
	var span := maxf(points[points.size() - 1].x, 1.0)
	draw_string(_type, Vector2(area.position.x - 40.0, area.position.y - 8.0), "$%d" % top, HORIZONTAL_ALIGNMENT_LEFT, -1, small, pencil)
	draw_string(_type, Vector2(area.position.x - 40.0, area.end.y + line_h * 0.6), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, small, pencil)
	draw_string(_type, Vector2(area.position.x, area.end.y + line_h * 0.6), clock(int(span)), HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, small, pencil)
	draw_string(_type, Vector2(area.position.x, area.end.y + line_h * 1.3), tr("TIME ON SHIFT"), HORIZONTAL_ALIGNMENT_CENTER, area.size.x, small, pencil)
	if points.size() < 3:
		draw_string(_type, Vector2(area.position.x, area.get_center().y), tr("INSUFFICIENT DATA. CONTINUE WORKING."),
				HORIZONTAL_ALIGNMENT_CENTER, area.size.x, small, pencil)
		return
	var line := PackedVector2Array()
	for i in points.size():
		var p := points[i]
		var wobble := Vector2(sin(i * 12.9898) , cos(i * 78.233)) * 1.5
		line.append(area.position + Vector2(p.x / span * area.size.x, (1.0 - p.y / top) * area.size.y) + wobble)
	draw_polyline(line, pencil, 2.5, true)
