extends Node
## Run: Godot --headless --path . res://tests/worlds/components/test_cabbage_feeder.tscn

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")


func _ready() -> void:
	var failed := false
	# on desk, capacity, stock -> dispense?
	for case: Array in [[0, 1, 10, true], [1, 1, 10, false], [1, 3, 1, false], [1, 3, 2, true], [0, 1, 0, false]]:
		if Feeder.should_dispense(case[0], case[1], case[2]) != case[3]:
			failed = true
			push_error("should_dispense%s wrong" % [case.slice(0, 3)])
	if Feeder.restock_wait(2.0, 0.0) != 1.0 or Feeder.restock_wait(2.0, 1.0) != 3.0:
		failed = true
		push_error("the restock wait should span 1-3 s at the starting delay")
	print("cabbage feeder tests failed" if failed else "cabbage feeder tests passed")
	get_tree().quit(1 if failed else 0)
