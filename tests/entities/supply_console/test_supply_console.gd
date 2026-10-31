extends Node
## Run: Godot --headless --path . res://tests/entities/supply_console/test_supply_console.tscn

const Console := preload("res://entities/supply_console/supply_console.gd")


func _ready() -> void:
	var failed := false
	for case: Array in [[0.0, 0.0, 1.0], [0.12, 0.1, 1.22], [0.9, 0.25, 1.5], [0.0, -0.7, 0.5]]:
		var got := Console.next_factor(case[0], case[1])
		if not is_equal_approx(got, case[2]):
			failed = true
			push_error("next_factor(%s, %s) = %s" % [case[0], case[1], got])
	# 35% of the full-sale price ($3 x marketing) per cabbage, times the factor; never under $1.
	for case: Array in [[1.0, 13, 1.0, 14], [0.5, 10, 1.0, 5], [1.5, 10, 1.0, 16], [1.0, 10, 2.0, 21], [0.5, 1, 1.0, 1]]:
		var got := Console.pack_price(case[0], case[1], case[2])
		if got != case[3]:
			failed = true
			push_error("pack_price(%s, %s, %s) = %s" % [case[0], case[1], case[2], got])
	var line := Console.sparkline(PackedFloat32Array([0.5, 1.5]), 5, Vector2(4, 1))
	if line != PackedVector2Array([Vector2(3, 0), Vector2(4, 1)]):
		failed = true
		push_error("sparkline = %s" % line)
	var walked := Console.walk_back(1.4, PackedFloat32Array([0.2, -0.3, 0.1]))
	var expected := [1.4, 1.5, 1.2, 1.4]   # newest step first; 1.4 - -0.3 hits the 1.5 cap
	if walked.size() != 4 or range(4).any(func(i: int) -> bool: return not is_equal_approx(walked[i], expected[i])):
		failed = true
		push_error("walk_back = %s" % walked)
	if Console.walk_back(1.45, PackedFloat32Array([-0.2]))[0] != 1.5:
		failed = true
		push_error("walk_back does not clamp")
	for case: Array in [[0, 3, 6, true], [0, 6, 6, false], [1, 0, 6, false], [0, 0, 0, false]]:
		if Console.is_broke(case[0], case[1], case[2]) != case[3]:
			failed = true
			push_error("is_broke(%s, %s, %s) wrong" % [case[0], case[1], case[2]])
	if Console.pack_price(1.0, 10, 1.0, 0.5) != 5:
		failed = true
		push_error("pack_price should apply the discount")
	# Auto-buy: stock at or under the reserve and the money there; while stock lasts, only at a fair price.
	for case: Array in [[3, 3, 1.4, 1.5, 20, 10, true], [4, 3, 1.0, 1.5, 20, 10, false], [2, 3, 1.0, 1.5, 5, 10, false],
			[2, 3, 1.3, 1.0, 20, 10, false], [0, 3, 1.3, 1.0, 20, 10, true], [2, 3, 1.0, 1.0, 20, 10, true]]:
		if Console.should_auto_buy(case[0], case[1], case[2], case[3], case[4], case[5]) != case[6]:
			failed = true
			push_error("should_auto_buy%s wrong" % [case])
	print("supply console tests failed" if failed else "supply console tests passed")
	get_tree().quit(1 if failed else 0)
