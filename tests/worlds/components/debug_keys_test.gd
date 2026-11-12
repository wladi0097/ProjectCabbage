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
