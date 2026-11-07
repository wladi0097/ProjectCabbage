class_name CatchCombo
extends Node3D
## The catch combo, there once the "catch_combo" card is stamped: every cabbage caught in mid-air
## off the chute (Cabbage calls `caught` on the "catch_combo" group) adds a step, and every sale
## pays ×multiplier (the SaleWindow's "combo" boost) while it lasts. save.combo_window seconds
## without a catch and it starts to decay, one step per DECAY_STEP seconds. `streak` counts the
## catches in a row (uncapped) until the combo has decayed to nothing. A miss (a chute unit that
## lands uncaught: Cabbage calls `missed`) ends both the streak and the multiplier at once: the
## multiplier is the reward for the streak, so a broken streak can't keep paying. A miss doesn't count
## while the player can't catch (missed_counts: away at the farm TV, a boss note up, the hand full). A
## price refusal (the SaleWindow's `refused` to `hold`, `thrown_back` to `unhold`, wired in the world)
## pauses the window while the refused unit is out (it blocks the chute), never longer than HOLD_LIMIT. Stencilled
## on the chute bed (the node lies on it) in faded paint (never more than PAINT opaque), popping on
## each catch and fading further as the window runs out.

const CARD := "catch_combo"
const DECAY_STEP := 0.6
const INK := Color(0.86, 0.84, 0.74)
const POP := 1.15
## Stencil paint: the label's opacity fresh after a catch, and how far it fades as the window runs out.
const PAINT := 0.45
const FADED := 0.2
## Seconds a refusal pauses the window at most, so a refused unit never thrown back can't stall it.
const HOLD_LIMIT := 4.0

var steps := 0
var streak := 0
var _idle := 0.0
## Refused units out of the window right now, and how long since the last refusal.
var _holds := 0
var _held_for := 0.0
var _pop := 0.0

@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group(&"catch_combo")
	_label.visible = false


func _process(delta: float) -> void:
	var save := SaveManager.save
	if steps == 0:
		return
	if _holds > 0:
		_held_for += delta
		if _held_for > HOLD_LIMIT:
			_holds = 0
	else:
		_idle += delta
	var left := save.combo_window - _idle
	if left < 0.0:
		steps -= 1
		_idle -= DECAY_STEP
		$Tick.pitch_scale = 0.7
		$Tick.cue($Tick.global_position, 0.5)
		if steps == 0:
			streak = 0
	_pop = maxf(0.0, _pop - delta * 4.0)
	_show(save)


## A mid-air catch at `_at`.
func caught(_at: Vector3) -> void:
	var save := SaveManager.save
	if not save.stamped.has(CARD):
		return
	if multiplier(steps + 1, save.combo_step, save.combo_cap) > multiplier(steps, save.combo_step, save.combo_cap):
		steps += 1
	streak += 1
	_idle = 0.0
	_pop = 1.0
	$Tick.pitch_scale = 1.0 + 0.06 * steps
	$Tick.cue($Tick.global_position)
	_show(save)


## A chute unit landed uncaught: the streak and its multiplier are gone.
func missed() -> void:
	if steps == 0 or not missed_counts(FarmTv.away, BossReport.up, Hand.held != null):
		return
	steps = 0
	streak = 0
	_idle = 0.0
	_pop = 0.0
	_show(SaveManager.save)


## Whether a unit landing uncaught breaks the streak: not while the camera is `at_tv`, a boss note
## is `note_up` or the hand is `holding` something (the player couldn't have caught it).
static func missed_counts(at_tv: bool, note_up: bool, holding: bool) -> bool:
	return not (at_tv or note_up or holding)


## A price refusal: the window pauses while the refused unit is out.
func hold() -> void:
	_holds += 1
	_held_for = 0.0


## A refused unit thrown back in: the window runs again once none are out.
func unhold() -> void:
	_holds = maxi(_holds - 1, 0)


## The sale multiplier at `count` steps of `step` each, capped at `cap`.
static func multiplier(count: int, step: float, cap: float) -> float:
	return minf(1.0 + count * step, maxf(cap, 1.0))


func _show(save: SaveGame) -> void:
	var factor := multiplier(steps, save.combo_step, save.combo_cap)
	var window := get_tree().get_first_node_in_group(&"sale_window") as SaleWindow
	if window != null:
		if steps > 0:
			window.boosts["combo"] = factor
		else:
			window.boosts.erase("combo")
	_label.visible = steps > 0
	if steps == 0:
		return
	var capped := factor >= save.combo_cap
	_label.text = tr("INTERCEPTS %d") % streak + "\n×%s%s" % [String.num(factor, 2), "  MAX" if capped else ""]
	var fresh := clampf(1.0 - _idle / maxf(save.combo_window, 0.1), 0.0, 1.0)
	_label.modulate = Color(INK, lerpf(FADED, PAINT, fresh))
	_label.scale = Vector3.ONE * (1.0 + (POP - 1.0) * _pop)
