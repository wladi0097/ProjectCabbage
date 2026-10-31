extends Node
## Run: Godot --headless --path . res://tests/entities/price_slate/test_price_slate.tscn

const Slate := preload("res://entities/price_slate/price_slate.gd")


func _ready() -> void:
	var failed := false
	for case: Array in [[2, 1.0], [3, 1.0], [4, 0.5625], [6, 0.25]]:
		var got := Slate.demand(case[0], Slate.ref_price(1.0, 1.0))
		if absf(got - case[1]) > 0.001:
			failed = true
			push_error("demand(%s) = %s" % [case[0], got])
	if not is_equal_approx(Slate.demand(6, Slate.ref_price(2.0, 1.0)), 1.0):
		failed = true
		push_error("marketing x2 should sell everything at $6")
	if Slate.max_price(1.0) != 12 or Slate.max_price(2.25) != 27:
		failed = true
		push_error("max price should be 12 x marketing")
	if Slate.next_mood(1.2, 0.1) != Slate.MOOD_RANGE.y or Slate.next_mood(0.8, -0.1) != Slate.MOOD_RANGE.x:
		failed = true
		push_error("mood should stay in its range")
	if Slate.wiggle_at(0.0) != 0.0 or Slate.wiggle_at(Slate.WIGGLE_TIME) != 0.0 or absf(Slate.wiggle_at(0.04)) < 0.05:
		failed = true
		push_error("wiggle should start and end at rest and shake in between")
	if not is_equal_approx(Slate.needle_angle(0.5), 0.0) or Slate.needle_angle(0.0) <= 0.0 or Slate.needle_angle(1.0) >= 0.0:
		failed = true
		push_error("needle should point up at 50%, turn left (positive) below and right above")
	print("price slate tests failed" if failed else "price slate tests passed")
	get_tree().quit(1 if failed else 0)
