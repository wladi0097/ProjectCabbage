class_name UpgradeDesk
extends Node3D
## The upgrade cards: one-off requisition forms in a fixed queue (CARDS). The first time the coins
## reach TRAY_COINS an inbox tray drops onto the bottom-left desk and the next three cards sail
## into it. Drag one onto the approval press by the window, grab the press's red handle and crank
## it down: at the bottom the head comes down on the card. Paid from the tally, it is stamped
## approved and takes effect; once the head lifts it goes on the spike file and the next card is
## dealt. Too poor, the head thuds and the card's price blinks red. Cards with currency "findings"
## are paid in Findings (¶) instead of coins. A card let go anywhere else
## flies back. A card with `needs` is only dealt once all the cards it lists are stamped. Further
## hands are hired in the projector tree, not here. Retired ids in old saves (bulk_procurement,
## regional_billboard, rotten_bin) are skipped (migrate); a stamped billboard keeps the ×1.5 marketing it gave.
## Hovering a card in the tray lifts it and fades its full text in mid-screen (Note); clicking the spike file lists every approved card (Approved). Sits at the world origin;
## the positions below are world space.

const CARDS := [
	# The queue (pacing in tools/pace.py, graph in reports/economy_rework_2026-10-31.md). Cards wait on
	# each other (`needs`), kept loose enough that the tray usually holds two or three.
	{id = "price_slate", price = 12, title = "PRICE SLATE",
		body = "Pricing is your responsibility.\nA slate sets your price per unit (cabbage): click < or > for $1 less or more. Up to ~$3 every unit sells; above that, more are refused."},
	# No effect here: entities/radio/ drops the radio onto the desk once it is stamped.
	{id = "radio", price = 6, title = "REQUISITION A DESK RADIO", needs = ["price_slate"],
		body = "Morale is a deliverable.\nA radio on the desk. Top key: play or stop. Bottom key: next song. No other effect."},
	{id = "desk_space", price = 20, title = "DESK SPACE REALLOCATION", needs = ["radio"],
		body = "The mat has been re-zoned.\nThe chute (the ramp at bottom right) keeps 2 units waiting on the mat instead of 1."},
	{id = "junior_associate", price = 35, title = "HIRE A JUNIOR ASSOCIATE", needs = ["radio"],
		body = "Unpaid. Grateful.\nA hired hand rests at the bottom of the desk. Every 8 s it takes a unit off the mat and throws it out of the window to sell at your price."},
	{id = "acceptance_meter", price = 40, title = "ACCEPTANCE METER", needs = ["radio"],
		body = "Measured. Managed.\nA gauge on the slate shows the chance a unit sells at your price. Also, every unit now sells even at a 20% higher price."},
	{id = "quality_assurance", price = 55, title = "ESTABLISH A RESEARCH LAB", needs = ["junior_associate"],
		body = "Every unit is a lesson.\nA research lab fills the window's left third. Flick a unit in (it is used up): 5 s later a 1 Finding (¶) token pops out. Sweep your hand over it."},
	# Minis (entities/mini_drop/): free units, no stock, sold at mini_value of the chalked price; the
	# tube sells them by itself, its lever sends a share (save.tube_split) to the lab instead.
	{id = "mini_cabbages", price = 45, title = "PILOT SCHEME: MINI UNITS", needs = ["junior_associate"],
		body = "Smaller units. Same paperwork.\nAbout every 20 s a free mini unit falls onto the mat (6 at most). It uses no stock and sells for 1/4 of your price."},
	{id = "street_posters", price = 10, currency = "findings", title = "STREET POSTER CAMPAIGN",
		needs = ["quality_assurance"], body = "Findings show the street wants cabbage.\nEvery unit now sells even at a 50% higher price: raise yours on the slate to cash in."},
	{id = "projector", price = 75, title = "REQUISITION A PROJECTOR", needs = ["quality_assurance"],
		body = "Attendance is mandatory.\nA PULL tab hangs from the top of the screen: drag it down to open the upgrade tree. Hold the mouse on an upgrade to buy it with coins."},
	# Research directives (`research`): a projector node naming one in its own `research` is shown
	# locked until it is stamped. The id stays performance_review for old saves.
	{id = "research_inspection", price = 10, currency = "findings", research = true, title = "RESEARCH: INSPECTION METHODOLOGY",
		needs = ["projector"], body = "The inspection is inspected.\nOpens the RESEARCH LAB department on the projector: faster analysis, more Findings, more benches."},
	# Manager + pricing consultant: no effect here, entities/manager/ and entities/consultant/ start
	# once stamped; their small upgrades are projector nodes.
	{id = "pricing_consultant", price = 15, currency = "findings", title = "RETAIN A PRICING CONSULTANT",
		needs = ["projector", "street_posters"], body = "Billed by the hour.\nEvery 4 s its hand moves your slate $1 toward the price ~90% of units sell at. Use the arrows yourself and it leaves for 15 s. Its on/off switch is by the slate."},
	# Sales events: no effect here, entities/golden_lamp/, catch_combo/ and window_targets/ start
	# once stamped; their small upgrades are projector nodes. Stamping catch_combo also starts rotten
	# units and drops the free waste bin (GameEvents "rotten_units", entities/rotten_bin/).
	{id = "catch_combo", price = 15, currency = "findings", title = "INTERCEPTION INCENTIVE SCHEME",
		needs = ["projector"], body = "Initiative is rewarded.\nGrab a unit in mid-air (a catch): every sale pays +10%, up to +50% after 5 catches. 4 s without a catch and the bonus drains away."},
	# Research units (Cabbage.research, worlds/components/cabbage_feeder.gd) and the hands that lob
	# them into the bay (entities/associate/, save.research_hands).
	{id = "research_cabbage", price = 20, currency = "findings", title = "REQUISITION RESEARCH UNITS",
		needs = ["quality_assurance", "projector"], body = "Some units are set aside for study.\n1 in 10 units off the chute is blue. Flicked into the research lab it gives 3× the Findings. Sold, it pays like any unit."},
	{id = "mini_tube", price = 160, title = "PNEUMATIC DELIVERY TUBE", needs = ["mini_cabbages"],
		body = "Minis no longer touch the desk.\nMinis fall into a tube instead and roll out of the window by themselves. Refused ones still land on the mat."},
	{id = "performance_review", price = 25, currency = "findings", research = true, title = "RESEARCH: TIME-AND-MOTION STUDY",
		needs = ["research_inspection", "pricing_consultant"], body = "Every motion is timed.\nHired hands and lab hands set off every 4 s instead of 8 s. Unlocks Hire Associate V and Brisk Walk II on the projector."},
	# Hired hands sell rotten units (fined) until this memo, then leave them on the mat until
	# WASTE HANDLING PROTOCOL (projector) has them bin them: entities/associate/ (pick_target).
	{id = "spoilage_memo", price = 40, title = "MEMO: DO NOT HANDLE SPOILED UNITS",
		needs = ["catch_combo"], body = "Spoilage is not your concern.\nHired hands stop throwing rotten (grey) units out of the window, where each is fined 10× your price, and leave them on the mat."},
	{id = "research_assistant", price = 250, title = "HIRE A LAB ASSISTANT", needs = ["research_cabbage"],
		body = "The lab coat is deducted from pay.\nA lab hand (blue cuff) joins at the bottom left. Each time the hired hands set off (every 8 s at first), it throws a unit from the mat into the research lab, if the lab has room."},
	{id = "tube_lever", price = 350, title = "TUBE DIVERSION LEVER", needs = ["mini_tube"],
		body = "Some units are worth more as data.\nA lever by the bin: SALES / SPLIT / RESEARCH (drag or click). RESEARCH drops tube minis into the research lab like a thrown unit (back onto the mat if the lab is full); SPLIT, every other one."},
	{id = "lab_priority", price = 40, currency = "findings", title = "MEMO: LAB PRIORITY", needs = ["research_assistant"],
		body = "Research units are not for sale.\nLab hands take blue research units first. Other hired hands stop selling them."},
	{id = "managerial_oversight", price = 30, currency = "findings", title = "REQUEST MANAGERIAL OVERSIGHT",
		needs = ["performance_review"], body = "Someone will be checking.\nEvery 2.5-4 min a manager raps on the window and sets a quota: sell that many units in 45 s (your pace over the last 5 min, plus 25%). Met: quota × your price in coins. Missed: just a memo."},
	{id = "window_targets", price = 40, currency = "findings", title = "STREET TARGET PRACTICE",
		needs = ["catch_combo"], body = "The street is given a target.\nAbout every 60 s a lamp lights a crate in the street for 15 s. A unit sold out of the window in line with it pays 10× its coins on top."},
	{id = "research_materials", price = 50, currency = "findings", research = true, title = "RESEARCH: MATERIALS HANDLING",
		needs = ["managerial_oversight"], body = "Units are found to be heavy.\nUnlocks Container Orders (40 more units per pack) and the Conveyor Retrofit on the projector."},
	# Supply + automation: the console reorders packs on its own (entities/supply_console/), a coin
	# vacuum docks on the mat (entities/vacuum/); their small upgrades are projector nodes.
	{id = "auto_procurement", price = 80, currency = "findings", title = "STANDING PURCHASE ORDER",
		needs = ["research_materials"], body = "Nobody signs anything.\nAt 3 units of stock or fewer, a pack is bought by itself if you can pay. The switch beside the AUTO lamp on the supply console turns it off or on."},
	{id = "coin_collector", price = 100, currency = "findings", title = "AUTOMATED COIN RECOVERY UNIT",
		needs = ["research_materials"], body = "It does not ask why.\nA robot docks at the mat's left edge. It gathers up to 8 coins per trip off the mat and banks them, so you don't have to sweep."},
	# No effect here: entities/vacuum/ takes the research lab's slips once it is stamped.
	{id = "token_recovery", price = 600, title = "EXPANDED RECOVERY MANDATE",
		needs = ["coin_collector"], body = "Paper is also money, eventually.\nThe robots also pick up Findings tokens in front of the research lab (each takes up one coin's space in the bag) and bank them as Findings when they dock."},
	# No effect here: entities/ledger/ shows the ledger once it is stamped.
	{id = "stats_ledger", price = 120, currency = "findings", title = "REQUISITION A LEDGER",
		needs = ["managerial_oversight"], body = "Someone may read it.\nA binder on the left of the desk: click it to read your sales, coins over time, staff and approvals. No other effect."},
	{id = "research_sentiment", price = 400, currency = "findings", research = true, title = "RESEARCH: CONSUMER SENTIMENT",
		needs = ["research_materials"], body = "The street is asked how it feels.\nUnlocks Slogan IV and Brassica for the Masses on the projector (each: every unit sells even at a 25% higher price)."},
	{id = "golden_lamp", price = 3000, currency = "findings", title = "REQUISITION A DESK LAMP",
		needs = ["coin_collector"], body = "Nobody knows why.\nA lamp at the back right. About every 150 s it glows gold for 20 s: meanwhile every sale pays 5×."},
	# One more unit on the mat now (apply), and the projector's mat chain (Projector.MAT_FIRST..MAT_MAX) for the rest.
	{id = "mat_allowance", price = 3000, title = "APPLY FOR AN EXTENDED MAT ALLOWANCE",
		needs = ["coin_collector", "desk_space"], body = "Floor space is a privilege, not a right.\nOne more unit fits on the mat now (2 to 3). Then the projector offers one more unit at a time, up to 20, each dearer than the last."},
	# Stage 2 (GameEvents "supply_warning"): only dealt once that event has started (`event`), into a
	# free tray slot. entities/farm_tv/ shows the remote and the TV, entities/farm_screen/ the farm.
	{id = "family_farm", price = 2500, title = "ACQUIRE THE FAMILY FARM", event = "supply_warning",
		body = "Your uncle is selling. Family rates apply.\nA TV and remote arrive: click the remote to look at the farm. Click a square to plant a seed; after 30 s click it again to harvest 3 units into your stock. 10 seeds come with it, more in its seed shop. The wholesalers will not take this well: once their prices spike, for 5 min crates cost more than they sell for, then ease back over 5 min."},
]
const OFFERED := 3
const Events := preload("res://globalScripts/game_events.gd")
const TRAY_COINS := 15
## The card slots in the tray and the card's spot on the press pad, in their own node's space.
const SLOTS: Array[Vector3] = [Vector3(0.0, 0.02, -0.24), Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.02, 0.24)]
const PAD := Vector3(0.0, 0.047, 0.0)
## A card let go within this flat distance of the pad goes onto it.
const PRESS_REACH := 0.2
const SPIKE_STEP := 0.006
const DEAL_STAGGER := 0.12
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
## The lever (press space): pivot, handle distance from it, rest angle above level, and how far it
## swings down. Cranked fully down (crank 1) the head has come down HEAD_DROP onto the pad.
const PIVOT := Vector3(0.085, 0.27, -0.12)
const HANDLE_REACH := 0.31
const LEVER_REST := 0.1745
const LEVER_SWING := 0.6109
const HEAD_DROP := 0.08
## The crank follows the hand at most this fast (crank per second): the lever is heavy.
const CRANK_SPEED := 5.0
const BOTTOM := 0.97
## The head must come back up past this before the stamped card leaves for the spike.
const CLEAR := 0.3
const NOTE_FADE := 0.15
## Hovered, the top spiked paper rises RIFFLE_LIFT and tips up RIFFLE_TIP radians; the stack under
## it rises STACK_LIFT.
const RIFFLE_LIFT := 0.06
const RIFFLE_TIP := 0.12
const STACK_LIFT := 0.015
const RIFFLE_TIME := 0.2
## Under the top card the spike holds one cheap stack mesh, a few / some / many sheets: up to
## STACK_SIZES[i].x papers underneath show STACK_SIZES[i].y sheets.
const STACK_SIZES: Array[Vector2i] = [Vector2i(3, 2), Vector2i(10, 5), Vector2i(1 << 30, 10)]
const PAPER_NOTE := preload("res://ui/elements/paper_note.tscn")
## Then it lies this long on the pad before it goes on the spike.
const SHOW_TIME := 0.45
const SHOCK_CHECK := 0.5

## The cards on offer, in slot order (the one on the press included).
var _offered: Array[UpgradeCard] = []
var _on_press: UpgradeCard
## Stamped and waiting for the head to lift.
var _leaving: UpgradeCard
## Seconds it has lain stamped on the pad with the head up.
var _shown := 0.0
var _crank := 0.0
var _cranking := false
var _bottomed := false
var _springing: Tween
## Cards on the spike file.
var _spiked := 0
## The only real card on the spike: the last one approved, landed (the rest is _stack).
var _top: UpgradeCard
var _stack := MeshInstance3D.new()
var _riffling: Tween
## The stack meshes by sheet count, built once.
static var _stacks := {}
var _fading: Tween
## Seconds to the next check whether stage 2's warning or shock starts (Events.warning_due, shock_due).
var _shock_in := 0.0

@onready var _tray: Node3D = $Tray
@onready var _press: Node3D = $Press
@onready var _spike: Node3D = $Spike
@onready var _skeleton: Skeleton3D = $Press/Model/Armature/Skeleton3D
@onready var _head := _skeleton.find_bone("Head")
@onready var _lever := _skeleton.find_bone("Lever")
@onready var _tray_rest := _tray.position
@onready var _note: Control = $Note/Center
@onready var _papers: Control = $Approved/Shade/List/Papers


func _ready() -> void:
	var handle: Interactable = $Press/Handle/Interactable
	# The fist closes round the red ball itself.
	handle.grip_height = 0.03
	handle.reach = true
	handle.grabbed.connect(_grab_lever)
	handle.released.connect(_let_go_lever)
	$Spike/Hit/Interactable.grabbed.connect(_open_approved)
	$Spike/Hit/Interactable.hovered.connect(_riffle.bind(true))
	$Spike/Hit/Interactable.unhovered.connect(_riffle.bind(false))
	$Approved/Shade.gui_input.connect(_on_shade_input)
	var save := SaveManager.save
	migrate(save)
	_stack.material_override = UpgradeCard.MATERIAL
	_spike.add_child(_stack)
	var approved := Array(save.stamped).filter(func(id: String) -> bool: return not card_data(id).is_empty())
	if not approved.is_empty():
		var card := UpgradeCard.new(card_data(approved[-1]))
		add_child(card)
		card.stamp(false)
		card.position = _spike_spot(sheets_under(approved.size()))
		card.rotation.y = randf_range(-0.5, 0.5)
		_spiked = approved.size() - 1
		_count_spiked(card)
		_land(card)
	_pose_press()
	if save.tray_unlocked:
		_deal(false)
	else:
		_tray.visible = false
		_tray.position = _tray_rest + Vector3.UP * 10.0


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.tray_unlocked and save.coins >= TRAY_COINS:
		save.tray_unlocked = true
		_drop_tray()
	_shock_in -= delta
	if _shock_in <= 0.0 and Events.warning_due(save):
		_start(save, "supply_warning")
		_make_room()
		_deal()
	if _shock_in <= 0.0 and Events.shock_due(save):
		_start(save, "supply_shock")
	if _shock_in <= 0.0:
		_shock_in = SHOCK_CHECK
	if _cranking:
		_crank = move_toward(_crank, _crank_under_mouse(), CRANK_SPEED * delta)
		if _crank >= BOTTOM and not _bottomed:
			_bottomed = true
			_bottom_out()
	if _cranking or (_springing != null and _springing.is_running()):
		_pose_press()
	if _leaving != null and _crank < CLEAR:
		_shown += delta
	if _leaving != null and _shown >= SHOW_TIME:
		_shown = 0.0
		_leaving.spike_to(_spike_spot(sheets_under(_spiked + 1)), randf_range(-0.5, 0.5)).finished.connect(_land.bind(_leaving))
		_count_spiked(_leaving)
		_leaving = null
		if Events.warning_ready(save):
			_start(save, "supply_warning")  # The stamped card's slot goes to the farm card.
		_deal()


## The next `count` cards in the queue that are not stamped yet and whose `needs` all are. A card
## with an `event` also waits for that GameEvents event to start in `save` (never without a save),
## and once it has, comes before the rest.
static func next_cards(stamped: PackedStringArray, count: int, save: SaveGame = null) -> Array[String]:
	var out: Array[String] = []
	for events_first: bool in [true, false]:
		for card: Dictionary in CARDS:
			if card.has("event") != events_first or out.size() >= count or stamped.has(card.id):
				continue
			var open: bool = card.get("needs", []).all(func(need: String) -> bool: return stamped.has(need)) \
					and (not events_first or (save != null and Events.due(card.event, save)))
			if open:
				out.append(card.id)
	return out


## Stage 2's step `id` begins (GameEvents "supply_warning" or "supply_shock"), logged.
func _start(save: SaveGame, id: String) -> void:
	if id == "supply_warning":
		start_warning(save)
	else:
		start_shock(save)
	SaveManager.log_event("event", id)


## The boss's warning: the farm card is dealt from now on, and the shock counts units from here.
static func start_warning(save: SaveGame) -> void:
	save.supply_warning = true
	save.warning_sold = save.sold


## Wholesale prices explode: the standing order is switched off (the player may switch it back on),
## and with the farm already bought, the wholesalers' squeeze starts now.
static func start_shock(save: SaveGame) -> void:
	save.supply_shock = true
	if save.stamped.has("auto_procurement"):  # Without the card there is no order to suspend: it starts on.
		save.auto_buy = false
	if save.stamped.has("family_farm"):
		save.squeeze_left = SupplyConsole.SQUEEZE_TIME + SupplyConsole.EASE_TIME


## Card `id`'s entry, with its demo price in the demo (Demo.CARD_PRICES).
static func card_data(id: String) -> Dictionary:
	for card: Dictionary in CARDS:
		if card.id == id:
			if Events.Demo.active() and Events.Demo.CARD_PRICES.has(id):
				var demo := card.duplicate()
				demo.price = Events.Demo.CARD_PRICES[id]
				return demo
			return card
	return {}


## Fixes up a save from an older build, once (save.migration): the hands count, the acceptance
## meter's later ×1.2 marketing, the retired bulk_procurement card (now the tree's pack_1, same +3
## pack), the projector's merged chains (Projector.migrate_merged), a chalked price above
## today's cap, and a save past the supply shock from before its warning (warning filed unread).
static func migrate(save: SaveGame) -> void:
	if save.hands == 0 and save.stamped.has("junior_associate"):
		save.hands = 1  # A save from before hands were counted.
	if save.migration < 1:
		if save.stamped.has("acceptance_meter") and not meter_logged(save.playtest_log):
			save.marketing *= 1.2
		if save.stamped.has("bulk_procurement") and not save.tree_bought.has("pack_1"):
			save.tree_bought.append("pack_1")
	if save.supply_shock and not save.supply_warning:  # Past the shock before the warning existed: filed.
		start_warning(save)
		if not save.reports.has("supply_warning"):
			save.reports.append("supply_warning")
	if save.migration < 2:
		Projector.migrate_merged(save)  # The projector's merged chains (desk space, packs, coin units...).
	elif save.migration < 3:
		Projector.migrate_merged(save, Projector.MERGED_PACKS)  # The slimmed pack branch (MERGED covers it before 2).
	Projector.migrate_mat(save)  # The mat allowance, once one repeatable node, now a chain.
	save.migration = SaveGame.MIGRATION
	save.sale_price = mini(save.sale_price, PriceSlate.max_price(save.marketing))


## The playtest log shows the acceptance meter's stamp raising marketing ×1.2 already (a save from
## the build that added it, before save.migration existed).
static func meter_logged(entries: Array[Dictionary]) -> bool:
	for i in range(1, entries.size()):
		if entries[i].kind == "card" and entries[i].id == "acceptance_meter":
			return entries[i].marketing > entries[i - 1].marketing * 1.15
	return false


## What stamping card `id` does to the save. Quality assurance, the projector, the ledger, the radio,
## the mini and research-unit cards and the research directives (performance_review aside) only need
## to be in `stamped`.
static func apply(id: String, save: SaveGame) -> void:
	match id:
		"price_slate":
			save.slate_unlocked = true
		"desk_space":
			save.desk_capacity += 1
		"mat_allowance":  # The mat to 3 (an old save's may hold more: its chain nodes count as bought).
			save.desk_capacity = maxi(save.desk_capacity, Projector.MAT_FIRST - 1)
			Projector.migrate_mat(save)
		"junior_associate":
			save.hands = maxi(save.hands, 1)
		"acceptance_meter":
			save.marketing *= 1.2
		"street_posters":
			save.marketing *= 1.5
		"performance_review":
			save.associate_interval *= 0.5
		"coin_collector":
			save.vacuums = maxi(save.vacuums, 1)
		"research_assistant":
			save.research_hands = maxi(save.research_hands, 1)
		"family_farm":
			if save.supply_shock:  # Bought before the shock, the squeeze waits for it (start_shock).
				save.squeeze_left = SupplyConsole.SQUEEZE_TIME + SupplyConsole.EASE_TIME


## The handle's centre (press space) with the lever cranked `crank` of the way down.
static func handle_at(crank: float) -> Vector3:
	var angle := LEVER_REST - crank * LEVER_SWING
	return PIVOT + Vector3(0.0, sin(angle), cos(angle)) * HANDLE_REACH


## One more card on the spike: out of the mouse ray's way, and the spike now opens the approved list.
func _count_spiked(card: UpgradeCard) -> void:
	card.collision_layer = 0
	_spiked += 1
	$Spike/Hit/Interactable.enabled = true


## Only a card in the tray lifts and shows its full text; on the press, held or gone, neither.
## Picked up (`instant`), the text goes at once.
func _on_card_hover(card: UpgradeCard, on: bool, instant: bool) -> void:
	on = on and card != _on_press and _offered.has(card)
	card.lift(on)
	if on:
		$Note/Center/Paper.set_card(card_data(card.id))
	if _fading != null:
		_fading.kill()
	if instant:
		_note.modulate.a = 0.0
		return
	_fading = create_tween()
	_fading.tween_property(_note, "modulate:a", 1.0 if on else 0.0, NOTE_FADE)


## The spike clicked: every approved card, newest on top, as paper on a grey shade.
func _open_approved() -> void:
	for paper in _papers.get_children():
		paper.free()
	for id: String in approved_newest_first(SaveManager.save):
		var paper: PaperNote = PAPER_NOTE.instantiate()
		_papers.add_child(paper)
		paper.set_card(card_data(id))
	$Approved.visible = true


## The stamped cards that still exist, the last stamped first.
static func approved_newest_first(save: SaveGame) -> Array:
	var ids := Array(save.stamped).filter(func(id: String) -> bool: return not card_data(id).is_empty())
	ids.reverse()
	return ids


## A click on the shade outside the papers closes the list (the shade keeps it from the desk).
func _on_shade_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var list: Control = $Approved/Shade/List
	if not list.get_global_rect().intersection(_papers.get_global_rect()).has_point(list.get_global_mouse_position()):
		$Approved.visible = false


## Card `card` has come down on the spike: it is the new top, the old top is freed into the stack.
func _land(card: UpgradeCard) -> void:
	if _top != null:
		_top.queue_free()
	_top = card
	_stack.mesh = stack_mesh(sheets_under(_spiked))
	_stack.position = Vector3.ZERO


## How many stack sheets lie under the top paper of a pile of `papers`.
static func sheets_under(papers: int) -> int:
	if papers <= 1:
		return 0
	for size in STACK_SIZES:
		if papers - 1 <= size.x:
			return size.y
	return 0


## `sheets` thin paper sheets, each turned a little, merged into one mesh (null for none).
static func stack_mesh(sheets: int) -> Mesh:
	if sheets == 0:
		return null
	if not _stacks.has(sheets):
		var box := BoxMesh.new()
		box.size = Vector3(UpgradeCard.SIZE.x, SPIKE_STEP * 0.8, UpgradeCard.SIZE.y)
		var rng := RandomNumberGenerator.new()
		rng.seed = sheets
		var st := SurfaceTool.new()
		for i in sheets:
			var at := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), Vector3.UP * (0.045 + i * SPIKE_STEP))
			st.append_from(box, 0, at)
		_stacks[sheets] = st.commit()
	return _stacks[sheets]


## Hovered, the top paper rides up the spike and tips, and the stack under it lifts a touch, so the
## pile reads as clickable; unhovered they settle back down.
func _riffle(on: bool) -> void:
	if _riffling != null:
		_riffling.kill()
	_riffling = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_riffling.tween_property(_stack, "position:y", STACK_LIFT if on else 0.0, RIFFLE_TIME)
	if _top != null:
		var rest := _spike_spot(sheets_under(_spiked)).y
		_riffling.tween_property(_top, "position:y", rest + RIFFLE_LIFT if on else rest, RIFFLE_TIME)
		_riffling.tween_property(_top, "rotation:x", RIFFLE_TIP if on else 0.0, RIFFLE_TIME)
	if on:
		$Hover.cue(_spike.global_position)


func _spike_spot(index: int) -> Vector3:
	return _spike.position + Vector3(0.0, 0.045 + index * SPIKE_STEP, 0.0)


func _slot(index: int) -> Vector3:
	return _tray_rest + SLOTS[index]


func _pad() -> Vector3:
	return _press.transform * PAD


## A full tray when the demo's warning starts (Events.warning_due): the last card not on the press
## sinks out, so the farm card is dealt in its place (it comes back once a slot is free).
func _make_room() -> void:
	if _offered.size() < OFFERED:
		return
	for i in range(_offered.size() - 1, -1, -1):
		var card := _offered[i]
		if card != _on_press:
			_offered.remove_at(i)
			card.fly_to(Vector3(0, -10, 0), false).finished.connect(card.queue_free)
			return


## Fills the free slots from the queue (new cards sail in one after another) and moves the cards
## still on offer up to theirs. `animate` false lays them straight down (loading a save).
func _deal(animate := true) -> void:
	var dealt := 0
	# Cards on offer stay; the free slots take the next open ones (never more than OFFERED: an
	# opened card earlier in the queue than one on offer waits for a slot).
	for id in next_cards(SaveManager.save.stamped, CARDS.size(), SaveManager.save):
		if _offered.size() >= OFFERED:
			break
		if _offered.any(func(other: UpgradeCard) -> bool: return other.id == id):
			continue
		var card := UpgradeCard.new(card_data(id))
		add_child(card)
		card.dropped.connect(_on_dropped)
		card.hover_changed.connect(_on_card_hover)
		_offered.append(card)
		var slot := _slot(_offered.size() - 1)
		if not animate:
			card.position = slot
			continue
		card.position = Vector3(0, -10, 0)
		get_tree().create_timer(DEAL_STAGGER * dealt).timeout.connect(card.deal_to.bind(slot))
		dealt += 1
	for i in _offered.size():
		var card := _offered[i]
		if card != _on_press and card.position.y > -1.0 and not card.position.is_equal_approx(_slot(i)):
			card.fly_to(_slot(i))


func _on_dropped(card: UpgradeCard) -> void:
	var pad := _pad()
	var near := Vector2(card.position.x - pad.x, card.position.z - pad.z).length() < PRESS_REACH
	if near and _crank < CLEAR and _leaving == null:
		if _on_press != null and _on_press != card:
			_on_press.fly_to(_slot(_offered.find(_on_press)))
		_on_press = card
		card.fly_to(pad, true, _press.rotation.y)
		return
	if _on_press == card:
		_on_press = null
	card.fly_to(_slot(_offered.find(card)))


func _grab_lever() -> void:
	if _springing != null:
		_springing.kill()
	_cranking = true
	$Lever.cue(_press.global_position)


func _let_go_lever() -> void:
	_cranking = false
	_bottomed = false
	if _crank > CLEAR:
		$Return.cue(_press.global_position)
	_springing = create_tween()
	_springing.tween_property(self, "_crank", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# The last frame of the spring lands after _process stopped posing it.
	_springing.tween_callback(_pose_press)


## Where the mouse is along the handle's swing, 0 (rest) to 1 (fully down), read off the vertical
## plane the handle swings in, so the handle stays under the hand.
func _crank_under_mouse() -> float:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(_press.global_basis.z, _press.to_global(handle_at(0.0)))
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return _crank
	var y: float = (hit as Vector3).y - _press.global_position.y
	return clampf(inverse_lerp(handle_at(0.0).y, handle_at(1.0).y, y), 0.0, 1.0)


## The head is down: a card on the pad gets stamped if the tally can pay, else a dry thud.
func _bottom_out() -> void:
	$Press/Puff.restart()
	var save := SaveManager.save
	var card := _on_press
	if card == null or save.get(card.currency) < card.price:
		$Denied.cue(_pad())
		if card != null:
			card.blink()
		return
	save.set(card.currency, save.get(card.currency) - card.price)
	save.stamped.append(card.id)
	apply(card.id, save)
	SaveManager.log_event("card", card.id, card.price, card.currency)
	$Stamp.cue(_pad())
	card.stamp()
	_ring()
	_on_press = null
	_offered.erase(card)
	_leaving = card
	var squash := create_tween()
	squash.tween_property($Press/Model, "scale", Vector3(1.04, 0.94, 1.04), 0.05)
	squash.tween_property($Press/Model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A thin pale ring of air pushed out flat from under the head, gone in a blink.
func _ring() -> void:
	var ring: MeshInstance3D = $Press/Ring
	var ink := ring.material_override as StandardMaterial3D
	ring.visible = true
	ring.scale = Vector3(0.5, 1.0, 0.5)
	ink.albedo_color.a = 0.8
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.32)
	tween.tween_property(ink, "albedo_color:a", 0.0, 0.32)
	tween.chain().tween_callback(ring.hide)


func _pose_press() -> void:
	_skeleton.set_bone_pose_position(_head, _skeleton.get_bone_rest(_head).origin + Vector3.DOWN * HEAD_DROP * clampf(_crank, 0.0, 1.0))
	_skeleton.set_bone_pose_rotation(_lever, Quaternion(Vector3.RIGHT, LEVER_SWING * _crank)
			* _skeleton.get_bone_rest(_lever).basis.get_rotation_quaternion())
	$Press/Handle.position = handle_at(_crank)


func _drop_tray() -> void:
	_tray.visible = true
	_tray.position = _tray_rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_tray, "position", _tray_rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		$Tray/Dust.restart()
		$Thud.cue(_tray.global_position)
		_deal())
	tween.tween_property($Tray/Model, "scale", Vector3(1.06, 0.7, 1.06), 0.06)
	tween.tween_property($Tray/Model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
