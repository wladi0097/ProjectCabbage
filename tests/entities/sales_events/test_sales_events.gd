extends Node
## Run: Godot --headless --path . res://tests/entities/sales_events/test_sales_events.tscn
## The golden lamp, catch combo, rotten bin and window targets' pure logic.

const Lamp := preload("res://entities/golden_lamp/golden_lamp.gd")
const Combo := preload("res://entities/catch_combo/catch_combo.gd")
const Bin := preload("res://entities/rotten_bin/rotten_bin.gd")
const Targets := preload("res://entities/window_targets/window_targets.gd")
const Desk := preload("res://entities/upgrade_desk/upgrade_desk.gd")
const Nodes := preload("res://entities/projector/projector.gd")
const Events := preload("res://globalScripts/game_events.gd")

var failed := false


func _ready() -> void:
	# Lamp: waits spread 0.6..1.4 of the mean; full glow until the last seconds, then flicker.
	_check(is_equal_approx(Lamp.next_wait(100.0, 0.0), 60.0) and is_equal_approx(Lamp.next_wait(100.0, 1.0), 140.0), "lamp wait")
	_check(Lamp.glow_at(10.0, 1.0) == 1.0 and Lamp.glow_at(1.0, 1.0) < 1.0 + 1e-6 and Lamp.glow_at(1.0, 1.0) >= 0.1, "lamp glow")
	# Combo: +step per catch up to the cap.
	_check(Combo.multiplier(0, 0.1, 1.5) == 1.0 and is_equal_approx(Combo.multiplier(3, 0.1, 1.5), 1.3)
			and is_equal_approx(Combo.multiplier(20, 0.1, 1.5), 1.5), "combo multiplier")
	# Bin: inside the mouth and low enough; rebate in chalked prices.
	var bin := Vector3(0.95, 0.76, 1.2)
	_check(Bin.in_mouth(bin, Vector3(1.0, 0.9, 1.1), 0.25) and not Bin.in_mouth(bin, Vector3(1.0, 1.3, 1.1), 0.25)
			and not Bin.in_mouth(bin, Vector3(0.5, 0.9, 1.1), 0.25), "bin mouth")
	_check(Bin.rebate_for(0.0, 4) == 0 and Bin.rebate_for(1.0, 4) == 4, "bin rebate")
	# Rotten units start once the bin card is offered (or stamped), never before the tray.
	var save := SaveGame.new()
	_check(not Bin.rotten_due(save), "no rot on a fresh save")
	save.stamped = PackedStringArray([Bin.CARD])
	_check(Bin.rotten_due(save), "rot once the bin is stamped")
	# The real queue: once catch_combo is stamped the bin card is dealt, and rot starts with it.
	var dealt := SaveGame.new()
	dealt.stamped = PackedStringArray(["price_slate", "radio", "desk_space", "junior_associate", "acceptance_meter",
			"mini_cabbages", "quality_assurance", "street_posters", "projector", "research_inspection",
			"pricing_consultant", "research_cabbage", "mini_tube"])
	dealt.tray_unlocked = true
	_check(not Bin.rotten_due(dealt), "no rot before the bin card is offered")
	dealt.stamped.append("catch_combo")
	_check(Desk.next_cards(dealt.stamped, Desk.OFFERED).has(Bin.CARD) and Bin.rotten_due(dealt), "rot once the bin card is offered")
	dealt.tray_unlocked = false
	_check(not Bin.rotten_due(dealt), "no rot before the tray")
	# Every big event names a real card or save flag.
	for id: String in Events.EVENTS:
		var event: Dictionary = Events.EVENTS[id]
		_check(not Desk.card_data(event.card).is_empty() if event.has("card") else event.flag in SaveGame.new(), "event " + id)
	var slate := SaveGame.new()
	slate.slate_unlocked = true
	_check(Events.due("mood_drift", slate) and not Events.due("mood_drift", SaveGame.new()), "flag event")
	# The hop into the bin: starts and ends in place, tops out over the rim, ends in a straight drop.
	var from := Vector3(1.2, 0.87, 0.9)
	var into := Vector3(0.95, 0.82, 1.04)
	_check(Cabbage.hop_at(from, into, 1.2, 0.0).is_equal_approx(from) and Cabbage.hop_at(from, into, 1.2, 1.0).is_equal_approx(into)
			and is_equal_approx(Cabbage.hop_at(from, into, 1.2, 0.45).y, 1.2), "hop ends")
	var late := Cabbage.hop_at(from, into, 1.2, 0.75)
	_check(is_equal_approx(late.x, into.x) and is_equal_approx(late.z, into.z) and late.y > 1.0, "hop drops in from the top")
	# Targets: a roll lights one of the three crates, all right of the QA bay's split; hits within half a width.
	_check(Targets.pick_centre(0.0) == Targets.CRATE_X[0] and Targets.pick_centre(0.5) == Targets.CRATE_X[1]
			and Targets.pick_centre(1.0) == Targets.CRATE_X[2], "target centre")
	_check(Targets.CRATE_X[0] - Targets.WIDTH / 2.0 >= SaleWindow.SPLIT_X
			and Targets.CRATE_X[2] + Targets.WIDTH / 2.0 <= SaleWindow.GAP_X.y + 0.1, "crates in the sell span")
	_check(Targets.hits(0.5, 0.6, 0.3) and not Targets.hits(0.3, 0.6, 0.3), "target hits")
	# Every card and tree node of the sales events exists and applies to real save numbers.
	for id in [Lamp.CARD, Combo.CARD, Bin.CARD, Targets.CARD]:
		_check(not Desk.card_data(id).is_empty(), "card " + id)
	for id in ["lamp_mult", "lamp_time", "lamp_every", "combo_window", "combo_cap", "combo_step",
			"bin_mouth", "bin_rebate", "bin_rebate_2", "bin_rebate_3", "bin_rebate_4", "bin_rebate_5", "hands_bin",
			"target_size", "target_every", "target_shower"]:
		var fresh := SaveGame.new()
		var before := {}
		for stat in Nodes.node_data(id).get("mul", {}).keys() + Nodes.node_data(id).get("add", {}).keys():
			before[stat] = fresh.get(stat)
		Nodes.apply(id, fresh)
		_check(not before.is_empty() and before.keys().all(func(stat: String) -> bool: return fresh.get(stat) != before[stat]), "node " + id)
	# Disposal rebate tiers: 20% of the chalked price, +25 points a tier, 120% at the top.
	var rebate := SaveGame.new()
	var tiers := []
	for id in ["bin_rebate", "bin_rebate_2", "bin_rebate_3", "bin_rebate_4", "bin_rebate_5"]:
		Nodes.apply(id, rebate)
		tiers.append(rebate.bin_rebate)
	var want := [0.2, 0.45, 0.7, 0.95, 1.2]
	_check(range(5).all(func(i: int) -> bool: return is_equal_approx(tiers[i], want[i])) and Bin.rebate_for(0.2, 10) == 2, "rebate tiers %s" % [tiers])
	print("sales events tests failed" if failed else "sales events tests passed")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		push_error(what + " wrong")
