class_name RefusalBubble
extends Control
## The street's answer to a refused unit: a paper slip hanging from the top screen edge over the
## window, its tail pointing up at the street. It shows the asked price in red, struck through.
## It pops in with a shake, holds, and fades. Never takes the mouse. Only over the desk: while the
## camera is at the farm TV (FarmTv.away) no slip is hung, and one already up stays out of sight.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const PAPER := ManagerBubble.PAPER
const INK := ManagerBubble.INK
const RED := Color(0.72, 0.13, 0.1)
const SIZE := Vector2(130, 96)
const TOP := 26.0
const POP_TIME := 0.18
## Drawn this much bigger than SIZE.
const SCALE := 1.3
const HOLD_TIME := 1.1
const FADE_TIME := 0.4
## Kept this far from the screen's side edges.
const MARGIN := 24.0

var _price := 0
var _x := 0.0
var _top := TOP
var _time := INF


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


## The street refused a unit at `price`, out by the window at world point `at`.
func say(price: int, at: Vector3) -> void:
	if FarmTv.away:
		return
	_price = price
	var camera := get_viewport().get_camera_3d()
	var view := get_viewport_rect().size
	_x = camera.unproject_position(at).x if camera else view.x / 2.0
	_x = clampf(_x, SIZE.x * SCALE / 2.0 + MARGIN, view.x - SIZE.x * SCALE / 2.0 - MARGIN)
	# The manager's bubble hangs in the same place while he waits: hang below it then.
	_top = TOP
	for manager: Manager in get_tree().root.find_children("*", "Manager", true, false):
		if manager.phase in [Manager.Phase.QUOTA, Manager.Phase.VERDICT]:
			_top = TOP + ManagerBubble.SIZE.y * ManagerBubble.SCALE + 12.0
	_time = 0.0


func _process(delta: float) -> void:
	if _time > POP_TIME + HOLD_TIME + FADE_TIME:
		return
	_time += delta
	queue_redraw()


## A slip is up and the camera is on the desk.
func showing() -> bool:
	return _time <= POP_TIME + HOLD_TIME + FADE_TIME and not FarmTv.away


func _draw() -> void:
	if not showing():
		return
	var pop := minf(_time / POP_TIME, 1.0)
	var alpha := 1.0 - clampf((_time - POP_TIME - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
	var shake := 7.0 * exp(-7.0 * _time) * sin(45.0 * _time)
	draw_set_transform(Vector2(_x + shake, _top), 0.0, Vector2.ONE * lerpf(0.6, 1.0, ease(pop, 0.4)) * SCALE)
	var box := Rect2(-SIZE.x / 2.0, 0.0, SIZE.x, SIZE.y)
	draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(0, 0, 0, 0.35 * alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(-26, 1), Vector2(8, 1), Vector2(-14, -_top / SCALE - 4)]), Color(PAPER, alpha))
	draw_rect(box, Color(PAPER, alpha))
	var x := box.position.x + 16.0
	var w := SIZE.x - 32.0
	draw_string(FONT, Vector2(x, 22), tr("OFFER DECLINED"), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(INK, 0.6 * alpha))
	# The asked price in red, struck through twice.
	var red := Color(RED, alpha)
	var text := "$%d" % _price
	var font_size := 44
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := -width / 2.0
	draw_string(FONT, Vector2(left, 78), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, red)
	draw_line(Vector2(left - 4, 66), Vector2(left + width + 4, 50), red, 3.5)
	draw_line(Vector2(left - 4, 58), Vector2(left + width + 4, 60), red, 2.5)
	draw_set_transform(Vector2.ZERO)
