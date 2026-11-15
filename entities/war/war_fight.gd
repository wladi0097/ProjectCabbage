class_name WarFight
extends RefCounted
## One fight on a farm's grid (research/war-contract.md), pure and deterministic: no randomness, the
## same placements and ticks give the same fight. Like Clash of Clans: the player only places units,
## anywhere inside the layout's deployment zones (hatched areas of cells); they act on their own. PLANNING (place freely) -> start() ->
## RUNNING (placing only with mid_round) -> WON (farmhouse down) or LOST (time out, every placed
## unit down with none left to place, or retreat).
##
## Space is cell space: cell (x, y) covers x..x+1, y..y+1, so its centre is (x + 0.5, y + 0.5).
## Units move continuously in it; ranges and splash are in cells. Buildings take whole cells.
## Towers shoot the nearest unit in range and keep on it until it dies or leaves their range (Clash
## of Clans): figures in front draw the fire, one behind them is left alone.
## Targeting: every unit goes by its stats' target rule (WarRules.BASE_STATS), the farmhouse only
## once every defence is down. Walls are only a goal for "wall" units (restructuring charges: the
## first standing wall on their straight path to the nearest defence); the rest path around them
## (A*, a wall cell costs WALL_COST) and hack through a wall only when it is the next cell on the
## cheapest path, but for hoppers (couriers): they go straight and hop a wall cell in HOP s, leaving
## it standing. Other buildings can't be walked through.
## Defences (research/war-units.md): the shredder's shots ramp on the figure it holds (`step` more a
## shot, up to `top`; a new figure starts it over); the silo bursts when it falls (`burst`, or
## `burst_share` of a figure's full health if that is more: big figures take a big share, to every
## figure within `burst_radius` of its walls).
## Terrain (TERRAIN) is no building: never a target, never hurt, towers shoot over it. Ponds, hedges
## and rivers block every unit's way, couriers too (BLOCKING); a bridge opens its river cell again;
## roads and fields are only printed on the paper. No zone or building may stand on blocked cells
## (problems()), and no figure is placed on one.

enum State {PLANNING, RUNNING, WON, LOST}
## Why the fight ended.
enum End {NONE, FARMHOUSE, TIME, WIPED, RETREAT}

const DEFENCES: Array[String] = ["cannon", "cctv", "mortar", "sprinkler", "shredder", "silo"]
const WALLS: Array[String] = ["wall_wood", "wall_stone", "wall_steel"]
const TERRAIN: Array[String] = ["pond", "hedge", "river", "bridge", "road", "field"]
const BLOCKING: Array[String] = ["pond", "hedge", "river"]
## Building kinds: hp, and for the towers their range (cells, centre to unit), min_range, seconds
## between shots, damage, splash radius and shot speed (cells/s: a shot lands after distance / it;
## INF: at once). The shredder adds `step` and `top` (its ramp), the silo `burst`, `burst_share` and `burst_radius`.
## Stats: research/war-units.md, tuned in the balance pass 2026-11-15 (tools/battle_sim.gd --matrix,
## research/war-balance.md: every defence answerable, each a soft counter to field associates).
const BUILDINGS := {
	cannon = {hp = 250.0, range = 6.0, min_range = 0.0, interval = 1.5, damage = 50.0, splash = 0.0, shot_speed = 10.0},
	cctv = {hp = 200.0, range = 8.0, min_range = 0.0, interval = 0.4, damage = 8.0, splash = 0.0, shot_speed = 14.0},
	mortar = {hp = 250.0, range = 7.0, min_range = 2.0, interval = 4.0, damage = 40.0, splash = 1.2, shot_speed = 4.0},
	sprinkler = {hp = 400.0, range = 2.5, min_range = 0.0, interval = 0.8, damage = 22.0, splash = 1.0, shot_speed = INF},
	shredder = {hp = 400.0, range = 3.0, min_range = 0.0, interval = 0.5, damage = 2.0, splash = 0.0, shot_speed = INF, step = 3.0, top = 36.0},
	silo = {hp = 350.0, range = 4.0, min_range = 0.0, interval = 3.0, damage = 20.0, splash = 1.0, shot_speed = 5.0, burst = 100.0, burst_share = 0.7, burst_radius = 1.0},
	wall_wood = {hp = 150.0},
	wall_stone = {hp = 500.0},
	wall_steel = {hp = 900.0},
	farmhouse = {hp = 600.0},
}
## Path cost of a standing wall cell (an open cell costs 1): a detour of up to that many cells is
## walked instead of breaking through.
const WALL_COST := 6.0
## Seconds a hopper (courier) takes to cross one wall cell.
const HOP := 0.5
## A unit with a range above this throws its hits (a shot event, damage after travel) instead of striking.
const MELEE := 1.5
const UNIT_SHOT_SPEED := 8.0
## A figure dropped this close to a deployment zone (cells) slides into it (snap), this far inside.
const SNAP := 1.0
const INSET := 0.3
## tick() advances in steps of at most this many seconds.
const STEP := 0.05

var state := State.PLANNING
var end := End.NONE
var grid_size := Vector2i.ZERO
var time_limit := 0.0
var elapsed := 0.0
## Units may be placed while RUNNING (WarRules.can_place_mid_round).
var mid_round := false
## Figures still in the tray that could be placed mid-round: the scene sets it, place() counts it
## down. With mid_round and some left, losing every placed unit doesn't lose the fight.
var reserve := 0
## Each {kind, cell: Vector2i, size: Vector2i, hp, max_hp, alive, cooldown, target, streak}, in
## layout order (zones left out); a tower's target is the unit index it shoots at (-1: none), its
## streak the shots in a row on it (the shredder's ramp).
var buildings: Array[Dictionary] = []
## The deployment zones (cells), in layout order: a unit may only be placed inside one.
var zones: Array[Rect2i] = []
## The terrain pieces, in layout order: each {kind, cell: Vector2i, size: Vector2i}.
var terrain: Array[Dictionary] = []
## Each {unit, stats, pos: Vector2, hp, max_hp, alive, target, attacking, path, cooldown, stale,
## hop_cell, hop_left}: target is the building index it goes for, attacking the one it hits now (a
## wall in the way, or the target; -1 walking); a hopper's hop_cell is the wall cell it is crossing
## or has crossed last, hop_left the seconds of the hop to go.
var units: Array[Dictionary] = []
## After the end: unit id -> figures that come home (a win's survivors, a retreat's share).
var kept := {}

var _events: Array[Dictionary] = []
## Shots in the air: {left, hits_units, index, to, damage, splash, wall_mult, walls (a unit's splash
## hurts walls: only the charge's blast)}.
var _flying: Array[Dictionary] = []
var _astar := AStarGrid2D.new()
## Cells no unit may enter (blocking terrain less the bridges) -> true.
var _blocked := {}


## `layout`: Array of {kind, cell: Vector2i, size: Vector2i (default 1x1)}, kinds BUILDINGS' or
## "zone" (a deployment zone, `size` its cells). `seconds`: the time limit (WarRules.fight_seconds).
func _init(layout: Array, size: Vector2i, seconds: float, place_mid_round := false) -> void:
	grid_size = size
	time_limit = seconds
	mid_round = place_mid_round
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for entry: Dictionary in layout:
		if entry.kind == "zone":
			zones.append(Rect2i(entry.cell, entry.get("size", Vector2i.ONE)))
			continue
		if entry.kind in TERRAIN:
			terrain.append({kind = entry.kind, cell = entry.cell, size = entry.get("size", Vector2i.ONE)})
			continue
		var hp: float = BUILDINGS[entry.kind].hp
		buildings.append({kind = entry.kind, cell = entry.cell, size = entry.get("size", Vector2i.ONE),
				hp = hp, max_hp = hp, alive = true, cooldown = 0.0, target = -1, streak = 0})
		_mark(buildings.size() - 1, true)
	_blocked = blocked_cells(layout)
	for cell: Vector2i in _blocked:
		if _astar.is_in_boundsv(cell):
			_astar.set_point_solid(cell, true)


## The cells `layout`'s blocking terrain covers, less its bridges' (cell -> true).
static func blocked_cells(layout: Array) -> Dictionary:
	var out := {}
	for kinds: Array in [BLOCKING, ["bridge"]]:
		for entry: Dictionary in layout:
			if entry.kind in kinds:
				for cell in _rect_cells(entry):
					if kinds == BLOCKING:
						out[cell] = true
					else:
						out.erase(cell)
	return out


## What is wrong with `layout`, one line each (empty: nothing): a zone or a building on blocked cells,
## a bridge off the river.
static func problems(layout: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var closed := blocked_cells(layout)
	var river := {}
	for entry: Dictionary in layout:
		if entry.kind == "river":
			for cell in _rect_cells(entry):
				river[cell] = true
	for entry: Dictionary in layout:
		var cells := _rect_cells(entry)
		if entry.kind not in TERRAIN and cells.any(func(c: Vector2i) -> bool: return closed.has(c)):
			out.append("%s@%d,%d stands on blocking terrain" % [entry.kind, entry.cell.x, entry.cell.y])
		elif entry.kind == "bridge" and not cells.all(func(c: Vector2i) -> bool: return river.has(c)):
			out.append("bridge@%d,%d is not on a river" % [entry.cell.x, entry.cell.y])
	return out


static func _rect_cells(entry: Dictionary) -> Array[Vector2i]:
	var size: Vector2i = entry.get("size", Vector2i.ONE)
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(Vector2i(entry.cell) + Vector2i(x, y))
	return out


## Whether no unit may enter `cell` (blocking terrain, no bridge on it).
func blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


## Puts a unit with `stats` (WarRules.unit_stats) at cell-space point `pos`; false if placing isn't
## allowed now or `pos` lies in no deployment zone (or on blocked terrain).
func place_at(unit: String, stats: Dictionary, pos: Vector2) -> bool:
	var open := state == State.PLANNING or (state == State.RUNNING and mid_round)
	if not open or not in_zone(pos) or blocked(Vector2i(pos.floor())):
		return false
	units.append({unit = unit, stats = stats, pos = pos, hp = float(stats.hp), max_hp = float(stats.hp),
			alive = true, target = -1, attacking = -1, path = [], cooldown = 0.0, stale = true,
			hop_cell = Vector2i(-1, -1), hop_left = 0.0})
	reserve = maxi(reserve - 1, 0)
	return true


## place_at the middle of zone `zone` (false: no such zone).
func place(unit: String, stats: Dictionary, zone: int) -> bool:
	return zone >= 0 and zone < zones.size() and place_at(unit, stats, Rect2(zones[zone]).get_center())


## Whether cell-space point `p` lies inside a deployment zone.
func in_zone(p: Vector2) -> bool:
	return zones.any(func(z: Rect2i) -> bool: return Rect2(z).has_point(p))


## Where a figure dropped at cell-space point `p` stands: `p` inside a zone; near
## one (`within`), the nearest point INSET cells inside it; else Vector2.INF (it is in no zone).
func snap(p: Vector2, within := SNAP) -> Vector2:
	if in_zone(p):
		return p
	var best := Vector2.INF
	for z in zones:
		var whole := Rect2(z)
		var inner := whole.grow(-INSET)
		var at := p.clamp(inner.position, inner.end)
		if p.distance_to(p.clamp(whole.position, whole.end)) <= within and p.distance_to(at) < p.distance_to(best):
			best = at
	return best


## Starts the fight; false if it already started or no unit is placed.
func start() -> bool:
	if state != State.PLANNING or units.is_empty():
		return false
	state = State.RUNNING
	return true


func tick(delta: float) -> void:
	while state == State.RUNNING and delta > 0.0:
		var dt := minf(delta, STEP)
		delta -= dt
		_step(dt)


func time_left() -> float:
	return maxf(time_limit - elapsed, 0.0)


## Ends a running fight LOST by retreat: per unit type, floor(alive placed figures * share) come home
## (in `kept`, also returned). {} and nothing changes if the fight isn't running.
func retreat(share: float) -> Dictionary:
	if state != State.RUNNING:
		return {}
	kept = {}
	var alive := survivors()
	for unit: String in alive:
		var saved := floori(alive[unit] * share + 0.0001)  # 10 * 0.3 is 2.9999...
		if saved > 0:
			kept[unit] = saved
	state = State.LOST
	end = End.RETREAT
	return kept


## Unit id -> placed figures still alive.
func survivors() -> Dictionary:
	var alive := {}
	for u in units:
		if u.alive:
			alive[u.unit] = int(alive.get(u.unit, 0)) + 1
	return alive


## The shots and blasts since the last call, oldest first, each {kind: "shot" or "explode", by
## (building kind or unit id), from: Vector2, to: Vector2 (cell space), splash, travel (s until
## the damage lands; 0 for a blast), damage}. "explode": a charge blew up, or a silo burst.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


## Distance from point `p` to building `index`'s edge (0 inside it).
func reach(p: Vector2, index: int) -> float:
	var b := buildings[index]
	var rect := Rect2(Vector2(b.cell), Vector2(b.size))
	return p.distance_to(p.clamp(rect.position, rect.end))


func centre(index: int) -> Vector2:
	var b := buildings[index]
	return Vector2(b.cell) + Vector2(b.size) / 2.0


func _step(dt: float) -> void:
	elapsed += dt
	_land(dt)
	for i in buildings.size():
		_tower(i, dt)
	for u in units:
		if u.alive:
			_act(u, dt)
	_judge()


func _judge() -> void:
	if not buildings.any(func(b: Dictionary) -> bool: return b.kind == "farmhouse" and b.alive):
		state = State.WON
		end = End.FARMHOUSE
		kept = survivors()
	elif elapsed >= time_limit - 0.0001:
		state = State.LOST
		end = End.TIME
	elif survivors().is_empty() and (not mid_round or reserve == 0):
		state = State.LOST
		end = End.WIPED


func _tower(i: int, dt: float) -> void:
	var b := buildings[i]
	if not b.alive or b.kind not in DEFENCES:
		return
	b.cooldown = maxf(b.cooldown - dt, 0.0)
	if b.cooldown > 0.0:
		return
	var spec: Dictionary = BUILDINGS[b.kind]
	var from := centre(i)
	var best: int = b.target if b.target >= 0 and _in_range(units[b.target], from, spec) else -1
	if best < 0:
		var near := INF
		for j in units.size():
			var d := from.distance_to(units[j].pos)
			if _in_range(units[j], from, spec) and d < near:
				best = j
				near = d
	b.streak = b.streak + 1 if best == b.target and best >= 0 else 0
	b.target = best
	if best < 0:
		return
	var best_d := from.distance_to(units[best].pos)
	b.cooldown = spec.interval
	var travel: float = best_d / spec.shot_speed
	var damage: float = minf(spec.damage + spec.get("step", 0.0) * b.streak, spec.get("top", INF))
	_events.append({kind = "shot", by = b.kind, from = from, to = units[best].pos, splash = spec.splash, travel = travel, damage = damage})
	var shot := {left = travel, hits_units = true, index = best, to = units[best].pos,
			damage = damage, splash = spec.splash, wall_mult = 1.0, walls = false}
	if travel <= 0.0:
		_strike(shot)  # Lands at once (the sprinkler's spray, the shredder).
	else:
		_flying.append(shot)


func _in_range(u: Dictionary, from: Vector2, spec: Dictionary) -> bool:
	var d := from.distance_to(u.pos)
	return u.alive and d >= spec.min_range and d <= spec.range


func _land(dt: float) -> void:
	var still: Array[Dictionary] = []
	for shot in _flying:
		shot.left -= dt
		if shot.left <= 0.0:
			_strike(shot)
		else:
			still.append(shot)
	_flying = still


## Deals a shot's damage: to units (a tower's; the cannon's follows its unit) or buildings (a unit's).
func _strike(shot: Dictionary) -> void:
	if shot.hits_units:
		for j in units.size():
			var u := units[j]
			if u.alive and (j == shot.index if shot.splash <= 0.0 else u.pos.distance_to(shot.to) <= shot.splash):
				_wound(u, shot.damage)
		return
	for i in buildings.size():
		var wall: bool = buildings[i].kind in WALLS
		if i == shot.index or (shot.splash > 0.0 and reach(shot.to, i) <= shot.splash and (shot.walls or not wall)):
			_hurt(i, shot.damage * (shot.wall_mult if wall else 1.0))


func _wound(u: Dictionary, damage: float) -> void:
	u.hp -= damage
	if u.hp <= 0.0:
		u.hp = 0.0
		u.alive = false


func _hurt(i: int, damage: float) -> void:
	var b := buildings[i]
	if not b.alive:
		return
	if b.kind == "farmhouse" and buildings.any(func(d: Dictionary) -> bool: return d.alive and d.kind in DEFENCES):
		return  # The farmhouse falls last: splash and blasts don't touch it while a defence stands.
	b.hp -= damage
	if b.hp > 0.0:
		return
	b.hp = 0.0
	b.alive = false
	_mark(i, false)
	for u in units:
		u.stale = true  # The way may be shorter now.
	var spec: Dictionary = BUILDINGS[b.kind]
	if spec.has("burst"):  # The silo takes everyone beside it along.
		_events.append({kind = "explode", by = b.kind, from = centre(i), to = centre(i),
				splash = spec.burst_radius + Vector2(b.size).x / 2.0, travel = 0.0, damage = spec.burst})
		for u in units:
			if u.alive and reach(u.pos, i) <= spec.burst_radius:
				_wound(u, maxf(spec.burst, spec.get("burst_share", 0.0) * u.max_hp))


func _act(u: Dictionary, dt: float) -> void:
	u.cooldown = maxf(u.cooldown - dt, 0.0)
	if u.target < 0 or not buildings[u.target].alive:
		u.target = _pick(u)
		u.stale = true
	if u.target < 0:
		u.attacking = -1
		return
	if u.stale:
		u.path = _path(u)
		u.stale = false
	if reach(u.pos, u.target) <= u.stats.range:
		_hit(u, u.target)
		return
	var wall := _wall_ahead(u)
	u.attacking = -1
	if wall >= 0 and u.stats.get("hops", false):
		var cell := Vector2i((u.path[0] as Vector2).floor())
		if u.hop_cell != cell:  # Up and over: HOP s, the fence left as it stands.
			u.hop_cell = cell
			u.hop_left = HOP
		if u.hop_left > 0.0:
			u.hop_left -= dt
			return
	elif wall >= 0 and reach(u.pos, wall) <= u.stats.range:
		_hit(u, wall)
		return
	_walk(u, dt)


## The building index `u` goes for by its rule: the nearest defence, then the farmhouse; for "wall"
## units the first standing wall on their straight way there (walls at cost 1), if any; -1 if
## nothing stands.
func _pick(u: Dictionary) -> int:
	var defence := _nearest(u.pos, DEFENCES)
	if defence < 0:
		defence = _nearest(u.pos, ["farmhouse"])
	if defence < 0 or u.stats.target != "wall":
		return defence
	u.target = defence
	for p: Vector2 in _path(u):
		var wall := _wall_at(Vector2i(p.floor()))
		if wall >= 0:
			return wall
	return defence


func _nearest(p: Vector2, kinds: Array[String]) -> int:
	var best := -1
	var best_d := INF
	for i in buildings.size():
		if buildings[i].alive and buildings[i].kind in kinds and reach(p, i) < best_d:
			best = i
			best_d = reach(p, i)
	return best


## The standing wall in the next cell of `u`'s path, or -1.
func _wall_ahead(u: Dictionary) -> int:
	if u.path.is_empty():
		return -1
	return _wall_at(Vector2i((u.path[0] as Vector2).floor()))


func _wall_at(cell: Vector2i) -> int:
	for i in buildings.size():
		var b := buildings[i]
		if b.alive and b.kind in WALLS and Rect2i(b.cell, b.size).has_point(cell):
			return i
	return -1


func _hit(u: Dictionary, i: int) -> void:
	u.attacking = i
	if u.cooldown > 0.0:
		return
	u.cooldown = u.stats.interval
	var stats: Dictionary = u.stats
	if stats.target == "wall":  # Blows up on contact and is gone.
		_events.append({kind = "explode", by = u.unit, from = u.pos, to = u.pos, splash = stats.splash, travel = 0.0, damage = stats.damage})
		_strike({hits_units = false, index = i, to = u.pos, damage = stats.damage, splash = stats.splash, wall_mult = stats.wall_mult, walls = true})
		u.hp = 0.0
		u.alive = false
		return
	var to := centre(i)
	var shot := {left = 0.0, hits_units = false, index = i, to = to, damage = stats.damage, splash = stats.splash,
			wall_mult = stats.wall_mult, walls = false}
	if stats.range <= MELEE:
		_strike(shot)
		return
	shot.left = u.pos.distance_to(to) / UNIT_SHOT_SPEED
	_events.append({kind = "shot", by = u.unit, from = u.pos, to = to, splash = stats.splash, travel = shot.left, damage = stats.damage})
	_flying.append(shot)


func _walk(u: Dictionary, dt: float) -> void:
	if u.path.is_empty():
		u.stale = true  # No way there right now: look again next step.
		return
	var left: float = u.stats.speed * dt
	while left > 0.0 and not u.path.is_empty():
		var to: Vector2 = u.path[0]
		var d: float = u.pos.distance_to(to)
		if d > left:
			u.pos += (to - u.pos) / d * left
			return
		u.pos = to
		left -= d
		u.path.pop_front()
		if _wall_ahead(u) >= 0 and Vector2i((u.path[0] as Vector2).floor()) != u.hop_cell:
			return  # Stop at the wall; _act hacks at it (or hops it).


## Cell centres from `u`'s cell into its target (the target's own cells opened for the search).
## Charges and hoppers go straight: walls cost them no more than open ground.
func _path(u: Dictionary) -> Array:
	var b := buildings[u.target]
	var from := Vector2i(u.pos.floor()).clamp(Vector2i.ZERO, grid_size - Vector2i.ONE)
	var goal: Vector2i = b.cell
	for cell in _cells(u.target):
		if (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(u.pos) < (Vector2(goal) + Vector2(0.5, 0.5)).distance_to(u.pos):
			goal = cell
	var solid: bool = b.kind not in WALLS
	if solid:
		for cell in _cells(u.target):
			_astar.set_point_solid(cell, false)
	var straight: bool = u.stats.target == "wall" or u.stats.get("hops", false)
	if straight:
		_wall_weights(1.0)
	var ids := _astar.get_id_path(from, goal)
	if straight:
		_wall_weights(WALL_COST)
	if solid:
		for cell in _cells(u.target):
			_astar.set_point_solid(cell, true)
	var path := []
	for k in range(1, ids.size()):
		path.append(Vector2(ids[k]) + Vector2(0.5, 0.5))
	return path


## Every standing wall cell's path cost set to `cost`.
func _wall_weights(cost: float) -> void:
	for i in buildings.size():
		if buildings[i].alive and buildings[i].kind in WALLS:
			for cell in _cells(i):
				if _astar.is_in_boundsv(cell):
					_astar.set_point_weight_scale(cell, cost)


func _cells(i: int) -> Array[Vector2i]:
	return _rect_cells(buildings[i])


## Puts building `i`'s cells into the path grid (a wall costs WALL_COST, the rest are solid) or
## clears them once it is down.
func _mark(i: int, standing: bool) -> void:
	var wall: bool = buildings[i].kind in WALLS
	for cell in _cells(i):
		if not _astar.is_in_boundsv(cell):
			continue
		if wall:
			_astar.set_point_weight_scale(cell, WALL_COST if standing else 1.0)
		else:
			_astar.set_point_solid(cell, standing or _blocked.has(cell))
