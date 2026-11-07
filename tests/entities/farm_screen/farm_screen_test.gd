extends GdUnitTestSuite

var _real_save: SaveGame
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	SaveManager.save = _real_save
	TranslationServer.set_locale(_locale)


func _farm() -> SaveGame:
	var save := SaveGame.new()
	FarmScreen.ensure(save)
	return save


func test_the_uncles_farm_starts_with_twelve_empty_squares_and_ten_seeds() -> void:
	var save := _farm()
	assert_int(save.farm_plots).is_equal(12)
	assert_int(save.farm_seeds).is_equal(10)
	assert_int(save.farm_growth.size()).is_equal(12)
	assert_bool(Array(save.farm_growth).all(func(g: float) -> bool: return g == FarmScreen.EMPTY)).is_true()


func test_the_uncles_seeds_are_handed_out_only_once() -> void:
	var save := _farm()
	save.farm_seeds = 0
	FarmScreen.ensure(save)
	assert_int(save.farm_seeds).is_equal(0)


func test_planting_an_empty_square_uses_one_seed() -> void:
	var save := _farm()
	assert_bool(FarmScreen.plant(save, 0)).is_true()
	assert_int(save.farm_seeds).is_equal(9)
	assert_float(save.farm_growth[0]).is_equal(0.0)


func test_a_planted_square_cannot_be_planted_again() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	assert_bool(FarmScreen.plant(save, 0)).is_false()
	assert_int(save.farm_seeds).is_equal(9)


func test_without_seeds_nothing_can_be_planted() -> void:
	var save := _farm()
	save.farm_seeds = 0
	assert_bool(FarmScreen.plant(save, 1)).is_false()
	assert_float(save.farm_growth[1]).is_equal(FarmScreen.EMPTY)


func test_a_square_is_not_ripe_before_thirty_seconds_and_gives_nothing() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, 29.0)
	assert_int(FarmScreen.harvest(save, 0)).is_equal(0)
	assert_int(save.stock).is_equal(10)


func test_a_ripe_square_gives_three_cabbages_into_stock_and_is_empty_again() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, 30.0)
	assert_int(FarmScreen.harvest(save, 0)).is_equal(3)
	assert_int(save.stock).is_equal(13)
	assert_int(save.farm_harvests).is_equal(1)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)


func test_an_empty_square_neither_grows_nor_harvests() -> void:
	var save := _farm()
	FarmScreen.tick(save, 100.0)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)
	assert_int(FarmScreen.harvest(save, 0)).is_equal(0)
	assert_int(save.farm_harvests).is_equal(0)


func test_a_square_stops_growing_once_ripe() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, 500.0)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.GROW_TIME)


func test_fertiliser_ripens_squares_in_twenty_seconds_and_the_greenhouse_in_fifteen() -> void:
	var save := _farm()
	save.farm_bought.append("fertiliser")
	assert_float(FarmScreen.grow_time(save)).is_equal(20.0)
	save.farm_bought.append("greenhouse")
	assert_float(FarmScreen.grow_time(save)).is_equal(15.0)


func test_irrigation_makes_every_harvest_give_four_cabbages() -> void:
	var save := _farm()
	save.farm_bought.append("irrigation")
	assert_int(FarmScreen.yield_of(save)).is_equal(4)


func test_the_seed_contract_halves_every_seed_pack() -> void:
	var save := _farm()
	assert_int(FarmScreen.seed_price(0, save)).is_equal(50)
	assert_int(FarmScreen.seed_price(1, save)).is_equal(220)
	save.farm_bought.append("seed_contract")
	assert_int(FarmScreen.seed_price(0, save)).is_equal(25)
	assert_int(FarmScreen.seed_price(1, save)).is_equal(110)


func test_clearing_a_plot_opens_one_more_empty_square_and_the_next_gets_dearer() -> void:
	var save := _farm()
	save.coins = 100000
	assert_int(FarmScreen.plot_price(save)).is_equal(FarmScreen.PLOT_PRICE)
	FarmScreen.plant(save, 0)
	assert_bool(FarmScreen.buy("plot", save)).is_true()
	assert_int(save.coins).is_equal(100000 - FarmScreen.PLOT_PRICE)
	assert_int(save.farm_plots).is_equal(13)
	assert_int(save.farm_growth.size()).is_equal(13)
	assert_float(save.farm_growth[12]).is_equal(FarmScreen.EMPTY)
	assert_float(save.farm_growth[0]).is_equal(0.0)
	assert_int(FarmScreen.plot_price(save)).is_greater(FarmScreen.PLOT_PRICE)


func test_plots_get_fifteen_percent_dearer_each() -> void:
	var save := _farm()
	save.farm_plots = 22
	assert_int(FarmScreen.plot_price(save)).is_equal(roundi(150 * pow(1.15, 10)))


func test_no_plot_can_be_cleared_beyond_twenty_four_squares() -> void:
	var save := _farm()
	save.coins = 1000000
	save.farm_plots = FarmScreen.MAX_PLOTS
	assert_bool(FarmScreen.on_offer("plot", save)).is_false()
	assert_bool(FarmScreen.buy("plot", save)).is_false()
	assert_int(save.coins).is_equal(1000000)


func test_a_farm_upgrade_is_bought_once_for_its_price() -> void:
	var save := _farm()
	save.coins = 10000
	assert_bool(FarmScreen.buy("fertiliser", save)).is_true()
	assert_int(save.coins).is_equal(7000)
	assert_bool(FarmScreen.on_offer("fertiliser", save)).is_false()
	assert_bool(FarmScreen.buy("fertiliser", save)).is_false()
	assert_int(save.coins).is_equal(7000)


func test_without_enough_coins_no_upgrade_is_bought() -> void:
	var save := _farm()
	save.coins = 8999
	assert_bool(FarmScreen.buy("tractor", save)).is_false()
	assert_int(save.coins).is_equal(8999)
	assert_bool(save.farm_bought.has("tractor")).is_false()


func test_upgrade_prices_are_the_listed_ones() -> void:
	var save := _farm()
	for u: Dictionary in FarmScreen.UPGRADES:
		assert_int(FarmScreen.upgrade_price(u.id, save)).is_equal(u.price)
	assert_int(FarmScreen.upgrade_price("plot", save)).is_equal(FarmScreen.plot_price(save))


func test_without_machines_nothing_is_planted_or_harvested_by_itself() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, 30.0)
	FarmScreen.auto(save)
	assert_int(save.stock).is_equal(10)
	assert_int(save.farm_seeds).is_equal(9)


func test_the_farm_hand_plants_one_empty_square_per_step() -> void:
	var save := _farm()
	save.farm_bought.append("farm_hand")
	FarmScreen.auto(save)
	assert_int(save.farm_seeds).is_equal(9)
	assert_float(save.farm_growth[0]).is_equal(0.0)
	assert_float(save.farm_growth[1]).is_equal(FarmScreen.EMPTY)


func test_the_tractor_harvests_one_ripe_square_per_step() -> void:
	var save := _farm()
	save.farm_bought.append("tractor")
	FarmScreen.plant(save, 0)
	FarmScreen.plant(save, 1)
	FarmScreen.tick(save, 30.0)
	FarmScreen.auto(save)
	assert_int(save.stock).is_equal(13)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)
	assert_bool(FarmScreen.is_ripe(save, 1)).is_true()


func test_with_both_machines_a_harvested_square_is_replanted_in_the_same_step() -> void:
	var save := _farm()
	save.farm_bought.append_array(PackedStringArray(["farm_hand", "tractor"]))
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, 30.0)
	FarmScreen.auto(save)
	assert_int(save.stock).is_equal(13)
	assert_float(save.farm_growth[0]).is_equal(0.0)
	assert_int(save.farm_seeds).is_equal(8)


func test_the_farm_feeds_the_desk_only_once_bought_and_while_it_has_seeds_or_crops() -> void:
	var save := _farm()
	assert_bool(FarmScreen.feeds(save)).is_false()
	save.stamped.append("family_farm")
	assert_bool(FarmScreen.feeds(save)).is_true()
	FarmScreen.plant(save, 0)
	save.farm_seeds = 0
	assert_bool(FarmScreen.feeds(save)).is_true()
	FarmScreen.tick(save, 30.0)
	FarmScreen.harvest(save, 0)
	assert_bool(FarmScreen.feeds(save)).is_false()


func test_money_on_the_farm_screen_is_grouped_in_thousands() -> void:
	assert_str(FarmScreen._thousands(1234567)).is_equal("1,234,567")
	assert_str(FarmScreen._thousands(12)).is_equal("12")
	assert_str(FarmScreen._thousands(1000)).is_equal("1,000")
	assert_str(FarmScreen._thousands(-1234)).is_equal("-1,234")


func test_an_upgrade_entry_shows_its_price_until_bought_then_owned() -> void:
	var save := _farm()
	assert_str(FarmScreen.price_tag("tractor", save)).is_equal("$9,000")
	save.farm_bought.append("tractor")
	assert_str(FarmScreen.price_tag("tractor", save)).is_equal("OWNED")
	assert_str(FarmScreen.price_tag("plot", save)).is_equal("$%s" % FarmScreen._thousands(FarmScreen.plot_price(save)))


func test_every_hint_line_fits_the_screen_in_german_and_a_short_one_keeps_the_full_size() -> void:
	var font := FarmScreen.screen_font()
	var width := FarmScreen.SIZE.x - 72
	var screen: FarmScreen = auto_free(load("res://entities/farm_screen/farm_screen.tscn").instantiate())
	add_child(screen)
	TranslationServer.set_locale("de")
	var tr_ := func(text: String) -> String: return TranslationServer.translate(text)
	var hints: Array[String] = [tr_.call(screen._msg), tr_.call("Not enough money for seeds."), tr_.call("Not enough money."),
			tr_.call("Locked. Clear a plot on the right."), tr_.call("No seeds. Buy some in the seed shop."),
			tr_.call("%d seeds delivered.") % 99999, tr_.call("Harvested: +%d cabbages to stock.") % 99,
			tr_.call("Planted. Ripe in %d s.") % 30, tr_.call("%s approved.") % tr_.call("CLEAR A PLOT")]
	for u: Dictionary in FarmScreen.UPGRADES:
		hints.append(tr_.call("%s approved.") % tr_.call(u.title))
	for hint in hints:
		var size := FarmScreen.msg_size(font, hint, width)
		assert_float(font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) 				.override_failure_message("%s at %d px" % [hint, size]).is_less_equal(width)
	assert_int(FarmScreen.msg_size(font, "Ripe.", width)).is_equal(22)


func test_the_farm_clock_only_runs_once_the_family_farm_is_stamped() -> void:
	var save := SaveGame.new()
	SaveManager.save = save
	var screen: FarmScreen = auto_free(load("res://entities/farm_screen/farm_screen.tscn").instantiate())
	add_child(screen)
	screen._process(2.0)
	assert_float(save.farm_seconds).is_equal(0.0)

	save.stamped.append("family_farm")
	screen._process(2.0)

	assert_float(save.farm_seconds).is_equal_approx(2.0, 0.0001)

