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


func test_a_payout_uses_the_fifty_and_hundred_dollar_coins_largest_first() -> void:
	assert_array(CoinPile.coin_values(150)).is_equal([50, 100])
	assert_array(CoinPile.coin_values(50)).is_equal([50])
	assert_array(CoinPile.coin_values(99)).is_equal([1, 1, 1, 1, 5, 10, 10, 10, 10, 50])
	assert_array(CoinPile.coin_values(310)).is_equal([10, 100, 100, 100])


func test_up_to_thirty_hundreds_a_payout_comes_in_hundred_dollar_coins() -> void:
	var hundreds := CoinPile.coin_values(3000)
	assert_array(hundreds).has_size(CoinPile.MAX_THROW)
	assert_bool(hundreds.all(func(v: int) -> bool: return v == 100)).is_true()


func test_nothing_or_a_negative_amount_throws_no_coins() -> void:
	assert_array(CoinPile.coin_values(0)).is_empty()
	assert_array(CoinPile.coin_values(-7)).is_empty()


func test_a_payout_past_thirty_hundreds_brings_in_the_next_coin_up_and_so_on_past_ten_thousand() -> void:
	assert_array(CoinPile.coin_values(3100)).is_equal([100, 500, 500, 500, 500, 500, 500])
	var thousands := CoinPile.coin_values(26000)
	assert_array(thousands).has_size(26)
	assert_bool(thousands.all(func(v: int) -> bool: return v == 1000)).is_true()
	var five_k := CoinPile.coin_values(140000)
	assert_array(five_k).has_size(28)
	assert_bool(five_k.all(func(v: int) -> bool: return v == 5000)).is_true()
	assert_bool(CoinPile.coin_values(250000).all(func(v: int) -> bool: return v == 10000)).is_true()
	var big := CoinPile.coin_values(18480)
	assert_int(_sum(big)).is_equal(18480)
	assert_int(big.size()).is_less_equal(CoinPile.MAX_THROW)
	var million := CoinPile.coin_values(1000000)
	assert_array(million).has_size(10)
	assert_bool(million.all(func(v: int) -> bool: return v == 100000)).is_true()


func test_a_payout_always_adds_up_to_its_amount() -> void:
	for amount: int in [1, 9, 10, 49, 50, 99, 150, 301, 4321, 31990, 123456, 2000000000]:
		assert_int(_sum(CoinPile.coin_values(amount))).override_failure_message("payout %d" % amount).is_equal(amount)


func test_each_denomination_looks_different_and_huge_ones_look_like_the_ten_thousand() -> void:
	var colours := CoinPile.DENOMINATIONS.map(func(v: int) -> Color: return CoinPile.coin_colour(v))
	assert_array(colours).is_equal([CoinPile.SILVER, CoinPile.GOLD, CoinPile.BRONZE, CoinPile.STEEL, CoinPile.PLATINUM,
			CoinPile.PEWTER, CoinPile.PALE_GOLD, CoinPile.OXIDE, CoinPile.BLACK_STEEL])
	for i in colours.size():
		assert_int(colours.count(colours[i])).is_equal(1)
	assert_that(CoinPile.coin_colour(100000)).is_equal(CoinPile.BLACK_STEEL)
	for i in CoinPile.DENOMINATIONS.size():
		assert_float(CoinPile.coin_face(CoinPile.DENOMINATIONS[i])).is_equal(float(i))
	assert_float(CoinPile.coin_face(100000)).is_equal(8.0)
	assert_int(CoinPile.COLOURS.size()).is_equal(CoinPile.DENOMINATIONS.size())
	assert_int(CoinPile.SCALES.size()).is_equal(CoinPile.DENOMINATIONS.size())


func test_coins_from_ten_dollars_up_get_thicker_with_their_value() -> void:
	assert_float(CoinPile.thickness(1)).is_equal(CoinPile.THICKNESS)
	assert_float(CoinPile.thickness(5)).is_equal(CoinPile.THICKNESS)
	assert_float(CoinPile.thickness(10)).is_equal_approx(CoinPile.THICKNESS * 1.5, 0.00001)
	assert_float(CoinPile.thickness(50)).is_greater(CoinPile.thickness(10))
	assert_float(CoinPile.thickness(100)).is_greater(CoinPile.thickness(50))
	for i in range(5, CoinPile.DENOMINATIONS.size()):
		assert_float(CoinPile.thickness(CoinPile.DENOMINATIONS[i])).is_greater(CoinPile.thickness(CoinPile.DENOMINATIONS[i - 1]))
		assert_float(CoinPile.SCALES[i].x).is_greater(CoinPile.SCALES[i - 1].x)
	assert_float(CoinPile.thickness(100000)).is_equal(CoinPile.thickness(10000))


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


func test_a_delayed_pop_out_counts_as_pending_before_it_pops() -> void:
	var pile := _pile_with([])
	pile.pop_out_after(60.0, Vector3.ZERO, Vector3.ZERO, 5)
	assert_int(pile.pending_value()).is_equal(5)


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


## How far the game camera's mouse ray moves per metre up (worlds/MainStoryWorld.tscn's Camera3D).
const RISE := Vector3(0.0, 1.0, 0.4826 / 0.8758)


## Where on the desk the mouse ray goes through `seen` (the hand drawn over it).
func _hand_over(seen: Vector3) -> Vector3:
	return seen - RISE * (seen.y - 0.76)


func test_one_sweep_takes_the_coins_stacked_on_top_as_well_as_those_below() -> void:
	var tall: Array[int] = []
	for i in CoinPile.MAX_STACK:
		tall.append(100)
	var pile := _pile_with([[Vector2i(0, 0), tall]])
	var top := Vector3(CoinPile.CELL * 0.5, pile._top(Vector2i(0, 0)), CoinPile.CELL * 0.5)
	var hand := _hand_over(top)
	pile._sweep(hand, hand, RISE)
	assert_dict(pile._stacks).is_empty()
	assert_bool(pile._coins.all(func(c: CoinPile.Coin) -> bool: return c.state == CoinPile.State.HOMING)).is_true()


func test_a_coin_high_on_a_heap_is_under_the_hand_where_it_shows_not_where_its_foot_is() -> void:
	var foot := Vector3(0.0, 0.76, 0.0)
	var high := Vector3(0.0, 0.76 + 0.25, 0.0)
	var over_the_top := _hand_over(high)
	assert_bool(CoinPile.under_hand(over_the_top, over_the_top, RISE, high, high)).is_true()
	assert_bool(CoinPile.under_hand(over_the_top, over_the_top, RISE, foot, foot)).is_false()
	# A whole column counts from its foot up to its top.
	assert_bool(CoinPile.under_hand(over_the_top, over_the_top, RISE, foot, high)).is_true()


func test_a_fast_stroke_takes_the_coins_between_two_frames_hand_points() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1]]])
	var mid := _middle_of_cell_zero()
	pile._sweep(mid + Vector3(-0.2, 0, 0), mid + Vector3(0.2, 0, 0), RISE)
	assert_dict(pile._stacks).is_empty()


func test_coins_clearly_outside_the_hands_footprint_stay_on_the_mat() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1, 1]], [Vector2i(0, 5), [1]], [Vector2i(20, 0), [10]]])
	var mid := _middle_of_cell_zero()
	pile._sweep(mid + Vector3(-0.2, 0, 0), mid + Vector3(0.2, 0, 0), RISE)
	assert_array(pile._stacks.keys()).contains_exactly_in_any_order([Vector2i(0, 5), Vector2i(20, 0)])


func test_a_mouse_jump_too_long_for_a_sweep_starts_a_new_stroke_where_it_lands() -> void:
	var here := Vector3(0.1, 0.76, 0.0)
	assert_vector(CoinPile.stroke_start(null, here)).is_equal(here)
	var near := here + Vector3(CoinPile.MAX_STROKE * 0.5, 0, 0)
	assert_vector(CoinPile.stroke_start(near, here)).is_equal(near)
	assert_vector(CoinPile.stroke_start(here + Vector3(CoinPile.MAX_STROKE * 2.0, 0, 0), here)).is_equal(here)


func test_a_swept_stack_leaves_top_coin_first_so_none_hangs_in_the_air() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 5, 10]]])
	var bottom: CoinPile.Coin = pile._stacks[Vector2i(0, 0)][0]
	var top: CoinPile.Coin = pile._stacks[Vector2i(0, 0)][2]
	var mid := _middle_of_cell_zero()
	pile._sweep(mid, mid, RISE)
	assert_float(top.delay).is_equal(0.0)
	assert_float(bottom.delay).is_greater(top.delay)


## Today's rule, checked the slow way: the cells of every stack under the stroke (CoinPile.under_hand
## against each stack's foot and top).
func _under_stroke(pile: CoinPile, from: Vector3, to: Vector3, rise: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in pile._stacks:
		var at := CoinPile.cell_centre(cell)
		if CoinPile.under_hand(from, to, rise, Vector3(at.x, 0.76, at.y), Vector3(at.x, pile._top(cell), at.y)):
			out.append(cell)
	return out


func test_the_hand_only_looks_at_the_stacks_near_its_stroke_and_takes_the_same_coins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for trial in 300:
		var spots := []
		for n in rng.randi_range(1, 120):
			var values: Array[int] = []
			# A third are full stacks of the thickest coin: their tops show far from their feet.
			var tall := rng.randf() < 0.33
			for i in CoinPile.MAX_STACK if tall else rng.randi_range(1, CoinPile.MAX_STACK):
				values.append(CoinPile.DENOMINATIONS[-1] if tall else CoinPile.DENOMINATIONS.pick_random())
			spots.append([Vector2i(rng.randi_range(-12, 30), rng.randi_range(-15, 8)), values])
		var pile := _pile_with(spots)
		# The game camera's ray, and tilted ones (either side, steeper) so no direction is favoured.
		var rise := RISE if trial % 3 == 0 else Vector3(rng.randf_range(-0.8, 0.8), 1.0, rng.randf_range(-0.8, 0.8))
		var cells: Array = pile._stacks.keys()
		# Half the strokes end over where a stack's top shows (its foot can lie well outside a short
		# stroke's box); the rest anywhere, from still up to the longest (fastest) stroke.
		var cell: Vector2i = cells.pick_random()
		var at := CoinPile.cell_centre(cell)
		var to := Vector3(rng.randf_range(-0.7, 1.7), 0.76, rng.randf_range(-0.9, 0.5))
		if trial % 2 == 0:
			to = Vector3(at.x, 0.76, at.y) - rise * (pile._top(cell) - 0.76) + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		var from := to if trial % 5 == 0 else to + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * rng.randf_range(0.0, CoinPile.MAX_STROKE)
		var expected := _under_stroke(pile, from, to, rise)
		var stacks_before: Array = pile._stacks.keys()
		pile._sweep(from, to, rise)
		var taken := stacks_before.filter(func(c: Vector2i) -> bool: return not pile._stacks.has(c))
		assert_array(taken).override_failure_message("stroke %d: took %s, the full scan takes %s" % [trial, taken, expected]) \
				.contains_exactly_in_any_order(expected)


func test_a_coin_landing_under_a_still_hand_is_taken() -> void:
	var pile := _pile_with([[Vector2i(10, 0), [1]]])
	var mid := _middle_of_cell_zero()
	pile._sweep(mid, mid, RISE)
	pile._sweep(mid, mid, RISE)
	var coin := CoinPile.Coin.new()
	coin.xf.origin = mid
	pile._coins.append(coin)
	pile._land(coin)
	pile._sweep(mid, mid, RISE)
	assert_int(coin.state).is_equal(CoinPile.State.HOMING)
	assert_array(pile._stacks.keys()).contains_exactly([Vector2i(10, 0)])


func test_a_coin_a_robot_has_taken_is_not_also_taken_by_the_hand() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 5, 10]], [Vector2i(3, 0), [50]]])
	var mid := _middle_of_cell_zero()
	assert_that(pile.vacuum_at(mid, 0.07, 10)).is_equal(Vector2i(3, 16))
	pile._sweep(mid + Vector3(-0.1, 0, 0), mid + Vector3(0.3, 0, 0), RISE)
	# The hand gets only the stack the robot left; the robot's bag still counts, once.
	assert_int(pile._coins.size()).is_equal(1)
	assert_int(pile._coins[0].state).is_equal(CoinPile.State.HOMING)
	assert_int(pile.pending_value()).is_equal(66)
	pile.bank_from(Vector3.ZERO, 16)
	assert_int(pile.pending_value()).is_equal(66)


func test_a_stack_the_hand_swept_is_gone_when_a_robot_arrives_for_it() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 5, 10]]])
	var mid := _middle_of_cell_zero()
	pile._sweep(mid, mid, RISE)
	assert_array(pile.resting_spots()).is_empty()
	assert_that(pile.vacuum_at(mid, 0.07, 10)).is_equal(Vector2i.ZERO)
	assert_int(pile.pending_value()).is_equal(16)


func test_a_coin_reaching_the_hopper_leaves_every_other_coin_drawn_where_it_lies() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 5]], [Vector2i(4, 0), [10]], [Vector2i(8, 0), [1, 1]]])
	for i in pile._coins.size():
		pile._coins[i].xf.origin = Vector3(0.1 * i, 0.76, 0.05 * i)
	pile._upload()
	var home: CoinPile.Coin = pile._coins[1]
	home.state = CoinPile.State.HOMING
	home.t = 0.99
	var save := SaveManager.save
	var coins_before := save.coins
	var earned_before := save.coins_earned
	var was_held := Hand.held
	var grip: Interactable = auto_free(Interactable.new())
	Hand.held = grip  # the hand holds something: no sweep, no mouse needed
	pile._process(1.0)
	Hand.held = was_held
	save.coins = coins_before
	save.coins_earned = earned_before
	assert_bool(pile._coins.has(home)).is_false()
	assert_int(pile.multimesh.visible_instance_count).is_equal(4)
	for i in pile._coins.size():
		var o := i * CoinPile.FLOATS
		assert_vector(Vector3(pile._buffer[o + 3], pile._buffer[o + 7], pile._buffer[o + 11])) \
				.is_equal_approx(pile._coins[i].xf.origin, Vector3.ONE * 0.0001)


func test_a_big_haul_swept_at_once_has_all_left_within_the_spread() -> void:
	assert_float(CoinPile.home_delay(2, 3)).is_equal_approx(2 * CoinPile.HOME_STAGGER, 0.0001)
	assert_float(CoinPile.home_delay(199, 200)).is_less_equal(CoinPile.HOME_SPREAD)


func test_banked_coins_count_towards_the_coins_ever_earned_and_spending_never_lowers_it() -> void:
	var save := SaveGame.new()
	CoinPile.bank(save, 12)
	save.coins -= 10
	CoinPile.bank(save, 5)
	assert_int(save.coins).is_equal(7)
	assert_int(save.coins_earned).is_equal(17)


func test_banked_coins_never_pass_the_cash_limit_and_only_what_fits_counts_as_earned() -> void:
	var save := SaveGame.new()
	save.coins = save.coin_limit - 3
	CoinPile.bank(save, 12)
	assert_int(save.coins).is_equal(save.coin_limit)
	assert_int(save.coins_earned).is_equal(3)


func test_a_sale_at_the_limit_pays_nothing_more() -> void:
	assert_int(CoinPile.fitting(22, 0, 0)).is_equal(0)
	# The coins already out (on the mat, in the air, in a robot's bag) take up the room too.
	assert_int(CoinPile.fitting(22, 500, 500)).is_equal(0)
	assert_int(CoinPile.fitting(22, 500, 900)).is_equal(0)


func test_a_payout_brings_in_only_what_still_fits_under_the_limit() -> void:
	assert_int(CoinPile.fitting(22, 40000, 0)).is_equal(22)
	assert_int(CoinPile.fitting(22, 10, 0)).is_equal(10)
	assert_int(CoinPile.fitting(22, 30, 20)).is_equal(10)


func test_a_payout_at_a_full_purse_throws_no_coin_onto_the_mat_and_says_so() -> void:
	var real := SaveManager.save
	var save := SaveGame.new()
	save.coins = save.coin_limit
	SaveManager.save = save
	var pile: CoinPile = auto_free(CoinPile.new())
	pile.multimesh = MultiMesh.new()
	add_child(pile)
	pile.set_process(false)
	var refusals := [0]
	pile.refused.connect(func(_at: Vector3) -> void: refusals[0] += 1)
	pile.throw_in(Vector3(0.3, 0.4, -1.1), 500)
	assert_int(pile.pending_value()).is_equal(0)
	assert_int(refusals[0]).is_equal(1)
	# The one coin shown is the street keeping it: worth nothing, never landing.
	assert_int(pile._coins.size()).is_equal(1)
	assert_bool(pile._coins[0].lost).is_true()
	save.coins -= 300  # Room for 300 of the next 500.
	pile.throw_in(Vector3(0.3, 0.4, -1.1), 500)
	assert_int(pile.pending_value()).is_equal(300)
	assert_int(refusals[0]).is_equal(2)
	SaveManager.save = real


func test_a_big_payout_comes_as_a_handful_of_high_coins_not_hundreds_of_small_ones_or_one_lonely_coin() -> void:
	for amount: int in [950, 3000, 4200, 10000, 26000, 140000, 999999, 5000000]:
		var values := CoinPile.coin_values(amount)
		assert_int(_sum(values)).override_failure_message("payout %d" % amount).is_equal(amount)
		assert_int(values.size()).override_failure_message("payout %d" % amount).is_between(5, CoinPile.MAX_THROW + 14)
	assert_bool(CoinPile.coin_values(10000).all(func(v: int) -> bool: return v == 500)).is_true()
	assert_int(CoinPile.coin_values(140000).max()).is_equal(5000)


func test_a_full_stack_sends_the_next_coin_to_the_nearest_stack_with_room_inside_the_pile_area() -> void:
	var full := []
	full.resize(CoinPile.MAX_STACK)
	# The aimed stack sits in the corner of the area: only the stack beside it, further in, is free.
	var stacks := {Vector2i(0, 0): full}
	for i in 30:
		assert_that(CoinPile.stack_cell(stacks, Vector2i(0, 0), CoinPile.MAX_STACK, Rect2i(0, 0, 3, 1))).is_equal(Vector2i(1, 0))
	stacks[Vector2i(1, 0)] = full
	assert_that(CoinPile.stack_cell(stacks, Vector2i(0, 0), CoinPile.MAX_STACK, Rect2i(0, 0, 3, 1))).is_equal(Vector2i(2, 0))


func test_no_coin_comes_to_rest_above_the_reach_height_however_many_land_on_one_spot() -> void:
	var pile := _pile_with([])
	var spot := CoinPile.cell_of(pile.landing_area.position)
	for i in 400:
		var coin := CoinPile.Coin.new()
		coin.value = 10000 if i % 2 == 0 else 1
		coin.cell = spot
		pile._coins.append(coin)
		pile._land(coin)
	assert_int(pile._stacks.size()).is_greater_equal(40)
	for coin in pile._coins:
		var top := coin.to.origin.y + CoinPile.thickness(coin.value) * 0.5 - pile.desk_height
		assert_float(top).is_less_equal(CoinPile.reach_height() + 0.0001)
		assert_bool(pile._pile_cells().has_point(CoinPile.cell_of(coin.to.origin))).is_true()


func test_no_coin_lands_on_the_desk_the_lab_stands_on_and_drops_its_slips_on() -> void:
	var closed := Rect2i(0, 0, 4, 4)
	for i in 30:
		var cell := CoinPile.stack_cell({}, Vector2i(1, 1), CoinPile.MAX_STACK, Rect2i(-8, -8, 20, 20), closed)
		assert_bool(closed.has_point(cell)).is_false()


func test_coins_past_the_most_the_desk_holds_are_held_back_and_none_is_lost() -> void:
	var saved := SaveManager.save
	SaveManager.save = SaveGame.new()
	var pile := _pile_with([])
	for i in CoinPile.MAX_ON_DESK - 2:
		pile._coins.append(CoinPile.Coin.new())
	var lying := pile.pending_value()
	pile.throw_in(Vector3.ZERO, 4)  # four $1 coins, room for two
	assert_int(pile._coins.size()).is_equal(CoinPile.MAX_ON_DESK)
	assert_int(pile._withheld).is_equal(2)
	assert_int(pile.pending_value()).is_equal(lying + 4)
	# Still full: the next payout stays out whole, and waiting only shows a coin worth nothing at the gap.
	pile.throw_in(Vector3.ZERO, 30)
	pile._release(CoinPile.KNOCK)
	assert_int(pile._withheld).is_equal(32)
	assert_int(pile.pending_value()).is_equal(lying + 34)
	SaveManager.save = saved


func test_held_back_coins_come_in_as_the_fewest_coins_once_some_are_picked_up() -> void:
	var saved := SaveManager.save
	SaveManager.save = SaveGame.new()
	var pile := _pile_with([])
	pile._withheld = 32
	pile._release(CoinPile.KNOCK)
	assert_int(pile._withheld).is_equal(0)
	assert_array(pile._coins.map(func(c: CoinPile.Coin) -> int: return c.value)).contains_exactly_in_any_order([1, 1, 10, 10, 10])
	assert_int(pile.pending_value()).is_equal(32)
	SaveManager.save = saved


func test_five_one_dollar_coins_or_two_fives_merge_into_the_next_coin_up_and_the_smallest_go_first() -> void:
	var ones: Array[int] = [1, 5, 1, 1, 5, 1, 1]
	assert_array(CoinPile.merge_pick(ones, 100)).is_equal([0, 2, 3, 5, 6])
	var fives: Array[int] = [1, 5, 10, 5]
	assert_array(CoinPile.merge_pick(fives, 100)).is_equal([1, 3])
	var few: Array[int] = [1, 1, 1, 1, 10]
	assert_array(CoinPile.merge_pick(few, 100)).is_empty()  # Four $1 make no $5.


func test_no_merge_makes_a_coin_above_the_highest_allowed() -> void:
	var hundreds: Array[int] = [100, 100, 100, 100, 100]
	assert_array(CoinPile.merge_pick(hundreds, 100)).is_empty()
	assert_array(CoinPile.merge_pick(hundreds, 500)).has_size(5)
	var tens_k: Array[int] = [10000, 10000]
	assert_array(CoinPile.merge_pick(tens_k, 10000)).is_empty()  # Nothing past the $10K coin.


func test_a_merge_flies_the_coins_together_and_the_first_pops_up_as_the_next_coin_worth_them_all() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1, 1]], [Vector2i(3, 0), [1, 1, 10]]])
	assert_bool(pile.merge_once(100)).is_true()
	assert_int(pile.pending_value()).is_equal(15)  # Nothing is lost or made while they fly.
	var merging := pile._coins.filter(func(c: CoinPile.Coin) -> bool: return c.state == CoinPile.State.MERGING)
	assert_array(merging).has_size(5)
	assert_array(merging.filter(func(c: CoinPile.Coin) -> bool: return c.merged == 5)).has_size(1)
	assert_array(pile._stacks[Vector2i(3, 0)]).has_size(1)  # The $10 is left, dropped onto the desk.
	assert_bool(pile._stacks.has(Vector2i(0, 0))).is_false()
	for coin: CoinPile.Coin in merging:
		var first := coin.merged > 0
		assert_bool(pile._merge_step(coin, CoinPile.MERGE_SHAKE)).is_false()  # The wobble first.
		assert_bool(pile._merge_step(coin, CoinPile.MERGE_TIME)).is_true()
		if first:
			assert_int(coin.value).is_equal(5)
			assert_int(coin.state).is_equal(CoinPile.State.FLYING)
			assert_float(coin.velocity.y).is_greater(0.0)  # It hops up.
		else:
			pile._coins.erase(coin)
	assert_int(pile.pending_value()).is_equal(15)
	assert_bool(pile.merge_once(100)).is_false()  # One $5 and one $10: nothing more to merge.


func test_merging_coins_wobble_once_in_place_about_three_millimetres_before_they_fly() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1, 1, 1, 1]]])
	pile.merge_once(100)
	var coin: CoinPile.Coin = pile._coins[2]
	var rest := coin.from.origin
	pile._merge_step(coin, CoinPile.MERGE_SHAKE * 0.25)
	assert_float(coin.xf.origin.x - rest.x).is_equal_approx(0.003, 0.0002)  # Out to one side,
	pile._merge_step(coin, CoinPile.MERGE_SHAKE * 0.5)
	assert_float(coin.xf.origin.x - rest.x).is_equal_approx(-0.003, 0.0002)  # the other,
	assert_bool(pile._merge_step(coin, CoinPile.MERGE_SHAKE * 0.25)).is_false()
	assert_vector(coin.xf.origin).is_equal_approx(rest, Vector3.ONE * 0.0001)  # and back, once.
	assert_float(coin.t).is_equal(0.0)  # Only now does the flight start.
	assert_float(CoinPile.MERGE_SHAKE).is_between(0.15, 0.25)  # a slow wobble, not a buzz


func test_a_merged_coin_jumps_once_and_lands_without_a_bounce() -> void:
	var pile := _pile_with([[Vector2i(0, 0), [1, 1, 1, 1, 1]]])
	pile.merge_once(100)
	var first: CoinPile.Coin = pile._coins.filter(func(c: CoinPile.Coin) -> bool: return c.merged > 0)[0]
	pile._merge_step(first, CoinPile.MERGE_SHAKE)
	pile._merge_step(first, CoinPile.MERGE_TIME)
	var bounces := [0]
	pile.bounced.connect(func(_at: Vector3) -> void: bounces[0] += 1)
	for _frame in 120:
		if first.state != CoinPile.State.FLYING:
			break
		pile._fly(first, 1.0 / 60.0)
	assert_int(first.state).is_equal(CoinPile.State.SETTLING)  # Down on the desk,
	assert_int(bounces[0]).is_equal(0)  # after the one hop and no bounce.


func test_bulk_discharge_sends_a_whole_bag_off_within_a_third_of_a_second_not_one_coin_at_a_time() -> void:
	assert_float(CoinPile.bag_delay(49, 50, false)).is_greater(1.0)  # Trickled: about 1.5 s.
	assert_float(CoinPile.bag_delay(49, 50, true)).is_less_equal(0.3)
	assert_float(CoinPile.bag_delay(2, 3, true)).is_equal_approx(CoinPile.bag_delay(2, 3, false), 0.0001)  # A small bag is no slower.


func test_a_merged_coin_swells_at_the_top_of_its_hop_and_is_its_own_size_before_and_after() -> void:
	assert_float(CoinPile.pop_scale(CoinPile.MERGE_POP)).is_equal_approx(1.0, 0.001)
	assert_float(CoinPile.pop_scale(CoinPile.MERGE_POP * 0.5)).is_equal_approx(1.0 + CoinPile.MERGE_SWELL, 0.001)
	assert_float(CoinPile.pop_scale(0.0)).is_equal(1.0)
