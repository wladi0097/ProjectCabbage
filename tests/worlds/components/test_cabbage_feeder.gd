extends Node
## Run: Godot --headless --path . res://tests/worlds/components/test_cabbage_feeder.tscn

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")


func _ready() -> void:
	var failed := false
	# fresh on desk, all on desk, capacity, stock -> dispense? Rotten units don't take a place.
	for case: Array in [[0, 0, 1, 10, true], [1, 1, 1, 10, false], [1, 1, 3, 1, false], [1, 1, 3, 2, true], [0, 0, 1, 0, false],
			[0, 2, 1, 10, true], [1, 3, 1, 10, false], [0, 2, 1, 2, false]]:
		if Feeder.should_dispense(case[0], case[1], case[2], case[3]) != case[4]:
			failed = true
			push_error("should_dispense%s wrong" % [case.slice(0, 4)])
	if Feeder.restock_wait(2.0, 0.0) != 1.0 or Feeder.restock_wait(2.0, 1.0) != 3.0:
		failed = true
		push_error("the restock wait should span 1-3 s at the starting delay")
	# Rotten units: none before they are unlocked, one in ROTTEN_EVERY after.
	# MAX_ROTTEN on the mat: fresh ones only.
	if Feeder.is_rotten(false, 0.0) or not Feeder.is_rotten(true, 0.0) or Feeder.is_rotten(true, 0.5) 			or not Feeder.is_rotten(true, 0.0, Feeder.MAX_ROTTEN - 1) or Feeder.is_rotten(true, 0.0, Feeder.MAX_ROTTEN):
		failed = true
		push_error("is_rotten wrong")
	print("cabbage feeder tests failed" if failed else "cabbage feeder tests passed")
	get_tree().quit(1 if failed else 0)
