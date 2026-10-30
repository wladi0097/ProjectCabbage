extends Node
## Run: Godot --headless --path . res://tests/entities/coins/test_coin_pile.tscn
## (a scene, not -s, so the autoloads the scripts use exist). Exit code 1 on failure.

var _failed := false


func _ready() -> void:
	# Coins dropped on one spot spread into a mound: no cell ever towers over a neighbour.
	var stacks := {}
	for i in 300:
		var cell := CoinPile.settle_cell(stacks, Vector2i.ZERO, CoinPile.MAX_STEP)
		stacks.get_or_add(cell, []).append(i)
	for cell: Vector2i in stacks:
		for offset in CoinPile.NEIGHBOURS:
			_check(stacks[cell].size() - stacks.get(cell + offset, []).size() <= CoinPile.MAX_STEP + 1,
					"pile too steep at %s" % cell)
	_check(stacks[Vector2i.ZERO].size() > 3, "the drop point should hold the peak")

	# A toss lands where it aims.
	var g := Vector3.DOWN * 9.8
	var toss := preload("res://worlds/components/cabbage_feeder.gd").ballistic_velocity(Vector3(2, 1, 1), Vector3(1, 0.8, 0), 0.7, g)
	var landed := Vector3(2, 1, 1) + toss * 0.7 + 0.5 * g * 0.49
	_check(landed.is_equal_approx(Vector3(1, 0.8, 0)), "toss missed: %s" % landed)

	# A held cabbage is heavy: one frame of a huge mouse jump adds at most accel * delta speed,
	# and no drag ever beats the speed cap.
	var step := Cabbage.carry_velocity(Vector3.ZERO, Vector3(0, 0, -5), 0.1, 10.0, 14.0, 4.5)
	_check(is_equal_approx(step.length(), 1.4), "accel cap: %s" % step)
	var v := Vector3.ZERO
	for i in 100:
		v = Cabbage.carry_velocity(v, Vector3(0, 0, -5), 0.1, 10.0, 14.0, 4.5)
	_check(is_equal_approx(v.length(), 4.5), "speed cap: %s" % v)
	# Homing ends dropping straight down into the hopper, and arrives exactly.
	var start := Vector3(1, 0.76, 0)
	var hopper := Vector3(-0.7, 1.07, -0.67)
	_check(CoinPile.home_point(start, hopper, 1.0).is_equal_approx(hopper), "homing misses the hopper")
	var near := CoinPile.home_point(start, hopper, 0.95)
	_check(near.y > hopper.y and Vector2(near.x - hopper.x, near.z - hopper.z).length() < near.y - hopper.y,
			"homing should end mostly vertical: %s" % near)
	print("coin pile tests failed" if _failed else "coin pile tests passed")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
