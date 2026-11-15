class_name GoldenLamp
extends Node3D
## A small desk lamp at the back right, there once the "golden_lamp" card is stamped (it drops in).
## About every save.lamp_every seconds it turns gold for save.lamp_time seconds; meanwhile every
## sale pays ×save.lamp_mult (the SaleWindow's "lamp" boost; a golden unit only with the projector's
## GOLD STANDARD, SaleWindow.boosts_for) and the whole desk light warms to
## gold. Through its last FADE_LEFT seconds it dims softly, pulsing slowly (PULSE_HZ), before going out:
## never a fast flicker (photosensitivity: nothing on screen blinks at 3 Hz or more).
## The research light (research_light.tscn, card "research_light") is the same script with other
## exports: its own save numbers (`stats`: lab_lamp_mult, _time, _every), a cold cyan, the lab's
## boost (QaBay.boosts, "lab_lamp": every Findings token ×lab_lamp_mult, a golden unit only with the
## projector's LAB_GOLD) and its rings (Spin* nodes) turning slowly, a little faster while it glows.

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
## The golden lamp's hover text; the research light's is its `hint_text` export.
const GOLD_HINT := "Golden Age lamp. About every %d s a Golden Age dawns for %d s: while it lasts, every sale pays %s×."
## How much faster the Spin* nodes turn while it glows.
const SPIN_GLOWING := 2.5

@export var card := CARD
## The save numbers it reads: <stats>_mult, <stats>_time, <stats>_every.
@export var stats := "lamp"
@export var color := GOLD
## The glow meshes' colour while dark.
@export var dark_color := Color(0.78, 0.76, 0.7)
## The node group holding what it boosts (SaleWindow or QaBay: both keep a `boosts` dictionary) and
## its key there.
@export var boost_group := &"sale_window"
@export var boost_key := "lamp"
@export_multiline var hint_text := GOLD_HINT
## The projector node that lets golden cabbages share the boost (until then the hint says so).
@export var gold_node := "gold_age"
## How far its Spin* nodes turn a second while dark (radians; alternate ones turn the other way).
@export var spin_speed := 0.0
## How far the desk light is tinted towards `color` at full glow.
@export var desk_tint := 0.35
## How bright the glow meshes and the Glow light get at full glow.
@export var bulb_energy := 6.0
@export var light_energy := GLOW_ENERGY
## How much of `color` the glow meshes' albedo takes when lit (less: the colour comes from the
## emission alone and stays saturated under the desk lamp).
@export var albedo_share := 1.0

## The desk's main light, tinted gold while the lamp glows.
@export var desk_light: Light3D

var glowing := false
var _wait := FIRST_WAIT
var _left := 0.0
var _rest := Vector3.ZERO
var _desk_color := Color.WHITE
var _bulb_material := StandardMaterial3D.new()

@onready var _bulbs: Array[Node] = $Model.find_children("Bulb*", "MeshInstance3D", true, false)
@onready var _spinners: Array[Node] = $Model.find_children("Spin*", "Node3D", true, false)
@onready var _glow: OmniLight3D = $Glow
@onready var _hint: Interactable = $Hit/Interactable


func _ready() -> void:
	_rest = position
	if desk_light != null:
		_desk_color = desk_light.light_color
	_bulb_material.albedo_color = color
	_bulb_material.emission_enabled = true
	_bulb_material.emission = color
	_bulb_material.emission_energy_multiplier = 0.0
	for bulb: MeshInstance3D in _bulbs:
		bulb.material_override = _bulb_material
	_glow.light_color = color
	$Tag.modulate = color
	visible = SaveManager.save.stamped.has(card)
	$Hit/Shape.disabled = not visible  # Hidden before its card: no invisible box eating clicks.
	_light(0.0)


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not visible:
		if save.stamped.has(card):
			_arrive()
		return
	_hint.tooltip = hint(save, stats, hint_text, gold_node)
	_spin(delta)
	if not glowing:
		_wait -= delta
		if _wait <= 0.0:
			glowing = true
			_left = save.get(stats + "_time")
			$On.play()
		return
	_left -= delta
	if _left <= 0.0:
		glowing = false
		_wait = next_wait(save.get(stats + "_every"), randf())
		_light(0.0)
		_window_boost(0.0)
		$Off.play()
		return
	var mult: float = save.get(stats + "_mult")
	$Tag.text = "×%s" % String.num(mult, 1).trim_suffix(".0")
	_light(glow_at(_left, Time.get_ticks_msec() / 1000.0))
	_window_boost(mult)


## Seconds to the next glow: `every` spread over 0.6..1.4 of it by `roll` (0..1).
static func next_wait(every: float, roll: float) -> float:
	return every * (0.6 + 0.8 * roll)


## The hover text `format` (every, time, mult) with today's (upgraded) numbers from `save` (the
## <prefix>_* numbers), and that golden units are left out until the projector node `gold` is bought
## (GOLD STANDARD for the lamp, SaleWindow.boosts_for; QaBay.LAB_GOLD for the research light).
static func hint(save: SaveGame, prefix := "lamp", format := GOLD_HINT, gold := SaleWindow.GOLD_AGE) -> String:
	var text := TranslationServer.translate(format) % [roundi(save.get(prefix + "_every")), roundi(save.get(prefix + "_time")), String.num(save.get(prefix + "_mult"), 1).trim_suffix(".0")]
	if not save.tree_bought.has(gold):
		text += " " + TranslationServer.translate("Golden cabbages excluded.")
	return text


## Turns the Spin* nodes (the research light's rings) about the vertical: slowly, faster while it
## glows, alternate ones the other way. A steady turn, never a blink.
func _spin(delta: float) -> void:
	var speed := spin_speed * (SPIN_GLOWING if glowing else 1.0)
	for i in _spinners.size():
		(_spinners[i] as Node3D).rotate_y(speed * delta * (1.0 + 0.35 * i) * (1.0 if i % 2 == 0 else -1.0))


## How bright the lamp is with `left` seconds of glow to go at clock `time`: full, then through the
## last FADE_LEFT seconds dimming to FADE_TO with a slow soft pulse.
static func glow_at(left: float, time: float) -> float:
	if left >= FADE_LEFT:
		return 1.0
	var pulse := 1.0 - PULSE_DEPTH * 0.5 * (1.0 - cos(time * TAU * PULSE_HZ))
	return lerpf(FADE_TO, 1.0, maxf(left, 0.0) / FADE_LEFT) * pulse


## The desk light's colour: `base` lerped towards each tint's colour by its alpha, in turn.
static func tinted(base: Color, tints: Array) -> Color:
	var out := base
	for tint: Color in tints:
		out = out.lerp(Color(tint, 1.0), tint.a)
	return out


func _window_boost(factor: float) -> void:
	var target := get_tree().get_first_node_in_group(boost_group)
	if target == null:
		return
	if factor > 0.0:
		target.boosts[boost_key] = factor
	else:
		target.boosts.erase(boost_key)


func _light(amount: float) -> void:
	_bulb_material.emission_energy_multiplier = bulb_energy * amount
	_bulb_material.albedo_color = dark_color.lerp(color * albedo_share, amount)
	_glow.light_energy = light_energy * amount
	_glow.visible = amount > 0.0
	if desk_light != null:
		# Both lamps can glow at once: each keeps its own tint on the light (meta), mixed in turn.
		var tints: Dictionary = desk_light.get_meta(&"lamp_tints", {})
		tints[boost_key] = color * Color(1, 1, 1, desk_tint * amount)
		desk_light.set_meta(&"lamp_tints", tints)
		desk_light.light_color = tinted(_desk_color, tints.values())
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
