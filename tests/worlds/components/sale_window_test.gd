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
