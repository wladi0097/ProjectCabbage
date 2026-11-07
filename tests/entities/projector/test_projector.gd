extends Node
## Run: timeout 120 Godot --headless --path . res://tests/entities/projector/test_projector.tscn --quit-after 600
## (--quit-after: a script that fails to parse never reaches quit() below and would hang.)


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
	# Departments: free sub-hubs, never bought; marketing opens with the street poster card, its
	# slogans greyed until then (the popup names the card).
	if Projector.is_reachable("slogan_1", save) or Projector.requirement("slogan_1", save) != ["REQUIRES DESK CARD:", "STREET POSTER CAMPAIGN"] \
			or not Projector.is_reachable("dept_manual", save) or not Projector.is_open("dept_manual", save):
		failed = true
		push_error("Slogan I should wait for the street posters: %s" % [Projector.requirement("slogan_1", save)])
	save.stamped.append("street_posters")
	save.coins = 1000
	if not Projector.is_open("dept_marketing", save) or Projector.can_hold("dept_marketing", save) or Projector.buy("dept_marketing", save) \
			or save.coins != 1000 or not save.tree_bought.is_empty():
		failed = true
		push_error("a department should open with its card and never be bought")
	var qa := SaveGame.new()
	qa.stamped = PackedStringArray(["projector", "quality_assurance"])
	if Projector.is_open("dept_qa", qa) or Projector.is_reachable("qa_time", qa) or Projector.requirement("qa_time", qa)[0] != "REQUIRES RESEARCH:":
		failed = true
		push_error("the QA department should wait for its research")
	qa.stamped.append("research_inspection")
	if not Projector.is_open("dept_qa", qa) or not Projector.can_hold("qa_time", qa):
		failed = true
		push_error("Faster Analysis should open with the QA department, whatever else is bought")
	# Every upgrade hangs under exactly one department; only departments sit on the hub.
	for node: Dictionary in Projector.NODES:
		var top := node
		while top.parent != "":
			top = Projector.node_data(top.parent)
		if not top.get("dept", false) or (node.parent == "") != node.get("dept", false):
			failed = true
			push_error("node %s should hang under a department" % node.id)
	if not Projector.is_reachable("slogan_1", save) or Projector.is_reachable("slogan_2", save):
		failed = true
		push_error("Slogan I should show, Slogan II only after it")
	if Projector.is_reachable("associate_1", save):
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
	if not Projector.is_reachable("slogan_2", save):
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
	if Projector.is_reachable("hire_associate_2", save):
		failed = true
		push_error("Hire Associate II should wait for the junior associate card")
	save.stamped.append("junior_associate")
	save.stamped.append("performance_review")  # The research behind Hire Associate V.
	save.coins = 10000000
	var last := 0
	for n in range(2, 11):
		var id := "hire_associate_%d" % n
		var hands := save.hands
		var price: int = Projector.node_data(id).price
		if not Projector.buy(id, save) or save.hands != hands + 1 or price <= last * 1.3:
			failed = true
			push_error("%s: hands %d, price %d after %d" % [id, save.hands, price, last])
		last = price
	# Research gates: every `research` is a research card on the desk (departments may carry one too).
	for node: Dictionary in Projector.NODES:
		var card: String = node.get("research", "")
		if card != "" and not UpgradeDesk.card_data(card).get("research", false):
			failed = true
			push_error("node %s waits for %s, which is no research card" % [node.id, card])
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.get("research", false) and not Projector.NODES.any(func(node: Dictionary) -> bool: return node.get("research", "") == card.id):
			failed = true
			push_error("research card %s opens nothing" % card.id)
	var gated := SaveGame.new()
	gated.stamped = PackedStringArray(["projector", "junior_associate"])
	gated.tree_bought = PackedStringArray(["hire_associate_2", "hire_associate_3", "hire_associate_4", "pack_1"])
	gated.coins = 100000
	# Shown (the player sees what research opens) but locked, and its children stay hidden.
	if not Projector.is_reachable("hire_associate_5", gated) or Projector.locked_by("hire_associate_5", gated) != "performance_review" \
			or Projector.buy("hire_associate_5", gated) or Projector.is_reachable("hire_associate_6", gated) \
			or Projector.locked_by("conveyor_1", gated) != "research_materials" or Projector.locked_by("pack_1", gated) != "":
		failed = true
		push_error("Hire Associate V should show locked behind the time-and-motion study")
	# Every node is drawn; the popup names what an unreachable or locked one waits for.
	if Projector.requirement("hire_associate_6", gated) != ["REQUIRES:", "HIRE ASSOCIATE V"] \
			or Projector.requirement("hire_associate_5", gated)[0] != "REQUIRES RESEARCH:" \
			or Projector.requirement("manager_time", gated)[0] != "REQUIRES DESK CARD:" or not Projector.requirement("pack_2", gated)[0].begins_with("REQUIRES") \
			or not Projector.requirement("discount_1", gated).is_empty() or Projector.can_hold("hire_associate_5", gated) or not Projector.can_hold("discount_1", gated):
		failed = true
		push_error("requirement / can_hold wrong: %s, %s" % [Projector.requirement("hire_associate_6", gated), Projector.requirement("manager_time", gated)])
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
			or full.qa_slots != 3 or full.vacuums != 3 or full.auto_reserve != 25:
		failed = true
		push_error("everything bought: capacity %d, hands %d, output %.2f, qa %d, vacuums %d, reserve %d" % [full.desk_capacity,
				full.hands, full.hand_output, full.qa_slots, full.vacuums, full.auto_reserve])
	# Merged chains in an old save: kept nodes that now do more top up the difference, never more
	# than the new chain gives, never less than the old one gave.
	var half := SaveGame.new()
	half.tree_bought = PackedStringArray(["desk_1", "vacuum_speed_1", "vacuum_2", "vacuum_bag_1", "associate_3", "associate_4"])
	half.desk_capacity = 3
	half.vacuum_capacity = 20
	half.associate_speed = 1.5
	Projector.migrate_merged(half)
	var whole := SaveGame.new()
	whole.tree_bought = PackedStringArray(["desk_1", "desk_2", "desk_3", "desk_4", "desk_5", "desk_6", "discount_1", "discount_2", "discount_3"])
	whole.desk_capacity = 13
	whole.pack_discount = 0.85 * 0.85 * 0.8
	Projector.migrate_merged(whole)
	if half.desk_capacity != 5 or half.vacuum_capacity != 20 or not is_equal_approx(half.associate_speed, 1.5) \
			or whole.desk_capacity != 13 or not is_equal_approx(whole.pack_discount, 0.85 * 0.85 * 0.8):
		failed = true
		push_error("merged chains: desk %d, bag %d, speed %.2f, full desk %d, discount %.3f" % [half.desk_capacity,
				half.vacuum_capacity, half.associate_speed, whole.desk_capacity, whole.pack_discount])
	# No two nodes on the same spot of the wheel.
	for a: Dictionary in Projector.NODES:
		for b: Dictionary in Projector.NODES:
			if a.id < b.id and a.at.distance_to(b.at) < 0.2:
				failed = true
				push_error("nodes %s and %s overlap" % [a.id, b.id])
	# The pull's pendulum: let go off to the side, it swings down and comes to rest straight under the
	# tie, the cord never longer than CORD.
	var tie := Vector3(0.0, 1.2, 0.0)
	var bob := tie + Vector3(Projector.CORD, 0.0, 0.0)
	var before := bob
	var longest := 0.0
	for step in 1200:
		var next := Projector.swing(bob, before, tie, 1.0 / 60.0)
		before = bob
		bob = next
		longest = maxf(longest, tie.distance_to(bob))
	if longest > Projector.CORD + 0.0001 or bob.distance_to(tie + Vector3.DOWN * Projector.CORD) > 0.01:
		failed = true
		push_error("the pull should settle under its tie: at %s, longest cord %.3f" % [bob, longest])
	# The drawing's cache key counts the affordable nodes; the lamp's pulse stays gentle.
	var upgrades := Projector.NODES.filter(func(node: Dictionary) -> bool: return not node.get("dept", false))
	if Projector.affordable(0) != 0 or Projector.affordable(1 << 30) != upgrades.size() \
			or Projector.affordable(40) != upgrades.filter(func(node: Dictionary) -> bool: return node.price <= 40).size():
		failed = true
		push_error("affordable() should count the nodes a budget covers")
	for i in 100:
		var light := Projector.pulse(i * 0.37)
		if light < 0.94 or light > 1.0:
			failed = true
			push_error("pulse %.3f out of its gentle range" % light)
			break
	# The cached tree layer must not be a Control: a Control is culled by its own empty rect, so the
	# whole tree vanished once the hub was panned off the slide.
	var screen := Projector.new()
	if not screen._layer is Node2D:
		failed = true
		push_error("the tree layer should be a Node2D (culled by what it draws, not by a rect)")
	for child: Node in [screen._layer, screen._top, screen._tree, screen._overlay, screen._sfx, screen._cord, screen._tab]:
		child.free()
	screen.free()
	# No two edges of the tree cross (hub to first ring, parent to child).
	var edges := []
	for node: Dictionary in Projector.NODES:
		edges.append([Vector2.ZERO if node.parent == "" else Projector.node_data(node.parent).at, node.at, node.id])
	for a in edges.size():
		for b in range(a + 1, edges.size()):
			var e: Array = edges[a]
			var f: Array = edges[b]
			if e[0] == f[0] or e[0] == f[1] or e[1] == f[0] or e[1] == f[1]:
				continue
			if Geometry2D.segment_intersects_segment(e[0], e[1], f[0], f[1]) != null:
				failed = true
				push_error("edges to %s and %s cross" % [e[2], f[2]])
	print("projector tests failed" if failed else "projector tests passed")
	get_tree().quit(1 if failed else 0)
