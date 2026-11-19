class_name BattleSim
extends RefCounted
## One WarFight played out from an army plan, with a timeline of what happened: the pure entry of
## the battle calculator (tools/battle_sim.gd prints it; tests call run()). Not used in play.
##
## A plan is an Array of {unit, count (1), at (s after START, 0), pos: Vector2 (cell-space point)
## or zone: int (+ offset: Vector2 from the zone's middle)}. Entries are placed in plan order, so
## of figures standing equally near a tower the first placed draws its fire.
## Both can be written as text (parse_layout(), parse_plan()): scenarios need no scene file.

## The calculator's short unit names.
const ALIAS := {fa = "field_associate", rc = "restructuring_charge", sa = "senior_asset", pc = "pult_crew", cr = "courier"}
## Terrain kinds that come in 1-cell pieces (like walls): a hedge joins its neighbours like a fence.
const ONE_CELL: Array[String] = ["hedge", "bridge"]


## A layout from text: pieces separated by ";", each "KIND@X,Y" or "KIND@X,Y,WxH". The footprint is
## the kind's (WarMap.SIZES) unless WxH is given; a zone is WxH cells (1x1); walls, hedges and bridges
## fill every cell of WxH (a line or a block of 1-cell pieces); ponds, rivers, roads and fields are one
## WxH rectangle each (WarFight.TERRAIN). Example: "farmhouse@14,4; shredder@9,5;
## wall_stone@7,0,1x11; zone@0,3,3x5; river@5,0,1x11; bridge@5,5; pond@11,1,3x2; hedge@8,8,4x1".
static func parse_layout(text: String) -> Array:
	var out := []
	for part in text.split(";", false):
		var bits := part.strip_edges().split("@")
		var kind := bits[0].strip_edges()
		var xy := bits[1].split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		var size := WarMap.size_of(kind)
		if xy.size() > 2:
			var wh := xy[2].split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		if kind in WarFight.WALLS or kind in ONE_CELL:
			for y in size.y:
				for x in size.x:
					out.append({kind = kind, cell = cell + Vector2i(x, y), size = Vector2i.ONE})
		else:
			out.append({kind = kind, cell = cell, size = size})
	return out


## A plan from text: entries separated by ";", each "TYPE [xN] [@WHERE] [tSECONDS]": TYPE a short
## name (ALIAS) or the full id; xN how many (1); WHERE z0 (zone 0's middle, the default), z0+1,-0.5
## (an offset in cells from it) or 3.5,5.5 (a cell-space point); tS dropped S s after START (0).
static func parse_plan(text: String) -> Array:
	var out := []
	for part in text.split(";", false):
		var entry := {zone = 0}
		for word in part.strip_edges().split(" ", false):
			if word.begins_with("x") and word.substr(1).is_valid_int():
				entry.count = int(word.substr(1))
			elif word.begins_with("t") and word.substr(1).is_valid_float():
				entry.at = float(word.substr(1))
			elif word.begins_with("@z"):
				var rest := word.substr(2)
				var cut := rest.find("+") if rest.find("+") >= 0 else rest.find("-")
				entry.zone = int(rest if cut < 0 else rest.substr(0, cut))
				if cut >= 0:
					var xy := rest.substr(cut + int(rest[cut] == "+")).split(",")
					entry.offset = Vector2(float(xy[0]), float(xy[1]))
			elif word.begins_with("@"):
				var xy := word.substr(1).split(",")
				entry.erase("zone")
				entry.pos = Vector2(float(xy[0]), float(xy[1]))
			else:
				entry.unit = ALIAS.get(word, word)
		out.append(entry)
	return out


## Plays `plan` on `layout` (WarMap.layout) and returns {won, end (WarFight.End), seconds,
## events, survivors (unit id -> count), buildings: [{kind, cell, dealt, alive}], units: [{unit, hp,
## max_hp, alive}] (placing order), top (shooter -> its hardest single hit), refused}.
## events, oldest first: {t, what ("died", "down"), kind (unit id or building kind), index,
## cell: Vector2i, by (a dead unit's: the building kind it was hitting, "" walking), hp (a dead
## unit's hp the step before: a charge that blew up at full health has its max_hp here)}.
## `research`: depot node ids bought (unit research and GENERAL ids such as war_drill_n); `k`: defences k times as strong (building hp x k, unit hp / k
## for the towers' damage x k: tools/pace.py's strength model); `seconds`: the time limit.
static func run(layout: Array, grid_size: Vector2i, plan: Array, research := PackedStringArray(),
		k := 1.0, seconds := WarRules.BASE_FIGHT) -> Dictionary:
	var fight := WarFight.new(layout, grid_size, seconds)
	for b in fight.buildings:
		b.hp *= k
		b.max_hp *= k
	var save := SaveGame.new()
	save.unit_research = research
	save.tree_bought = research
	var drops := []  # [at, unit, stats, pos], in plan order
	for entry: Dictionary in plan:
		var stats := WarRules.unit_stats(save, entry.unit)
		stats.hp = float(stats.hp) / k
		var pos: Vector2 = entry.get("pos", Vector2.INF)
		if entry.has("zone"):
			pos = Rect2(fight.zones[entry.zone]).get_center() + entry.get("offset", Vector2.ZERO)
		for i in int(entry.get("count", 1)):
			drops.append([float(entry.get("at", 0.0)), entry.unit, stats, pos])
	var later := drops.filter(func(d: Array) -> bool: return d[0] > 0.0 and d[0] < seconds)
	# A drop due at or past the time limit is never placed: refused, and not held in reserve.
	var refused := drops.filter(func(d: Array) -> bool: return d[0] >= seconds).size()
	for d: Array in drops:
		if d[0] <= 0.0 and not fight.place_at(d[1], d[2], d[3]):
			refused += 1
	fight.mid_round = not later.is_empty()  # Drops after START: placing stays open for them.
	fight.reserve = later.size()
	var events: Array[Dictionary] = []
	var top := {}
	if fight.start():
		var units_up: Array = []
		var houses_up: Array = fight.buildings.map(func(b: Dictionary) -> bool: return b.alive)
		while fight.state == WarFight.State.RUNNING:
			for d: Array in later:
				if d[0] > fight.elapsed - 0.0001 and d[0] <= fight.elapsed + WarFight.STEP - 0.0001:
					if not fight.place_at(d[1], d[2], d[3]):
						refused += 1
						fight.reserve = maxi(fight.reserve - 1, 0)
			while units_up.size() < fight.units.size():
				units_up.append(true)
			var hp_before: Array = fight.units.map(func(u: Dictionary) -> float: return u.hp)
			fight.tick(WarFight.STEP)
			for shot: Dictionary in fight.take_events():
				top[shot.by] = maxf(float(top.get(shot.by, 0.0)), float(shot.damage))
			for j in fight.units.size():
				var u: Dictionary = fight.units[j]
				if units_up[j] and not u.alive:
					units_up[j] = false
					var by: String = fight.buildings[u.attacking].kind if u.attacking >= 0 else ""
					events.append({t = fight.elapsed, what = "died", kind = u.unit, index = j, cell = Vector2i(u.pos.floor()), by = by,
							hp = hp_before[j] if j < hp_before.size() else u.max_hp})
			for i in fight.buildings.size():
				var b: Dictionary = fight.buildings[i]
				if houses_up[i] and not b.alive:
					houses_up[i] = false
					events.append({t = fight.elapsed, what = "down", kind = b.kind, index = i, cell = b.cell, by = "", hp = 0.0})
	var buildings := []
	for b in fight.buildings:
		buildings.append({kind = b.kind, cell = b.cell, dealt = b.max_hp - b.hp, alive = b.alive})
	var units := []
	for u in fight.units:
		units.append({unit = u.unit, hp = u.hp, max_hp = u.max_hp, alive = u.alive})
	return {won = fight.state == WarFight.State.WON, end = fight.end, seconds = fight.elapsed,
			events = events, survivors = fight.survivors(), buildings = buildings, units = units, top = top, refused = refused}


## The fewest groups of `plan` (its counts times n, n = 1..most) that win; 0 if none does.
static func fewest(layout: Array, grid_size: Vector2i, plan: Array, research := PackedStringArray(),
		k := 1.0, seconds := WarRules.BASE_FIGHT, most := 40) -> int:
	for n in range(1, most + 1):
		var scaled := plan.map(func(e: Dictionary) -> Dictionary:
			var c := e.duplicate()
			c.count = int(e.get("count", 1)) * n
			return c)
		if run(layout, grid_size, scaled, research, k, seconds).won:
			return n
	return 0


# ---- The map difficulty calculator (research/war-balance.md).

## Playstyles: army templates scaled by a count n; each part [unit, figures per n] (at least 1).
## Figures stand in rows by DEPTH (toward the enemy: the front draws the fire), side by side.
const PLAYSTYLES := {
	associates = [["field_associate", 1.0]],
	charge = [["field_associate", 1.0], ["restructuring_charge", 0.25]],
	tank = [["senior_asset", 0.25], ["field_associate", 1.0]],
	artillery = [["field_associate", 0.5], ["pult_crew", 1.0]],
	couriers = [["courier", 1.0]],
	charges = [["restructuring_charge", 1.0]],
	seniors = [["senior_asset", 1.0]],
	pults = [["pult_crew", 1.0]],
}
## Cells from the zone's middle toward the enemy, per unit: tanks in front, charges and pults behind.
const DEPTH := {senior_asset = 1.2, courier = 0.5, field_associate = 0.0, restructuring_charge = -1.0, pult_crew = -1.2}
## Cells between figures of one row.
const ROW_GAP := 0.5
## Research levels: none, the first node of every tree, every node of chapter 3, and nuclear:
## chapter 4's too (the CIVIL UNREST `card` nodes and the DRILL chain).
const LEVELS: Array[String] = ["none", "some", "full", "nuclear"]


## The depot nodes of research level `level` (LEVELS).
static func research_for(level: String) -> PackedStringArray:
	var out := PackedStringArray()
	for node in WarRules.RESEARCH:
		if level == "nuclear" or (level == "full" and not node.has("card")) or (level == "some" and node.parent == ""):
			out.append(node.id)
	if level == "nuclear":
		out.append_array(["war_drill_1", "war_drill_2", "war_drill_3"])
	return out


## The army cap that goes with a research level: the base; BIGGER ARMIES and one war_cap node;
## chapter 3's three; nuclear: all five.
static func cap_for(level: String) -> int:
	var save := SaveGame.new()
	if level != "none":
		save.stamped = PackedStringArray(["bigger_armies"])
		save.tree_bought = PackedStringArray(["war_cap_1"] if level == "some" else ["war_cap_1", "war_cap_2", "war_cap_3"])
		if level == "nuclear":
			save.tree_bought.append_array(["war_cap_4", "war_cap_5"])
	return WarRules.army_cap(save)


## Unit id -> figures of playstyle `style` at count n.
static func army_of(style: String, n: int) -> Dictionary:
	var army := {}
	for part: Array in PLAYSTYLES[style]:
		army[part[0]] = maxi(1, ceili(n * float(part[1]) - 0.0001))
	return army


## A plan placing `army` (unit id -> count) in the zones `use` (indices): figure by figure round the
## zones, in rows by DEPTH toward the defences (or the farmhouse), side by side ROW_GAP apart, kept
## INSET inside the zone; the front rows first.
static func plan_for(army: Dictionary, layout: Array, use: Array) -> Array:
	var zones := layout.filter(func(e: Dictionary) -> bool: return e.kind == "zone")
	var aim := Vector2.ZERO
	var count := 0
	for kinds: Array in [WarFight.DEFENCES, ["farmhouse"]]:
		if count == 0:
			for e: Dictionary in layout:
				if e.kind in kinds:
					aim += Vector2(e.cell) + Vector2(e.get("size", Vector2i.ONE)) / 2.0
					count += 1
	aim /= maxi(count, 1)
	var per_zone := {}  # zone -> unit -> count
	var turn := 0
	for unit: String in WarRules.UNITS:
		for i in int(army.get(unit, 0)):
			var z: int = use[turn % use.size()]
			turn += 1
			if not per_zone.has(z):
				per_zone[z] = {}
			per_zone[z][unit] = int(per_zone[z].get(unit, 0)) + 1
	var plan := []
	for z: int in per_zone:
		var rect := Rect2(zones[z].cell, zones[z].get("size", Vector2i.ONE))
		var mid := rect.get_center()
		var ahead := (aim - mid).normalized() if aim != mid else Vector2.RIGHT
		var side := Vector2(-ahead.y, ahead.x)
		var inner := rect.grow(-WarFight.INSET)
		for unit: String in per_zone[z]:
			var m: int = per_zone[z][unit]
			for i in m:
				var p: Vector2 = mid + ahead * float(DEPTH[unit]) + side * (i - (m - 1) / 2.0) * ROW_GAP
				plan.append({unit = unit, pos = p.clamp(inner.position, inner.end)})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DEPTH[a.unit] > DEPTH[b.unit])
	return plan


## {cabbages, places} of `army` (unit id -> figures).
static func army_cost(army: Dictionary) -> Dictionary:
	var cabbages := 0
	var places := 0
	for unit: String in army:
		cabbages += int(army[unit]) * WarRules.unit_cabbage_price(unit)
		places += int(army[unit]) * WarRules.unit_space(unit)
	return {cabbages = cabbages, places = places}


## One try of `army` from zones `use`: {won, seconds, lost (unit id -> figures), lost_cabbages}.
## goal "defences": won once every defence is down (seconds: the last one's fall), else the farmhouse.
static func trial(layout: Array, grid: Vector2i, army: Dictionary, use: Array, options := {}) -> Dictionary:
	var r := run(layout, grid, plan_for(army, layout, use), options.get("research", PackedStringArray()),
			options.get("k", 1.0), options.get("seconds", WarRules.BASE_FIGHT))
	var won: bool = r.won
	var until: float = r.seconds
	if options.get("goal", "farmhouse") == "defences" and r.buildings.any(func(b: Dictionary) -> bool: return b.kind in WarFight.DEFENCES):
		won = r.buildings.all(func(b: Dictionary) -> bool: return b.kind not in WarFight.DEFENCES or not b.alive)
		until = 0.0
		for e: Dictionary in r.events:
			if e.what == "down" and e.kind in WarFight.DEFENCES:
				until = maxf(until, e.t)
	var lost := {}
	var lost_cabbages := 0
	for e: Dictionary in r.events:
		if e.what == "died" and (not won or e.t <= until + 0.0001):
			lost[e.kind] = int(lost.get(e.kind, 0)) + 1
			lost_cabbages += WarRules.unit_cabbage_price(e.kind)
	return {won = won, seconds = until if won else r.seconds, lost = lost, lost_cabbages = lost_cabbages}


## The ways to set an army down: each zone alone, then spread over all of them.
static func zone_choices(layout: Array) -> Array:
	var count := layout.filter(func(e: Dictionary) -> bool: return e.kind == "zone").size()
	var out := []
	for z in count:
		out.append([z])
	if count > 1:
		out.append(range(count))
	return out


## Whether entry `a` is a cheaper win than `b` (cabbages, then places, then cabbages lost).
static func cheaper(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty() or not b.won:
		return a.get("won", false)
	return a.get("won", false) and [a.cabbages, a.places, a.lost_cabbages] < [b.cabbages, b.places, b.lost_cabbages]


static func _entry(style: String, army: Dictionary, use: Array, t: Dictionary, cap: int) -> Dictionary:
	var cost := army_cost(army)
	var figures := 0
	for unit: String in army:
		figures += int(army[unit])
	return {style = style, won = t.won, army = army, cabbages = cost.cabbages, places = cost.places, figures = figures,
			zones = use, seconds = t.seconds, lost = t.lost, lost_cabbages = t.lost_cabbages, fits = cost.places <= cap}


## The cheapest winning army of playstyle `style`: per zone choice the fewest n (1..most) that wins,
## the cheapest of those; {} when none does.
static func cheapest(layout: Array, grid: Vector2i, style: String, options := {}) -> Dictionary:
	var best := {}
	for use: Array in zone_choices(layout):
		for n in range(1, int(options.get("most", 30)) + 1):
			var army := army_of(style, n)
			if not best.is_empty() and army_cost(army).cabbages > best.cabbages:
				break
			var t := trial(layout, grid, army, use, options)
			if t.won:
				var e := _entry(style, army, use, t, options.get("cap", 99))
				if cheaper(e, best):
					best = e
				break
	return best


## Improves winning army `start` one step at a time while it still wins for less (cabbages, then
## places): one figure dropped, or one or two figures swapped for one of another type in `units`.
static func refine(layout: Array, grid: Vector2i, start: Dictionary, units: Array, options := {}) -> Dictionary:
	var best := start
	var better := true
	while better:
		better = false
		var tries := []
		for unit: String in best.army:
			var less: Dictionary = best.army.duplicate()
			less[unit] -= 1
			tries.append(less)
			for other: String in units:
				for give in [1, 2]:
					if other != unit and best.army[unit] >= give:
						var swap: Dictionary = best.army.duplicate()
						swap[unit] -= give
						swap[other] = int(swap.get(other, 0)) + 1
						tries.append(swap)
		for army: Dictionary in tries:
			for unit: String in army.keys():
				if army[unit] <= 0:
					army.erase(unit)
			var cost := army_cost(army)
			if army.is_empty() or [cost.cabbages, cost.places] >= [best.cabbages, best.places]:
				continue
			for use: Array in zone_choices(layout):
				var t := trial(layout, grid, army, use, options)
				if t.won:
					best = _entry("mixed", army, use, t, options.get("cap", 99))
					better = true
					break
			if better:
				break
	return best


## The map difficulty calculator: every playstyle the units in `options.units` (default all) can
## play on `layout`, each its cheapest winning army, then a mixed army refined from the three cheapest.
## options: units, level (LEVELS: sets research and cap), research (node ids), cap, k, seconds, goal
## ("farmhouse"; "defences": won once every defence is down), most (the largest n tried, 30).
## Returns {styles: [entries, the winners cheapest first, then the styles that never won ({style,
## won false})], best (the cheapest entry, {} if none), cap, level, k_associates (the map's strength
## on the k ladder: what the cheapest associates-only army costs, in gameplan's strength model
## inverted), k_best (the same for the best army's cabbages)}. An entry: {style, won, army (unit id ->
## figures), cabbages, places, figures, zones (indices used), seconds, lost (unit id -> figures),
## lost_cabbages, fits (places within the cap)}.
static func assess(layout: Array, grid: Vector2i, options := {}) -> Dictionary:
	var opts := options.duplicate()
	var level: String = opts.get("level", "none")
	if not opts.has("research"):
		opts.research = research_for(level)
	if not opts.has("cap"):
		opts.cap = cap_for(level)
	var units: Array = opts.get("units", WarRules.UNITS)
	var won := []
	var lost := []
	for style: String in PLAYSTYLES:
		if PLAYSTYLES[style].all(func(part: Array) -> bool: return part[0] in units):
			var e := cheapest(layout, grid, style, opts)
			if e.is_empty():
				lost.append({style = style, won = false})
			else:
				won.append(e)
	won.sort_custom(cheaper)
	var best: Dictionary = won[0] if not won.is_empty() else {}
	if units.size() > 1:
		for e: Dictionary in won.slice(0, 3):  # The three cheapest styles, each refined.
			var mixed := refine(layout, grid, e, units, opts)
			if cheaper(mixed, best):
				best = mixed
		if best.get("style", "") == "mixed":
			won.push_front(best)
	var r := 1.0
	for node in WarRules.RESEARCH:
		if node.unit == "field_associate" and node.stat in ["hp", "damage"] and opts.research.has(node.id):
			r *= float(node.step)
	for id: String in opts.research:
		r *= WarRules.DRILL_STEP if id.begins_with("war_drill_") else 1.0
	var price := float(WarRules.unit_cabbage_price("field_associate"))
	var associates: Array = won.filter(func(e: Dictionary) -> bool: return e.style == "associates")
	return {styles = won + lost, best = best, cap = opts.cap, level = level,
			k_associates = strength(associates[0].cabbages / price, r) if not associates.is_empty() else INF,
			k_best = strength(best.cabbages / price, r) if not best.is_empty() else INF}


## What WarMap stores as a map's `difficulty` (assess at level none, every unit): {k (k_associates to
## 0.01; 99 if associates never win), associates (their fewest, -1: never), style (the best playstyle),
## cabbages (its army)}.
static func difficulty(layout: Array, grid: Vector2i) -> Dictionary:
	return difficulty_of(assess(layout, grid))


## difficulty() from an assess at level none with every unit, already run.
static func difficulty_of(a: Dictionary) -> Dictionary:
	var fa: Array = a.styles.filter(func(e: Dictionary) -> bool: return e.style == "associates" and e.won)
	return {k = snappedf(a.k_associates, 0.01) if not fa.is_empty() else 99.0, associates = fa[0].figures if not fa.is_empty() else -1,
			style = a.best.get("style", ""), cabbages = a.best.get("cabbages", 0)}


## Map strength k of a map that `associates` field associates take (the strength model of
## research/war-balance.md and tools/pace.py, N = 3 (k / R^0.7)^1.55, inverted; R the associate's hp x
## damage research).
static func strength(associates: float, r := 1.0) -> float:
	return pow(associates / 3.0, 1.0 / 1.55) * pow(r, 0.7)
