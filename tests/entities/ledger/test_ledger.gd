extends Node
## Run: Godot --headless --path . res://tests/entities/ledger/test_ledger.tscn


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	if Ledger.unlocked(save):
		failed = true
		push_error("the ledger should wait for its desk card")
	save.stamped = PackedStringArray(["stats_ledger"])
	if not Ledger.unlocked(save):
		failed = true
		push_error("the stats_ledger card should unlock it")
	if Ledger.clock(3723) != "1:02:03" or Ledger.clock(59) != "0:00:59":
		failed = true
		push_error("clock: %s, %s" % [Ledger.clock(3723), Ledger.clock(59)])
	save.sold = 40
	save.catches = 10
	save.coins = 120
	save.marketing = 1.5
	var summary := {}
	for row: Array in Ledger.summary_rows(save, 3723):
		summary[row[0]] = row[1]
	if summary.get("UNITS MOVED") != "40" or summary.get("INTERCEPTION RATE") != "25%" \
			or summary.get("COINS ON HAND") != "$120" or summary.get("MARKETING MULTIPLIER") != "x1.50" \
			or summary.get("TIME ON SHIFT") != "1:02:03":
		failed = true
		push_error("summary: %s" % summary)
	# A fresh save: summary, chart, personnel, one empty requisitions page, no blank.
	var pages := Ledger.pages(SaveGame.new(), 0)
	if pages.size() != 4 or pages[3].kind != "list" or not pages[3].rows.is_empty():
		failed = true
		push_error("fresh pages: %s" % [pages.map(func(p: Dictionary) -> String: return p.kind)])
	# Purchases from the log, by play time; sessions and snapshots are left out.
	save.playtest_log.append(save.log_entry(5, "session", "0"))
	save.playtest_log.append(save.log_entry(30, "snapshot"))
	save.playtest_log.append(save.log_entry(65, "card", "price_slate", 12, "coins"))
	save.playtest_log.append(save.log_entry(700, "node", "slogan_1", 70, "coins"))
	save.playtest_log.append(save.log_entry(900, "card", "street_posters", 10, "findings"))
	var reqs := Ledger.requisitions(save)
	if reqs.size() != 3 or reqs[0] != ["T+0:01:05", "PRICE SLATE", "$12"] or reqs[1][1] != "SLOGAN I" \
			or reqs[2][2] != "¶10":
		failed = true
		push_error("requisitions: %s" % [reqs])
	if Ledger.coin_points(save, 1000).size() != 6 or Ledger.coin_points(save, 1000)[5] != Vector2(1000, 120):
		failed = true
		push_error("coin points: %s" % Ledger.coin_points(save, 1000))
	# 13 purchases spill onto a second requisitions page; the count is padded even with a blank page.
	for i in 10:
		save.playtest_log.append(save.log_entry(1000 + i, "node", "pack_1", 50, "coins"))
	pages = Ledger.pages(save, 2000)
	if pages.size() != 6 or pages[3].rows.size() != Ledger.REQ_PER_PAGE or pages[4].rows.size() != 1 \
			or pages[5].kind != "blank":
		failed = true
		push_error("paged requisitions: %d pages" % pages.size())
	save.hands = 9
	var personnel := Ledger.personnel_rows(save)
	if personnel[0] != ["HEADCOUNT", "10"] or not personnel.has(["FURTHER ASSOCIATES", "2"]):
		failed = true
		push_error("personnel: %s" % [personnel])
	print("ledger tests failed" if failed else "ledger tests passed")
	get_tree().quit(1 if failed else 0)
