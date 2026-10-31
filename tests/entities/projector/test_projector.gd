extends Node
## Run: Godot --headless --path . res://tests/entities/projector/test_projector.tscn


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	if Projector.unlocked(save):
		failed = true
		push_error("the projector should wait for its desk card")
	save.stamped = PackedStringArray(["projector"])
	if not Projector.unlocked(save):
		failed = true
		push_error("the projector card should unlock it")
	var ids := {}
	for node: Dictionary in Projector.NODES:
		if ids.has(node.id) or (node.parent != "" and Projector.node_data(node.parent).is_empty()):
			failed = true
			push_error("node %s: duplicate id or unknown parent" % node.id)
		ids[node.id] = true
		for stat in node.get("mul", {}).keys() + node.get("add", {}).keys():
			if save.get(stat) == null:
				failed = true
				push_error("node %s changes %s, which the save doesn't have" % [node.id, stat])
	# The id lookup (cached) finds every node and nothing else.
	if Projector.node_data("slogan_2").parent != "slogan_1" or not Projector.node_data("no_such_node").is_empty() \
			or Projector.NODES.any(func(node: Dictionary) -> bool: return Projector.node_data(node.id) != node):
		failed = true
		push_error("node_data should find each node by id and {} for an unknown id")
	if not Projector.is_shown("slogan_1", save) or Projector.is_shown("slogan_2", save):
		failed = true
		push_error("Slogan I should show, Slogan II only after it")
	if Projector.is_shown("associate_1", save):
		failed = true
		push_error("the associate node should wait for the junior associate card")
	save.coins = 10
	if Projector.buy("slogan_1", save) or save.coins != 10:
		failed = true
		push_error("an unaffordable node should not be bought")
	save.coins = 1000
	if not Projector.buy("slogan_1", save) or save.coins != 1000 - Projector.node_data("slogan_1").price or not is_equal_approx(save.marketing, 1.25) \
			or not save.tree_bought.has("slogan_1") or Projector.buy("slogan_1", save):
		failed = true
		push_error("buying Slogan I: coins %d, marketing %.2f" % [save.coins, save.marketing])
	if not Projector.is_shown("slogan_2", save):
		failed = true
		push_error("Slogan II should show once Slogan I is bought")
	var fresh := SaveGame.new()
	var base := SaveGame.new()
	for id: String in ["pack_1", "associate_1", "qa_time", "qa_findings", "double_findings", "conveyor_1"]:
		Projector.apply(id, fresh)
	if fresh.pack_size != base.pack_size + 3 or not is_equal_approx(fresh.associate_speed, base.associate_speed * 1.5) \
			or not is_equal_approx(fresh.qa_time, base.qa_time * 0.75) or fresh.findings_per_cabbage != (base.findings_per_cabbage + 1) * 2 \
			or not is_equal_approx(fresh.dispense_interval, base.dispense_interval * 0.5) or fresh.desk_capacity != base.desk_capacity + 2:
		failed = true
		push_error("effects wrong: pack %d, associate %.2f, qa %.2f, findings %d, dispense %.2f, capacity %d" % [fresh.pack_size,
				fresh.associate_speed, fresh.qa_time, fresh.findings_per_cabbage, fresh.dispense_interval, fresh.desk_capacity])
	# The hire ladder: II needs the junior associate, each adds one hand, each costs more than the last.
	if Projector.is_shown("hire_associate_2", save):
		failed = true
		push_error("Hire Associate II should wait for the junior associate card")
	save.stamped.append("junior_associate")
	save.stamped.append("performance_review")  # The research behind Hire Associate V.
	save.coins = 100000
	var last := 0
	for n in range(2, 11):
		var id := "hire_associate_%d" % n
		var hands := save.hands
		var price: int = Projector.node_data(id).price
		if not Projector.buy(id, save) or save.hands != hands + 1 or price <= last * 1.3:
			failed = true
			push_error("%s: hands %d, price %d after %d" % [id, save.hands, price, last])
		last = price
	# Research gates: every `research` is a research card on the desk; the first ring is open.
	for node: Dictionary in Projector.NODES:
		var card: String = node.get("research", "")
		if card != "" and not UpgradeDesk.card_data(card).get("research", false):
			failed = true
			push_error("node %s waits for %s, which is no research card" % [node.id, card])
		if node.parent == "" and card != "":
			failed = true
			push_error("first-ring node %s should not need research" % node.id)
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.get("research", false) and not Projector.NODES.any(func(node: Dictionary) -> bool: return node.get("research", "") == card.id):
			failed = true
			push_error("research card %s opens nothing" % card.id)
	var gated := SaveGame.new()
	gated.stamped = PackedStringArray(["projector", "junior_associate"])
	gated.tree_bought = PackedStringArray(["hire_associate_2", "hire_associate_3", "hire_associate_4", "pack_1"])
	gated.coins = 100000
	# Shown (the player sees what research opens) but locked, and its children stay hidden.
	if not Projector.is_shown("hire_associate_5", gated) or Projector.locked_by("hire_associate_5", gated) != "performance_review" \
			or Projector.buy("hire_associate_5", gated) or Projector.is_shown("hire_associate_6", gated) \
			or Projector.locked_by("conveyor_1", gated) != "research_materials" or Projector.locked_by("pack_1", gated) != "":
		failed = true
		push_error("Hire Associate V should show locked behind the time-and-motion study")
	var shown := Projector.shown_nodes(gated)
	if shown.get("hire_associate_5") != "performance_review" or shown.has("hire_associate_6") or shown.get("pack_1") != "" \
			or shown.size() != Projector.NODES.filter(func(node: Dictionary) -> bool: return Projector.is_shown(node.id, gated)).size():
		failed = true
		push_error("shown_nodes should list the shown nodes with their research locks: %s" % shown)
	gated.stamped.append("performance_review")
	if Projector.locked_by("hire_associate_5", gated) != "" or not Projector.buy("hire_associate_5", gated):
		failed = true
		push_error("the stamped research should unlock Hire Associate V")
	# Supply + automation: every capacity source together fills the mat to exactly 20, every hire to
	# Associate.MAX_VISIBLE hands, and Open-Plan Seating raises the hands' output.
	var full := SaveGame.new()
	UpgradeDesk.apply("desk_space", full)
	UpgradeDesk.apply("junior_associate", full)
	UpgradeDesk.apply("coin_collector", full)
	for node: Dictionary in Projector.NODES:
		Projector.apply(node.id, full)
	if full.desk_capacity != 20 or full.hands != Associate.MAX_VISIBLE or not is_equal_approx(full.hand_output, 2.25) \
			or full.qa_slots != 3 or full.qa_feed_every != 3 or full.vacuums != 3 or full.auto_reserve != 25:
		failed = true
		push_error("everything bought: capacity %d, hands %d, output %.2f, qa %d/%d, vacuums %d, reserve %d" % [full.desk_capacity,
				full.hands, full.hand_output, full.qa_slots, full.qa_feed_every, full.vacuums, full.auto_reserve])
	# No two nodes on the same spot of the wheel.
	for a: Dictionary in Projector.NODES:
		for b: Dictionary in Projector.NODES:
			if a.id < b.id and a.at.distance_to(b.at) < 0.2:
				failed = true
				push_error("nodes %s and %s overlap" % [a.id, b.id])
	print("projector tests failed" if failed else "projector tests passed")
	get_tree().quit(1 if failed else 0)
