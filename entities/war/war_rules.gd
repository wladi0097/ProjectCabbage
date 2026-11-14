class_name WarRules
## The war's rules on the save (research/war-contract.md): which unit types are hired, the army cap,
## buying and training figures, the fight's time limit, retreat and mid-round placing, and each
## unit's stats with its depot research applied. Pure static logic; WarFight runs the fight itself.

## Unit ids, in depot column order.
const UNITS: Array[String] = ["field_associate", "compliance_officer", "senior_asset", "pult_crew"]
## The desk card (save.stamped) that hires each unit type. Every one also needs `war_mode`.
const UNIT_CARD := {
	field_associate = "war_mode",
	compliance_officer = "unit_compliance",
	senior_asset = "unit_senior",
	pult_crew = "unit_pult",
}
## Cabbages from stock per figure (field_associate paced in tools/pace.py ch3, war pass 2026-11-14:
## the figures lost in a war are its harvest drive; the parked types' are placeholders).
const UNIT_PRICE := {field_associate = 1000, compliance_officer = 30, senior_asset = 80, pult_crew = 50}
## Seconds one figure trains before it joins save.army (WAR_TRAINING cuts it).
const UNIT_TRAINING := {field_associate = 15.0, compliance_officer = 30.0, senior_asset = 45.0, pult_crew = 40.0}
## Base stats, in WarFight's cell units: hp, damage per hit, seconds between hits (interval),
## speed (cells/s), range (cells from the unit to the target's edge), splash (radius in cells, 0:
## single target), wall_mult (damage times this against walls) and the target rule:
## "defence" (nearest cannon or mortar, then the farmhouse), "tower" (the same set: cannons and
## mortars, then the farmhouse), "wall" (nearest wall, blows up on contact; no walls left: as "defence").
const BASE_STATS := {
	field_associate = {hp = 150.0, damage = 25.0, interval = 1.0, speed = 1.2, range = 0.8, splash = 0.0, wall_mult = 1.0, target = "defence"},
	compliance_officer = {hp = 60.0, damage = 30.0, interval = 1.0, speed = 1.8, range = 0.6, splash = 1.2, wall_mult = 20.0, target = "wall"},
	senior_asset = {hp = 700.0, damage = 18.0, interval = 1.0, speed = 0.7, range = 0.8, splash = 0.0, wall_mult = 1.0, target = "tower"},
	pult_crew = {hp = 90.0, damage = 30.0, interval = 1.5, speed = 1.0, range = 3.0, splash = 1.0, wall_mult = 1.0, target = "defence"},
}
## Depot research, a small tree per unit: each node multiplies one stat by `step` (all >= +25%),
## costs `findings`, and needs its `parent` bought first ("": none). The field associate's prices are
## paced (tools/pace.py ch3); the parked types' are placeholders.
const RESEARCH: Array[Dictionary] = [
	{id = "fa_hp_1", unit = "field_associate", stat = "hp", step = 1.3, findings = 100000, parent = ""},
	{id = "fa_damage_1", unit = "field_associate", stat = "damage", step = 1.3, findings = 200000, parent = "fa_hp_1"},
	{id = "fa_speed_1", unit = "field_associate", stat = "speed", step = 1.25, findings = 150000, parent = "fa_hp_1"},
	{id = "fa_hp_2", unit = "field_associate", stat = "hp", step = 1.3, findings = 400000, parent = "fa_damage_1"},
	{id = "co_hp_1", unit = "compliance_officer", stat = "hp", step = 1.5, findings = 3000, parent = ""},
	{id = "co_damage_1", unit = "compliance_officer", stat = "damage", step = 1.3, findings = 6000, parent = "co_hp_1"},
	{id = "co_splash_1", unit = "compliance_officer", stat = "splash", step = 1.3, findings = 9000, parent = "co_damage_1"},
	{id = "sa_hp_1", unit = "senior_asset", stat = "hp", step = 1.3, findings = 4000, parent = ""},
	{id = "sa_damage_1", unit = "senior_asset", stat = "damage", step = 1.3, findings = 8000, parent = "sa_hp_1"},
	{id = "sa_hp_2", unit = "senior_asset", stat = "hp", step = 1.3, findings = 14000, parent = "sa_damage_1"},
	{id = "pc_damage_1", unit = "pult_crew", stat = "damage", step = 1.3, findings = 4000, parent = ""},
	{id = "pc_range_1", unit = "pult_crew", stat = "range", step = 1.25, findings = 8000, parent = "pc_damage_1"},
	{id = "pc_splash_1", unit = "pult_crew", stat = "splash", step = 1.3, findings = 8000, parent = "pc_damage_1"},
	{id = "pc_damage_2", unit = "pult_crew", stat = "damage", step = 1.3, findings = 14000, parent = "pc_range_1"},
]

const BASE_CAP := 3
## Army cap added by the BIGGER ARMIES card, and by each projector war_cap_1..3 node.
const CARD_CAP := 2
const NODE_CAP := 2
const BASE_FIGHT := 90.0
## Seconds each projector war_time_1..3 node adds to the fight.
const NODE_FIGHT := 15.0
## Training time kept by each projector war_training_1..3 node (0.75: 25% shorter each).
const NODE_TRAINING := 0.75
## Retreat share with the RETREAT card, added per war_retreat_1..5 node, and its top.
const BASE_RETREAT := 0.3
const NODE_RETREAT := 0.1
const MAX_RETREAT := 0.8


static func unit_unlocked(save: SaveGame, unit: String) -> bool:
	return UNIT_CARD.has(unit) and save.stamped.has("war_mode") and save.stamped.has(UNIT_CARD[unit])


static func army_cap(save: SaveGame) -> int:
	return BASE_CAP + CARD_CAP * int(save.stamped.has("bigger_armies")) + NODE_CAP * _nodes(save, "war_cap_", 3)


## Figures ready plus figures in training: what the cap counts.
static func army_size(save: SaveGame) -> int:
	var size := save.army_training.size()
	for unit: String in save.army:
		size += int(save.army[unit])
	return size


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


## Hired, under the army cap, and the cabbages in the store (`out`: UpgradeDesk.units_out, cabbages
## out of the chute can't pay).
static func can_buy(save: SaveGame, unit: String, out := Vector2i.ZERO) -> bool:
	return unit_unlocked(save, unit) and army_size(save) < army_cap(save) \
			and UpgradeDesk.spendable(save, "stock", out) >= unit_cabbage_price(unit)


## Pays one figure's cabbages and queues its training; false (nothing changes) if it can't be bought.
static func buy(save: SaveGame, unit: String, out := Vector2i.ZERO) -> bool:
	if not can_buy(save, unit, out):
		return false
	UpgradeDesk.pay(save, "stock", unit_cabbage_price(unit), out)
	save.army_training.append({unit = unit, left = training_seconds(save, unit)})
	return true


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


static func buy_research(save: SaveGame, id: String) -> bool:
	if not can_buy_research(save, id):
		return false
	save.findings -= int(research_node(id).findings)
	save.unit_research.append(id)
	return true


## How many of the projector nodes `prefix`1..`count` are bought.
static func _nodes(save: SaveGame, prefix: String, count: int) -> int:
	var bought := 0
	for i in range(1, count + 1):
		bought += int(save.tree_bought.has(prefix + str(i)))
	return bought
