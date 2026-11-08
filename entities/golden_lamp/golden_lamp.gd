class_name GoldenLamp
extends Node3D
## A small desk lamp at the back right, there once the "golden_lamp" card is stamped (it drops in).
## About every save.lamp_every seconds it turns gold for save.lamp_time seconds; meanwhile every
## sale pays ×save.lamp_mult (the SaleWindow's "lamp" boost) and the whole desk light warms to
## gold. Through its last FADE_LEFT seconds it dims softly, pulsing slowly (PULSE_HZ), before going out:
## never a fast flicker (photosensitivity: nothing on screen blinks at 3 Hz or more).

const CARD := "golden_lamp"
const GOLD := Color(1.0, 0.78, 0.29)
## The first glow after it arrives (or after loading) comes sooner, so a new lamp shows what it does.
const FIRST_WAIT := 12.0
const FADE_LEFT := 3.0
## The gentle dimming pulse in the last seconds (Hz, well under 3) and how deep it dips.
const PULSE_HZ := 1.2
const PULSE_DEPTH := 0.15
## How dim it gets by the end of the fade (of full).
const FADE_TO := 0.35
const DROP_HEIGHT := 1.2
const DROP_TIME := 0.4
const GLOW_ENERGY := 2.5

## The desk's main light, tinted gold while the lamp glows.
@export var desk_light: Light3D

var glowing := false
var _wait := FIRST_WAIT
var _left := 0.0
var _rest := Vector3.ZERO
var _desk_color := Color.WHITE
var _bulb_material := StandardMaterial3D.new()

@onready var _bulb: MeshInstance3D = $Model.find_child("Bulb", true, false)
@onready var _glow: OmniLight3D = $Glow
@onready var _hint: Interactable = $Hit/Interactable


func _ready() -> void:
	_rest = position
	if desk_light != null:
		_desk_color = desk_light.light_color
	_bulb_material.albedo_color = GOLD
	_bulb_material.emission_enabled = true
	_bulb_material.emission = GOLD
	_bulb_material.emission_energy_multiplier = 0.0
	_bulb.material_override = _bulb_material
	_glow.light_color = GOLD
	visible = SaveManager.save.stamped.has(CARD)
	$Hit/Shape.disabled = not visible  # Hidden before its card: no invisible box eating clicks.
	_light(0.0)


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not visible:
		if save.stamped.has(CARD):
			_arrive()
		return
	_hint.tooltip = hint(save)
	if not glowing:
		_wait -= delta
		if _wait <= 0.0:
			glowing = true
			_left = save.lamp_time
			$On.play()
		return
	_left -= delta
	if _left <= 0.0:
		glowing = false
		_wait = next_wait(save.lamp_every, randf())
		_light(0.0)
		_window_boost(0.0)
		$Off.play()
		return
	$Tag.text = "×%s" % String.num(save.lamp_mult, 1).trim_suffix(".0")
	_light(glow_at(_left, Time.get_ticks_msec() / 1000.0))
	_window_boost(save.lamp_mult)


## Seconds to the next glow: `every` spread over 0.6..1.4 of it by `roll` (0..1).
static func next_wait(every: float, roll: float) -> float:
	return every * (0.6 + 0.8 * roll)


## The hover text: what it does, with today's (upgraded) numbers from `save`.
static func hint(save: SaveGame) -> String:
	return TranslationServer.translate("Desk lamp. About every %d s it glows gold for %d s: while it does, every sale pays %s×.") % [roundi(save.lamp_every), roundi(save.lamp_time), String.num(save.lamp_mult, 1)]


## How bright the lamp is with `left` seconds of glow to go at clock `time`: full, then through the
## last FADE_LEFT seconds dimming to FADE_TO with a slow soft pulse.
static func glow_at(left: float, time: float) -> float:
	if left >= FADE_LEFT:
		return 1.0
	var pulse := 1.0 - PULSE_DEPTH * 0.5 * (1.0 - cos(time * TAU * PULSE_HZ))
	return lerpf(FADE_TO, 1.0, maxf(left, 0.0) / FADE_LEFT) * pulse


func _window_boost(factor: float) -> void:
	var window := get_tree().get_first_node_in_group(&"sale_window") as SaleWindow
	if window == null:
		return
	if factor > 0.0:
		window.boosts["lamp"] = factor
	else:
		window.boosts.erase("lamp")


func _light(amount: float) -> void:
	_bulb_material.emission_energy_multiplier = 6.0 * amount
	_bulb_material.albedo_color = Color(0.78, 0.76, 0.7).lerp(GOLD, amount)
	_glow.light_energy = GLOW_ENERGY * amount
	_glow.visible = amount > 0.0
	if desk_light != null:
		desk_light.light_color = _desk_color.lerp(GOLD, 0.35 * amount)
	$Tag.visible = amount > 0.0
	$Tag.modulate.a = amount


func _arrive() -> void:
	visible = true
	$Hit/Shape.disabled = false
	_wait = FIRST_WAIT
	position = _rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback($Thud.play)
	tween.tween_property($Model, "scale", Vector3(1.08, 0.85, 1.08), 0.05)
	tween.tween_property($Model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
