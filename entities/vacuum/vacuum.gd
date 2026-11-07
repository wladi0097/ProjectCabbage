class_name CoinVacuums
extends Node3D
## The coin collector (desk card coin_collector): small grey robot pucks that roam the mat and suck
## up the resting coin stacks. This node is the dock on the mat's left edge; it slides in once the
## card is stamped and parks save.vacuums units, each backed into its own charging dock (the first
## is this node's, every further one a copy ROW_STEP along the mat edge). A unit drives (slowly:
## BASE_SPEED × save.vacuum_speed) to the nearest stack,
## takes up to save.vacuum_capacity coins within save.vacuum_reach as it goes, and when the bag is
## full or the mat is clean drives home, beeps and empties: the coins fly from it to the tally.
## Its lamp glows while out and blinks when full. The bodies are kinematic, so they nudge cabbages
## aside. All the money logic is in CoinPile (vacuum_at, bank_from); coins in a bag still count in
## pending_value. Once TOKEN_CARD is stamped they also take the QA bay's resting report slips (one
## per bag slot) and, home, the slips fly from them into the Findings counter (QaBay.file_from).

enum State { PARKED, ROAM, RETURN }

const BODY := preload("res://entities/vacuum/vacuum_body.tscn")
## Metres per second and radians per second at vacuum_speed 1. Slow on purpose.
const BASE_SPEED := 0.1
const TURN_SPEED := 2.2
## It only drives forward while facing within this angle of its goal.
const FACING := 0.7
## Close enough to a goal (m).
const ARRIVE := 0.02
## Seconds parked after emptying before it goes out again, and between goal re-picks while out.
const REST := 1.5
const REPICK := 0.6
## Seconds between rescans of the mat for resting stacks.
const RESCAN := 0.25
## Each further unit parks this far along the mat edge from the last (dock-local x).
const ROW_STEP := 0.27
## Where the units may drive: the open mat, clear of the press, the ramp and the window sill.
const AREA := Rect2(-0.3, -0.6, 1.65, 1.25)
const LAMP_ON := 3.0
const RADIUS := 0.11
const HEIGHT := 0.07
const SLIDE_FROM := Vector3(0.0, 0.8, 0.0)
const SLIDE_TIME := 0.4
const TOKEN_CARD := "token_recovery"

@export var coins: CoinPile


class Unit:
	var body: AnimatableBody3D
	var brush: Node3D
	var lamp: StandardMaterial3D
	## Its parking spot, in the dock's space.
	var home: Transform3D
	## Its dock's lamp, glowing while it rests there.
	var dock_lamp: StandardMaterial3D
	var state := State.PARKED
	var goal := Vector3.ZERO
	var loaded := 0
	var value := 0
	## QA report slips in the bag (token_recovery), filed when it empties.
	var slips: Array[Node3D] = []
	var wait := 0.0


var _units: Array[Unit] = []
var _time := 0.0
## The resting stacks the units can reach, refreshed every RESCAN (and right after a unit takes coins).
var _spots: Array[Vector3] = []
var _rescan := 0.0
## The QA bay, found on the first _bay call.
var _qa: QaBay

@onready var _rest := position


func _ready() -> void:
	visible = unlocked(SaveManager.save)


func _physics_process(delta: float) -> void:
	var save := SaveManager.save
	if not visible:
		if unlocked(save):
			_arrive()
		return
	while _units.size() < save.vacuums:
		_add_unit()
	_time += delta
	_rescan -= delta
	if _rescan <= 0.0:
		_rescan = RESCAN
		# Only the stacks a unit can get close enough to (inside AREA, give or take its reach).
		var reach := AREA.grow(save.vacuum_reach * 0.9)
		_spots.clear()
		var bay := _bay(save)
		for spot in coins.resting_spots() + (bay.resting_spots() if bay != null else [] as Array[Vector3]):
			if reach.has_point(Vector2(spot.x, spot.z)):
				_spots.append(spot)
	for unit in _units:
		_drive(unit, _spots, save, delta)
		unit.dock_lamp.emission_energy_multiplier = LAMP_ON * 0.5 if unit.state == State.PARKED and unit.wait > 0.0 else 0.0


## The QA bay, when the units may take its slips (TOKEN_CARD stamped); else null.
func _bay(save: SaveGame) -> QaBay:
	if not save.stamped.has(TOKEN_CARD):
		return null
	if _qa == null:
		_qa = get_tree().get_first_node_in_group(&"qa_bay") as QaBay
	return _qa


static func unlocked(save: SaveGame) -> bool:
	return save.stamped.has("coin_collector") and save.vacuums > 0


## The spot in `spots` nearest to `from`, skipping any within `taken_reach` of a spot in `taken`;
## null when there is none.
static func nearest(spots: Array[Vector3], from: Vector3, taken: Array[Vector3] = [], taken_reach := 0.1) -> Variant:
	var best: Variant = null
	for spot in spots:
		var free := true
		for other in taken:
			if other.distance_to(spot) < taken_reach:
				free = false
				break
		if not free:
			continue
		if best == null or from.distance_to(spot) < from.distance_to(best):
			best = spot
	return best


## Turns `yaw` toward the flat direction from `from` to `to` by at most `step`; returns the new yaw.
## Yaw 0 faces -Z (the unit's forward).
static func turn_toward(yaw: float, from: Vector3, to: Vector3, step: float) -> float:
	var want := atan2(-(to.x - from.x), -(to.z - from.z))
	return yaw + clampf(wrapf(want - yaw, -PI, PI), -step, step)


func _drive(unit: Unit, spots: Array[Vector3], save: SaveGame, delta: float) -> void:
	var at := unit.body.global_position
	unit.wait -= delta
	match unit.state:
		State.PARKED:
			unit.lamp.emission_energy_multiplier = 0.0
			if unit.wait <= 0.0 and not spots.is_empty() and nearest(spots, at, _taken(unit)) != null:
				unit.state = State.ROAM
				unit.wait = 0.0
			return
		State.ROAM:
			var got := coins.vacuum_at(at, save.vacuum_reach, save.vacuum_capacity - unit.loaded)
			unit.loaded += got.x
			var bay := _bay(save)
			if bay != null:
				var slips := bay.vacuum_at(at, save.vacuum_reach, save.vacuum_capacity - unit.loaded)
				unit.slips.append_array(slips)
				unit.loaded += slips.size()
				if not slips.is_empty():
					_rescan = 0.0
			if got.x > 0:
				_rescan = 0.0  # a stack shrank or went: look again next tick
			unit.value += got.y
			unit.lamp.emission_energy_multiplier = LAMP_ON * (0.8 + 0.2 * sin(_time * 3.0))
			if unit.loaded >= save.vacuum_capacity or spots.is_empty():
				unit.state = State.RETURN
			elif unit.wait <= 0.0 or at.distance_to(unit.goal) < ARRIVE:
				unit.wait = REPICK
				# Every stack left is another unit's: this one goes home.
				var spot: Variant = nearest(spots, at, _taken(unit))
				if spot == null:
					unit.state = State.RETURN
				else:
					unit.goal = _clamp(spot)
		State.RETURN:
			unit.goal = (global_transform * unit.home).origin
			# Full: the lamp blinks on the way home.
			unit.lamp.emission_energy_multiplier = LAMP_ON if unit.loaded < save.vacuum_capacity or fmod(_time, 0.5) < 0.25 else 0.0
			if at.distance_to(unit.goal) < ARRIVE:
				_unload(unit)
				return
	_steer(unit, save, delta)


## The goals of the other units out collecting.
func _taken(unit: Unit) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for other in _units:
		if other != unit and other.state == State.ROAM:
			out.append(other.goal)
	return out


func _steer(unit: Unit, save: SaveGame, delta: float) -> void:
	var xf := unit.body.global_transform
	var yaw := turn_toward(xf.basis.get_euler().y, xf.origin, unit.goal, TURN_SPEED * save.vacuum_speed * delta)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var flat := Vector3(unit.goal.x - xf.origin.x, 0.0, unit.goal.z - xf.origin.z)
	var step := 0.0
	if absf(wrapf(atan2(-flat.x, -flat.z) - yaw, -PI, PI)) < FACING:
		step = minf(BASE_SPEED * save.vacuum_speed * delta, flat.length())
	var to := xf.origin + forward * step
	# Units don't drive through each other: an overlap is pushed apart.
	for other in _units:
		var apart := to - other.body.global_position
		apart.y = 0.0
		if other != unit and apart.length() < RADIUS * 2.0:
			to += (apart.normalized() if apart.length() > 0.001 else forward.cross(Vector3.UP)) * (RADIUS * 2.0 - apart.length()) * 0.5
	unit.body.global_transform = Transform3D(Basis(Vector3.UP, yaw), to)
	if unit.brush != null:
		unit.brush.rotate_y(delta * 14.0)


## Home: backs into its spot, beeps, and the bag's coins fly to the tally.
func _unload(unit: Unit) -> void:
	unit.body.global_transform = global_transform * unit.home
	unit.state = State.PARKED
	unit.wait = REST
	if not unit.slips.is_empty():
		_bay(SaveManager.save).file_from(unit.slips, unit.body.global_position + Vector3.UP * HEIGHT)
		unit.slips = []
	if unit.value > 0:
		coins.bank_from(unit.body.global_position + Vector3.UP * HEIGHT, unit.value)
		$Beep.cue(unit.body.global_position)
	unit.loaded = 0
	unit.value = 0


func _clamp(spot: Vector3) -> Vector3:
	return Vector3(clampf(spot.x, AREA.position.x, AREA.end.x), spot.y, clampf(spot.z, AREA.position.y, AREA.end.y))


func _add_unit() -> void:
	var unit := Unit.new()
	unit.body = AnimatableBody3D.new()
	unit.body.collision_layer = 1
	unit.body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT / 2.0
	unit.body.add_child(shape)
	var model := BODY.instantiate()
	unit.body.add_child(model)
	add_child(unit.body)
	unit.brush = model.get_node_or_null("Model/Brush")
	unit.lamp = model.get_node("Model/Lamp").material_override
	var dock: Node3D = $Dock
	if not _units.is_empty():
		dock = $Dock.duplicate()
		dock.position += Vector3.RIGHT * ROW_STEP * _units.size()
		add_child(dock)
	var lamp: MeshInstance3D = dock.get_node("Model/Lamp")
	lamp.material_override = lamp.material_override.duplicate()
	unit.dock_lamp = lamp.material_override
	var park: Node3D = dock.get_node("Park")
	unit.home = Transform3D(park.transform.basis, dock.position + park.position)
	unit.body.global_transform = global_transform * unit.home
	_units.append(unit)


## Drops onto the mat's edge once the card is stamped.
func _arrive() -> void:
	visible = true
	position = _rest + SLIDE_FROM
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Beep.cue(global_position))
