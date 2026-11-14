class_name DepotResearch
## The depot sheet's DEVELOPMENT PROGRAMME: the war research (WarRules.RESEARCH) as the shared
## upgrade tree's rules (UpgradeTree.rules, like FarmTree and the projector): every node is paid in
## Findings, bought parent first and only once its unit type is hired (WarRules.buy_research), and
## goes into save.unit_research. Positions round the hub, titles and copy are here; what a node does
## and costs is WarRules'. Today only the field associates' nodes (Depot.IN_SERVICE).

const NODES := [
	{id = "fa_hp_1", parent = "", at = Vector2(0.0, -0.32), icon = "hand", currency = "findings",
		title = "BODY ARMOUR",
		body = "Cardboard, laminated. Still issued.\nField associates take 30% more damage before they fall."},
	{id = "fa_damage_1", parent = "fa_hp_1", at = Vector2(-0.34, -0.05), icon = "crate", currency = "findings",
		title = "HEAVIER CLIPBOARDS",
		body = "The clipboard is now a weapon. It always was.\nField associates hit 30% harder."},
	{id = "fa_speed_1", parent = "fa_hp_1", at = Vector2(0.34, -0.05), icon = "clock", currency = "findings",
		title = "TIME AND MOTION",
		body = "Every step has been measured. Some were cut.\nField associates walk 25% faster."},
	{id = "fa_hp_2", parent = "fa_damage_1", at = Vector2(-0.34, 0.32), icon = "hand", currency = "findings",
		title = "HAZARD BRIEFING",
		body = "The hazards were briefed. The briefing was mandatory.\nField associates take another 30% more damage before they fall."},
]
const THEMES := []


static func node_data(id: String) -> Dictionary:
	for node: Dictionary in NODES:
		if node.id == id:
			return node
	return {}


## Shown once its unit type is hired.
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := WarRules.research_node(id)
	return not node.is_empty() and not node_data(id).is_empty() and WarRules.unit_unlocked(save, node.unit)


## Reachable: shown, and its parent bought.
static func is_reachable(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return is_shown(id, save) and (node.parent == "" or is_bought(node.parent, save))


static func is_open(id: String, save: SaveGame) -> bool:
	return is_bought(id, save)


static func is_dept(_id: String) -> bool:
	return false


static func locked_by(_id: String, _save: SaveGame) -> String:
	return ""


static func is_bought(id: String, save: SaveGame) -> bool:
	return save.unit_research.has(id)


static func price_of(id: String, _save: SaveGame) -> int:
	return int(WarRules.research_node(id).get("findings", 0))


static func can_hold(id: String, save: SaveGame) -> bool:
	return is_reachable(id, save) and not is_bought(id, save)


static func can_buy(id: String, save: SaveGame) -> bool:
	return WarRules.can_buy_research(save, id) and not node_data(id).is_empty()


static func buy(id: String, save: SaveGame) -> bool:
	return can_buy(id, save) and WarRules.buy_research(save, id)


## What node `id` waits for, as [heading, name] for its popup, or [] if nothing.
static func requirement(id: String, save: SaveGame) -> Array:
	var node := node_data(id)
	if not is_bought(id, save) and node.parent != "" and not is_bought(node.parent, save):
		return ["REQUIRES:", node_data(node.parent).title]
	return []


static func fresh(_save: SaveGame) -> Array[String]:
	return []


static func themes_shown(_save: SaveGame) -> Array[bool]:
	return []


## Besides zoom and size, what changes the drawing: cards, nodes bought, what the Findings cover.
static func drawn_key(save: SaveGame) -> Array:
	var covered := 0
	for node: Dictionary in NODES:
		covered += int(save.findings >= price_of(node.id, save))
	return [save.stamped.size(), save.unit_research.size(), covered]
