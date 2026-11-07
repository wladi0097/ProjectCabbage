class_name LightSwitch
extends StaticBody3D
## A small wall-switch: an off-white bakelite plate with a dark toggle that flicks up (on) or down.
## It lies in its own XY plane facing +Z (like a Label3D), so it can sit flat on any face. Clicked,
## it emits `flicked`; the owner flips its setting and calls show_on with the new state. The owner
## sets `tooltip` (what it switches) before adding it.

signal flicked

const PLATE := Vector3(0.036, 0.05, 0.006)
const BAT := Vector3(0.012, 0.02, 0.014)
## How far the toggle tips up (on) or down (off), and how long the flick takes.
const TILT := 0.55
const FLICK_TIME := 0.12
const PLATE_COLOR := Color(0.58, 0.57, 0.5)
const BAT_COLOR := Color(0.16, 0.16, 0.15)

## Shown beside it while hovered (Interactable.tooltip).
var tooltip := ""
var _pivot := Node3D.new()
var _interactable := Interactable.new()


func _ready() -> void:
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PLATE
	plate.mesh = box
	plate.material_override = _bakelite(PLATE_COLOR)
	add_child(plate)
	_pivot.position.z = PLATE.z * 0.5
	add_child(_pivot)
	var bat := MeshInstance3D.new()
	var stick := BoxMesh.new()
	stick.size = BAT
	bat.mesh = stick
	bat.material_override = _bakelite(BAT_COLOR)
	bat.position.z = BAT.z * 0.5
	_pivot.add_child(bat)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = PLATE + Vector3(0.01, 0.01, BAT.z)
	shape.shape = hit
	add_child(shape)
	_interactable.pressable = true
	_interactable.grip_height = 0.02
	_interactable.tooltip = tooltip
	add_child(_interactable)
	_interactable.grabbed.connect(flicked.emit)


## Shows the toggle up (`on`) or down; `animate` flicks it there, else it is set at once.
func show_on(on: bool, animate := true) -> void:
	var angle := -TILT if on else TILT
	if not animate:
		_pivot.rotation.x = angle
		return
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_pivot, "rotation:x", angle, FLICK_TIME)


## Clickable or not (hidden switches must not catch the hand).
func set_enabled(on: bool) -> void:
	_interactable.enabled = on


static func _bakelite(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	return mat
