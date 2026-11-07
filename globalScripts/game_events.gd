extends RefCounted
## The "big events" (research/events.md): something happens, the game gets harder, and the player
## has to react. Each one's trigger lives here: a desk card offered in the tray or stamped, or a
## save flag. The systems themselves stay in their entities; they ask `due` when to start. `report`
## is the boss's paper that flies in when it starts (entities/boss_report/).

const EVENTS := {
	## Rotten units come down the chute and are fined at the window (entities/rotten_bin/).
	rotten_units = {card = "rotten_bin", when = "offered", report = {re = "ROTTEN UNITS IN THE SUPPLY CHAIN",
		body = "Some of our suppliers are shipping rotten cabbages. You will know them by the colour. Never sell one. The street confiscates it and fines us 10× your price. A waste bin has been requisitioned; the form is in your tray."}},
	## The street's mood moves the full-sale price every minute (entities/price_slate/).
	mood_drift = {flag = "slate_unlocked", report = {re = "THE STREET HAS MOODS",
		body = "Market research confirms the street's mood changes every minute. A price that sold everything a minute ago may now be refused. Watch your slate and adjust. Feelings are not our policy, but they are our problem."}},
	## Buying many packs pushes next minute's pack price up (entities/supply_console/).
	pack_pressure = {flag = "buy_unlocked", report = {re = "WHOLESALE PRICES REACT TO YOU",
		body = "You may now order packs at the supply console. Every pack you order pushes next minute's pack price up. Panic buying will be invoiced accordingly. Spread your orders and watch the ticker."}},
	## The window only sells through its right two thirds (worlds/components/sale_window.gd split).
	window_split = {card = "quality_assurance", when = "stamped", report = {re = "QUALITY ASSURANCE TAKES THE WINDOW",
		body = "The QA bay now occupies the left third of the window. Units only sell through the right two thirds. Aim accordingly. Units thrown into the bay are studied, not sold."}},
	## The manager's timed quota (entities/manager/).
	manager_quota = {card = "managerial_oversight", when = "stamped", report = {re = "YOU WILL BE MANAGED",
		body = "As requested, a manager will visit your window every few minutes with a quota: so many units in 45 s. Meet it and you are paid for it. Miss it and it goes in your file."}},
	## Stage 2: at SHOCK_SOLD units sold, once the tray has a free slot, wholesale prices explode
	## (SupplyConsole.crate_share) and the family farm card is dealt into that slot.
	supply_shock = {flag = "supply_shock", report = {re = "WHOLESALE PRICES EXPLODE",
		body = "Demand is up and supply is down. The wholesalers have noticed. A crate unit now costs 60% of what the street pays for one. Margins are thin. My uncle is selling his farm at family rates. The offer is in your tray. We grow our own."}},
	## Buying the farm: crates cost more than they sell for for a while (SupplyConsole.SQUEEZE_TIME).
	supply_squeeze = {card = "family_farm", when = "stamped", report = {re = "THE WHOLESALERS RETALIATE",
		body = "Word of the farm got out. For 5 minutes crates cost more than a unit sells for, and the standing order will not buy them. Live off the farm: the remote on your desk switches to it. Prices ease back over the 5 minutes after that."}},
}
## Units sold before stage 2 can start (tools/pace.py: about 31 min).
const SHOCK_SOLD := 900


## Whether event `id` has started for `save`.
static func due(id: String, save: SaveGame) -> bool:
	var event: Dictionary = EVENTS[id]
	if event.has("flag"):
		return save.get(event.flag)
	if save.stamped.has(event.card):
		return true
	return event.when == "offered" and save.tray_unlocked \
			and UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save).has(event.card)


## Whether stage 2 starts now: enough units sold and a free slot in the tray for the farm card.
static func shock_due(save: SaveGame) -> bool:
	return not save.supply_shock and save.tray_unlocked and save.sold >= SHOCK_SOLD \
			and UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save).size() < UpgradeDesk.OFFERED
