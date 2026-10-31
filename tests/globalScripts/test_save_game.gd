extends Node
## Run: Godot --headless --path . res://tests/globalScripts/test_save_game.tscn


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	save.coins = 42
	save.playtest_log.append(save.log_entry(95, "card", "price_slate", 12, "coins"))
	var entry: Dictionary = save.playtest_log[0]
	if entry.t != 95 or entry.id != "price_slate" or entry.coins != 42:
		failed = true
		push_error("log entry wrong: %s" % entry)
	var csv := save.playtest_csv().split("\n")
	if csv[0] != ",".join(SaveGame.LOG_COLUMNS) or not csv[1].begins_with("95,card,price_slate,12,coins,42,"):
		failed = true
		push_error("csv wrong: %s" % csv)
	# Two hours of snapshots every 30 s and a purchase each minute: the first hour thins to one
	# snapshot per 5 min (12), the last hour keeps all (120), and every purchase stays.
	var entries: Array[Dictionary] = []
	for t in range(0, 7200, 30):
		entries.append(save.log_entry(t, "snapshot"))
		if t % 60 == 0:
			entries.append(save.log_entry(t, "node", "pack_1"))
	var thin := SaveGame.thin_log(entries, 7200)
	var snapshots := thin.filter(func(e: Dictionary) -> bool: return e.kind == "snapshot").size()
	if snapshots != 12 + 120 or thin.size() - snapshots != 120:
		failed = true
		push_error("thin_log kept %d snapshots and %d others" % [snapshots, thin.size() - snapshots])
	print("save game tests failed" if failed else "save game tests passed")
	get_tree().quit(1 if failed else 0)
