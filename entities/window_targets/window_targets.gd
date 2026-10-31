class_name WindowTargets
extends Node3D
## Window targets, there once the "window_targets" card is stamped. About every save.target_every
## seconds a work lamp lights one of the crates in the street behind the window gap for LIT_TIME
## seconds. A sale that goes out through the gap within its x span lands in it: the street
## throws save.target_shower times that sale's coins back on top, the bell rings and the lamp goes
## out. The span is WIDTH × save.target_size wide, somewhere in the SaleWindow's sell span.

const CARD := "window_targets"
const WIDTH := 0.32
const LIT_TIME := 15.0
## The first target after it arrives (or after loading) comes sooner.
const FIRST_WAIT := 15.0
## The lamp blinks through its last BLINK_LEFT seconds.
const BLINK_LEFT := 3.0
## Shower coins come in this long after the sale's own coins.
const SHOWER_DELAY := 0.75
const GLOW_ENERGY := 6.0
const SPILL_ENERGY := 3.0
const PULSE := 1.5
## Targets stay this far inside the sell span, clear of the window frame.
const MARGIN := 0.12

var lit := false
## The lit span's centre x.
var centre := 0.0
var _wait := FIRST_WAIT
var _left := 0.0
var _window: SaleWindow

@onready var _glow: Node3D = $Glow


func _ready() -> void:
	_glow.visible = false
	_hook_window.call_deferred()


func _hook_window() -> void:
	_window = get_tree().get_first_node_in_group(&"sale_window") as SaleWindow
	if _window != null:
		_window.sold.connect(_on_sold)


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.stamped.has(CARD) or _window == null:
		return
	if not lit:
		_wait -= delta
		if _wait <= 0.0:
			_light_up(save)
		return
	_left -= delta
	if _left <= 0.0:
		_go_out(save)
		return
	var blink := _left > BLINK_LEFT or fmod(_left, 0.4) > 0.15
	# A slow pulse while lit, so the eye finds it; blinking at the end.
	var pulse := 0.75 + 0.25 * cos(_left * TAU / PULSE)
	$Glow/Light.light_energy = GLOW_ENERGY * pulse if blink else GLOW_ENERGY * 0.25
	$Glow/Spill.light_energy = SPILL_ENERGY * pulse if blink else SPILL_ENERGY * 0.25
	$Glow/Face.visible = blink
	$Glow/Edge.visible = blink


## Seconds to the next target: `every` spread over 0.6..1.4 of it by `roll` (0..1).
static func next_wait(every: float, roll: float) -> float:
	return every * (0.6 + 0.8 * roll)


## A random centre for a `width` wide target inside `span` (x from..to) for `roll` (0..1).
static func pick_centre(span: Vector2, width: float, roll: float) -> float:
	var half := minf(width / 2.0, (span.y - span.x) / 2.0)
	return lerpf(span.x + half, span.y - half, roll)


## A sale out through the gap at `x` lands in the target centred on `at`, `width` wide.
static func hits(x: float, at: float, width: float) -> bool:
	return absf(x - at) <= width / 2.0


func _light_up(save: SaveGame) -> void:
	var width := WIDTH * save.target_size
	var span := _window.sell_span()
	centre = pick_centre(Vector2(span.x + MARGIN, span.y - MARGIN), width, randf())
	lit = true
	_left = LIT_TIME
	_glow.position.x = centre
	_glow.scale.x = save.target_size
	_glow.visible = true
	$Glow/Light.light_energy = GLOW_ENERGY
	$Glow/Face.visible = true
	$Glow/Edge.visible = true
	$On.global_position = _glow.global_position
	$On.play()


func _go_out(save: SaveGame) -> void:
	lit = false
	_glow.visible = false
	_wait = next_wait(save.target_every, randf())


func _on_sold(cabbage: Cabbage, coins: int) -> void:
	var save := SaveManager.save
	var span := _window.sell_span()
	var x := clampf(cabbage.global_position.x, span.x, span.y)
	if not lit or not hits(x, centre, WIDTH * save.target_size):
		return
	_go_out(save)
	$Bell.global_position = _glow.global_position
	$Bell.play()
	var from := Vector3(x, _window.throw_from.y, _window.throw_from.z)
	_window.coins.throw_in_after(SaleWindow.THROW_DELAY + SHOWER_DELAY, from, coins * save.target_shower)
