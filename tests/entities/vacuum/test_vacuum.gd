extends Node
## Run: Godot --headless --path . res://tests/entities/vacuum/test_vacuum.tscn

var _failed := false


func _ready() -> void:
	var save := SaveGame.new()
	_check(not CoinVacuums.unlocked(save), "no vacuum before the card")
	UpgradeDesk.apply("coin_collector", save)
	save.stamped.append("coin_collector")
	_check(CoinVacuums.unlocked(save) and save.vacuums == 1, "the card gives one unit")
	# The nearest stack, skipping the ones another unit is already after.
	var spots: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0.3, 0, 0), Vector3(-0.5, 0, 0)]
	_check(CoinVacuums.nearest(spots, Vector3.ZERO) == Vector3(0.3, 0, 0), "nearest")
	var taken: Array[Vector3] = [Vector3(0.32, 0, 0)]
	_check(CoinVacuums.nearest(spots, Vector3.ZERO, taken) == Vector3(-0.5, 0, 0), "nearest skips a taken stack")
	_check(CoinVacuums.nearest([] as Array[Vector3], Vector3.ZERO) == null, "nothing to collect")
	# Turning: forward is -Z at yaw 0; a goal to the right (+X) is yaw -PI/2, reached in capped steps.
	_check(is_equal_approx(CoinVacuums.turn_toward(0.0, Vector3.ZERO, Vector3(0, 0, -1), 0.5), 0.0), "already facing")
	_check(is_equal_approx(CoinVacuums.turn_toward(0.0, Vector3.ZERO, Vector3(1, 0, 0), 0.5), -0.5), "turn step capped")
	_check(is_equal_approx(CoinVacuums.turn_toward(-1.4, Vector3.ZERO, Vector3(1, 0, 0), 0.5), -PI / 2.0), "turn lands on the goal")
	print("vacuum tests failed" if _failed else "vacuum tests passed")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
