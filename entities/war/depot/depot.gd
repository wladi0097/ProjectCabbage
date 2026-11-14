class_name Depot
extends Node3D
## The PERSONNEL DEPOT on the map table, right of the sheet (depot_model.tscn: the hut, its shutter,
## its lamp; no light of its own). It is the war card's doing (WAR_CARD): not on the table
## before, then it drops in from above with a thud and a puff of dust the first time the camera is
## at the map (drop, save.depot_dropped; a loaded save that saw it land has it there already).
## The mouse on it (MapTable.pick: hit) lifts it a little and rattles its shutter up (hover); a
## click rolls out the depot sheet (DepotSheet). Sounds: Drop as it starts to fall (its thud lands
## DROP_TIME in), Rattle as the hover rattles the shutter up.

## The desk card that brings the depot (and the field associates).
const WAR_CARD := "war_mode"
## The unit types the depot deals in today, in its column order (a subset of WarRules.UNITS; more
## types join this list as they are designed). Each is shown once its card is stamped.
const IN_SERVICE: Array[String] = ["field_associate"]
## The drop: it waits DROP_AFTER s once the camera is there, falls DROP_FROM m in DROP_TIME s,
## squashes and settles.
const DROP_AFTER := 0.5
const DROP_FROM := 1.2
const DROP_TIME := 0.42
const SQUASH := Vector3(1.12, 0.78, 1.12)
const SETTLE_TIME := 0.35
## Hovered, it lifts this far (m) and its shutter goes up this far (m), with a rattle on the way.
const HOVER_LIFT := 0.025
const SHUTTER_UP := 0.012
const RATTLE := 0.002
const HOVER_TIME := 0.14

## The click box (the model's Body3D shape), in the depot's own space.
@onready var _box: AABB = _shape_box()
@onready var _shutter: Node3D = $Shutter
@onready var _shutter_rest := _shutter.position
@onready var _drop_sound: SoundCue = $Drop
@onready var _rattle_sound: SoundCue = $Rattle
@onready var _dust: CPUParticles3D = $Dust
@onready var _rest := position

var _hover_tween: Tween
var _drop_tween: Tween


## Whether the depot belongs on the table for `save`: the war card is stamped.
static func unlocked(save: SaveGame) -> bool:
	return save.stamped.has(WAR_CARD)


## Whether the depot is still to drop in for `save`: unlocked, and its first drop has not played.
static func drops(save: SaveGame) -> bool:
	return unlocked(save) and not save.depot_dropped


## The unit types the depot shows and declarations take for `save`: those IN_SERVICE whose card is stamped.
static func units(save: SaveGame) -> Array[String]:
	var out: Array[String] = []
	for unit in IN_SERVICE:
		if WarRules.unit_unlocked(save, unit):
			out.append(unit)
	return out


## Whether the depot stands on the table as `save` has it (unlocked and landed, or landing).
static func standing(save: SaveGame) -> bool:
	return unlocked(save) and save.depot_dropped


## Whether a ray (the mouse at the map) is on the depot.
func hit(from: Vector3, dir: Vector3) -> bool:
	if not visible or _drop_tween != null:
		return false
	var inv := global_transform.affine_inverse()
	return _box.intersects_ray(inv * from, inv.basis * dir) != null


## The depot drops in: from DROP_FROM above its place, a thud and dust as it lands. Its first drop
## counts as played from here on (save.depot_dropped).
func drop() -> void:
	SaveManager.save.depot_dropped = true
	position = _rest + Vector3.UP * DROP_FROM
	_drop_tween = create_tween()
	_drop_tween.tween_interval(DROP_AFTER)
	_drop_tween.tween_callback(func() -> void:
		show()
		_drop_sound.cue(global_position))
	_drop_tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_tween.tween_callback(_landed)
	_drop_tween.tween_property(self, "scale", Vector3.ONE, SETTLE_TIME).from(SQUASH) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_drop_tween.finished.connect(func() -> void: _drop_tween = null)


## Whether its drop is playing now.
func dropping() -> bool:
	return _drop_tween != null


## The mouse is on it (`on`) or has left: it lifts and its shutter rattles up, or both settle.
func hover(on: bool) -> void:
	if _drop_tween != null:
		return
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "position", _rest + Vector3.UP * (HOVER_LIFT if on else 0.0), HOVER_TIME)
	var up := _shutter_rest + Vector3.UP * SHUTTER_UP
	if not on:
		_hover_tween.parallel().tween_property(_shutter, "position", _shutter_rest, HOVER_TIME)
		return
	# The shutter catches twice on its way up, rattling in its rails.
	_rattle_sound.cue(global_position)
	_hover_tween.chain()
	for k: float in [0.4, 0.3, 0.8, 0.65, 1.0]:
		_hover_tween.tween_property(_shutter, "position", _shutter_rest.lerp(up, k) + Vector3.FORWARD * RATTLE * (1.0 - k), HOVER_TIME / 4.0)


func _landed() -> void:
	_dust.restart()


func _shape_box() -> AABB:
	var shape := $Body3D/Shape as CollisionShape3D
	var size := (shape.shape as BoxShape3D).size
	return AABB(shape.position - size / 2.0, size)
