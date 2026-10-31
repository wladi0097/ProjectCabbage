extends CanvasLayer
## Milestone memos: when units sold (save.sold) passes a threshold in MILESTONES, its bonus is applied
## to the save once (its id goes into save.milestones), logged, and a paper memo slides up from the
## bottom edge, gets stamped, and slides away after HOLD seconds or on a click. Several due at once
## queue up. The game keeps running; only the paper's own rect takes the mouse.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const PAPER := Color(0.72, 0.73, 0.69)
const INK := Color(0.13, 0.15, 0.14)
const STAMP := Color(0.55, 0.12, 0.1)

## at = units sold; key = the save number multiplied by mul (times-only, so it stacks with upgrades).
const MILESTONES := [
	{id = "units_25", at = 25, key = "marketing", mul = 1.25, re = "25 UNITS MOVED",
		note = "Your output has been observed.", bonus = "Units are 25% more desirable."},
	{id = "units_100", at = 100, key = "findings_per_cabbage", mul = 2, re = "100 UNITS MOVED",
		note = "Management notes your contribution.", bonus = "Quality Assurance files twice the Findings."},
	{id = "units_250", at = 250, key = "associate_speed", mul = 1.5, re = "250 UNITS MOVED",
		note = "Associates were reminded that walking is billable.", bonus = "Hired hands move 50% faster."},
	{id = "units_1000", at = 1000, key = "hand_output", mul = 1.5, re = "1,000 UNITS MOVED",
		note = "The board has been informed. It did not respond.", bonus = "Hired hands make 50% more trips."},
	{id = "units_2500", at = 2500, key = "associate_speed", mul = 1.5, re = "2,500 UNITS MOVED",
		note = "Your figures have been laminated.", bonus = "Hired hands move 50% faster."},
	{id = "units_10000", at = 10000, key = "marketing", mul = 2.0, re = "10,000 UNITS MOVED",
		note = "A plaque is under consideration.", bonus = "Units are twice as desirable."},
]
const SIZE := Vector2(560, 250)
const IN_TIME := 0.35
const OUT_TIME := 0.3
const HOLD := 6.0
const STAMP_AT := 0.7

var _queue: Array[Dictionary] = []
var _memo := {}
var _t := 0.0
var _out_at := HOLD
var _stamped := false

@onready var _paper: Control = $Paper


func _ready() -> void:
	_paper.size = SIZE
	_paper.pivot_offset = SIZE / 2.0
	_paper.rotation = deg_to_rad(-1.5)
	_paper.visible = false
	_paper.draw.connect(_draw_paper)
	_paper.gui_input.connect(_on_paper_input)


func _process(delta: float) -> void:
	var save := SaveManager.save
	var due_now := due(save.sold, save.milestones)
	if not due_now.is_empty():
		apply(save, due_now)
		SaveManager.log_event("milestone", due_now.id)
		_queue.append(due_now)
	if _memo.is_empty():
		if _queue.is_empty():
			_paper.visible = false
			return
		_memo = _queue.pop_front()
		_t = 0.0
		_out_at = HOLD
		_stamped = false
		_paper.visible = true
		$Land.play()
	_t += delta
	if not _stamped and _t >= STAMP_AT:
		_stamped = true
		$Stamp.play()
	var view := get_viewport().get_visible_rect().size
	var shown := slide_at(_t, _out_at)
	_paper.position = Vector2(view.x * 0.5 - SIZE.x * 0.5, lerpf(view.y + 30.0, view.y - SIZE.y - 40.0, shown))
	_paper.queue_redraw()
	if _t >= _out_at + OUT_TIME:
		_memo = {}


## Queues a memo from elsewhere (the manager's performance concern): `re`, `note` and `bonus` as in
## MILESTONES, nothing applied.
func post(memo: Dictionary) -> void:
	_queue.append(memo)


func _on_paper_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_out_at = minf(_out_at, _t)
		_paper.accept_event()


## The first milestone reached at `sold` units and not yet in `reached`, or {} if none.
static func due(sold: int, reached: PackedStringArray) -> Dictionary:
	for m: Dictionary in MILESTONES:
		if sold >= m.at and not reached.has(m.id):
			return m
	return {}


## Multiplies the milestone's save number by its mul and records it as reached.
static func apply(save: SaveGame, m: Dictionary) -> void:
	var value: Variant = save.get(m.key)
	save.set(m.key, roundi(value * m.mul) if value is int else value * m.mul)
	save.milestones.append(m.id)


## 0 hidden .. 1 fully up: eases up over IN_TIME, then down over OUT_TIME from `out_at`.
static func slide_at(t: float, out_at: float) -> float:
	var up := 1.0 - pow(1.0 - clampf(t / IN_TIME, 0.0, 1.0), 3.0)
	return up * (1.0 - clampf((t - out_at) / OUT_TIME, 0.0, 1.0))


func _draw_paper() -> void:
	if _memo.is_empty():
		return
	var w := SIZE.x
	_paper.draw_rect(Rect2(Vector2(10, 10), SIZE), Color(0, 0, 0, 0.4))
	_paper.draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	_paper.draw_string(FONT, Vector2(28, 52), "MEMORANDUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, INK)
	_paper.draw_string(FONT, Vector2(28, 52), "INTERNAL  |  DO NOT REPLY", HORIZONTAL_ALIGNMENT_RIGHT, w - 56, 14, Color(INK, 0.6))
	_paper.draw_line(Vector2(28, 66), Vector2(w - 28, 66), INK, 2.0)
	_paper.draw_string(FONT, Vector2(28, 92), "TO: DESK 4     FROM: MANAGEMENT     RE: " + _memo.re, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 16, Color(INK, 0.8))
	_paper.draw_string(FONT, Vector2(28, 132), _memo.note, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21, INK)
	_paper.draw_string(FONT, Vector2(28, 168), "Effective immediately: " + _memo.bonus, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21, INK)
	_paper.draw_line(Vector2(28, 196), Vector2(w - 28, 196), Color(INK, 0.3), 1.0)
	_paper.draw_string(FONT, Vector2(28, 222), "Retain for your records. Records are retained regardless.", HORIZONTAL_ALIGNMENT_LEFT, w - 200, 13, Color(INK, 0.55))
	if _stamped:
		# The stamp thumps down slightly too big and settles.
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - (_t - STAMP_AT) / 0.12)
		_paper.draw_set_transform(Vector2(w - 92, 214), deg_to_rad(-9.0), Vector2(pop, pop))
		_paper.draw_rect(Rect2(-62, -24, 124, 46), Color(STAMP, 0.8), false, 3.0)
		_paper.draw_string(FONT, Vector2(-62, 12), "NOTED", HORIZONTAL_ALIGNMENT_CENTER, 124, 30, Color(STAMP, 0.8))
		_paper.draw_set_transform(Vector2.ZERO)
