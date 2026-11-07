class_name FineNotice
extends CanvasLayer
## The fine for selling a rotten unit: a notice of penalty drops onto the left desk and
## fades away after HOLD seconds. It never takes the mouse. A new fine
## replaces the one showing. One sound (Penalty) covers it all: the paper slap as it lands
## (IN_TIME), a thump and a low buzzer after it.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const PAPER := Color(0.72, 0.73, 0.69)
const INK := Color(0.13, 0.15, 0.14)
const SIZE := Vector2(420, 220)
## Where its centre lands, as a fraction of the view (on the left desk, off the mat).
const AT := Vector2(0.15, 0.45)
const IN_TIME := 0.18
const HOLD := 5.0
const OUT_TIME := 0.8

var _t := HOLD + OUT_TIME
var _price := 0
var _owed := 0
var _short := false

@onready var _paper: Control = $Paper


func _ready() -> void:
	_paper.size = SIZE
	_paper.pivot_offset = SIZE / 2.0
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.visible = false
	_paper.draw.connect(_draw_paper)


## Shows a fine: `taken` coins left the tally; the full fine is SaleWindow.FINE times the price.
func show_fine(taken: int) -> void:
	_price = SaveManager.save.sale_price
	_owed = SaleWindow.FINE * _price
	_short = taken < _owed
	_t = 0.0
	_paper.rotation = deg_to_rad(randf_range(-4.0, 2.0))
	_paper.visible = true
	$Penalty.play()


func _process(delta: float) -> void:
	if not _paper.visible:
		return
	_t += delta
	if _t >= HOLD + OUT_TIME:
		_paper.visible = false
		return
	var view := get_viewport().get_visible_rect().size
	_paper.position = view * AT - SIZE / 2.0
	# Dropped onto the desk: from a little bigger down to size, then faded out at the end.
	var land := clampf(_t / IN_TIME, 0.0, 1.0)
	_paper.scale = Vector2.ONE * lerpf(1.25, 1.0, land * land)
	_paper.modulate.a = land * (1.0 - clampf((_t - HOLD) / OUT_TIME, 0.0, 1.0))
	_paper.queue_redraw()


func _draw_paper() -> void:
	var w := SIZE.x
	_paper.draw_rect(Rect2(Vector2(8, 8), SIZE), Color(0, 0, 0, 0.4))
	_paper.draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	_paper.draw_string(FONT, Vector2(24, 44), tr("NOTICE OF PENALTY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	_paper.draw_string(FONT, Vector2(24, 44), "FORM 11-R", HORIZONTAL_ALIGNMENT_RIGHT, w - 48, 13, Color(INK, 0.6))
	_paper.draw_line(Vector2(24, 56), Vector2(w - 24, 56), INK, 2.0)
	_paper.draw_string(FONT, Vector2(24, 80), tr("RE: UNIT UNFIT FOR SALE"), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 15, Color(INK, 0.8))
	_paper.draw_string(FONT, Vector2(24, 112), tr("A rotten unit was offered to the public."), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 19, INK)
	_paper.draw_string(FONT, Vector2(24, 142), tr("Penalty: %d × $%d = $%d") % [SaleWindow.FINE, _price, _owed],
			HORIZONTAL_ALIGNMENT_LEFT, w - 48, 19, INK)
	var line := tr("Tally insufficient. Balance set to zero.") if _short else tr("Deducted from your tally.")
	_paper.draw_string(FONT, Vector2(24, 170), line, HORIZONTAL_ALIGNMENT_LEFT, w - 48, 17, Color(INK, 0.85))
	_paper.draw_string(FONT, Vector2(24, 202), tr("Rotten units are to be disposed of, not sold."), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 13, Color(INK, 0.55))
