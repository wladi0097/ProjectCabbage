extends Node
## Run: Godot --headless --path . res://tests/worlds/components/test_sale_window.tscn

const Sale := preload("res://worlds/components/sale_window.gd")


func _ready() -> void:
	var failed := false
	# position -> stray? (on the mat, off it on the left, behind the press; resting against the
	# ScreenBottom bar at z 1.22 - radius 0.12, or the LeftBar at x -0.564 + 0.1, is not stray)
	for case: Array in [[Vector3(0.5, 0.85, 0.3), false], [Vector3(-1.2, 0.85, 0.3), true], [Vector3(1.7, 0.85, -0.6), true],
			[Vector3(0.2, 0.87, 1.11), false], [Vector3(-0.46, 0.87, 0.3), false], [Vector3(0.5, 0.87, 1.4), true]]:
		if Sale.is_stray(case[0]) != case[1]:
			failed = true
			push_error("is_stray(%s) wrong" % case[0])
	# The QA bay takes the gap's left third: the zone keeps its right edge and starts at SPLIT_X.
	var window := SaleWindow.new()
	var zone := CollisionShape3D.new()
	zone.name = "Zone"
	var box := BoxShape3D.new()
	box.size = Vector3(2.12, 0.3, 0.58)
	zone.shape = box
	zone.position.x = 0.7
	window.add_child(zone)
	window.split()
	window.split()
	var width: float = (zone.shape as BoxShape3D).size.x
	var left := zone.position.x - width / 2.0
	var right := zone.position.x + width / 2.0
	if not is_equal_approx(left, Sale.SPLIT_X) or not is_equal_approx(right, 1.76):
		failed = true
		push_error("split zone spans %.3f..%.3f" % [left, right])
	window.free()
	# One payout hook: every boost multiplies the price; never below 1. Fines: 10x, at most all coins.
	if Sale.payout(4, {}) != 4 or Sale.payout(4, {lamp = 5.0, combo = 1.5}) != 30 or Sale.payout(1, {x = 0.1}) != 1:
		failed = true
		push_error("payout wrong")
	if Sale.fine_for(4, 100) != 40 or Sale.fine_for(4, 25) != 25 or Sale.fine_for(4, 0) != 0:
		failed = true
		push_error("fine_for wrong")
	print("sale window tests failed" if failed else "sale window tests passed")
	get_tree().quit(1 if failed else 0)
