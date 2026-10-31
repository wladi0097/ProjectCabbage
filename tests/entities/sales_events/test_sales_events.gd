extends Node
## Run: Godot --headless --path . res://tests/entities/sales_events/test_sales_events.tscn
## The golden lamp, catch combo, rotten bin and window targets' pure logic.

const Lamp := preload("res://entities/golden_lamp/golden_lamp.gd")
const Combo := preload("res://entities/catch_combo/catch_combo.gd")
const Bin := preload("res://entities/rotten_bin/rotten_bin.gd")
const Targets := preload("res://entities/window_targets/window_targets.gd")
const Desk := preload("res://entities/upgrade_desk/upgrade_desk.gd")
const Nodes := preload("res://entities/projector/projector.gd")

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
	# Targets: centres keep the whole target in the span; hits within half a width.
	_check(is_equal_approx(Targets.pick_centre(Vector2(0.0, 1.0), 0.2, 0.0), 0.1)
			and is_equal_approx(Targets.pick_centre(Vector2(0.0, 1.0), 0.2, 1.0), 0.9)
			and is_equal_approx(Targets.pick_centre(Vector2(0.0, 0.1), 0.4, 0.3), 0.05), "target centre")
	_check(Targets.hits(0.5, 0.6, 0.3) and not Targets.hits(0.3, 0.6, 0.3), "target hits")
	# Every card and tree node of the sales events exists and applies to real save numbers.
	for id in [Lamp.CARD, Combo.CARD, Bin.CARD, Targets.CARD]:
		_check(not Desk.card_data(id).is_empty(), "card " + id)
	for id in ["lamp_mult", "lamp_time", "lamp_every", "combo_window", "combo_cap", "combo_step",
			"bin_mouth", "bin_rebate", "hands_bin", "target_size", "target_every", "target_shower"]:
		var fresh := SaveGame.new()
		var before := {}
		for stat in Nodes.node_data(id).get("mul", {}).keys() + Nodes.node_data(id).get("add", {}).keys():
			before[stat] = fresh.get(stat)
		Nodes.apply(id, fresh)
		_check(not before.is_empty() and before.keys().all(func(stat: String) -> bool: return fresh.get(stat) != before[stat]), "node " + id)
	print("sales events tests failed" if failed else "sales events tests passed")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		push_error(what + " wrong")
