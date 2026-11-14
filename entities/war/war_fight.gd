class_name WarFight
extends RefCounted
## One fight on a farm's grid (research/war-contract.md), pure and deterministic: no randomness, the
## same placements and ticks give the same fight. Like Clash of Clans: the player only places units
## on the layout's landing spots; they act on their own. PLANNING (place freely) -> start() ->
## RUNNING (placing only with mid_round) -> WON (farmhouse down) or LOST (time out, every placed
## unit down with none left to place, or retreat).
##
## Space is cell space: cell (x, y) covers x..x+1, y..y+1, so its centre is (x + 0.5, y + 0.5).
## Units move continuously in it; ranges and splash are in cells. Buildings take whole cells.
## Targeting: every unit goes by its stats' target rule (WarRules.BASE_STATS), the farmhouse only
## once every defence is down. Walls are only a goal for "wall" units; the rest path around them
## (A*, a wall cell costs WALL_COST) and hack through a wall only when it is the next cell on the
## cheapest path. Other buildings can't be walked through.

enum State {PLANNING, RUNNING, WON, LOST}
## Why the fight ended.
enum End {NONE, FARMHOUSE, TIME, WIPED, RETREAT}

const DEFENCES: Array[String] = ["cannon", "mortar"]
const WALLS: Array[String] = ["wall_wood", "wall_stone", "wall_steel"]
## Building kinds: hp, and for the towers their range (cells, centre to unit), min_range, seconds
## between shots, damage, splash radius and shot speed (cells/s: a shot lands after distance / it).
const BUILDINGS := {
	cannon = {hp = 300.0, range = 5.0, min_range = 0.0, interval = 1.0, damage = 12.0, splash = 0.0, shot_speed = 10.0},
	mortar = {hp = 250.0, range = 7.0, min_range = 2.0, interval = 4.0, damage = 20.0, splash = 1.2, shot_speed = 4.0},
	wall_wood = {hp = 150.0},
	wall_stone = {hp = 400.0},
	wall_steel = {hp = 900.0},
	farmhouse = {hp = 600.0},
}
## Path cost of a standing wall cell (an open cell costs 1): a detour of up to that many cells is
## walked instead of breaking through.
const WALL_COST := 6.0
## A unit with a range above this throws its hits (a shot event, damage after travel) instead of striking.
const MELEE := 1.5
const UNIT_SHOT_SPEED := 8.0
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
## Each {kind, cell: Vector2i, size: Vector2i, hp, max_hp, alive, cooldown}, in layout order
## (landing spots left out).
var buildings: Array[Dictionary] = []
## The landing spots' cells, in layout order (place()'s landing_index).
var landings: Array[Vector2i] = []
## Each {unit, stats, pos: Vector2, hp, max_hp, alive, target, attacking, path, cooldown, stale}:
## target is the building index it goes for, attacking the one it hits now (a wall in the way,
## or the target; -1 walking).
var units: Array[Dictionary] = []
## After the end: unit id -> figures that come home (a win's survivors, a retreat's share).
var kept := {}

var _events: Array[Dictionary] = []
## Shots in the air: {left, hits_units, index, to, damage, splash, wall_mult}.
var _flying: Array[Dictionary] = []
var _astar := AStarGrid2D.new()


## `layout`: Array of {kind, cell: Vector2i, size: Vector2i (default 1x1)}, kinds BUILDINGS' or
## "landing". `seconds`: the time limit (WarRules.fight_seconds).
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
		if entry.kind == "landing":
			landings.append(entry.cell)
			continue
		var hp: float = BUILDINGS[entry.kind].hp
		buildings.append({kind = entry.kind, cell = entry.cell, size = entry.get("size", Vector2i.ONE),
				hp = hp, max_hp = hp, alive = true, cooldown = 0.0})
		_mark(buildings.size() - 1, true)


## Puts a unit with `stats` (WarRules.unit_stats) on landing spot `landing_index`; false if placing
## isn't allowed now or there is no such spot.
func place(unit: String, stats: Dictionary, landing_index: int) -> bool:
	var open := state == State.PLANNING or (state == State.RUNNING and mid_round)
	if not open or landing_index < 0 or landing_index >= landings.size():
		return false
	units.append({unit = unit, stats = stats, pos = Vector2(landings[landing_index]) + Vector2(0.5, 0.5),
			hp = float(stats.hp), max_hp = float(stats.hp), alive = true, target = -1, attacking = -1,
			path = [], cooldown = 0.0, stale = true})
	reserve = maxi(reserve - 1, 0)
	return true


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
## the damage lands; 0 for a blast)}.
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
	var best := -1
	var best_d := INF
	for j in units.size():
		var d := from.distance_to(units[j].pos)
		if units[j].alive and d >= spec.min_range and d <= spec.range and d < best_d:
			best = j
			best_d = d
	if best < 0:
		return
	b.cooldown = spec.interval
	var travel: float = best_d / spec.shot_speed
	_events.append({kind = "shot", by = b.kind, from = from, to = units[best].pos, splash = spec.splash, travel = travel})
	_flying.append({left = travel, hits_units = true, index = best, to = units[best].pos,
			damage = spec.damage, splash = spec.splash, wall_mult = 1.0})


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
				u.hp -= shot.damage
				if u.hp <= 0.0:
					u.hp = 0.0
					u.alive = false
		return
	for i in buildings.size():
		if i == shot.index or (shot.splash > 0.0 and reach(shot.to, i) <= shot.splash):
			_hurt(i, shot.damage * (shot.wall_mult if buildings[i].kind in WALLS else 1.0))


func _hurt(i: int, damage: float) -> void:
	var b := buildings[i]
	if not b.alive:
		return
	b.hp -= damage
	if b.hp > 0.0:
		return
	b.hp = 0.0
	b.alive = false
	_mark(i, false)
	for u in units:
		u.stale = true  # The way may be shorter now.


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
	if wall >= 0 and reach(u.pos, wall) <= u.stats.range:
		_hit(u, wall)
		return
	u.attacking = -1
	_walk(u, dt)


## The building index `u` goes for by its rule: walls first for "wall" units, then the nearest
## defence, then the farmhouse; -1 if nothing stands.
func _pick(u: Dictionary) -> int:
	if u.stats.target == "wall":
		var wall := _nearest(u.pos, WALLS)
		if wall >= 0:
			return wall
	var defence := _nearest(u.pos, DEFENCES)
	return defence if defence >= 0 else _nearest(u.pos, ["farmhouse"])


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
		_events.append({kind = "explode", by = u.unit, from = u.pos, to = u.pos, splash = stats.splash, travel = 0.0})
		_strike({hits_units = false, index = i, to = u.pos, damage = stats.damage, splash = stats.splash, wall_mult = stats.wall_mult})
		u.hp = 0.0
		u.alive = false
		return
	var to := centre(i)
	var shot := {left = 0.0, hits_units = false, index = i, to = to, damage = stats.damage, splash = stats.splash, wall_mult = stats.wall_mult}
	if stats.range <= MELEE:
		_strike(shot)
		return
	shot.left = u.pos.distance_to(to) / UNIT_SHOT_SPEED
	_events.append({kind = "shot", by = u.unit, from = u.pos, to = to, splash = stats.splash, travel = shot.left})
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
		if _wall_ahead(u) >= 0:
			return  # Stop at the wall; _act hacks at it.


## Cell centres from `u`'s cell into its target (the target's own cells opened for the search).
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
	var ids := _astar.get_id_path(from, goal)
	if solid:
		for cell in _cells(u.target):
			_astar.set_point_solid(cell, true)
	var path := []
	for k in range(1, ids.size()):
		path.append(Vector2(ids[k]) + Vector2(0.5, 0.5))
	return path


func _cells(i: int) -> Array[Vector2i]:
	var b := buildings[i]
	var out: Array[Vector2i] = []
	for y in b.size.y:
		for x in b.size.x:
			out.append(Vector2i(b.cell) + Vector2i(x, y))
	return out


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
			_astar.set_point_solid(cell, standing)
