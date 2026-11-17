extends RefCounted
## The "big events" (research/events.md): something happens, the game gets harder, and the player
## has to react. Each one's trigger lives here: a desk card stamped, or a
## save flag. The systems themselves stay in their entities; they ask `due` when to start. `report`
## is the boss's paper that flies in when it starts (entities/boss_report/).

const EVENTS := {
	## Rotten units come down the chute and are fined at the window; the bin arrives with them, free
	## (entities/rotten_bin/). Old saves may still have the retired "rotten_bin" card stamped.
	rotten_units = {card = "catch_combo", report = {re = "ROTTEN CABBAGES IN THE SUPPLY CHAIN",
		body = "Some suppliers ship rotten cabbages. You can tell them by their colour. Never sell one: the street takes it and fines us 10× your price. Throw them into the waste bin at the bottom of your mat."}},
	## The street's mood moves the full-sale price every minute (entities/price_slate/).
	mood_drift = {flag = "slate_unlocked", report = {re = "THE STREET HAS MOODS",
		body = "Market research confirms the street's mood changes every minute. A price that sold everything a minute ago may now be refused. Watch your slate and adjust. Feelings are not our policy, but they are our problem."}},
	## Buying many packs pushes next minute's pack price up (entities/supply_console/).
	pack_pressure = {flag = "buy_unlocked", report = {re = "WHOLESALE PRICES REACT TO YOU",
		body = "You may now order packs at the supply console. Every pack you order pushes next minute's pack price up. Panic buying will be invoiced accordingly. Spread your orders and watch the ticker."}},
	## The window only sells through its right two thirds (worlds/components/sale_window.gd split).
	window_split = {card = "quality_assurance", report = {re = "THE RESEARCH LAB TAKES THE WINDOW",
		body = "The research lab now takes up the left third of the window. Cabbages only sell through the right two thirds. Aim accordingly. Cabbages thrown into the lab are studied, not sold. A projector requisition will reach your tray. What it shows is discretionary spending. The forms on your desk come first."}},
	## The manager's timed quota (entities/manager/).
	manager_quota = {card = "managerial_oversight", report = {re = "YOU WILL BE MANAGED",
		body = "As requested, a manager will come to your window every few minutes with a quota: sell that many cabbages in 45 s. Meet it and you get paid. Miss it and it goes in your file."}},
	## Stage 2, step 1: the tray has run dry (tray_dry; the demo: Demo.WARNING_SOLD units sold) and
	## has a slot: the family farm card is dealt into it at its price. Crate prices stay as they are.
	supply_warning = {flag = "supply_warning", report = {re = "WHOLESALE PRICES WILL SPIKE",
		body = "I have it from a reliable source that wholesale prices will spike soon. Crates still cost what they cost today. For now. My uncle is selling his farm at family rates. The offer is in your tray. A desk that grows its own does not care what the wholesalers think."}},
	## Stage 2, step 2: shock_after() units sold since the warning (or SHOCK_AFTER_FARM since the
	## farm card, shock_due), wholesale prices explode
	## (SupplyConsole.crate_share).
	supply_shock = {flag = "supply_shock", report = {re = "WHOLESALE PRICES EXPLODE",
		body = "As foreseen, the wholesalers have raised their prices. A cabbage from a crate now costs 60% of what the street pays for it. Margins are thin. Your standing order is paused; switch it back on at the supply console if you must. If you have not bought my uncle's farm yet, the offer is still in your tray. We grow our own."}},
	## The farm and the shock both in: crates cost more than they sell for, for good
	## (SupplyConsole.squeezing), from whichever came second.
	supply_squeeze = {card = "family_farm", flag = "supply_shock", report = {re = "THE WHOLESALERS RETALIATE",
		body = "Word of the farm got out. Crates now cost more than a cabbage sells for. This is not a phase. The standing order will not buy at a loss, and neither should you. Live off the farm: the remote on your desk switches to it."}},
	## Stage 2, after the golden units: OVERRIPE_AFTER farm seconds after the golden_cabbage card,
	## ripe squares left save.rot_after s rot. The mechanisation card, the cure, is dealt
	## right after the golden card, not by this event (no card waits on a timer).
	overripe = {flag = "overripe", report = {re = "SPOILAGE ON THE FARM",
		body = "Premium cabbages have raised expectations. The farm no longer meets them. From today a ripe square left unharvested for 3 minutes rots: it yields nothing and blocks the square until you clear it. Farm hands will not touch it. The mechanisation programme is the remedy; cold storage may be requisitioned on channel 2. Compost is not a product category."}},
	## Stage 2, the first tractor (mechanisation card stamped): the player is a manager now. Deals the
	## two managerial-work cards (UpgradeDesk own_sales, own_research: `event = "promotion"`), which
	## reward selling and researching yourself over leaving it all to the helpers.
	promotion = {card = "mechanisation", report = {re = "YOU ARE NOW A MANAGER",
		body = "With a tractor on the farm, you now supervise machinery. Your title is changed to Manager, Desk 4. Your salary is not. From today every cabbage you sell or research with your own hands counts as managerial work and will be accounted for as such. The forms are in your tray."}},
	## Stage 2, VOLATILE_AFTER play seconds after the promotion report is signed (volatile_due): the
	## street's mood jumps PriceSlate.WILD_STEP a minute within WILD_RANGE (entities/price_slate/).
	street_volatility = {flag = "street_volatile", report = {re = "THE STREET HAS BECOME VOLATILE",
		body = "Analysts report that the street now overreacts. From today its prices jump hard every minute, and the jumps may get wild. A price left alone will soon be refused. A pricing consultant is very useful here: click the switch beside the slate to set its mandate. If none is retained yet, one can still be requisitioned. Panic is not a pricing strategy."}},
	## The end of stage 2 (chapter 2): the CONSOLIDATED GROWTH REQUISITION card is stamped. Chapter 3
	## (buying out other farms on the map table) starts from here: chapter_3(save). The player is
	## promoted again, and the PROCURE MARKET INTELLIGENCE card is dealt (UpgradeDesk, `event`).
	invest_in_growth = {card = "consolidation", report = {re = "YOU ARE PROMOTED AGAIN",
		body = "The board has reviewed your figures. You are now Head of Acquisitions, Desk 4. Your salary has been reviewed and found adequate. We are not expanding fast enough: cabbage grows at the speed of cabbage, and the board will not wait for it. From today we grow by buying out other farms. A form is in your tray. A map table has been set up to your right."}},
	## Chapter 3: the company owns its first farm (`farms`: at least that many in save.farms_owned).
	## The TV's channel 1 lets the player make one of their fields a farm square (entities/farm_screen/).
	first_farm = {farms = 1, report = {re = "A FARM HAS BEEN ACQUIRED",
		body = "The company now owns a farm it has never seen. To keep a clean overview, check the TV, channel 1: green arrows mark your fields. Click one to upgrade it to a farm. It will produce accordingly. One field for every farm we own. Head office likes to see on a screen what is ours."}},
	## Chapter 3: the HOME PORTFOLIO REVIEW card is stamped (UpgradeDesk "home_review": HOME_SELLERS farms
	## owned, nothing spent), and nobody at home sells any more. War starts from here: the paper deals the
	## war card (UpgradeDesk "war_mode", `event`), which sets up the personnel depot; with it the other
	## home farms, and later every farm abroad, are taken by war, one at a time (FarmRegister.war_ready).
	no_more_sellers = {card = "home_review", report = {re = "THIS MEANS WAR",
		body = "The remaining owners have stopped answering our offers. The board has reviewed the matter. This means war. The authorisation is in your tray. Once it is stamped, a personnel depot is set up at your map table. Build an army there and take what is ours. Your maps will be extended beyond the border in due course."}},
	## Chapter 3: every farm site of the home country is owned (`home_farms`: home_farms(save), the
	## country sheet's HOME_SITES sites, not just any 8 farms). The country is ours: we make the laws
	## (UpgradeDesk "no_taxes" needs the same farms).
	home_country = {home_farms = HOME_SITES, report = {re = "THE COUNTRY IS OURS",
		body = "Every farm in Kohlmark now belongs to the company. A country that grows nothing but our cabbages is, for practical purposes, ours. The board has reviewed the constitution and found it amendable. From today we write the laws. The first one is on your desk."}},
	## Chapter 3's war line: the first law is stamped (the home farms were the field associates' tutorials)
	## and BIGGER_ARMIES farms are owned. Deals EXPAND THE FIELD WORKFORCE (UpgradeDesk "bigger_armies",
	## `event`: army cap +2, read by WarRules).
	bigger_armies_memo = {card = "no_taxes", farms = BIGGER_ARMIES, report = {re = "WE NEED BIGGER ARMIES",
		body = "The board has reviewed the war reports. The victories are adequate. The armies are not: a war fought by a handful of staff is a meeting. The field workforce is to be expanded. The requisition is in your tray. Keep the paperwork for the fallen in order."}},
	## Once per save: a form in the tray has been affordable for PROGRESS_AFTER play seconds with none
	## approved (progress_due; UpgradeDesk ticks save.progress_wait). Changes nothing but the paperwork.
	## Last, so it never jumps ahead of a story note due at the same moment.
	progress_required = {flag = "progress_warned", report = {re = "PROGRESS IS REQUIRED",
		body = "Head office notes that a form on your desk could have been approved five minutes ago and was not. Forms are orders. Approving them is how the company advances, and with it your position. The projector is discretionary. Progress is not."}},
}
## Chapter 3: every farm in the game (8 sites at home, 16 abroad: one per field square on the TV's
## channel 1, one lamp each on the FieldLine), and how many of the home ones their owners sell.
const FARMS := 24
const HOME_SELLERS := 5
## Farms owned (the first law stamped) when the board asks for bigger armies (bigger_armies_memo).
const BIGGER_ARMIES := 10
## The home country's farm sites (the country sheet, FarmRegister): how many there are, and what
## their ids start with ("K-1".."K-8"; a farm abroad has another prefix).
const HOME_SITES := 8
const HOME_PREFIX := "K-"
## Farm seconds after the golden_cabbage card until the overripe event starts.
const OVERRIPE_AFTER := 60.0
## Play seconds after the promotion report is signed until the street turns volatile.
const VOLATILE_AFTER := 120.0
## Play seconds a tray form may lie affordable, none approved, before head office writes.
const PROGRESS_AFTER := 300.0
## Units sold after the warning until wholesale prices explode (tools/pace.py: about 4 min; the
## demo: Demo.SHOCK_AFTER), or SHOCK_AFTER_FARM after the family farm card is stamped, whichever
## comes first: the farm pays off soon after it is bought (shock_due).
const SHOCK_AFTER := 150
const SHOCK_AFTER_FARM := 40
## The desk cards that may still be left when the tray counts as run dry (tray_dry): dear ones the
## player saves up for anyway (the desk lamp, the mat allowance), and optional ones a player may
## never want (the behaviour memos, the no-effect ledger; in chapter 3, long after the tray ran dry,
## the handling schedule, the map table's holdings indicator and the farm shortcut; the comforts: the
## rotten shield and the two merging cards). Nothing else needs any of them.
const DRY_LEFT := ["golden_lamp", "mat_allowance", "spoilage_memo", "lab_priority", "stats_ledger", "hand_schedule", "map_readout", "farm_shortcut", "rotten_shield", "coin_merge", "token_merge", "research_light", "annexed_grid"]
const Demo := preload("res://globalScripts/demo.gd")


static func shock_after() -> int:
	return Demo.SHOCK_AFTER if Demo.active() else SHOCK_AFTER


## How many of the home country's farm sites `save` owns.
static func home_farms(save: SaveGame) -> int:
	var count := 0
	for site in save.farms_owned:
		if site.begins_with(HOME_PREFIX):
			count += 1
	return count


## Whether event `id` has started for `save`: its flag set, its card stamped, its `farms` owned and
## its `home_farms` of them at home, whichever it has.
static func due(id: String, save: SaveGame) -> bool:
	var event: Dictionary = EVENTS[id]
	return (not event.has("flag") or save.get(event.flag)) and (not event.has("card") or save.stamped.has(event.card)) 			and save.farms_owned.size() >= event.get("farms", 0) and home_farms(save) >= event.get("home_farms", 0)


## Whether chapter 3 has begun: chapter 2's last card is stamped (the "invest_in_growth" event).
static func chapter_3(save: SaveGame) -> bool:
	return due("invest_in_growth", save)


## Whether chapter 3 is over: its last card (UpgradeDesk "stars", needs every farm) is stamped.
static func chapter_3_done(save: SaveGame) -> bool:
	return save.stamped.has("stars")


## Whether the tray has nothing left to deal but DRY_LEFT cards (event cards aside).
static func tray_dry(save: SaveGame) -> bool:
	return UpgradeDesk.next_cards(save.stamped, UpgradeDesk.CARDS.size()).all(func(id: String) -> bool: return id in DRY_LEFT)


## Whether stage 2's warning may start: the tray has run dry (in the demo, or Demo.WARNING_SOLD
## units are sold). It starts when the tray has a slot for the farm card: a free one
## (warning_due), or the one a card leaves when it is stamped (the farm card is dealt before the
## rest, UpgradeDesk.next_cards).
static func warning_ready(save: SaveGame) -> bool:
	return not save.supply_warning and save.tray_unlocked \
			and (tray_dry(save) or (Demo.active() and save.sold >= Demo.WARNING_SOLD))


## Whether the warning starts now: ready, and a free slot in the tray for the farm card. The demo
## never waits on a full tray (its end needs the farm): the farm card takes the last slot's place
## (UpgradeDesk._make_room).
static func warning_due(save: SaveGame) -> bool:
	return warning_ready(save) and (Demo.active() \
			or UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save).size() < UpgradeDesk.OFFERED)


## Whether the overripe event starts now: OVERRIPE_AFTER farm seconds after the golden card.
static func overripe_due(save: SaveGame) -> bool:
	return not save.overripe and save.golden_at >= 0.0 and save.farm_seconds >= save.golden_at + OVERRIPE_AFTER


## Whether the street turns volatile now: VOLATILE_AFTER play seconds counted since the promotion
## report was signed (save.volatile_wait, PriceSlate counts it).
static func volatile_due(save: SaveGame) -> bool:
	return not save.street_volatile and save.reports.has("promotion") and save.volatile_wait >= VOLATILE_AFTER


## The progress clock after `delta` play seconds: it runs while a tray form is `affordable`, and
## starts again from 0 when a form was `approved` or none is affordable.
static func progress_clock(seconds: float, delta: float, affordable: bool, approved: bool) -> float:
	return seconds + delta if affordable and not approved else 0.0


## Whether head office's progress warning starts now: not `warned` yet, a form still `affordable`,
## and the clock at PROGRESS_AFTER.
static func progress_due(seconds: float, warned: bool, affordable: bool) -> bool:
	return not warned and affordable and seconds >= PROGRESS_AFTER


## Whether wholesale prices explode now: shock_after() units sold since the warning, or
## SHOCK_AFTER_FARM since the family farm was stamped (save.farm_sold), whichever first. Never once
## the supply console is gone (SupplyConsole.retired): there are no crates left to price.
static func shock_due(save: SaveGame) -> bool:
	return save.supply_warning and not save.supply_shock and not SupplyConsole.retired(save) and (save.sold >= save.warning_sold + shock_after() \
			or (save.farm_sold >= 0 and save.sold >= save.farm_sold + SHOCK_AFTER_FARM))
