class_name FarmTree
extends Control
## CH2 on the farm TV (entities/farm_tv/): the farm's own upgrade tree, the projector's tree view
## (UpgradeTree) in the CRT's green phosphor, its layout and palette in farm_tree.tscn. Until desk
## card `farm_terminal` is stamped the channel shows SUBSCRIPTION PENDING instead. Bought ids go into
## save.farm_bought. Coins buy more (farm hands, tractors, their speed, longer shifts), Findings (¶) buy smarter
## (their routes, irrigation). Hand nodes wait for card seasonal_workforce, tractor nodes for
## mechanisation (the desk cards that bring the first of each). The farm's old one-off upgrades keep
## their ids (seed_contract, fertiliser, irrigation, greenhouse): FarmScreen reads them from farm_bought.

const CARD := "farm_terminal"
## Every node (UpgradeTree's format: parent, at, icon, price, currency, add/mul on save numbers,
## needs). ponytail: prices are placeholders, unpaced (the old farm list's 2,500-30,000 coins); set
## them with tools/pace.py once CH1's workers are in.
const NODES := [
	{id = "hand_2", parent = "", at = Vector2(-0.6, -0.42), icon = "hand", price = 5000,
		needs = ["seasonal_workforce"], add = {farm_hands = 1}, title = "SECOND FARM HAND",
		body = "Seasonal contract. The season is permanent.\nOne more farm hand plants empty squares: 1 to 2 hands."},
	{id = "hand_speed", parent = "hand_2", at = Vector2(-1.05, -0.72), icon = "clock", price = 7500,
		mul = {farm_hand_speed = 1.5}, title = "WORK BOOTS",
		body = "Boots are issued. Laces are extra.\nFarm hands walk 50% faster."},
	{id = "hand_3", parent = "hand_speed", at = Vector2(-1.5, -1.02), icon = "hand", price = 15000,
		add = {farm_hands = 1}, title = "THIRD FARM HAND",
		body = "The bunkhouse is at capacity.\nOne more farm hand plants empty squares: 2 to 3 hands."},
	{id = "hand_route", parent = "hand_2", at = Vector2(-1.1, -0.2), icon = "lens", price = 150,
		currency = "findings", add = {farm_hand_route = 1}, title = "PLANTING ROSTER",
		body = "A roster is pinned to the barn door.\nFarm hands walk straight to an empty square instead of wandering the field."},
	# ponytail: shift prices are placeholders, unpaced; set them with tools/pace.py.
	{id = "hand_shift", parent = "hand_2", at = Vector2(-0.55, -0.95), icon = "clock", price = 9000,
		add = {farm_hand_shift = 1}, title = "MANDATORY OVERTIME",
		body = "Overtime is voluntary. Volunteering is mandatory.
Farm hands carry one more seed per trip and plant one more square before returning to the yard."},
	{id = "tractor_2", parent = "", at = Vector2(0.6, -0.42), icon = "tractor", price = 12000,
		needs = ["mechanisation"], add = {farm_tractors = 1}, title = "SECOND TRACTOR",
		body = "Leased. Never owned.\nOne more tractor harvests ripe squares: 1 to 2 tractors."},
	{id = "tractor_speed", parent = "tractor_2", at = Vector2(1.05, -0.72), icon = "clock", price = 18000,
		mul = {farm_tractor_speed = 1.5}, title = "GOVERNOR REMOVED",
		body = "The speed governor is now optional.\nTractors drive 50% faster."},
	{id = "tractor_3", parent = "tractor_speed", at = Vector2(1.5, -1.02), icon = "tractor", price = 30000,
		add = {farm_tractors = 1}, title = "THIRD TRACTOR",
		body = "Three tractors. One gate.\nOne more tractor harvests ripe squares: 2 to 3 tractors."},
	{id = "tractor_route", parent = "tractor_2", at = Vector2(1.1, -0.2), icon = "lens", price = 250,
		currency = "findings", add = {farm_tractor_route = 1}, title = "HARVEST DISPATCH",
		body = "Ripeness is now reported centrally.\nTractors drive straight to a ripe square instead of cruising the field."},
	{id = "tractor_shift", parent = "tractor_2", at = Vector2(0.55, -0.95), icon = "clock", price = 20000,
		add = {farm_tractor_shift = 1}, title = "DOUBLE SHIFT",
		body = "The night shift is the day shift, continued.
Tractors harvest one more ripe square before returning to the yard."},
	# The old one-off farm upgrades, same ids: FarmScreen reads them from farm_bought.
	{id = "fertiliser", parent = "", at = Vector2(-0.6, 0.48), icon = "sprout", price = 3000,
		title = "FERTILISER",
		body = "Its contents are not disclosed.\nSquares ripen in 20 s instead of 30 s."},
	{id = "greenhouse", parent = "fertiliser", at = Vector2(-1.05, 0.82), icon = "sprout", price = 30000,
		title = "GREENHOUSE",
		body = "Weather is no longer a factor. Nor is daylight.\nSquares ripen in 15 s."},
	{id = "irrigation", parent = "fertiliser", at = Vector2(-1.1, 0.3), icon = "lens", price = 300,
		currency = "findings", title = "IRRIGATION",
		body = "The water is metered by the drop.\nEvery harvest gives 1 more cabbage."},
	{id = "seed_contract", parent = "", at = Vector2(0.6, 0.48), icon = "crate", price = 2500,
		title = "SEED CONTRACT",
		body = "A supplier has been found. Do not ask which.\nSeed packs cost half."},
]
## Each theme's heading: [title, spot (as a node's `at`), its first nodes], part of its branch (the
## edges to its first nodes run through it; spots by tools/_theme_place.gd).
const THEMES := [
	["FARM HANDS", Vector2(-0.30, -0.21), ["hand_2"]],
	["TRACTORS", Vector2(0.30, -0.21), ["tractor_2"]],
	["SOIL", Vector2(-0.30, 0.24), ["fertiliser"]],
	["SUPPLY", Vector2(0.30, 0.24), ["seed_contract"]],
]

@export var approve_sound: AudioStream
@export var denied_sound: AudioStream

@onready var _tree: UpgradeTree = $Tree
@onready var _locked: Control = $Locked
@onready var _budget: Label = $Budget
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
	_budget.text = tr("BUDGET  $%d   |   FINDINGS  ¶%d") % [save.coins, save.findings]


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
