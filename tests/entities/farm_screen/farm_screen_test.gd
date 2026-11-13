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


func test_a_new_farm_starts_with_four_open_empty_squares_and_ten_seeds() -> void:
	var save := _farm()
	assert_int(save.farm_plots).is_equal(4)
	assert_int(save.farm_seeds).is_equal(10)
	assert_int(save.farm_growth.size()).is_equal(4)
	assert_bool(Array(save.farm_growth).all(func(g: float) -> bool: return g == FarmScreen.EMPTY)).is_true()


func test_an_old_farm_with_more_squares_keeps_them() -> void:
	var save := SaveGame.new()
	save.farm_plots = 12
	save.farm_growth = PackedFloat32Array([5.0])
	FarmScreen.ensure(save)
	assert_int(save.farm_plots).is_equal(12)
	assert_int(save.farm_growth.size()).is_equal(12)
	assert_float(save.farm_growth[0]).is_equal(5.0)


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
	assert_bool(FarmScreen.clear_plot(save)).is_true()
	assert_int(save.coins).is_equal(100000 - FarmScreen.PLOT_PRICE)
	assert_int(save.farm_plots).is_equal(5)
	assert_int(save.farm_growth.size()).is_equal(5)
	assert_float(save.farm_growth[4]).is_equal(FarmScreen.EMPTY)
	assert_float(save.farm_growth[0]).is_equal(0.0)
	assert_int(FarmScreen.plot_price(save)).is_greater(FarmScreen.PLOT_PRICE)


func test_plots_get_fifteen_percent_dearer_each() -> void:
	var save := _farm()
	save.farm_plots = 14
	assert_int(FarmScreen.plot_price(save)).is_equal(roundi(150 * pow(1.15, 10)))
	assert_int(FarmScreen.plot_price_of(14)).is_equal(FarmScreen.plot_price(save))


func test_no_plot_can_be_cleared_beyond_twenty_four_squares() -> void:
	var save := _farm()
	save.coins = 1000000
	save.farm_plots = FarmScreen.MAX_PLOTS
	assert_bool(FarmScreen.clear_plot(save)).is_false()
	assert_int(save.coins).is_equal(1000000)


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


func test_a_ripe_square_waits_while_its_harvest_would_overfill_storage() -> void:
	var save := _farm()
	save.stock = 18
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, FarmScreen.GROW_TIME)
	assert_int(FarmScreen.harvest(save, 0)).is_equal(0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()
	assert_bool(FarmScreen.can_work(save, true, 0)).is_false()
	assert_int(FarmScreen.target_for(save, true, 1, [])).is_equal(-1)
	save.stock = 17
	assert_int(FarmScreen.harvest(save, 0)).is_equal(3)
	assert_int(save.stock).is_equal(20)


func test_every_hint_line_fits_the_screen_in_german_and_a_short_one_keeps_the_full_size() -> void:
	var font := FarmScreen.screen_font()
	var width := FarmScreen.SIZE.x - 72
	var screen: FarmScreen = auto_free(load("res://entities/farm_screen/farm_screen.tscn").instantiate())
	add_child(screen)
	TranslationServer.set_locale("de")
	var tr_ := func(text: String) -> String: return TranslationServer.translate(text)
	var hints: Array[String] = [tr_.call(FarmScreen.OPENING) % [30, 3], tr_.call("Not enough money for seeds."), tr_.call("Not enough money."),
			tr_.call("Clear the squares in order."), tr_.call("No seeds. Buy a pack under the seed box."),
			tr_.call("%d seeds delivered.") % 99999, tr_.call("Standing order: %d seeds delivered.") % 99999, tr_.call("Harvested: +%d cabbages to stock.") % 99,
			tr_.call("Planted. Ripe in %d s.") % 30, tr_.call("Square cleared."), tr_.call("Seed back in the box."),
			tr_.call("Seed in hand. Let go over an empty square to plant it."), tr_.call("Drag a seed from the box onto an empty square."),
			tr_.call("Grab the cabbage and yank it off its square."),
			tr_.call("Storage full (%d cabbages). Sell some first.") % 99999, tr_.call("Rotten square cleared."),
			tr_.call("Golden harvest: +%d golden cabbages to stock.") % 99,
			tr_.call("Harvested by hand: +%d cabbages (GREEN THUMB ×%d).") % [99, 3]]
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


func test_planting_without_seeds_blinks_the_seed_count_red_from_the_first_moment() -> void:
	assert_bool(FarmScreen.blink_on(FarmScreen.SEED_BLINK)).is_true()
	assert_bool(FarmScreen.blink_on(0.0)).is_false()


func test_the_first_harvest_records_when_it_happened() -> void:
	var save := _farm()
	save.farm_seconds = 42.0
	FarmScreen.plant(save, 0)
	FarmScreen.plant(save, 1)
	FarmScreen.tick(save, 30.0)
	FarmScreen.harvest(save, 0)
	assert_float(save.farm_first_harvest).is_equal(42.0)
	save.farm_seconds = 99.0
	FarmScreen.harvest(save, 1)
	assert_float(save.farm_first_harvest).is_equal(42.0)


func _screen(save: SaveGame) -> FarmScreen:
	SaveManager.save = save
	var screen: FarmScreen = auto_free(load("res://entities/farm_screen/farm_screen.tscn").instantiate())
	add_child(screen)
	return screen


const BOX := FarmScreen.SEED_BOX


func _at(i: int) -> Vector2:
	return FarmScreen.square(i).get_center()


func test_releasing_a_seed_over_an_empty_square_plants_it() -> void:
	var save := _farm()
	var screen := _screen(save)
	screen._press(BOX.get_center())
	assert_bool(screen._held).is_true()
	screen._release(_at(0))
	assert_float(save.farm_growth[0]).is_equal(0.0)
	assert_int(save.farm_seeds).is_equal(9)
	assert_bool(screen._held).is_false()


func test_pressing_an_empty_square_without_a_seed_plants_nothing() -> void:
	var save := _farm()
	var screen := _screen(save)
	screen._press(_at(0))
	screen._release(_at(0))
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)
	assert_int(save.farm_seeds).is_equal(10)
	assert_float(screen._shake).is_greater(0.0)


func test_a_seed_released_off_the_field_goes_back_to_the_box() -> void:
	var save := _farm()
	var screen := _screen(save)
	# The box itself, the glass's edge, a locked square.
	for off: Vector2 in [BOX.get_center(), Vector2(5, 5), _at(6)]:
		screen._press(BOX.get_center())
		screen._release(off)
		assert_bool(screen._held).is_false()
		assert_bool(screen._flying).is_true()
	assert_int(save.farm_seeds).is_equal(10)
	assert_array(Array(save.farm_growth)).not_contains([0.0])


func test_a_seed_released_over_a_planted_square_goes_back_to_the_box() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	var screen := _screen(save)
	screen._press(BOX.get_center())
	screen._release(_at(0))
	assert_int(save.farm_seeds).is_equal(9)
	assert_bool(screen._flying).is_true()


func test_without_seeds_no_seed_can_be_taken_from_the_box_and_it_blinks() -> void:
	var save := _farm()
	save.farm_seeds = 0
	var screen := _screen(save)
	screen._press(BOX.get_center())
	assert_bool(screen._held).is_false()
	assert_bool(FarmScreen.blink_on(screen._seed_blink)).is_true()


func test_clicking_the_next_locked_square_clears_it_and_a_further_one_does_nothing() -> void:
	var save := _farm()
	save.coins = 1000
	var screen := _screen(save)
	screen._press(_at(6))
	assert_int(save.farm_plots).is_equal(4)
	screen._press(_at(4))
	assert_int(save.farm_plots).is_equal(5)
	assert_int(save.coins).is_equal(1000 - FarmScreen.PLOT_PRICE)


func _ripe() -> SaveGame:
	var save := _farm()
	save.stock = 0
	FarmScreen.plant(save, 0)
	FarmScreen.tick(save, FarmScreen.GROW_TIME)
	return save


func test_a_ripe_cabbage_is_only_harvested_once_pulled_past_the_threshold() -> void:
	var save := _ripe()
	var screen := _screen(save)
	screen._press(_at(0))
	screen._drag(_at(0) + Vector2(FarmScreen.PULL_DISTANCE - 1.0, 0))
	assert_int(save.stock).is_equal(0)
	screen._drag(_at(0) + Vector2(0, -FarmScreen.PULL_DISTANCE))
	assert_int(save.stock).is_equal(3)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)


func test_a_cabbage_let_go_before_the_threshold_springs_back_unharvested() -> void:
	var save := _ripe()
	var screen := _screen(save)
	screen._press(_at(0))
	screen._drag(_at(0) + Vector2(30, 30))
	screen._release(_at(0) + Vector2(30, 30))
	assert_int(save.stock).is_equal(0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()
	assert_int(screen._snap).is_equal(0)


func test_a_cabbage_pulled_with_storage_full_springs_back_and_stays_ripe() -> void:
	var save := _ripe()
	save.storage_cap = 2
	save.stock = 0
	var screen := _screen(save)
	screen._press(_at(0))
	screen._drag(_at(0) + Vector2(FarmScreen.PULL_DISTANCE * 2.0, 0))
	assert_int(save.stock).is_equal(0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()
	assert_int(screen._snap).is_equal(0)


func test_pulling_a_cabbage_out_by_hand_records_the_first_harvest() -> void:
	var save := _ripe()
	save.farm_seconds = 12.0
	var screen := _screen(save)
	screen._press(_at(0))
	screen._drag(_at(0) + Vector2(FarmScreen.PULL_DISTANCE, 0))
	assert_float(save.farm_first_harvest).is_equal(12.0)


func test_a_pulled_cabbage_leans_toward_the_mouse_but_never_further_than_its_strain() -> void:
	assert_vector(FarmScreen.strain(Vector2.ZERO)).is_equal(Vector2.ZERO)
	assert_float(FarmScreen.strain(Vector2(10, 0)).x).is_greater(0.0)
	assert_float(FarmScreen.strain(Vector2(0, -1000)).length()).is_equal_approx(FarmScreen.STRAIN, 0.001)


func test_a_sprout_shows_more_growth_the_longer_it_has_grown() -> void:
	var ripe := FarmScreen.GROW_TIME
	assert_int(FarmScreen.growth_stage(0.0, ripe)).is_equal(0)
	var last := -1
	for k in 10:
		var stage := FarmScreen.growth_stage(ripe * k / 10.0, ripe)
		assert_int(stage).is_greater_equal(last)
		last = stage
	assert_int(FarmScreen.growth_stage(ripe * 0.99, ripe)).is_equal(FarmScreen.STAGES.size() - 1)
	assert_int(FarmScreen.growth_stage(ripe * 0.5, ripe)).is_between(1, FarmScreen.STAGES.size() - 2)


func test_bare_soil_is_the_same_every_time_and_not_one_tile_for_every_square() -> void:
	assert_int(FarmScreen.soil_variant(3)).is_equal(FarmScreen.soil_variant(3))
	var used := {}
	for i in FarmScreen.MAX_PLOTS:
		assert_int(FarmScreen.soil_variant(i)).is_between(0, FarmScreen.SOILS.size() - 1)
		used[FarmScreen.soil_variant(i)] = true
	assert_int(used.size()).is_greater(1)


func test_every_growth_stage_and_the_ripe_cabbage_is_a_pixel_sprite_drawn_at_whole_pixels() -> void:
	for sprite: Texture2D in FarmScreen.STAGES + FarmScreen.SOILS + [FarmScreen.CABBAGE_SPRITE]:
		assert_int(sprite.get_width()).is_equal(FarmScreen.PIXEL)
	var side := FarmScreen.sprite_rect(FarmScreen.square(0)).size.x
	assert_float(fmod(side, FarmScreen.PIXEL)).is_equal(0.0)
	assert_bool(FarmScreen.square(0).encloses(FarmScreen.sprite_rect(FarmScreen.square(0)))).is_true()
	var screen := _screen(_farm())
	assert_int(screen.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_a_squares_sprite_takes_about_four_fifths_of_the_square() -> void:
	var fill := FarmScreen.sprite_rect(FarmScreen.square(0)).size.x / FarmScreen.square(0).size.x
	assert_float(fill).is_between(0.7, 0.8)


func test_a_fresh_farm_shows_no_status_row_until_the_readout_card_is_stamped() -> void:
	var save := _farm()
	save.stamped.append("family_farm")
	assert_bool(FarmScreen.status_shown(save)).is_false()
	save.stamped.append(FarmScreen.STATUS_CARD)
	assert_bool(FarmScreen.status_shown(save)).is_true()
	assert_array(UpgradeDesk.card_data(FarmScreen.STATUS_CARD).get("needs")).is_equal(["family_farm"])


func test_the_cursor_is_a_grab_hand_while_holding_a_seed() -> void:
	var save := _farm()
	assert_int(FarmScreen.cursor_for(save, Vector2(5, 5), true)).is_equal(FarmScreen.GRAB)
	assert_int(FarmScreen.cursor_for(save, _at(0), true)).is_equal(FarmScreen.GRAB)


func test_the_cursor_is_an_open_hand_over_the_seed_box_and_a_ripe_cabbage_only() -> void:
	var save := _ripe()
	assert_int(FarmScreen.cursor_for(save, BOX.get_center(), false)).is_equal(FarmScreen.OPEN_HAND)
	assert_int(FarmScreen.cursor_for(save, _at(0), false)).is_equal(FarmScreen.OPEN_HAND)
	assert_int(FarmScreen.cursor_for(save, _at(1), false)).is_equal(Input.CURSOR_ARROW)
	FarmScreen.plant(save, 1)
	assert_int(FarmScreen.cursor_for(save, _at(1), false)).is_equal(Input.CURSOR_ARROW)


func test_the_cursor_points_at_the_next_locked_square_and_is_the_arrow_elsewhere() -> void:
	var save := _farm()
	assert_int(FarmScreen.cursor_for(save, _at(4), false)).is_equal(FarmScreen.POINT)
	assert_int(FarmScreen.cursor_for(save, _at(5), false)).is_equal(Input.CURSOR_ARROW)
	assert_int(FarmScreen.cursor_for(save, Vector2(5, 5), false)).is_equal(Input.CURSOR_ARROW)


func test_the_seed_pack_buttons_show_a_pointer() -> void:
	var screen := _screen(_farm())
	for button: Button in screen._seed_buttons:
		assert_int(button.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)


func test_the_seed_packs_are_two_buttons_with_a_seed_icon_and_their_price() -> void:
	var save := _farm()
	save.farm_bought.append("seed_contract")
	var screen := _screen(save)
	screen._refresh(save)
	var ten: Button = screen.get_node("Packs/Seeds0")
	assert_str((ten.get_node("Row/Price") as Label).text).is_equal("10×  $25")
	assert_object((ten.get_node("Row/Bag") as TextureRect).texture).is_not_null()
	assert_str((screen.get_node("Packs/Seeds1/Row/Price") as Label).text).is_equal("50×  $110")


func test_every_square_lies_on_the_left_three_quarters_and_the_seed_box_in_the_yard() -> void:
	for i in FarmScreen.MAX_PLOTS:
		assert_bool(FarmScreen.FIELD.encloses(FarmScreen.square(i))).override_failure_message("square %d" % i).is_true()
	assert_float(FarmScreen.FIELD.end.x).is_less_equal(FarmScreen.SIZE.x * 0.75)
	assert_bool(FarmScreen.YARD.encloses(FarmScreen.SEED_BOX)).is_true()


func test_a_farm_hand_on_route_zero_heads_for_any_open_square() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0)
	for k in 50:
		var i := FarmScreen.target_for(save, false, 0, [])
		assert_bool(i >= 0 and i < save.farm_plots).is_true()


func test_a_tractor_on_route_one_only_drives_to_ripe_squares() -> void:
	var save := _farm()
	FarmScreen.plant(save, 1)
	FarmScreen.tick(save, 30.0)
	FarmScreen.plant(save, 2)
	for k in 20:
		assert_int(FarmScreen.target_for(save, true, 1, [])).is_equal(1)
	assert_int(FarmScreen.target_for(save, true, 1, [1])).is_equal(-1)


func test_a_farm_hand_on_route_one_only_walks_to_empty_squares() -> void:
	var save := _farm()
	for i in 3:
		FarmScreen.plant(save, i)
	assert_int(FarmScreen.target_for(save, false, 1, [])).is_equal(3)
	assert_int(FarmScreen.target_for(save, false, 1, [3])).is_equal(-1)
	FarmScreen.plant(save, 3)
	assert_int(FarmScreen.target_for(save, false, 0, [])).is_equal(-1)


func test_workers_follow_the_counts_in_the_save() -> void:
	var save := _farm()
	save.farm_hands = 2
	save.farm_tractors = 1
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	assert_int(workers.size()).is_equal(3)
	assert_int(workers.filter(func(w: FarmScreen.Worker) -> bool: return w.tractor).size()).is_equal(1)
	save.farm_hands = 1
	FarmScreen.sync_workers(workers, save)
	assert_int(workers.size()).is_equal(2)


func test_a_farm_hand_walks_out_and_plants_and_a_tractor_harvests() -> void:
	var save := _farm()
	save.farm_hands = 1
	save.farm_tractors = 1
	save.farm_hand_route = 1
	save.farm_tractor_route = 1
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	for k in 200:  # 20 s
		FarmScreen.work(workers, save, 0.1)
	assert_int(_planted(save)).is_greater(0)
	FarmScreen.tick(save, 30.0)
	var stock := save.stock
	for k in 200:
		FarmScreen.work(workers, save, 0.1)
	assert_int(save.stock).is_greater(stock)


func test_a_faster_farm_hand_plants_sooner() -> void:
	var slow := _farm()
	var fast := _farm()
	for save: SaveGame in [slow, fast]:
		save.farm_hands = 1
		save.farm_hand_route = 1
		# One empty square, so both walk the same way (targets are picked at random).
		for i in range(1, save.farm_growth.size()):
			save.farm_growth[i] = 0.0
	fast.farm_hand_speed = 2.0
	assert_float(_seconds_to_plant(fast)).is_less(_seconds_to_plant(slow))


## Seconds until `save`'s farm hand plants square 0 (30 s at most).
func _seconds_to_plant(save: SaveGame) -> float:
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	for k in 300:
		if save.farm_growth[0] >= 0.0:
			return k * 0.1
		FarmScreen.work(workers, save, 0.1)
	return 30.0


## How many open squares are planted.
func _planted(save: SaveGame) -> int:
	return Array(save.farm_growth).filter(func(g: float) -> bool: return g >= 0.0).size()


## One worker of `save`'s (a tractor or a farm hand) on route 1, standing in the yard.
func _crew(save: SaveGame, tractor: bool) -> Array[FarmScreen.Worker]:
	save.farm_hands = 0 if tractor else 1
	save.farm_tractors = 1 if tractor else 0
	save.farm_hand_route = 1
	save.farm_tractor_route = 1
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	return workers


## Runs `workers` in 0.05 s steps until `done` is true (false after `seconds`).
func _run_until(workers: Array[FarmScreen.Worker], save: SaveGame, done: Callable, seconds := 30.0) -> bool:
	for k in int(seconds / 0.05):
		if done.call():
			return true
		FarmScreen.work(workers, save, 0.05)
	return done.call()


## A save whose first `n` squares are ripe, with an empty store.
func _ripe_squares(n: int) -> SaveGame:
	var save := _farm()
	save.stock = 0
	for i in n:
		FarmScreen.plant(save, i)
	FarmScreen.tick(save, 30.0)
	return save


func test_a_farm_hand_fetches_a_seed_from_the_crate_before_planting() -> void:
	var save := _farm()
	var workers := _crew(save, false)
	var hand := workers[0]
	assert_bool(_run_until(workers, save, func() -> bool: return hand.seeds > 0)).is_true()
	assert_float(hand.pos.distance_to(FarmScreen.crate_spot())).is_less(1.0)
	assert_int(save.farm_seeds).is_equal(FarmScreen.START_SEEDS - 1)
	assert_int(_planted(save)).is_equal(0)
	assert_bool(_run_until(workers, save, func() -> bool: return _planted(save) > 0)).is_true()
	assert_int(hand.seeds).is_equal(0)
	assert_int(_planted(save)).is_equal(1)
	assert_int(save.farm_seeds).is_equal(FarmScreen.START_SEEDS - 1)


func test_a_farm_hand_waits_in_the_yard_while_the_crate_is_empty() -> void:
	var save := _farm()
	save.farm_seeds = 0
	var workers := _crew(save, false)
	var hand := workers[0]
	_run_until(workers, save, func() -> bool: return false, 10.0)
	assert_object(hand.pos).is_equal(FarmScreen.home(false, 0))
	assert_int(_planted(save)).is_equal(0)
	save.farm_seeds = 5
	FarmScreen.work(workers, save, 0.05)
	assert_int(hand.target).is_equal(FarmScreen.CRATE)


func test_a_farm_hand_whose_square_got_planted_keeps_its_seed_for_another() -> void:
	var save := _farm()
	var workers := _crew(save, false)
	var hand := workers[0]
	hand.seeds = 1
	hand.target = 0
	hand.pos = FarmScreen.square(0).get_center()
	FarmScreen.plant(save, 0)
	FarmScreen.work(workers, save, 0.05)
	assert_int(hand.seeds).is_equal(1)
	assert_float(hand.busy).is_equal(0.0)
	assert_bool(_run_until(workers, save, func() -> bool: return _planted(save) == 2)).is_true()


func test_a_worker_goes_back_to_the_yard_after_each_job() -> void:
	var save := _ripe_squares(2)
	var workers := _crew(save, true)
	var tractor := workers[0]
	assert_bool(_run_until(workers, save, func() -> bool: return save.stock > 0)).is_true()
	var first := save.stock
	assert_bool(tractor.going_home).is_true()
	assert_bool(_run_until(workers, save, func() -> bool: return tractor.pos == FarmScreen.home(true, 0))).is_true()
	assert_int(save.stock).is_equal(first)
	assert_bool(_run_until(workers, save, func() -> bool: return save.stock > first)).is_true()
	# A farm hand too: back to the yard after planting its one seed.
	save = _farm()
	workers = _crew(save, false)
	assert_bool(_run_until(workers, save, func() -> bool: return _planted(save) > 0)).is_true()
	assert_bool(workers[0].going_home).is_true()


func test_a_longer_shift_lets_a_worker_do_more_jobs_before_returning() -> void:
	var save := _ripe_squares(2)
	save.farm_tractor_shift = 2
	var workers := _crew(save, true)
	var tractor := workers[0]
	var yard := FarmScreen.home(true, 0)
	assert_bool(_run_until(workers, save, func() -> bool: return save.stock > 0)).is_true()
	assert_bool(tractor.going_home).is_false()
	var home_between := false
	for k in 600:
		if save.stock >= 2 * FarmScreen.YIELD:
			break
		FarmScreen.work(workers, save, 0.05)
		home_between = home_between or tractor.pos == yard
	assert_int(save.stock).is_equal(2 * FarmScreen.YIELD)
	assert_bool(home_between).is_false()
	assert_bool(tractor.going_home).is_true()
	# A farm hand on a shift of 2 takes 2 seeds from the crate and plants both.
	save = _farm()
	save.farm_hand_shift = 2
	workers = _crew(save, false)
	assert_bool(_run_until(workers, save, func() -> bool: return workers[0].seeds > 0)).is_true()
	assert_int(workers[0].seeds).is_equal(2)
	assert_bool(_run_until(workers, save, func() -> bool: return _planted(save) == 2)).is_true()
	assert_bool(workers[0].going_home).is_true()


func test_a_tractor_waits_while_storage_is_full() -> void:
	var save := _ripe_squares(1)
	save.storage_cap = 0
	var workers := _crew(save, true)
	_run_until(workers, save, func() -> bool: return false, 10.0)
	assert_object(workers[0].pos).is_equal(FarmScreen.home(true, 0))
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()
	save.storage_cap = 100
	assert_bool(_run_until(workers, save, func() -> bool: return save.stock > 0)).is_true()


func test_a_farm_hand_sent_away_puts_its_seeds_back_in_the_crate() -> void:
	var save := _farm()
	var workers := _crew(save, false)
	workers[0].seeds = 2
	save.farm_hands = 0
	FarmScreen.sync_workers(workers, save)
	assert_int(save.farm_seeds).is_equal(FarmScreen.START_SEEDS + 2)


func test_each_tractor_waits_in_its_own_parking_bay_stacked_down_the_yards_left_side() -> void:
	for n in FarmScreen.SLOTS:
		var bay := FarmScreen.bay_rect(n)
		assert_bool(FarmScreen.YARD.encloses(bay)).is_true()
		assert_bool(bay.has_point(FarmScreen.home(true, n))).is_true()
		assert_float(bay.position.x).is_less(FarmScreen.YARD.get_center().x)
		var tractor := Vector2.ONE * FarmScreen.PIXEL * FarmScreen.TRACTOR_PIXEL
		assert_bool(bay.encloses(Rect2(bay.get_center() - tractor * 0.5, tractor))).is_true()
		if n > 0:
			assert_float(bay.position.y).is_greater_equal(FarmScreen.bay_rect(n - 1).end.y)


func test_each_farm_hand_lives_in_its_own_tractor_sized_hut_in_the_yards_top_right() -> void:
	for n in FarmScreen.SLOTS:
		var hut := FarmScreen.hut_rect(n)
		assert_bool(FarmScreen.YARD.encloses(hut)).is_true()
		assert_bool(hut.has_point(FarmScreen.home(false, n))).is_true()
		assert_float(hut.size.x).is_equal(FarmScreen.PIXEL * FarmScreen.TRACTOR_PIXEL)
		assert_float(hut.position.x).is_greater_equal(FarmScreen.bay_rect(0).end.x)
		assert_float(hut.end.y).is_less(FarmScreen.SEED_BOX.position.y)
		for other in n:
			assert_bool(hut.intersects(FarmScreen.hut_rect(other))).is_false()


func test_the_auto_seed_switch_sits_in_the_yard_under_the_huts_clear_of_the_bays_and_seed_box() -> void:
	var switch: Button = _screen(_farm()).get_node("AutoSeed")
	var r := switch.get_rect()
	assert_bool(FarmScreen.YARD.encloses(r)).is_true()
	assert_float(r.position.x).is_greater_equal(FarmScreen.bay_rect(0).end.x)
	assert_float(r.end.y).is_less(FarmScreen.SEED_BOX.position.y - 12)  # Inside the yard's frame.
	for n in FarmScreen.SLOTS:
		assert_bool(r.intersects(FarmScreen.hut_rect(n))).is_false()
	# Its lever sprite is drawn at whole pixels: the button is exactly its face's size.
	var on := switch.get_theme_stylebox("pressed") as StyleBoxTexture
	var off := switch.get_theme_stylebox("normal") as StyleBoxTexture
	assert_vector(r.size).is_equal(on.texture.get_size())
	assert_object(on.texture).is_not_equal(off.texture)


func test_a_farm_hand_is_indoors_only_while_it_waits_in_its_hut() -> void:
	var save := _farm()
	var workers := _crew(save, false)
	var hand := workers[0]
	assert_bool(FarmScreen.indoors(hand)).is_true()
	assert_bool(_run_until(workers, save, func() -> bool: return hand.seeds > 0)).is_true()
	assert_bool(FarmScreen.indoors(hand)).is_false()
	assert_bool(_run_until(workers, save, func() -> bool: return _planted(save) > 0 and FarmScreen.indoors(hand))).is_true()
	assert_bool(FarmScreen.indoors(FarmScreen.Worker.new(true, 0))).is_false()  # A tractor parks, it has no hut.


func test_the_standing_seed_order_buys_a_pack_once_the_crate_is_down_to_its_reserve() -> void:
	var save := _farm()
	save.coins = 1000
	save.farm_seeds = 6
	assert_int(FarmScreen.auto_seed(save)).is_equal(0)  # No card, no order.
	save.stamped.append(FarmScreen.AUTO_CARD)
	assert_int(FarmScreen.auto_seed(save)).is_equal(0)  # 6 seeds: above the reserve of 5.
	save.farm_seeds = 5
	assert_int(FarmScreen.auto_seed(save)).is_equal(10)
	assert_int(save.farm_seeds).is_equal(15)
	assert_int(save.coins).is_equal(1000 - FarmScreen.seed_price(0, save))
	assert_int(FarmScreen.auto_seed(save)).is_equal(0)


func test_the_standing_seed_order_waits_while_switched_off_or_the_money_is_short() -> void:
	var save := _farm()
	save.stamped.append(FarmScreen.AUTO_CARD)
	save.farm_seeds = 0
	save.coins = FarmScreen.seed_price(0, save) - 1
	assert_int(FarmScreen.auto_seed(save)).is_equal(0)
	assert_int(save.farm_seeds).is_equal(0)
	save.coins += 1
	save.farm_auto_seed = false
	assert_int(FarmScreen.auto_seed(save)).is_equal(0)
	save.farm_auto_seed = true
	assert_int(FarmScreen.auto_seed(save)).is_equal(10)
	assert_int(save.coins).is_equal(0)


func test_the_standing_seed_order_reorders_earlier_and_buys_the_big_pack_once_upgraded() -> void:
	var save := _farm()
	save.stamped.append(FarmScreen.AUTO_CARD)
	save.coins = 1000
	save.farm_seeds = 20
	save.farm_seed_reserve = 20
	save.farm_seed_pack = 1
	assert_int(FarmScreen.auto_seed(save)).is_equal(50)
	assert_int(save.coins).is_equal(1000 - FarmScreen.seed_price(1, save))


func test_the_auto_seed_switch_only_shows_with_the_card_and_flips_the_saved_order() -> void:
	var save := _farm()
	var screen := _screen(save)
	TranslationServer.set_locale("en")
	var switch: Button = screen.get_node("AutoSeed")
	screen._refresh(save)
	assert_bool(switch.visible).is_false()
	save.stamped.append(FarmScreen.AUTO_CARD)
	screen._refresh(save)
	assert_bool(switch.visible).is_true()
	assert_bool(switch.button_pressed).is_true()  # On from the stamp.
	assert_int(switch.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	switch.button_pressed = false
	assert_bool(save.farm_auto_seed).is_false()
	screen._refresh(save)
	assert_str(switch.text).is_equal("AUTO SEED: OFF")


func test_idle_workers_stand_in_the_top_of_the_yard_above_the_seed_box() -> void:
	for n in 3:
		for tractor: bool in [false, true]:
			var at := FarmScreen.home(tractor, n)
			var half := 8.0 * (FarmScreen.TRACTOR_PIXEL if tractor else FarmScreen.WORKER_PIXEL)
			assert_bool(FarmScreen.YARD.grow(-half).has_point(at)).is_true()
			assert_float(at.y + half).is_less(FarmScreen.SEED_BOX.position.y)


func test_the_farm_hand_is_a_glove_and_the_tractor_faces_the_way_it_drives_in_pixel_sprites() -> void:
	for tex: Texture2D in [FarmScreen.HAND_OPEN, FarmScreen.HAND_CARRY, FarmScreen.HAND_PRESS] + FarmScreen.TRACTOR_SPRITES:
		assert_object(tex.get_size()).is_equal(Vector2(FarmScreen.PIXEL, FarmScreen.PIXEL))
	assert_float(fmod(FarmScreen.WORKER_PIXEL, 1.0)).is_equal(0.0)
	assert_float(fmod(FarmScreen.TRACTOR_PIXEL, 1.0)).is_equal(0.0)
	var save := _ripe_squares(1)
	var workers := _crew(save, true)
	FarmScreen.work(workers, save, 0.1)
	assert_bool(workers[0].left).is_true()  # The field lies left of the yard.
	assert_int(FarmScreen.worker_frame(0.0)).is_not_equal(FarmScreen.worker_frame(FarmScreen.WALK_STEP))


func test_clicking_an_empty_square_without_a_seed_shakes_the_hint_then_settles() -> void:
	assert_float(absf(FarmScreen.shake_offset(FarmScreen.SHAKE_TIME * 0.9))).is_greater(0.0)
	assert_float(absf(FarmScreen.shake_offset(FarmScreen.SHAKE_TIME * 0.5))).is_less_equal(FarmScreen.SHAKE_PX)
	assert_float(FarmScreen.shake_offset(0.0)).is_equal(0.0)


func test_the_seed_pile_on_the_crate_shrinks_as_the_seeds_run_out() -> void:
	assert_int(FarmScreen.pile_stage(0)).is_equal(0)
	assert_int(FarmScreen.pile_stage(3)).is_equal(1)
	assert_int(FarmScreen.pile_stage(FarmScreen.PILE_SOME)).is_equal(2)
	assert_int(FarmScreen.pile_stage(FarmScreen.PILE_LOTS)).is_equal(3)


func test_the_seed_crate_and_its_pile_fit_in_the_seed_box() -> void:
	assert_bool(FarmScreen.SEED_BOX.encloses(FarmScreen.crate_rect())).is_true()
	assert_bool(FarmScreen.SEED_BOX.encloses(FarmScreen.pile_rect())).is_true()


func test_just_clicking_a_ripe_cabbage_says_to_yank_it_and_shakes_the_hint() -> void:
	var save := _ripe()
	var screen := _screen(save)
	screen._press(_at(0))
	screen._release(_at(0))
	assert_int(save.stock).is_equal(0)
	assert_str(screen._msg).is_equal(tr("Grab the cabbage and yank it off its square."))
	assert_float(screen._shake).is_greater(0.0)


func test_the_seed_pack_buttons_are_pixel_plates_like_the_crate() -> void:
	var screen := _screen(_farm())
	for button: Button in screen._seed_buttons:
		assert_object(button.get_theme_stylebox("normal")).is_instanceof(StyleBoxTexture)
		assert_object(button.get_theme_stylebox("pressed")).is_instanceof(StyleBoxTexture)
		assert_int((button.get_node("Row") as HBoxContainer).alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)


func test_seeds_in_a_hands_glove_are_kept_in_the_save_and_go_back_to_the_crate_on_load() -> void:
	var save := _farm()
	save.farm_hands = 1
	save.farm_hand_route = 1
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	var total := save.farm_seeds
	for k in 200:
		FarmScreen.work(workers, save, 0.1)
		if workers[0].seeds > 0:
			break
	assert_int(workers[0].seeds).is_greater(0)
	assert_int(save.farm_seeds + save.farm_seeds_carried).is_equal(total)
	# Quit now: the next load has no workers, the glove's seeds are back in the crate.
	FarmScreen.return_carried(save)
	assert_int(save.farm_seeds).is_equal(total)
	assert_int(save.farm_seeds_carried).is_equal(0)


# Golden squares, rot and GREEN THUMB.

func _ripe_square(cards: Array = []) -> SaveGame:
	var save := _farm()
	save.stamped = PackedStringArray(cards)
	save.storage_cap = 200
	save.stock = 0
	FarmScreen.plant(save, 0, 1.0)
	FarmScreen.tick(save, FarmScreen.GROW_TIME)
	return save


func test_a_planted_square_grows_golden_only_with_the_golden_card_and_at_its_chance() -> void:
	var save := _farm()
	FarmScreen.plant(save, 0, 0.0)
	assert_bool(FarmScreen.is_golden(save, 0)).is_false()
	save.stamped.append("golden_cabbage")
	FarmScreen.plant(save, 1, save.golden_chance - 0.001)
	FarmScreen.plant(save, 2, save.golden_chance + 0.001)
	assert_bool(FarmScreen.is_golden(save, 1)).is_true()
	assert_bool(FarmScreen.is_golden(save, 2)).is_false()


func test_golden_squares_start_at_one_in_forty() -> void:
	assert_float(SaveGame.new().golden_chance).is_equal_approx(1.0 / 40.0, 0.0001)


func test_a_harvested_golden_square_puts_golden_units_into_stock_and_is_plain_again() -> void:
	var save := _ripe_square(["golden_cabbage"])
	save.farm_golden.append(0)
	assert_int(FarmScreen.harvest(save, 0)).is_equal(3)
	assert_int(save.stock).is_equal(3)
	assert_int(save.golden_stock).is_equal(3)
	assert_bool(FarmScreen.is_golden(save, 0)).is_false()


func test_before_the_overripe_event_a_ripe_square_waits_forever() -> void:
	var save := _ripe_square()
	FarmScreen.tick(save, FarmScreen.ROT_AFTER * 10.0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()


func test_after_the_overripe_event_a_ripe_square_rots_three_minutes_after_it_ripened() -> void:
	var save := _ripe_square(["golden_cabbage"])
	save.farm_golden.append(0)
	save.overripe = true
	FarmScreen.tick(save, 179.0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()
	FarmScreen.tick(save, 1.0)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.ROTTEN)
	assert_int(save.farm_rotted).is_equal(1)
	assert_bool(FarmScreen.is_golden(save, 0)).is_false()
	assert_float(FarmScreen.ROT_AFTER).is_equal(180.0)
	assert_float(SaveGame.new().rot_after).is_equal(FarmScreen.ROT_AFTER)


func test_a_longer_rot_delay_keeps_a_ripe_square_ripe_that_long() -> void:
	var save := _ripe_square()
	save.overripe = true
	save.rot_after = 720.0
	assert_int(FarmScreen.tick(save, 719.0)).is_equal(0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()
	assert_int(FarmScreen.tick(save, 1.0)).is_equal(1)


func test_a_loaded_square_already_past_its_rot_time_starts_its_wait_again_instead_of_rotting_at_once() -> void:
	var save := _ripe_square()
	save.overripe = true
	save.farm_growth[1] = FarmScreen.GROW_TIME + 400.0  # Saved when squares waited 10 min.
	save.farm_growth[2] = FarmScreen.GROW_TIME + 100.0  # Still inside the new limit: keeps its count.
	FarmScreen.restart_overdue(save)
	assert_float(save.farm_growth[1]).is_equal(FarmScreen.GROW_TIME)
	assert_float(save.farm_growth[2]).is_equal(FarmScreen.GROW_TIME + 100.0)
	assert_int(FarmScreen.tick(save, 1.0)).is_equal(0)
	assert_int(FarmScreen.tick(save, 79.0)).is_equal(1)  # Square 2, on its old count.
	assert_int(FarmScreen.tick(save, 100.0)).is_equal(2)  # Squares 0 and 1, a full wait after loading.


func test_the_rot_tick_reports_how_many_squares_rotted_and_nothing_when_none_did() -> void:
	var save := _ripe_square()
	save.overripe = true
	assert_int(FarmScreen.tick(save, FarmScreen.ROT_AFTER - 1.0)).is_equal(0)
	assert_int(FarmScreen.tick(save, 1.0)).is_equal(1)
	assert_int(FarmScreen.tick(save, 1.0)).is_equal(0)


func test_a_rotten_square_gives_nothing_takes_no_seed_and_no_worker_until_clicked_clear() -> void:
	var save := _farm()
	save.farm_growth[0] = FarmScreen.ROTTEN
	assert_int(FarmScreen.harvest(save, 0)).is_equal(0)
	assert_bool(FarmScreen.plant(save, 0)).is_false()
	assert_bool(FarmScreen.can_work(save, false, 0)).is_false()
	assert_bool(FarmScreen.can_work(save, true, 0)).is_false()
	assert_int(FarmScreen.cursor_for(save, FarmScreen.square(0).get_center(), false)).is_equal(FarmScreen.POINT)
	SaveManager.save = save
	var screen: FarmScreen = auto_free(load("res://entities/farm_screen/farm_screen.tscn").instantiate())
	add_child(screen)
	screen._press(FarmScreen.square(0).get_center())
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)
	assert_bool(FarmScreen.clear_rot(save, 0)).is_false()


func test_green_thumb_doubles_a_hand_harvest_but_not_a_tractors() -> void:
	var save := _ripe_square(["green_thumb"])
	assert_int(FarmScreen.harvest(save, 0, true)).is_equal(6)
	save = _ripe_square(["green_thumb"])
	assert_int(FarmScreen.harvest(save, 0)).is_equal(3)
	save = _ripe_square()
	assert_int(FarmScreen.harvest(save, 0, true)).is_equal(3)


func test_a_ripe_squares_label_shows_what_a_hand_pull_gives_green_thumb_included() -> void:
	assert_str(FarmScreen.ripe_label(_ripe_square())).is_equal("x3 ")
	assert_str(FarmScreen.ripe_label(_ripe_square(["green_thumb"]))).is_equal("x6 ")


func test_a_doubled_hand_harvest_waits_while_it_would_overfill_storage() -> void:
	var save := _ripe_square(["green_thumb"])
	save.storage_cap = 5
	assert_int(FarmScreen.harvest(save, 0, true)).is_equal(0)
	assert_bool(FarmScreen.is_ripe(save, 0)).is_true()


func test_one_in_one_out_replants_a_square_the_player_pulls_by_hand() -> void:
	var save := _ripe_square(["green_thumb"])
	save.hand_replant = 1
	var seeds := save.farm_seeds
	FarmScreen.harvest(save, 0, true)
	assert_float(save.farm_growth[0]).is_equal(0.0)
	assert_int(save.farm_seeds).is_equal(seeds - 1)
	save.farm_seeds = 0
	FarmScreen.tick(save, FarmScreen.GROW_TIME)
	FarmScreen.harvest(save, 0, true)
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)


func test_a_tractors_harvest_is_not_replanted_by_one_in_one_out_the_square_waits_for_a_farm_hand() -> void:
	var save := _ripe_squares(1)
	save.hand_replant = 1
	var seeds := save.farm_seeds
	var workers := _crew(save, true)
	assert_bool(_run_until(workers, save, func() -> bool: return save.farm_harvests > 0)).is_true()
	assert_float(save.farm_growth[0]).is_equal(FarmScreen.EMPTY)
	assert_int(save.farm_seeds).is_equal(seeds)
	assert_int(save.hand_planted).is_equal(0)


func test_a_farm_hand_still_plants_the_squares_tractors_empty_when_one_in_one_out_is_owned() -> void:
	var save := _ripe_squares(1)
	save.hand_replant = 1
	save.farm_hands = 1
	save.farm_tractors = 1
	save.farm_hand_route = 1
	save.farm_tractor_route = 1
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	assert_bool(_run_until(workers, save, func() -> bool: return save.farm_harvests > 0)).is_true()
	assert_bool(_run_until(workers, save, func() -> bool: return save.farm_hand_planted > 0, 60.0)).is_true()


func test_a_hand_pulled_square_replanted_at_once_counts_as_planted_by_hand() -> void:
	var save := _ripe_squares(1)
	save.hand_replant = 1
	FarmScreen.harvest(save, 0, true)
	assert_int(save.hand_planted).is_equal(1)
	assert_int(save.farm_hand_planted).is_equal(0)


func test_a_hand_harvest_shows_its_units_and_green_thumbs_multiplier_over_the_square() -> void:
	var save := _farm()
	assert_str(FarmScreen.pop_text(3, save)).is_equal("+3")
	save.stamped.append("green_thumb")
	assert_str(FarmScreen.pop_text(6, save)).is_equal("+6  ×2")
	var ripe := _ripe_square(["green_thumb"])
	SaveManager.save = ripe
	var screen: FarmScreen = auto_free(load("res://entities/farm_screen/farm_screen.tscn").instantiate())
	add_child(screen)
	screen._press(FarmScreen.square(0).get_center())
	screen._drag(FarmScreen.square(0).get_center() + Vector2(FarmScreen.PULL_DISTANCE, 0))
	assert_int(ripe.stock).is_equal(6)
	assert_str(screen._pop).is_equal("+6  ×2")
	assert_float(screen._pop_left).is_greater(0.0)


func test_units_harvested_by_hand_and_by_tractor_are_counted_apart() -> void:
	var save := _ripe_squares(3)
	var by_hand := FarmScreen.harvest(save, 0, true)
	var by_tractor := FarmScreen.harvest(save, 1) + FarmScreen.harvest(save, 2)
	assert_int(save.hand_harvested).is_equal(by_hand)
	assert_int(save.tractor_harvested).is_equal(by_tractor)
	assert_int(save.farm_harvests).is_equal(3)


func test_a_seed_the_player_plants_counts_as_planted_by_hand() -> void:
	var save := _farm()
	var screen := _screen(save)
	screen._press(BOX.get_center())
	screen._release(_at(0))
	assert_int(save.hand_planted).is_equal(1)


func test_squares_a_farm_hand_plants_count_as_the_farm_hands() -> void:
	var save := _farm()
	save.farm_hands = 1
	save.farm_hand_route = 1
	var workers: Array[FarmScreen.Worker] = []
	FarmScreen.sync_workers(workers, save)
	for k in 200:
		FarmScreen.work(workers, save, 0.1)
	assert_int(save.farm_hand_planted).is_equal(_planted(save))
	assert_int(save.hand_planted).is_equal(0)


func test_a_bought_farm_loaded_without_its_squares_has_every_square_before_the_first_draw() -> void:
	var save := SaveGame.new()
	save.stamped.append("family_farm")
	save.farm_plots = 8
	_screen(save)
	assert_int(save.farm_growth.size()).is_equal(8)
