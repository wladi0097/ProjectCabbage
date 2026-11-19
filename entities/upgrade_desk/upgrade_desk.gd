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
	# `farms` (chapter 3): the card also needs that many farms owned; a threshold, nothing is spent.
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
		needs = ["projector", "street_posters"], body = "Billed by the hour.\nEvery 4 s it moves your price $1 toward the price at which your mandate's share of cabbages is refused (10% to start). Change the price yourself and that becomes the mandate: the consultant keeps your refusal rate from then on. Its switch by the slate opens the mandate."},
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
	# No effect here: once it is stamped rotten and regular cabbages pass through each other
	# (Cabbage.SHIELD_CARD, quarantine), so the hands' throws stop knocking a rotten one out of the
	# window. Hands treat rotten ones exactly as without it. Optional (GameEvents.DRY_LEFT). Paced in
	# tools/pace.py: under half a minute of income; dealt once rotten ones come (catch_combo)
	# and the tube lever is in (earlier it held back the calibrated tube lever in the tray).
	{id = "rotten_shield", price = 60, title = "QUARANTINE PROTOCOL", needs = ["catch_combo", "tube_lever"],
		body = "Spoilage is to be isolated, not relocated.
Rotten (grey) cabbages are quarantined: other cabbages pass straight through them, so no throw or roll knocks one out of the window. Hands handle them exactly as before."},
	{id = "lab_priority", price = 40, currency = "findings", title = "MEMO: LAB PRIORITY", needs = ["research_assistant"],
		body = "Research cabbages are not for sale.\nLab hands take blue research cabbages first. Other hired hands stop selling them."},
	# Optional (no card needs it; one of GameEvents.DRY_LEFT). No effect here: entities/hand_schedule/
	# puts its switch on the desk between the hands' two parking piles once it is stamped; the paper it
	# opens strikes cabbage kinds for lab hands or hired hands (save.hands_forbidden,
	# lab_hands_forbidden). Plain cabbages and minis are listed, blue ones with lab_priority (which strikes
	# blue for hired hands: apply), golden ones with the projector's schedule_golden. Dealt with the lab
	# assistant (both kinds of hand exist). $150: a comfort, paced in tools/pace.py (chapter 1's tray).
	{id = "hand_schedule", price = 150, title = "HANDLING ASSIGNMENT SCHEDULE", needs = ["research_assistant"],
		body = "Every cabbage has a rightful hand. This is now on file.
A switch at the bottom of the desk, between the lab hands and the hired hands, opens a schedule: lab hands left, hired hands right. Click a cabbage there and that kind of hand no longer touches it. Plain cabbages to start; more kinds as the paperwork allows."},
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
		needs = ["coin_collector", "desk_space"], body = "Floor space is a privilege, not a right.\nOne more cabbage fits on the mat right away (3 instead of 2). After that, the projector sells more space a step at a time, up to 10, each dearer than the last."},
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
	# ---- Chapter 3 (the farms on the map table). Its cards follow each other by `needs` (no event
	# deals them but the first), one after the other but for two groups that arrive together: the cash
	# card, BIG MINDS and the archive card once the first is stamped (any order), then CONDENSE and
	# STRUCTURED FARM once all three are. Two optional cards lie beside the chain (nothing needs them,
	# GameEvents.DRY_LEFT): map_readout. What holds a card back is its price, and
	# farms are part of it (`farms`: that many farms owned; `home_farms`: that many of the home
	# country's; printed with the farm icon, "5 [farm] +", checked at the press, never spent). The tray
	# holds OFFERED cards: one more that is open waits for a slot (in this order). Prices paced in
	# tools/pace.py (`python tools/pace.py ch3`); the cards from the first law on are provisional. ----
	# Dealt by GameEvents "invest_in_growth" (the promotion paper, on stamping consolidation; `event`).
	# Stamped, the supply console leaves for good (SupplyConsole.retired) and the FieldLine drops in
	# on its spot (worlds/components/field_exchange.gd): its handset is the way to the map table.
	# ¶1,500: about 2 min of Findings at chapter 2's end (¶650-850 a minute), right after the last card took ¶4,000.
	{id = "market_intelligence", price = 1500, currency = "findings", title = "PROCURE MARKET INTELLIGENCE", event = "invest_in_growth", needs = ["consolidation"],
		body = "We no longer buy cabbages. We buy what is known about those who grow them.
The supply console is removed for good: no more crates. A field line takes its place: its lamps count the farms you own, of 24. Lift the handset to go to the map table."},
	# The limits (save.coin_limit $40,000, save.findings_limit ¶8,000 from the start: nothing is hoarded
	# through chapter 2's end) go up five times each, early in chapter 3 and before anything that costs
	# more than they allow: the cash card before the first farm ($60,000), the archive card before
	# CH2's YIELD TARGETS (¶15,000). Both are dealt together with BIG MINDS (all three need only the
	# card before them, stamped in any order; each fits the starting limits, BIG MINDS is paid in cabbages), and
	# what follows needs all three. apply: save.coin_limit / findings_limit x LIMIT_RAISE. Further
	# steps: the projector's coin_limit_1..5 (behind big_ideas and the cash card, like every node of
	# the wide sheet dearer than the starting purse), its archive_1..5 (in Findings). Paced in tools/pace.py (`ch3`):
	# $10,000 is about 10 s of income (the first thing chapter 3 buys) and ¶2,000 is what chapter 2's last cards leave.
	{id = "cash_holding", price = 10000, title = "RAISE THE AUTHORISED CASH HOLDING", needs = ["market_intelligence"],
		body = "Cash on the desk was capped at $40K. The cap has been reviewed.
You can hold up to $200K instead of $40K. Coins that do not fit are not paid in. More on the projector."},
	# The projector's sheet grows (Projector.screen_for, save.projector_wide) and its late-game and
	# chapter 3 nodes show (`needs = ["big_ideas"]` there). No effect here. 800 cabbages from
	# stock (chapter 3's cabbage drains start here: from the farm on, cabbages pile up): a minute or two
	# of the farm's harvest with the chute shut, so the sheet opens right after the field line.
	{id = "big_ideas", price = 800, currency = "stock", title = "BIG MINDS HAVE BIG IDEAS", needs = ["market_intelligence"],
		body = "The screen was too small for the thinking.
The projector gets a much wider screen, with new and dearer upgrades around its edge. Pull it down to see."},
	{id = "archive_capacity", price = 2000, currency = "findings", title = "EXTEND THE ARCHIVE", needs = ["market_intelligence"],
		body = "Findings are filed. The cabinet was full.
You can hold up to ¶40K instead of ¶8K. Findings that do not fit are not filed. More on channel 2."},
	# Optional (no card needs it; one of GameEvents.DRY_LEFT). No effect here: entities/map_table/ sets
	# its tally machine (props/map_tally) on the chart table once it is stamped. Dealt once the map
	# table is there (market_intelligence), after the three cards above in the queue: it takes the
	# slot the first of them frees. $8,000: a comfort, under half a minute of income (tools/pace.py `ch3`).
	{id = "map_readout", price = 8000, title = "REQUISITION A HOLDINGS INDICATOR", needs = ["market_intelligence"],
		body = "Holdings were counted by walking back to the desk. Walking has been discontinued.
A tally machine is bolted to the edge of the map table: your coins, cabbages in stock, Findings and farms owned, in view while you read the maps."},
	# Dealt with STRUCTURED FARM (below) once the three cards above are stamped; NEGOTIATION needs both.
	# Needs the first farm. apply: save.condense 2, and
	# worlds/components/cabbage_feeder.gd rolls condensed cabbages (Cabbage.units); the projector's
	# CONDENSATION branch needs it and big_ideas. $30,000: well under a minute of income once the first
	# farm is bought, for 1.7 times the sales (the chapter's first big step comes as soon as the farm
	# allows it; the farms then have to feed it).
	{id = "condense", price = 30000, farms = 1, title = "CONDENSE CABBAGES", needs = ["cash_holding", "big_ideas", "archive_capacity"],
		body = "Two cabbages now occupy the space of one. Physics has been informed.
Every plain cabbage from the chute is condensed: it takes 2 cabbages from stock and counts as 2 wherever it goes (sold, paid, researched). Research and golden cabbages follow on the projector."},
	# The home farms past the first are NOT FOR SALE until these two are stamped (FarmRegister.GATES):
	# NEGOTIATION opens the 2nd to 4th, BRIBERY the 5th. No effect here: the country sheet reads
	# save.stamped, and each farm behind them is haggled over on its deed before it is stamped
	# (FarmRegister: cabbages for the 2nd to 4th, coins for the 5th). Between them RECOVER REJECTED
	# GOODS (2 farms; FarmRegister.RECOVER): half of an offer that missed comes back. No effect here
	# either. Prices paced in tools/pace.py (`python tools/pace.py ch3`, `haggle`); PROVISIONAL.
	# CH2's farm tree opens up (FarmTree.wide, save.farm_tree_wide) and its outer ring shows (`needs =
	# ["structured_farm"]` there: SEED BEDS, the farm hands' rounds and satchels, FARM OUTPUT from x20,
	# ARCHIVE from the third step), as BIG MINDS does for the projector. No effect here. Paid in
	# Findings like the ring it opens, plus 1,000 cabbages from stock; paced in tools/pace.py (`ch3`).
	{id = "structured_farm", price = 12000, currency = "findings", also = {stock = 1000}, farms = 1, title = "STRUCTURED FARM", needs = ["cash_holding", "big_ideas", "archive_capacity"],
		body = "The farm grew. Its organisation chart did not.
The farm tree on channel 2 opens up, with new and dearer upgrades around its edge: more seeds in a farm square, and farm hands who keep up with them."},
	{id = "negotiation", price = 90000, farms = 1, title = "NEGOTIATION", needs = ["condense", "structured_farm"],
		body = "The owners said no. No is an opening position.
The next three farms on the country map are for sale again. Their deeds take offers of cabbages: enough and the price drops, too few and it rises. Cabbages offered are gone either way."},
	{id = "rejected_goods", price = 120000, also = {stock = 2500}, farms = 2, title = "RECOVER REJECTED GOODS", needs = ["negotiation"],
		body = "A refused offer was never accepted. Legal concurs.
Half of every offer an owner refuses comes back to you. Offers he accepts stay spent."},
	# Optional (no card needs it; one of GameEvents.DRY_LEFT): the golden lamp's research twin, dealt
	# with BRIBERY into the wait for its coins, while the Findings sit idle (feedback round 2, point 3
	# and 19). No effect here: entities/golden_lamp/research_light.tscn (the GoldenLamp script) drops in
	# at the desk's left once it is stamped and glows cyan about every save.lab_lamp_every s: Findings
	# ×lab_lamp_mult (QaBay.boosts). Its projector chain (lab_lamp_*) follows. ¶25,000: paced in
	# tools/pace.py (`ch3`).
	{id = "research_light", price = 25000, currency = "findings", title = "COMMISSION A RESEARCH LIGHT", needs = ["structured_farm", "rejected_goods"],
		body = "Insight is scheduled. The schedule is lit.
About every 150 s the ring light at the left of the desk glows cyan for 20 s. While it does, every cabbage taken into the research lab gives 5× the Findings (golden cabbages excluded). More on the projector."},
	{id = "bribery", price = 1500000, also = {stock = 6000}, farms = 4, title = "BRIBERY", needs = ["rejected_goods"],
		body = "Entered in the books as hospitality.
The fifth farm on the country map is for sale. Its owner does not eat cabbage: its deed takes coins in an envelope. Same rules."},
	# The war phase's trigger: dealt with BRIBERY stamped, it lies in the tray while the player works
	# toward the fifth farm (so the tray is never empty there). Costs nothing (price 0: costs() leaves it
	# out, the farm count stands in the price box); its stamp starts GameEvents "no_more_sellers", the
	# boss's THIS MEANS WAR paper, which deals the war card. Plain stock: the war is no chapter change.
	# Every card dealt from that paper on (the war card, the world map, the war line, the laws, stars)
	# costs Findings on top of its coins or cabbages (`also`, user 2026-11-16): the war is research too.
	# A ramp: the first cards a few ¶K (what a player who left research alone holds), rising card by
	# card past the ¶40K archive the archive card gives, so mid-way through the war line the projector's
	# research nodes are needed; sea lanes, the courier and stars are the big ones. Paced for that
	# player: tools/pace.py ch3 shy ("war cards" line, "research push").
	{id = "home_review", price = 0, farms = 5, title = "HOME PORTFOLIO REVIEW", needs = ["bribery"],
		body = "Five farms is a portfolio. Portfolios are reviewed.
Costs nothing. The farms are only counted. Stamped, the board reviews what is still for sale at home."},
	# War mode: dealt by GameEvents "no_more_sellers" (HOME PORTFOLIO REVIEW is stamped and the boss's
	# THIS MEANS WAR paper has come: "take what is ours"; `event`). No effect here:
	# the country sheets read save.stamped (FarmRegister.WAR_CARD): a farm nobody sells (at home the
	# last three, abroad every one) gets a WAR ORDER whose stamp rolls out the war sheet. Plain stock,
	# not the oxblood form: that is for chapter changes only (user 2026-11-14). $1,000,000, 5,000
	# cabbages and ¶2,000 (the Findings ramp's first step; tools/pace.py `ch3 shy`).
	{id = "war_mode", price = 1000000, also = {findings = 2000, stock = 5000}, title = "AUTHORISE HOSTILE ACQUISITIONS", event = "no_more_sellers", needs = ["bribery"],
		body = "They will not sell. Selling was a courtesy.
A farm that is not for sale can be taken by war: click it on its country's map for the war order. Stamp the order and the war sheet for that farm is rolled out. In Kohlmark that is the last three farms."},
	# The world map (plain stock: it opens no chapter). Needs GameEvents.HOME_SELLERS farms
	# (a test holds the two together: nobody at home sells more) and the war card (abroad nothing is
	# bought); the price is cabbages from stock
	# only. Stamped, the world sheet's roll arrives in the map table's holder (MapTable.WORLD_CARD).
	# 13,000: paced in tools/pace.py (`python tools/pace.py ch3`), the chapter's last built purchase;
	# it needs the 15,000 store (the fifth farm's 9,000 needed 9,999).
	{id = "world_map", price = 13000, currency = "stock", also = {findings = 3000}, farms = 5, title = "EXTEND THE MAPS BEYOND THE BORDER", needs = ["war_mode"],
		body = "The home market is settled. Abroad has not been consulted.
The cartographers are paid in cabbages. A chart of the world's markets is delivered to the holder at your map table: click its roll to lay it out, then click a country for its own map. Every farm abroad is taken by war."},
	# The first law (the boss's THE COUNTRY IS OURS paper, GameEvents "home_country"): needs every farm
	# site of the home country (`home_farms`, GameEvents.HOME_SITES). apply: the 19% tax is gone, so the
	# street's full-sale price is 19% higher (save.marketing x TAX_FREE) and the chalked price goes up
	# with it. The home farms past the fifth are taken by war on the country sheet (the war card,
	# FarmRegister.WAR_CARD). PROVISIONAL price, paced in tools/pace.py (`python tools/pace.py ch3`).
	{id = "no_taxes", price = 3500000, also = {findings = 120000}, home_farms = 8, title = "NO MORE TAXES ON CABBAGES", needs = ["world_map"],
		body = "Taxing cabbages was found to be an oversight. It has been corrected.
The 19% tax on cabbages is abolished and the company keeps it: every cabbage sells for 19% more."},
	# The sea (plain stock: it opens no chapter). A farm abroad can be attacked only in a country next
	# to one that is wholly ours (WorldRegister.reach); across a drawn sea lane only once this is stamped
	# (WorldRegister.SEA_CARD). Needs 13 farms: almost all 15 of the starting continent (the home
	# country's 8 and Sulvania's 3, where the lanes start, with either neighbour's 2); before it no
	# farm lies anywhere else, so `farms` counts just those. Paid in Findings and coins (the charts are
	# research). No effect here: the world sheet reads save.stamped. PROVISIONAL price (tools/pace.py ch3).
	{id = "sea_lanes", price = 200000, currency = "findings", also = {coins = 4000000}, farms = 13, title = "SEA LANES", needs = ["no_taxes"],
		body = "Water is not a border. It is a delay.
The sea lanes drawn on the world chart are opened: farms in a country across a lane from one that is wholly ours can be attacked."},
	# The war line (research/war-contract.md): beside the main line from the world map on, never behind
	# the first law (the home farms 6 to 8 are the field associates' tutorials; research/war-maps.md
	# finding 2), one card after the other, spread over the farms taken abroad by `farms`. No effect
	# here: WarRules (entities/war/war_rules.gd) reads save.stamped (unit types, army cap, mid-round
	# placing, the retreat share). EXPAND THE FIELD WORKFORCE is dealt by the boss's WE NEED BIGGER
	# ARMIES paper (GameEvents "bigger_armies_memo").
	# The unit cards (research/war-units.md section 6) hire one unit type each (WarRules.UNIT_CARD), in
	# the order the maps need them: the charge after K-8 (before Veldmark's masonry ring), the senior
	# asset before Sulvania, the pult crew before Grauland's shredders, the courier before Morrow.
	# Prices paced with the fights (tools/pace.py ch3, war pass 2026-11-14; the unit cards' in the
	# balance pass 2026-11-15, research/war-balance.md: each lands as soon as its `needs` and farms allow).
	# Each also takes Findings since 2026-11-16, on the ramp described at the review card.
	# The war line's first card, a plain form: the war sheet pencils a held figure's way to its first
	# target only once this is stamped (WarSheet.ROUTE_CARD). Cheap, right after the world map (about
	# 10 s of income at the sixth farm, tools/pace.py ch3), and 10,000 cabbages from stock (2 min of the
	# farms' harvest; it needs COMMANDEERED RAILWAY's 30,000 store). TACTICAL ADJUSTMENTS and STRATEGIC
	# WITHDRAWAL take 15,000 and 20,000 cabbages on top of their coins the same way.
	{id = "route_planning", price = 350000, also = {findings = 5000, stock = 10000}, farms = 6, title = "ISSUE PROJECTED ROUTE OVERLAYS", needs = ["world_map"],
		body = "Staff routes are pencilled on the site plan before deployment. Deviations are noted.
While you hold a staff figure over a hatched zone, a pencil line on the war sheet shows the way it will walk to its first target."},
	{id = "unit_charge", price = 1200000, also = {findings = 10000}, farms = 8, title = "AUTHORISE RESTRUCTURING CHARGES", needs = ["route_planning"],
		body = "Every wall is a regulatory matter. Some are settled on contact.
Restructuring charges join the personnel depot. Each walks straight at the first fence between it and the nearest defence and settles it on contact, itself included. Security grade takes two."},
	{id = "bigger_armies", price = 1400000, also = {findings = 120000}, farms = 10, title = "EXPAND THE FIELD WORKFORCE", event = "bigger_armies_memo", needs = ["no_taxes"],
		body = "Headcount is the only strategy the board understands.
Two more staff of any kind may take the field in one war."},
	{id = "tactics", price = 1500000, also = {findings = 20000, stock = 15000}, farms = 10, title = "AUTHORISE TACTICAL ADJUSTMENTS", needs = ["unit_charge"],
		body = "The plan may now be revised while it fails.
Staff may still be placed in a hatched zone after the attack has started."},
	{id = "unit_senior", price = 1700000, also = {findings = 45000}, farms = 11, title = "PROMOTE SENIOR ASSETS", needs = ["tactics"],
		body = "Slow, expensive and very hard to remove. Like all senior staff.
Senior assets join the personnel depot. They go for the defences only, take a great deal of punishment on the way, and count as two staff in the field."},
	{id = "unit_pult", price = 2000000, also = {findings = 60000}, farms = 14, title = "COMMISSION CABBAGE-PULT CREWS", needs = ["unit_senior"],
		body = "The cabbage has always been a projectile. Now it is a budget line.
Cabbage-pult crews join the personnel depot. They lob cabbages at the nearest defence from a distance, over any fence, and hit whatever stands next to it."},
	{id = "retreat", price = 2400000, also = {findings = 80000, stock = 20000}, farms = 15, title = "STRATEGIC WITHDRAWAL PROTOCOL", needs = ["unit_pult"],
		body = "It is not a retreat. It is a return to head office.
A war can be called off with a RETREAT button. 30% of the staff placed come home; the rest are written off."},
	{id = "unit_courier", price = 2700000, also = {findings = 200000}, farms = 17, title = "ENGAGE EXPRESS COURIERS", needs = ["retreat"],
		body = "Next-day delivery. Signature not required.
Express couriers join the personnel depot. They ride fast, hop any fence and leave it standing, and deliver themselves to the nearest defence."},
	# Chapter 3's end (`priority`, the end-of-chapter rule), last in the chain, so it reaches the tray
	# only once the card before it is stamped: `farms` is a requirement, not a price: the
	# company must own that many farms (save.farms_owned; all GameEvents.FARMS of them), none is spent
	# (costs, spendable, pay). Stamped, chapter 4 begins: its nuclear hour's cards follow below.
	# The farms are the wall (the last one is the final island); the coins and Findings on top are a
	# last lap. Chapter 4 starts with everything bought (designer 2026-11-19): every chapter 3 card,
	# projector, depot and farm tree node first. So it costs the whole vault and the whole archive (the
	# top TREASURY and ARCHIVE steps, $16M and ¶900K): out of reach before CENTRAL RESERVE, and the
	# purse is emptied by the last big nodes until those are bought. tools/pace.py ch3: the final island
	# at 168:16, the grid card 169:25, then condense_8, stock_999999, condense_9 (the last, 174:14,
	# ~$9.3M/min) and stars at 175:56, 1.7 min later (the archive is already full by then). Without
	# the sim holding it back it still comes last (176:36).
	{id = "stars", price = 16000000, also = {findings = 900000}, farms = 24, priority = true, title = "WE OWN THE WORLD. WE MUST CONTINUE IN THE STARS", needs = ["market_intelligence", "big_ideas", "condense", "negotiation", "bribery", "war_mode", "world_map", "no_taxes", "sea_lanes", "bigger_armies", "retreat", "unit_courier"],
		body = "There is nothing left to buy down here.
The field line counts the farms. Stamped, the board looks up, and the next forms on the desk are nuclear."},
	# ---- Chapter 4, part 0: NUCLEAR (research/gameplan.md, decided 2026-11-19). The hour after
	# `stars`, before the flagship: ten cards, one after the other by `needs`, each opening projector
	# and farm tree chains (needs = [this card] there). Paid in coins and Findings like the war phase's
	# cards. Prices paced in tools/pace.py (`python tools/pace.py ch4`): ~60 min from stars to the
	# programme card, ~100 purchases. ----
	# Every mechanical number display turns into a green digital readout (entities/tally_machine/ and
	# the other counters read save.stamped), and the purse holds NUMBERS_RAISE times as much (apply).
	{id = "print_numbers", price = 14000000, title = "PRINT LARGER NUMBERS", needs = ["stars"],
		body = "The drums have run out of digits. Accounts have asked for more digits.
Every counter on the desk becomes a digital readout that prints large sums short (4.5B). You can hold up to $40M instead of $16M. More on the projector."},
	{id = "nuclear_research", price = 15000000, also = {findings = 180000}, title = "NUCLEAR RESEARCH", needs = ["print_numbers"],
		body = "Fission is a growth sector. The board has approved one.
NUCLEAR opens on the projector: the street's price and the Findings per cabbage. ENRICHED SOIL opens on the farm tree."},
	{id = "half_life", price = 74000000, also = {findings = 620000}, title = "HALF-LIFE ACCOUNTING", needs = ["nuclear_research"],
		body = "Assets that decay slowly are booked as permanent.
CHAIN REACTION (research cabbages), the DECAY ARCHIVE (Findings limit) and DECAY PREMIUM: LAB (golden cabbages in the research lab) open on the projector."},
	# No effect here: entities/coins/ mints the coins above $10K once it is stamped.
	{id = "critical_mass", price = 120000000, also = {findings = 1900000}, title = "CRITICAL MASS", needs = ["half_life"],
		body = "Enough money in one place starts a reaction.
Seven larger coins are minted, $50K to $1B: payouts come in fewer, heavier coins. Merges past the $10K coin open on the projector."},
	{id = "isotope_seed", price = 190000000, also = {findings = 3700000, stock = 150000}, title = "ISOTOPE-ENRICHED SEED", needs = ["critical_mass"],
		body = "The seed has been improved at the atomic level. The packet has not.
ACCELERATED RIPENING (squares ripen sooner) and MUTATION (more golden squares) open on the farm tree."},
	{id = "lead_storage", price = 250000000, also = {findings = 4400000, stock = 300000}, title = "LEAD-LINED STORAGE", needs = ["isotope_seed"],
		body = "The warehouses glow faintly. Stock levels are unaffected.
LEAD LINING takes storage past 999.999 cabbages, and DECAY PREMIUM: SALE raises what golden cabbages sell for. Both on the projector."},
	{id = "reactor_machinery", price = 370000000, also = {findings = 5500000, stock = 400000}, title = "REACTOR-POWERED MACHINERY", needs = ["lead_storage"],
		body = "Every tractor now has a reactor. Every reactor has a logbook.
REACTOR DRIVES (faster farm hands and tractors) open on the farm tree, HANDLED WITH TONGS (your own sales and research) on the projector."},
	{id = "enrichment_cascade", price = 490000000, also = {findings = 6200000, stock = 600000}, title = "ENRICHMENT CASCADE", needs = ["reactor_machinery"],
		body = "The compactor is now fed through a cascade of centrifuges. The cabbages spin.
CONDENSE X, XI and XII open on the projector: 48, 64 and 96 to a cabbage."},
	# The compaction cards (user 2026-11-19): the chute cannot move cabbages faster, so money comes
	# from what each one holds. Each opens CONDENSE steps past XII and NUCLEAR rows that pay for them.
	{id = "pressure_vessel", price = 560000000, also = {findings = 6700000, stock = 1000000}, title = "PRESSURE VESSEL PROTOCOL", needs = ["enrichment_cascade"],
		body = "The compactor now runs at a pressure the vessel was not rated for. The vessel has been re-rated.
CONDENSE XIII, XIV and XV open on the projector (128, 192 and 256 to a cabbage), with denser research and golden cabbages and CRITICAL PRICING."},
	{id = "nuclear_family", price = 470000000, also = {findings = 7400000, stock = 800000}, title = "NUCLEAR FAMILY", needs = ["pressure_vessel"],
		body = "Staff housing has been moved next to the cooling towers. Families are welcome.
A sixth, seventh and eighth farm hand and tractor open on the farm tree, with a hut and a parking bay each in the yard."},
	{id = "degenerate_matter", price = 1600000000, also = {findings = 7800000, stock = 1500000}, title = "DEGENERATE MATTER POLICY", needs = ["nuclear_family"],
		body = "The atoms in the compactor no longer have room for their own electrons. Facilities has been informed.
CONDENSE XVI opens on the projector (384 to a cabbage), and ISOMER PREMIUM for golden cabbages."},
	# The nuclear hour's end (`priority`, like the end of every chapter). The flagship build follows
	# (not built yet): until then the alpha's end popup comes (ui/sub/alpha_end) once it is stamped.
	{id = "star_programme", price = 3200000000, also = {findings = 9000000, stock = 1500000}, priority = true, title = "CABBAGE STAR PROGRAMME", needs = ["degenerate_matter"],
		body = "The planet is fully booked. The board has looked up.
Stamped, the programme begins. Its first vessel is still on the drawing board."},
	# The annexed grid (Projector.GRID_CARD; decision 2026-11-17): the conquered countries' power
	# is rerouted to the compactor. The projector's
	# CONDENSE chain stops at V (8 to a cabbage), and at 20 farms this one takes a plain condensed
	# cabbage to 12 and opens CONDENSE VII to IX (16, 24, 32). It replaced CONDENSE VI: a save that
	# bought that node has it filed (Projector.migrate_condense_cap). Optional (GameEvents.DRY_LEFT),
	# dealt with the courier card, after the chain's end in the queue so it never holds
	# back a chain card (needs STRATEGIC WITHDRAWAL, not just CONDENSE: a 20-farm card
	# dealt at the first farm would sit in the tray for two hours). A reward, so cheap in coins: half a
	# minute of income at 20 farms; its Findings are the courier card's (the war ramp only climbs), about
	# 2.5 min of research (tools/pace.py `ch3`).
	{id = "annexed_grid", price = 2000000, also = {findings = 200000}, farms = 20, title = "ANNEXED POWER GRID: COMPACTOR SUPPLY", needs = ["condense", "retreat"],
		body = "The annexed countries had a power grid. It now has one customer.
Their grid feeds the compactor. Every plain cabbage from the chute holds 12 cabbages. CONDENSE VII, VIII and IX open on the projector: 16, 24 and 32 to a cabbage."},
	# Optional (no card needs it; one of GameEvents.DRY_LEFT). No effect here: the map table puts TO
	# FARM over TO DESK and the farm TV splits its back key into TO DESK / TO MAP
	# (MapTable.SHORTCUT_CARD). Dealt with NEGOTIATION, when farms are bought with cabbages and the
	# player shuttles between the map and the farm. Last in the queue, after the chain's end, so left
	# in the tray with the other two optional cards it never holds back a chain card. 1,000 cabbages
	# from stock: a comfort, under a minute of the farms' harvest then (tools/pace.py `ch3`).
	{id = "farm_shortcut", price = 1000, currency = "stock", title = "FASTER TO OUR FARMS", needs = ["negotiation"],
		body = "Time spent in corridors is not billable. The corridors have been shortened.
A TO FARM button stands above TO DESK at the map table, and the TV's back key gets a TO MAP half: map to farm and back without passing the desk."},
	# Merging (optional, GameEvents.DRY_LEFT; chapter 3, where the coins pile up): no effect here,
	# entities/coins/ (CoinPile.MERGE_CARD) merges the coins lying on the desk once coin_merge is
	# stamped, entities/qa_bay/ (QaBay.MERGE_CARD) the Findings tokens once token_merge is. How often
	# and how far: save.merge_every / merge_top, the projector's MERGING chains on the wide sheet
	# (merge_speed_*, merge_top_*, behind coin_merge). Dealt with BIG MINDS, last in the queue like the
	# other comforts, so they never hold back a chain card. Paced in tools/pace.py (`ch3`): about half
	# a minute of income or Findings each when they come.
	{id = "coin_merge", price = 25000, title = "CONSOLIDATE LOOSE CHANGE", needs = ["big_ideas"],
		body = "Small coins are an administrative burden.
Every 2 s the coins on the desk merge: 5 × $1 into a $5, 2 × $5 into a $10 and so on, up to $100. Faster and bigger merges on the projector."},
	{id = "token_merge", price = 3000, currency = "findings", title = "CONSOLIDATE THE FINDINGS", needs = ["big_ideas", "token_recovery"],
		body = "Findings are filed by weight.
The Findings tokens in front of the research lab merge like the coins: 5 × ¶1 into a ¶5, 2 × ¶5 into a ¶10 and so on, as fast and as far as the coins."},
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
## once warned or from chapter 3 on.
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
## warning: the tray has run dry; the promotion and chapter 3's opening: a card is stamped; the war
## card: HOME PORTFOLIO REVIEW is stamped; the workforce card: the first law and Events.BIGGER_ARMIES farms). No upgrade card waits on a timer. Chapter 3's other cards follow
## each other by `needs` alone.
const UNTIMED_EVENTS := ["supply_warning", "promotion", "invest_in_growth", "no_more_sellers", "bigger_armies_memo"]
## NO MORE TAXES ON CABBAGES (card no_taxes): what the street's full-sale price is multiplied by.
const TAX_FREE := 1.19
## Cards cash_holding and archive_capacity: what the coin and the Findings limit are multiplied by.
const LIMIT_RAISE := 5
## Card print_numbers: what the coin limit is multiplied by ($16M to $40M).
const NUMBERS_RAISE := 2.5


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
## today's cap, a save past the supply shock from before its warning (warning filed unread),
## GRACE PERIOD bought back when it lengthened the combo timer (now it halves a miss), and a save
## already at the map table from before its tally was a card (map_readout: filed, the tally stays).
## The handling schedule stamped in chapter 3 simply stays stamped (migrate_schedule: its annexes).
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
	Projector.migrate_mat(save)  # The mat allowance, once one repeatable node, now a chain that stops at 10 (it went to 20).
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
	if save.migration < 5 and save.stamped.has("market_intelligence") and not save.stamped.has("map_readout"):
		save.stamped.append("map_readout")  # At the map table while its tally still came with it: the tally stays.
	for nth in mini(save.farms_owned.size(), FarmRegister.GATES.size()):  # Farms bought before their card gated them: the card is filed.
		if FarmRegister.GATES[nth] != "" and not save.stamped.has(FarmRegister.GATES[nth]):
			save.stamped.append(FarmRegister.GATES[nth])
	if save.migration < 6 and (save.stamped.has("world_map") or save.farms_owned.size() > Events.HOME_SELLERS) and not save.stamped.has(FarmRegister.WAR_CARD):
		save.stamped.append(FarmRegister.WAR_CARD)  # Past the war card before it existed (farms seized, countries annexed): filed; the farms stay.
	if save.stamped.has(FarmRegister.BRIBE) and not save.stamped.has(FarmRegister.RECOVER):
		save.stamped.append(FarmRegister.RECOVER)  # BRIBERY stamped before the card it now follows existed: filed.
	var review: String = Events.EVENTS.no_more_sellers.card
	if (save.reports.has("no_more_sellers") or save.stamped.has(FarmRegister.WAR_CARD) or save.offered.has(FarmRegister.WAR_CARD)) \
			and not save.stamped.has(review):
		save.stamped.append(review)  # Past the war's start from when the fifth farm started it: the review is filed.
	WarRules.migrate_research(save)  # Depot research bought before its big steps were split in two.
	if save.farm_bought.has("hand_route_2") and not save.farm_bought.has(FarmScreen.PLANT_PERMIT):
		save.farm_bought.append(FarmScreen.PLANT_PERMIT)  # FARM ROUNDS bought before the permit became its parent: filed, its hands keep planting farms.
	if save.migration < 7:
		drop_retired_units(save)
	if save.migration < 8:
		Projector.migrate_round_two(save)  # ARCHIVE moved to the projector, the consultant's steps, one condensing chain per kind.
	Projector.migrate_condense_cap(save)  # CONDENSE VI bought before the chain stopped at V: its card is filed.
	if save.migration < 9:
		migrate_schedule(save)
		if not save.farms_owned.is_empty() or save.map_sheet != "" or not save.haggles.is_empty():
			save.field_line_answered = true  # Been to the map before the line rang: it stays quiet.
	if save.migration < 10:
		save.consultant_ceiling = 0  # Most likely left by a hand price (old Consultant.adopt): none again.
	save.migration = SaveGame.MIGRATION
	save.sale_price = mini(save.sale_price, PriceSlate.max_price(save.marketing))


## The handling schedule's retired projector annexes and what each cost (migrate_schedule).
const RETIRED_ANNEXES := {schedule_research = 15000, schedule_mini = 25000}
## What the golden annex (HandSchedule.GOLD_NODE) cost before it dropped to its price today.
const GOLD_ANNEX_WAS := 40000


## The handling schedule's blue and mini annexes (projector, $15,000 and $25,000) are gone: refunded
## and dropped. The golden annex, bought at GOLD_ANNEX_WAS, stays bought and the difference to its
## price today comes back (even without GOLD HANDS, its parent now: it shows under that unbought
## node, nothing more). Refunds are paid past the coin limit (as Projector.migrate_mat), never lost
## at the cap. Blue is listed by MEMO: LAB PRIORITY now, whose stamp strikes it for hired hands (once
## here for a save that had it); without the memo blue comes off the paper again.
static func migrate_schedule(save: SaveGame) -> void:
	for id: String in RETIRED_ANNEXES:
		if save.tree_bought.erase(id):
			save.coins += RETIRED_ANNEXES[id]
	if save.tree_bought.has(HandSchedule.GOLD_NODE):
		save.coins += GOLD_ANNEX_WAS - int(Projector.node_data(HandSchedule.GOLD_NODE).price)
	if save.stamped.has(HandSchedule.LAB_CARD):
		HandSchedule.strike_blue(save)
	else:
		save.hands_forbidden.erase("research")
		save.lab_hands_forbidden.erase("research")


## Figures of unit types that no longer exist (the compliance officer) leave the army, the training
## queue and a war under way.
static func drop_retired_units(save: SaveGame) -> void:
	for counts: Dictionary in [save.army, save.war_pending]:
		for unit: String in counts.keys():
			if unit not in WarRules.UNITS:
				counts.erase(unit)
	save.army_training = save.army_training.filter(func(e: Dictionary) -> bool: return e.unit in WarRules.UNITS)


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
		"lab_priority":  # Hired hands leave blue alone; the handling schedule can clear it.
			HandSchedule.strike_blue(save)
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
		"condense":  # A plain cabbage off the chute holds 2 from stock (CabbageFeeder.condensed).
			save.condense = maxi(save.condense, 2)
		Projector.GRID_CARD:  # A plain condensed cabbage holds 12, past the projector's CONDENSE V.
			save.condense = maxi(save.condense, 12)
		"cash_holding":  # The purse holds five times as much (SaveGame.earn).
			save.coin_limit *= LIMIT_RAISE
		"archive_capacity":
			save.findings_limit *= LIMIT_RAISE
		"print_numbers":  # The readouts print short sums, so the purse may hold more.
			save.coin_limit = roundi(save.coin_limit * NUMBERS_RAISE)
		"no_taxes":  # The street pays 19% more for the same cabbage, and the slate's price goes up with it.
			save.marketing *= TAX_FREE
			save.sale_price = mini(roundi(save.sale_price * TAX_FREE), PriceSlate.max_price(save.marketing))


## What card `card` (a CARDS entry) costs, {currency: amount}: its `price` in `currency` and its
## `also`, coins first, then Findings, then units (the order the card prints them). A card's `farms`
## stands before them all: farms the company must own, checked like a price (affords) but never
## taken (pay).
static func costs(card: Dictionary) -> Dictionary:
	var all: Dictionary = card.get("also", {}).duplicate()
	if card.get("price", 0) > 0:  # The reminder slip's NOTICE has none; HOME PORTFOLIO REVIEW only counts farms.
		all[card.get("currency", "coins")] = card.price
	for owned: String in ["farms", "home_farms"]:
		if card.has(owned):
			all[owned] = card[owned]
	var out := {}
	for paid_in: String in ["farms", "home_farms", "coins", "findings", "stock"]:
		if all.has(paid_in):
			out[paid_in] = all[paid_in]
	return out


## Whether the save covers every currency of `bill` (costs), units only from the store (spendable).
static func affords(save: SaveGame, bill: Dictionary, out := Vector2i.ZERO) -> bool:
	return bill.keys().all(func(paid_in: String) -> bool: return spendable(save, paid_in, out) >= bill[paid_in])


## What the save can pay in `currency`. In units only the ones still in the store: `out` of the
## stock are out of the chute (on the mat, in a hand, refused in the street) and can't pay. In
## "farms": the farms owned.
static func spendable(save: SaveGame, currency: String, out := Vector2i.ZERO) -> int:
	if currency == "farms":
		return save.farms_owned.size()
	if currency == "home_farms":
		return Events.home_farms(save)
	return save.get(currency) - (out.x if currency == "stock" else 0)


## Takes `price` in `currency` from the save. Paid in units, they come from the store (not the `out`
## ones, x of them, y golden) and plain ones go first: golden units in the store are kept as long as
## there are plain ones to pay with. "farms" are only needed, never taken.
static func pay(save: SaveGame, currency: String, price: int, out := Vector2i.ZERO) -> void:
	if currency in ["farms", "home_farms"]:
		return
	save.set(currency, save.get(currency) - price)
	if currency == "stock":
		save.golden_stock = out.y + maxi(clamp_stock(save.golden_stock - out.y, save.stock - out.x), 0)


## The stock units out of the chute among `cabbages`: x all of them, y the golden ones (see
## spendable); a condensed cabbage counts as the cabbages it holds (Cabbage.units).
static func units_out(cabbages: Array) -> Vector2i:
	var out := Vector2i.ZERO
	for cabbage: Cabbage in cabbages:
		if cabbage.in_stock():
			out += Vector2i(1, int(cabbage.golden)) * cabbage.units
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
		if paid_in not in ["farms", "home_farms"]:  # A requirement, not a payment.
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


## Esc closes the approved list, in _input so it gets Esc before the in-game menu (as the ledger does).
## Debug builds only: double-clicking a card on offer stamps it for free (the first click drops it, so
## the second lands while it flies back: any double click right after a drop counts).
func _input(event: InputEvent) -> void:
	if $Approved.visible and event.is_action_pressed("ui_cancel"):
		$Approved.visible = false
		get_viewport().set_input_as_handled()
		return
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
