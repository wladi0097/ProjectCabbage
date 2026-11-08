class_name LightSwitch
extends StaticBody3D
## A small wall-switch: an off-white bakelite plate with a dark toggle that flicks up (on) or down.
## It lies in its own XY plane facing +Z (like a Label3D), so it can sit flat on any face. Clicked,
## it emits `flicked`; the owner flips its setting and calls show_on with the new state. The owner
## sets `tooltip` (what it switches). Instance light_switch.tscn. A pilot lamp over the toggle glows
## amber while on and stays dark while off, so its state reads at a glance.

signal flicked

## How far the toggle tips up (on) or down (off), and how long the flick takes.
const TILT := 0.55
const FLICK_TIME := 0.12
## The pilot lamp's glow while on (off: none).
const LAMP_ON := 2.2

## Shown beside it while hovered (Interactable.tooltip).
@export_multiline var tooltip := ""

@onready var _pivot: Node3D = $Pivot
@onready var _interactable: Interactable = $Interactable
@onready var _lamp: StandardMaterial3D = ($Lamp as MeshInstance3D).material_override


func _ready() -> void:
	_interactable.tooltip = tooltip
	_interactable.grabbed.connect(flicked.emit)


## Shows the toggle up (`on`) or down; `animate` flicks it there, else it is set at once.
func show_on(on: bool, animate := true) -> void:
	var angle := -TILT if on else TILT
	_lamp.emission_energy_multiplier = lamp_glow(on)
	if not animate:
		_pivot.rotation.x = angle
		return
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_pivot, "rotation:x", angle, FLICK_TIME)


## The pilot lamp's emission for a switch that is `on` or off.
static func lamp_glow(on: bool) -> float:
	return LAMP_ON if on else 0.0


## Clickable or not (hidden switches must not catch the hand).
func set_enabled(on: bool) -> void:
	_interactable.enabled = on

