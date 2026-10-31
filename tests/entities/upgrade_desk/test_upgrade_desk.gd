extends Node
## Run: Godot --headless --path . res://tests/entities/upgrade_desk/test_upgrade_desk.tscn


func _ready() -> void:
	var failed := false
	if UpgradeDesk.next_cards(PackedStringArray(), 3) != ["price_slate"]:
		failed = true
		push_error("only the price slate should be offered before it is stamped")
	if UpgradeDesk.next_cards(PackedStringArray(["price_slate"]), 3) != ["desk_space", "junior_associate", "acceptance_meter"]:
		failed = true
		push_error("the slate should open desk space, the junior associate and the meter")
	if UpgradeDesk.next_cards(PackedStringArray(["price_slate", "desk_space"]), 3) != ["junior_associate", "acceptance_meter"]:
		failed = true
		push_error("a stamped card should leave the offer, quality assurance waits for the junior too")
	if UpgradeDesk.next_cards(PackedStringArray(["price_slate", "desk_space", "acceptance_meter", "junior_associate"]), 3) \
			!= ["quality_assurance"]:
		failed = true
		push_error("no hire card: further hands are hired in the projector tree")
	if UpgradeDesk.next_cards(PackedStringArray(["price_slate", "desk_space", "acceptance_meter", "junior_associate", "quality_assurance"]), 3) \
			!= ["street_posters", "projector"]:
		failed = true
		push_error("quality assurance should open the posters and the projector")
	# The chains narrow the tray and widen it again: the time-and-motion study opens three at once.
	var early := PackedStringArray(["price_slate", "desk_space", "acceptance_meter", "junior_associate", "quality_assurance",
			"street_posters", "projector", "research_inspection", "pricing_consultant", "catch_combo"])
	if UpgradeDesk.next_cards(early, 3) != ["performance_review", "rotten_bin"]:
		failed = true
		push_error("inspection, consultant and combo should leave the review and the bin: %s" % [UpgradeDesk.next_cards(early, 3)])
	early.append_array(["performance_review", "rotten_bin"])
	if UpgradeDesk.next_cards(early, 3) != ["managerial_oversight", "regional_billboard", "window_targets"]:
		failed = true
		push_error("the review should open the manager, the billboard and the targets: %s" % [UpgradeDesk.next_cards(early, 3)])
	# Every `needs` names a card earlier in the queue, so the queue order is a valid stamping order.
	for i in UpgradeDesk.CARDS.size():
		for need: String in UpgradeDesk.CARDS[i].get("needs", []):
			if not UpgradeDesk.CARDS.slice(0, i).any(func(card: Dictionary) -> bool: return card.id == need):
				failed = true
				push_error("%s needs %s, which is not before it" % [UpgradeDesk.CARDS[i].id, need])
	if UpgradeDesk.card_data("junior_associate").get("currency", "coins") != "coins" or UpgradeDesk.card_data("projector").price != 75 \
			or UpgradeDesk.card_data("regional_billboard").get("currency") != "findings":
		failed = true
		push_error("card currencies or prices wrong")
	if not UpgradeDesk.card_data("bulk_procurement").is_empty() or not UpgradeDesk.card_data("hire_associate").is_empty():
		failed = true
		push_error("bulk procurement and the hire card moved to the projector tree")
	var save := SaveGame.new()
	var interval := save.associate_interval
	for card: Dictionary in UpgradeDesk.CARDS:
		UpgradeDesk.apply(card.id, save)
	if not save.slate_unlocked or save.desk_capacity != 2 or save.pack_size != 10 or save.hands != 1 \
			or not is_equal_approx(save.marketing, 1.2 * 1.5 * 1.5) or not is_equal_approx(save.associate_interval, interval * 0.5):
		failed = true
		push_error("card effects wrong: slate %s, desk %d, pack %d, hands %d, marketing %.2f, interval %.1f" % [save.slate_unlocked, save.desk_capacity, save.pack_size, save.hands, save.marketing, save.associate_interval])
	Associate.add_hand(save)
	if save.hands != 2:
		failed = true
		push_error("add_hand should add a hand")
	# An old save: meter stamped without its ×1.2, bulk procurement stamped, price above the cap.
	var old := SaveGame.new()
	old.stamped = PackedStringArray(["price_slate", "junior_associate", "acceptance_meter", "bulk_procurement"])
	old.sale_price = 999
	UpgradeDesk.migrate(old)
	if old.hands != 1 or not is_equal_approx(old.marketing, 1.2) or not old.tree_bought.has("pack_1") \
			or old.sale_price != PriceSlate.max_price(1.2) or old.migration != SaveGame.MIGRATION:
		failed = true
		push_error("migration wrong: hands %d, marketing %.2f, tree %s, price %d" % [old.hands, old.marketing, old.tree_bought, old.sale_price])
	UpgradeDesk.migrate(old)
	if not is_equal_approx(old.marketing, 1.2) or old.tree_bought.size() != 1:
		failed = true
		push_error("migration should run once")
	# The build that added the ×1.2 logged it: no second ×1.2.
	var logged := SaveGame.new()
	logged.stamped = PackedStringArray(["acceptance_meter"])
	logged.playtest_log.append(logged.log_entry(10, "session"))
	logged.marketing = 1.2
	logged.playtest_log.append(logged.log_entry(20, "card", "acceptance_meter", 40, "coins"))
	UpgradeDesk.migrate(logged)
	if not is_equal_approx(logged.marketing, 1.2):
		failed = true
		push_error("a logged meter stamp should not get the ×1.2 again: %.2f" % logged.marketing)
	if UpgradeCard.price_text(10, "findings") != "¶10" or UpgradeCard.price_text(130, "coins") != "$130":
		failed = true
		push_error("price text wrong: %s, %s" % [UpgradeCard.price_text(10, "findings"), UpgradeCard.price_text(130, "coins")])
	# Research directives and the ledger: paid in Findings, each research card titled RESEARCH:.
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.get("research", false) and (card.get("currency") != "findings" or not card.title.begins_with("RESEARCH: ")):
			failed = true
			push_error("research card %s: currency or title wrong" % card.id)
	var ledger := UpgradeDesk.card_data("stats_ledger")
	if ledger.is_empty() or ledger.get("currency") != "findings" or ledger.get("research", false):
		failed = true
		push_error("the ledger should be a ¶ card, not research")
	if not UpgradeDesk.next_cards(PackedStringArray(["price_slate", "desk_space", "acceptance_meter", "junior_associate",
			"quality_assurance", "projector", "street_posters"]), 3).has("research_inspection"):
		failed = true
		push_error("the projector should open the inspection research")
	print("upgrade desk tests failed" if failed else "upgrade desk tests passed")
	get_tree().quit(1 if failed else 0)
