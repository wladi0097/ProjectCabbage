extends Node
## Run: Godot --headless --path . res://tests/worlds/components/test_sale_window.tscn

const Sale := preload("res://worlds/components/sale_window.gd")


func _ready() -> void:
	var failed := false
	# position -> stray? (on the mat, off it on the left, behind the press)
	for case: Array in [[Vector3(0.5, 0.85, 0.3), false], [Vector3(-1.2, 0.85, 0.3), true], [Vector3(1.7, 0.85, -0.6), true]]:
		if Sale.is_stray(case[0]) != case[1]:
			failed = true
			push_error("is_stray(%s) wrong" % case[0])
	print("sale window tests failed" if failed else "sale window tests passed")
	get_tree().quit(1 if failed else 0)
