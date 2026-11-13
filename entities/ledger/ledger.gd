class_name Ledger
extends Control
## The stats ledger, there once the "stats_ledger" desk card is stamped: a bound grey-green binder
## (the Binder node, 3D) drops onto the desk's left side. Hovered it lifts a little; clicked, the
## book slides in from the screen's left edge, lands and flips open. A click on the left page turns
## back, on the right page forward; the X beside it, a click anywhere else or Esc shuts and stows it.
## The game keeps running behind it.
##
## The pages (pages()) are built from the save once a frame while it is open: a performance summary,
## coins and Findings earned per minute (two charts stacked on one time axis), cabbages sold per
## minute, personnel, then every requisition approved, by play time. The requisition rows are only
## rescanned when the log changes; the chart lines rescan the whole log every frame their page is
## open, as they end at the live totals and play second. A chart's time axis spans the history the
## log holds (a debug start or an old save holds only the recent part), not the whole shift.
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
## The Findings line: the lab's cold cyan, darkened to read as ink on the paper.
const LAB_INK := Color(0.04, 0.47, 0.58)
## The cabbages line: the cabbage's green, darkened to read as ink.
const LEAF_INK := Color(0.27, 0.5, 0.15)
## The charts: at most CHART_POINTS readings per line (wider intervals on a long run, CHART_STEPS
## minutes each), CHART_ROWS grid rows, about CHART_TICKS minute ticks, the y labels' gutter (px), a
## time axis at least MIN_SPAN s wide (a fresh shift's first readings sit at its left, not stretched).
const CHART_POINTS := 60
const CHART_STEPS := [1, 2, 5, 10, 15, 30, 60, 120, 240, 480]
const CHART_ROWS := 4
const CHART_TICKS := 6
const GUTTER := 70.0
const MIN_SPAN := 300.0
const SMOOTH_FROM := 5
const INKS := {ink = Color(INK, 0.8), lab = LAB_INK, leaf = LEAF_INK}

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
		["COINS EARNED TO DATE", "$" + FarmScreen._thousands(save.coins_earned)],
		["FINDINGS FILED", "¶%d" % save.findings],
		["FINDINGS EARNED TO DATE", "¶" + FarmScreen._thousands(save.findings_earned)],
		["PRICE PER CABBAGE", "$%d" % save.sale_price],
		["MARKETING MULTIPLIER", "x%.2f" % save.marketing],
		["HANDS EMPLOYED", str(save.hands)],
		["TIME ON SHIFT", clock(seconds)],
	]


## Every card and tree node bought, newest first: [play time, what, price, currency]. A card in
## several currencies (UpgradeDesk.costs) logs a line per currency, so it fills a row each.
static func requisitions(save: SaveGame) -> Array:
	var rows := []
	for entry: Dictionary in save.playtest_log:
		var data: Dictionary = UpgradeDesk.card_data(entry.id) if entry.kind == "card" \
				else Projector.node_data(entry.id) if entry.kind == "node" else {}
		if entry.kind in ["card", "node"]:
			rows.push_front(["T+" + clock(entry.t), data.get("title", str(entry.id).to_upper()),
					money(entry.price, entry.currency), entry.currency])
	return rows


## How many requisitions `rows` (requisitions) hold: one card's rows in several currencies (same
## time, same title, next to each other) count once.
static func approved_total(rows: Array) -> int:
	var total := 0
	for i in rows.size():
		total += int(i == 0 or rows[i].slice(0, 2) != rows[i - 1].slice(0, 2))
	return total


## Seconds per chart point over a run `seconds` long: the first of CHART_STEPS (minutes) that keeps
## the whole run within `most` points (CHART_POINTS for the lines, CHART_TICKS for the minute ticks).
static func chart_step(seconds: float, most := CHART_POINTS) -> int:
	for minutes: int in CHART_STEPS:
		if seconds / (minutes * 60.0) <= most:
			return minutes * 60
	return CHART_STEPS.back() * 60


## Rate per minute of the log's running total, the sum of `columns` (totals that only ever rise:
## "_earned", sales), with `total` now at play second `now`: one point (end of the interval in s,
## per minute) for every whole `step` s. Between rows the total is read off a straight line, so a
## purchase or event row is just one more sample of the same rising curve (no dent, no spike) and a
## gap in the log spreads evenly. Rows missing any column (older builds) are skipped; samples are kept
## in time order (a row at or before the last one never sends the line back); too few give no points.
static func rate_points(entries: Array, columns: Array, now: int, total: int, step: int) -> PackedVector2Array:
	var ts: Array[float] = []
	var vs: Array[float] = []
	for entry: Dictionary in entries:
		if _has_all(entry, columns):
			_sample(ts, vs, float(entry.t), columns.reduce(func(sum: float, c: String) -> float: return sum + float(entry[c]), 0.0))
	_sample(ts, vs, now, total)
	var points := PackedVector2Array()
	if ts.size() < 2:
		return points
	var j := 0
	var before := NAN
	for k in range(ceili(ts[0] / step), floori(ts[-1] / step) + 1):
		var at := float(k * step)
		while ts[j + 1] < at:
			j += 1
		var value := lerpf(vs[j], vs[j + 1], (at - ts[j]) / (ts[j + 1] - ts[j]))
		if not is_nan(before):
			points.append(Vector2(at, (value - before) * 60.0 / step))
		before = value
	return points


static func _has_all(entry: Dictionary, columns: Array) -> bool:
	return entry.has("t") and columns.all(func(c: String) -> bool: return entry.has(c))


## Adds a sample at play second `t`, later than the last; one at the same second replaces it.
static func _sample(ts: Array[float], vs: Array[float], t: float, value: float) -> void:
	if not ts.is_empty() and t <= ts[-1]:
		if t == ts[-1]:
			vs[-1] = value
		return
	ts.append(t)
	vs.append(value)


## Play second of the log's first row carrying every one of `columns`, where a chart's history
## starts (`now` when there is none yet).
static func series_start(entries: Array, columns: Array, now: int) -> int:
	for entry: Dictionary in entries:
		if _has_all(entry, columns):
			return mini(int(entry.t), now)
	return now


## Seconds per reading for a history from play second `start` to `now` (chart_step of what is held,
## so a short recent history is read minute by minute however long the shift).
static func history_step(start: int, now: int) -> int:
	return chart_step(maxf(now - start, 60.0))


## The time axis (start, end in play s) for readings `points` `step` s apart: from the first
## reading's interval start to the last reading, at least MIN_SPAN wide, so the line fills the plot.
static func chart_window(points: PackedVector2Array, step: int) -> Vector2:
	if points.is_empty():
		return Vector2(0.0, MIN_SPAN)
	var start := points[0].x - step
	return Vector2(start, maxf(points[-1].x, start + MIN_SPAN))


## The minutes to label along `window` (chart_window): round minutes about CHART_TICKS apart, inside it.
static func time_ticks(window: Vector2) -> Array[int]:
	@warning_ignore("integer_division")
	var every := chart_step(window.y - window.x, CHART_TICKS) / 60
	var ticks: Array[int] = []
	var minute := ceili(window.x / 60.0 / every) * every
	while minute * 60.0 <= window.y + 0.001:
		ticks.append(minute)
		minute += every
	return ticks


## Readings averaged with their neighbours (three in a row, two at the ends), to calm coins banked
## in bursts; the times stay as they are. Fewer than SMOOTH_FROM readings are left as recorded (two
## averaged would only draw their mean as a flat line).
static func smooth(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < SMOOTH_FROM:
		return points
	var out := PackedVector2Array()
	for i in points.size():
		var near := Array(points.slice(maxi(i - 1, 0), mini(i + 2, points.size())))
		out.append(Vector2(points[i].x, near.reduce(func(sum: float, p: Vector2) -> float: return sum + p.y, 0.0) / near.size()))
	return out


## A line is pencilled in once anything came in (the Findings chart waits for the lab).
static func shows_line(points: PackedVector2Array) -> bool:
	return Array(points).any(func(p: Vector2) -> bool: return p.y > 0.0)


static func peak(points: PackedVector2Array) -> float:
	var top := 0.0
	for p in points:
		top = maxf(top, p.y)
	return top


## The y scale's top: CHART_ROWS round steps over the highest reading as recorded (smoothing never
## hides the best minute off the scale).
static func scale_top(points: PackedVector2Array) -> float:
	return nice_step(peak(points) / CHART_ROWS) * CHART_ROWS


## A grid step of 1, 2 or 5 times a power of ten, the smallest at least `value` (1 for nothing).
static func nice_step(value: float) -> float:
	if value <= 0.0:
		return 1.0
	var power := pow(10.0, floorf(log(maxf(value, 0.01)) / log(10.0)))
	for times: float in [1.0, 2.0, 5.0]:
		if times * power >= value * 0.999999:
			return times * power
	return 10.0 * power


## A scale's tick: "$1,200", "¶0.5", "$15K" (steps of a thousand or more count in thousands).
static func tick_text(value: float, step: float, mark: String) -> String:
	if step >= 1000.0:
		return mark + String.num(value / 1000.0, 1).trim_suffix(".0") + "K"
	return mark + (FarmScreen._thousands(roundi(value)) if step >= 1.0 else String.num(value, 2))


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


## A chart page's rows: one chart each, stacked on one time axis (the first chart's history):
## {caption, columns (log totals summed), mark (before each number), total (to date), ink (INKS), empty}.
static func charts(save: SaveGame, kind: String) -> Array:
	if kind == "cabbages":
		return [{caption = "CABBAGES PER MINUTE", columns = ["sold", "minis_sold"], mark = "",
				total = save.sold + save.minis_sold, ink = "leaf", empty = "INSUFFICIENT DATA. CONTINUE WORKING."}]
	return [
		{caption = "$ PER MINUTE", columns = ["coins_earned"], mark = "$", total = save.coins_earned,
				ink = "ink", empty = "INSUFFICIENT DATA. CONTINUE WORKING."},
		{caption = "¶ PER MINUTE", columns = ["findings_earned"], mark = "¶", total = save.findings_earned,
				ink = "lab", empty = "NO FINDINGS ON FILE."},
	]


## Every page, an even count: {title, form, kind ("rows", "chart", "list" or "blank"), rows}.
static func pages(save: SaveGame, seconds: int) -> Array:
	return pages_from(save, seconds, requisitions(save))


## pages() with the requisition rows already worked out.
static func pages_from(save: SaveGame, seconds: int, reqs: Array) -> Array:
	var list := [
		{title = "QUARTERLY PERFORMANCE SUMMARY", form = "FORM QP-1", kind = "rows", rows = summary_rows(save, seconds)},
		{title = "EARNINGS PER MINUTE WORKED", form = "FORM QP-2", kind = "chart", rows = charts(save, "earnings")},
		{title = "CABBAGES SOLD PER MINUTE", form = "FORM QP-3", kind = "chart", rows = charts(save, "cabbages")},
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
			draw_string(_type, Vector2(x, row_y.call(REQ_PER_PAGE) + line_h), tr("%d REQUISITIONS APPROVED IN TOTAL.") % approved_total(_reqs),
					HORIZONTAL_ALIGNMENT_LEFT, w, int(text * 0.8), Color(INK, 0.7))
		"chart":
			_draw_charts(page.rows, x, w, rect.position.y, line_h, save, seconds)
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




## A chart page: its charts (`specs`, charts()) stacked in the page's ruled area on one time axis,
## the history the first chart's columns hold, labelled once under the last chart.
func _draw_charts(specs: Array, x: float, w: float, top_y: float, line_h: float, save: SaveGame, seconds: int) -> void:
	var pencil: Color = INKS.ink
	var small := int(line_h * 0.34)
	var first: Dictionary = specs[0]
	var step := history_step(series_start(save.playtest_log, first.columns, seconds), seconds)
	var lines := specs.map(func(spec: Dictionary) -> PackedVector2Array:
		return rate_points(save.playtest_log, spec.columns, seconds, spec.total, step))
	var window := chart_window(lines[0], step)
	var ticks := time_ticks(window)
	# Ruled lines 4.4 to 15.8 hold the plots, a caption's gap between two.
	var gap := 1.4
	var plot_h := (11.4 - gap * (specs.size() - 1)) / specs.size()
	var area := Rect2()
	for i in specs.size():
		area = Rect2(Vector2(x + GUTTER, top_y + line_h * (4.4 + i * (plot_h + gap))), Vector2(w - GUTTER, line_h * plot_h))
		_draw_chart(area, specs[i], lines[i], window, ticks, line_h)
	for minute in ticks:
		var px := _time_x(area, window, minute * 60.0)
		draw_line(Vector2(px, area.end.y), Vector2(px, area.end.y + 6.0), pencil, 1.5)
		draw_string(_type, Vector2(px - 40.0, area.end.y + line_h * 0.7), FarmScreen._thousands(minute),
				HORIZONTAL_ALIGNMENT_CENTER, 80.0, small, pencil)
	draw_string(_type, Vector2(area.position.x, area.end.y + line_h * 1.4), tr("MINUTES ON SHIFT"),
			HORIZONTAL_ALIGNMENT_CENTER, area.size.x, small, pencil)
	var legend := "DOTS: %d-MINUTE READINGS. LINE: AVERAGE OF 3." if lines[0].size() >= SMOOTH_FROM else "%d-MINUTE READINGS."
	@warning_ignore("integer_division")
	draw_string(_type, Vector2(x, area.end.y + line_h * 2.5), tr(legend) % (step / 60),
			HORIZONTAL_ALIGNMENT_LEFT, w, int(small * 0.9), Color(INK, 0.55))


## One chart in `area`: its caption and total to date above, round y ticks in the gutter, the
## minute grid of `ticks`, each reading as a faint dot and their running average as the line.
func _draw_chart(area: Rect2, spec: Dictionary, points: PackedVector2Array, window: Vector2, ticks: Array[int], line_h: float) -> void:
	var pencil: Color = INKS.ink
	var ink: Color = INKS[spec.ink]
	var small := int(line_h * 0.34)
	var caption_y := area.position.y - line_h * 0.45
	draw_string(_type, Vector2(area.position.x - GUTTER, caption_y), tr(spec.caption), HORIZONTAL_ALIGNMENT_LEFT,
			area.size.x, small, ink)
	draw_string(_type, Vector2(area.position.x, caption_y), tr("TO DATE %s") % (spec.mark + FarmScreen._thousands(spec.total)),
			HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, small, ink)
	var enough := shows_line(points)
	var top := scale_top(points)
	draw_rect(area, PAPER.lightened(0.08))
	var lift := small * 0.35
	for i in CHART_ROWS + 1:
		var y := area.end.y - area.size.y * i / CHART_ROWS
		if i > 0:
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(INK, 0.14), 1.0)
		if enough:
			draw_string(_type, Vector2(area.position.x - GUTTER, y + lift), tick_text(top * i / CHART_ROWS, top / CHART_ROWS, spec.mark),
					HORIZONTAL_ALIGNMENT_RIGHT, GUTTER - 8.0, small, ink)
	for minute in ticks:
		var px := _time_x(area, window, minute * 60.0)
		draw_line(Vector2(px, area.position.y), Vector2(px, area.end.y), Color(INK, 0.08), 1.0)
	draw_line(area.position, Vector2(area.position.x, area.end.y), pencil, 2.5)
	draw_line(Vector2(area.position.x, area.end.y), area.end, pencil, 2.5)
	if not enough:
		draw_string(_type, Vector2(area.position.x, area.get_center().y + lift), tr(spec.empty),
				HORIZONTAL_ALIGNMENT_CENTER, area.size.x, small, Color(INK, 0.6))
		return
	var at := func(p: Vector2) -> Vector2:
		return Vector2(_time_x(area, window, p.x), area.end.y - p.y / top * area.size.y)
	for p in points:
		var faint := points.size() >= SMOOTH_FROM
		draw_circle(at.call(p), 2.5 if faint else 3.5, Color(ink, 0.45) if faint else ink)
	if points.size() > 1:
		draw_polyline(PackedVector2Array(Array(smooth(points)).map(at)), ink, 2.5, true)


func _time_x(area: Rect2, window: Vector2, t: float) -> float:
	return area.position.x + (t - window.x) / (window.y - window.x) * area.size.x
