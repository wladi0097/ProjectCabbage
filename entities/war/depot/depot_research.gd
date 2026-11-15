class_name DepotResearch
extends RefCounted
## The depot sheet's DEVELOPMENT PROGRAMME: the war research (WarRules.RESEARCH) as the shared
## upgrade tree's rules (UpgradeTree.rules, like FarmTree and the projector), one tree for the whole
## depot, laid out as an org chart round the hub (UpgradeTree.hub_at): above it the GENERAL department
## with its four war chains spreading left and right (GENERAL: coins, save.tree_bought), below it a row
## of department plates (DEPTS: info only, never bought) in the columns' order, each unit's research
## going down under its plate: the root, its first child on the left with the grandchild under it, the
## second child on the right half a row lower, so no two titles meet in English or German. A unit not
## hired yet shows nothing in its slot; the others keep their places. Unit research is paid in Findings,
## parent first (WarRules.buy_research), into save.unit_research. Everything fits the sheet's research
## box at the home zoom (DepotSheet.TREE_ZOOM). Positions, titles and copy are here; what a unit node
## does and costs is WarRules'.

## The departments: one per unit type the depot deals in (Depot.IN_SERVICE).
const DEPTS := [
	{id = "dept_field_associate", parent = "", at = Vector2(-1.340, 0.239), icon = "hand", dept = true,
		unit = "field_associate", title = "FIELD ASSOCIATE",
		body = "The backbone of every hostile acquisition.\nField associate research, paid in Findings."},
	{id = "dept_restructuring_charge", parent = "", at = Vector2(-0.670, 0.239), icon = "megaphone", dept = true,
		unit = "restructuring_charge", title = "RESTRUCTURING CHARGE",
		body = "Single use. Highly effective. Fully deductible.\nRestructuring charge research, paid in Findings."},
	{id = "dept_senior_asset", parent = "", at = Vector2(0.000, 0.239), icon = "desk", dept = true,
		unit = "senior_asset", title = "SENIOR ASSET",
		body = "Expensive to keep, impossible to dismiss.\nSenior asset research, paid in Findings."},
	{id = "dept_pult_crew", parent = "", at = Vector2(0.670, 0.239), icon = "crate", dept = true,
		unit = "pult_crew", title = "CABBAGE-PULT CREW",
		body = "Produce, delivered at speed.\nCabbage-pult crew research, paid in Findings."},
	{id = "dept_courier", parent = "", at = Vector2(1.340, 0.239), icon = "clock", dept = true,
		unit = "courier", title = "EXPRESS COURIER",
		body = "Always on time. Never signed for.\nExpress courier research, paid in Findings."},
]
## The GENERAL programme above the hub: a department of its own and four chains paid in coins and
## kept in save.tree_bought, where WarRules reads them (fight time, training time, army cap, retreat
## share; they came over from the projector, ids and prices unchanged). Shown with the war card
## (WAR_CARD); EXIT INTERVIEWS also waits on the withdrawal protocol (`lock`, the RETREAT card).
const GENERAL := [
	{id = "dept_general", parent = "", at = Vector2(0.000, -0.289), icon = "chair", dept = true, unit = "", title = "GENERAL",
		body = "Standing orders for the whole depot.\nFight time, training, headcount and retreats, paid in coins."},
	{id = "war_time_1", parent = "dept_general", at = Vector2(-0.365, -0.512), icon = "clock", price = 1500000,
		title = "EXTENDED MANDATE",
		body = "The war has been granted an extension.\nEvery fight lasts 105 s, not 90 s."},
	{id = "war_time_2", parent = "war_time_1", at = Vector2(-0.662, -0.365), icon = "clock", price = 3000000,
		title = "OVERTIME AUTHORISED",
		body = "Overtime is unpaid. It is also compulsory.\nEvery fight lasts 120 s, not 105 s."},
	{id = "war_time_3", parent = "war_time_2", at = Vector2(-0.959, -0.512), icon = "clock", price = 6000000,
		title = "OPEN-ENDED ENGAGEMENT",
		body = "No end date was ever agreed. This was deliberate.\nEvery fight lasts 135 s, not 120 s."},
	{id = "war_training_1", parent = "dept_general", at = Vector2(-0.365, -0.212), icon = "hand", price = 1000000,
		title = "INDUCTION BOOKLET",
		body = "Forty pages. Nobody reads past the first.\nStaff train 25% faster at the personnel depot."},
	{id = "war_training_2", parent = "war_training_1", at = Vector2(-0.662, -0.066), icon = "hand", price = 2500000,
		title = "ON-THE-JOB TRAINING",
		body = "The job is the training. The training is the job.\nStaff train another 25% faster."},
	{id = "war_training_3", parent = "war_training_2", at = Vector2(-0.959, -0.212), icon = "hand", price = 5000000,
		title = "ACCELERATED ONBOARDING",
		body = "Hired on Monday, deployed on Monday.\nStaff train another 25% faster."},
	{id = "war_cap_1", parent = "dept_general", at = Vector2(0.365, -0.512), icon = "chair", price = 2000000,
		title = "FIELD HEADCOUNT",
		body = "The field has been found to hold more staff.\nThe army cap is raised by 2."},
	{id = "war_cap_2", parent = "war_cap_1", at = Vector2(0.662, -0.365), icon = "chair", price = 4000000,
		title = "REGIONAL DIVISION",
		body = "A division needs a regional manager. You.\nThe army cap is raised by 2 more."},
	{id = "war_cap_3", parent = "war_cap_2", at = Vector2(0.959, -0.512), icon = "chair", price = 7000000,
		title = "STANDING WORKFORCE",
		body = "They are never sent home. There is no home.\nThe army cap is raised by 2 more."},
	{id = "war_retreat_1", parent = "dept_general", at = Vector2(0.365, -0.212), icon = "belt", price = 1000000,
		lock = "retreat", title = "EXIT INTERVIEWS",
		body = "Leaving is a process. The process saves lives.\nA retreat brings 40% of the placed staff home,\nnot 30%."},
	{id = "war_retreat_2", parent = "war_retreat_1", at = Vector2(0.662, -0.066), icon = "belt", price = 1500000,
		title = "MARKED FIRE EXITS",
		body = "The exits are signposted. In green, naturally.\nA retreat brings 50% of the placed staff home,\nnot 40%."},
	{id = "war_retreat_3", parent = "war_retreat_2", at = Vector2(0.959, -0.212), icon = "belt", price = 2500000,
		title = "ORDERLY WITHDRAWAL",
		body = "Single file. No running. Mind the cannon.\nA retreat brings 60% of the placed staff home,\nnot 50%."},
	{id = "war_retreat_4", parent = "war_retreat_3", at = Vector2(1.256, -0.066), icon = "belt", price = 3500000,
		title = "STAFF SHUTTLE",
		body = "Departs every few seconds, under fire.\nA retreat brings 70% of the placed staff home,\nnot 60%."},
	{id = "war_retreat_5", parent = "war_retreat_4", at = Vector2(1.553, -0.212), icon = "belt", price = 5000000,
		title = "NOBODY LEFT BEHIND",
		body = "Staff are assets. Assets are recovered.\nA retreat brings 80% of the placed staff home,\nnot 70%."},
]
## Every unit's research nodes; a root hangs off its unit's department.
const ALL := [
	{id = "fa_hp_1", parent = "dept_field_associate", at = Vector2(-1.340, 0.538), icon = "hand", currency = "findings",
		title = "BODY ARMOUR",
		body = "Cardboard, laminated. Still issued.\nField associates take 30% more damage before they fall."},
	{id = "fa_damage_1", parent = "fa_hp_1", at = Vector2(-1.477, 0.838), icon = "crate", currency = "findings",
		title = "HEAVIER CLIPBOARDS",
		body = "The clipboard is now a weapon. It always was.\nField associates hit 30% harder."},
	{id = "fa_speed_1", parent = "fa_hp_1", at = Vector2(-1.203, 0.988), icon = "clock", currency = "findings",
		title = "TIME AND MOTION",
		body = "Every step has been measured. Some were cut.\nField associates walk 25% faster."},
	{id = "fa_hp_2", parent = "fa_damage_1", at = Vector2(-1.477, 1.138), icon = "hand", currency = "findings",
		title = "HAZARD BRIEFING",
		body = "The hazards were briefed. The briefing was mandatory.\nField associates take another 30% more damage before they fall."},
	{id = "rc_hp_1", parent = "dept_restructuring_charge", at = Vector2(-0.670, 0.538), icon = "hand", currency = "findings",
		title = "PADDED CASING",
		body = "Survives the commute. Usually.\nRestructuring charges take 50% more damage before they fall."},
	{id = "rc_wall_1", parent = "rc_hp_1", at = Vector2(-0.670, 0.838), icon = "pilcrow", currency = "findings",
		title = "STRUCTURAL ASSESSMENT",
		body = "Every fence has a weak point. It has been found.\nRestructuring charges do 50% more damage to fences: security grade goes in one blast."},
	{id = "rc_splash_1", parent = "rc_wall_1", at = Vector2(-0.670, 1.138), icon = "megaphone", currency = "findings",
		title = "WIDER REMIT",
		body = "The restructuring now covers the adjoining departments.\nRestructuring charges blast 30% wider."},
	{id = "sa_hp_1", parent = "dept_senior_asset", at = Vector2(0.000, 0.538), icon = "hand", currency = "findings",
		title = "EXECUTIVE PADDING",
		body = "Upholstered at company expense.\nSenior assets take 30% more damage before they fall."},
	{id = "sa_damage_1", parent = "sa_hp_1", at = Vector2(-0.137, 0.838), icon = "crate", currency = "findings",
		title = "FIRM HANDSHAKE",
		body = "Held slightly too long. On purpose.\nSenior assets hit 30% harder."},
	{id = "sa_speed_1", parent = "sa_hp_1", at = Vector2(0.137, 0.988), icon = "clock", currency = "findings",
		title = "COMPANY CAR",
		body = "Parked in the space nearest the door.\nSenior assets walk 25% faster."},
	{id = "sa_hp_2", parent = "sa_damage_1", at = Vector2(-0.137, 1.138), icon = "hand", currency = "findings",
		title = "GOLDEN PARACHUTE",
		body = "Removal now costs more than retention.\nSenior assets take another 30% more damage before they fall."},
	{id = "pc_damage_1", parent = "dept_pult_crew", at = Vector2(0.670, 0.538), icon = "crate", currency = "findings",
		title = "HEAVIER HEADS",
		body = "Selected for density, not flavour.\nCabbage-pult crews hit 30% harder."},
	{id = "pc_range_1", parent = "pc_damage_1", at = Vector2(0.533, 0.838), icon = "lens", currency = "findings",
		title = "LONGER ARM",
		body = "The arm was extended. The budget was not.\nCabbage-pult crews throw 25% further."},
	{id = "pc_splash_1", parent = "pc_damage_1", at = Vector2(0.807, 0.988), icon = "megaphone", currency = "findings",
		title = "LOOSER LEAVES",
		body = "The leaves come off on impact. That is the point.\nCabbage-pult crews splash 30% wider."},
	{id = "pc_damage_2", parent = "pc_range_1", at = Vector2(0.533, 1.138), icon = "crate", currency = "findings",
		title = "DENSER CABBAGE",
		body = "Grown under pressure. Like everyone here.\nCabbage-pult crews hit another 30% harder."},
	{id = "cr_speed_1", parent = "dept_courier", at = Vector2(1.340, 0.538), icon = "clock", currency = "findings",
		title = "GEARED HUB",
		body = "Three speeds. All of them fast.\nExpress couriers ride 25% faster."},
	{id = "cr_hp_1", parent = "cr_speed_1", at = Vector2(1.203, 0.838), icon = "hand", currency = "findings",
		title = "HELMET POLICY",
		body = "Mandatory since the incident.\nExpress couriers take 30% more damage before they fall."},
	{id = "cr_damage_1", parent = "cr_speed_1", at = Vector2(1.477, 0.988), icon = "crate", currency = "findings",
		title = "PRIORITY POST",
		body = "Delivered with force. Signed for by no one.\nExpress couriers hit 30% harder."},
]
const THEMES := []
## Everything the tree draws (UpgradeTree reads `rules.NODES`).
const NODES := GENERAL + DEPTS + ALL
## The card that opens the depot, and with it the GENERAL programme.
const WAR_CARD := "war_mode"


static func node_data(id: String) -> Dictionary:
	for node: Dictionary in NODES:
		if node.id == id:
			return node
	return {}


## Whether node `id` is the GENERAL department or one of its chains (paid in coins, in tree_bought).
static func is_general(id: String) -> bool:
	return id == "dept_general" or id.begins_with("war_")


## Shown once the war card is stamped (GENERAL) or its unit type is hired.
static func is_shown(id: String, save: SaveGame) -> bool:
	if node_data(id).is_empty():
		return false
	if is_general(id):
		return save.stamped.has(WAR_CARD)
	var unit := unit_of(id)
	return unit != "" and WarRules.unit_unlocked(save, unit)


## The unit type node `id` (a department or a research node) belongs to ("": none, or GENERAL).
static func unit_of(id: String) -> String:
	if is_dept(id):
		return node_data(id).unit
	return WarRules.research_node(id).get("unit", "") if not node_data(id).is_empty() else ""


## The department of `unit`'s branch.
static func dept_of(unit: String) -> String:
	return "dept_" + unit


## Reachable: shown, and its parent open (its department, or bought).
static func is_reachable(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return is_shown(id, save) and (node.parent == "" or is_open(node.parent, save))


## Its children may show: a shown department, or a bought node.
static func is_open(id: String, save: SaveGame) -> bool:
	return is_shown(id, save) if is_dept(id) else is_bought(id, save)


static func is_dept(id: String) -> bool:
	return node_data(id).get("dept", false)


## The card node `id` still waits for although reachable (its `lock`: EXIT INTERVIEWS the RETREAT
## card), or "".
static func locked_by(id: String, save: SaveGame) -> String:
	var lock: String = node_data(id).get("lock", "")
	return lock if lock != "" and not save.stamped.has(lock) and not is_bought(id, save) else ""


## GENERAL nodes are kept in tree_bought (WarRules reads them there), unit research in unit_research.
static func is_bought(id: String, save: SaveGame) -> bool:
	return save.tree_bought.has(id) if is_general(id) else save.unit_research.has(id)


## Coins for a GENERAL node (its `price`), Findings for unit research (WarRules).
static func price_of(id: String, _save: SaveGame) -> int:
	if is_general(id):
		return int(node_data(id).get("price", 0))
	return int(WarRules.research_node(id).get("findings", 0))


static func can_hold(id: String, save: SaveGame) -> bool:
	return not is_dept(id) and is_reachable(id, save) and not is_bought(id, save) and locked_by(id, save) == ""


static func can_buy(id: String, save: SaveGame) -> bool:
	if is_dept(id) or node_data(id).is_empty():
		return false
	if is_general(id):
		return can_hold(id, save) and save.coins >= price_of(id, save)
	return WarRules.can_buy_research(save, id)


static func buy(id: String, save: SaveGame) -> bool:
	if not can_buy(id, save):
		return false
	if not is_general(id):
		return WarRules.buy_research(save, id)
	save.coins -= price_of(id, save)
	save.tree_bought.append(id)
	return true


## What node `id` waits for, as [heading, name] (or a form lock) for its popup, or [] if nothing.
static func requirement(id: String, save: SaveGame) -> Array:
	var node := node_data(id)
	if not is_bought(id, save) and node.parent != "" and not is_dept(node.parent) and not is_bought(node.parent, save):
		return ["REQUIRES:", node_data(node.parent).title]
	var lock := locked_by(id, save)
	return UpgradeTree.form_lock(lock, save) if lock != "" else []


static func fresh(_save: SaveGame) -> Array[String]:
	return []


static func themes_shown(_save: SaveGame) -> Array[bool]:
	return []


## Besides zoom and size, what changes the drawing: cards, nodes bought, what the Findings and coins
## cover.
static func drawn_key(save: SaveGame) -> Array:
	var covered := 0
	for node: Dictionary in NODES:
		if not is_dept(node.id):
			covered += int(save.get(UpgradeTree.currency_of(node)) >= price_of(node.id, save))
	return [save.stamped.size(), save.unit_research.size(), save.tree_bought.size(), covered]
