class_name WindowTargets
extends Node3D
## Window targets, there once the "window_targets" card is stamped. About every save.target_every
## seconds a work lamp lights one of the three crates in the street behind the window gap for LIT_TIME
## seconds. A sale that goes out through the gap within its x span lands in it: the street
## throws save.target_shower times that sale's coins back on top, the bell rings and the lamp goes
## out. The span is WIDTH × save.target_size wide, centred on the lit crate.

const CARD := "window_targets"
const Events := preload("res://globalScripts/game_events.gd")
## The street crates' centres (x) and width: the CRATES in room_geo.py (0.6 m × CS 0.8), all in the
## sell span right of the QA bay.
const CRATE_X: Array[float] = [0.60, 1.11, 1.62]
const WIDTH := 0.48
const LIT_TIME := 15.0
## The first target after it arrives (or after loading) comes sooner.
const FIRST_WAIT := 15.0
## The lamp blinks through its last BLINK_LEFT seconds.
const BLINK_LEFT := 3.0
## Shower coins come in this long after the sale's own coins.
const SHOWER_DELAY := 0.75
const GLOW_ENERGY := 14.0
const SPILL_ENERGY := 4.0
const PULSE := 1.5

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
	if not shines(save) or _window == null:
		if lit:
			_go_out(save)  # The ending has begun: the target goes dark mid-glow.
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


## Whether targets light up on the window: once the card is stamped, until the ending (the gun card).
static func shines(save: SaveGame) -> bool:
	return save.stamped.has(CARD) and not Events.chapter_5(save)


## Seconds to the next target: `every` spread over 0.6..1.4 of it by `roll` (0..1).
static func next_wait(every: float, roll: float) -> float:
	return every * (0.6 + 0.8 * roll)


## The centre of the crate a `roll` (0..1) lights.
static func pick_centre(roll: float) -> float:
	return CRATE_X[mini(floori(roll * CRATE_X.size()), CRATE_X.size() - 1)]


## A sale out through the gap at `x` lands in the target centred on `at`, `width` wide.
static func hits(x: float, at: float, width: float) -> bool:
	return absf(x - at) <= width / 2.0


func _light_up(save: SaveGame) -> void:
	centre = pick_centre(randf())
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
