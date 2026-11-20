class_name Telescope
extends Node3D
## The survey telescope (desk card TELESCOPE, chapter 4): its room end clamped under the raised
## sash's meeting rail, the barrel running out through the open gap toward the street, the eyepiece
## end dipped toward the desk. Absent until the card is stamped; then the clamp comes down onto the
## rail and the barrel slides in through it. Hovered, the barrel nods and turns a touch and the lens
## catches the light; clicked, it opens the telescope's view (TelescopeView, still empty: chapter 4
## goes on from here later). The world scene places it on the rail.

const CARD := "telescope"
const DROP_HEIGHT := 0.4
const DROP_TIME := 0.4
## The barrel arrives pushed this far back out of the window (m, along its axis) and slides in.
const SLIDE := 0.3
const SLIDE_TIME := 0.7
## Hovered: the barrel nods (rad, room end down), swivels (rad) and the lens glints (emission energy).
const HOVER_NOD := 0.05
const HOVER_TURN := 0.08
const HOVER_TIME := 0.25
const LENS_IDLE := 0.15
const LENS_GLINT := 1.4

var _tween: Tween
var _hover: Tween

@onready var _tube: Node3D = $Tube
@onready var _rest := position
@onready var _tube_rest := _tube.position
@onready var _tube_turn := _tube.rotation
@onready var _lens: StandardMaterial3D = $Tube/Lens.get_surface_override_material(0)
@onready var _land_sound: AudioStreamPlayer3D = $Land
@onready var _view: TelescopeView = $View/View


func _ready() -> void:
	var hit: Interactable = $Tube/Hit/Interactable
	hit.hovered.connect(_hovered.bind(true))
	hit.unhovered.connect(_hovered.bind(false))
	hit.grabbed.connect(look)
	visible = bought(SaveManager.save)


func _process(_delta: float) -> void:
	if not visible and bought(SaveManager.save):
		_arrive()


static func bought(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## Opens the telescope's view: only once the card is stamped.
func look() -> void:
	if not bought(SaveManager.save):
		return
	$Click.play()
	_hovered(false)
	_view.open()


func is_looking() -> bool:
	return _view.visible


func _arrive() -> void:
	visible = true
	position = _rest + Vector3.UP * DROP_HEIGHT
	_tube.position = _tube_rest + _tube.basis.z * -SLIDE
	_land_sound.play()
	_tween = create_tween()
	_tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_tube, "position", _tube_rest, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hovered(on: bool) -> void:
	if on:
		$Hover.play()
	if _hover != null:
		_hover.kill()
	var k := 1.0 if on else 0.0
	_hover = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover.tween_property(_tube, "rotation", _tube_turn + Vector3(HOVER_NOD, HOVER_TURN, 0.0) * k, HOVER_TIME)
	_hover.tween_property(_lens, "emission_energy_multiplier", lerpf(LENS_IDLE, LENS_GLINT, k), HOVER_TIME)
