extends GdUnitTestSuite


func test_a_cabbage_on_the_mat_is_not_stray() -> void:
	assert_bool(SaleWindow.is_stray(Vector3(0.5, 0.85, 0.3))).is_false()


func test_a_cabbage_off_the_mat_or_hidden_behind_the_press_is_stray() -> void:
	assert_bool(SaleWindow.is_stray(Vector3(-1.2, 0.85, 0.3))).is_true()
	assert_bool(SaleWindow.is_stray(Vector3(0.5, 0.87, 1.4))).is_true()
	assert_bool(SaleWindow.is_stray(Vector3(1.7, 0.85, -0.6))).is_true()


func test_a_cabbage_resting_against_the_bottom_or_left_screen_bar_is_not_stray() -> void:
	# ScreenBottom at z 1.22 minus a 0.12 radius; LeftBar at x -0.564 plus 0.1.
	assert_bool(SaleWindow.is_stray(Vector3(0.2, 0.87, 1.11))).is_false()
	assert_bool(SaleWindow.is_stray(Vector3(-0.46, 0.87, 0.3))).is_false()


func test_the_qa_bay_takes_the_gaps_left_third_and_the_zone_keeps_its_right_edge() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	var zone := CollisionShape3D.new()
	zone.name = "Zone"
	var box := BoxShape3D.new()
	box.size = Vector3(2.12, 0.3, 0.58)
	zone.shape = box
	zone.position.x = 0.7
	window.add_child(zone)

	window.split()
	window.split()

	var width := (zone.shape as BoxShape3D).size.x
	assert_float(zone.position.x - width / 2.0).is_equal_approx(SaleWindow.SPLIT_X, 0.0001)
	assert_float(zone.position.x + width / 2.0).is_equal_approx(1.76, 0.0001)
	assert_float(window.sell_span().x).is_equal_approx(SaleWindow.SPLIT_X, 0.0001)
	assert_float(box.size.x).is_equal_approx(2.12, 0.0001)


func test_a_sale_pays_the_chalked_price_times_every_boost() -> void:
	assert_int(SaleWindow.payout(4, {})).is_equal(4)
	assert_int(SaleWindow.payout(4, {lamp = 5.0, combo = 1.5})).is_equal(30)


func test_a_sale_never_pays_less_than_one_coin() -> void:
	assert_int(SaleWindow.payout(1, {x = 0.1})).is_equal(1)
	assert_int(SaleWindow.payout(0.25, {})).is_equal(1)


func test_a_mini_pays_its_share_of_the_chalked_price() -> void:
	assert_int(SaleWindow.payout(8 * SaveGame.new().mini_value, {})).is_equal(2)


func test_selling_a_rotten_unit_costs_ten_times_the_price_but_never_more_than_the_tally() -> void:
	assert_int(SaleWindow.fine_for(4, 100)).is_equal(40)
	assert_int(SaleWindow.fine_for(4, 25)).is_equal(25)
	assert_int(SaleWindow.fine_for(4, 0)).is_equal(0)


func test_the_street_buys_exactly_its_acceptance_share_without_unlucky_streaks() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	window._owed = 0.0
	var bought: Array[bool] = []
	for i in 8:
		bought.append(window._buys(0.25))
	assert_array(bought).is_equal([false, false, false, true, false, false, false, true])


func test_a_sure_sale_always_sells_and_a_hopeless_price_never_does() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	window._owed = 0.0
	for i in 5:
		assert_bool(window._buys(1.0)).is_true()
	for i in 5:
		assert_bool(window._buys(0.0)).is_false()


func test_a_mini_is_accepted_35_percent_more_often_than_a_full_cabbage() -> void:
	assert_float(SaleWindow.acceptance_for(0.4, false)).is_equal_approx(0.4, 0.0001)
	assert_float(SaleWindow.acceptance_for(0.4, true)).is_equal_approx(0.54, 0.0001)


func test_a_minis_acceptance_never_goes_past_a_sure_sale() -> void:
	assert_float(SaleWindow.acceptance_for(0.9, true)).is_equal(1.0)


func test_a_golden_unit_sells_for_golden_sale_times_the_price() -> void:
	var save := SaveGame.new()
	assert_float(SaleWindow.golden_factor(true, save)).is_equal(10.0)
	assert_float(SaleWindow.golden_factor(false, save)).is_equal(1.0)
	assert_int(SaleWindow.payout(4 * SaleWindow.golden_factor(true, save), {})).is_equal(40)


func test_a_sale_counts_as_the_hands_when_a_hired_hand_lobbed_it_last_else_as_the_players() -> void:
	var save := SaveGame.new()
	SaleWindow.count_seller(save, true)
	SaleWindow.count_seller(save, false)
	SaleWindow.count_seller(save, false)
	assert_int(save.hand_sold).is_equal(1)
	assert_int(save.player_sold).is_equal(2)


func test_managerial_work_pays_only_on_cabbages_the_player_sold_themself() -> void:
	var save := SaveGame.new()
	assert_float(SaleWindow.own_factor(true, save)).is_equal(1.0)  # Before the card: no bonus.
	UpgradeDesk.apply("own_sales", save)
	assert_float(SaleWindow.own_factor(true, save)).is_equal_approx(1.2, 0.0001)
	assert_float(SaleWindow.own_factor(false, save)).is_equal(1.0)


func test_managerial_work_multiplies_with_gold_and_every_boost() -> void:
	var save := SaveGame.new()
	save.own_sale = 1.5
	save.tree_bought.append(SaleWindow.GOLD_AGE)
	var price := 4 * SaleWindow.golden_factor(true, save) * SaleWindow.own_factor(true, save)
	assert_int(SaleWindow.payout(price, SaleWindow.boosts_for(true, {combo = 2.0, lamp = 5.0}, save))).is_equal(600)  # 4 × 10 × 1.5 × 2 × 5


func test_a_golden_cabbage_sold_in_the_golden_age_pays_no_more_than_outside_it() -> void:
	var save := SaveGame.new()
	var price := 4 * SaleWindow.golden_factor(true, save)
	var outside := SaleWindow.payout(price, SaleWindow.boosts_for(true, {}, save))
	assert_int(SaleWindow.payout(price, SaleWindow.boosts_for(true, {lamp = 5.0}, save))).is_equal(outside)
	assert_int(outside).is_equal(40)  # It keeps its own premium.


func test_a_golden_cabbage_still_gets_every_other_boost_in_the_golden_age() -> void:
	var save := SaveGame.new()
	var price := 4 * SaleWindow.golden_factor(true, save)
	assert_int(SaleWindow.payout(price, SaleWindow.boosts_for(true, {lamp = 5.0, combo = 1.5}, save))).is_equal(60)


func test_an_ordinary_cabbage_still_gets_the_golden_ages_bonus() -> void:
	var save := SaveGame.new()
	assert_int(SaleWindow.payout(4, SaleWindow.boosts_for(false, {lamp = 5.0}, save))).is_equal(20)


func test_with_gold_standard_the_golden_age_covers_golden_cabbages_too() -> void:
	var save := SaveGame.new()
	save.tree_bought.append(SaleWindow.GOLD_AGE)
	var price := 4 * SaleWindow.golden_factor(true, save)
	assert_int(SaleWindow.payout(price, SaleWindow.boosts_for(true, {lamp = 5.0}, save))).is_equal(200)


func test_leaving_a_golden_cabbage_out_of_the_golden_age_does_not_end_it_for_the_rest() -> void:
	var boosts := {lamp = 5.0}
	SaleWindow.boosts_for(true, boosts, SaveGame.new())
	assert_dict(boosts).is_equal({lamp = 5.0})


## Records what the street is asked to throw back for a sale.
class FakeCoins extends CoinPile:
	var paid: Array[int] = []

	func throw_in_after(_delay: float, _origin: Vector3, amount: int) -> void:
		paid.append(amount)


## A golden cabbage the player throws out of a window in the golden age ($1 chalked: a sure
## sale; lamp ×5, golden ×10), judged through the window's own sale path: the coins the street throws back.
func _golden_sale_in_the_golden_age(gold_standard: bool) -> int:
	var real := SaveManager.save
	var save := SaveGame.new()
	save.sale_price = 1
	save.golden_sale = 10.0
	if gold_standard:
		save.tree_bought.append(SaleWindow.GOLD_AGE)
	SaveManager.save = save
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var window := SaleWindow.new()
	var coins: FakeCoins = auto_free(FakeCoins.new())
	window.coins = coins
	for cue: String in ["Suck", "Refuse"]:
		var player: AudioStreamPlayer3D = preload("res://entities/components/sound_cue.gd").new()
		player.name = cue
		window.add_child(player)
	holder.add_child(window)
	window.boosts = {lamp = 5.0}
	window._owed = 1.0  # The street buys this one.
	var cabbage: Cabbage = preload("res://entities/cabbage/cabbage.tscn").instantiate()
	cabbage.golden = true
	holder.add_child(cabbage)
	window._judge(cabbage)
	SaveManager.save = real
	return coins.paid[0] if coins.paid.size() == 1 else -1


func test_a_golden_cabbage_thrown_out_of_the_window_in_the_golden_age_is_paid_without_the_golden_ages_bonus() -> void:
	assert_int(_golden_sale_in_the_golden_age(false)).is_equal(10)  # $1 × 10, no lamp


func test_a_golden_cabbage_thrown_out_of_the_window_in_the_golden_age_is_paid_with_it_once_gold_standard_is_bought() -> void:
	assert_int(_golden_sale_in_the_golden_age(true)).is_equal(50)  # $1 × 10 × 5



## A cabbage holding `units` (golden or not), sold at $3 through the window's own sale path with
## 10 in stock (4 of them golden): [coins thrown back, the save after].
func _condensed_sale(units: int, golden := false) -> Array:
	var real := SaveManager.save
	var save := SaveGame.new()
	save.sale_price = 3
	save.stock = 10
	save.golden_stock = 4
	SaveManager.save = save
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var window := SaleWindow.new()
	var coins: FakeCoins = auto_free(FakeCoins.new())
	window.coins = coins
	for cue: String in ["Suck", "Refuse"]:
		var player: AudioStreamPlayer3D = preload("res://entities/components/sound_cue.gd").new()
		player.name = cue
		window.add_child(player)
	holder.add_child(window)
	window._owed = 1.0  # The street buys this one.
	var cabbage: Cabbage = preload("res://entities/cabbage/cabbage.tscn").instantiate()
	cabbage.units = units
	cabbage.golden = golden
	holder.add_child(cabbage)
	window._judge(cabbage)
	SaveManager.save = real
	return [coins.paid[0] if coins.paid.size() == 1 else -1, save]


## Every engine error while it is added (OS.add_logger): gdUnit doesn't report those.
class ErrorLog extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append(code + " " + rationale)


func test_a_refused_cabbage_freed_while_away_leaves_nothing_behind_that_runs_on_it() -> void:
	var window: SaleWindow = auto_free(SaleWindow.new())
	add_child(window)
	var cabbage: Cabbage = preload("res://entities/cabbage/cabbage.tscn").instantiate()
	add_child(cabbage)
	window._send_back(cabbage, 0.1, true)
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	cabbage.free()

	await get_tree().create_timer(0.3).timeout
	OS.remove_logger(errors)

	assert_array(errors.errors.filter(func(e: String) -> bool: return e.contains("Lambda"))).is_empty()


func test_a_condensed_cabbage_sells_as_two_cabbages_two_sold_two_paid_two_off_the_stock() -> void:
	var sale := _condensed_sale(2)
	var save: SaveGame = sale[1]
	assert_int(sale[0]).is_equal(6)  # 2 × $3
	assert_int(save.sold).is_equal(2)
	assert_int(save.player_sold).is_equal(2)
	assert_int(save.stock).is_equal(8)
	assert_int(save.golden_stock).is_equal(4)


func test_a_plain_cabbage_still_sells_as_one() -> void:
	var sale := _condensed_sale(1)
	assert_int(sale[0]).is_equal(3)
	assert_int((sale[1] as SaveGame).sold).is_equal(1)
	assert_int((sale[1] as SaveGame).stock).is_equal(9)


func test_a_condensed_golden_cabbage_pays_the_golden_price_twice_and_takes_two_golden_cabbages() -> void:
	var sale := _condensed_sale(2, true)
	var save: SaveGame = sale[1]
	assert_int(sale[0]).is_equal(60)  # 2 × $3 × 10
	assert_int(save.golden_sold).is_equal(2)
	assert_int(save.sold).is_equal(2)
	assert_int(save.golden_stock).is_equal(2)
	assert_int(save.stock).is_equal(8)


func test_a_condensed_cabbage_lands_outside_as_two_thuds_and_a_plain_one_as_one() -> void:
	assert_int(SaleWindow.thuds(1)).is_equal(1)
	assert_int(SaleWindow.thuds(2)).is_equal(2)
	assert_int(SaleWindow.thuds(4)).is_equal(2)
	# The second thud comes while the cabbage is still on its way out.
	assert_float(SaleWindow.SECOND_THUD).is_less(SaleWindow.SUCK_TIME)


## A rotten cabbage with $4 chalked, $100 in the tally and 5 in stock, sold through the window or
## `burst` on the desk: [the save after, the fined emissions].
func _rotten_fine(burst: bool) -> Array:
	var real := SaveManager.save
	var save := SaveGame.new()
	save.sale_price = 4
	save.coins = 100
	save.stock = 5
	SaveManager.save = save
	var holder := Node3D.new()  # Freed before the next one: a burst fines the first window in the tree.
	add_child(holder)
	var window := SaleWindow.new()
	window.coins = auto_free(FakeCoins.new())
	for cue: String in ["Suck", "Refuse"]:
		var player: AudioStreamPlayer3D = preload("res://entities/components/sound_cue.gd").new()
		player.name = cue
		window.add_child(player)
	holder.add_child(window)
	var seen := []
	window.fined.connect(func(_c: Cabbage, fine: int, was_burst: bool) -> void: seen.append([fine, was_burst]))
	var cabbage: Cabbage = preload("res://entities/cabbage/cabbage.tscn").instantiate()
	cabbage.rotten = true
	holder.add_child(cabbage)
	if burst:
		cabbage.burst()
	else:
		window._judge(cabbage)
	SaveManager.save = real
	holder.free()
	return [save, seen]


func test_a_rotten_cabbage_bursting_on_the_desk_is_fined_the_same_as_selling_it() -> void:
	var sold := _rotten_fine(false)
	var burst := _rotten_fine(true)
	for got: Array in [sold, burst]:
		var save: SaveGame = got[0]
		assert_int(save.coins).is_equal(60)
		assert_int(save.fines).is_equal(1)
		assert_int(save.stock).is_equal(4)
	assert_array(sold[1]).is_equal([[40, false]])
	assert_array(burst[1]).is_equal([[40, true]])
