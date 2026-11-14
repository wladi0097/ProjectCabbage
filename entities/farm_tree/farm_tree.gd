class_name FarmTree
extends Control
## CH2 on the farm TV (entities/farm_tv/): the farm's own upgrade tree, the projector's tree view
## (UpgradeTree) in the CRT's green phosphor, its layout and palette in farm_tree.tscn. Until desk
## card `farm_terminal` is stamped the channel shows SUBSCRIPTION PENDING instead. Bought ids go into
## save.farm_bought. Every node is paid in Findings (¶): coins stay for the projector (stage 2's coin
## sinks were walling the projector's mat and storage chains). Hand nodes wait for card seasonal_workforce, tractor nodes for
## mechanisation (the desk cards that bring the first of each). The farm's old one-off upgrades keep
## their ids (seed_contract, fertiliser, irrigation, greenhouse): FarmScreen reads them from farm_bought.
## STRUCTURED FARM (desk card WIDE_CARD, as the projector's BIG MINDS): the view opens up (it settles
## zoomed out to ZOOM_WIDE, the first time shown easing out over WIDEN_TIME with the projector's
## widening sound, save.farm_tree_wide) and the outer ring shows: the nodes that name the card in
## `needs` and their runs (SEED BEDS, the farm hands' farm rounds and satchels, and the late steps
## moved behind it: FARM OUTPUT from x20, ARCHIVE from the third). A node a save has bought always shows.

const CARD := "farm_terminal"
const WIDE_CARD := "structured_farm"
## The opened-up view: the zoom it settles at (and returns to), how far out it zooms, the opening's seconds.
const ZOOM_WIDE := 0.6
const ZOOM_MIN_WIDE := 0.2
const WIDEN_TIME := 0.9
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
		needs = ["archive_capacity"], add = {golden_chance = 0.0333}, title = "GILDED STRAIN",
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
	# FARM OUTPUT (chapter 3): what a farm square harvests, times a plain square (save.farm_square_mult,
	# FarmScreen.harvest_yield): 10× to 15×, 20×, 30×. Shown once a farm is owned (needs_farm).
	# ¶15,000 / ¶60,000 / ¶100,000 (tools/pace.py ch3): chapter 3's Findings sink, each bought a few
	# minutes before a farm whose cabbages it helps to bring in (the 2nd, the 3rd, the 5th).
	{id = "farm_mult_1", parent = "", at = Vector2(-1.55, 0.05), icon = "sprout", price = 15000, currency = "findings",
		needs = ["archive_capacity"], needs_farm = true, add = {farm_square_mult = 5.0}, title = "YIELD TARGETS",
		body = "The farm has been informed of its potential.\nEvery farm square harvests 15× a plain square's cabbages, not 10×."},
	{id = "farm_mult_2", parent = "farm_mult_1", at = Vector2(-1.6, 0.55), icon = "sprout", price = 60000, currency = "findings",
		needs = ["structured_farm"], add = {farm_square_mult = 5.0}, title = "SHARED SERVICES",
		body = "Every farm now shares one accountant.\nEvery farm square harvests 20× a plain square's cabbages, not 15×."},
	{id = "farm_mult_3", parent = "farm_mult_2", at = Vector2(-1.6, 1.05), icon = "sprout", price = 100000, currency = "findings",
		add = {farm_square_mult = 10.0}, title = "VERTICAL INTEGRATION",
		body = "The farm now reports to itself.\nEvery farm square harvests 30× a plain square's cabbages, not 20×."},
	# ARCHIVE: the most Findings the save holds (save.findings_limit, SaveGame.earn), ¶40,000 from the
	# desk card archive_capacity (`needs`: shown with it), up to ¶900,000: the Findings counter has six drums, so the ladder ends
	# under ¶1,000,000 (nothing costs more than ¶200,000). Each step costs less than the limit before it
	# and at least doubles it (the last two: half as much again); FARM OUTPUT's ¶60,000 needs the first. Paced in
	# tools/pace.py (`ch3`).
	{id = "archive_1", parent = "", at = Vector2(0.55, 1.20), icon = "crate", price = 10000, currency = "findings",
		needs = ["archive_capacity"], add = {findings_limit = 60000}, title = "SECOND CABINET",
		body = "Identical to the first. This was a requirement.\nYou can hold up to ¶100,000 instead of ¶40,000."},
	{id = "archive_2", parent = "archive_1", at = Vector2(0.55, 1.65), icon = "crate", price = 20000, currency = "findings",
		add = {findings_limit = 100000}, title = "BASEMENT STACKS",
		body = "Damp, but alphabetical.\nYou can hold up to ¶200,000 instead of ¶100,000."},
	{id = "archive_3", parent = "archive_2", at = Vector2(1.00, 1.65), icon = "crate", price = 40000, currency = "findings",
		needs = ["structured_farm"], add = {findings_limit = 200000}, title = "MICROFILM",
		body = "Every Finding, reduced to the size of a seed.\nYou can hold up to ¶400,000 instead of ¶200,000."},
	{id = "archive_4", parent = "archive_3", at = Vector2(1.00, 1.22), icon = "crate", price = 60000, currency = "findings",
		add = {findings_limit = 200000}, title = "OFF-SITE ARCHIVE",
		body = "Nobody has seen it. It is reported to be full.\nYou can hold up to ¶600,000 instead of ¶400,000."},
	{id = "archive_5", parent = "archive_4", at = Vector2(1.45, 1.50), icon = "crate", price = 100000, currency = "findings",
		add = {findings_limit = 300000}, title = "RECORD OFFICE",
		body = "The records now have records of their own.\nYou can hold up to ¶900,000 instead of ¶600,000."},
	# ---- The outer ring (desk card structured_farm; `needs` on the first of each run). Prices paced
	# in tools/pace.py (`ch3`, `flow`). ----
	# SEED BEDS: seeds a farm square holds (save.farm_slots, FarmScreen.slots_of): 2 to 3, 4, 6, each
	# seed its own batch. Only felt if the farm hands can fill them: the two runs below.
	{id = "farm_slots_1", parent = "farm_mult_1", at = Vector2(-2.0, 0.05), icon = "sprout", price = 25000, currency = "findings",
		needs = ["structured_farm"], add = {farm_slots = 1}, title = "SEED BEDS",
		body = "The field has been divided on paper.\nEvery farm square holds 3 seeds instead of 2. Each seed grows its own batch."},
	{id = "farm_slots_2", parent = "farm_slots_1", at = Vector2(-2.42, 0.05), icon = "sprout", price = 50000, currency = "findings",
		add = {farm_slots = 1}, title = "SEED BEDS II",
		body = "The paths between the beds were found to be unproductive.\nEvery farm square holds 4 seeds instead of 3."},
	{id = "farm_slots_3", parent = "farm_slots_2", at = Vector2(-2.42, 0.55), icon = "sprout", price = 110000, currency = "findings",
		add = {farm_slots = 2}, title = "SEED BEDS III",
		body = "A second layer has been approved.\nEvery farm square holds 6 seeds instead of 4."},
	# The farm hands follow: farm squares first (save.farm_hand_route 2, FarmScreen.target_for), then
	# more seeds a trip (farm_hand_shift), so the beds above are filled.
	{id = "hand_route_2", parent = "hand_route", at = Vector2(-1.6, -0.45), icon = "lens", price = 20000, currency = "findings",
		needs = ["structured_farm"], add = {farm_hand_route = 1}, title = "FARM ROUNDS",
		body = "The roster now has a first page.\nFarm hands plant the farm squares first, and plain squares only when every farm is full."},
	{id = "hand_shift_2", parent = "hand_shift", at = Vector2(-1.0, -1.5), icon = "crate", price = 45000, currency = "findings",
		needs = ["structured_farm"], add = {farm_hand_shift = 2}, title = "SEED SATCHELS",
		body = "A bag is issued. Its weight is deducted.\nFarm hands carry two more seeds per trip and plant two more before returning to the yard."},
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
	["FARM OUTPUT", Vector2(-0.77, 0.00), ["farm_mult_1"],
		"Acquired farms are held to the same targets.\nEvery farm square harvests more cabbages."],
	["ARCHIVE", Vector2(0.33, 0.72), ["archive_1"],
		"Findings need somewhere to be kept.\nThe most Findings (¶) you can hold."],
]

@export var approve_sound: AudioStream
@export var denied_sound: AudioStream
## The view opening up, the first time it shows after WIDE_CARD (the projector sheet's widening).
@export var widen_sound: AudioStream

@onready var _tree: UpgradeTree = $Tree
@onready var _locked: Control = $Locked
## The cream of the Findings counter, for the budget line's ¶ figure.
@export var findings_color: Color
## The budget line: one rich text line, so the ¶ figure (its bold font is the Findings counter's
## Oswald Bold) and the terminal words share a baseline whatever the fonts' ascents.
@onready var _budget: RichTextLabel = $BudgetLine
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
	# STRUCTURED FARM: the view settles zoomed out; the first time it is watched (the TV's viewport
	# renders) it eases out with the widening sound, after that it is simply there.
	var tv := get_viewport() as SubViewport
	if open and wide(save) and _tree.zoom_home != ZOOM_WIDE and is_visible_in_tree() \
			and (tv == null or tv.render_target_update_mode != SubViewport.UPDATE_DISABLED):
		_tree.zoom_min = ZOOM_MIN_WIDE
		if not save.farm_tree_wide:
			_play(widen_sound)
		_tree.home(ZOOM_WIDE, 0.0 if save.farm_tree_wide else WIDEN_TIME)
		save.farm_tree_wide = true
	var line := tr("BUDGET  $%d   |   FINDINGS") % save.coins \
			+ " [b][color=%s]¶%d[/color][/b]" % [findings_color.to_html(false), save.findings]
	if _budget.text != line:
		_budget.text = line


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


## Whether the save has the opened-up tree: the desk card WIDE_CARD is stamped.
static func wide(save: SaveGame) -> bool:
	return save.stamped.has(WIDE_CARD)


## The terminal is in, every desk card node `id` names in `needs` is stamped, and a farm is owned if
## it is `needs_farm`.
static func _cards_in(node: Dictionary, save: SaveGame) -> bool:
	return unlocked(save) and node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card)) \
			and (not node.get("needs_farm", false) or not save.farms_owned.is_empty())


## Shown: it and its ancestors have their cards (a whole branch shows with its feature), or the
## save bought it (an old save keeps a node that has since moved behind a card).
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	if node.is_empty() or not unlocked(save):
		return false
	return is_bought(id, save) or (_cards_in(node, save) and (node.parent == "" or is_shown(node.parent, save)))


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
	return [save.stamped.size(), save.farm_bought.size(), covered, save.farms_owned.is_empty()]
