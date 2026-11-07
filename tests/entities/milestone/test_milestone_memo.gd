extends Node
## Run: Godot --headless --path . res://tests/entities/milestone/test_milestone_memo.tscn

const Memo := preload("res://entities/milestone/milestone_memo.gd")


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	if not Memo.due(save).is_empty():
		failed = true
		push_error("a fresh save should have nothing due, got %s" % Memo.due(save).get("id"))
	save.sold = 9
	if not Memo.due(save).is_empty():
		failed = true
		push_error("nothing before 10 units")
	# Thresholds passed at once come one after the other, each applied once.
	save.sold = 120
	var order := PackedStringArray()
	while not Memo.due(save).is_empty():
		var m := Memo.due(save)
		order.append(m.id)
		Memo.apply(save, m)
	if order != PackedStringArray(["units_10", "units_25", "units_100"]):
		failed = true
		push_error("filed in order: %s" % order)
	if not is_equal_approx(save.marketing, 1.25) or save.findings_per_cabbage != 2:
		failed = true
		push_error("bonuses: marketing %s, findings %s" % [save.marketing, save.findings_per_cabbage])
	# FILES: newest filed first, then the rest in list order.
	var files := Memo.files_order(save)
	if files.size() != Memo.MEMOS.size() or files[0].id != "units_100" or files[2].id != "units_10" \
			or files[3].id != "units_250":
		failed = true
		push_error("files order: %s" % files.map(func(m: Dictionary) -> String: return m.id).slice(0, 4))
	# Conditions: a stat, a card stamped, a projector node bought, every card stamped.
	save.tube_split = 0.5
	save.stamped.append("research_inspection")
	save.tree_bought.append("double_findings")
	for id in ["lever_split", "research_directive", "double_findings"]:
		if not Memo.met(save, Memo.memo(id)):
			failed = true
			push_error("%s should be met" % id)
	if Memo.met(save, Memo.memo("every_card")):
		failed = true
		push_error("every_card needs every card")
	for card: Dictionary in UpgradeDesk.CARDS:
		save.stamped.append(card.id)
	if not Memo.met(save, Memo.memo("every_card")):
		failed = true
		push_error("every_card should be met with every card stamped")
	var ids := {}
	for m: Dictionary in Memo.MEMOS:
		var condition := int(m.has("stat")) + int(m.has("card")) + int(m.has("node"))
		if ids.has(m.id) or condition != 1 or (m.has("stat") and not m.stat in save) \
				or (m.has("key") and not (m.key in save and m.mul >= 1.25 and m.has("bonus"))) \
				or not (m.has("re") and m.has("how") and m.has("note") and m.has("icon")):
			failed = true
			push_error("memo %s: unique id, one condition on a save field, a felt bonus, all texts" % m.id)
		ids[m.id] = true
	# The six original ids stay, so old saves never get their bonus twice.
	for id in ["units_25", "units_100", "units_250", "units_1000", "units_2500", "units_10000"]:
		if not Memo.memo(id).has("key"):
			failed = true
			push_error("%s should keep its bonus" % id)
	if SteamAchievements.api_name("units_25") != "UNITS_25":
		failed = true
		push_error("Steam API name is the id upper-cased")
	SteamAchievements.unlock("units_25")  # no Steam here: must be a no-op
	if not is_zero_approx(Memo.slide_at(0.0)) or not is_equal_approx(Memo.slide_at(Memo.IN_TIME), 1.0):
		failed = true
		push_error("memo should slide up over IN_TIME")
	var from := Vector2(960, 900)
	var to := Vector2(1850, 1030)
	var mid := Memo.fly_at(0.5, from, to)
	if not Memo.fly_at(0.0, from, to).is_equal_approx(from) or not Memo.fly_at(1.0, from, to).is_equal_approx(to) 			or mid.y >= from.y or mid.x <= from.x or mid.x >= to.x:
		failed = true
		push_error("the fly should start at rest, bow upward, and end in the folder: %s" % mid)
	if Memo.glow_at(0.0, 3.0) != 0.0 or Memo.glow_at(-1.0, 3.0) != 0.0 or Memo.glow_at(Memo.GLOW_TIME, 3.0) < 0.2 			or Memo.glow_at(Memo.GLOW_TIME, 3.0) > 1.0 or not Memo.glow_at(0.5, 0.0) < Memo.glow_at(5.0, 0.0):
		failed = true
		push_error("the glow should pulse while it lasts, fade in its last second, and be off after")
	print("milestone memo tests failed" if failed else "milestone memo tests passed")
	get_tree().quit(1 if failed else 0)
