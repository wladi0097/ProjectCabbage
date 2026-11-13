class_name FarmTree
extends Control
## CH2 on the farm TV (entities/farm_tv/): the farm's own upgrade tree, the projector's tree view
## (UpgradeTree) in the CRT's green phosphor, its layout and palette in farm_tree.tscn. Until desk
## card `farm_terminal` is stamped the channel shows SUBSCRIPTION PENDING instead. Bought ids go into
## save.farm_bought. Every node is paid in Findings (¶): coins stay for the projector (stage 2's coin
## sinks were walling the projector's mat and storage chains). Hand nodes wait for card seasonal_workforce, tractor nodes for
## mechanisation (the desk cards that bring the first of each). The farm's old one-off upgrades keep
## their ids (seed_contract, fertiliser, irrigation, greenhouse): FarmScreen reads them from farm_bought.

const CARD := "farm_terminal"
## Every node (UpgradeTree's format: parent, at, icon, price, currency, add/mul on save numbers,
## needs). ponytail: prices are placeholders, unpaced (the old coin prices / ~12, the sim's $ per ¶
## at 70-90 min); set them with tools/pace.py once CH1's workers are in.
const NODES := [
	{id = "hand_2", parent = "", at = Vector2(-0.6, -0.42), icon = "hand", price = 400, currency = "findings",
		needs = ["seasonal_workforce"], add = {farm_hands = 1}, title = "SECOND FARM HAND",
		body = "Seasonal contract. The season is permanent.\nOne more farm hand plants empty squares: 1 to 2 hands."},
	{id = "hand_speed", parent = "hand_2", at = Vector2(-1.05, -0.72), icon = "clock", price = 600, currency = "findings",
		mul = {farm_hand_speed = 1.5}, title = "WORK BOOTS",
		body = "Boots are issued. Laces are extra.\nFarm hands walk 50% faster."},
	{id = "hand_3", parent = "hand_speed", at = Vector2(-1.5, -1.02), icon = "hand", price = 1200, currency = "findings",
		add = {farm_hands = 1}, title = "THIRD FARM HAND",
		body = "The bunkhouse is at capacity.\nOne more farm hand plants empty squares: 2 to 3 hands."},
	{id = "hand_route", parent = "hand_2", at = Vector2(-1.1, -0.2), icon = "lens", price = 150,
		currency = "findings", add = {farm_hand_route = 1}, title = "PLANTING ROSTER",
		body = "A roster is pinned to the barn door.\nFarm hands walk straight to an empty square instead of wandering the field."},
	{id = "hand_shift", parent = "hand_2", at = Vector2(-0.55, -0.95), icon = "clock", price = 700, currency = "findings",
		add = {farm_hand_shift = 1}, title = "MANDATORY OVERTIME",
		body = "Overtime is voluntary. Volunteering is mandatory.
Farm hands carry one more seed per trip and plant one more square before returning to the yard."},
	{id = "tractor_2", parent = "", at = Vector2(0.6, -0.42), icon = "tractor", price = 1000, currency = "findings",
		needs = ["mechanisation"], add = {farm_tractors = 1}, title = "SECOND TRACTOR",
		body = "Leased. Never owned.\nOne more tractor harvests ripe squares: 1 to 2 tractors."},
	{id = "tractor_speed", parent = "tractor_2", at = Vector2(1.05, -0.72), icon = "clock", price = 1200, currency = "findings",
		mul = {farm_tractor_speed = 1.5}, title = "GOVERNOR REMOVED",
		body = "The speed governor is now optional.\nTractors drive 50% faster."},
	{id = "tractor_3", parent = "tractor_speed", at = Vector2(1.5, -1.02), icon = "tractor", price = 2500, currency = "findings",
		add = {farm_tractors = 1}, title = "THIRD TRACTOR",
		body = "Three tractors. One gate.\nOne more tractor harvests ripe squares: 2 to 3 tractors."},
	{id = "tractor_route", parent = "tractor_2", at = Vector2(1.1, -0.2), icon = "lens", price = 250,
		currency = "findings", add = {farm_tractor_route = 1}, title = "HARVEST DISPATCH",
		body = "Ripeness is now reported centrally.\nTractors drive straight to a ripe square instead of cruising the field."},
	{id = "tractor_shift", parent = "tractor_2", at = Vector2(0.55, -0.95), icon = "clock", price = 1600, currency = "findings",
		add = {farm_tractor_shift = 1}, title = "DOUBLE SHIFT",
		body = "The night shift is the day shift, continued.
Tractors harvest one more ripe square before returning to the yard."},
	# The old one-off farm upgrades, same ids: FarmScreen reads them from farm_bought.
	{id = "fertiliser", parent = "", at = Vector2(-0.6, 0.48), icon = "sprout", price = 250, currency = "findings",
		title = "FERTILISER",
		body = "Its contents are not disclosed.\nSquares ripen in 20 s instead of 30 s."},
	{id = "greenhouse", parent = "fertiliser", at = Vector2(-1.05, 0.82), icon = "sprout", price = 2500, currency = "findings",
		title = "GREENHOUSE",
		body = "Weather is no longer a factor. Nor is daylight.\nSquares ripen in 15 s."},
	{id = "irrigation", parent = "fertiliser", at = Vector2(-1.1, 0.3), icon = "lens", price = 300,
		currency = "findings", title = "IRRIGATION",
		body = "The water is metered by the drop.\nEvery harvest gives 1 more cabbage."},
	{id = "seed_contract", parent = "", at = Vector2(0.6, 0.48), icon = "crate", price = 200, currency = "findings",
		title = "SEED CONTRACT",
		body = "A supplier has been found. Do not ask which.\nSeed packs cost half."},
	# STANDING SEED ORDER (desk card standing_seed_order, FarmScreen.auto_seed): when it reorders and what.
	# Comfort, no gain (the order buys at once anyway, the 50 pack saves 12% on seeds): priced as pocket
	# change, right after the card (tools/pace.py: under 20 s and ~3 min after it).
	{id = "seed_reserve", parent = "seed_contract", at = Vector2(1.1, 0.3), icon = "clock", price = 200, currency = "findings",
		needs = ["standing_seed_order"], add = {farm_seed_reserve = 15}, title = "SAFETY SEED STOCK",
		body = "Running out is a planning failure. Planning has been increased.
The standing seed order buys when the crate is down to 20 seeds, not 5."},
	{id = "seed_bulk", parent = "seed_reserve", at = Vector2(1.05, 0.82), icon = "crate", price = 500, currency = "findings",
		add = {farm_seed_pack = 1}, title = "BULK SEED CONTRACT",
		body = "The supplier prefers fewer, larger invoices.
The standing seed order buys the 50-seed pack instead of the 10."},
	# GREEN THUMB (desk card green_thumb): the hand harvest's multiplier and replanting (FarmScreen.harvest).
	{id = "thumb_yield", parent = "", at = Vector2(0.0, -1.0), icon = "hand", price = 600, currency = "findings",
		needs = ["green_thumb"], add = {hand_yield = 1.0}, title = "EMPLOYEE OF THE MONTH",
		body = "Your photograph is on the barn wall.\nA square you pull by hand yields 3× instead of 2×."},
	{id = "thumb_replant", parent = "thumb_yield", at = Vector2(0.0, -1.45), icon = "sprout", price = 900, currency = "findings",
		add = {hand_replant = 1}, title = "ONE IN, ONE OUT",
		body = "The hole is never left empty. It is policy.\nA square you pull out yourself is replanted at once from the crate. Tractor harvests still wait for a farm hand."},
	# Golden squares (desk card golden_cabbage): how often one grows golden (save.golden_chance). What a
	# golden unit pays is the projector's (coins), not this tree's.
	{id = "gold_chance_1", parent = "", at = Vector2(0.0, 0.95), icon = "sprout", price = 1500, currency = "findings",
		needs = ["golden_cabbage"], add = {golden_chance = 0.015}, title = "SELECTIVE BREEDING",
		body = "Only the promising seeds are spoken to.\n1 square in 25 grows golden, not 1 in 40."},
	{id = "gold_chance_2", parent = "gold_chance_1", at = Vector2(0.0, 1.4), icon = "sprout", price = 4000, currency = "findings",
		add = {golden_chance = 0.0267}, title = "PEDIGREE SEED STOCK",
		body = "The seeds now have papers.\n1 square in 15 grows golden, not 1 in 25."},
	{id = "gold_chance_3", parent = "gold_chance_2", at = Vector2(0.0, 1.85), icon = "sprout", price = 9000, currency = "findings",
		add = {golden_chance = 0.0333}, title = "GILDED STRAIN",
		body = "It is no longer entirely a vegetable.\n1 square in 10 grows golden, not 1 in 15."},
	# COLD CHAIN: how long a ripe square waits before it rots (save.rot_after, FarmScreen.tick), shown
	# with the golden card, a minute before GameEvents "overripe" starts the rot.
	{id = "cold_frames", parent = "", at = Vector2(1.55, 0.05), icon = "crate", price = 250, currency = "findings",
		needs = ["golden_cabbage"], add = {rot_after = 120.0}, title = "COLD FRAMES",
		body = "The cabbages are kept cool. The staff are kept informed.\nA ripe square rots after 5 min instead of 3."},
	{id = "refrigerated_tarpaulin", parent = "cold_frames", at = Vector2(1.6, 0.55), icon = "crate", price = 500,
		currency = "findings", add = {rot_after = 180.0}, title = "REFRIGERATED TARPAULIN",
		body = "Patent pending. Electricity extra.\nA ripe square rots after 8 min instead of 5."},
	{id = "shelf_life_review", parent = "refrigerated_tarpaulin", at = Vector2(1.6, 1.05), icon = "clock", price = 900,
		currency = "findings", add = {rot_after = 240.0}, title = "SHELF-LIFE REVIEW",
		body = "Spoilage has been reclassified as maturing.\nA ripe square rots after 12 min instead of 8."},
]
## Each theme's heading: [title, spot (as a node's `at`), its first nodes], part of its branch (the
## edges to its first nodes run through it; spots by tools/_theme_place.gd), and its category's
## description for the heading's hover popup (a flavour line, then what the branch improves).
const THEMES := [
	["FARM HANDS", Vector2(-0.30, -0.21), ["hand_2"],
		"Seasonal in name only.\nMore farm hands planting empty squares, faster and further per trip."],
	["TRACTORS", Vector2(0.30, -0.21), ["tractor_2"],
		"Harvesting, mechanised and leased.\nMore tractors harvesting ripe squares, faster and more squares per trip."],
	["SOIL", Vector2(-0.30, 0.24), ["fertiliser"],
		"The ground is held to targets.\nSquares ripen sooner, and every harvest gives more cabbages."],
	["SUPPLY", Vector2(0.30, 0.24), ["seed_contract"],
		"Seeds, procured without questions.\nCheaper seed packs, and a standing order that buys sooner and in bulk."],
	["BY HAND", Vector2(0.0, -0.55), ["thumb_yield"],
		"Your own work, recognised in writing.\nSquares you pull by hand yield more and are replanted at once."],
	["GOLDEN", Vector2(0.0, 0.55), ["gold_chance_1"],
		"Some seeds are more promising than others.\nMore squares grow golden."],
	["COLD CHAIN", Vector2(0.77, 0.00), ["cold_frames"],
		"Spoilage is a scheduling issue.\nRipe squares wait longer before they rot."],
]

@export var approve_sound: AudioStream
@export var denied_sound: AudioStream

@onready var _tree: UpgradeTree = $Tree
@onready var _locked: Control = $Locked
## The budget line; its ¶ figure is a label of its own in the Findings counter's Oswald Bold and cream.
@onready var _budget: Label = $BudgetLine/Budget
@onready var _findings: Label = $BudgetLine/Findings
@onready var _sfx: AudioStreamPlayer = $Sfx


func _ready() -> void:
	_tree.rules = FarmTree
	_tree.bought.connect(_approved)
	_tree.denied.connect(_play.bind(denied_sound))


func _process(_delta: float) -> void:
	var save := SaveManager.save
	var open := unlocked(save)
	_locked.visible = not open
	_tree.visible = open
	_budget.text = tr("BUDGET  $%d   |   FINDINGS") % save.coins
	_findings.text = "¶%d" % save.findings


func _approved(id: String, paid: int) -> void:
	SaveManager.log_event("farm", id, paid, UpgradeTree.currency_of(node_data(id)))
	_play(approve_sound)


func _play(stream: AudioStream) -> void:
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


## CH2 is subscribed to: desk card farm_terminal is stamped.
static func unlocked(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


static func node_data(id: String) -> Dictionary:
	for node: Dictionary in NODES:
		if node.id == id:
			return node
	return {}


## The terminal is in and every desk card node `id` names in `needs` is stamped.
static func _cards_in(node: Dictionary, save: SaveGame) -> bool:
	return unlocked(save) and node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card))


## Shown: it and its ancestors have their cards (a whole branch shows with its feature).
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return not node.is_empty() and _cards_in(node, save) and (node.parent == "" or is_shown(node.parent, save))


## Reachable: its cards are stamped and its parent bought.
static func is_reachable(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return not node.is_empty() and _cards_in(node, save) and (node.parent == "" or is_bought(node.parent, save))


static func is_open(id: String, save: SaveGame) -> bool:
	return is_bought(id, save)


## The farm tree has no departments and no research gates.
static func is_dept(_id: String) -> bool:
	return false


static func locked_by(_id: String, _save: SaveGame) -> String:
	return ""


static func is_bought(id: String, save: SaveGame) -> bool:
	return save.farm_bought.has(id)


static func price_of(id: String, _save: SaveGame) -> int:
	return node_data(id).get("price", 0)


static func can_hold(id: String, save: SaveGame) -> bool:
	return is_reachable(id, save) and not is_bought(id, save)


## Holdable, and the save has its price in its currency (coins or Findings).
static func can_buy(id: String, save: SaveGame) -> bool:
	return can_hold(id, save) and save.get(UpgradeTree.currency_of(node_data(id))) >= price_of(id, save)


## Pays for node `id` in its currency and applies it; false (and nothing changes) if it can't be bought.
static func buy(id: String, save: SaveGame) -> bool:
	if not can_buy(id, save):
		return false
	var currency := UpgradeTree.currency_of(node_data(id))
	save.set(currency, save.get(currency) - price_of(id, save))
	save.farm_bought.append(id)
	UpgradeTree.apply_effect(node_data(id), save)
	return true


## What node `id` waits for, as [heading, name] for its popup, or [] if nothing.
static func requirement(id: String, save: SaveGame) -> Array:
	if is_bought(id, save):
		return []  # Old saves bought from the flat list, parents or not.
	var node := node_data(id)
	if node.parent != "" and not is_bought(node.parent, save):
		return ["REQUIRES:", node_data(node.parent).title]
	for card: String in node.get("needs", []):
		if not save.stamped.has(card):
			return ["REQUIRES DESK CARD:", UpgradeDesk.card_data(card).get("title", card)]
	return []


## Nothing is marked NEW on the farm tree. ponytail: needs a farm_seen save list to add.
static func fresh(_save: SaveGame) -> Array[String]:
	return []


static func themes_shown(save: SaveGame) -> Array[bool]:
	var out: Array[bool] = []
	for heading: Array in THEMES:
		out.append(heading[2].any(func(id: String) -> bool: return is_shown(id, save)))
	return out


## Besides zoom and size, what changes the tree's drawing: cards, nodes bought, what the budget covers.
static func drawn_key(save: SaveGame) -> Array:
	var covered := 0
	for node: Dictionary in NODES:
		covered += int(save.get(UpgradeTree.currency_of(node)) >= node.price)
	return [save.stamped.size(), save.farm_bought.size(), covered]
