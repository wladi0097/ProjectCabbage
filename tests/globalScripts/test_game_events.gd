extends Node
## Run: Godot --headless --path . res://tests/globalScripts/test_game_events.tscn
## Stage 2: when the supply shock starts, the farm card waiting for it, crate prices, and the boss
## reports due.

const Events := preload("res://globalScripts/game_events.gd")
const Report := preload("res://entities/boss_report/boss_report.gd")

var failed := false


func _ready() -> void:
	# Every card but the farm and the golden lamp stamped: the tray holds one card, so a slot is free.
	var save := SaveGame.new()
	save.tray_unlocked = true
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in ["family_farm", "golden_lamp"]:
			save.stamped.append(card.id)
	save.sold = Events.SHOCK_SOLD - 1
	_check(not Events.shock_due(save), "no shock before enough units are sold")
	save.sold = Events.SHOCK_SOLD
	_check(Events.shock_due(save), "shock with enough units sold and a free slot")
	_check(not UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save).has("family_farm"), "no farm card before the shock")
	save.supply_shock = true
	_check(not Events.shock_due(save), "the shock starts once")
	_check(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save) == ["golden_lamp", "family_farm"], "the farm card takes the free slot")
	_check(not UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED).has("family_farm"), "no farm card without a save")
	# A full tray: the shock waits for a slot.
	var full := SaveGame.new()
	full.tray_unlocked = true
	full.sold = Events.SHOCK_SOLD
	full.stamped = PackedStringArray(["price_slate", "radio"])
	_check(not Events.shock_due(full), "no shock while the tray is full")
	# Crate prices: normal before the shock; the squeeze holds, then eases back to the shock's share.
	var Console := SupplyConsole
	_check(Console.crate_share(false, 0.0) == 0.0 and Console.crate_share(true, 0.0) == Console.SHOCK_SHARE, "shock share")
	_check(Console.crate_share(true, Console.SQUEEZE_TIME + Console.EASE_TIME) == Console.SQUEEZE_SHARE
			and Console.crate_share(true, Console.EASE_TIME) == Console.SQUEEZE_SHARE, "squeeze holds")
	_check(is_equal_approx(Console.crate_share(true, Console.EASE_TIME * 0.5), (Console.SHOCK_SHARE + Console.SQUEEZE_SHARE) * 0.5), "squeeze eases")
	var unit := SaveGame.new()
	_check(Console.unit_cost(unit) == Console.UNIT_COST, "normal unit cost")
	unit.supply_shock = true
	unit.marketing = 5.0
	_check(is_equal_approx(Console.unit_cost(unit), Console.SHOCK_SHARE * 15.0) and Console.unit_cost(unit) < 15.0, "shocked unit still sells at a profit")
	UpgradeDesk.apply("family_farm", unit)
	_check(Console.unit_cost(unit) > 15.0, "squeezed unit sells at a loss")
	_check(Console.pack_price(1.0, 10, 1.0, 9.0) == 90 and Console.pack_price(1.0, 10) == 11, "pack price per unit")
	# Reports: one per started event, each only once; every event has one.
	var fresh := SaveGame.new()
	_check(Report.due(fresh) == ["welcome"], "a new game starts with the welcome")
	fresh.reports.append("welcome")
	fresh.slate_unlocked = true
	fresh.buy_unlocked = true
	_check(Report.due(fresh) == ["mood_drift", "pack_pressure"], "reports for started events, in order")
	fresh.reports.append("mood_drift")
	_check(Report.due(fresh) == ["pack_pressure"], "a report is shown once")
	_check(Report.report("welcome").re == Report.WELCOME.re and Report.report("supply_shock") == Events.EVENTS.supply_shock.report, "report texts")
	# Signing: ink is the stroke's length; the pen cursor is drawn.
	_check(is_equal_approx(Report.ink_of(PackedVector2Array([Vector2.ZERO, Vector2(30, 40), Vector2(30, 0)])), 90.0), "ink length")
	var pen := Report.pen_image()
	_check(pen.get_size() == Vector2i(32, 32) and pen.get_pixel(1, 30).a > 0.0 and pen.get_pixel(30, 1).a == 0.0, "pen cursor")
	for id: String in Events.EVENTS:
		var report: Dictionary = Events.EVENTS[id].get("report", {})
		_check(not report.get("re", "").is_empty() and not report.get("body", "").is_empty(), "report for " + id)
	print("game events tests failed" if failed else "game events tests passed")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		push_error(what)
