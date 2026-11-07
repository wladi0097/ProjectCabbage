extends RefCounted
## The "big events" (research/events.md): something happens, the game gets harder, and the player
## has to react. Each one's trigger lives here: a desk card offered in the tray or stamped, or a
## save flag. The systems themselves stay in their entities; they ask `due` when to start.

const EVENTS := {
	## Rotten units come down the chute and are fined at the window (entities/rotten_bin/).
	rotten_units = {card = "rotten_bin", when = "offered"},
	## The street's mood moves the full-sale price every minute (entities/price_slate/).
	mood_drift = {flag = "slate_unlocked"},
	## Buying many packs pushes next minute's pack price up (entities/supply_console/).
	pack_pressure = {flag = "buy_unlocked"},
	## The window only sells through its right two thirds (worlds/components/sale_window.gd split).
	window_split = {card = "quality_assurance", when = "stamped"},
	## The manager's timed quota (entities/manager/).
	manager_quota = {card = "managerial_oversight", when = "stamped"},
}


## Whether event `id` has started for `save`.
static func due(id: String, save: SaveGame) -> bool:
	var event: Dictionary = EVENTS[id]
	if event.has("flag"):
		return save.get(event.flag)
	if save.stamped.has(event.card):
		return true
	return event.when == "offered" and save.tray_unlocked \
			and UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED).has(event.card)
