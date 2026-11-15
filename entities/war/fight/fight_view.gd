class_name FightView
extends Node3D
## What the player sees of a WarFight on the war sheet (WarSheet): it follows the sim every frame and
## never changes it. Figures (entities/war/soldiers/<unit>.tscn, scaled to the map's cells) stand on
## the map, hop toy-like while they walk, face what they go for, lunge when they strike and tip over
## on their base's back edge when they fall. Turrets turn toward the nearest figure in range and
## recoil on a shot; every shot throws a small physics cabbage from the Muzzle along an arc timed to
## the shot's travel (pooled, at most MAX_SHOTS; they lie on the board until clear()); splash shots,
## blasts and buildings going down raise a dust puff; a hit flashes and shakes what it hit; a
## building at 0 HP shows its Rubble and its wall neighbours drop their arms toward it.
## Each kind its own way (research/war-units.md): the CCTV mast's head sweeps and fires rapid small
## cabbages; the sprinkler's head spins while it sprays a ring of brine round its target; the
## shredder's feed slot faces its figure and throws a stream of green strips that thickens (and its
## drum churns faster) with its streak; the silo lobs high and bursts in a ring of puffs and card
## bits that rocks the figures it spares; a restructuring charge waddles with its fuse flickering
## and goes up in card debris; a courier rolls without a bob, leans into turns and jumps the fence
## it hops; a senior asset lumbers; a pult crew lobs its cabbage high.
## The war sheet holds it as `Field` (sheet frame): `Figures` holds the figures not in the fight yet, `Shots`
## the cabbages and puffs, `Floor` catches the cabbages. Placed figures stand under the map.
## Sounds (SoundCues under `Sounds`, capped there): a tower's shot (Cannon, Mortar) or a unit's throw
## (Throw) as it leaves, a melee strike (Strike), a blast (Blast), a tower's cabbage landing on its
## figure (Hit) or a unit's on the board (Land), a figure lying down (Topple), a building going
## down (Collapse, or its wall's own: WallWood, WallStone, WallSteel).

const SOLDIERS := "res://entities/war/soldiers/%s.tscn"
const SHOT := preload("res://entities/war/fight/shot_cabbage.tscn")
const PUFF := preload("res://entities/war/fight/puff.tscn")
const FLASH := preload("res://entities/war/fight/hit_flash.tres")
const STRIPS := preload("res://entities/war/fight/strips.tscn")
const SPRAY := preload("res://entities/war/fight/spray.tscn")
const DEBRIS := preload("res://entities/war/fight/debris.tscn")
## The soldier figures are built for 0.2 m cells; the map's are WarMap.CELL (their sizes to each
## other stay: the senior asset stays the big one).
const FIGURE_SCALE := WarMap.CELL / 0.2
const MAX_SHOTS := 40
## How a figure walks: the pace of its bounce (rad/s), the hop (m) and its side-to-side roll (rad:
## a waddle, a lumber); kinds not in GAITS walk as GAIT.
const GAIT := {pace = 18.0, hop = 0.01, sway = 0.0}
const GAITS := {
	senior_asset = {pace = 9.0, hop = 0.005, sway = 0.07},
	restructuring_charge = {pace = 24.0, hop = 0.004, sway = 0.28},
	pult_crew = {pace = 13.0, hop = 0.006, sway = 0.03},
	courier = {pace = 0.0, hop = 0.0, sway = 0.0},
}
## The courier leans into its turns (rad per rad still to turn, at most LEAN) and jumps a fence this
## high (m; the tallest fence is 0.076).
const LEAN_PER_TURN := 0.5
const LEAN := 0.3
const JUMP := 0.12
## The charge's fuse flickers (rad/s).
const FUSE_FLICKER := 31.0
const TIP_TIME := 0.35
const TURN_RATE := 10.0
## A strike's lunge forward (m), and how fast it settles (1/s).
const LUNGE := 0.02
const LUNGE_BACK := 6.0
const FLASH_TIME := 0.08
const SHAKE_TIME := 0.15
const SHAKE := 0.005
const RECOIL := 0.012
## A turret at rest faces south-west, toward the zones and the figures (0 would point north, foreshortened).
const REST_AIM := PI * 0.75
## Walking figures keep this far apart (cells), six to a ring, so a column on one path still shows
## each; the spread grows in over SPREAD_IN cells walked, so a figure first stands where it was set down.
const SPREAD := 0.3
const SPREAD_IN := 1.0
## A thrown cabbage flies this high over its way (m: base + per metre of way), and keeps this much
## of its speed when it lands, to roll a little.
const ARC := 0.05
const ARC_PER_M := 0.12
const KEEP_SPEED := 0.15
const SHOT_RADIUS := 0.016
## The shot cabbage's mesh scale in shot_cabbage.tscn.
const SHOT_MESH := 0.22
## A shooter's cabbage, if not a plain one: its size (x a shot cabbage) and arc (x the usual).
const SHOT_STYLE := {cctv = {size = 0.55, arc = 0.25}, silo = {size = 1.15, arc = 1.6}, pult_crew = {size = 1.0, arc = 2.2}}
## The shredder's strips per shot: STRIPS_MIN, STRIPS_PER_STREAK more for each shot in a row on its
## figure, at most STRIPS_MAX; its drum (the strips in its bin) turns this fast (rad/s) and shakes
## this much more (m) each shot in a row, up to 10.
const STRIPS_MIN := 3
const STRIPS_PER_STREAK := 2
const STRIPS_MAX := 24
const DRUM_SPIN := 3.0
const DRUM_PER_STREAK := 2.5
const DRUM_SHAKE := 0.0006
## The sprinkler's head spins this fast (rad/s) while anyone is in range.
const SPRINKLER_SPIN := 14.0
## The CCTV head sweeps this far each side of REST_AIM (rad) at this pace (rad/s) with nobody in range.
const PAN := 0.7
const PAN_PACE := 0.9
## The silo's burst: puffs round it, card bits flying; figures it spares rock over (tip) and back.
const BURST_PUFFS := 7
const BURST_BITS := 40
const BLAST_BITS := 22
const KNOCK_TIP := 0.7
const KNOCK_TIME := 1.1
## A building kind's sound as it goes down (anything else: Collapse).
const DOWN_SOUND := {wall_wood = "WallWood", wall_stone = "WallStone", wall_steel = "WallSteel"}

var map: WarMap
## The placed figures, in WarFight.units' order.
var units: Array[Node3D] = []

var _buildings: Array[Node3D] = []
var _rest: Array[Vector3] = []
## The map `_rest` was taken from (instance id).
var _rest_of := 0
var _hp: Array[float] = []
var _up: Array[bool] = []
var _shake: Array[float] = []
var _aim: Array[float] = []
var _recoil: Array[float] = []
var _unit_hp: Array[float] = []
var _cooldown: Array[float] = []
var _tip: Array[float] = []
var _hop: Array[float] = []
var _lunge: Array[float] = []
## A figure rocked by a burst: 1 just hit .. 0 standing again.
var _knock: Array[float] = []
## The courier's lean (rad, + to its right).
var _lean: Array[float] = []
## A hopper's fence cell as last seen, and where it stood when that hop began (cell space).
var _hop_seen: Array[Vector2i] = []
var _hop_from: Array[Vector2] = []
## Seconds followed (the fuse flicker, the CCTV sweep).
var _time := 0.0
## Where each placed figure was set down (cell space; INF until the fight has it).
var _from: Array[Vector2] = []
## Cabbages in the air: {body, from, to, t, travel, height, splash, tower}.
var _flying: Array[Dictionary] = []
## Every cabbage thrown, oldest first (the pool).
var _shots: Array[RigidBody3D] = []
## Flashing meshes -> seconds left.
var _flash := {}

@onready var figures: Node3D = $Figures
@onready var _shots_node: Node3D = $Shots
@onready var _sounds: Node3D = $Sounds


## Takes `war_map` as it stands: every building up, walls joined, nothing placed or thrown.
func setup(war_map: WarMap) -> void:
	clear()
	map = war_map
	_buildings = map.buildings()
	# Kept for the same map (its buildings were jolted in the last fight); a new map brings its own.
	if _rest_of != map.get_instance_id() or _rest.size() != _buildings.size():
		_rest_of = map.get_instance_id()
		_rest.clear()
		for node in _buildings:
			_rest.append(node.position)
	_hp.clear()
	_up.clear()
	_shake.clear()
	_aim.clear()
	_recoil.clear()
	for i in _buildings.size():
		var node := _buildings[i]
		node.position = _rest[i]
		WarMap.wreck(node, false)
		if node.has_node("Turret"):
			(node.get_node("Turret") as Node3D).rotation.y = REST_AIM
		_hp.append(INF)
		_up.append(true)
		_shake.append(0.0)
		_aim.append(REST_AIM)
		_recoil.append(0.0)
	map.show_walls()


## Everything thrown and placed goes (the figures not placed too); the buildings stay as they are until setup().
func clear() -> void:
	for node in units:
		node.queue_free()
	units.clear()
	_unit_hp.clear()
	_cooldown.clear()
	_tip.clear()
	_hop.clear()
	_lunge.clear()
	_from.clear()
	_knock.clear()
	_lean.clear()
	_hop_seen.clear()
	_hop_from.clear()
	for child in _shots_node.get_children() + figures.get_children():
		child.queue_free()
	_shots.clear()
	_flying.clear()
	_flash.clear()


## A new figure of `unit`: a holder (place it, turn it about Y) with the soldier scene in it as `Soldier`.
static func figure(unit: String) -> Node3D:
	var holder := Node3D.new()
	holder.set_meta(&"unit", unit)
	var soldier: Node3D = (load(SOLDIERS % unit) as PackedScene).instantiate()
	soldier.name = &"Soldier"
	soldier.scale = Vector3.ONE * FIGURE_SCALE
	holder.add_child(soldier)
	return holder


## Figure `holder` was placed (it is WarFight.units' next one): it stands on the map from now on.
func add_unit(holder: Node3D) -> void:
	holder.reparent(map, false)
	holder.rotation = Vector3.ZERO
	units.append(holder)
	_unit_hp.append(INF)
	_cooldown.append(0.0)
	_tip.append(0.0)
	_hop.append(0.0)
	_lunge.append(0.0)
	_from.append(Vector2.INF)
	_knock.append(0.0)
	_lean.append(0.0)
	_hop_seen.append(Vector2i(-1, -1))
	_hop_from.append(Vector2.INF)


## One frame of `fight`, after its tick: figures, buildings, turrets and what was thrown.
func follow(fight: WarFight, delta: float) -> void:
	_time += delta
	for e in fight.take_events():
		_event(fight, e)
	for i in mini(units.size(), fight.units.size()):
		_unit(fight, i, delta)
	_towers(fight, delta)
	_fly(delta)
	for mesh: Variant in _flash.keys():
		_flash[mesh] -= delta
		if not is_instance_valid(mesh):
			_flash.erase(mesh)
		elif _flash[mesh] <= 0.0:
			(mesh as GeometryInstance3D).material_overlay = null
			_flash.erase(mesh)


## Where cell-space point `p` lies, globally.
func spot(p: Vector2) -> Vector3:
	return map.to_global(WarMap.point(p))


func shots_thrown() -> int:
	return _shots.size()


func _unit(fight: WarFight, i: int, delta: float) -> void:
	var u := fight.units[i]
	var holder := units[i]
	var soldier: Node3D = holder.get_node("Soldier")
	var gait: Dictionary = GAITS.get(u.unit, GAIT)
	var ring := int(i / 6.0)
	if _from[i] == Vector2.INF:
		_from[i] = u.pos
	var off := Vector2.ZERO if i == 0 else Vector2.from_angle(i * TAU / 6.0 + ring) * SPREAD * (1 + ring)
	off *= minf(u.pos.distance_to(_from[i]) / SPREAD_IN, 1.0)
	if u.hop_cell != _hop_seen[i]:  # A new fence to hop: from where it stands now.
		_hop_seen[i] = u.hop_cell
		_hop_from[i] = u.pos
	var jump := Vector3.ZERO
	if u.alive and u.hop_cell != Vector2i(-1, -1):
		jump = hop_arc(_hop_from[i], u.pos, u.hop_cell, 1.0 - u.hop_left / WarFight.HOP)
	var at := WarMap.point(u.pos + off + Vector2(jump.x, jump.z))
	var step := at - Vector3(holder.position.x, 0.0, holder.position.z)
	holder.position = at
	if u.hp < _unit_hp[i] - 0.001 and _unit_hp[i] != INF:
		_flash_node(soldier)
	_unit_hp[i] = u.hp
	if u.alive:
		var look := Vector2(step.x, step.z)
		if u.attacking >= 0:
			look = fight.centre(u.attacking) - u.pos
		if look.length() > 0.0001:
			var turn := angle_difference(holder.rotation.y, atan2(look.x, look.y))
			if u.unit == "courier":  # Into the turn.
				_lean[i] = lerpf(_lean[i], clampf(-turn * LEAN_PER_TURN, -LEAN, LEAN), minf(TURN_RATE * delta, 1.0))
			holder.rotation.y += turn * minf(TURN_RATE * delta, 1.0)
		if u.attacking >= 0 and u.cooldown > _cooldown[i] + 0.001:
			_lunge[i] = 1.0  # It struck.
			if u.stats.range <= WarFight.MELEE:
				_sound("Strike", holder.global_position)
		_hop[i] = _hop[i] + delta * float(gait.pace) if step.length() > 0.00001 else 0.0
	else:
		if _tip[i] < 1.0 and _tip[i] + delta / TIP_TIME >= 1.0 and holder.visible:
			_sound("Topple", holder.global_position)  # It lands on its back.
		_tip[i] = minf(_tip[i] + delta / TIP_TIME, 1.0)
		_hop[i] = 0.0
		_lean[i] = 0.0
	_cooldown[i] = u.cooldown
	_lunge[i] = maxf(_lunge[i] - delta * LUNGE_BACK, 0.0)
	var tip := maxf(_tip[i], KNOCK_TIP * sin(PI * (1.0 - _knock[i])) if _knock[i] > 0.0 else 0.0)
	_knock[i] = maxf(_knock[i] - delta / KNOCK_TIME, 0.0)
	soldier.transform = pose(soldier, tip, absf(sin(_hop[i])) * float(gait.hop) + jump.y, _lunge[i] * LUNGE,
			sin(_hop[i]) * float(gait.sway) + _lean[i])
	var spark := soldier.get_node_or_null("Muzzle/Spark") as Node3D
	if spark != null:  # The charge's fuse.
		spark.visible = u.alive
		spark.scale = Vector3.ONE * (0.55 + 0.7 * absf(sin(_time * FUSE_FLICKER + i) * sin(_time * 13.0 + 1.0)))


## Where a hopper crossing fence cell `cell` is seen, as {x, z: cell-space offset from its sim
## position `pos`; y: lift in m}: it rises from `from` (where it stood as the hop began) while it
## waits out the hop (`waited` 0..1 of WarFight.HOP), is over the fence's middle at the top of the
## arc and lands as it reaches the cell beyond, where the sim has it again.
static func hop_arc(from: Vector2, pos: Vector2, cell: Vector2i, waited: float) -> Vector3:
	var way := (Vector2(cell) + Vector2(0.5, 0.5) - from) * 2.0
	if way.length_squared() < 0.0001:
		return Vector3.ZERO
	var crossed := clampf((pos - from).dot(way) / way.length_squared(), 0.0, 1.0)
	var k := 0.5 * clampf(waited, 0.0, 1.0) + 0.5 * crossed
	var off := way * (k - crossed)
	return Vector3(off.x, JUMP * sin(PI * k), off.y)


## A soldier's transform in its holder: `tip` 0 standing .. 1 lying on its back (pivoting on its
## base's back edge), lifted `hop` m, pushed `lunge` m forward (+Z, the way it faces) and rolled
## `roll` rad about that way, on its base.
static func pose(soldier: Node3D, tip: float, hop: float, lunge: float, roll := 0.0) -> Transform3D:
	var edge := Vector3(0.0, 0.0, back_edge(soldier))
	var fall := ease(tip, 2.4) * (PI / 2.0 + 0.08 * sin(tip * PI))
	var turn := Transform3D(Basis(Vector3.RIGHT, -fall), Vector3.ZERO)
	return Transform3D(Basis(Vector3.BACK, roll), Vector3(0.0, hop, lunge)) * Transform3D(Basis(), edge) * turn \
			* Transform3D(Basis.from_scale(Vector3.ONE * FIGURE_SCALE), -edge)


## The back edge of a soldier's base (holder Z, m): where it tips over.
static func back_edge(soldier: Node3D) -> float:
	var model := soldier.get_node_or_null("Model") as MeshInstance3D
	if model == null or model.mesh == null:
		return -0.02
	return model.mesh.get_aabb().position.z * FIGURE_SCALE


func _towers(fight: WarFight, delta: float) -> void:
	var walls_changed := false
	for i in mini(_buildings.size(), fight.buildings.size()):
		var b := fight.buildings[i]
		var node := _buildings[i]
		if b.hp < _hp[i] - 0.001 and _hp[i] != INF:
			_shake[i] = SHAKE_TIME
			_flash_node(node)
		_hp[i] = b.hp
		if not b.alive and _up[i]:
			_up[i] = false
			WarMap.wreck(node, true)
			_puff(node.global_position, 1.6)
			_sound(DOWN_SOUND.get(b.kind, "Collapse"), node.global_position)
			walls_changed = walls_changed or b.kind in WarFight.WALLS
		_shake[i] = maxf(_shake[i] - delta, 0.0)
		var jolt := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SHAKE * _shake[i] / SHAKE_TIME
		node.position = _rest[i] + jolt
		if b.alive and b.kind in WarFight.DEFENCES and node.has_node("Turret"):
			var target := _nearest(fight, i)
			if target >= 0:
				var dir: Vector2 = fight.units[target].pos - fight.centre(i)
				_aim[i] = atan2(-dir.x, -dir.y)
			elif b.kind == "cctv":  # The camera sweeps the approach.
				_aim[i] = REST_AIM + sin(_time * PAN_PACE + i) * PAN
			var turret: Node3D = node.get_node("Turret")
			if b.kind == "sprinkler" and target >= 0:
				turret.rotation.y = wrapf(turret.rotation.y + SPRINKLER_SPIN * delta, -PI, PI)
			else:
				turret.rotation.y = lerp_angle(turret.rotation.y, _aim[i], minf(TURN_RATE * delta, 1.0))
			_recoil[i] = maxf(_recoil[i] - delta * LUNGE_BACK, 0.0)
			var mesh_at := Vector3(0.0, 0.0, RECOIL * _recoil[i])
			if b.kind == "shredder" and target >= 0:  # The drum churns, harder the longer it holds on.
				var drum := node.get_node_or_null("Base/Strips") as Node3D
				if drum != null:
					drum.rotation.y = wrapf(drum.rotation.y + (DRUM_SPIN + DRUM_PER_STREAK * b.streak) * delta, -PI, PI)
				mesh_at += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * DRUM_SHAKE * mini(b.streak, 10)
			(turret.get_node("Mesh") as Node3D).position = mesh_at
	if walls_changed:
		map.show_walls(_up)


## The unit tower `i` shoots at: its target while that lives, else the living unit nearest it
## within its range (as WarFight's towers pick), or -1.
func _nearest(fight: WarFight, i: int) -> int:
	var held: int = fight.buildings[i].target
	if held >= 0 and fight.units[held].alive:
		return held
	var spec: Dictionary = WarFight.BUILDINGS[fight.buildings[i].kind]
	var from := fight.centre(i)
	var best := -1
	var best_d := INF
	for j in fight.units.size():
		var d := from.distance_to(fight.units[j].pos)
		if fight.units[j].alive and d >= spec.min_range and d <= spec.range and d < best_d:
			best = j
			best_d = d
	return best


func _event(fight: WarFight, e: Dictionary) -> void:
	var to := spot(e.to) + Vector3.UP * SHOT_RADIUS
	if e.kind == "explode":
		_blast(fight, e, to)
		return
	var from := spot(e.from) + Vector3.UP * 0.05
	var tower := -1
	for i in mini(_buildings.size(), fight.buildings.size()):  # A tower's shot: from its muzzle, and it kicks back.
		if fight.centre(i).is_equal_approx(e.from) and _buildings[i].has_node("Turret/Muzzle"):
			from = (_buildings[i].get_node("Turret/Muzzle") as Node3D).global_position
			_recoil[i] = 1.0
			tower = i
	for j in mini(units.size(), fight.units.size()):  # A thrower's: from its figure.
		if fight.units[j].unit == e.by and fight.units[j].pos.is_equal_approx(e.from):
			from = (units[j].get_node("Soldier/Muzzle") as Node3D).global_position if units[j].has_node("Soldier/Muzzle") else from
	if e.by == "sprinkler":  # Brine at once, in a ring round the figure, and a mist at the head.
		_spray(to, _metres(e.to, float(e.splash)) * 0.8, 36)
		_spray(from, 0.05, 16)
		_sound("Hit", to)
		return
	if e.by == "shredder":
		_stream(from, to, int(fight.buildings[tower].streak) if tower >= 0 else 0)
		_sound("Hit", to)
		return
	var by_tower: bool = e.by in WarFight.DEFENCES
	if e.by != "cctv":  # The mast's rattle has no sound of its own yet.
		_sound(("Cannon" if e.by == "cannon" else "Mortar") if by_tower else "Throw", from)
	var style: Dictionary = SHOT_STYLE.get(e.by, {})
	_throw(from, to, float(e.travel), float(e.splash), by_tower, style.get("size", 1.0), style.get("arc", 1.0))


## A blast: a charge goes up (its figure gone) in a puff and card bits, or a silo bursts at its
## Burst in a ring of puffs and card bits, rocking the figures it spared.
func _blast(fight: WarFight, e: Dictionary, at: Vector3) -> void:
	if e.by == "silo":
		for i in mini(_buildings.size(), fight.buildings.size()):
			if fight.centre(i).is_equal_approx(e.to) and _buildings[i].has_node("Burst"):
				at = (_buildings[i].get_node("Burst") as Node3D).global_position
		var radius := _metres(e.to, float(e.splash))
		_puff(at, 2.6)
		for k in BURST_PUFFS:
			_puff(at + Vector3.FORWARD.rotated(Vector3.UP, k * TAU / BURST_PUFFS) * radius * 0.7, 1.8)
		_bits(at, BURST_BITS, 1.4)
		for j in mini(units.size(), fight.units.size()):
			if fight.units[j].alive and fight.units[j].pos.distance_to(e.to) <= float(e.splash):
				_knock[j] = 1.0
	else:
		_puff(at, 1.0 + 2.0 * float(e.splash))
		_bits(at, BLAST_BITS, 1.0)
		for j in mini(units.size(), fight.units.size()):  # Nothing is left of the charge.
			if fight.units[j].unit == e.by and fight.units[j].pos.is_equal_approx(e.from):
				units[j].visible = false
	_sound("Blast", at)


## `cells` (cell space) as metres on the board, at cell-space point `p`.
func _metres(p: Vector2, cells: float) -> float:
	return spot(p).distance_to(spot(p + Vector2(cells, 0.0)))


## The shredder's strips for one shot after `streak` shots in a row on its figure.
static func strip_count(streak: int) -> int:
	return mini(STRIPS_MIN + STRIPS_PER_STREAK * streak, STRIPS_MAX)


## The shredder's shot: strip_count(streak) green strips streaming from `from` to `to`.
func _stream(from: Vector3, to: Vector3, streak: int) -> CPUParticles3D:
	var strips := _effect(STRIPS, from, to - from)
	strips.amount = strip_count(streak)
	var speed := from.distance_to(to) / strips.lifetime
	strips.initial_velocity_min = speed
	strips.initial_velocity_max = speed * 1.08
	_shots_node.add_child(strips)
	return strips


func _spray(at: Vector3, radius: float, drops: int) -> void:
	var spray := _effect(SPRAY, at)
	spray.amount = drops
	spray.emission_ring_radius = maxf(radius, 0.02)
	spray.emission_ring_inner_radius = spray.emission_ring_radius * 0.7
	_shots_node.add_child(spray)


func _bits(at: Vector3, count: int, speed: float) -> void:
	var bits := _effect(DEBRIS, at)
	bits.amount = count
	bits.initial_velocity_min *= speed
	bits.initial_velocity_max *= speed
	_shots_node.add_child(bits)


## A one-shot effect (`scene`: strips, spray, debris) at `at`, its -Z toward `look` (none: upright),
## not added yet: set it up, then add it under Shots (it starts as it enters and frees itself).
func _effect(scene: PackedScene, at: Vector3, look := Vector3.ZERO) -> CPUParticles3D:
	var fx: CPUParticles3D = scene.instantiate()
	var facing := Basis()
	if look.length() > 0.0001 and absf(look.normalized().y) < 0.99:
		facing = Basis.looking_at(look)
	fx.transform = _shots_node.global_transform.affine_inverse() * Transform3D(facing, at)
	return fx


## Throws a cabbage from `from` to `to`: a tower's (`tower`) hits a figure there, a unit's lands on
## the board; `size` times a shot cabbage, flying `arc` times the usual height.
func _throw(from: Vector3, to: Vector3, travel: float, splash: float, tower := false, size := 1.0, arc := 1.0) -> void:
	var body: RigidBody3D
	if _shots.size() < MAX_SHOTS:
		body = SHOT.instantiate()
		_shots_node.add_child(body)
	else:  # The oldest one is thrown again.
		body = _shots.pop_front()
		_flying = _flying.filter(func(f: Dictionary) -> bool: return f.body != body)
	_shots.append(body)
	body.freeze = true
	body.global_position = from
	(body.get_node("Mesh") as Node3D).scale = Vector3.ONE * SHOT_MESH * size
	_flying.append({body = body, from = from, to = to, t = 0.0, travel = maxf(travel, 0.12),
			height = (ARC + ARC_PER_M * from.distance_to(to)) * arc, splash = splash, tower = tower})


func _fly(delta: float) -> void:
	var still: Array[Dictionary] = []
	for f in _flying:
		f.t += delta
		var k := minf(f.t / f.travel, 1.0)
		var body: RigidBody3D = f.body
		body.global_position = (f.from as Vector3).lerp(f.to, k) + Vector3.UP * f.height * 4.0 * k * (1.0 - k)
		if k < 1.0:
			still.append(f)
			continue
		body.freeze = false  # Landed: it rolls a little and lies there.
		body.linear_velocity = ((f.to - f.from) - Vector3.UP * 4.0 * f.height) / f.travel * KEEP_SPEED
		if f.splash > 0.0:
			_puff(f.to, 1.0 + f.splash)
		_sound("Hit" if f.tower else "Land", f.to)
	_flying = still


func _puff(at: Vector3, size: float) -> void:
	var puff: Node3D = PUFF.instantiate()
	puff.position = _shots_node.to_local(at)  # Before it enters the tree: it puffs as it does.
	puff.scale = Vector3.ONE * size
	_shots_node.add_child(puff)


func _flash_node(node: Node) -> void:
	for mesh: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
		if mesh.is_visible_in_tree():
			mesh.material_overlay = FLASH
			_flash[mesh] = FLASH_TIME


## Cues sound `cue` (a SoundCue under Sounds) at `at`.
func _sound(cue: String, at: Vector3) -> void:
	(_sounds.get_node(cue) as SoundCue).cue(at)
