extends GdUnitTestSuite


func test_there_are_no_vacuums_before_the_coin_collector_card() -> void:
	assert_bool(CoinVacuums.unlocked(SaveGame.new())).is_false()


func test_the_coin_collector_card_brings_the_first_vacuum() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("coin_collector", save)
	save.stamped.append("coin_collector")
	assert_int(save.vacuums).is_equal(1)
	assert_bool(CoinVacuums.unlocked(save)).is_true()


func test_the_coin_collector_card_never_takes_vacuums_away() -> void:
	var save := SaveGame.new()
	save.vacuums = 3
	UpgradeDesk.apply("coin_collector", save)
	assert_int(save.vacuums).is_equal(3)


func test_a_stamped_card_without_units_parks_no_dock() -> void:
	var save := SaveGame.new()
	save.stamped.append("coin_collector")
	assert_bool(CoinVacuums.unlocked(save)).is_false()


func test_a_vacuum_heads_for_the_nearest_stack() -> void:
	var spots: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0.3, 0, 0), Vector3(-0.5, 0, 0)]
	assert_vector(CoinVacuums.nearest(spots, Vector3.ZERO)).is_equal(Vector3(0.3, 0, 0))


func test_a_vacuum_skips_a_stack_another_unit_is_already_after() -> void:
	var spots: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0.3, 0, 0), Vector3(-0.5, 0, 0)]
	var taken: Array[Vector3] = [Vector3(0.32, 0, 0)]
	assert_vector(CoinVacuums.nearest(spots, Vector3.ZERO, taken)).is_equal(Vector3(-0.5, 0, 0))


func test_a_vacuum_finds_nothing_when_every_stack_is_taken_or_the_mat_is_clean() -> void:
	var spots: Array[Vector3] = [Vector3(0.3, 0, 0)]
	var taken: Array[Vector3] = [Vector3(0.3, 0, 0)]
	assert_that(CoinVacuums.nearest(spots, Vector3.ZERO, taken)).is_null()
	assert_that(CoinVacuums.nearest([] as Array[Vector3], Vector3.ZERO)).is_null()


func test_a_vacuum_already_facing_its_goal_does_not_turn() -> void:
	assert_float(CoinVacuums.turn_toward(0.0, Vector3.ZERO, Vector3(0, 0, -1), 0.5)).is_equal_approx(0.0, 0.0001)


func test_a_vacuum_turns_toward_its_goal_by_at_most_one_step() -> void:
	assert_float(CoinVacuums.turn_toward(0.0, Vector3.ZERO, Vector3(1, 0, 0), 0.5)).is_equal_approx(-0.5, 0.0001)
	assert_float(CoinVacuums.turn_toward(-1.4, Vector3.ZERO, Vector3(1, 0, 0), 0.5)).is_equal_approx(-PI / 2.0, 0.0001)


func test_a_vacuum_facing_backwards_turns_the_short_way_round() -> void:
	var goal := Vector3(0, 0, 1).rotated(Vector3.UP, 0.1)
	assert_float(CoinVacuums.turn_toward(PI - 0.1, Vector3.ZERO, goal, 0.5)).is_equal_approx(PI + 0.1, 0.0001)


func test_a_robot_dropped_at_the_window_stays_on_the_desk() -> void:
	# The sale window's sill is at z -0.8; past it units are sold.
	var at := CoinVacuums.on_mat(Vector3(0.7, 0.9, -1.1))
	assert_bool(CoinVacuums.AREA.has_point(Vector2(at.x, at.z))).is_true()
	assert_float(at.z).is_greater(-0.7)


func test_a_robot_set_down_on_the_mat_stays_where_it_was_put() -> void:
	assert_vector(CoinVacuums.on_mat(Vector3(0.4, 0.76, 0.1))).is_equal(Vector3(0.4, 0.76, 0.1))


func test_a_tipped_robot_stops_collecting_until_picked_up() -> void:
	assert_bool(CoinVacuums.collects(CoinVacuums.State.TIPPED, false)).is_false()
	assert_bool(CoinVacuums.collects(CoinVacuums.State.ROAM, true)).is_false()
	var righted := CoinVacuums.set_down(CoinVacuums.State.TIPPED)
	assert_int(righted).is_equal(CoinVacuums.State.ROAM)
	assert_bool(CoinVacuums.collects(righted, false)).is_true()


func test_a_robot_taken_off_its_dock_drives_home_once_set_down() -> void:
	assert_int(CoinVacuums.set_down(CoinVacuums.State.PARKED)).is_equal(CoinVacuums.State.RETURN)


func test_only_a_robot_out_driving_can_tip_over() -> void:
	var save := SaveGame.new()
	assert_bool(CoinVacuums.can_tip(CoinVacuums.State.ROAM, false, save)).is_true()
	assert_bool(CoinVacuums.can_tip(CoinVacuums.State.RETURN, false, save)).is_true()
	assert_bool(CoinVacuums.can_tip(CoinVacuums.State.PARKED, false, save)).is_false()
	assert_bool(CoinVacuums.can_tip(CoinVacuums.State.ROAM, true, save)).is_false()


func test_only_a_robot_lying_on_its_back_asks_for_help() -> void:
	assert_bool(CoinVacuums.asks_for_help(CoinVacuums.State.TIPPED, false)).is_true()
	assert_bool(CoinVacuums.asks_for_help(CoinVacuums.State.TIPPED, true)).is_false()
	assert_bool(CoinVacuums.asks_for_help(CoinVacuums.set_down(CoinVacuums.State.TIPPED), false)).is_false()
	assert_bool(CoinVacuums.asks_for_help(CoinVacuums.State.ROAM, false)).is_false()
	assert_bool(CoinVacuums.asks_for_help(CoinVacuums.State.PARKED, false)).is_false()


func test_the_stabiliser_stops_robots_tipping() -> void:
	var save := SaveGame.new()
	save.tree_bought.append(CoinVacuums.STABILISER)
	assert_bool(CoinVacuums.can_tip(CoinVacuums.State.ROAM, false, save)).is_false()
	assert_bool(CoinVacuums.can_tip(CoinVacuums.State.RETURN, false, save)).is_false()
	assert_that(Projector.node_data(CoinVacuums.STABILISER).get("parent")).is_equal("vacuum_speed_1")


## Drives a unit from `from` to `goal` past units parked at `others`; true once it gets there.
func _arrives(from: Vector3, goal: Vector3, others: Array[Vector3]) -> bool:
	var xf := Transform3D(Basis(), from)
	for i in 4000:
		xf = CoinVacuums.drive_step(xf, goal, others, CoinVacuums.TURN_SPEED / 60.0, CoinVacuums.BASE_SPEED / 60.0)
		for other in others:
			assert_float(Vector2(xf.origin.x - other.x, xf.origin.z - other.z).length()).is_greater_equal(CoinVacuums.RADIUS * 2.0 - 0.001)
		if xf.origin.distance_to(goal) < CoinVacuums.ARRIVE:
			return true
	return false


func test_a_robot_drives_round_a_parked_robot_in_its_way_instead_of_sticking_to_it() -> void:
	# The dock row on the mat's left edge: going home to the last dock past the parked middle unit.
	var parked: Array[Vector3] = [Vector3(-0.254, 0.76, 0.28)]
	assert_bool(_arrives(Vector3(-0.25, 0.76, -0.12), Vector3(-0.254, 0.76, 0.55), parked)).is_true()


func test_a_robot_drives_round_a_robot_dead_ahead() -> void:
	var parked: Array[Vector3] = [Vector3(0.0, 0.76, 0.0)]
	assert_bool(_arrives(Vector3(0.0, 0.76, 0.3), Vector3(0.0, 0.76, -0.3), parked)).is_true()


func test_a_stack_past_a_corner_of_the_mat_out_of_reach_is_not_a_goal() -> void:
	var corner := Vector3(CoinVacuums.AREA.position.x, 0.76, CoinVacuums.AREA.position.y)
	assert_bool(CoinVacuums.reachable(corner + Vector3(-0.05, 0, -0.05), 0.07)).is_false()
	assert_bool(CoinVacuums.reachable(corner + Vector3(-0.05, 0, 0.1), 0.07)).is_true()


func test_a_vacuum_emptying_at_home_only_blips_far_quieter_than_a_tip() -> void:
	var level := SoundCue.level_for(CoinVacuums.UNLOAD_BEEP, 0.0, 1.0)
	assert_float(linear_to_db(level)).is_less_equal(-15.0)


func test_a_robot_comes_home_even_past_a_robot_fallen_next_to_its_dock() -> void:
	var home := Vector3(-0.254, 0.76, 0.28)
	var fallen: Array[Vector3] = [home + Vector3(0.07, 0.0, 0.02)]
	var xf := Transform3D(Basis(), Vector3(0.3, 0.76, -0.2))
	var arrived := false
	for i in 4000:
		xf = CoinVacuums.drive_step(xf, home, fallen, CoinVacuums.TURN_SPEED / 60.0, CoinVacuums.BASE_SPEED / 60.0)
		if xf.origin.distance_to(home) < CoinVacuums.ARRIVE:
			arrived = true
			break
	assert_bool(arrived).is_true()


func test_a_robot_drives_round_one_by_the_mat_edge_on_the_mat_side_never_off_the_mat() -> void:
	var edge := CoinVacuums.AREA.position.x
	var in_the_way: Array[Vector3] = [Vector3(edge + 0.03, 0.76, 0.0)]
	var xf := Transform3D(Basis(), Vector3(edge, 0.76, 0.3))
	var goal := Vector3(edge, 0.76, -0.3)
	var off := 0
	for i in 4000:
		xf = CoinVacuums.drive_step(xf, goal, in_the_way, CoinVacuums.TURN_SPEED / 60.0, CoinVacuums.BASE_SPEED / 60.0)
		if xf.origin != CoinVacuums.on_mat(xf.origin):
			off += 1
		if xf.origin.distance_to(goal) < CoinVacuums.ARRIVE:
			break
	assert_int(off).is_equal(0)
	assert_float(xf.origin.distance_to(goal)).is_less(CoinVacuums.ARRIVE)


func _fleet() -> CoinVacuums:
	var vacuums: CoinVacuums = auto_free(preload("res://entities/vacuum/vacuum.tscn").instantiate())
	add_child(vacuums)
	vacuums.set_physics_process(false)
	vacuums._add_unit()
	return vacuums


func _grip(unit: CoinVacuums.Unit) -> Interactable:
	for child in unit.body.get_children():
		if child is Interactable:
			return child
	return null


func test_a_robot_in_the_hand_collides_with_no_cabbage() -> void:
	var unit := _fleet()._units[0]
	_grip(unit).grabbed.emit()

	assert_int(unit.body.collision_layer & 7).is_equal(0)


func test_a_robot_set_down_on_a_cabbage_stays_soft_until_the_cabbage_is_gone() -> void:
	var vacuums := _fleet()
	var unit := vacuums._units[0]
	var cabbage: Cabbage = preload("res://entities/cabbage/cabbage.tscn").instantiate()
	add_child(cabbage)
	cabbage.freeze = true
	cabbage.global_position = unit.body.global_position + Vector3.UP * 0.05
	await get_tree().physics_frame
	_grip(unit).grabbed.emit()
	_grip(unit).released.emit()

	assert_int(unit.body.collision_layer & 7).is_equal(0)

	cabbage.free()
	await get_tree().physics_frame
	vacuums._settle(unit)

	assert_int(unit.body.collision_layer).is_equal(CoinVacuums.SOLID_LAYER)


func test_with_few_slips_on_the_mat_a_robot_takes_coins_and_slips_alike() -> void:
	assert_int(CoinVacuums.trip_kind(5, 3, 4, false)).is_equal(CoinVacuums.Trip.MIXED)
	assert_int(CoinVacuums.trip_kind(5, 3, 4, true)).is_equal(CoinVacuums.Trip.MIXED)


func test_with_no_coins_on_the_mat_a_robot_takes_slips_as_before() -> void:
	assert_int(CoinVacuums.trip_kind(0, 20, 4, false)).is_equal(CoinVacuums.Trip.MIXED)


func test_with_a_full_bag_of_slips_and_coins_on_the_mat_a_robot_alternates_coin_and_slip_trips() -> void:
	var last := false
	var trips: Array[CoinVacuums.Trip] = []
	for i in 4:
		var trip := CoinVacuums.trip_kind(5, 4, 4, last)
		trips.append(trip)
		last = trip == CoinVacuums.Trip.COINS
	assert_array(trips).is_equal([CoinVacuums.Trip.COINS, CoinVacuums.Trip.SLIPS, CoinVacuums.Trip.COINS, CoinVacuums.Trip.SLIPS])


func test_robots_start_on_different_kinds_so_about_half_the_fleet_is_on_coins() -> void:
	var on_coins := 0
	for i in 6:
		if CoinVacuums.trip_kind(5, 20, 4, CoinVacuums.starts_on_slips(i)) == CoinVacuums.Trip.COINS:
			on_coins += 1
	assert_int(on_coins).is_equal(3)
	assert_bool(CoinVacuums.starts_on_slips(0)).is_not_equal(CoinVacuums.starts_on_slips(1))


func test_a_robot_with_nothing_of_its_kind_on_the_mat_takes_the_other_kind() -> void:
	assert_int(CoinVacuums.trip_goes_on(CoinVacuums.Trip.COINS, 0, 7)).is_equal(CoinVacuums.Trip.SLIPS)
	assert_int(CoinVacuums.trip_goes_on(CoinVacuums.Trip.SLIPS, 3, 0)).is_equal(CoinVacuums.Trip.COINS)
	assert_int(CoinVacuums.trip_goes_on(CoinVacuums.Trip.COINS, 2, 7)).is_equal(CoinVacuums.Trip.COINS)


func test_before_the_token_card_the_robots_still_see_the_coins_on_the_mat() -> void:
	var real := SaveManager.save
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["coin_collector"])
	save.vacuums = 1
	var pile: CoinPile = auto_free(CoinPile.new())
	var coin := CoinPile.Coin.new()
	coin.state = CoinPile.State.RESTING
	pile._stacks[Vector2i(5, 0)] = [coin]
	var vacuums := _fleet()
	vacuums.coins = pile
	vacuums.visible = true
	SaveManager.save = save
	vacuums._physics_process(0.01)
	SaveManager.save = real

	assert_int(vacuums._spots.size()).is_equal(1)
