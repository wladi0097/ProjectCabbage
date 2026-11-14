extends GdUnitTestSuite

const WarSheet := preload("res://entities/map_table/war_sheet.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")

var _real_save: SaveGame
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = _at_war()
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	FarmRegister.lamp_held = false
	BossReport.hold = 0.0
	SaveManager.save = _real_save
	TranslationServer.set_locale(_locale)


## Five home farms, the war card, enough for any war.
func _at_war() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation", "negotiation", "bribery", "war_mode"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	save.coin_limit = 100000000
	save.coins = 50000000
	save.storage_cap = 100000
	save.stock = 50000
	return save


func _sheet(farm := &"K-6") -> WarSheet:
	var sheet: WarSheet = auto_free(load("res://entities/map_table/war_sheet.tscn").instantiate())
	add_child(sheet)
	sheet.open = 1.0
	sheet.begin(farm, "Sennick Holding", "Kohlmark")
	return sheet


func _text(sheet: WarSheet, label: String) -> String:
	return (sheet.get_node("Page/Sheet/" + label) as Label).text


func test_winning_the_war_takes_that_one_farm_for_its_coins_and_cabbages() -> void:
	var save := _at_war()
	var bill: Dictionary = WorldRegister.COUNTRIES[WorldRegister.HOME].wars[0]
	assert_dict(WarSheet.price(save, &"K-7")).is_equal(bill)
	assert_bool(WarSheet.win(save, &"K-7")).is_true()
	assert_array(Array(save.farms_owned)).is_equal(["K-1", "K-2", "K-3", "K-4", "K-5", "K-7"])
	assert_int(save.coins).is_equal(50000000 - bill.coins)
	assert_int(save.stock).is_equal(50000 - bill.stock)
	assert_bool(WarSheet.win(save, &"K-7")).is_false()  # Once.
	assert_dict(WarSheet.price(save, &"K-6")).is_equal(WorldRegister.COUNTRIES[WorldRegister.HOME].wars[1])


func test_a_war_that_cannot_be_paid_for_is_not_won_and_costs_nothing() -> void:
	for lacking: String in ["coins", "stock"]:
		var poor := _at_war()
		poor.set(lacking, WarSheet.price(poor, &"K-6")[lacking] - 1)
		var coins := poor.coins
		var stock := poor.stock
		assert_bool(WarSheet.win(poor, &"K-6")).is_false()
		assert_int(poor.farms_owned.size()).is_equal(5)
		assert_int(poor.coins).is_equal(coins)
		assert_int(poor.stock).is_equal(stock)
		assert_dict(WarSheet.short(poor, &"K-6")).is_equal({lacking: 1})
	var save := _at_war()
	save.stock = WarSheet.price(save, &"K-6").stock + 3
	assert_bool(WarSheet.win(save, &"K-6", Vector2i(4, 0))).is_false()  # 4 of them lie on the mat.
	assert_bool(WarSheet.win(save, &"K-6", Vector2i(3, 0))).is_true()


func test_the_war_sheet_names_the_farm_its_country_and_what_victory_costs() -> void:
	var sheet := _sheet(&"K-6")
	var bill: Dictionary = WorldRegister.COUNTRIES[WorldRegister.HOME].wars[0]
	assert_str(_text(sheet, "Farm")).is_equal("Sennick Holding  (K-6)")
	assert_str(_text(sheet, "Country")).is_equal("Kohlmark")
	assert_str(_text(sheet, "Coins")).is_equal("$" + FarmScreen._thousands(bill.coins))
	assert_str(_text(sheet, "Cabbages")).is_equal("%s cabbages" % FarmScreen._thousands(bill.stock))
	assert_str(_text(sheet, "CoinsShort")).is_empty()
	SaveManager.save.coins = bill.coins - 500
	sheet._process(0.0)
	assert_str(_text(sheet, "CoinsShort")).is_equal("SHORT $500")
	assert_str(sheet.hint(WarSheet.VICTORY)).ends_with("Short: $500.")


func test_a_farm_abroad_is_printed_with_its_countrys_initial() -> void:
	assert_str(FarmDeed.code("K-3")).is_equal("K-3")
	assert_str(FarmDeed.code("ostrevia-1")).is_equal("O-1")
	assert_str(FarmDeed.code("lower_provinces-2")).is_equal("L-2")


func test_only_the_declare_victory_box_takes_a_click() -> void:
	var sheet := _sheet()
	assert_str(sheet.spot_at(sheet.victory_box.get_center())).is_equal(WarSheet.VICTORY)
	assert_str(sheet.spot_at(sheet.victory_box.position - Vector2(20, 20))).is_equal(&"")
	assert_bool(MapSheet.SIZE.x * MapSheet.PIXELS_PER_METRE > sheet.victory_box.end.x).is_true()
	var box: Array = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).war_map.victory_box
	assert_bool(sheet.victory_box.is_equal_approx(Rect2(box[0], box[1], box[2], box[3]))).is_true()
	# The hint slip lies on the paper, clear of the box.
	var slip := Rect2(sheet.hint_pixel(), Vector2(760, 240))
	assert_bool(Rect2(Vector2.ZERO, MapSheet.SIZE * MapSheet.PIXELS_PER_METRE).encloses(slip)).is_true()
	assert_bool(slip.intersects(sheet.victory_box)).is_false()


func test_declaring_victory_stamps_it_and_asks_for_the_farms_country_sheet_again() -> void:
	var sheet := _sheet(&"K-6")
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	sheet.press(WarSheet.VICTORY)
	assert_bool(SaveManager.save.farms_owned.has("K-6")).is_true()
	assert_bool((sheet.get_node("Page/Sheet/Imprint") as Label).visible).is_true()
	assert_bool((sheet.get_node("Strike") as SoundCue).playing).is_true()
	assert_bool(FarmRegister.lamp_held).is_true()
	assert_float(BossReport.hold).is_greater(MapTable.swap_time())  # The boss's paper waits for the moment.
	assert_bool(sheet.busy()).is_true()
	assert_str(sheet.spot_at(sheet.victory_box.get_center())).is_equal(&"")  # Once.
	assert_array(wanted).is_empty()
	sheet._dealing.custom_step(WarSheet.LEAVE_AFTER + 0.01)
	assert_array(wanted).is_equal([[WorldRegister.HOME, &"K-6"]])
	assert_bool(sheet.busy()).is_false()


func test_a_victory_not_paid_for_is_refused_and_what_is_short_flashes() -> void:
	SaveManager.save.coins = 10
	var sheet := _sheet()
	sheet.press(WarSheet.VICTORY)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)
	assert_object(sheet._dealing).is_null()
	assert_object(sheet._blinking).is_not_null()
	assert_bool((sheet.get_node("Denied") as SoundCue).playing).is_true()
	assert_bool((sheet.get_node("Page/Sheet/Imprint") as Label).visible).is_false()


func test_a_victory_goes_into_the_playtest_log_and_is_written_to_the_save_at_once() -> void:
	var sheet := _sheet(&"K-6")
	var bill := WarSheet.price(SaveManager.save, &"K-6")
	SaveManager.save.last_played = 0
	sheet.press(WarSheet.VICTORY)
	assert_int(SaveManager.save.last_played).is_greater(0)
	var rows := SaveManager.save.playtest_log.map(func(row: Dictionary) -> Array: return [row.kind, row.id, row.price, row.currency])
	assert_array(rows).contains_exactly([["war_won", "K-6", bill.coins, "coins"], ["war_won", "K-6", bill.stock, "stock"]])


func test_the_war_sheet_is_german_in_german_and_still_says_cabbages() -> void:
	TranslationServer.set_locale("de")
	var sheet := _sheet()
	assert_str(_text(sheet, "Cabbages")).contains("Kohlköpfe")
	for key: String in ["DECLARE VICTORY", "FIELD DISPATCH", "FORM 9-T  THEATRE OF OPERATIONS", "Declare victory. Cost: %s."]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
