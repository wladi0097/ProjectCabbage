extends GdUnitTestSuite

var _pending_coins: Callable


func before_test() -> void:
	_pending_coins = SaveManager.pending_coins


func after_test() -> void:
	SaveManager.pending_coins = _pending_coins


func _sum(values: Array[int]) -> int:
	return values.reduce(func(a: int, b: int) -> int: return a + b, 0)


## A pile that doesn't run, with resting stacks of the given values: [[cell, [values]], ...].
func _pile_with(spots: Array) -> CoinPile:
	var pile: CoinPile = auto_free(CoinPile.new())
	pile.multimesh = MultiMesh.new()
	pile.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(pile)
	for spot: Array in spots:
		var stack := []
		for value: int in spot[1]:
			var coin := CoinPile.Coin.new()
			coin.state = CoinPile.State.RESTING
			coin.value = value
			stack.append(coin)
			pile._coins.append(coin)
		pile._stacks[spot[0]] = stack
	return pile


func _middle_of_cell_zero() -> Vector3:
	return Vector3(CoinPile.CELL * 0.5, 0.76, CoinPile.CELL * 0.5)


func test_a_payout_is_the_fewest_coins_with_the_biggest_thrown_last_onto_the_top() -> void:
	assert_array(CoinPile.coin_values(4)).is_equal([1, 1, 1, 1])
	assert_array(CoinPile.coin_values(5)).is_equal([5])
	assert_array(CoinPile.coin_values(17)).is_equal([1, 1, 5, 10])
	assert_array(CoinPile.coin_values(23)).is_equal([1, 1, 1, 10, 10])


func test_up_to_thirty_tens_a_payout_comes_in_ten_dollar_coins() -> void:
	var tens := CoinPile.coin_values(300)
	assert_array(tens).has_size(CoinPile.MAX_THROW)
	assert_bool(tens.all(func(v: int) -> bool: return v == 10)).is_true()


func test_nothing_or_a_negative_amount_throws_no_coins() -> void:
	assert_array(CoinPile.coin_values(0)).is_empty()
	assert_array(CoinPile.coin_values(-7)).is_empty()


func test_a_payout_past_thirty_tens_comes_in_bronze_worth_a_hundred_and_more() -> void:
	assert_array(CoinPile.coin_values(310)).is_equal([10, 100, 100, 100])
	var big := CoinPile.coin_values(1848)
	assert_int(_sum(big)).is_equal(1848)
	assert_int(big.size()).is_less_equal(CoinPile.MAX_THROW)
	var million := CoinPile.coin_values(1000000)
	assert_array(million).has_size(10)
	assert_bool(million.all(func(v: int) -> bool: return v == 100000)).is_true()


func test_a_payout_always_adds_up_to_its_amount() -> void:
	for amount: int in [1, 9, 10, 99, 301, 4321, 31990, 123456, 2000000000]:
		assert_int(_sum(CoinPile.coin_values(amount))).override_failure_message("payout %d" % amount).is_equal(amount)


func test_each_denomination_looks_different_and_big_ones_look_like_the_ten() -> void:
	assert_that(CoinPile.coin_colour(1)).is_equal(CoinPile.SILVER)
	assert_that(CoinPile.coin_colour(5)).is_equal(CoinPile.GOLD)
	assert_that(CoinPile.coin_colour(10)).is_equal(CoinPile.BRONZE)
	assert_that(CoinPile.coin_colour(1000)).is_equal(CoinPile.BRONZE)
	assert_float(CoinPile.coin_face(1)).is_equal(0.0)
	assert_float(CoinPile.coin_face(5)).is_equal(1.0)
	assert_float(CoinPile.coin_face(10)).is_equal(2.0)
	assert_float(CoinPile.coin_face(100)).is_equal(2.0)


func test_only_ten_dollar_and_bigger_coins_are_thick() -> void:
	assert_float(CoinPile.thickness(1)).is_equal(CoinPile.THICKNESS)
	assert_float(CoinPile.thickness(5)).is_equal(CoinPile.THICKNESS)
	assert_float(CoinPile.thickness(10)).is_equal_approx(CoinPile.THICKNESS * 1.5, 0.00001)
	assert_float(CoinPile.thickness(100)).is_equal(CoinPile.thickness(10))


func test_a_point_falls_in_the_grid_cell_whose_centre_is_within_half_a_cell() -> void:
	assert_that(CoinPile.cell_of(Vector3(-0.01, 0.76, 0.06))).is_equal(Vector2i(-1, 1))
	for point: Vector3 in [Vector3(0.0, 0, 0.0), Vector3(-0.31, 0, 0.47), Vector3(1.2, 0, -0.55)]:
		var centre := CoinPile.cell_centre(CoinPile.cell_of(point))
		assert_float(absf(centre.x - point.x)).is_less_equal(CoinPile.CELL * 0.5 + 0.0001)
		assert_float(absf(centre.y - point.z)).is_less_equal(CoinPile.CELL * 0.5 + 0.0001)


func test_a_payout_stacks_on_its_spot_up_to_ten_high_then_spills_right_beside_it() -> void:
	var stacks := {}
	for i in 25:
		stacks.get_or_add(CoinPile.stack_cell(stacks, Vector2i.ZERO, CoinPile.MAX_STACK), []).append(i)
	assert_int(stacks[Vector2i.ZERO].size()).is_equal(CoinPile.MAX_STACK)
	for cell: Vector2i in stacks:
		assert_int(stacks[cell].size()).is_less_equal(CoinPile.MAX_STACK)
		assert_int(maxi(absi(cell.x), absi(cell.y))).is_less_equal(1)


func test_a_coin_lands_on_its_aimed_cell_when_the_mat_around_it_is_full() -> void:
	var full := []
	full.resize(CoinPile.MAX_STACK)
	var stacks := {}
	for dx in range(-7, 8):
		for dz in range(-7, 8):
			stacks[Vector2i(dx, dz)] = full
	assert_that(CoinPile.stack_cell(stacks, Vector2i.ZERO, CoinPile.MAX_STACK)).is_equal(Vector2i.ZERO)


func test_a_thrown_coin_reaches_its_target_in_the_given_time() -> void:
	var from := Vector3(2, 1, 1)
	var to := Vector3(1, 0.8, 0)
	var v := CoinPile.ballistic(from, to, 0.7)
	var landed := from + v * 0.7 + 0.5 * Vector3.DOWN * CoinPile.GRAVITY * 0.49
	assert_vector(landed).is_equal_approx(to, Vector3.ONE * 0.0001)


func test_a_collected_coin_flies_from_where_it_lay_and_drops_straight_into_the_hopper() -> void:
	var start := Vector3(1, 0.76, 0)
	var hopper := Vector3(-0.7, 1.07, -0.67)
	assert_vector(CoinPile.home_point(start, hopper, 0.0)).is_equal_approx(start, Vector3.ONE * 0.0001)
	assert_vector(CoinPile.home_point(start, hopper, 1.0)).is_equal_approx(hopper, Vector3.ONE * 0.0001)
	var near := CoinPile.home_point(start, hopper, 0.95)
	assert_float(near.y).is_greater(hopper.y)
	assert_float(Vector2(near.x - hopper.x, near.z - hopper.z).length()).is_less(near.y - hopper.y)


func test_a_vacuum_takes_resting_coins_in_reach_up_to_its_room_top_coin_first() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1, 10]], [Vector2i(1, 0), [1, 1]], [Vector2i(20, 0), [10]]])
	assert_int(pile.pending_value()).is_equal(24)
	assert_int(pile.resting_spots().size()).is_equal(3)
	assert_that(pile.vacuum_at(_middle_of_cell_zero(), 0.07, 4)).is_equal(Vector2i(4, 13))
	assert_int(pile._coins.size()).is_equal(2)
	assert_bool(pile._coins.has(pile._stacks[Vector2i(1, 0)][0])).is_true()
	assert_bool(pile._coins.has(pile._stacks[Vector2i(20, 0)][0])).is_true()
	assert_that(pile.vacuum_at(_middle_of_cell_zero(), 0.07, 10)).is_equal(Vector2i(1, 1))


func test_a_vacuum_leaves_stacks_that_are_still_settling() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 5]]])
	pile._coins[1].state = CoinPile.State.SETTLING
	assert_that(pile.vacuum_at(_middle_of_cell_zero(), 0.07, 10)).is_equal(Vector2i.ZERO)
	assert_array(pile.resting_spots()).is_empty()


func test_vacuumed_coins_stay_pending_until_banked_and_fly_home_as_new_coins() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1, 1, 10]]])
	pile.vacuum_at(_middle_of_cell_zero(), 0.07, 10)
	assert_int(pile.pending_value()).is_equal(13)
	assert_array(pile._coins).is_empty()
	pile.bank_from(Vector3.ZERO, 13)
	assert_int(pile._held).is_equal(0)
	assert_int(pile.pending_value()).is_equal(13)
	assert_array(pile._coins).has_size(CoinPile.coin_values(13).size())


func test_a_vacuum_cannot_bank_more_than_it_holds() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [5]]])
	pile.vacuum_at(_middle_of_cell_zero(), 0.07, 10)
	pile.bank_from(Vector3.ZERO, 100)
	assert_int(pile.pending_value()).is_equal(5)


func test_a_delayed_payout_counts_as_pending_before_and_after_it_is_thrown() -> void:
	var pile := _pile_with([])
	pile.throw_in_after(60.0, Vector3.ZERO, 7)
	assert_int(pile.pending_value()).is_equal(7)
	pile._throw_scheduled(Vector3.ZERO, 7)
	assert_int(pile._scheduled).is_equal(0)
	assert_int(pile.pending_value()).is_equal(7)


func test_the_autosave_counts_the_coins_still_on_the_mat() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [10, 5]]])
	assert_int(SaveManager.pending_coins.call()).is_equal(15)
	assert_int(pile.pending_value()).is_equal(15)


func test_the_coin_buffer_grows_in_chunks_and_rewrites_a_resting_coin_that_changed_slot() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1]], [Vector2i(5, 0), [10]]])
	pile._upload()
	assert_int(pile.multimesh.instance_count).is_equal(CoinPile.CHUNK)
	assert_int(pile.multimesh.visible_instance_count).is_equal(2)
	var moved: CoinPile.Coin = pile._coins[0]
	moved.xf.origin = Vector3(0.3, 0.76, 0.2)
	pile._coins.push_back(pile._coins.pop_front())
	pile._upload()
	var o := CoinPile.FLOATS
	assert_vector(Vector3(pile._buffer[o + 3], pile._buffer[o + 7], pile._buffer[o + 11])) \
			.is_equal_approx(moved.xf.origin, Vector3.ONE * 0.0001)
