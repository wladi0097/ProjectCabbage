class_name SaveGame
extends Resource

@export var version := ""
## Which one-off fix-ups of old saves have run (UpgradeDesk.migrate); new saves start at MIGRATION.
@export var migration := 0
@export var created := 0
@export var last_played := 0
@export var play_seconds := 0
@export var coins := 0
## The most coins and Findings the save may hold (earn): what comes in past it is lost, so nothing
## is hoarded through a chapter's end. $40,000 and ¶8,000 at the start; chapter 3's desk cards
## cash_holding and archive_capacity multiply them by 5, then the projector's TREASURY chain
## (coin_limit_1..5, to $16M) and CH2's ARCHIVE chain (archive_1..5) raise them. A save holding more
## (an old one) keeps it and earns nothing until it is under the limit again.
@export var coin_limit := 40000
@export var findings_limit := 8000
## Unsold cabbages, the ones on the mat included. The game starts with 10 to sell.
@export var stock := 10
## The most units the stock may hold: no pack is bought and no farm square harvested past it.
## 20 at the start; the projector's storage chain (storage_1..6, then stock_15000) raises it up to 15000.
@export var storage_cap := 20
@export var sold := 0
## Cabbages grabbed in mid-air as they fly off the chute.
@export var catches := 0
@export var buy_unlocked := false
## Coins per cabbage, chalked on the price slate. Higher sells less often (see PriceSlate.demand).
@export var sale_price := 2
## The price slate drops onto the desk once its upgrade card is stamped.
@export var slate_unlocked := false
## The upgrade cards' inbox tray dropped in (first time at UpgradeDesk.TRAY_COINS), and the ids of
## the cards stamped so far, in order.
@export var tray_unlocked := false
@export var stamped := PackedStringArray()
## The cards in the inbox tray right now (the one on the press included), in slot order: the desk
## keeps it, the projector reads it (UpgradeTree.form_lock). Refilled from the queue on load.
@export var offered := PackedStringArray()
## Hidden demand: marketing multiplies the full-sale price (upgrades raise it), the mood drifts it
## each minute within PriceSlate.mood_range.
@export var marketing := 1.0
@export var demand_mood := 1.0
## Seconds since the mood last moved (it moves at PriceSlate.MOOD_PERIOD), and the step already
## rolled for its next move (what the READS THE ROOM forecast shows).
@export var mood_clock := 0.0
@export var mood_next := 0.0
## The street volatility event (GameEvents "street_volatility"): play seconds counted since the
## promotion report was signed, and whether the street now jumps heavily (PriceSlate.WILD_STEP).
@export var volatile_wait := 0.0
@export var street_volatile := false
## Head office's progress warning (GameEvents "progress_required"): play seconds a tray form has lain
## affordable with none approved (UpgradeDesk ticks it), and whether the warning has come (once).
@export var progress_wait := 0.0
@export var progress_warned := false
## Upgradeable: how many cabbages may sit on the mat (10 at most, Projector.MAT_MAX), seconds between dispenses, cabbages per pack.
@export var desk_capacity := 1
@export var dispense_interval := 1.0
## Mean seconds after a sale before the next cabbage rolls (each wait is 0.5..1.5 of it). Upgradeable
## (projector: PROMPT REPLENISHMENT and CONVEYOR III halve it).
@export var restock_delay := 0.67
@export var pack_size := 10
## Quality Assurance's output: each cabbage analysed in the QA bay adds findings_per_cabbage.
@export var findings := 0
## Seconds the QA bay analyses one cabbage, and the Findings it yields. Upgradeable (projector tree).
@export var qa_time := 5.0
@export var findings_per_cabbage := 1
## Seconds between each hired hand's trips to the mat. Upgradeable. Old saves that never changed it
## stored nothing (the old default 12 s) and so load this default too.
@export var associate_interval := 8.0
## How fast the hired hands move (times Associate's slow base speeds). Upgradeable (projector tree).
@export var associate_speed := 1.0
## Hired hands (associates): 1 once the junior associate card is stamped, +1 per further hire.
@export var hands := 0
## Pack price as a multiple of the base price (0.5..1.5), the buy pressure still pushing it up,
## and the last factors for the ticker's sparkline.
@export var price_factor := 1.0
@export var price_pressure := 0.0
@export var price_history := PackedFloat32Array()
## The projector tree's nodes bought so far (ids from Projector.NODES), in order.
@export var tree_bought := PackedStringArray()
## The projector screen has been pulled down once (until then its pull swings hard to be noticed).
@export var projector_opened := false
## Projector nodes the player has seen reachable (rolled the screen up after); newly reachable ones show as NEW.
@export var tree_seen := PackedStringArray()
## Memos filed (ids from MilestoneMemo's MEMOS, also the Steam achievements), each reward applied once.
@export var milestones := PackedStringArray()
## Tooltips already shown once (their text): from then on they wait a second of hovering (Hand).
@export var tooltips_seen := PackedStringArray()
# Manager + pricing consultant (entities/manager/, entities/consultant/).
## The manager's quota: seconds given, bonus coins per unit of quota per coin of price, and how
## much the last 5 minutes' pace is raised. Upgradeable (projector tree). Quotas met and missed.
@export var manager_time := 45.0
@export var manager_reward := 1.0
@export var manager_raise := 1.25
@export var quotas_met := 0
@export var quotas_missed := 0
## The pricing consultant: seconds between its taps on the slate. Upgradeable (projector tree).
## Old saves' consultant_skill and consultant_markup are retired: loaded, read by nothing.
@export var consultant_interval := 4.0
## Its mandate (the sheet its switch opens): on duty or away, the share of cabbages (percent) it may
## let the street refuse, and the price floor and ceiling it keeps to (0 ceiling: none).
@export var consultant_on := true
@export var consultant_bounce := 10
@export var consultant_floor := 1
@export var consultant_ceiling := 0
# Sales events: golden lamp, catch combo, rotten units + bin, window targets (entities/golden_lamp/,
# entities/catch_combo/, entities/rotten_bin/, entities/window_targets/). All upgradeable (projector tree).
## Golden lamp: sale multiplier while it glows, seconds it glows, mean seconds between glows.
@export var lamp_mult := 5.0
@export var lamp_time := 20.0
@export var lamp_every := 150.0
## Catch combo: the share of its steps a miss keeps (0 none, GRACE PERIOD 0.5), the most it
## multiplies a sale, and what each catch adds.
@export var miss_keep := 0.0
@export var combo_cap := 1.5
@export var combo_step := 0.1
## How heavily a held unit lags the hand: 1 heavy (Cabbage.follow, max_accel), 0 none (projector
## node free_carry).
@export var carry_weight := 1.0
## Rotten units come down the chute once the bin card has been offered. The bin's mouth size (×),
## the rebate per binned rotten unit in dollars (whatever the price), whether hired hands bin rotten units (0/1),
## and the fines paid and units binned so far.
@export var rotten_unlocked := false
@export var bin_mouth := 1.0
@export var bin_coins := 0
@export var hands_bin := 0
@export var fines := 0
@export var binned := 0
## Window targets: target width (×), mean seconds between targets, a hit's shower (times the sale).
@export var target_size := 1.0
@export var target_every := 60.0
@export var target_shower := 10
# Supply + automation: Open-Plan Seating, packs, auto-buy, coin vacuums, QA slots and feed
# (entities/associate/, entities/supply_console/, entities/vacuum/, entities/qa_bay/).
## Trips per hired hand per associate_interval (Open-Plan Seating raises it).
@export var hand_output := 1.0
## Pack price multiplier (cheaper-pack nodes lower it).
@export var pack_discount := 1.0
## Automatic pack buying (desk card auto_procurement): switched on at the console, buys when the
## stock is at most auto_reserve, and (stock left) waits while the price factor is above auto_max_factor.
@export var auto_buy := true
@export var auto_reserve := 3
@export var auto_max_factor := 1.5
## Coin vacuums on the mat (desk card coin_collector gives the first): count, speed (× base),
## coins carried before docking, suction radius (m), seconds recharging on the dock after emptying.
@export var vacuums := 0
@export var vacuum_speed := 1.0
@export var vacuum_capacity := 8
@export var vacuum_reach := 0.07
@export var vacuum_rest := 4.0
## Cabbages the QA bay analyses at once.
@export var qa_slots := 1
# Mini units, the tube and its lever (entities/mini_drop/): they start once the desk card
# mini_cabbages is stamped. Free (never stock), sold at mini_value times the chalked price.
## Mean seconds between mini drops, their share of the chalked price, the tube's speed (× base) and
## the lever: the share of the tube's minis sent to research (0 all sold .. 1 all to research).
@export var mini_every := 20.0
@export var mini_value := 0.25
@export var tube_speed := 1.0
@export var tube_split := 0.0
@export var minis_sold := 0
## The mini growing station (desk card mini_station): the chance a tube mini passing through it comes
## out a full-size unit (still no stock, sold at the full price). Upgradeable (projector tree).
@export var mini_grow_chance := 0.05
## Research units (blue, desk card research_cabbage): the chance a unit off the chute is one, the
## Findings it yields times a normal unit's, and how many have been analysed.
@export var research_chance := 0.1
@export var research_mult := 3.0
@export var research_units := 0
## Research hands (entities/associate/, research = true): hands that lob units into the QA bay.
@export var research_hands := 0
## HANDLING ASSIGNMENT SCHEDULE (desk card hand_schedule, entities/hand_schedule/): the cabbage kinds
## (HandSchedule.KINDS) struck for hired hands, and for lab hands: a hand never takes a kind in its list.
@export var hands_forbidden := PackedStringArray()
@export var lab_hands_forbidden := PackedStringArray()
## Units the street refused and threw back in.
@export var refusals := 0
## The radio (entities/radio/): playing or stopped, the track it is on, songs skipped, and seconds
## played with it bought but stopped (for the memos).
@export var radio_on := true
@export var radio_track := 0
@export var songs_skipped := 0
@export var radio_silent := 0.0
## Stage 2 (globalScripts/game_events.gd): the boss's warning has come (the farm card is dealt) and
## the units sold by then; wholesale prices have exploded (SupplyConsole.crate_share; with the family
## farm in too, the squeeze for good, SupplyConsole.squeezing). farm_sold: the units
## sold when the family farm card was stamped (-1: not yet), the shock's other clock (Events.shock_due).
@export var supply_warning := false
@export var warning_sold := 0
@export var farm_sold := -1
@export var supply_shock := false
## The family farm on the TV (entities/farm_screen/): seeds, open squares (0: not set up yet), each
## open square's seconds grown (-1 empty), the farm upgrades bought, and harvests so far.
@export var farm_seeds := 0
## Seeds out of the crate in farm hands' gloves (FarmScreen workers aren't saved): put back into
## farm_seeds when the farm screen next comes up, so quitting mid-trip loses none.
@export var farm_seeds_carried := 0
@export var farm_plots := 0
@export var farm_growth := PackedFloat32Array()
@export var farm_bought := PackedStringArray()
@export var farm_harvests := 0
## Seconds played since the family farm was bought (the demo ends Demo.END_AFTER of them later).
@export var farm_seconds := 0.0
## farm_seconds at the first harvest (-1: none yet); the farm terminal card (CH2) comes some time later.
@export var farm_first_harvest := -1.0
## The farm's workers walking CH1: farm hands (plant) and tractors (harvest), how fast they move
## (1.0 = base), and how they pick a square (0: at random, 1: straight to the right one).
@export var farm_hands := 0
@export var farm_tractors := 0
@export var farm_hand_speed := 1.0
@export var farm_tractor_speed := 1.0
@export var farm_hand_route := 0
@export var farm_tractor_route := 0
## Jobs a farm hand (squares planted, seeds carried from the crate) or a tractor (squares harvested)
## does on one trip before it walks back to the yard (1 = back after every job; farm tree raises it).
@export var farm_hand_shift := 1
@export var farm_tractor_shift := 1
## Golden units (desk card golden_cabbage): the chance a square planted on the farm grows golden
## (farm tree raises it), the open squares that are golden, the golden units in stock (part of
## stock, the mat's included), what one pays sold (× the price) and in the lab (× the Findings),
## golden units sold, and farm_seconds when the card was stamped (-1: not yet; the overripe event
## starts GameEvents.OVERRIPE_AFTER later).
@export var golden_chance := 0.025
@export var farm_golden := PackedInt32Array()
@export var golden_stock := 0
@export var golden_sale := 10.0
@export var golden_lab := 10.0
@export var golden_sold := 0
@export var golden_at := -1.0
## The overripe event has started (GameEvents "overripe"): ripe squares left rot_after seconds rot
## (FarmScreen.ROT_AFTER to start, CH2's SPOILAGE nodes raise it). Squares rotted so far.
@export var overripe := false
@export var rot_after := 180.0
@export var farm_rotted := 0
## GREEN THUMB (desk card green_thumb): a square harvested by hand yields hand_yield times; with
## hand_replant (farm tree, 0/1) the pulled square is replanted at once from the crate.
@export var hand_yield := 2.0
@export var hand_replant := 0
## Managerial work (desk cards own_sales, own_research, dealt by GameEvents "promotion"): a unit the
## player flicks out of the window themself pays own_sale times (× the price), one they flick into
## the research lab yields own_lab times the Findings. Hired hands, lab hands and the tube get 1×.
## 1.0 until the card (1.2); its projector chain raises it to 1.6.
@export var own_sale := 1.0
@export var own_lab := 1.0
## CONDENSE CABBAGES (desk card condense, chapter 3): how many cabbages from stock one condensed
## cabbage off the chute holds (Cabbage.units, CabbageFeeder.condensed): 1 before the card, 2 with it;
## the projector's CONDENSE II to IX raise it to 32. It counts that many times wherever it goes.
@export var condense := 1
## Cabbages a hired hand throws out of the window per trip before it goes back to its spot
## (projector node TWO-HANDED POLICY: 2).
@export var hand_trip := 1
## BIG MINDS HAVE BIG IDEAS (desk card big_ideas): the projector's wider sheet has been unrolled
## once (Projector: until then the first pull-down shows it widening).
@export var projector_wide := false
## STANDING SEED ORDER (desk card standing_seed_order): its AUTO SEED switch on CH1 (on from the
## stamp), the crate's seed count at or under which it buys a pack (farm tree SAFETY SEED STOCK
## raises it), and the pack it buys (FarmScreen.SEED_PACKS: 0 the 10, 1 the 50; farm tree).
@export var farm_auto_seed := true
@export var farm_seed_reserve := 5
@export var farm_seed_pack := 0
## The TV channel last shown (1: the fields, 2: the farm tree).
@export var farm_channel := 1
## Chapter 3's farms bought on the map: the ids of the farm sites owned (.size(): how many farms).
@export var farms_owned := PackedStringArray()
## The negotiations for the next farm (FarmRegister.haggle), one per owner: site id -> {price = the
## coin price his offers have left it at (0: still the asking price), offers = every offer made to
## him, in order (PackedInt32Array: cabbages, or coins for a bribe)}. All start over when a farm is
## bought. What an owner has in mind is never saved: it follows from `created`, the farms owned and
## the site, so reloading cannot change it.
@export var haggles := {}
## From when one owner at a time was haggled with: his offers, the price they left and his site. Only
## read to migrate (FarmRegister.haggle moves them into `haggles` and clears them).
@export var haggle_offers := PackedInt32Array()
@export var haggle_price := 0
@export var haggle_site := ""
## The map sheet that lay open last at the map table (MapTable: "world", or a country's id; "": the
## home country's). A war sheet is not kept: its country's is.
@export var map_sheet := ""
# The war (entities/war/, research/war-contract.md): soldiers bought at the PERSONNEL DEPOT.
## Trained figures ready to fight: unit id (WarRules.UNITS) -> count. A war takes its figures out
## of here (WarSheet.begin) and puts survivors back.
@export var army := {}
## Figures in training, a queue trained front first (WarRules.tick_training): each {unit, left =
## seconds}. They count toward the army cap.
@export var army_training := []
## Depot research nodes bought (WarRules.RESEARCH ids, paid in Findings), in order.
@export var unit_research := PackedStringArray()
## The depot's first drop onto the map table has played.
@export var depot_dropped := false
## The CH1 squares made farm squares, one per farm owned, picked by the player (FarmScreen.place_farm),
## and how many times a plain square's cabbages each farm square harvests (CH2's FARM OUTPUT raises it).
@export var farm_squares := PackedInt32Array()
@export var farm_square_mult := 10.0
## Seeds a farm square holds (2; CH2's SEED BEDS behind STRUCTURED FARM raise it). Each farm square's
## seeds, in farm_squares' order, oldest first: every seed's own seconds grown (it ripens and is
## harvested as its own batch) and whether it grows golden (1). farm_growth / farm_golden hold the
## oldest seed of a farm square (FarmScreen._sync). farm_square_seeds is the old count per farm square
## from when a square had one clock: only read to migrate (FarmScreen.ensure).
@export var farm_slots := 2
@export var farm_seed_clocks: Array[PackedFloat32Array] = []
@export var farm_seed_golden: Array[PackedByteArray] = []
@export var farm_square_seeds := PackedInt32Array()
## STRUCTURED FARM (desk card structured_farm): CH2's tree has been shown opening up once (FarmTree).
@export var farm_tree_wide := false
## The chute lever (card chute_control) is pulled: a metal blocker sits on the chute and no unit
## comes down it; stock only piles up.
@export var chute_blocked := false
## Big events whose boss report has been shown or filed (entities/boss_report/), GameEvents ids.
@export var reports := PackedStringArray()
## The alpha's end popup (ui/sub/alpha_end/, chapter 3's last card stamped) has been closed: it never comes again.
@export var alpha_end := false
# Playtest counters: running totals for tools/pace.py's calibration (research/numbers.md). Each is
# counted where its event already happens; the *_seconds ones add up frame time.
## Seconds with the camera at (or panning to) the farm TV (FarmTv._process).
@export var tv_seconds := 0.0
## Units harvested off the farm: pulled by the player's hand, and by tractors (FarmScreen.harvest).
@export var hand_harvested := 0
@export var tractor_harvested := 0
## Squares planted: by the player (clicks, GREEN THUMB replants) and by farm hands (FarmScreen).
@export var hand_planted := 0
@export var farm_hand_planted := 0
## Sales (full, grown and mini units) whose last throw was the player's, and a hired hand's lob
## (SaleWindow._judge, Cabbage.lobbed). Grown minis sold (the growing station's full-size ones).
@export var player_sold := 0
@export var hand_sold := 0
@export var grown_sold := 0
## Supply packs bought: the console button pressed by the player, and by the standing order.
@export var packs_manual := 0
@export var packs_auto := 0
## Coins banked in total (CoinPile, whatever paid them) and Findings yielded in total (QaBay._take).
@export var coins_earned := 0
@export var findings_earned := 0
## Golden units analysed in the QA bay (golden_sold counts the sold ones).
@export var golden_analysed := 0
## Seconds with no stock at all, with the mat full of fresh units (the chute waiting), and with the
## chute shut by its lever (CabbageFeeder.clock).
@export var empty_seconds := 0.0
@export var mat_full_seconds := 0.0
@export var chute_shut_seconds := 0.0
## The playtest log in memory (not saved: it lives in SaveManager.LOG_PATH, appended line by line).
## Saves from before that kept it here; loading one fills this, and SaveManager moves it to the file.
var playtest_log: Array[Dictionary] = []

const MIGRATION := 6
## The save field that caps each capped one (room, earn).
const LIMITS := {&"coins": &"coin_limit", &"findings": &"findings_limit"}


## How much more of `field` ("coins", "findings") fits under its limit: 0 at the limit or over it.
func room(field: StringName) -> int:
	return maxi(get(LIMITS[field]) - get(field), 0)


## Adds what fits of `amount` to `field` and returns it: the only way coins and Findings come in.
## Never takes anything away: a save over its limit keeps what it holds.
func earn(field: StringName, amount: int) -> int:
	var fits := clampi(amount, 0, room(field))
	set(field, get(field) + fits)
	return fits

## The playtest log (SaveManager.LOG_PATH, a CSV appended one line per entry; tools/pace.py reads it).
## A line starting "t,kind," is a header: a build with other columns appends a new one, and every
## line after it follows that header. Rows: "session" (id = seconds away), "minute" (every
## SaveManager.LOG_MINUTE s of play), "card"/"node"/"farm" (a purchase: id, price, currency), "farm_bought"/"war_won"
## (the map table: a row per currency; older builds also wrote "seizure"/"annexation"), "war" (a war
## order stamped: id = the farm) and "offer" (a haggle: id = which farm, price = what was offered),
## "milestone", "event", "quota_met"/"quota_missed", and "snapshot" (old builds, every 30 s).
## Every row carries the state right after it. Columns:
##   t: play seconds. kind, id, price, currency: what happened (above).
##   coins, findings, stock: held now. sold: full units sold. hands: hired hands. sale_price: $ chalked.
##   marketing: demand multiplier. catches: units caught mid-air. refusals: sales the street refused.
##   minis_sold, grown_sold: tube units sold (minis, and minis grown full-size).
##   player_sold, hand_sold: sales by the player's throws vs hired hands' lobs (minis included).
##   packs_manual, packs_auto: supply packs bought by button vs standing order.
##   coins_earned, findings_earned: totals ever earned (not held). research_units: research units analysed.
##   golden_sold, golden_analysed: golden units sold vs sent to the lab. binned, fines: rotten units binned vs fined.
##   farm_harvests: harvests. hand_harvested, tractor_harvested: units harvested by hand vs tractors.
##   hand_planted, farm_hand_planted: squares planted by the player vs farm hands. farm_rotted: squares rotted.
##   farm_hands, farm_tractors: farm workers. desk_capacity, storage_cap: mat room and stock cap.
##   tv_seconds, empty_seconds, mat_full_seconds, chute_shut_seconds: play seconds at the TV, with
##   no stock, with the mat full, with the chute shut (whole seconds).
const LOG_COLUMNS := ["t", "kind", "id", "price", "currency", "coins", "findings", "sold", "stock",
		"hands", "sale_price", "marketing", "catches", "refusals", "minis_sold", "grown_sold",
		"player_sold", "hand_sold", "packs_manual", "packs_auto", "coins_earned", "findings_earned",
		"research_units", "golden_sold", "golden_analysed", "binned", "fines", "farm_harvests",
		"hand_harvested", "tractor_harvested", "hand_planted", "farm_hand_planted", "farm_rotted",
		"farm_hands", "farm_tractors", "desk_capacity", "storage_cap", "tv_seconds", "empty_seconds",
		"mat_full_seconds", "chute_shut_seconds"]
## The first LOG_EVENT columns describe the event; the rest are save fields, read by name.
const LOG_EVENT := 5
const LOG_TEXT := ["kind", "id", "currency"]


## One playtest log line: what happened at play second `t`, and the state right after it.
func log_entry(t: int, kind: String, id := "", price := 0, currency := "") -> Dictionary:
	var entry := {t = t, kind = kind, id = id, price = price, currency = currency}
	for i in range(LOG_EVENT, LOG_COLUMNS.size()):
		var value: Variant = get(LOG_COLUMNS[i])
		if value is float and LOG_COLUMNS[i] == "marketing":
			value = snappedf(value, 0.001)
		elif value is float:
			value = roundi(value)  # The *_seconds clocks: whole seconds.
		entry[LOG_COLUMNS[i]] = value
	return entry


static func log_header() -> String:
	return ",".join(LOG_COLUMNS)


static func log_line(entry: Dictionary) -> String:
	return ",".join(LOG_COLUMNS.map(func(column: String) -> String: return str(entry.get(column, ""))))


## The log file at `path` open at its end for appending, a header written first if it is new (null if
## it can't be opened).
static func open_log(path: String) -> FileAccess:
	var fresh := not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	if file == null:
		return null
	file.seek_end()
	if fresh:
		file.store_line(log_header())
	return file


## Appends `entry` to the log file at `path` (open_log).
static func append_log(path: String, entry: Dictionary) -> void:
	var file := open_log(path)
	if file != null:
		file.store_line(log_line(entry))


## Writes the whole log file at `path` anew from `entries` (an old save's in-save log).
static func write_log(path: String, entries: Array[Dictionary]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line(log_header())
	for entry in entries:
		file.store_line(log_line(entry))


## The entries of a log file's text, each line read by the header above it; numbers come back as
## numbers, empty cells are left out.
static func parse_log(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var columns := PackedStringArray()
	for line in text.split("\n", false):
		var cells := line.strip_edges().split(",")
		if line.begins_with("t,kind,"):
			columns = cells
			continue
		var entry := {}
		for i in mini(cells.size(), columns.size()):
			var cell := cells[i]
			if cell.is_empty():
				continue
			var value: Variant = cell
			if columns[i] not in LOG_TEXT and cell.is_valid_int():
				value = cell.to_int()
			elif columns[i] not in LOG_TEXT and cell.is_valid_float():
				value = cell.to_float()
			entry[columns[i]] = value
		if entry.has("t") and entry.has("kind"):
			out.append(entry)
	return out


## Whether a log file's text needs a new header line before this build's rows: its last header differs.
static func needs_header(text: String) -> bool:
	var at := text.rfind("t,kind,")
	return not text.is_empty() and (at < 0 or text.substr(at).get_slice("\n", 0).strip_edges() != log_header())
