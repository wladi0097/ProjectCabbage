class_name CogSwitch
extends StaticBody3D
## A setting's switch: a chunky steel cog on a short post over a small enamel plate, tilted 45° toward
## the camera so its teeth read from above. It lies in its own XY plane facing +Z (like a Label3D),
## so it can sit flat on any face. Hovered, the cog lifts a little and turns steadily (easing in, and
## out again once the hand leaves); clicked, it gives a brisk quarter turn and emits `flicked`. The
## owner flips its setting and calls show_on with the new state. The owner sets `tooltip` (what it
## switches). Instance cog_switch.tscn. An amber lamp in the cog's hub glows while on and stays
## dark while off, so its state reads at a glance.

signal flicked

## Hovered, the cog's turning speed (rad/s) and how fast it eases toward it or back to rest (1/s).
const SPIN_SPEED := 2.4
const SPIN_EASE := 5.0
## Hovered, how far the cog lifts along the plate's normal.
const LIFT := 0.005
## A click's quarter turn and how long it takes.
const KICK := PI / 2.0
const FLICK_TIME := 0.16
## The lamp's glow while on (off: none).
const LAMP_ON := 2.6

## Shown beside it while hovered (Interactable.tooltip).
@export_multiline var tooltip := ""

var _hovered := false
var _speed := 0.0
var _lift := 0.0
var _spin := 0.0
var _kick := 0.0
var _kick_to := 0.0
var _kicking: Tween

@onready var _pivot: Node3D = $Pivot
@onready var _cog: Node3D = $Pivot/Cog
@onready var _lamp_node: Node3D = $Lamp
@onready var _interactable: Interactable = $Interactable
@onready var _lamp: StandardMaterial3D = _lamp_node.material_override
@onready var _pivot_rest := _pivot.position
@onready var _lamp_rest := _lamp_node.position


func _ready() -> void:
	_interactable.tooltip = tooltip
	_interactable.grabbed.connect(_click)
	_interactable.hovered.connect(set_hovered.bind(true))
	_interactable.unhovered.connect(set_hovered.bind(false))


func _process(delta: float) -> void:
	_speed = eased_speed(_speed, _hovered, delta)
	_spin = fposmod(_spin + _speed * delta, TAU)
	_cog.rotation.z = _spin + _kick
	_lift = lerpf(_lift, 1.0 if _hovered else 0.0, 1.0 - exp(-12.0 * delta))
	_pivot.position = _pivot_rest + Vector3.BACK * LIFT * _lift
	_lamp_node.position = _lamp_rest + Vector3.BACK * LIFT * _lift


## The cog's turning speed after `delta` seconds, easing toward SPIN_SPEED while `hovered` and back
## to rest when not (a crawl below 1% of full speed stops).
static func eased_speed(speed: float, hovered: bool, delta: float) -> float:
	var target := SPIN_SPEED if hovered else 0.0
	speed = lerpf(speed, target, 1.0 - exp(-SPIN_EASE * delta))
	return 0.0 if not hovered and speed < SPIN_SPEED * 0.01 else speed


## Hovered or left (for an owner whose own hit box covers the switch).
func set_hovered(on: bool) -> void:
	_hovered = on


## A brisk quarter turn of the cog (a click).
func turn() -> void:
	_kick_to += KICK
	if _kicking != null:
		_kicking.kill()
	_kicking = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_kicking.tween_method(func(angle: float) -> void: _kick = angle, _kick, _kick_to, FLICK_TIME)


func _click() -> void:
	turn()
	flicked.emit()


## Lights the hub lamp while `on`. `animate` is kept for the owners; the lamp switches at once.
func show_on(on: bool, _animate := true) -> void:
	_lamp.emission_energy_multiplier = lamp_glow(on)


## The lamp's emission for a switch that is `on` or off.
static func lamp_glow(on: bool) -> float:
	return LAMP_ON if on else 0.0


## Clickable or not (hidden switches must not catch the hand).
func set_enabled(on: bool) -> void:
	_interactable.enabled = on
	if not on:
		_hovered = false
