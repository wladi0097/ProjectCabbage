class_name CatchCombo
extends Node3D
## The catch combo, there once the "catch_combo" card is stamped: every cabbage caught in mid-air
## off the chute (Cabbage calls `caught` on the "catch_combo" group) adds a step, and every sale
## pays ×multiplier (the SaleWindow's "combo" boost) while it lasts. save.combo_window seconds
## without a catch and it starts to decay, one step per DECAY_STEP seconds. `streak` counts the
## catches in a row (uncapped) until the combo has decayed to nothing. A price refusal (the
## SaleWindow's `refused` and `thrown_back`, wired in the world to `hold`) restarts the window: the
## refused unit blocks the chute while it is out, so that wait never breaks the streak. Stencilled
## on the chute bed (the node lies on it), popping on each catch and fading as the window runs out.

const CARD := "catch_combo"
const DECAY_STEP := 0.6
const INK := Color(0.86, 0.84, 0.74)
const POP := 1.15

var steps := 0
var streak := 0
var _idle := 0.0
var _pop := 0.0

@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group(&"catch_combo")
	_label.visible = false


func _process(delta: float) -> void:
	var save := SaveManager.save
	if steps == 0:
		return
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


## A price refusal: the time the refused unit holds up the chute doesn't count against the window.
func hold() -> void:
	_idle = 0.0


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
	_label.modulate = Color(INK, 0.35 + 0.65 * fresh)
	_label.scale = Vector3.ONE * (1.0 + (POP - 1.0) * _pop)
