class_name UpgradeTree
extends Control
## An upgrade tree view, shared by the projector's sheet (entities/projector/) and the farm TV's CH2
## (entities/farm_tree/). Its host sets the rect, `rules` and `light`; the palette and font are set
## in the host's scene. `rules` is the script that holds the tree: its NODES and THEMES and these
## static rules on a save: node_data, is_shown, is_reachable, is_open, is_dept, locked_by, is_bought,
## price_of, can_hold, can_buy, buy, requirement, fresh (reachable, never seen: marked NEW),
## themes_shown and drawn_key (whatever else changes the drawing).
## Round the hub sit the departments (`dept`, if any): info only, never bought, so drawn as rounded
## label plates in the hub's green rather than circles. Each node: a circle with a glyph and its name
## above; hovered, a block with name, description and cost (coins, or Findings for `currency`
## "findings"); held for HOLD_TIME, it is bought (`bought`; can't pay: `denied`). Like a phone map, a
## held press dragged across the tree pans it (kept in view) and the wheel zooms it; a double-click
## recentres. Nodes and edges are drawn once on Layer, around its own origin, and only redrawn when
## they change; panning just moves it. Hover, hold and the popup go on Top, redrawn each frame.
## Layer is a Node2D, not a Control: a Control is culled by its own (here empty) rect, so the whole
## tree vanished once the hub was panned out of view.

signal bought(id: String, paid: int)
signal denied

const FONT := preload("res://assets/fonts/Oswald.ttf")
const HOLD_TIME := 0.6
## Zoomed right out, the whole tree with its theme headings fits.
const ZOOM_MIN := 0.27
const ZOOM_MAX := 2.5
## One wheel notch zooms by this factor, about the cursor.
const ZOOM_STEP := 1.15
const WIDEN := 1.6
## A press that moves less than this (px) is a click (a hold), not a pan.
const CLICK_PX := 8.0
## Seconds per beat of a NEW node's pulsing ring.
const NEW_PULSE := 1.4
## A node's popup: its width, the body's font size and line step (px), and the room for a line.
const POPUP_WIDTH := 430.0
const POPUP_BODY := 21
## The popup body's alpha (of the lamp): the description (the rules) at full beam, the flavour
## line dimmer, an aside (like PaperNote.FLAVOUR_INK on the desk cards).
const FLAVOUR_ALPHA := 0.6
const BODY_ALPHA := 1.0
const POPUP_STEP := 27.0
const POPUP_TEXT := POPUP_WIDTH - 32.0
## A point off every view: hovering it hovers nothing.
const OFF := Vector2(-1e9, -1e9)

@export var font: Font = FONT
## The face of a popup's ¶ cost figure, when it differs from `font` (CH2's terminal font: the
## Findings counter's Oswald Bold, so ¶ reads as the same currency everywhere); null: `font`.
@export var price_font: Font
## Lines, rims and text; the contrast colour (a bought node's glyph, the popup's text); the ground
## the tree is drawn on; the hub's green; a refused hold; what a node waits for.
@export var ink := Color(0.13, 0.15, 0.14)
@export var beam := Color(0.78, 0.84, 0.84)
@export var ground := Color(0.36, 0.39, 0.36)
@export var accent := Color(0.42, 0.72, 0.24)
@export var refused := Color(0.55, 0.12, 0.1)
@export var warn := Color(0.85, 0.35, 0.3)
@export var glow := Color(0.846, 0.888, 0.888, 0.25)
## The projector lamp's slow shimmer on the nodes (pulse).
@export var shimmer := false

## The tree's script (see above), set by the host.
var rules: Variant
## How lit the tree is, 0..1: it fades with it, and only takes hovers and holds above 0.9.
var light := 1.0

var _hovered := ""
## The THEMES heading under the mouse (index), or -1: its popup shows the category.
var _hovered_theme := -1
var _holding := ""
var _hold := 0.0
var _denied := 0.0
## The tree's pan (px) and zoom; a press pans once it moves past CLICK_PX.
var _pan := Vector2.ZERO
var _zoom := 1.0
var _panning := false
var _panned := false
var _pan_press := Vector2.ZERO
var _pan_start := Vector2.ZERO
var _layer_key := []
## Nodes showing for the first time since the tree lit up (marked NEW until close).
var _fresh: Array[String] = []
## THEMES that have a node showing (headings drawn), by index, and the ids showing (is_shown),
## both worked out when the layer is.
var _themes_shown: Array[bool] = []
var _shown := {}
static var _plate_style: StyleBoxFlat

@onready var _layer: Node2D = $Layer
@onready var _top: Control = $Top


func _ready() -> void:
	_layer.draw.connect(_draw_layer)
	_top.draw.connect(_draw_top)


func _process(delta: float) -> void:
	var save: SaveGame = SaveManager.save
	_denied = maxf(_denied - delta, 0.0)
	if _holding != "" and light > 0.9:
		if rules.can_buy(_holding, save):
			_hold += delta / HOLD_TIME
			if _hold >= 1.0:
				var id := _holding
				var paid: int = rules.price_of(id, save)
				rules.buy(id, save)
				_holding = ""
				_hold = 0.0
				bought.emit(id, paid)
		elif _denied == 0.0:
			_denied = 0.5
			denied.emit()
	if not is_visible_in_tree():
		return
	_layer.position = _wheel()[0]
	_layer.modulate.a = light * (pulse(Time.get_ticks_msec() / 1000.0) if shimmer else 1.0)
	_top.size = size
	var key: Array = [_zoom, size, save.get_instance_id()] + rules.drawn_key(save)
	if key != _layer_key:
		_layer_key = key
		_themes_shown = rules.themes_shown(save)
		_shown.clear()
		for node: Dictionary in rules.NODES:
			if rules.is_shown(node.id, save):
				_shown[node.id] = true
		if light > 0.0:
			for id: String in rules.fresh(save):
				if not _fresh.has(id):
					_fresh.append(id)
		_layer.queue_redraw()
	_top.queue_redraw()


## The view goes dark: hover and hold drop, and the ids marked NEW are handed back (seen now).
func close() -> PackedStringArray:
	var seen := PackedStringArray(_fresh)
	_fresh.clear()
	_layer_key = []
	_hovered = ""
	_hovered_theme = -1
	_holding = ""
	return seen


## The lamp's slow, gentle shimmer (about 0.95..1): two slow waves, never a per-frame flicker.
static func pulse(time: float) -> float:
	return 1.0 - 0.03 * (0.5 + 0.5 * sin(time * 1.3)) - 0.02 * (0.5 + 0.5 * sin(time * 3.1 + 1.0))


## The save number node `node` is paid in: "coins" unless it says "findings".
static func currency_of(node: Dictionary) -> String:
	return node.get("currency", "coins")


## What node `node` does to the save: multiplies each save number in `mul`, raises each in `add`.
static func apply_effect(node: Dictionary, save: SaveGame) -> void:
	for stat: String in node.get("mul", {}):
		var value: Variant = save.get(stat) * node.mul[stat]
		save.set(stat, roundi(value) if save.get(stat) is int else value)
	for stat: String in node.get("add", {}):
		save.set(stat, save.get(stat) + node.add[stat])


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var save: SaveGame = SaveManager.save
	var lit := light > 0.9
	if button != null and button.pressed and lit and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(button.position, ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		_hover(button.position)
		accept_event()
	elif button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and lit:
			# A press on a node starts buying it; moved past CLICK_PX it pans instead.
			_panning = true
			_panned = false
			_pan_press = button.position
			_pan_start = _pan
			_hover(button.position)
			# Only a node that can be held reacts (bought or out of reach: no denied blink and sound).
			_holding = _hovered if rules.can_hold(_hovered, save) else ""
			_hold = 0.0
			if button.double_click and _hovered == "":
				_recentre()
		elif not button.pressed:
			_panning = false
			_panned = false
			_holding = ""
			_hold = 0.0
			_hover(button.position if lit else OFF)
		accept_event()
	elif event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		if _panning and (_panned or at.distance_to(_pan_press) > CLICK_PX):
			_panned = true
			_pan = _clamp_pan(_pan_start + at - _pan_press)
		_hover(at if lit and not _panned else OFF)
		if _holding != "" and _hovered != _holding:
			_holding = ""
			_hold = 0.0
		mouse_default_cursor_shape = CURSOR_DRAG if _panned else CURSOR_POINTING_HAND if rules.can_hold(_hovered, save) \
				else CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover(OFF)
		_holding = ""


# --- Layout ---

## The wheel's centre, its scale (px per unit, x and y) and the node radius, panned and zoomed.
## On a wide view it spreads sideways, at most to WIDEN times its height scale.
func _wheel() -> Array:
	var uy := size.y / 2.0 / 1.25
	var unit := Vector2(minf(size.x / 2.0 / 1.05, uy * WIDEN), uy)
	return [size / 2.0 + Vector2(0.0, uy * 0.06) + _pan, unit * _zoom, _radius(unit) * _zoom]


func _radius(unit: Vector2) -> float:
	return clampf(unit.y * 0.1, 20.0, 42.0)


## Zooms by `factor` keeping the tree point under `point` where it is.
func _zoom_at(point: Vector2, factor: float) -> void:
	var wheel := _wheel()
	var under: Vector2 = (point - wheel[0]) / wheel[1]
	var base_unit: Vector2 = wheel[1] / _zoom
	var middle: Vector2 = wheel[0] - _pan
	var old := _zoom
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var pan := point - under * base_unit * _zoom - middle
	# Zooming into empty space that would push the whole tree out is refused.
	if _keeps_tree(pan):
		_pan = pan
	else:
		_zoom = old


## `pan` if a node (or the hub) stays well inside the view with it, else the closest move along one
## axis that does, else the current pan: the tree can't be lost off the view.
func _clamp_pan(pan: Vector2) -> Vector2:
	for option: Vector2 in [pan, Vector2(pan.x, _pan.y), Vector2(_pan.x, pan.y)]:
		if _keeps_tree(option):
			return option
	return _pan


func _keeps_tree(pan: Vector2) -> bool:
	var wheel := _wheel()
	var centre: Vector2 = wheel[0] - _pan + pan
	var inside := Rect2(Vector2.ZERO, size).grow(-wheel[2] * 1.5)
	if inside.has_point(centre):
		return true
	for node: Dictionary in rules.NODES:
		if inside.has_point(centre + node.at * wheel[1]):
			return true
	return false


## Eases the view back to the start: no pan, zoom 1.
func _recentre() -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_pan", Vector2.ZERO, 0.25)
	tween.tween_property(self, "_zoom", 1.0, 0.25)


## What is under `point`: a node (_hovered), else a theme heading (_hovered_theme). OFF: nothing.
func _hover(point: Vector2) -> void:
	_hovered = _node_at(point)
	_hovered_theme = _theme_at(point) if _hovered == "" else -1


## The index of the THEMES heading showing under `point`, or -1.
func _theme_at(point: Vector2) -> int:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return -1
	var wheel := _wheel()
	for i in rules.THEMES.size():
		if i < _themes_shown.size() and _themes_shown[i] \
				and theme_plate(rules.THEMES[i], wheel[1], wheel[2], font).grow(4.0).has_point(point - wheel[0]):
			return i
	return -1


func _node_at(point: Vector2) -> String:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return ""
	var wheel := _wheel()
	var r: float = wheel[2]
	for node: Dictionary in rules.NODES:
		if not _shown.has(node.id):
			continue
		var at: Vector2 = wheel[0] + node.at * wheel[1]
		if _plate(node.id, at, r).grow(4.0).has_point(point) if rules.is_dept(node.id) else point.distance_to(at) < r * 1.2:
			return node.id
	return ""


# --- Drawing ---

## The tree's nodes and edges on _layer, around its origin (the hub). Drawn at full strength; the
## light (and the shimmer) dim the layer (modulate). Only redrawn when _layer_key changes.
func _draw_layer() -> void:
	var save: SaveGame = SaveManager.save
	var wheel := _wheel()
	var unit: Vector2 = wheel[1]
	var r: float = wheel[2]
	var faint := PackedVector2Array()
	var locked := PackedVector2Array()
	for node: Dictionary in rules.NODES:
		if not _shown.has(node.id):
			continue
		# Edge to edge: the line stops at both circles instead of running into them (under a
		# department's opaque plate it simply runs on to its centre).
		var from: Vector2 = Vector2.ZERO if node.parent == "" else rules.node_data(node.parent).at * unit
		var from_r := r * 1.1 if node.parent == "" else _size(node.parent, r)
		# A branch's first node hangs off its heading, and the heading off the parent: the heading is
		# part of the branch (its opaque plate hides where the lines meet under it).
		var branch := theme_of(rules.THEMES, node.id)
		if branch >= 0:
			var spot: Vector2 = rules.THEMES[branch][1] * unit
			_edge(faint, locked, from, spot, from_r, 0.0, r, node.id, save)
			from = spot
			from_r = 0.0
		_edge(faint, locked, from, node.at * unit, from_r, _size(node.id, r), r, node.id, save)
	if not faint.is_empty():
		_layer.draw_multiline(faint, Color(ink, 0.15), 2.0)
	if not locked.is_empty():
		_layer.draw_multiline(locked, Color(ink, 0.35), 3.0)
	# Each theme's heading at the start of its branch: a green label plate like a department's (info
	# only: no glyph, a thin rim, never held; hovered, it shows its category's popup).
	var heading := _plate_font(r)
	for i in rules.THEMES.size():
		if i >= _themes_shown.size() or not _themes_shown[i]:
			continue
		var box := theme_plate(rules.THEMES[i], unit, r, font)
		_draw_plate(_layer, box, accent, Color(ink, 0.6), 2.0)
		_layer.draw_string(font, Vector2(box.position.x, box.get_center().y + heading * 0.36), tr(rules.THEMES[i][0]),
				HORIZONTAL_ALIGNMENT_CENTER, box.size.x, heading, ink)
	# The hub: a cabbage cross-section, the one green thing on the tree.
	_layer.draw_circle(Vector2.ZERO, r * 1.1, accent)
	_layer.draw_circle(Vector2.ZERO, r * 1.1, ink, false, 3.0, true)
	for i in 3:
		_layer.draw_arc(Vector2(r * 0.15, 0), r * (0.3 + i * 0.25), PI * 0.6, PI * 1.9, 16, Color(0.9, 1.0, 0.8, 0.8), 2.0, true)
	for node: Dictionary in rules.NODES:
		if _shown.has(node.id):
			_draw_node(node, node.at * unit, r, save)


## One edge, rim to rim (`from_r`, `to_r`), styled by node `id`: solid when reachable, dashed when
## locked, faint dashes when out of reach.
func _edge(faint: PackedVector2Array, locked: PackedVector2Array, from: Vector2, to: Vector2, from_r: float,
		to_r: float, r: float, id: String, save: SaveGame) -> void:
	if from.distance_to(to) <= from_r + to_r + r * 0.5:
		return
	var dir := from.direction_to(to)
	var start := from + dir * from_r
	var end := to - dir * to_r
	if not rules.is_reachable(id, save):
		_dashes(faint, start, end, 7.0)
	elif rules.locked_by(id, save) != "":
		_dashes(locked, start, end, 9.0)
	else:
		_layer.draw_line(start, end, Color(ink, 0.6), 3.0, true)


## The index of the heading in `themes` whose first nodes include `id`, or -1.
static func theme_of(themes: Array, id: String) -> int:
	for i in themes.size():
		if id in themes[i][2]:
			return i
	return -1


## How far (degrees) the branch bends at `heading` ([title, spot, roots]) of tree `tree`: 0 when it
## sits straight between its first nodes' parent (or the hub) and their middle.
static func heading_bend(tree: Script, heading: Array) -> float:
	var parent: String = tree.node_data(heading[2][0]).parent
	var from: Vector2 = Vector2.ZERO if parent == "" else tree.node_data(parent).at
	var toward := Vector2.ZERO
	for id: String in heading[2]:
		toward += tree.node_data(id).at / heading[2].size()
	return 180.0 - rad_to_deg(absf((from - heading[1]).angle_to(toward - heading[1])))


## Dash segments from `from` to `to` (`dash` long, same gap) added to a multiline batch.
static func _dashes(into: PackedVector2Array, from: Vector2, to: Vector2, dash: float) -> void:
	var length := from.distance_to(to)
	var dir := from.direction_to(to)
	var at := 0.0
	while at < length:
		into.append(from + dir * at)
		into.append(from + dir * minf(at + dash, length))
		at += dash * 2.0


## What moves per frame, on _top: the hint, the hovered node's ring, the hold arc and the popup.
## Steady: the shimmer doesn't reach it.
func _draw_top() -> void:
	var save: SaveGame = SaveManager.save
	var wheel := _wheel()
	var r: float = wheel[2]
	var area := Rect2(Vector2.ZERO, size)
	var hint := tr("DRAG TO MOVE   |   WHEEL TO ZOOM") if _pan == Vector2.ZERO and is_equal_approx(_zoom, 1.0) else tr("DOUBLE-CLICK TO RECENTRE")
	_top.draw_string(font, area.end - Vector2(area.size.x, 12.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 14.0, 15, Color(ink, light * 0.55))
	if _holding != "":
		var at: Vector2 = wheel[0] + rules.node_data(_holding).at * wheel[1]
		if _denied > 0.0:
			_top.draw_arc(at, r + 4.0, 0.0, TAU, 32, Color(refused, light), 4.0, true)
		elif _hold > 0.0:
			_top.draw_arc(at, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * _hold, 40, Color(ink, light), 5.0, true)
	# NEW: a ring pulsing out from each node showing for the first time.
	var beat := fmod(Time.get_ticks_msec() / 1000.0, NEW_PULSE) / NEW_PULSE
	for id in _fresh:
		var at: Vector2 = wheel[0] + rules.node_data(id).at * wheel[1]
		var fade := Color(ink, light * 0.7 * (1.0 - beat))
		var corner := Vector2(r * 0.8, r * 1.05)
		if rules.is_dept(id):
			var box := _plate(id, at, r)
			_draw_plate(_top, box.grow(r * 0.35 * beat), Color.TRANSPARENT, fade, 3.0)
			corner = box.end - at + Vector2(4.0, 0.0)
		else:
			_top.draw_arc(at, r * (1.15 + 0.35 * beat), 0.0, TAU, 40, fade, 3.0, true)
		_top.draw_string(font, at + corner, tr("NEW"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(r * 0.6, 14.0, 28.0)), Color(ink, light))
	if _hovered != "":
		var at: Vector2 = wheel[0] + rules.node_data(_hovered).at * wheel[1]
		var lit := Color(glow, glow.a * light)
		var reach := r
		if rules.is_dept(_hovered):
			var box := _plate(_hovered, at, r)
			_draw_plate(_top, box, lit, Color.TRANSPARENT, 0.0)
			reach = box.size.x / 2.0
		else:
			_top.draw_circle(at, r, lit)
		_draw_popup(rules.node_data(_hovered), at, reach, save, light, area)
	elif _hovered_theme >= 0:
		var heading: Array = rules.THEMES[_hovered_theme]
		var box := theme_plate(heading, wheel[1], r, font)
		box.position += wheel[0]
		_draw_plate(_top, box, Color(glow, glow.a * light), Color.TRANSPARENT, 0.0)
		_draw_category(heading[0], heading[3], theme_members(rules, _hovered_theme), box.get_center(), box.size.x / 2.0,
				save, light, area)


## Where an edge stops short of node `id`: its circle's rim, or (under a department's plate) nowhere.
func _size(id: String, r: float) -> float:
	return 0.0 if rules.is_dept(id) else r


func _draw_node(node: Dictionary, at: Vector2, r: float, save: SaveGame) -> void:
	if node.get("dept", false):
		_draw_dept(node, at, r, save)
		return
	var is_bought: bool = rules.is_bought(node.id, save)
	var reachable: bool = rules.is_reachable(node.id, save)
	var locked: bool = reachable and rules.locked_by(node.id, save) != ""
	var alpha := 0.16 if not reachable else 0.3 if locked else 1.0 if is_bought or save.get(currency_of(node)) >= rules.price_of(node.id, save) else 0.35
	var line := Color(ink, alpha)
	if is_bought:
		_layer.draw_circle(at, r, line)
	if locked or not reachable:
		# A broken rim: on the plan, not yet approved (a padlock when research holds it).
		var rim := PackedVector2Array()
		for i in 12:
			for j in 3:
				rim.append(at + Vector2.from_angle(TAU * (i + 0.2 * j) / 12.0) * r)
				rim.append(at + Vector2.from_angle(TAU * (i + 0.2 * (j + 1)) / 12.0) * r)
		_layer.draw_multiline(rim, line, 3.0)
	else:
		_layer.draw_circle(at, r, line, false, 3.0, true)
	_draw_icon("padlock" if locked else node.icon, at, r * 0.55, Color(beam, alpha) if is_bought else line)
	# Bought shows as the filled disc (the popup says APPROVED): a word under it would run into
	# the next node's title in the vertical chains.
	var font_size := int(clampf(r * 0.6, 9.0, 34.0))
	_layer.draw_string(font, at + Vector2(-200.0, -r - 8.0), tr(node.title), HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, line)


## A department: info only, so a rounded plate in the hub's green with its glyph and name, never
## a circle (circles are bought). Closed (its cards or research missing) it is faded, a padlock for research.
func _draw_dept(node: Dictionary, at: Vector2, r: float, save: SaveGame) -> void:
	var open: bool = rules.is_open(node.id, save)
	var locked: bool = rules.is_reachable(node.id, save) and not open
	var alpha := 1.0 if open else 0.45 if locked else 0.3
	var line := Color(ink, alpha)
	var box := _plate(node.id, at, r)
	# Opaque (faded toward the ground, not see-through) so the edges under it stay hidden.
	_draw_plate(_layer, box, ground.lerp(accent, alpha), line, 4.0 if open else 2.0)
	var font_size := _plate_font(r)
	var icon_at := Vector2(box.position.x + box.size.y * 0.55, at.y)
	_draw_icon("padlock" if locked else node.icon, icon_at, box.size.y * 0.3, line)
	_layer.draw_string(font, Vector2(box.position.x + box.size.y, at.y + font_size * 0.36), tr(node.title),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, line)


## A department plate's type size for node radius `r`.
static func _plate_font(r: float) -> int:
	return int(clampf(r * 0.7, 12.0, 32.0))


func _plate(id: String, at: Vector2, r: float) -> Rect2:
	return plate(rules.node_data(id).get("title", ""), at, r, font)


## A department's plate around `at`, sized to its translated `title` with room for the glyph on its left.
static func plate(title: String, at: Vector2, r: float, face: Font = FONT) -> Rect2:
	var font_size := _plate_font(r)
	var height := font_size * 2.0
	var dims := Vector2(face.get_string_size(TranslationServer.translate(title), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + height * 1.45, height)
	return Rect2(at - dims / 2.0, dims)


## A theme's heading plate (`heading`: [title, spot, roots]) at wheel scale `unit` (px per unit) and
## node radius `r`, sized to its translated title.
static func theme_plate(heading: Array, unit: Vector2, r: float, face: Font = FONT) -> Rect2:
	var font_size := _plate_font(r)
	var height := font_size * 2.0
	var dims := Vector2(face.get_string_size(TranslationServer.translate(heading[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + height, height)
	return Rect2(heading[1] * unit - dims / 2.0, dims)


## A node's popup while desk card `card` (a form) locks it: ["LOCKED", the form's title, the
## sentence to fill with it]. The sentence tells the player to approve it while it is in the tray
## (save.offered, what the desk really holds), else that it has not reached the desk yet (the tree
## names undealt cards, as it always has).
static func form_lock(card: String, save: SaveGame) -> Array:
	var on_desk := save.tray_unlocked and save.offered.has(card)
	return ["LOCKED", UpgradeDesk.card_data(card).get("title", card), FORM_ON_DESK if on_desk else FORM_NOT_YET]


const FORM_ON_DESK := "Approve the form %s on your desk."
const FORM_NOT_YET := "Needs the form %s, which has not reached your desk yet."

## A category's popup (a THEMES heading or a department), under its description: the heading over
## the node it points at, or one line when nothing is left to point at (next_pick).
const PICK_HEADING := {buy = "CHEAPEST AFFORDABLE:", short = "CHEAPEST, NOT AFFORDABLE YET:", locked = "CHEAPEST, STILL LOCKED:"}
const PICK_DONE := "Every upgrade here is approved. Nothing further to requisition."
const PICK_LATER := "Nothing else here is on file yet."


## The nodes of THEMES heading `index` of tree `tree`: its first nodes and everything under them,
## up to where another heading's branch starts (the tree's own grouping), in NODES order.
static func theme_members(tree: Script, index: int) -> Array[String]:
	var stop := {}
	for i in tree.THEMES.size():
		if i != index:
			for id: String in tree.THEMES[i][2]:
				stop[id] = true
	return _under(tree, tree.THEMES[index][2], stop)


## The nodes under department `id`, every heading's branch included, in NODES order.
static func dept_members(tree: Script, id: String) -> Array[String]:
	return _under(tree, [id], {}).filter(func(member: String) -> bool: return member != id)


static func _under(tree: Script, roots: Array, stop: Dictionary) -> Array[String]:
	var inside := {}
	for id: String in roots:
		inside[id] = true
	var out: Array[String] = []
	for node: Dictionary in tree.NODES:  # Parents come before their children in NODES.
		if not inside.has(node.id) and inside.has(node.parent) and not stop.has(node.id):
			inside[node.id] = true
		if inside.has(node.id):
			out.append(node.id)
	return out


## What a category of `ids` (tree `tree`) points the player at in `save`, among its nodes showing and
## not bought: {id, state "buy"} the cheapest it can buy now (reachable, not locked, paid for); else
## {id, "short"} the cheapest open one it can't pay yet; else {id, "locked"} the cheapest of the rest
## (its popup line is requirement: a form to approve, a parent first). Nothing showing left:
## {state "done"} when every node is bought, else {state "later"} (the rest hidden behind cards).
static func next_pick(tree: Script, ids: Array, save: SaveGame) -> Dictionary:
	var left := ids.filter(func(id: String) -> bool: return not tree.is_dept(id) and not tree.is_bought(id, save))
	if left.is_empty():
		return {state = "done"}
	var shown := left.filter(func(id: String) -> bool: return tree.is_shown(id, save))
	if shown.is_empty():
		return {state = "later"}
	var open := shown.filter(func(id: String) -> bool: return tree.is_reachable(id, save) and tree.locked_by(id, save) == "")
	var paid := open.filter(func(id: String) -> bool:
		return save.get(currency_of(tree.node_data(id))) >= tree.price_of(id, save))
	for pool: Array in [[paid, "buy"], [open, "short"], [shown, "locked"]]:
		if not pool[0].is_empty():
			var best: String = pool[0][0]
			for id: String in pool[0]:
				if tree.price_of(id, save) < tree.price_of(best, save):
					best = id
			return {id = best, state = pool[1]}
	return {state = "later"}


## A popup body `text` (already translated) word-wrapped to POPUP_TEXT at POPUP_BODY: its own line
## breaks kept, a word too long for a line left on one of its own.
static func popup_lines(text: String, face: Font = FONT) -> PackedStringArray:
	var out := PackedStringArray()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var longer := word if line.is_empty() else line + " " + word
			if not line.is_empty() and face.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, POPUP_BODY).x > POPUP_TEXT:
				out.append(line)
				longer = word
			line = longer
		out.append(line)
	return out


## How many of popup_lines(`text`) are its flavour line (wrapped): 0 when it has no line break.
static func flavour_lines(text: String, face: Font = FONT) -> int:
	var flavour := PaperNote.flavour_split(text)[0]
	return 0 if flavour == "" else popup_lines(flavour, face).size()


## A rounded box on `canvas`: `fill` inside, a `border` rim `width` wide.
static func _draw_plate(canvas: CanvasItem, box: Rect2, fill: Color, border: Color, width: float) -> void:
	# One stylebox, re-set per plate: draw() records its polygons at once, so reuse is safe.
	if _plate_style == null:
		_plate_style = StyleBoxFlat.new()
		_plate_style.anti_aliasing = true
	var style := _plate_style
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width))
	style.set_corner_radius_all(int(box.size.y * 0.25))
	style.draw(canvas.get_canvas_item(), box)


## Simple line glyphs, centred on `at`, about `s` from the centre to the edge.
func _draw_icon(icon: String, at: Vector2, s: float, color: Color) -> void:
	match icon:
		"megaphone":
			_layer.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.6, -s * 0.3), at + Vector2(s * 0.7, -s * 0.8),
					at + Vector2(s * 0.7, s * 0.8), at + Vector2(-s * 0.6, s * 0.3)]), color)
			_layer.draw_rect(Rect2(at + Vector2(-s, -s * 0.3), Vector2(s * 0.4, s * 0.6)), color)
		"crate":
			var box := Rect2(at - Vector2(s, s) * 0.8, Vector2(s, s) * 1.6)
			_layer.draw_rect(box, color, false, 2.5)
			_layer.draw_line(box.position, box.end, color, 2.0)
			_layer.draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), color, 2.0)
		"clock":
			_layer.draw_arc(at, s * 0.85, 0.0, TAU, 24, color, 2.5, true)
			_layer.draw_line(at, at + Vector2(0, -s * 0.6), color, 2.5)
			_layer.draw_line(at, at + Vector2(s * 0.45, 0), color, 2.5)
		"lens":
			_layer.draw_arc(at + Vector2(-s * 0.2, -s * 0.2), s * 0.55, 0.0, TAU, 20, color, 2.5, true)
			_layer.draw_line(at + Vector2(s * 0.2, s * 0.2), at + Vector2(s * 0.85, s * 0.85), color, 4.0)
		"hand":
			# A mitten-like office hand: palm, four fingers, a thumb.
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.15), Vector2(s, s * 0.85)), color)
			for i in 4:
				var tall := s * (0.55 if i in [0, 3] else 0.7)
				_layer.draw_rect(Rect2(at + Vector2(-s * 0.5 + i * s * 0.26, -s * 0.15 - tall), Vector2(s * 0.2, tall)), color)
			_layer.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.5, s * 0.05), at + Vector2(-s * 0.95, -s * 0.3),
					at + Vector2(-s * 0.8, -s * 0.45), at + Vector2(-s * 0.5, -s * 0.2)]), color)
		"belt":
			for x: float in [-0.55, 0.55]:
				_layer.draw_arc(at + Vector2(s * x, 0), s * 0.3, 0.0, TAU, 14, color, 2.5, true)
			_layer.draw_line(at + Vector2(-s * 0.55, -s * 0.3), at + Vector2(s * 0.55, -s * 0.3), color, 2.5)
			_layer.draw_line(at + Vector2(-s * 0.55, s * 0.3), at + Vector2(s * 0.55, s * 0.3), color, 2.5)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.25, -s * 0.75), Vector2(s * 0.5, s * 0.4)), color)
		"padlock":
			_layer.draw_arc(at + Vector2(0, -s * 0.15), s * 0.42, PI, TAU, 12, color, 3.0, true)
			for x: float in [-0.42, 0.42]:
				_layer.draw_line(at + Vector2(s * x, -s * 0.15), at + Vector2(s * x, s * 0.1), color, 3.0)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.7, s * 0.05), Vector2(s * 1.4, s * 0.85)), color)
			_layer.draw_circle(at + Vector2(0, s * 0.4), s * 0.13, Color(ground, color.a))
		"pilcrow":
			_layer.draw_string(font, at + Vector2(-s, s * 0.6), "¶+", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 1.5), color)
		"desk":
			# A desk top seen from above, with two units on it.
			_layer.draw_rect(Rect2(at - Vector2(s * 0.9, s * 0.6), Vector2(s * 1.8, s * 1.2)), color, false, 2.5)
			for x: float in [-0.4, 0.4]:
				_layer.draw_circle(at + Vector2(s * x, 0), s * 0.28, color)
		"puck":
			# The coin unit: a disc with its lamp, and a coin beside it.
			_layer.draw_arc(at + Vector2(-s * 0.15, 0), s * 0.7, 0.0, TAU, 20, color, 2.5, true)
			_layer.draw_circle(at + Vector2(-s * 0.15, -s * 0.4), s * 0.14, color)
			_layer.draw_circle(at + Vector2(s * 0.75, s * 0.55), s * 0.22, color)
		"chair":
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.8), Vector2(s * 0.25, s * 1.0)), color)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.5, 0), Vector2(s * 1.0, s * 0.22)), color)
			for x: float in [-0.45, 0.4]:
				_layer.draw_line(at + Vector2(s * x, s * 0.2), at + Vector2(s * x, s * 0.85), color, 2.5)
		"tractor":
			# Side on: a cab over a body, a big rear wheel and a small front one.
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.55, -s * 0.85), Vector2(s * 0.5, s * 0.55)), color, false, 2.5)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.7, -s * 0.3), Vector2(s * 1.5, s * 0.4)), color)
			_layer.draw_arc(at + Vector2(-s * 0.35, s * 0.4), s * 0.42, 0.0, TAU, 18, color, 2.5, true)
			_layer.draw_circle(at + Vector2(s * 0.55, s * 0.5), s * 0.25, color)
		"sprout":
			# A stem with two leaves out of a line of soil.
			_layer.draw_line(at + Vector2(-s * 0.8, s * 0.7), at + Vector2(s * 0.8, s * 0.7), color, 2.5)
			_layer.draw_line(at + Vector2(0, s * 0.7), at + Vector2(0, -s * 0.2), color, 2.5)
			_layer.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 0.1), at + Vector2(-s * 0.75, -s * 0.55),
					at + Vector2(-s * 0.3, -s * 0.05)]), color)
			_layer.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 0.2), at + Vector2(s * 0.7, -s * 0.85),
					at + Vector2(s * 0.35, -s * 0.15)]), color)


func _draw_popup(node: Dictionary, at: Vector2, r: float, save: SaveGame, lit: float, area: Rect2) -> void:
	var needs: Array = rules.requirement(node.id, save)
	if node.get("dept", false) and needs.is_empty():
		_draw_category(node.title, node.body, dept_members(rules, node.id), at, r, save, lit, area)
		return
	var width := POPUP_WIDTH
	var lines := popup_lines(tr(node.body), font)
	# A form lock (form_lock) says what to do in a wrapped sentence under its heading.
	var form := popup_lines(tr(needs[2]) % tr(needs[1]), font) if needs.size() > 2 else PackedStringArray()
	var height := 100.0 + lines.size() * POPUP_STEP + (32.0 if not needs.is_empty() else 0.0) \
			+ maxf(0.0, form.size() - 1) * POPUP_STEP
	var pos := at + Vector2(r + 14.0, -height / 2.0)
	if pos.x + width > area.end.x:
		pos.x = at.x - r - 14.0 - width
	pos.x = clampf(pos.x, area.position.x + 6.0, area.end.x - width - 6.0)
	pos.y = clampf(pos.y, area.position.y + 6.0, area.end.y - height - 6.0)
	var box := Rect2(pos, Vector2(width, height))
	_top.draw_rect(box, Color(ink, lit * 0.92))
	var text := Color(beam, lit)
	_top.draw_string(font, pos + Vector2(16, 38), tr(node.title), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 30, text)
	# The flavour line (the body's first, PaperNote.flavour_split) in italics and dimmer, the
	# description upright at full beam, so the rules read first.
	var flavour := flavour_lines(tr(node.body), font)
	for i in lines.size():
		_top.draw_string(PaperNote.italic(font) if i < flavour else font, pos + Vector2(16, 70 + i * POPUP_STEP), lines[i], HORIZONTAL_ALIGNMENT_LEFT, POPUP_TEXT, POPUP_BODY, Color(text, lit * (FLAVOUR_ALPHA if i < flavour else BODY_ALPHA)))
	if not needs.is_empty():
		# What it waits for, on one line, its name under it.
		var red := Color(warn, lit)
		var below := maxf(0.0, form.size() - 1) * POPUP_STEP
		_top.draw_string(font, pos + Vector2(16, height - 48 - below), tr(needs[0]), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 21, red)
		if form.is_empty():
			_top.draw_string(font, pos + Vector2(16, height - 16), tr(needs[1]), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 24, red)
		for i in form.size():
			_top.draw_string(font, pos + Vector2(16, height - 16 - below + i * POPUP_STEP), form[i], HORIZONTAL_ALIGNMENT_LEFT, POPUP_TEXT, POPUP_BODY, red)
		return
	var is_bought: bool = rules.is_bought(node.id, save)
	var price: int = rules.price_of(node.id, save)
	var findings := currency_of(node) == "findings"
	var cost := tr("APPROVED") if is_bought else (tr("COST ¶%d") if findings else tr("COST $%d")) % price
	var short: bool = not is_bought and save.get(currency_of(node)) < price
	_draw_cost(pos + Vector2(16, height - 16), cost, Color(warn, lit) if short else text)


## A popup's cost line at `at` (its baseline): the ¶ figure in price_font (the Findings counter's
## face), the words before it in `font`.
func _draw_cost(at: Vector2, cost: String, color: Color) -> void:
	var sign_at := cost.find("¶")
	if price_font == null or sign_at < 0:
		_top.draw_string(font, at, cost, HORIZONTAL_ALIGNMENT_LEFT, POPUP_TEXT, 24, color)
		return
	var words := cost.left(sign_at)
	_top.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
	var figure_at := at + Vector2(font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, 0)
	_top.draw_string(price_font, figure_at, cost.substr(sign_at), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, color)


## The lines under a category's description for next_pick `pick`, each [text, size, warn?, cost?]:
## its heading, the node's name, then its cost or what locks it; or one dry line.
func _pick_rows(pick: Dictionary, save: SaveGame) -> Array:
	if not pick.has("id"):
		var dry := []
		for line in popup_lines(tr(PICK_DONE if pick.state == "done" else PICK_LATER), font):
			dry.append([line, POPUP_BODY, false, false])
		return dry
	var node: Dictionary = rules.node_data(pick.id)
	var rows := [[tr(PICK_HEADING[pick.state]), 21, false, false], [tr(node.title), 24, false, false]]
	if pick.state != "locked":
		var cost := (tr("COST ¶%d") if currency_of(node) == "findings" else tr("COST $%d")) % rules.price_of(pick.id, save)
		rows.append([cost, 24, pick.state == "short", true])
		return rows
	var needs: Array = rules.requirement(pick.id, save)
	if needs.is_empty():
		return rows
	var why: String = tr(needs[2]) % tr(needs[1]) if needs.size() > 2 else tr(needs[0]) + " " + tr(needs[1])
	for line in popup_lines(why, font):
		rows.append([line, POPUP_BODY, true, false])
	return rows


## A category's popup (a THEMES heading or an open department) beside `at`: its name, its
## description (`body`, a flavour line first), and the node next_pick points at among `ids`.
func _draw_category(title: String, body: String, ids: Array, at: Vector2, r: float, save: SaveGame, lit: float,
		area: Rect2) -> void:
	var lines := popup_lines(tr(body), font)
	var rows := _pick_rows(next_pick(rules, ids, save), save)
	# Like a node's popup: the first row sits where its cost would, each further row one step lower.
	var height := 100.0 + lines.size() * POPUP_STEP
	for row: Array in rows.slice(0, -1):
		height += POPUP_STEP if row[1] == POPUP_BODY else 32.0
	var pos := at + Vector2(r + 14.0, -height / 2.0)
	if pos.x + POPUP_WIDTH > area.end.x:
		pos.x = at.x - r - 14.0 - POPUP_WIDTH
	pos.x = clampf(pos.x, area.position.x + 6.0, area.end.x - POPUP_WIDTH - 6.0)
	pos.y = clampf(pos.y, area.position.y + 6.0, area.end.y - height - 6.0)
	_top.draw_rect(Rect2(pos, Vector2(POPUP_WIDTH, height)), Color(ink, lit * 0.92))
	var text := Color(beam, lit)
	_top.draw_string(font, pos + Vector2(16, 38), tr(title), HORIZONTAL_ALIGNMENT_LEFT, POPUP_TEXT, 30, text)
	var flavour := flavour_lines(tr(body), font)
	for i in lines.size():
		_top.draw_string(PaperNote.italic(font) if i < flavour else font, pos + Vector2(16, 70 + i * POPUP_STEP), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, POPUP_TEXT, POPUP_BODY, Color(text, lit * (FLAVOUR_ALPHA if i < flavour else BODY_ALPHA)))
	var y := 70.0 + (lines.size() - 1) * POPUP_STEP + 41.0
	for row: Array in rows:
		var color := Color(warn, lit) if row[2] else text
		if row[3]:
			_draw_cost(pos + Vector2(16, y), row[0], color)
		else:
			_top.draw_string(font, pos + Vector2(16, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, POPUP_TEXT, row[1], color)
		y += POPUP_STEP if row[1] == POPUP_BODY else 32.0
