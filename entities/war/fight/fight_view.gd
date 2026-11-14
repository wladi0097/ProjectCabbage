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
## The war sheet holds it as `Field` (sheet frame): `Tray` holds the figures not placed yet, `Shots`
## the cabbages and puffs, `Floor` catches the cabbages. Placed figures stand under the map.
## Sounds (SoundCues under `Sounds`, capped there): a tower's shot (Cannon, Mortar) or a unit's throw
## (Throw) as it leaves, a melee strike (Strike), a blast (Blast), a tower's cabbage landing on its
## figure (Hit) or a unit's on the board (Land), a figure lying down (Topple), a building going
## down (Collapse, or its wall's own: WallWood, WallStone, WallSteel).

const SOLDIERS := "res://entities/war/soldiers/%s.tscn"
const SHOT := preload("res://entities/war/fight/shot_cabbage.tscn")
const PUFF := preload("res://entities/war/fight/puff.tscn")
const FLASH := preload("res://entities/war/fight/hit_flash.tres")
## The soldier figures are built for 0.2 m cells; the map's are WarMap.CELL (their sizes to each
## other stay: the senior asset stays the big one).
const FIGURE_SCALE := WarMap.CELL / 0.2
const MAX_SHOTS := 40
## A walking figure's hop (m) and its pace (rad/s of the bounce).
const HOP := 0.01
const HOP_PACE := 18.0
const TIP_TIME := 0.35
const TURN_RATE := 10.0
## A strike's lunge forward (m), and how fast it settles (1/s).
const LUNGE := 0.02
const LUNGE_BACK := 6.0
const FLASH_TIME := 0.08
const SHAKE_TIME := 0.15
const SHAKE := 0.005
const RECOIL := 0.012
## Figures on one spot stand this far apart (cells), six to a ring.
const SPREAD := 0.3
## A thrown cabbage flies this high over its way (m: base + per metre of way), and keeps this much
## of its speed when it lands, to roll a little.
const ARC := 0.05
const ARC_PER_M := 0.12
const KEEP_SPEED := 0.15
const SHOT_RADIUS := 0.016
## A building kind's sound as it goes down (anything else: Collapse).
const DOWN_SOUND := {wall_wood = "WallWood", wall_stone = "WallStone", wall_steel = "WallSteel"}

var map: WarMap
## The placed figures, in WarFight.units' order.
var units: Array[Node3D] = []

var _buildings: Array[Node3D] = []
var _rest: Array[Vector3] = []
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
## Cabbages in the air: {body, from, to, t, travel, height, splash, tower}.
var _flying: Array[Dictionary] = []
## Every cabbage thrown, oldest first (the pool).
var _shots: Array[RigidBody3D] = []
## Flashing meshes -> seconds left.
var _flash := {}

@onready var tray: Node3D = $Tray
@onready var _shots_node: Node3D = $Shots
@onready var _sounds: Node3D = $Sounds


## Takes `war_map` as it stands: every building up, walls joined, nothing placed or thrown.
func setup(war_map: WarMap) -> void:
	clear()
	map = war_map
	_buildings = map.buildings()
	if _rest.size() != _buildings.size():
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
			(node.get_node("Turret") as Node3D).rotation.y = 0.0
		_hp.append(INF)
		_up.append(true)
		_shake.append(0.0)
		_aim.append(0.0)
		_recoil.append(0.0)
	map.show_walls()


## Everything thrown and placed goes (the tray too); the buildings stay as they are until setup().
func clear() -> void:
	for node in units:
		node.queue_free()
	units.clear()
	_unit_hp.clear()
	_cooldown.clear()
	_tip.clear()
	_hop.clear()
	_lunge.clear()
	for child in _shots_node.get_children() + tray.get_children():
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


## One frame of `fight`, after its tick: figures, buildings, turrets and what was thrown.
func follow(fight: WarFight, delta: float) -> void:
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
	var ring := int(i / 6.0)
	var off := Vector2.ZERO if i == 0 else Vector2.from_angle(i * TAU / 6.0 + ring) * SPREAD * (1 + ring)
	var at := WarMap.point(u.pos + off)
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
			holder.rotation.y = lerp_angle(holder.rotation.y, atan2(look.x, look.y), minf(TURN_RATE * delta, 1.0))
		if u.attacking >= 0 and u.cooldown > _cooldown[i] + 0.001:
			_lunge[i] = 1.0  # It struck.
			if u.stats.range <= WarFight.MELEE:
				_sound("Strike", holder.global_position)
		_hop[i] = _hop[i] + delta * HOP_PACE if step.length() > 0.00001 else 0.0
	else:
		if _tip[i] < 1.0 and _tip[i] + delta / TIP_TIME >= 1.0:
			_sound("Topple", holder.global_position)  # It lands on its back.
		_tip[i] = minf(_tip[i] + delta / TIP_TIME, 1.0)
		_hop[i] = 0.0
	_cooldown[i] = u.cooldown
	_lunge[i] = maxf(_lunge[i] - delta * LUNGE_BACK, 0.0)
	soldier.transform = pose(soldier, _tip[i], absf(sin(_hop[i])) * HOP, _lunge[i] * LUNGE)


## A soldier's transform in its holder: `tip` 0 standing .. 1 lying on its back (pivoting on its
## base's back edge), lifted `hop` m and pushed `lunge` m forward (+Z, the way it faces).
static func pose(soldier: Node3D, tip: float, hop: float, lunge: float) -> Transform3D:
	var edge := Vector3(0.0, 0.0, back_edge(soldier))
	var fall := ease(tip, 2.4) * (PI / 2.0 + 0.08 * sin(tip * PI))
	var turn := Transform3D(Basis(Vector3.RIGHT, -fall), Vector3.ZERO)
	return Transform3D(Basis(), Vector3(0.0, hop, lunge) + edge) * turn * Transform3D(Basis.from_scale(Vector3.ONE * FIGURE_SCALE), -edge)


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
			var turret: Node3D = node.get_node("Turret")
			turret.rotation.y = lerp_angle(turret.rotation.y, _aim[i], minf(TURN_RATE * delta, 1.0))
			_recoil[i] = maxf(_recoil[i] - delta * LUNGE_BACK, 0.0)
			(turret.get_node("Mesh") as Node3D).position = Vector3(0.0, 0.0, RECOIL * _recoil[i])
	if walls_changed:
		map.show_walls(_up)


## The living unit nearest building `i` within its range (as WarFight's towers pick), or -1.
func _nearest(fight: WarFight, i: int) -> int:
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
		_puff(to, 1.0 + 2.0 * float(e.splash))
		_sound("Blast", to)
		return
	var from := spot(e.from) + Vector3.UP * 0.05
	for i in _buildings.size():  # A tower's shot: from its muzzle, and it kicks back.
		if fight.centre(i).is_equal_approx(e.from) and _buildings[i].has_node("Turret/Muzzle"):
			from = (_buildings[i].get_node("Turret/Muzzle") as Node3D).global_position
			_recoil[i] = 1.0
	for j in mini(units.size(), fight.units.size()):  # A thrower's: from its figure.
		if fight.units[j].unit == e.by and fight.units[j].pos.is_equal_approx(e.from):
			from = (units[j].get_node("Soldier/Muzzle") as Node3D).global_position if units[j].has_node("Soldier/Muzzle") else from
	var tower: bool = e.by in WarFight.DEFENCES
	_sound(("Cannon" if e.by == "cannon" else "Mortar") if tower else "Throw", from)
	_throw(from, to, float(e.travel), float(e.splash), tower)


## Throws a cabbage from `from` to `to`: a tower's (`tower`) hits a figure there, a unit's lands on the board.
func _throw(from: Vector3, to: Vector3, travel: float, splash: float, tower := false) -> void:
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
	_flying.append({body = body, from = from, to = to, t = 0.0, travel = maxf(travel, 0.12),
			height = ARC + ARC_PER_M * from.distance_to(to), splash = splash, tower = tower})


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
