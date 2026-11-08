class_name CatchCombo
extends Node3D
## The catch combo, there once the "catch_combo" card is stamped: every cabbage caught in mid-air
## off the chute (Cabbage calls `caught` on the "catch_combo" group) adds a step, and every sale
## pays ×multiplier (the SaleWindow's "combo" boost). There is no timer: the combo lasts until a
## miss (a chute unit that lands uncaught: Cabbage calls `missed`), which ends the streak and keeps
## only save.miss_keep of the steps (none until the GRACE PERIOD node). `streak` counts the catches
## in a row since the last miss. A miss doesn't count while the player can't catch (missed_counts:
## away at the farm TV, a boss note up, the hand full). Stencilled on the chute bed (the node lies
## on it), drawn over the units and always shown once the card is stamped (×1.00 at no combo),
## popping on each catch; the ×multiplier is its big line. Its size and paint live in the scene.

const CARD := "catch_combo"
const POP := 1.15
## Every COMBO_EVERY catches in a row the combo sting plays ($Combo), pitched up COMBO_PITCH per
## milestone so far, up to COMBO_PITCH_MAX.
const COMBO_EVERY := 5
const COMBO_PITCH := 0.05
const COMBO_PITCH_MAX := 1.3

var steps := 0
var streak := 0
var _pop := 0.0

@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group(&"catch_combo")
	_label.visible = false
	_show(SaveManager.save)


func _process(delta: float) -> void:
	var save := SaveManager.save
	_label.visible = save.stamped.has(CARD)
	if _pop > 0.0:
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
	_pop = 1.0
	$Tick.pitch_scale = 1.0 + 0.06 * steps
	$Tick.cue($Tick.global_position)
	if milestone(streak):
		$Combo.pitch_scale = sting_pitch(streak)
		$Combo.play()
	_show(save)


## Whether a streak of `count` catches in a row earns the combo sting (5, 10, 15...).
static func milestone(count: int) -> bool:
	return count > 0 and count % COMBO_EVERY == 0


## The sting's pitch at a streak of `count`: a little higher each milestone, up to COMBO_PITCH_MAX.
static func sting_pitch(count: int) -> float:
	@warning_ignore("integer_division")
	return minf(1.0 + COMBO_PITCH * (count / COMBO_EVERY - 1), COMBO_PITCH_MAX)


## A chute unit landed uncaught: the streak is gone, and the multiplier down to what miss_keep keeps.
func missed() -> void:
	if (steps == 0 and streak == 0) or not missed_counts(FarmTv.away, BossReport.up, Hand.held != null):
		return
	var save := SaveManager.save
	steps = kept_steps(steps, save.miss_keep)
	streak = 0
	_pop = 0.0
	_show(save)


## The steps left after a miss at `count` steps, keeping `keep` (0..1) of them, rounded down.
static func kept_steps(count: int, keep: float) -> int:
	return floori(count * clampf(keep, 0.0, 1.0))


## Whether a unit landing uncaught breaks the streak: not while the camera is `at_tv`, a boss note
## is `note_up` or the hand is `holding` something (the player couldn't have caught it).
static func missed_counts(at_tv: bool, note_up: bool, holding: bool) -> bool:
	return not (at_tv or note_up or holding)


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
	var capped := steps > 0 and factor >= save.combo_cap
	_label.text = "×%.2f%s\n" % [factor, "  MAX" if capped else ""] + tr("INTERCEPTS %d") % streak
	_label.scale = Vector3.ONE * (1.0 + (POP - 1.0) * _pop)
