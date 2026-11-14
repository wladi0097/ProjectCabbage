extends GdUnitTestSuite

const Events := preload("res://globalScripts/game_events.gd")
const MapTally := preload("res://entities/map_table/props/map_tally.gd")
const SCENE := "res://entities/map_table/props/map_tally.tscn"
const WINDOWS := ["Coins", "Cabbages", "Findings", "Farms"]

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = _chapter_3()


func after_test() -> void:
	SaveManager.save = _real_save
	FarmTv.away = false


func _chapter_3() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation"])
	save.coin_limit = 200000  # The cash holding card: the purse is not full.
	save.coins = 84250
	save.storage_cap = 2000
	save.stock = 1250
	save.findings = 3120
	return save


func _tally() -> MapTally:
	var tally: MapTally = auto_free(load(SCENE).instantiate())
	add_child(tally)
	return tally


func _shown(tally: MapTally) -> Array:
	return WINDOWS.map(func(window: String) -> String: return (tally.get_node("Windows/" + window) as Label3D).text)


func test_the_tally_shows_coins_cabbages_research_and_farms() -> void:
	var save := SaveManager.save
	save.farms_owned = PackedStringArray(["K-1", "K-2"])
	assert_array(Array(MapTally.readout(save))).is_equal(["84K", "1,250", "3,120", "2/24"])
	assert_array(_shown(_tally())).is_equal(["84K", "1,250", "3,120", "2/24"])


func test_the_tally_prints_its_numbers_as_the_price_tags_and_the_field_line_do() -> void:
	var save := SaveManager.save
	save.coins = 5400000
	save.findings = 100000
	var texts := MapTally.readout(save)
	assert_str(texts[0]).is_equal(FarmRegister.short_coins(5400000)).is_equal("5.4M")
	assert_str(texts[2]).is_equal("100K")
	assert_str(texts[3]).is_equal(FieldLine.count_text(0, Events.FARMS))


func test_the_tally_changes_when_a_farm_is_bought() -> void:
	var tally := _tally()
	tally.live = true
	assert_bool(FarmRegister.buy(SaveManager.save, &"K-3")).is_true()
	tally.show_save(SaveManager.save)
	assert_array(_shown(tally)).is_equal(["24K", "450", "3,120", "1/24"])
	# What the farm cost and the farm itself flick over; the Findings it did not touch stay still.
	assert_array([0, 1, 2, 3].map(tally.flicking)).is_equal([true, true, false, true])


func test_a_window_that_flicks_over_comes_up_dim_and_ends_at_its_full_height_in_its_own_colour() -> void:
	var tally := _tally()
	var cabbages := tally.get_node("Windows/Cabbages") as Label3D
	var ink := cabbages.modulate
	tally.live = true
	SaveManager.save.stock = 900
	tally.show_save(SaveManager.save)
	tally._flicks[1].custom_step(0.01)
	assert_float(cabbages.scale.y).is_less(0.7)
	assert_float(cabbages.modulate.g).is_less(ink.g * 0.5)
	assert_float(cabbages.modulate.g).is_greater(cabbages.modulate.r)
	tally._flicks[1].custom_step(1.0)
	assert_float(cabbages.scale.y).is_equal_approx(1.0, 0.001)
	assert_bool(cabbages.modulate.is_equal_approx(ink)).is_true()


func test_a_number_that_ticks_all_the_time_flicks_once_and_then_changes_quietly() -> void:
	var tally := _tally()
	tally.live = true
	SaveManager.save.stock = 1249
	tally.show_save(SaveManager.save)
	tally._flicks[1].custom_step(1.0)
	SaveManager.save.stock = 1248
	tally.show_save(SaveManager.save)
	assert_array(_shown(tally)).contains(["1,248"])
	assert_bool(tally.flicking(1)).is_false()
	assert_bool(MapTally.rested(MapTally.REST)).is_true()
	assert_bool(MapTally.rested(0.5)).is_false()


func test_away_from_the_map_the_tally_follows_the_save_without_flicking() -> void:
	var tally := _tally()
	SaveManager.save.coins = 500
	tally._process(0.0)
	assert_array(_shown(tally)).is_equal(["500", "1,250", "3,120", "0/24"])
	assert_bool(tally.flicking(0)).is_false()


func test_only_the_cabbage_window_is_green_and_only_the_research_window_is_cyan() -> void:
	var tally := _tally()
	var ink := func(window: String) -> Color: return (tally.get_node("Windows/" + window) as Label3D).modulate
	assert_float(ink.call("Cabbages").g).is_greater(ink.call("Cabbages").r + 0.3)
	assert_float(ink.call("Cabbages").g).is_greater(ink.call("Cabbages").b + 0.3)
	assert_float(ink.call("Findings").b).is_greater(ink.call("Findings").r + 0.3)
	for plain: String in ["Coins", "Farms"]:
		assert_float(ink.call(plain).s).is_less(0.2)


func test_the_tally_is_hidden_until_the_map_table_is_unlocked() -> void:
	SaveManager.save = SaveGame.new()
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.make_current()
	var table: MapTable = auto_free(load("res://entities/map_table/map_table.tscn").instantiate())
	add_child(table)
	var tally := table.get_node("Tally") as MapTally
	assert_bool(tally.is_visible_in_tree()).is_false()
	SaveManager.save.stamped.append("consolidation")
	table._process(0.0)
	assert_bool(tally.is_visible_in_tree()).is_true()


func test_the_tally_flicks_only_while_the_camera_is_at_the_map() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.make_current()
	var table: MapTable = auto_free(load("res://entities/map_table/map_table.tscn").instantiate())
	add_child(table)
	var tally := table.get_node("Tally") as MapTally
	assert_bool(tally.live).is_false()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	assert_bool(tally.live).is_true()
	table.back_to_desk()
	table._pan_tween.custom_step(10.0)
	assert_bool(tally.live).is_false()


func test_a_window_at_its_limit_turns_red_and_flicks_over_and_turns_back_under_it() -> void:
	var tally := _tally()
	var save := SaveManager.save
	var coins := tally.get_node("Windows/Coins") as Label3D
	var ink := coins.modulate
	tally.live = true
	save.coins = save.coin_limit
	assert_array(MapTally.at_limit(save)).is_equal([true, false, false, false])
	tally.show_save(save)
	assert_bool(tally.flicking(0)).is_true()
	tally._flicks[0].custom_step(1.0)
	assert_bool(coins.modulate.is_equal_approx(MapTally.FULL_INK)).is_true()
	assert_float(MapTally.FULL_INK.r).is_greater(MapTally.FULL_INK.g + 0.5)
	assert_str(coins.text).is_equal(FarmRegister.short_coins(save.coin_limit))  # Still the number, no word.
	# A farm is paid for: under the limit again, at once, whenever the window last flicked.
	save.coins -= 1000
	tally.show_save(save)
	assert_bool(tally.flicking(0)).is_true()
	tally._flicks[0].custom_step(1.0)
	assert_bool(coins.modulate.is_equal_approx(ink)).is_true()


func test_only_coins_and_research_have_a_limit_on_the_tally() -> void:
	var save := SaveManager.save
	save.coins = save.coin_limit + 5  # An old save over its limit counts as full.
	save.findings = save.findings_limit
	save.stock = save.storage_cap
	save.farms_owned = PackedStringArray(["K-1"])
	assert_array(MapTally.at_limit(save)).is_equal([true, false, true, false])
	var tally := _tally()
	assert_bool((tally.get_node("Windows/Findings") as Label3D).modulate.is_equal_approx(MapTally.FULL_INK)).is_true()
	var cabbages := (tally.get_node("Windows/Cabbages") as Label3D).modulate
	assert_float(cabbages.g).is_greater(cabbages.r + 0.3)  # The cabbage window stays green.
