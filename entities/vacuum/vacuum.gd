class_name CoinVacuums
extends Node3D
## The coin collector (desk card coin_collector): small grey robot pucks that roam the mat and suck
## up the resting coin stacks. This node is the dock on the mat's left edge; it slides in once the
## card is stamped and parks save.vacuums units, each backed into its own charging dock (the first
## is this node's, every further one a copy ROW_STEP along the mat edge). A unit drives (slowly:
## BASE_SPEED × save.vacuum_speed) to the nearest stack,
## takes up to save.vacuum_capacity coins within save.vacuum_reach as it goes, and when the bag is
## full or the mat is clean drives home, beeps and empties: the coins fly from it to the tally. It
## then recharges on its dock for save.vacuum_rest seconds before it goes out again.
## Its lamp glows while out and blinks when full. The bodies are kinematic, so they nudge cabbages
## aside. All the money logic is in CoinPile (vacuum_at, bank_from); coins in a bag still count in
## pending_value. Once TOKEN_CARD is stamped they also take the QA bay's resting report slips (one
## per bag slot) and, home, the slips fly from them into the Findings counter (QaBay.file_from).
## With a full bag of slips and coins on the mat, each unit alternates coin and slip trips (Trip); its
## lamp glows cyan on a slip trip.
## The hand can pick a unit up and set it down anywhere on the mat (never past it: on_mat). About every
## TIP_EVERY one unit out driving falls onto its back and stops, brush spinning, until the player
## picks it up and sets it down; the projector's STABILISER node stops that. While it lies there a
## small stencilled HELP_TEXT hovers over it and shakes (asks_for_help).

enum State { PARKED, ROAM, RETURN, TIPPED }
## What a unit takes on this trip. MIXED (coins and slips alike) unless, as it sets out, the mat holds
## coins and at least a full bag of slips (chapter 3): then it alternates COINS and SLIPS trips, else
## the slips by the dock would fill its bag before it reached the money (trip_kind).
enum Trip { MIXED, COINS, SLIPS }

const BODY := preload("res://entities/vacuum/vacuum_body.tscn")
## Metres per second and radians per second at vacuum_speed 1. Slow on purpose.
const BASE_SPEED := 0.1
const TURN_SPEED := 2.2
## It only drives forward while facing within this angle of its goal.
const FACING := 0.7
## Close enough to a goal (m).
const ARRIVE := 0.02
## Seconds between goal re-picks while out. Parked after emptying, a unit recharges on its dock for
## save.vacuum_rest seconds (its dock lamp glows) before it goes out again; the dock nodes shorten it.
const REPICK := 0.6
## Seconds between rescans of the mat for resting stacks.
const RESCAN := 0.25
## Each further unit parks this far along the mat edge from the last (dock-local x).
const ROW_STEP := 0.135
## Where the units may drive: the open mat, clear of the press, the ramp and the window sill.
const AREA := Rect2(-0.3, -0.6, 1.65, 1.25)
const LAMP_ON := 3.0
## The lamp's tint: amber, cold research cyan on a SLIPS trip.
const LAMP_COINS := Color(1, 0.62, 0.22)
const LAMP_SLIPS := Color(0.35, 0.85, 0.95)
const RADIUS := 0.055
const HEIGHT := 0.035
## Held, a unit hangs this far over the mat.
const LIFT := 0.05
## The units' own collision layer, and the cabbages' (a unit set down on one waits until it is clear).
const SOLID_LAYER := 1
const CABBAGE_LAYER := 4
## Seconds between tips (one unit of the fleet, random in this range) and the node that ends them.
const TIP_EVERY := Vector2(240.0, 360.0)
const STABILISER := "vacuum_gyro"
## The projector node that empties a whole bag in one burst instead of coin by coin.
const BULK_DISCHARGE := "vacuum_bulk"
const SLIDE_FROM := Vector3(0.0, 0.8, 0.0)
const SLIDE_TIME := 0.4
const TOKEN_CARD := "token_recovery"
## Strength of the beep when a unit empties at home (SoundCue level): a faint blip, the coins landing
## in the tally carry the moment. Tipping over and arriving still beep at full strength.
const UNLOAD_BEEP := 0.15
## A fallen unit's plea, HELP_HEIGHT over it, jittering up to HELP_SHAKE (m).
const HELP_TEXT := "UNIT INVERTED
PLEASE ASSIST"
const HELP_HEIGHT := 0.11
const HELP_SHAKE := 0.004

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
	var trip := Trip.MIXED
	## Its last alternating trip was a COINS one (set per unit index, so the fleet starts split).
	var last_coins := false
	var wait := 0.0
	## In the player's hand.
	var held := false
	## Not solid (only on the hand's HOVER_LAYER, which nothing collides with): carried, or set down
	## on a cabbage and not yet clear of it, so it never shoves resting units aside.
	var ghost := false
	## Which way it faced when it fell over (TIPPED).
	var fallen_yaw := 0.0
	## The plea over it while it lies on its back.
	var help: Label3D


var _units: Array[Unit] = []
var _time := 0.0
## The resting stacks the units can reach, refreshed every RESCAN (and right after a unit takes coins).
var _spots: Array[Vector3] = []
## The same, split by kind (for the trip kinds).
var _coin_spots: Array[Vector3] = []
var _slip_spots: Array[Vector3] = []
var _rescan := 0.0
## The QA bay, found on the first _bay call.
var _qa: QaBay
var _tip_in := randf_range(TIP_EVERY.x, TIP_EVERY.y)

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
		# Only the stacks a unit can get close enough to (inside AREA, give or take its reach). Measured,
		# not boxed: one past a corner of AREA is further from it than one past an edge.
		var bay := _bay(save)
		_coin_spots = _reachable(coins.resting_spots(), save.vacuum_reach)
		_slip_spots = _reachable(bay.resting_spots() if bay != null else [] as Array[Vector3], save.vacuum_reach)
		_spots = _coin_spots.duplicate()
		_spots.append_array(_slip_spots)
	_tip_in -= delta
	if _tip_in <= 0.0:
		_tip_in = randf_range(TIP_EVERY.x, TIP_EVERY.y)
		var out := _units.filter(func(u: Unit) -> bool: return can_tip(u.state, u.held, save))
		if not out.is_empty():
			_tip(out.pick_random())
	for unit in _units:
		_drive(unit, _spots, save, delta)
		unit.help.visible = asks_for_help(unit.state, unit.held)
		if unit.help.visible:
			unit.help.global_position = unit.body.global_position + Vector3(HELP_SHAKE * sin(_time * 47.0),
					HELP_HEIGHT + HELP_SHAKE * 0.6 * sin(_time * 61.0), 0.0)
		unit.dock_lamp.emission_energy_multiplier = LAMP_ON * 0.5 if unit.state == State.PARKED and unit.wait > 0.0 else 0.0


## The QA bay, when the units may take its slips (TOKEN_CARD stamped); else null.
func _bay(save: SaveGame) -> QaBay:
	if not save.stamped.has(TOKEN_CARD):
		return null
	if _qa == null:
		_qa = get_tree().get_first_node_in_group(&"qa_bay") as QaBay
	return _qa


static func _reachable(spots: Array[Vector3], reach: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for spot in spots:
		if reachable(spot, reach):
			out.append(spot)
	return out


## The kind of trip a unit sets out on, with `stacks` coin stacks and `slips` slips resting on the mat and a
## bag of `capacity`: MIXED as before, unless there are coins and a full bag of slips; then the other
## kind than its last trip (`last_coins`).
static func trip_kind(stacks: int, slips: int, capacity: int, last_coins: bool) -> Trip:
	if stacks == 0 or slips < capacity:
		return Trip.MIXED
	return Trip.SLIPS if last_coins else Trip.COINS


## The kind a unit out on `trip` goes on with: its own while any of it lies on the mat, else the other
## (never idling with work on the mat).
static func trip_goes_on(trip: Trip, stacks: int, slips: int) -> Trip:
	if trip == Trip.COINS and stacks == 0 and slips > 0:
		return Trip.SLIPS
	if trip == Trip.SLIPS and slips == 0 and stacks > 0:
		return Trip.COINS
	return trip


## Whether the first alternating trip of the unit at `index` is a SLIPS one: every second unit, so
## about half the fleet is on coins.
static func starts_on_slips(index: int) -> bool:
	return index % 2 == 1


## Whether a unit may fall over now: out driving, not in the hand, and no stabiliser bought.
static func can_tip(state: State, held: bool, save: SaveGame) -> bool:
	return not held and (state == State.ROAM or state == State.RETURN) and not save.tree_bought.has(STABILISER)


## Whether a unit shows its plea: on its back and not yet picked up.
static func asks_for_help(state: State, held: bool) -> bool:
	return state == State.TIPPED and not held


## Whether a unit sucks up coins now: only out collecting, upright and not in the hand.
static func collects(state: State, held: bool) -> bool:
	return state == State.ROAM and not held


## The state a unit goes on in once the hand sets it down: a fallen one is upright again and drives
## out, one taken off its dock drives home.
static func set_down(state: State) -> State:
	return State.ROAM if state == State.TIPPED else State.RETURN if state == State.PARKED else state


## Whether a unit driving on the mat can get within `reach` of a stack at `spot`.
static func reachable(spot: Vector3, reach: float) -> bool:
	var on := on_mat(spot)
	return Vector2(spot.x, spot.z).distance_to(Vector2(on.x, on.z)) <= reach * 0.9


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
	if unit.held:
		_carry(unit)
		return
	if unit.ghost:
		_settle(unit)
	var at := unit.body.global_position
	unit.wait -= delta
	match unit.state:
		State.TIPPED:
			# On its back: the brush spins in the air, the lamp blinks, nothing is collected.
			unit.lamp.emission_energy_multiplier = LAMP_ON if fmod(_time, 0.8) < 0.4 else 0.0
			if unit.brush != null:
				unit.brush.rotate_y(delta * 30.0)
			# Rocks on its back as the wheels spin.
			unit.body.global_transform = Transform3D(Basis(Vector3.UP, unit.fallen_yaw)
					* Basis(Vector3.BACK, PI + 0.06 * sin(_time * 23.0)), unit.body.global_position)
			return
		State.PARKED:
			unit.lamp.emission_energy_multiplier = 0.0
			if unit.wait <= 0.0 and not spots.is_empty() and nearest(spots, at, _taken(unit)) != null:
				unit.state = State.ROAM
				unit.wait = 0.0
				unit.trip = trip_kind(_coin_spots.size(), _slip_spots.size(), save.vacuum_capacity, unit.last_coins)
				if unit.trip != Trip.MIXED:
					unit.last_coins = unit.trip == Trip.COINS
			return
		State.ROAM when collects(unit.state, unit.held):
			unit.trip = trip_goes_on(unit.trip, _coin_spots.size(), _slip_spots.size())
			spots = _spots if unit.trip == Trip.MIXED else _coin_spots if unit.trip == Trip.COINS else _slip_spots
			var got := Vector2i.ZERO
			if unit.trip != Trip.SLIPS:
				got = coins.vacuum_at(at, save.vacuum_reach, save.vacuum_capacity - unit.loaded)
			unit.loaded += got.x
			var bay := _bay(save)
			if bay != null and unit.trip != Trip.COINS:
				var slips := bay.vacuum_at(at, save.vacuum_reach, save.vacuum_capacity - unit.loaded)
				unit.slips.append_array(slips)
				unit.loaded += slips.size()
				if not slips.is_empty():
					_rescan = 0.0
			if got.x > 0:
				_rescan = 0.0  # a stack shrank or went: look again next tick
			unit.value += got.y
			unit.lamp.emission = LAMP_SLIPS if unit.trip == Trip.SLIPS else LAMP_COINS
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
					unit.goal = on_mat(spot)
		State.RETURN:
			unit.goal = (global_transform * unit.home).origin
			# Full: the lamp blinks on the way home.
			unit.lamp.emission_energy_multiplier = LAMP_ON if unit.loaded < save.vacuum_capacity or fmod(_time, 0.5) < 0.25 else 0.0
			if at.distance_to(unit.goal) < ARRIVE:
				_unload(unit)
				return
	_steer(unit, save, delta)


## The goals of the other units out collecting, and where the parked or fallen ones sit: a stack
## under a unit is that unit's, as the others can't drive into it to reach it.
func _taken(unit: Unit) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for other in _units:
		if other == unit:
			continue
		if other.state == State.ROAM:
			out.append(other.goal)
		elif other.state == State.PARKED or other.state == State.TIPPED:
			out.append(other.body.global_position)
	return out


func _steer(unit: Unit, save: SaveGame, delta: float) -> void:
	var others: Array[Vector3] = []
	for other in _units:
		if other != unit:
			others.append(other.body.global_position)
	unit.body.global_transform = drive_step(unit.body.global_transform, unit.goal, others,
			TURN_SPEED * save.vacuum_speed * delta, BASE_SPEED * save.vacuum_speed * delta)
	if unit.brush != null:
		unit.brush.rotate_y(delta * 14.0)


## One drive step from `xf` toward `goal`: turns by at most `turn`, rolls forward up to `step` while
## facing it, and never into a unit at `others`. One in the way is driven round (on the side toward
## the goal), not pushed against: a unit parked or fallen in the path used to block it for good. One
## sitting on the goal itself is ignored (driven round, it would be circled forever), and a goal on
## the mat keeps the step on it (on_mat): driving round never pushes a unit off the mat, it goes round
## the other side.
static func drive_step(xf: Transform3D, goal: Vector3, others: Array[Vector3], turn: float, step: float) -> Transform3D:
	var yaw := turn_toward(xf.basis.get_euler().y, xf.origin, goal, turn)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var flat := Vector3(goal.x - xf.origin.x, 0.0, goal.z - xf.origin.z)
	var move := 0.0
	if absf(wrapf(atan2(-flat.x, -flat.z) - yaw, -PI, PI)) < FACING:
		move = minf(step, flat.length())
	var to := xf.origin + forward * move
	var keep := on_mat(goal) == goal
	for other in others:
		var apart := Vector3(to.x - other.x, 0.0, to.z - other.z)
		if apart.length() >= RADIUS * 2.0 or Vector2(goal.x - other.x, goal.z - other.z).length() < RADIUS * 2.0:
			continue
		var out := apart.normalized() if apart.length() > 0.001 else forward.cross(Vector3.UP)
		var side := out.cross(Vector3.UP)
		if side.dot(flat) < 0.0:
			side = -side
		# One too close to the mat's edge to pass between: always round it on the mat's side.
		var edge := edge_out(other)
		if keep and edge != Vector3.ZERO:
			var sense := 1.0 if angle_from(edge, goal - other) >= angle_from(edge, out) else -1.0
			side = Vector3(-out.z, 0.0, out.x) * sense
		to = Vector3(other.x, to.y, other.z) + out * RADIUS * 2.0 + side * move
	if keep:
		to = on_mat(to)
	return Transform3D(Basis(Vector3.UP, yaw), to)


## The outward direction of the mat edge nearer to `at` than a unit fits through (2 × RADIUS); zero
## when there is room all round.
static func edge_out(at: Vector3) -> Vector3:
	var gaps := {
		Vector3.LEFT: at.x - AREA.position.x, Vector3.RIGHT: AREA.end.x - at.x,
		Vector3.FORWARD: at.z - AREA.position.y, Vector3.BACK: AREA.end.y - at.z}
	var best := Vector3.ZERO
	var closest := RADIUS * 2.0
	for way: Vector3 in gaps:
		if gaps[way] < closest:
			closest = gaps[way]
			best = way
	return best


## The flat angle (0..TAU) from `from` to `to`, counted the way round that never wraps past `from`.
static func angle_from(from: Vector3, to: Vector3) -> float:
	return fposmod(atan2(from.x * to.z - from.z * to.x, from.x * to.x + from.z * to.z), TAU)


## Falls onto its back where it is: stops until the hand picks it up.
func _tip(unit: Unit) -> void:
	unit.state = State.TIPPED
	var xf := unit.body.global_transform
	unit.fallen_yaw = xf.basis.get_euler().y
	unit.body.global_position = xf.origin + Vector3.UP * HEIGHT
	$Beep.cue(xf.origin)


## In the hand: upright, hanging under it, never off the mat.
func _carry(unit: Unit) -> void:
	var desk := (global_transform * unit.home).origin.y
	unit.body.global_transform = Transform3D(Basis(Vector3.UP, _yaw(unit)), on_mat(Hand.point_on_height(desk + LIFT)))


## Which way a unit faces (a fallen one: the way it fell).
func _yaw(unit: Unit) -> float:
	return unit.fallen_yaw if unit.state == State.TIPPED else unit.body.global_transform.basis.get_euler().y


## Set down where the hand lets go: on the mat (on_mat keeps it off the sill and out of the window).
func _set_down(unit: Unit) -> void:
	unit.held = false
	var at := on_mat(unit.body.global_position)
	at.y = (global_transform * unit.home).origin.y
	unit.body.global_transform = Transform3D(Basis(Vector3.UP, _yaw(unit)), at)
	unit.state = set_down(unit.state)
	unit.wait = 0.0
	_settle(unit)


## Solid again once no cabbage overlaps it (until then it stays a ghost, so none is blasted away).
func _settle(unit: Unit) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := unit.body.get_child(0) as CollisionShape3D
	query.shape = shape.shape
	query.transform = unit.body.global_transform * shape.transform
	query.collision_mask = CABBAGE_LAYER
	unit.ghost = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	unit.body.collision_layer = Interactable.HOVER_LAYER if unit.ghost else SOLID_LAYER


## Home: backs into its spot, beeps, and the bag's coins fly to the tally.
func _unload(unit: Unit) -> void:
	unit.body.global_transform = global_transform * unit.home
	unit.state = State.PARKED
	unit.wait = SaveManager.save.vacuum_rest
	var bulk := SaveManager.save.tree_bought.has(BULK_DISCHARGE)
	if not unit.slips.is_empty():
		_bay(SaveManager.save).file_from(unit.slips, unit.body.global_position + Vector3.UP * HEIGHT, bulk)
		unit.slips = []
	if unit.value > 0:
		coins.bank_from(unit.body.global_position + Vector3.UP * HEIGHT, unit.value, bulk)
		$Beep.cue(unit.body.global_position, UNLOAD_BEEP)
	unit.loaded = 0
	unit.value = 0


## `spot` moved onto the open mat (AREA), height kept: where a unit may drive or be set down.
static func on_mat(spot: Vector3) -> Vector3:
	return Vector3(clampf(spot.x, AREA.position.x, AREA.end.x), spot.y, clampf(spot.z, AREA.position.y, AREA.end.y))


func _add_unit() -> void:
	var unit := Unit.new()
	unit.body = AnimatableBody3D.new()
	unit.body.collision_layer = SOLID_LAYER
	unit.body.collision_mask = 0
	# Moved by setting its transform, which must hold at once (synced, a set-down was undone by the
	# next drive step reading the old one back).
	unit.body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT / 2.0
	unit.body.add_child(shape)
	var grip := Interactable.new()
	grip.grip_height = HEIGHT + 0.02
	grip.tooltip = "Coin robot: it collects the coins resting on the mat. If it falls over, pick it up and set it down."
	unit.body.add_child(grip)
	grip.grabbed.connect(func() -> void:
		unit.held = true
		unit.ghost = true
		unit.body.collision_layer = Interactable.HOVER_LAYER)
	grip.released.connect(func() -> void: _set_down(unit))
	unit.help = Label3D.new()
	unit.help.text = HELP_TEXT
	unit.help.font = preload("res://assets/fonts/Oswald.ttf")
	unit.help.font_size = 40
	unit.help.pixel_size = 0.0011
	unit.help.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	unit.help.no_depth_test = true
	unit.help.render_priority = 2
	unit.help.outline_render_priority = 1
	unit.help.modulate = Color(0.86, 0.84, 0.74)
	unit.help.outline_modulate = Color(0.06, 0.07, 0.07, 0.85)
	unit.help.outline_size = 10
	unit.help.line_spacing = -6.0
	unit.help.visible = false
	add_child(unit.help)
	unit.last_coins = starts_on_slips(_units.size())
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
