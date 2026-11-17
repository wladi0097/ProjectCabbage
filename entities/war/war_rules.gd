class_name WarRules
## The war's rules on the save (research/war-contract.md): which unit types are hired, the army cap,
## buying and training figures, the fight's time limit, retreat and mid-round placing, and each
## unit's stats with its depot research applied. Pure static logic; WarFight runs the fight itself.

## Unit ids, in depot column order (research/war-units.md: the final roster).
const UNITS: Array[String] = ["field_associate", "restructuring_charge", "senior_asset", "pult_crew", "courier"]
## The desk card (save.stamped) that hires each unit type. Every one also needs `war_mode`.
const UNIT_CARD := {
	field_associate = "war_mode",
	restructuring_charge = "unit_charge",
	senior_asset = "unit_senior",
	pult_crew = "unit_pult",
	courier = "unit_courier",
}
## Cabbages from stock per figure (field_associate paced in tools/pace.py ch3, war pass 2026-11-14:
## the figures lost in a war are its harvest drive; the others set in the balance pass 2026-11-15 so
## each is clearly cheaper than associates on the defences it counters: research/war-balance.md).
const UNIT_PRICE := {field_associate = 1000, restructuring_charge = 500, senior_asset = 2500, pult_crew = 2000, courier = 1500}
## Seconds one figure trains before it joins save.army (WAR_TRAINING cuts it).
const UNIT_TRAINING := {field_associate = 15.0, restructuring_charge = 10.0, senior_asset = 45.0, pult_crew = 30.0, courier = 25.0}
## Army places one figure takes under the cap (default 1).
const UNIT_SPACE := {senior_asset = 2}
## Base stats, in WarFight's cell units: hp, damage per hit, seconds between hits (interval),
## speed (cells/s), range (cells from the unit to the target's edge), splash (radius in cells, 0:
## single target), wall_mult (damage times this against walls), hops (crosses fences without
## breaking them, WarFight.HOP s a cell) and the target rule: "defence" (nearest defence, then the
## farmhouse), "wall" (the first standing fence on its straight path to the nearest defence, blows
## up on contact; no fence on that path: blows up at the defence).
const BASE_STATS := {
	field_associate = {hp = 150.0, damage = 25.0, interval = 1.0, speed = 1.2, range = 0.8, splash = 0.0, wall_mult = 1.0, hops = false, target = "defence"},
	restructuring_charge = {hp = 60.0, damage = 30.0, interval = 1.0, speed = 1.2, range = 0.6, splash = 1.2, wall_mult = 20.0, hops = false, target = "wall"},
	senior_asset = {hp = 1200.0, damage = 18.0, interval = 1.0, speed = 0.9, range = 0.8, splash = 0.0, wall_mult = 1.0, hops = false, target = "defence"},
	pult_crew = {hp = 110.0, damage = 30.0, interval = 1.5, speed = 1.0, range = 3.5, splash = 1.0, wall_mult = 1.0, hops = false, target = "defence"},
	courier = {hp = 110.0, damage = 40.0, interval = 1.2, speed = 2.0, range = 0.8, splash = 0.0, wall_mult = 1.0, hops = true, target = "defence"},
}
## Depot research, one chain of five per unit, bought top down: each node multiplies one stat by
## `step` (+12% to +30%), costs `findings`, and needs its `parent` bought first ("": none). Prices
## start cheap and climb (a few ¶K for the field associate's first step, user 2026-11-16), so the
## early steps come at once and the later ones push the player to the projector's research nodes;
## a unit hired later starts dearer. Paced with the war cards' Findings (tools/pace.py ch3 shy).
## The big old steps were split in two (SPLITS): the old id is now the second half, the new id the
## first, and the two multiply to the old step, so an old save's research is worth what it was.
const RESEARCH: Array[Dictionary] = [
	{id = "fa_hp_0", unit = "field_associate", stat = "hp", step = 1.1402, findings = 3000, parent = ""},
	{id = "fa_hp_1", unit = "field_associate", stat = "hp", step = 1.1402, findings = 8000, parent = "fa_hp_0"},
	{id = "fa_speed_1", unit = "field_associate", stat = "speed", step = 1.25, findings = 20000, parent = "fa_hp_1"},
	{id = "fa_damage_1", unit = "field_associate", stat = "damage", step = 1.3, findings = 50000, parent = "fa_speed_1"},
	{id = "fa_hp_2", unit = "field_associate", stat = "hp", step = 1.3, findings = 120000, parent = "fa_damage_1"},
	{id = "rc_hp_0", unit = "restructuring_charge", stat = "hp", step = 1.2248, findings = 10000, parent = ""},
	{id = "rc_wall_0", unit = "restructuring_charge", stat = "wall_mult", step = 1.2248, findings = 20000, parent = "rc_hp_0"},
	{id = "rc_hp_1", unit = "restructuring_charge", stat = "hp", step = 1.2248, findings = 40000, parent = "rc_wall_0"},
	{id = "rc_wall_1", unit = "restructuring_charge", stat = "wall_mult", step = 1.2248, findings = 80000, parent = "rc_hp_1"},
	{id = "rc_splash_1", unit = "restructuring_charge", stat = "splash", step = 1.3, findings = 150000, parent = "rc_wall_1"},
	{id = "sa_hp_0", unit = "senior_asset", stat = "hp", step = 1.1402, findings = 15000, parent = ""},
	{id = "sa_hp_1", unit = "senior_asset", stat = "hp", step = 1.1402, findings = 30000, parent = "sa_hp_0"},
	{id = "sa_speed_1", unit = "senior_asset", stat = "speed", step = 1.25, findings = 60000, parent = "sa_hp_1"},
	{id = "sa_damage_1", unit = "senior_asset", stat = "damage", step = 1.3, findings = 120000, parent = "sa_speed_1"},
	{id = "sa_hp_2", unit = "senior_asset", stat = "hp", step = 1.3, findings = 200000, parent = "sa_damage_1"},
	{id = "pc_damage_0", unit = "pult_crew", stat = "damage", step = 1.1402, findings = 20000, parent = ""},
	{id = "pc_damage_1", unit = "pult_crew", stat = "damage", step = 1.1402, findings = 40000, parent = "pc_damage_0"},
	{id = "pc_range_1", unit = "pult_crew", stat = "range", step = 1.25, findings = 80000, parent = "pc_damage_1"},
	{id = "pc_splash_1", unit = "pult_crew", stat = "splash", step = 1.3, findings = 150000, parent = "pc_range_1"},
	{id = "pc_damage_2", unit = "pult_crew", stat = "damage", step = 1.3, findings = 250000, parent = "pc_splash_1"},
	{id = "cr_speed_0", unit = "courier", stat = "speed", step = 1.1181, findings = 30000, parent = ""},
	{id = "cr_speed_1", unit = "courier", stat = "speed", step = 1.1181, findings = 60000, parent = "cr_speed_0"},
	{id = "cr_hp_0", unit = "courier", stat = "hp", step = 1.1402, findings = 120000, parent = "cr_speed_1"},
	{id = "cr_hp_1", unit = "courier", stat = "hp", step = 1.1402, findings = 200000, parent = "cr_hp_0"},
	{id = "cr_damage_1", unit = "courier", stat = "damage", step = 1.3, findings = 300000, parent = "cr_hp_1"},
]
## The split steps (2026-11-16): new first half -> the old id, now the second half. migrate_research
## files the first half for a save that bought the old id before the split.
const SPLITS := {fa_hp_0 = "fa_hp_1", rc_hp_0 = "rc_hp_1", rc_wall_0 = "rc_wall_1", sa_hp_0 = "sa_hp_1",
		pc_damage_0 = "pc_damage_1", cr_speed_0 = "cr_speed_1", cr_hp_0 = "cr_hp_1"}

const BASE_CAP := 3
## Army cap added by the BIGGER ARMIES card, and by each depot GENERAL war_cap_1..3 node.
const CARD_CAP := 2
const NODE_CAP := 2
const BASE_FIGHT := 90.0
## Seconds each depot GENERAL war_time_1..3 node adds to the fight.
const NODE_FIGHT := 15.0
## Training time kept by each depot GENERAL war_training_1..3 node (0.75: 25% shorter each).
const NODE_TRAINING := 0.75
## Retreat share with the RETREAT card, added per war_retreat_1..5 node, and its top.
const BASE_RETREAT := 0.3
const NODE_RETREAT := 0.1
const MAX_RETREAT := 0.8


static func unit_unlocked(save: SaveGame, unit: String) -> bool:
	return UNIT_CARD.has(unit) and save.stamped.has("war_mode") and save.stamped.has(UNIT_CARD[unit])


static func army_cap(save: SaveGame) -> int:
	return BASE_CAP + CARD_CAP * int(save.stamped.has("bigger_armies")) + NODE_CAP * _nodes(save, "war_cap_", 3)


## Army places one figure of `unit` takes (UNIT_SPACE).
static func unit_space(unit: String) -> int:
	return int(UNIT_SPACE.get(unit, 1))


## The places of figures ready plus figures in training: what the cap counts.
static func army_size(save: SaveGame) -> int:
	var size := 0
	for entry: Dictionary in save.army_training:
		size += unit_space(entry.unit)
	for unit: String in save.army:
		size += int(save.army[unit]) * unit_space(unit)
	return size


## Whether one more figure of `unit` fits under the army cap.
static func fits(save: SaveGame, unit: String) -> bool:
	return army_size(save) + unit_space(unit) <= army_cap(save)


static func fight_seconds(save: SaveGame) -> float:
	return BASE_FIGHT + NODE_FIGHT * _nodes(save, "war_time_", 3)


static func training_seconds(save: SaveGame, unit: String) -> float:
	return float(UNIT_TRAINING[unit]) * pow(NODE_TRAINING, _nodes(save, "war_training_", 3))


static func unit_cabbage_price(unit: String) -> int:
	return UNIT_PRICE[unit]


## The share of placed, living units a retreat brings home: 0 without the RETREAT card.
static func retreat_share(save: SaveGame) -> float:
	if not save.stamped.has("retreat"):
		return 0.0
	return minf(BASE_RETREAT + NODE_RETREAT * _nodes(save, "war_retreat_", 5), MAX_RETREAT)


static func can_place_mid_round(save: SaveGame) -> bool:
	return save.stamped.has("tactics")


## `unit`'s stats (BASE_STATS keys) with every research node bought for it applied.
static func unit_stats(save: SaveGame, unit: String) -> Dictionary:
	var stats: Dictionary = BASE_STATS[unit].duplicate()
	for node in RESEARCH:
		if node.unit == unit and save.unit_research.has(node.id):
			stats[node.stat] = float(stats[node.stat]) * float(node.step)
	return stats


## Hired, fitting under the army cap, and the cabbages in the store (`out`: UpgradeDesk.units_out, cabbages
## out of the chute can't pay).
static func can_buy(save: SaveGame, unit: String, out := Vector2i.ZERO) -> bool:
	return unit_unlocked(save, unit) and fits(save, unit) \
			and UpgradeDesk.spendable(save, "stock", out) >= unit_cabbage_price(unit)


## Pays one figure's cabbages and queues its training; false (nothing changes) if it can't be bought.
static func buy(save: SaveGame, unit: String, out := Vector2i.ZERO) -> bool:
	if not can_buy(save, unit, out):
		return false
	UpgradeDesk.pay(save, "stock", unit_cabbage_price(unit), out)
	var seconds := training_seconds(save, unit)
	save.army_training.append({unit = unit, left = seconds, total = seconds})  # total: the bar stays true if a training node is bought mid-way.
	return true


## Whether `save` has a figure of `unit` to dismiss: one ready, or one in training.
static func can_dismiss(save: SaveGame, unit: String) -> bool:
	return int(save.army.get(unit, 0)) > 0 or save.army_training.any(func(entry: Dictionary) -> bool: return entry.unit == unit)


## Dismisses one figure of `unit` (the depot's trash circle): a ready one first, else the newest of its
## trainees (it never started, or the front trains on). Nothing is paid back: the cabbages went into
## the requisition. False (nothing changes) if there is none.
static func dismiss(save: SaveGame, unit: String) -> bool:
	var ready := int(save.army.get(unit, 0))
	if ready > 0:
		save.army[unit] = ready - 1
		return true
	for i in range(save.army_training.size() - 1, -1, -1):
		if save.army_training[i].unit == unit:
			save.army_training.remove_at(i)
			return true
	return false


## Trains the queue's front figure for `delta` seconds; time left over goes on to the next one.
## Finished figures join save.army.
static func tick_training(save: SaveGame, delta: float) -> void:
	while delta > 0.0 and not save.army_training.is_empty():
		var front: Dictionary = save.army_training[0]
		var used := minf(delta, float(front.left))
		front.left = float(front.left) - used
		delta -= used
		if front.left <= 0.0:
			save.army_training.pop_front()
			save.army[front.unit] = int(save.army.get(front.unit, 0)) + 1


static func research_node(id: String) -> Dictionary:
	for node in RESEARCH:
		if node.id == id:
			return node
	return {}


## Not bought yet, its parent bought, its unit hired and the Findings there.
static func can_buy_research(save: SaveGame, id: String) -> bool:
	var node := research_node(id)
	return not node.is_empty() and not save.unit_research.has(id) \
			and (node.parent == "" or save.unit_research.has(node.parent)) \
			and unit_unlocked(save, node.unit) and save.findings >= int(node.findings)


## A save that bought a split step's old id before the split gets its new first half filed, so its
## research is worth what it was (UpgradeDesk.migrate; idempotent: a new save buys the first half first).
static func migrate_research(save: SaveGame) -> void:
	for first: String in SPLITS:
		if save.unit_research.has(SPLITS[first]) and not save.unit_research.has(first):
			save.unit_research.append(first)


static func buy_research(save: SaveGame, id: String) -> bool:
	if not can_buy_research(save, id):
		return false
	save.findings -= int(research_node(id).findings)
	save.unit_research.append(id)
	return true


## How many of the depot GENERAL nodes (save.tree_bought) `prefix`1..`count` are bought.
static func _nodes(save: SaveGame, prefix: String, count: int) -> int:
	var bought := 0
	for i in range(1, count + 1):
		bought += int(save.tree_bought.has(prefix + str(i)))
	return bought
