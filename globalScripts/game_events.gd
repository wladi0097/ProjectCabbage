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
		body = "The research lab now takes up the left third of the window. Cabbages only sell through the right two thirds. Aim accordingly. Cabbages thrown into the lab are studied, not sold."}},
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
	## The farm and the shock both in: crates cost more than they sell for for a while
	## (SupplyConsole.SQUEEZE_TIME), from whichever came second.
	supply_squeeze = {card = "family_farm", flag = "supply_shock", report = {re = "THE WHOLESALERS RETALIATE",
		body = "Word of the farm got out. Crates now cost more than a cabbage sells for: 10 minutes at a time, with a 1 minute break in between. The standing order will not buy them meanwhile. Live off the farm: the remote on your desk switches to it."}},
	## Stage 2, after the golden units: OVERRIPE_AFTER farm seconds after the golden_cabbage card,
	## ripe squares left FarmScreen.ROT_AFTER s rot. The mechanisation card, the cure, is dealt
	## right after the golden card, not by this event (no card waits on a timer).
	overripe = {flag = "overripe", report = {re = "SPOILAGE ON THE FARM",
		body = "Premium cabbages have raised expectations. The farm no longer meets them. From today a ripe square left unharvested for 10 minutes rots: it yields nothing and blocks the square until you clear it. Farm hands will not touch it. The mechanisation programme is the remedy. Compost is not a product category."}},
	## The end of stage 2 (chapter 2): the CONSOLIDATED GROWTH REQUISITION card is stamped. Chapter 3
	## (buying other companies, the stock market) starts from here: chapter_3(save).
	invest_in_growth = {card = "consolidation", report = {re = "WE SHOULD INVEST IN GROWTH",
		body = "The board has reviewed your figures. Cabbage grows at the speed of cabbage, and the board cannot wait that long. From today the desk grows by acquisition: we will buy other companies, and we will invest in the stock market. You will be given a ticker. Cabbages remain cabbages. Some of them will now be shares."}},
}
## Farm seconds after the golden_cabbage card until the overripe event starts.
const OVERRIPE_AFTER := 60.0
## Units sold after the warning until wholesale prices explode (tools/pace.py: about 4 min; the
## demo: Demo.SHOCK_AFTER), or SHOCK_AFTER_FARM after the family farm card is stamped, whichever
## comes first: the farm pays off soon after it is bought (shock_due).
const SHOCK_AFTER := 150
const SHOCK_AFTER_FARM := 40
## The desk cards that may still be left when the tray counts as run dry (tray_dry): dear ones the
## player saves up for anyway (the desk lamp, the mat allowance), and optional ones a player may
## never want (the behaviour memos, the no-effect ledger). Nothing else needs any of them.
const DRY_LEFT := ["golden_lamp", "mat_allowance", "spoilage_memo", "lab_priority", "stats_ledger"]
const Demo := preload("res://globalScripts/demo.gd")


static func shock_after() -> int:
	return Demo.SHOCK_AFTER if Demo.active() else SHOCK_AFTER


## Whether event `id` has started for `save`: its flag set and its card stamped, whichever it has.
static func due(id: String, save: SaveGame) -> bool:
	var event: Dictionary = EVENTS[id]
	return (not event.has("flag") or save.get(event.flag)) and (not event.has("card") or save.stamped.has(event.card))


## Whether chapter 3 has begun: chapter 2's last card is stamped (the "invest_in_growth" event).
static func chapter_3(save: SaveGame) -> bool:
	return due("invest_in_growth", save)


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


## Whether wholesale prices explode now: shock_after() units sold since the warning, or
## SHOCK_AFTER_FARM since the family farm was stamped (save.farm_sold), whichever first.
static func shock_due(save: SaveGame) -> bool:
	return save.supply_warning and not save.supply_shock and (save.sold >= save.warning_sold + shock_after() \
			or (save.farm_sold >= 0 and save.sold >= save.farm_sold + SHOCK_AFTER_FARM))
