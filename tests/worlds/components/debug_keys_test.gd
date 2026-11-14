extends GdUnitTestSuite

const DebugKeys := preload("res://worlds/components/debug_keys.gd")


func test_debug_key_3_puts_100_cabbages_into_stock_even_past_the_storage_cap() -> void:
	var save := SaveGame.new()
	save.stock = save.storage_cap
	var coins := save.coins

	DebugKeys.press(KEY_3, save)

	assert_int(save.stock).is_equal(save.storage_cap + 100)
	assert_int(save.coins).is_equal(coins)
	assert_int(save.sold).is_equal(0)


func test_debug_keys_1_and_2_sell_10_and_100_at_the_chalked_price() -> void:
	var save := SaveGame.new()
	var stock := save.stock

	DebugKeys.press(KEY_1, save)
	DebugKeys.press(KEY_2, save)

	assert_int(save.sold).is_equal(110)
	assert_int(save.coins).is_equal(SaveGame.new().coins + 110 * save.sale_price)
	assert_int(save.stock).is_equal(stock)


func test_debug_key_5_gives_the_company_one_more_farm_and_never_more_than_the_game_has() -> void:
	var save := SaveGame.new()
	DebugKeys.press(KEY_5, save)
	assert_array(Array(save.farms_owned)).is_equal(["K-1"])
	assert_int(save.coins).is_equal(SaveGame.new().coins)
	for i in 40:
		DebugKeys.press(KEY_5, save)
	assert_int(save.farms_owned.size()).is_equal(DebugKeys.Events.FARMS)
	# No farm twice.
	var seen := {}
	for id in save.farms_owned:
		seen[id] = true
	assert_int(seen.size()).is_equal(save.farms_owned.size())


func test_debug_key_5_gives_the_home_sites_not_yet_bought_on_the_map_first() -> void:
	var save := SaveGame.new()
	save.farms_owned = PackedStringArray(["K-2", "K-1"])  # Bought on the map.
	DebugKeys.press(KEY_5, save)
	DebugKeys.press(KEY_5, save)
	assert_array(Array(save.farms_owned)).is_equal(["K-2", "K-1", "K-3", "K-4"])


func test_debug_key_4_is_the_way_to_the_map_table_and_changes_nothing_in_the_save() -> void:
	var save := SaveGame.new()
	DebugKeys.press(DebugKeys.MAP_KEY, save)
	assert_int(DebugKeys.MAP_KEY).is_equal(KEY_4)
	assert_int(save.coins).is_equal(SaveGame.new().coins)
	assert_int(save.stock).is_equal(SaveGame.new().stock)
	assert_int(save.sold).is_equal(0)
	var table: Node = auto_free(load("res://entities/map_table/map_table.tscn").instantiate())
	assert_bool(table.is_in_group(&"map_table")).is_true()  # The key calls the group's toggle_view.
	assert_bool(table.has_method(&"toggle_view")).is_true()
