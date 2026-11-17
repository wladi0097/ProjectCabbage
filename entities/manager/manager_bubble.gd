class_name ManagerBubble
extends Control
## The manager's speech bubble: a paper bubble hanging from the top screen edge over the window,
## its tail pointing up at him. It says the quota, counts the cabbages moved against it in big figures
## and drains a bar with the time left;
## at the verdict it pops again with his praise or scorn. Drawn only while he is there; never takes the mouse.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const PAPER := Color(0.72, 0.73, 0.69)
const INK := Color(0.13, 0.15, 0.14)
## The time bar's colour in its last seconds.
const URGENT := Color(0.55, 0.12, 0.1)
const SIZE := Vector2(480, 136)
## The bubble's centre as a fraction of the view's width (top right, over the empty corner by the
## lamp), kept EDGE px clear of the right edge on a narrow view.
const AT_X := 0.875
const EDGE := 24.0
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


## The bubble's centre (px) on a view `width` px wide.
static func centre_x(width: float) -> float:
	return minf(width * AT_X, width - SIZE.x * SCALE / 2.0 - EDGE)


func _draw() -> void:
	if manager == null or manager.phase not in [Manager.Phase.QUOTA, Manager.Phase.VERDICT]:
		return
	var view := get_viewport_rect().size
	var scale_by := lerpf(0.85, 1.0, ease(_pop, 0.4)) * SCALE
	draw_set_transform(Vector2(centre_x(view.x), TOP), 0.0, Vector2.ONE * scale_by)
	var box := Rect2(-SIZE.x / 2.0, 0.0, SIZE.x, SIZE.y)
	var alpha := clampf(_pop * 2.0, 0.0, 1.0)
	draw_rect(Rect2(box.position + Vector2(8, 8), box.size), Color(0, 0, 0, 0.35 * alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(-34, 1), Vector2(10, 1), Vector2(-20, -TOP - 4)]), Color(PAPER, alpha))
	draw_rect(box, Color(PAPER, alpha))
	var ink := Color(INK, alpha)
	var x := box.position.x + 22.0
	var w := SIZE.x - 44.0
	draw_string(FONT, Vector2(x, 30), tr("MANAGEMENT  |  CABBAGE QUOTA"), HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color(ink, alpha * 0.6))
	# Cabbages moved against the quota, the first thing read.
	draw_string(FONT, Vector2(x, 42), counter_text(SaveManager.save.sold - manager.sold_at, manager.quota),
			HORIZONTAL_ALIGNMENT_RIGHT, w, 38, ink)
	# The ask, set smaller where it runs long (three-digit quotas, German).
	var ask_size := 22
	while ask_size > 14 and FONT.get_string_size(manager.line, HORIZONTAL_ALIGNMENT_LEFT, -1, ask_size).x > w:
		ask_size -= 1
	draw_string(FONT, Vector2(x, 76), manager.line, HORIZONTAL_ALIGNMENT_LEFT, w, ask_size, ink)
	# The time left: a ruled bar draining in ink, in the alarm colour once the countdown ticks.
	var hot := ink
	if manager.phase == Manager.Phase.QUOTA and urgent(manager.left):
		hot = Color(URGENT, alpha)
	var bar := Rect2(x, 96, w - 70.0, 18)
	draw_rect(bar, Color(ink, alpha * 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * time_fraction(manager.left, SaveManager.save.manager_time), bar.size.y)),
			Color(hot, alpha * 0.8))
	draw_rect(bar, ink, false, 1.5)
	draw_string(FONT, Vector2(bar.end.x, 112), clock_text(manager.left), HORIZONTAL_ALIGNMENT_RIGHT, x + w - bar.end.x, 20, hot)
	if manager.on_hold and manager.phase == Manager.Phase.QUOTA:
		draw_string(FONT, Vector2(x, 130), tr("QUOTA ON HOLD. The war takes precedence."), HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color(URGENT, alpha))
	elif manager.revised and manager.phase == Manager.Phase.QUOTA:
		draw_string(FONT, Vector2(x, 130), tr("Head office has revised the target."), HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color(ink, alpha * 0.6))
	draw_set_transform(Vector2.ZERO)


## The bar's fill: the share of the deadline `total` still `left` (s), 0..1.
static func time_fraction(left: float, total: float) -> float:
	return clampf(left / maxf(total, 1.0), 0.0, 1.0)


## "12 / 30": cabbages moved since he asked against the quota, never past it.
static func counter_text(moved: int, quota: int) -> String:
	return "%d / %d" % [clampi(moved, 0, quota), quota]


## "0:23", "1:15": the seconds left, rounded up.
static func clock_text(left: float) -> String:
	var secs := ceili(left)
	@warning_ignore("integer_division")
	return "%d:%02d" % [secs / 60, secs % 60]


## The last Manager.TICK_FROM seconds, as the countdown ticks them.
static func urgent(left: float) -> bool:
	return ceili(left) <= Manager.TICK_FROM
