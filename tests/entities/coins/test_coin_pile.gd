extends Node
## Run: Godot --headless --path . res://tests/entities/coins/test_coin_pile.tscn
## (a scene, not -s, so the autoloads the scripts use exist). Exit code 1 on failure.

var _failed := false


func _ready() -> void:
	# One payout's coins stack on their spot, at most MAX_STACK high, then spill right beside it.
	var stacks := {}
	for i in 25:
		var cell := CoinPile.stack_cell(stacks, Vector2i.ZERO, CoinPile.MAX_STACK)
		stacks.get_or_add(cell, []).append(i)
	_check(stacks[Vector2i.ZERO].size() == CoinPile.MAX_STACK, "the aimed stack should fill first")
	for cell: Vector2i in stacks:
		_check(stacks[cell].size() <= CoinPile.MAX_STACK, "stack too tall at %s" % cell)
		_check(maxi(absi(cell.x), absi(cell.y)) <= 1, "overflow should land right beside the stack: %s" % cell)
	# A payout is silver for the change, then gold for every full 10 (on top).
	_check(CoinPile.coin_values(23) == [1, 1, 1, 10, 10], "coin_values(23) = %s" % [CoinPile.coin_values(23)])
	_check(CoinPile.coin_values(4) == [1, 1, 1, 1], "coin_values(4) = %s" % [CoinPile.coin_values(4)])

	# A toss lands where it aims.
	var g := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var toss := preload("res://worlds/components/cabbage_feeder.gd").ballistic_velocity(Vector3(2, 1, 1), Vector3(1, 0.8, 0), 0.7)
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
