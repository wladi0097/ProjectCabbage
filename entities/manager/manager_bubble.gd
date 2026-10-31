class_name ManagerBubble
extends Control
## The manager's speech bubble: a paper bubble hanging from the top screen edge over the window,
## its tail pointing up at him. It says the quota, counts down and fills a bar with the units moved;
## at the verdict it is stamped MET or NOT MET. Drawn only while he is there; never takes the mouse.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const PAPER := Color(0.72, 0.73, 0.69)
const INK := Color(0.13, 0.15, 0.14)
const STAMP := Color(0.55, 0.12, 0.1)
const SIZE := Vector2(480, 150)
## The bubble's centre as a fraction of the view's width (over the sale part of the window).
const AT_X := 0.62
const TOP := 26.0
const POP_TIME := 0.25
## Drawn a little smaller than SIZE so it covers less of the sill.
const SCALE := 0.88

var manager: Manager
var _pop := 1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func pop() -> void:
	_pop = 0.0


func _process(delta: float) -> void:
	_pop = minf(_pop + delta / POP_TIME, 1.0)
	queue_redraw()


func _draw() -> void:
	if manager == null or manager.phase not in [Manager.Phase.QUOTA, Manager.Phase.VERDICT]:
		return
	var view := get_viewport_rect().size
	var scale_by := lerpf(0.85, 1.0, ease(_pop, 0.4)) * SCALE
	draw_set_transform(Vector2(view.x * AT_X, TOP), 0.0, Vector2.ONE * scale_by)
	var box := Rect2(-SIZE.x / 2.0, 0.0, SIZE.x, SIZE.y)
	var alpha := clampf(_pop * 2.0, 0.0, 1.0)
	draw_rect(Rect2(box.position + Vector2(8, 8), box.size), Color(0, 0, 0, 0.35 * alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(-34, 1), Vector2(10, 1), Vector2(-20, -TOP - 4)]), Color(PAPER, alpha))
	draw_rect(box, Color(PAPER, alpha))
	var ink := Color(INK, alpha)
	var x := box.position.x + 22.0
	var w := SIZE.x - 44.0
	draw_string(FONT, Vector2(x, 30), "MANAGEMENT  |  UNIT QUOTA", HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color(ink, alpha * 0.6))
	var secs := ceili(manager.left)
	var urgent := manager.phase == Manager.Phase.QUOTA and secs <= Manager.TICK_FROM
	draw_string(FONT, Vector2(x, 38), "0:%02d" % secs, HORIZONTAL_ALIGNMENT_RIGHT, w, 34, Color(STAMP, alpha) if urgent else ink)
	draw_string(FONT, Vector2(x, 76), manager.line, HORIZONTAL_ALIGNMENT_LEFT, w, 22, ink)
	# Units moved against the quota: a ruled bar filling in ink.
	var moved := mini(SaveManager.save.sold - manager.sold_at, manager.quota)
	var bar := Rect2(x, 96, w - 110.0, 18)
	draw_rect(bar, Color(ink, alpha * 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * moved / maxf(manager.quota, 1.0), bar.size.y)), Color(ink, alpha * 0.8))
	draw_rect(bar, ink, false, 1.5)
	draw_string(FONT, Vector2(bar.end.x + 12, 112), "%d / %d" % [moved, manager.quota], HORIZONTAL_ALIGNMENT_LEFT, 100, 20, ink)
	# The time left as a thin rule along the bottom edge.
	var time_left := manager.left / maxf(SaveManager.save.manager_time, 1.0)
	draw_line(Vector2(x, 132), Vector2(x + w * time_left, 132), Color(ink, alpha * 0.5), 3.0)
	if manager.phase == Manager.Phase.VERDICT:
		var thump := 1.0 + 0.3 * (1.0 - ease(_pop, 0.3))
		draw_set_transform(Vector2(view.x * AT_X, TOP) + Vector2(140, 70) * scale_by, deg_to_rad(-8.0), Vector2.ONE * thump * scale_by)
		var word := "MET" if manager.met else "NOT MET"
		draw_rect(Rect2(-74, -26, 148, 50), Color(STAMP, 0.85), false, 3.0)
		draw_string(FONT, Vector2(-74, 13), word, HORIZONTAL_ALIGNMENT_CENTER, 148, 32, Color(STAMP, 0.85))
	draw_set_transform(Vector2.ZERO)
