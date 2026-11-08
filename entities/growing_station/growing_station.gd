class_name GrowingStation
extends Node3D
## The mini growing station (desk card mini_station): a low steel collar round the tube's intake
## well (kept low so it hides nothing behind it). Every tube mini falls through it; out of sight
## below, one in about twenty (save.mini_grow_chance, raised on the projector) comes out a full-size
## unit (Cabbage.grow): no stock, the full price, counted as sold. MiniDrop rolls it (grows) and
## calls pulse: the collar's band glows a cold blue and slowly fades, a clunk. Absent before the
## card; then it drops onto the intake. Lives under MiniDrop's Tube, so it is only drawn with the tube.

const DROP := 0.9
const DROP_TIME := 0.45
## The glow rises in GLOW_RISE, then fades out over GLOW_FADE: calm, never a blink.
const GLOW_RISE := 0.3
const GLOW_FADE := 1.6
const GLOW := 0.9

var _tween: Tween

@onready var _glow: StandardMaterial3D = ($Model/Glow as MeshInstance3D).material_override
@onready var _rest := position


## Whether a mini passing the station grows, for a random `roll` in 0..1: only with the card stamped,
## with save.mini_grow_chance.
static func grows(save: SaveGame, roll: float) -> bool:
	return save.stamped.has("mini_station") and roll < save.mini_grow_chance


func _ready() -> void:
	visible = SaveManager.save.stamped.has("mini_station")


func _process(_delta: float) -> void:
	if not visible and SaveManager.save.stamped.has("mini_station"):
		_deliver()


func _deliver() -> void:
	visible = true
	position = _rest + Vector3.UP * DROP
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Thud.cue(global_position))


## A mini grew inside: the collar glows cold blue for a moment and fades back.
func pulse() -> void:
	$Clunk.cue(global_position)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_glow, "emission_energy_multiplier", GLOW, GLOW_RISE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_glow, "emission_energy_multiplier", 0.0, GLOW_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
