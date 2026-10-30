extends Node
## Run: Godot --headless --path . res://tests/entities/tally_machine/test_tally_machine.tscn


func _ready() -> void:
	var failed := false
	for case: Array in [[1234.0, [4, 3, 2, 1, 0]], [19.5, [9.5, 1.5, 0, 0, 0]], [15.25, [5.25, 1, 0, 0, 0]],
			[999.5, [9.5, 9.5, 9.5, 0.5, 0]], [0.0, [0, 0, 0, 0, 0]]]:
		var got := TallyMachine.drum_positions(case[0], 5)
		for k in 5:
			if not is_equal_approx(got[k], case[1][k]):
				failed = true
				push_error("drums for %s: %s" % [case[0], got])
				break
	print("tally machine tests failed" if failed else "tally machine tests passed")
	get_tree().quit(1 if failed else 0)
