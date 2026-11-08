class_name SaveGame
extends Resource

@export var version := ""
## Which one-off fix-ups of old saves have run (UpgradeDesk.migrate); new saves start at MIGRATION.
@export var migration := 0
@export var created := 0
@export var last_played := 0
@export var play_seconds := 0
@export var coins := 0
## Unsold cabbages, the ones on the mat included. The game starts with 10 to sell.
@export var stock := 10
## The most units the stock may hold: no pack is bought and no farm square harvested past it.
## 20 at the start; the projector's storage chain (storage_1..6) raises it up to 9999.
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
## Hidden demand: marketing multiplies the full-sale price (upgrades raise it), the mood drifts it
## each minute within PriceSlate.MOOD_RANGE.
@export var marketing := 1.0
@export var demand_mood := 1.0
## Upgradeable: how many cabbages may sit on the mat, seconds between dispenses, cabbages per pack.
@export var desk_capacity := 1
@export var dispense_interval := 1.0
## Mean seconds after a sale before the next cabbage rolls (each wait is 0.5..1.5 of it). Upgradeable.
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
## The pricing consultant: seconds between its taps on the slate, and its skill (0 textbook price,
## 1 reads the mood, 2 best income after pack costs). Upgradeable (projector tree).
@export var consultant_interval := 4.0
@export var consultant_skill := 0
## The slate's switch: the consultant works (true) or stays away.
@export var consultant_on := true
## How far over its own target the player last left the price (0.2 = 20% over): the consultant keeps it.
@export var consultant_markup := 0.0
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
## coins carried before docking, suction radius (m).
@export var vacuums := 0
@export var vacuum_speed := 1.0
@export var vacuum_capacity := 8
@export var vacuum_reach := 0.07
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
## Units the street refused and threw back in.
@export var refusals := 0
## The radio (entities/radio/): playing or stopped, the track it is on, songs skipped, and seconds
## played with it bought but stopped (for the memos).
@export var radio_on := true
@export var radio_track := 0
@export var songs_skipped := 0
@export var radio_silent := 0.0
## Stage 2 (globalScripts/game_events.gd): the boss's warning has come (the farm card is dealt) and
## the units sold by then; wholesale prices have exploded (SupplyConsole.crate_share); seconds left
## of the wholesalers' squeeze once both the shock and the family farm are in.
@export var supply_warning := false
@export var warning_sold := 0
@export var supply_shock := false
@export var squeeze_left := 0.0
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
## The TV channel last shown (1: the fields, 2: the farm tree).
@export var farm_channel := 1
## The chute lever (card chute_control) is pulled: a metal blocker sits on the chute and no unit
## comes down it; stock only piles up.
@export var chute_blocked := false
## Big events whose boss report has been shown or filed (entities/boss_report/), GameEvents ids.
@export var reports := PackedStringArray()
## For playtests: every purchase, session start and a snapshot every SaveManager.LOG_EVERY seconds,
## each with the play time and the state after it (log_entry). Also written as playtest_log.csv.
@export var playtest_log: Array[Dictionary] = []

const MIGRATION := 4
## Snapshots older than THIN_AFTER play seconds are kept one per THIN_EVERY seconds (thin_log).
const THIN_AFTER := 3600
const THIN_EVERY := 300
const LOG_COLUMNS := ["t", "kind", "id", "price", "currency", "coins", "findings", "sold", "stock",
		"hands", "sale_price", "marketing", "catches"]


## One playtest log line: what happened at play second `t`, and the state right after it.
func log_entry(t: int, kind: String, id := "", price := 0, currency := "") -> Dictionary:
	return {t = t, kind = kind, id = id, price = price, currency = currency, coins = coins,
			findings = findings, sold = sold, stock = stock, hands = hands, sale_price = sale_price,
			marketing = snappedf(marketing, 0.001), catches = catches}


## `entries` with the snapshots from before play second `now` - THIN_AFTER kept only one per THIN_EVERY
## seconds; every other entry (purchases, milestones, sessions...) stays.
static func thin_log(entries: Array[Dictionary], now: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bucket := -1
	for entry in entries:
		var t: int = entry.t
		if entry.kind == "snapshot" and t < now - THIN_AFTER:
			@warning_ignore("integer_division")
			if t / THIN_EVERY == bucket:
				continue
			@warning_ignore("integer_division")
			bucket = t / THIN_EVERY
		out.append(entry)
	return out


func playtest_csv() -> String:
	var lines := PackedStringArray([",".join(LOG_COLUMNS)])
	for entry in playtest_log:
		lines.append(",".join(LOG_COLUMNS.map(func(column: String) -> String: return str(entry.get(column, "")))))
	return "\n".join(lines) + "\n"
