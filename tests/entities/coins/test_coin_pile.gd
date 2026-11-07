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
	# A payout is the fewest coins: silver $1 change, a gold $5, then bronze $10s (on top).
	_check(CoinPile.coin_values(23) == [1, 1, 1, 10, 10], "coin_values(23) = %s" % [CoinPile.coin_values(23)])
	_check(CoinPile.coin_values(4) == [1, 1, 1, 1], "coin_values(4) = %s" % [CoinPile.coin_values(4)])
	_check(CoinPile.coin_values(17) == [1, 1, 5, 10], "coin_values(17) = %s" % [CoinPile.coin_values(17)])
	_check(CoinPile.coin_values(5) == [5], "coin_values(5) = %s" % [CoinPile.coin_values(5)])
	# Each denomination looks different; the $10 (and bigger) is the thick one the stacks allow for.
	_check(CoinPile.coin_colour(1) != CoinPile.coin_colour(5) and CoinPile.coin_colour(5) != CoinPile.coin_colour(10)
			and CoinPile.coin_colour(100) == CoinPile.coin_colour(10), "coin colours")
	_check(CoinPile.thickness(10) > CoinPile.thickness(5) and CoinPile.thickness(5) == CoinPile.thickness(1), "coin thickness")
	var big := CoinPile.coin_values(1848)
	_check(big.size() <= CoinPile.MAX_THROW + 18 and big.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1848,
			"coin_values(1848) stays few and adds up: %s" % [big])

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
	_test_vacuum()
	print("coin pile tests failed" if _failed else "coin pile tests passed")
	get_tree().quit(1 if _failed else 0)


## A vacuum takes resting stacks in reach up to its room, the money stays pending until it banks it.
func _test_vacuum() -> void:
	var pile := CoinPile.new()
	pile.multimesh = MultiMesh.new()
	pile.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(pile)
	for spot: Array in [[Vector2i(0, 0), [1, 1, 10]], [Vector2i(1, 0), [1, 1]], [Vector2i(20, 0), [10]]]:
		var stack := []
		for value: int in spot[1]:
			var coin := CoinPile.Coin.new()
			coin.state = CoinPile.State.RESTING
			coin.value = value
			stack.append(coin)
			pile._coins.append(coin)
		pile._stacks[spot[0]] = stack
	_check(pile.pending_value() == 24 and pile.resting_spots().size() == 3, "setup: %d" % pile.pending_value())
	var got := pile.vacuum_at(Vector3(CoinPile.CELL * 0.5, 0.76, CoinPile.CELL * 0.5), 0.07, 4)
	_check(got == Vector2i(4, 13), "vacuum_at took %s" % got)
	_check(pile.pending_value() == 24 and pile._coins.size() == 2, "vacuumed coins must stay pending")
	# One coin of the second stack and the far stack stay; nothing taken is left in _coins.
	_check(pile._coins.all(func(coin: CoinPile.Coin) -> bool: return not coin.gone)
			and pile._coins.has(pile._stacks[Vector2i(1, 0)][0]) and pile._coins.has(pile._stacks[Vector2i(20, 0)][0]),
			"the coins left on the mat")
	_check(pile.vacuum_at(Vector3(CoinPile.CELL * 0.5, 0.76, CoinPile.CELL * 0.5), 0.07, 10) == Vector2i(1, 1), "the rest of the stack")
	pile.bank_from(Vector3.ZERO, 14)
	_check(pile.pending_value() == 24 and pile._held == 0 and pile._coins.size() == 1 + 5,
			"banked coins fly home: held %d, coins %d" % [pile._held, pile._coins.size()])
	# A delayed payout counts as pending from the start (banked on quit), and once over the timer.
	pile.throw_in_after(60.0, Vector3.ZERO, 7)
	_check(pile.pending_value() == 31, "scheduled payout pending: %d" % pile.pending_value())
	pile._throw_scheduled(Vector3.ZERO, 7)
	_check(pile.pending_value() == 31 and pile._scheduled == 0, "thrown payout pending: %d" % pile.pending_value())
	pile.free()


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
