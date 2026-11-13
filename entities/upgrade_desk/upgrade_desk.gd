class_name UpgradeDesk
extends Node3D
## The upgrade cards: one-off requisition forms in a fixed queue (CARDS). The first time the coins
## reach TRAY_COINS an inbox tray drops onto the bottom-left desk and the next three cards sail
## into it. Drag one onto the approval press by the window, grab the press's red handle and crank
## it down: at the bottom the head comes down on the card. Paid from the tally, it is stamped
## approved and takes effect; once the head lifts it goes on the spike file and the next card is
## dealt. Too poor, the head thuds and the card's price blinks red. Cards with currency "findings"
## are paid in Findings (¶) instead of coins, "stock" in units from stock. A card let go anywhere else
## flies back. A card with `needs` is only dealt once all the cards it lists are stamped. Further
## hands are hired in the projector tree, not here. Retired ids in old saves (bulk_procurement,
## regional_billboard, rotten_bin) are skipped (migrate); a stamped billboard keeps the ×1.5 marketing it gave.
## Hovering a card in the tray lifts it and fades its full text in mid-screen (Note); clicking the spike file lists every approved card (Approved). Sits at the world origin;
## the positions below are world space.

const CARDS := [
	# The queue (pacing in tools/pace.py, graph in reports/economy_rework_2026-10-31.md). Cards wait on
	# each other (`needs`), kept loose enough that the tray usually holds two or three. A card costs
	# `price` in `currency` (coins if none); `also` adds more currencies on top ({findings = 2000}),
	# all paid at once (costs, affords). Checks on a card's currency read `price`/`currency`.
	{id = "price_slate", price = 12, title = "PRICE SLATE",
		body = "Pricing is your responsibility.\nThe slate shows your price per cabbage. Click \"<\" or \">\" to change it by $1. Up to ~$3, every cabbage sells. Above that, more get refused."},
	# No effect here: entities/radio/ drops the radio onto the desk once it is stamped.
	{id = "radio", price = 6, title = "REQUISITION A DESK RADIO", needs = ["price_slate"],
		body = "Morale is a deliverable.\nA radio on the desk. Top key: play or stop. Bottom key: next song. No other effect."},
	{id = "desk_space", price = 20, title = "DESK SPACE REALLOCATION", needs = ["radio"],
		body = "The mat has been re-zoned.\nThe chute (ramp, bottom right) keeps 2 cabbages ready on the mat, not 1."},
	{id = "junior_associate", price = 35, title = "HIRE A JUNIOR ASSOCIATE", needs = ["radio"],
		body = "Unpaid. Grateful.\nA hired hand waits at the bottom of the desk. Every 8 s it throws a cabbage from the mat out of the window. It sells at your price."},
	{id = "acceptance_meter", price = 40, title = "ACCEPTANCE METER", needs = ["radio"],
		body = "Measured. Managed.\nA gauge on the slate shows how likely a cabbage sells at your price. Also, the street now pays 20% more without refusing."},
	{id = "quality_assurance", price = 55, title = "ESTABLISH A RESEARCH LAB", needs = ["junior_associate"],
		body = "Every cabbage is a lesson.\nA research lab fills the left third of the window. Flick a cabbage in (it is used up). 5 s later a Finding (¶) token pops out. Move your hand over it to collect it."},
	# Minis (entities/mini_drop/): free units, no stock, sold at mini_value of the chalked price; the
	# tube sells them by itself, its lever sends a share (save.tube_split) to the lab instead.
	{id = "mini_cabbages", price = 45, title = "PILOT SCHEME: MINI CABBAGES", needs = ["junior_associate"],
		body = "Smaller cabbages. Same paperwork.\nAbout every 20 s a free mini cabbage drops onto the mat (6 at most). It uses no stock and sells for 1/4 of your price."},
	{id = "street_posters", price = 10, currency = "findings", title = "STREET POSTER CAMPAIGN",
		needs = ["quality_assurance"], body = "Findings show the street wants cabbage.\nThe street now pays 50% more without refusing. Raise your price on the slate to cash in."},
	{id = "projector", price = 75, title = "REQUISITION A PROJECTOR", needs = ["quality_assurance"],
		body = "Attendance is mandatory.\nA PULL tab hangs from the top of the screen: drag it down to open the upgrade tree. Hold the mouse on an upgrade to buy it with coins."},
	# Research directives (`research`): a projector node naming one in its own `research` is shown
	# locked until it is stamped. The id stays performance_review for old saves.
	{id = "research_inspection", price = 10, currency = "findings", research = true, title = "RESEARCH: INSPECTION METHODOLOGY",
		needs = ["projector"], body = "The inspection is inspected.\nOpens the RESEARCH LAB department on the projector: faster analysis, more Findings, more benches."},
	# Manager + pricing consultant: no effect here, entities/manager/ and entities/consultant/ start
	# once stamped; their small upgrades are projector nodes.
	{id = "pricing_consultant", price = 15, currency = "findings", title = "RETAIN A PRICING CONSULTANT",
		needs = ["projector", "street_posters"], body = "Billed by the hour.\nEvery 4 s it moves your price $1 toward the price at which your mandate's share of cabbages is refused (10% to start). Use the arrows yourself and it leaves for 15 s. Its switch by the slate opens the mandate."},
	# Sales events: no effect here, entities/golden_lamp/, catch_combo/ and window_targets/ start
	# once stamped; their small upgrades are projector nodes. Stamping catch_combo also starts rotten
	# units and drops the free waste bin (GameEvents "rotten_units", entities/rotten_bin/).
	{id = "catch_combo", price = 15, currency = "findings", title = "INTERCEPTION INCENTIVE SCHEME",
		needs = ["projector"], body = "Initiative is rewarded.\nCatch a cabbage in mid-air: every sale pays +10%, up to +50% after 5 catches. A cabbage you let land ends the bonus."},
	# Research units (Cabbage.research, worlds/components/cabbage_feeder.gd) and the hands that lob
	# them into the bay (entities/associate/, save.research_hands).
	{id = "research_cabbage", price = 20, currency = "findings", title = "REQUISITION RESEARCH CABBAGES",
		needs = ["quality_assurance", "projector"], body = "Some cabbages are set aside for study.\n1 in 10 cabbages from the chute is blue. In the research lab it gives 3× the Findings. Sold, it pays like any cabbage."},
	{id = "mini_tube", price = 160, title = "PNEUMATIC DELIVERY TUBE", needs = ["mini_cabbages"],
		body = "Minis no longer touch the desk.\nMinis fall into a tube instead and roll out of the window by themselves. Refused ones still land on the mat."},
	{id = "performance_review", price = 25, currency = "findings", research = true, title = "RESEARCH: TIME-AND-MOTION STUDY",
		needs = ["research_inspection", "pricing_consultant"], body = "Every motion is timed.\nHired hands and lab hands set off every 4 s instead of 8 s. Unlocks Hire Associate V and Brisk Walk II on the projector."},
	# Hired hands sell rotten units (fined) until this memo, then leave them on the mat until
	# WASTE HANDLING PROTOCOL (projector) has them bin them: entities/associate/ (pick_target).
	{id = "spoilage_memo", price = 40, title = "MEMO: DO NOT HANDLE SPOILED CABBAGES",
		needs = ["catch_combo"], body = "Spoilage is not your concern.\nHired hands leave rotten (grey) cabbages on the mat. Thrown out of the window, each one costs a fine of 10× your price."},
	{id = "research_assistant", price = 250, title = "HIRE A LAB ASSISTANT", needs = ["research_cabbage"],
		body = "The lab coat is deducted from pay.\nA lab hand (blue cuff) joins at the bottom left. Each time the hired hands throw (every 8 s at first), it throws a cabbage from the mat into the research lab, if there is room."},
	{id = "tube_lever", price = 350, title = "TUBE DIVERSION LEVER", needs = ["mini_tube"],
		body = "Some cabbages are worth more as data.\nA lever by the bin: SALES / SPLIT / RESEARCH (drag or click). RESEARCH sends tube minis into the research lab (onto the mat if it is full). SPLIT sends every second one."},
	{id = "lab_priority", price = 40, currency = "findings", title = "MEMO: LAB PRIORITY", needs = ["research_assistant"],
		body = "Research cabbages are not for sale.\nLab hands take blue research cabbages first. Other hired hands stop selling them."},
	{id = "managerial_oversight", price = 30, currency = "findings", title = "REQUEST MANAGERIAL OVERSIGHT",
		needs = ["performance_review"], body = "Someone will be checking.\nEvery 2.5-4 min a manager knocks on the window with a quota: sell that many cabbages in 45 s (your pace of the last 5 min plus 25%, but never more than the chute can drop in time). Met: you get quota × your price in coins. Missed: only a memo."},
	{id = "window_targets", price = 40, currency = "findings", title = "STREET TARGET PRACTICE",
		needs = ["catch_combo"], body = "The street is given a target.\nAbout every 60 s a lamp lights a crate in the street for 15 s. Throw a cabbage out of the window in line with it: that sale pays 10× its coins on top."},
	{id = "research_materials", price = 50, currency = "findings", research = true, title = "RESEARCH: MATERIALS HANDLING",
		needs = ["managerial_oversight"], body = "Cabbages are found to be heavy.\nUnlocks Conveyor Retrofit on the projector (a cabbage down the chute every 0.5 s)."},
	# Supply + automation: the console reorders packs on its own (entities/supply_console/), a coin
	# vacuum docks on the mat (entities/vacuum/); their small upgrades are projector nodes.
	{id = "auto_procurement", price = 80, currency = "findings", title = "STANDING PURCHASE ORDER",
		needs = ["research_materials"], body = "Nobody signs anything.\nWhen stock drops to 3 cabbages or fewer, a pack is bought automatically if you can pay. The switch next to the AUTO lamp on the supply console turns this on or off."},
	{id = "coin_collector", price = 100, currency = "findings", title = "AUTOMATED COIN RECOVERY UNIT",
		needs = ["research_materials"], body = "It does not ask why.\nA robot docks at the mat's left edge. It gathers up to 8 coins per trip off the mat and banks them, so you don't have to sweep."},
	# No effect here: entities/vacuum/ takes the research lab's slips once it is stamped.
	{id = "token_recovery", price = 600, title = "EXPANDED RECOVERY MANDATE",
		needs = ["coin_collector"], body = "Paper is also money, eventually.\nThe robots also pick up Findings tokens in front of the research lab (each takes up one coin's space in the bag) and bank them as Findings when they dock."},
	# No effect here: entities/ledger/ shows the ledger once it is stamped.
	{id = "stats_ledger", price = 120, currency = "findings", title = "REQUISITION A LEDGER",
		needs = ["managerial_oversight"], body = "Someone may read it.\nA binder on the left of the desk: click it to read your sales, earnings per minute worked, staff and approvals. No other effect."},
	{id = "research_sentiment", price = 400, currency = "findings", research = true, title = "RESEARCH: CONSUMER SENTIMENT",
		needs = ["research_materials"], body = "The street is asked how it feels.\nUnlocks Slogan IV and Brassica for the Masses on the projector (each: the street pays 25% more without refusing)."},
	{id = "golden_lamp", price = 2000, currency = "findings", title = "DECLARE A GOLDEN AGE",
		needs = ["coin_collector"], body = "Nobody knows why.\nAbout every 150 s a Golden Age dawns for 20 s and the lamp at the back right glows gold. While it lasts, every sale pays 5× (golden cabbages excluded)."},
	# One more unit on the mat now (apply), and the projector's mat chain (Projector.MAT_FIRST..MAT_MAX) for the rest.
	{id = "mat_allowance", price = 3000, title = "APPLY FOR AN EXTENDED MAT ALLOWANCE",
		needs = ["coin_collector", "desk_space"], body = "Floor space is a privilege, not a right.\nOne more cabbage fits on the mat right away (3 instead of 2). After that, the projector sells one more space at a time, up to 20, each dearer than the last."},
	# Stage 2 (GameEvents "supply_warning"): only dealt once that event has started (`event`), into a
	# free tray slot. entities/farm_tv/ shows the remote and the TV, entities/farm_screen/ the farm.
	{id = "family_farm", price = 1600, title = "ACQUIRE THE FAMILY FARM", event = "supply_warning", priority = true,
		body = "Your uncle is selling. Family rates apply.\nA TV and a remote arrive. Click the remote to see the farm."},
	# Dealt with the farm, before any card paid in units, and itself paid in Findings: only units in
	# stock pay those (UpgradeDesk.spendable), and with the chute open stock keeps rolling out onto the
	# mat, so every "stock" card needs this one (in its `needs` or through their chain). No effect here:
	# entities/chute_lever/ drops the lever onto the chute once it is stamped and
	# worlds/components/cabbage_feeder.gd stops while it is pulled (save.chute_blocked). Paced in
	# tools/pace.py: stamped within a minute of the farm.
	{id = "chute_control", price = 25, currency = "findings", title = "INSTALL A SUPPLY INTERRUPTION LEVER", needs = ["family_farm"],
		body = "The street will adjust.\nA heavy lever on the back of the chute. Pull it down and a steel plate shuts the chute: no cabbages come down, stock piles up. Pull it up to reopen."},
	# Paid in units from stock (currency "stock"): 60 only fit once STOCK ROOM (projector storage_1,
	# `tree`) holds 75, so it is dealt once that node is bought, and only after the chute lever (which
	# comes with the farm). Unlocks the storage chain past it (Projector stock_100's `lock`).
	{id = "offsite_storage", price = 60, currency = "stock", tree = "storage_1", needs = ["chute_control"], title = "REQUISITION OFF-SITE STORAGE",
		body = "Space is allocated to those who can prove they need it.\nPaid in cabbages from your stock, not coins: fill the stock room first. Unlocks the storage past the stock room on the projector."},
	# The farm's big steps. The terminal opens CH2 on the TV (entities/farm_tree/): dealt with the farm,
	# and the cheapest Findings card of stage 2 after the chute lever, so it comes within a minute or two
	# of the farm (tools/pace.py: 59 min, the farm 58). Stage 2's cards are paid in Findings
	# (¶) or cabbages, the farm aside: coins stay for the projector.
	{id = "farm_terminal", price = 150, currency = "findings", title = "FARM ADMINISTRATION TERMINAL", needs = ["family_farm"],
		body = "The farm is now managed remotely.\nChannel 2 on the TV: the farm's own upgrade tree. Hold the mouse on an upgrade to buy it with Findings (¶)."},
	# No effect here: entities/farm_screen/ draws its status row (FarmScreen.status_shown) once it is
	# stamped. Dealt once the farm is bought (no card waits on a timer).
	# ponytail: the price is a placeholder, unpaced (tools/pace.py).
	{id = "farm_readout", price = 150, currency = "findings", title = "FARM TELEMETRY PACKAGE", needs = ["family_farm"],
		body = "What is measured can be reported.\nA status line along the top of channel 1 (the fields): seeds, cabbages in stock against storage, and money, always in view."},
	# From stage 2 on the next desk cards are paid in cabbages (units from stock): the first farm hand
	# (110) from CORRIDOR OVERFLOW (Projector stock_125, 125; more than the OFF-SITE LOCKER's 100), so
	# it waits for OFF-SITE STORAGE, which unlocks those (else the tray can lock up on it), then
	# GREEN THUMB (70, after the hand: `needs`). Paced in tools/pace.py: ~74 and ~76 min, the farm ~59.
	# GREEN THUMB rewards the hand farming before the tractors take over: FarmScreen.harvest(by_hand).
	{id = "seasonal_workforce", price = 110, currency = "stock", title = "AUTHORISE A SEASONAL WORKFORCE", needs = ["farm_terminal", "offsite_storage"],
		body = "Seasonal. Indefinitely.\nA farm hand walks onto the fields (channel 1) and plants empty squares with your seeds. More hands on channel 2."},
	{id = "green_thumb", price = 70, currency = "stock", title = "GREEN THUMB COMMENDATION", needs = ["seasonal_workforce"],
		body = "Manual labour is recognised. Briefly.\nA square you harvest by hand on channel 1 (pull the cabbage out) yields double. Tractors are not commended. More on channel 2."},
	# Golden units: FarmScreen.sow rolls save.golden_chance, the chute sends save.golden_stock down as
	# gold units (Cabbage.golden), SaleWindow / QaBay pay golden_sale / golden_lab times. Dealt after
	# the farm hand: paying that one's 110 took CORRIDOR OVERFLOW (125), so 120 fits. Stamped, it also
	# starts the clock on GameEvents "overripe" and deals mechanisation.
	{id = "golden_cabbage", price = 120, currency = "stock", needs = ["seasonal_workforce"],
		title = "PILOT SCHEME: PREMIUM CABBAGES",
		body = "Some cabbages are better than others. Officially.\nAbout 1 square in 40 planted on the farm grows golden. Its cabbages come down the chute gold: sold, each pays 10× your price; flicked into the research lab, 10× the Findings."},
	# Dealt right after the golden card (no card waits on a timer), ahead of GameEvents "overripe"
	# (rot) a minute later: tractors harvest before squares rot.
	{id = "mechanisation", price = 180, currency = "stock", title = "MECHANISATION PROGRAMME", needs = ["golden_cabbage"],
		body = "The horse has been informed.\nA tractor drives onto the fields (channel 1) and harvests ripe squares before they rot. More tractors on channel 2."},
	# No effect here: entities/farm_screen/ shows its AUTO SEED switch once it is stamped and buys seed
	# packs by itself (FarmScreen.auto_seed); its CH2 nodes raise the reorder point and the pack.
	{id = "standing_seed_order", price = 180, currency = "stock", title = "STANDING SEED ORDER", needs = ["mechanisation"],
		body = "Seeds are a recurring cost. Recurrence has been automated.
An AUTO SEED switch in the yard on channel 1. On, a 10-seed pack is bought by itself whenever the crate is down to 5 seeds and the money is there. More on channel 2."},
	# Managerial work (GameEvents "promotion", started by stamping mechanisation, `event`; `needs` it
	# too, so they wait for the chute lever like every card paid in units): the player's own work pays
	# more than the helpers'. apply sets save.own_sale / own_lab to 1.2, the projector's chains raise
	# them to 1.6 (Projector own_sale_1.., own_lab_1..). SaleWindow.own_factor, QaBay.findings_for.
	{id = "own_sales", price = 150, currency = "stock", title = "SOLD BY A MANAGER", event = "promotion", needs = ["mechanisation"],
		body = "A sale made by a manager is a managerial sale. It is billed accordingly.
Every cabbage you flick out of the window yourself pays 20% more. Hired hands' sales are unchanged. More on the projector."},
	{id = "own_research", price = 150, currency = "stock", title = "RESEARCHED BY A MANAGER", event = "promotion", needs = ["mechanisation"],
		body = "Findings signed by a manager are more significant. Statistically.
Every cabbage you flick into the research lab yourself gives 20% more Findings. Lab hands and the tube are unchanged. More on the projector."},
	# Stage 2 mini cards (reports/mini_cabbages_2026-11-08.md). mini_thinning: entities/mini_drop/ sends one
	# mini per farm harvest; micro_samples: QaBay.findings_for; mini_station: entities/growing_station/,
	# its chance raised by the projector's growth chain. Prices are placeholders, not paced yet
	# (tools/pace.py); micro samples is dear (¶1000) because a tube on RESEARCH floods the lab with minis.
	{id = "mini_thinning", price = 200, currency = "findings", title = "FIELD THINNING PROGRAMME", needs = ["family_farm"],
		body = "The field produces waste. Waste is a product.\nEvery harvest on the farm also sends one mini cabbage down the tube (at most 6 of these out at once)."},
	{id = "micro_samples", price = 1000, currency = "findings", title = "RESEARCH: MICRO-SAMPLE PROTOCOL", needs = ["tube_lever", "family_farm"],
		body = "Research has established that a sample need not be large. Or whole.\nA mini sent to the research lab yields eight times its usual share of Findings."},
	{id = "mini_station", price = 500, currency = "findings", title = "INSTALL A CABBAGE GROWING STATION", needs = ["mini_thinning", "mini_tube"],
		body = "Small cabbages are a temporary condition.\nA growing chamber is bolted over the tube's intake. 1 mini in 20 comes out a full cabbage: no stock, sold at your full price, counted as sold."},
	# Stage 2's end (`priority`: the oxblood form, like the farm card). Dealt once every other stage-2
	# card is stamped (these `needs` reach all of them, the mini cards aside; golden_cabbage named too, as
	# an old save's mechanisation came from migrate_farm without it). Paid in more units than
	# REGIONAL DEPOT (Projector storage_4, 1,500) holds, so it waits on AIRCRAFT HANGAR (stock_2000,
	# 2,000) and a nearly full store: below that cap by more than a harvest and a full mat, as a
	# harvest only goes in whole (FarmScreen.storage_room) and the mat can't pay. The steps past it
	# (SALT MINE to ANNEXED PROVINCE) are growth, optional before the stamp.
	# Stamped, GameEvents "invest_in_growth" starts (chapter 3). Price set by the designer: $20,000,
	# 1,900 units and ¶4,000 (the ¶ ready under 2 min after the units). Paced in tools/pace.py storage.
	{id = "consolidation", price = 1900, currency = "stock", also = {findings = 4000, coins = 20000}, priority = true, title = "CONSOLIDATED GROWTH REQUISITION",
		needs = ["offsite_storage", "farm_readout", "green_thumb", "seasonal_workforce", "standing_seed_order", "golden_cabbage"],
		body = "The desk has outgrown the desk.\nPaid in cabbages from stock, more than the regional depot holds: add storage, shut the chute, let the farm fill it. Stamped, the board reviews the desk's future."},
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
## A card landing on the spike makes the pile hop for this long (_file).
const HOP_TIME := 0.25
## The memo the first card filed on the spike posts (MilestoneMemo.post: no Steam achievement).
const SPIKE_MEMO := {re = "FILING PROCEDURE", note = "Every approved card is impaled on the spike, top right.",
	bonus = "Click the spike to review them."}
## Under the top card the spike holds one cheap stack mesh, a few / some / many sheets: up to
## STACK_SIZES[i].x papers underneath show STACK_SIZES[i].y sheets.
const STACK_SIZES: Array[Vector2i] = [Vector2i(3, 2), Vector2i(10, 5), Vector2i(1 << 30, 10)]
const PAPER_NOTE := preload("res://ui/elements/paper_note.tscn")
## Then it lies this long on the pad before it goes on the spike.
const SHOW_TIME := 0.45
const SHOCK_CHECK := 0.5
## The reminder slip's room for its big word (m, width × height) and how far it slides in.
const SLIP_BOX := Vector2(0.25, 0.08)
const SLIP_SLIDE := 0.08
## The reminder slip's paper, hovered: shown like a form's (PaperNote), with no bill.
const NOTICE := {id = "progress_notice", form = "MEMO 0-0  STANDING NOTICE", title = "NOTICE",
	body = "Head office reminds you.\nEvery form on this desk must be approved for you to progress. The projector is optional."}
## Debug builds only: a double click within this many seconds of dropping a card stamps it free.
const DEBUG_DOUBLE := 0.6
## The first-stamp hint (first_stamp_hint), until a save has ever stamped a form: none; the ghost form
## on the pad ($Press/Ghost) while the hand holds something; the ghost and the tray's affordable form
## nudging (UpgradeCard.nudge); or, a form on the pad, the STAMP tag ($Press/Handle/Tag) and the lever bobbing.
enum Hint { NONE, PAD, NUDGE, STAMP }
## The nudge or bob comes every this many checks (SHOCK_CHECK each); a bob pulls the lever this far (crank).
const HINT_BEAT := 6
const BOB := 0.08
## The ghost's outline draws on over GHOST_DRAW s as it appears, then flashes GHOST_FLASH brighter once.
const GHOST_DRAW := 0.45
const GHOST_FLASH := 1.2

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
var _riffling: Tween
## The stack meshes by sheet count, built once.
static var _stacks := {}
var _fading: Tween
## Seconds to the next check whether stage 2's warning or shock starts (Events.warning_due, shock_due).
var _shock_in := 0.0
## Seconds played since the last check: what the checks that keep a clock (_tick_progress) count.
var _since_check := 0.0
## The card dropped last and when (Time ticks, s), for the debug double click.
var _dropped: UpgradeCard
var _dropped_at := -INF
## Forms approved when the progress clock last looked (-1: not yet): one more restarts it.
var _approved_seen := -1
## The in-game menu: open, the progress clock stops (null outside the main world).
var _menu: CanvasItem
## The milestone memo layer (entities/milestone/), which posts SPIKE_MEMO.
@export var memo: Node
## Whether the first-stamp hint is still looked at (_hint): false for good once any form is stamped.
var _hinting := true
var _hint_beats := 0

@onready var _tray: Node3D = $Tray
@onready var _press: Node3D = $Press
@onready var _spike: Node3D = $Spike
## The approved papers under _top, one merged mesh (stack_mesh).
@onready var _stack: MeshInstance3D = $Spike/Stack
@onready var _skeleton: Skeleton3D = $Press/Model/Armature/Skeleton3D
@onready var _head := _skeleton.find_bone("Head")
@onready var _lever := _skeleton.find_bone("Lever")
@onready var _tray_rest := _tray.position
## The reminder slip jammed under the tray's far rim once head office's progress note is filed.
@onready var _slip: Node3D = $Tray/Slip
@onready var _slip_rest := _slip.position
@onready var _note: Control = $Note/Center
@onready var _papers: Control = $Approved/Shade/List/Papers
@onready var _ghost: MeshInstance3D = $Press/Ghost
@onready var _tag: Node3D = $Press/Handle/Tag


func _ready() -> void:
	var handle: Interactable = $Press/Handle/Interactable
	handle.grabbed.connect(_grab_lever)
	handle.released.connect(_let_go_lever)
	$Spike/Hit/Interactable.grabbed.connect(_open_approved)
	$Spike/Hit/Interactable.hovered.connect(_riffle.bind(true))
	$Spike/Hit/Interactable.unhovered.connect(_riffle.bind(false))
	$Approved/Shade.gui_input.connect(_on_shade_input)
	_menu = get_tree().root.find_child("InGameMenu", true, false) as CanvasItem
	var save := SaveManager.save
	_hinting = save.stamped.is_empty()  # A save that ever stamped a form never sees the first-stamp hint.
	var slip_hover: Interactable = $Tray/Slip/Hit/Interactable
	slip_hover.hovered.connect(_on_slip_hover.bind(true))
	slip_hover.unhovered.connect(_on_slip_hover.bind(false))
	_show_slip(slip_shown(save))
	migrate(save)
	var approved := Array(save.stamped).filter(func(id: String) -> bool: return not card_data(id).is_empty())
	if not approved.is_empty():
		var card := UpgradeCard.create(card_data(approved[-1]))
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
	_since_check += delta
	if _shock_in <= 0.0 and Events.warning_due(save):
		_start(save, "supply_warning")
		_make_room()
		_deal()
	if _shock_in <= 0.0 and Events.shock_due(save):
		_start(save, "supply_shock")
	if _shock_in <= 0.0 and Events.overripe_due(save):
		save.overripe = true
		SaveManager.log_event("event", "overripe")
		_deal()
	# Never while the tray is still dropping in (_drop_tray deals once it has landed).
	if _shock_in <= 0.0 and save.tray_unlocked and _tray.position.is_equal_approx(_tray_rest) and _leaving == null \
			and _offered.size() < OFFERED and next_cards(save.stamped, OFFERED, save).any(func(id: String) -> bool: return not _offered.any(
				func(card: UpgradeCard) -> bool: return card.id == id)):
		_deal()  # A `tree` card whose projector node was just bought, into a free slot.
	if _shock_in <= 0.0 and not _slip.visible and slip_shown(save):
		_pop_slip()
	if _shock_in <= 0.0 and _hinting:
		_hint(save, true)
	if _shock_in <= 0.0:
		_tick_progress(save, _since_check)
		_since_check = 0.0
		# The overshoot carries over (a check every SHOCK_CHECK on average), at most one check's worth
		# so a long hitch never piles up checks; the clocks above get the true time anyway.
		_shock_in = SHOCK_CHECK + maxf(_shock_in, -SHOCK_CHECK)
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
		_leaving.spike_to(_spike_spot(sheets_under(_spiked + 1)), randf_range(-0.5, 0.5)).finished.connect(_file.bind(_leaving))
		_count_spiked(_leaving)
		_leaving = null
		if Events.warning_ready(save):
			_start(save, "supply_warning")  # The stamped card's slot goes to the farm card.
		_deal()


## Head office's progress clock, `delta` play seconds on (GameEvents progress_clock, progress_due): it
## runs while a form in the tray is affordable and none is approved, also at the farm TV (the form
## still waits); it stands still while a boss report or the in-game menu is up, and stops for good
## once warned or after the chapter's last card.
func _tick_progress(save: SaveGame, delta: float) -> void:
	if save.progress_warned or Events.chapter_3(save) or BossReport.up or (_menu != null and _menu.visible):
		return
	var approved := _approved_seen >= 0 and save.stamped.size() != _approved_seen
	_approved_seen = save.stamped.size()
	var bills := _offered.filter(func(card: UpgradeCard) -> bool: return not save.stamped.has(card.id)) \
			.map(func(card: UpgradeCard) -> Dictionary: return card.costs)
	var affordable := any_affordable(save, bills, units_out(get_tree().get_nodes_in_group(&"cabbages")))
	save.progress_wait = Events.progress_clock(save.progress_wait, delta, affordable, approved)
	if Events.progress_due(save.progress_wait, save.progress_warned, affordable):
		save.progress_warned = true
		SaveManager.log_event("event", "progress_required")


## What the desk shows a player who has never stamped a form (Hint): nothing once any form was ever
## stamped or while no form on offer is affordable; with a form on the pad the press asks to be
## pulled; else the pad asks for a form, and the affordable form in the tray nudges unless the hand
## holds something.
static func first_stamp_hint(stamped_ever: bool, affordable: bool, on_pad: bool, holding: bool) -> Hint:
	if stamped_ever or not affordable:
		return Hint.NONE
	if on_pad:
		return Hint.STAMP
	return Hint.PAD if holding else Hint.NUDGE


## Shows the first-stamp hint for the desk as it is; on a `beat` every HINT_BEAT-th call nudges the
## affordable form at rest in the tray, or bobs the lever. Once a form is stamped it hides and is never
## looked at again (_hinting).
func _hint(save: SaveGame, beat := false) -> void:
	var out := units_out(get_tree().get_nodes_in_group(&"cabbages"))
	var affordable := _offered.filter(func(card: UpgradeCard) -> bool: return affords(save, card.costs, out))
	var hint := first_stamp_hint(not save.stamped.is_empty(), not affordable.is_empty(), _on_press != null, Hand.held != null)
	var ghost := hint == Hint.PAD or hint == Hint.NUDGE
	if ghost and not _ghost.visible:
		_draw_ghost()
	_ghost.visible = ghost
	_tag.visible = hint == Hint.STAMP
	_hinting = save.stamped.is_empty()
	if not beat:
		return
	_hint_beats = (_hint_beats + 1) % HINT_BEAT
	if _hint_beats != 0:
		return
	if hint == Hint.NUDGE:
		for card: UpgradeCard in affordable:
			var i := _offered.find(card)
			if card.position.is_equal_approx(_slot(i)) and (Hand.hovered == null or Hand.hovered.get_parent() != card):
				card.nudge(_pad() - card.position)
				return
	elif hint == Hint.STAMP and not _cranking and (_springing == null or not _springing.is_running()):
		_springing = create_tween().set_trans(Tween.TRANS_SINE)
		_springing.tween_property(self, "_crank", BOB, 0.16)
		_springing.tween_property(self, "_crank", 0.0, 0.22)
		_springing.tween_callback(_pose_press)


## The ghost's attention beat as it appears: its outline draws itself on around the form (GHOST_DRAW s),
## then flashes once and fades back to its slow pulse (form_ghost.gdshader `draw`, `flash`).
func _draw_ghost() -> void:
	var ink := _ghost.mesh.surface_get_material(0) as ShaderMaterial
	ink.set_shader_parameter(&"draw", 0.0)
	ink.set_shader_parameter(&"flash", 0.0)
	var tween := create_tween()
	tween.tween_property(ink, "shader_parameter/draw", 1.0, GHOST_DRAW)
	tween.tween_property(ink, "shader_parameter/flash", GHOST_FLASH, 0.08)
	tween.tween_property(ink, "shader_parameter/flash", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Whether the reminder slip is on the tray: once head office's progress note has been signed and filed.
static func slip_shown(save: SaveGame) -> bool:
	return save.reports.has("progress_required")


## The slip slides in from behind the tray, under its rim, and settles.
func _pop_slip() -> void:
	_show_slip(true)
	_slip.position = _slip_rest + Vector3(0.0, 0.0, -SLIP_SLIDE)
	var tween := create_tween()
	tween.tween_property(_slip, "position", _slip_rest, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: $Land.cue(_slip.global_position))


## Shows or hides the slip; only a shown one answers hovering (its NOTICE paper), never anything else.
func _show_slip(on: bool) -> void:
	_slip.visible = on
	($Tray/Slip/Hit/Interactable as Interactable).enabled = on
	($Tray/Slip/Hit/Shape as CollisionShape3D).disabled = not on  # Hidden, it blocks no ray.


## Whether the save covers any of `bills` (costs of the forms in the tray; `out`: see affords).
static func any_affordable(save: SaveGame, bills: Array, out := Vector2i.ZERO) -> bool:
	return bills.any(func(bill: Dictionary) -> bool: return affords(save, bill, out))


## The next `count` cards in the queue that are not stamped yet and whose `needs` all are. A timed
## card (an `event` or a `tree` node) also waits until it is due in `save` (never without a save),
## and once it is, comes before the rest.
static func next_cards(stamped: PackedStringArray, count: int, save: SaveGame = null) -> Array[String]:
	var out: Array[String] = []
	for events_first: bool in [true, false]:
		for card: Dictionary in CARDS:
			if timed(card) != events_first or out.size() >= count or stamped.has(card.id):
				continue
			var open: bool = card.get("needs", []).all(func(need: String) -> bool: return stamped.has(need)) \
					and (not events_first or (save != null and due(card, save)))
			if open:
				out.append(card.id)
	return out


## A card that waits for something in the save besides other cards: a GameEvents `event` (only one
## of UNTIMED_EVENTS, never a clock) or a projector node bought (`tree`).
static func timed(card: Dictionary) -> bool:
	return card.has("event") or card.has("tree")


## The only events a card may be dealt by: started by what the player does, never by a timer (the
## warning: the tray has run dry; the promotion: the mechanisation card is stamped). No upgrade card
## waits on a timer.
const UNTIMED_EVENTS := ["supply_warning", "promotion"]


## Whether timed card `card` is due in `save`: its event has started, its projector node is bought.
static func due(card: Dictionary, save: SaveGame) -> bool:
	return (not card.has("event") or Events.due(card.event, save)) 			and (not card.has("tree") or save.tree_bought.has(card.tree))


## Stage 2's step `id` begins (GameEvents "supply_warning" or "supply_shock"), logged. The overripe
## event starts in _process (Events.overripe_due).
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
## and with the farm already bought, the wholesalers' squeeze starts now (SupplyConsole.squeezing).
static func start_shock(save: SaveGame) -> void:
	save.supply_shock = true
	if save.stamped.has("auto_procurement"):  # Without the card there is no order to suspend: it starts on.
		save.auto_buy = false


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
## today's cap, a save past the supply shock from before its warning (warning filed unread), and
## GRACE PERIOD bought back when it lengthened the combo timer (now it halves a miss).
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
	Projector.migrate_vacuums(save)  # The coin units, once 5 steps, now with bag steps on the path.
	if save.bin_coins == 0:  # The bin rebate, once a share of the price, now flat dollars per tier.
		save.bin_coins = RottenBin.bin_coins_for(save.tree_bought)
	Projector.migrate_storage(save)  # The storage chain, once 6 steps; container orders from before the cap.
	if save.tree_bought.has("storage_2") and not save.stamped.has("offsite_storage"):
		save.stamped.append("offsite_storage")  # Bought past the stock room before the card gated it.
	save.stock = clamp_stock(save.stock, save.storage_cap)
	save.golden_stock = clamp_stock(save.golden_stock, save.stock)
	if save.stamped.has("family_farm") and save.farm_sold < 0:
		save.farm_sold = save.sold  # Bought before the farm clocked the shock: it counts from today.
	if save.stamped.has("golden_cabbage") and save.golden_at < 0.0:
		save.golden_at = save.farm_seconds  # Stamped without a clock: the overripe event comes a minute from now.
	if save.tree_bought.has("combo_window"):  # GRACE PERIOD, once a longer combo timer, now keeps half on a miss.
		save.miss_keep = maxf(save.miss_keep, 0.5)
	if save.migration < 4:
		migrate_farm(save)
	save.migration = SaveGame.MIGRATION
	save.sale_price = mini(save.sale_price, PriceSlate.max_price(save.marketing))


## Stock a loaded save holds, at most what storage can hold now (a save from a build with more room,
## or an edited one).
static func clamp_stock(stock: int, cap: int) -> int:
	return mini(stock, cap)


## An old save's one-off FARM HAND / TRACTOR (farm_bought "farm_hand", "tractor"; the ids stay there,
## unread) are now desk cards: each is stamped, with its worker.
static func migrate_farm(save: SaveGame) -> void:
	for old: Array in [["farm_hand", "seasonal_workforce"], ["tractor", "mechanisation"]]:
		if save.farm_bought.has(old[0]) and not save.stamped.has(old[1]):
			save.stamped.append(old[1])
			apply(old[1], save)


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
			save.farm_sold = save.sold  # The shock comes Events.SHOCK_AFTER_FARM units from now at the latest.
		"seasonal_workforce":  # The first farm hand walks onto CH1.
			save.farm_hands = maxi(save.farm_hands, 1)
		"mechanisation":
			save.farm_tractors = maxi(save.farm_tractors, 1)
		"golden_cabbage":  # The overripe event comes Events.OVERRIPE_AFTER farm seconds from now.
			save.golden_at = save.farm_seconds
		"own_sales":  # Managerial work: the player's own sales pay 20% more (SaleWindow.own_factor).
			save.own_sale += 0.2
		"own_research":  # And their own flicks into the lab (QaBay.findings_for).
			save.own_lab += 0.2


## What card `card` (a CARDS entry) costs, {currency: amount}: its `price` in `currency` and its
## `also`, coins first, then Findings, then units (the order the card prints them).
static func costs(card: Dictionary) -> Dictionary:
	var all: Dictionary = card.get("also", {}).duplicate()
	if card.has("price"):  # The reminder slip's NOTICE has none.
		all[card.get("currency", "coins")] = card.price
	var out := {}
	for paid_in: String in ["coins", "findings", "stock"]:
		if all.has(paid_in):
			out[paid_in] = all[paid_in]
	return out


## Whether the save covers every currency of `bill` (costs), units only from the store (spendable).
static func affords(save: SaveGame, bill: Dictionary, out := Vector2i.ZERO) -> bool:
	return bill.keys().all(func(paid_in: String) -> bool: return spendable(save, paid_in, out) >= bill[paid_in])


## What the save can pay in `currency`. In units only the ones still in the store: `out` of the
## stock are out of the chute (on the mat, in a hand, refused in the street) and can't pay.
static func spendable(save: SaveGame, currency: String, out := Vector2i.ZERO) -> int:
	return save.get(currency) - (out.x if currency == "stock" else 0)


## Takes `price` in `currency` from the save. Paid in units, they come from the store (not the `out`
## ones, x of them, y golden) and plain ones go first: golden units in the store are kept as long as
## there are plain ones to pay with.
static func pay(save: SaveGame, currency: String, price: int, out := Vector2i.ZERO) -> void:
	save.set(currency, save.get(currency) - price)
	if currency == "stock":
		save.golden_stock = out.y + maxi(clamp_stock(save.golden_stock - out.y, save.stock - out.x), 0)


## The stock units out of the chute among `cabbages`: x all of them, y the golden ones (see spendable).
static func units_out(cabbages: Array) -> Vector2i:
	var out := Vector2i.ZERO
	for cabbage: Cabbage in cabbages:
		if cabbage.in_stock():
			out += Vector2i(1, int(cabbage.golden))
	return out


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
	_fade_note(on, instant)


## The reminder slip hovered: its NOTICE on the same paper a form shows, the same way.
func _on_slip_hover(on: bool) -> void:
	if on:
		$Note/Center/Paper.set_card(NOTICE)
	_fade_note(on, false)


## The hovered paper fades in (`on`) or out, or is gone at once (`instant`).
func _fade_note(on: bool, instant: bool) -> void:
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


## A newly approved card has come down on the spike: it lands, and the pile hops and settles so the
## eye finds it. The first card a save ever files also posts SPIKE_MEMO, saying what the spike is
## (once: a loaded save's top card lands through _land alone).
func _file(card: UpgradeCard) -> void:
	_land(card)
	if _riffling != null:
		_riffling.kill()
	var rest := _spike_spot(sheets_under(_spiked)).y
	_riffling = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_riffling.tween_property(_stack, "position:y", STACK_LIFT, HOP_TIME * 0.4)
	_riffling.tween_property(card, "position:y", rest + RIFFLE_LIFT * 0.5, HOP_TIME * 0.4)
	_riffling.chain().tween_property(_stack, "position:y", 0.0, HOP_TIME * 0.6).set_trans(Tween.TRANS_BOUNCE)
	_riffling.tween_property(card, "position:y", rest, HOP_TIME * 0.6).set_trans(Tween.TRANS_BOUNCE)
	if memo != null and first_filed(SaveManager.save):
		memo.post(SPIKE_MEMO)


## Whether `save` has just approved its very first card (the one now landing on the spike).
static func first_filed(save: SaveGame) -> bool:
	return approved_newest_first(save).size() == 1


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
			_record_offered()
			card.fly_to(Vector3(0, -10, 0), false).finished.connect(card.queue_free)
			return


## Keeps save.offered (what the projector's form locks read) equal to the tray.
func _record_offered() -> void:
	SaveManager.save.offered = PackedStringArray(_offered.map(func(card: UpgradeCard) -> String: return card.id))


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
		var card := UpgradeCard.create(card_data(id))
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
	_record_offered()
	for i in _offered.size():
		var card := _offered[i]
		if card != _on_press and card.position.y > -1.0 and not card.position.is_equal_approx(_slot(i)):
			card.fly_to(_slot(i))


func _on_dropped(card: UpgradeCard) -> void:
	_dropped = card
	_dropped_at = Time.get_ticks_msec() / 1000.0
	var pad := _pad()
	var near := Vector2(card.position.x - pad.x, card.position.z - pad.z).length() < PRESS_REACH
	if near and _crank < CLEAR and _leaving == null:
		if _on_press != null and _on_press != card:
			_on_press.fly_to(_slot(_offered.find(_on_press)))
		_on_press = card
		card.fly_to(pad, true, _press.rotation.y)
	else:
		if _on_press == card:
			_on_press = null
		card.fly_to(_slot(_offered.find(card)))
	if _hinting:
		_hint(SaveManager.save)


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
	var out := units_out(get_tree().get_nodes_in_group(&"cabbages"))
	if card == null or not affords(save, card.costs, out):
		$Denied.cue(_pad())
		if card != null:
			card.blink()
		return
	for paid_in: String in card.costs:  # All or nothing: affords covered every currency.
		pay(save, paid_in, card.costs[paid_in], out)
	save.stamped.append(card.id)
	apply(card.id, save)
	for paid_in: String in card.costs:  # One log line per currency (SaveGame.LOG_COLUMNS: one price each).
		SaveManager.log_event("card", card.id, card.costs[paid_in], paid_in)
	$Stamp.cue(_pad())
	card.stamp()
	_ring()
	_on_press = null
	_offered.erase(card)
	_record_offered()
	_leaving = card
	if _hinting:
		_hint(save)  # The first stamp ever: the hint is gone for good.
	var squash := create_tween()
	squash.tween_property($Press/Model, "scale", Vector3(1.04, 0.94, 1.04), 0.05)
	squash.tween_property($Press/Model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Debug builds only: double-clicking a card on offer stamps it for free (the first click drops it, so
## the second lands while it flies back: any double click right after a drop counts).
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or not click.double_click or _dropped not in _offered:
		return
	if debug_free(OS.is_debug_build(), Time.get_ticks_msec() / 1000.0 - _dropped_at):
		_stamp_free(_dropped)


## Whether a double click `since_drop` seconds after a card was dropped stamps it free (`debug` build only).
static func debug_free(debug: bool, since_drop: float) -> bool:
	return debug and since_drop <= DEBUG_DOUBLE


func _stamp_free(card: UpgradeCard) -> void:
	var save := SaveManager.save
	save.stamped.append(card.id)
	apply(card.id, save)
	if _on_press == card:
		_on_press = null
	_offered.erase(card)
	_record_offered()
	_dropped = null
	card.stamp(false)
	$Stamp.cue(card.position)
	card.spike_to(_spike_spot(sheets_under(_spiked + 1)), randf_range(-0.5, 0.5)).finished.connect(_file.bind(card))
	_count_spiked(card)
	_deal()
	if _hinting:
		_hint(save)
	print("debug: stamped %s free" % card.id)


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
