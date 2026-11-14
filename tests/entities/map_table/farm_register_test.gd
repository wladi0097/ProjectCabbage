extends GdUnitTestSuite

const Events := preload("res://globalScripts/game_events.gd")
const Report := preload("res://entities/boss_report/boss_report.gd")
const DebugKeys := preload("res://worlds/components/debug_keys.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")
const SITES := ["K-1", "K-2", "K-3", "K-4", "K-5", "K-6", "K-7", "K-8"]

var _real_save: SaveGame
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = _rich()
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	FarmRegister.lamp_held = false
	SaveManager.save = _real_save
	TranslationServer.set_locale(_locale)


## A save that can pay for every farm, with the cards the farms wait for stamped (`cards`).
func _rich(cards := ["negotiation", "bribery"]) -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation"] + cards)
	save.coins = 10000000
	save.storage_cap = 30000
	save.stock = 30000
	return save


func _register() -> FarmRegister:
	var sheet: FarmRegister = auto_free(load("res://entities/map_table/country_sheet.tscn").instantiate())
	add_child(sheet)
	sheet.open = 1.0  # Lying open on the table.
	for i in sheet.thing_count():
		sheet.raise_thing(1.0, i)
	return sheet


## Lays out `site`'s deed, stamps it and lets the whole purchase play out, until the deed is gone.
func _buy(sheet: FarmRegister, site: String) -> void:
	sheet.press(StringName(site))
	sheet.press(FarmRegister.STAMP)
	_play_out(sheet)


## Runs the purchase in progress to its end.
func _play_out(sheet: FarmRegister) -> void:
	if sheet._dealing != null:
		sheet._dealing.custom_step(10.0)


## The art pixel in the middle of the laid-out deed's stamp box.
func _box(sheet: FarmRegister) -> Vector2:
	return sheet._deed_corner + FarmDeed.STAMP_BOX.get_center()


## How far each parcel reaches on the land layer (px), by site; the head office's patch is "HQ".
func _reach(sheet: FarmRegister) -> Dictionary:
	var layer := sheet.get_node("Page/Sheet/Layers/Parcels") as CanvasItem
	var sites: PackedVector3Array = (layer.material as ShaderMaterial).get_shader_parameter(&"sites")
	var out := {"HQ": sites[sites.size() - 1].z}
	for site: StringName in sheet._sites:
		for entry in sites:
			if Vector2(entry.x, entry.y).is_equal_approx(sheet._pixel(site)):
				out[String(site)] = entry.z
	return out


func _tag(sheet: FarmRegister, site: String) -> Label:
	return sheet.get_node("Page/Sheet/Price_" + site)


func _building(sheet: FarmRegister, site: String) -> MapBuilding:
	return sheet._sites[StringName(site)]


func test_a_farm_is_bought_with_its_price_in_coins_and_cabbages_and_only_once() -> void:
	var save := _rich()
	var bill := FarmRegister.price(save)
	assert_bool(FarmRegister.buy(save, &"K-3")).is_true()
	assert_array(Array(save.farms_owned)).is_equal(["K-3"])
	assert_int(save.coins).is_equal(10000000 - bill.coins)
	assert_int(save.stock).is_equal(30000 - bill.stock)
	assert_bool(FarmRegister.buy(save, &"K-3")).is_false()
	assert_array(Array(save.farms_owned)).is_equal(["K-3"])
	assert_int(save.coins).is_equal(10000000 - bill.coins)


func test_the_price_rises_with_every_farm_owned_whichever_site_is_bought() -> void:
	var save := _rich()
	var last := {coins = 0, stock = 0}
	for site: String in ["K-7", "K-2", "K-8", "K-1", "K-4"]:
		var bill := FarmRegister.price(save)
		assert_int(bill.coins).is_greater(last.coins)
		assert_int(bill.stock).is_greater(last.stock)
		last = bill
		assert_bool(FarmRegister.buy(save, StringName(site))).is_true()


func test_there_is_a_price_for_every_farm_that_is_sold_at_home() -> void:
	assert_int(FarmRegister.PRICES.size()).is_equal(Events.HOME_SELLERS)
	assert_int(FarmRegister.GATES.size()).is_equal(Events.HOME_SELLERS)


func test_a_farm_that_cannot_be_paid_for_is_refused_and_costs_nothing() -> void:
	for lacking: String in ["coins", "stock"]:
		var save := _rich()
		save.set(lacking, FarmRegister.price(save)[lacking] - 1)
		var coins := save.coins
		var stock := save.stock
		assert_bool(FarmRegister.buy(save, &"K-1")).is_false()
		assert_array(Array(save.farms_owned)).is_empty()
		assert_int(save.coins).is_equal(coins)
		assert_int(save.stock).is_equal(stock)
		assert_dict(FarmRegister.short(save)).is_equal({lacking: 1})


func test_cabbages_out_of_the_store_cannot_pay_for_a_farm() -> void:
	var save := _rich()
	save.stock = FarmRegister.price(save).stock + 3
	assert_bool(FarmRegister.buy(save, &"K-1", Vector2i(4, 0))).is_false()  # 4 of them lie on the mat.
	assert_bool(FarmRegister.buy(save, &"K-1", Vector2i(3, 0))).is_true()
	assert_int(save.stock).is_equal(3)


func test_farms_six_to_eight_are_not_for_sale_until_the_world_map_card_is_stamped() -> void:
	var save := _rich()
	for i in Events.HOME_SELLERS:
		assert_bool(FarmRegister.buy(save, StringName(SITES[i]))).is_true()
	var coins := save.coins
	assert_bool(FarmRegister.for_sale(save, &"K-6")).is_false()
	assert_bool(FarmRegister.buy(save, &"K-6")).is_false()
	assert_int(save.farms_owned.size()).is_equal(Events.HOME_SELLERS)
	assert_int(save.coins).is_equal(coins)
	assert_dict(FarmRegister.price(save)).is_empty()
	assert_dict(FarmRegister.seizure(save)).is_empty()
	save.stamped.append(FarmRegister.SEIZE_CARD)
	assert_str(FarmRegister.SEIZE_CARD).is_equal("world_map")
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.SEIZURES[0])
	assert_bool(FarmRegister.for_sale(save, &"K-6")).is_true()


func test_buying_the_first_farm_starts_the_first_farm_paper_and_the_fifth_the_no_more_sellers_paper() -> void:
	var save := _rich()
	save.reports = PackedStringArray(["welcome", "invest_in_growth"])
	assert_array(Report.due(save)).not_contains(["first_farm"])
	FarmRegister.buy(save, &"K-2")
	assert_array(Report.due(save)).contains(["first_farm"])
	for site: String in ["K-1", "K-3", "K-4"]:
		FarmRegister.buy(save, StringName(site))
	assert_bool(Events.due("no_more_sellers", save)).is_false()
	FarmRegister.buy(save, &"K-5")
	assert_bool(Events.due("no_more_sellers", save)).is_true()


func test_the_price_tag_prints_the_price_of_the_next_farm_in_coins_and_cabbages() -> void:
	var sheet := _register()
	for site: String in SITES:
		assert_str(_tag(sheet, site).text).is_equal("$60K + 800")
	_buy(sheet, "K-4")
	assert_str(_tag(sheet, "K-4").text).is_equal("ACQUIRED")
	assert_str(_tag(sheet, "K-1").text).is_equal("$200K + 2,000")
	assert_int((sheet.get_node("Page") as SubViewport).render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)


func test_the_boss_paper_waits_until_the_deed_has_left_and_a_pause_after_it() -> void:
	Report.hold = 0.0
	var sheet := _register()
	SaveManager.save.coins = 0
	sheet.press(&"K-4")
	sheet.press(FarmRegister.STAMP)  # Refused: nothing to wait for.
	assert_float(Report.hold).is_equal(0.0)
	SaveManager.save.coins = 10000000
	sheet.press(FarmRegister.STAMP)
	assert_float(Report.hold).is_equal(FarmRegister.deed_gone_after() + FarmRegister.PAPER_AFTER)
	# The deed is still on the map until deed_gone_after, and the land is seen before it leaves.
	sheet._dealing.custom_step(FarmRegister.deed_gone_after() - 0.05)
	assert_str(sheet.deed_site()).is_equal(&"K-4")
	sheet._dealing.custom_step(0.1)
	assert_str(sheet.deed_site()).is_equal(&"")
	assert_float(FarmRegister.deed_gone_after()).is_greater(FarmRegister.STAMP_DROP_TIME + FarmRegister.HIT_PAUSE + FarmRegister.PARCEL_TIME)
	assert_float(FarmRegister.deed_gone_after()).is_less(2.5)
	assert_float(FarmRegister.PAPER_AFTER).is_greater(0.5)
	assert_float(FarmRegister.PAPER_AFTER).is_less(2.0)
	Report.hold = 0.0


func test_every_price_and_word_a_tag_prints_fits_beside_its_eyelet_in_english_and_german() -> void:
	var sheet := _register()
	var tag := _tag(sheet, "K-1")
	var font := tag.get_theme_font(&"font")
	var sites: Array = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).country_map.farm_sites
	var box: Dictionary = sites[0].price_tag
	# The print stands 10 px right of the tag's middle; the eyelet takes the left 27 px, 6 px stay free on the right.
	var room := minf((box.w / 2.0 - 27.0 + 10.0) * 2.0, (box.w / 2.0 - 6.0 - 10.0) * 2.0)
	var texts: Array[String] = []
	for owned in FarmRegister.PRICES.size():
		var save := _rich()
		save.farms_owned.resize(owned)
		texts.append(FarmRegister.tag_text(save, &"K-1"))
	texts.append("$1.5M + 9,000")  # Millions fit too (the pacing sim wants $1.5M and $5M).
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for text in texts + [TranslationServer.translate("ACQUIRED"), TranslationServer.translate("NOT FOR SALE")]:
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.get_theme_font_size(&"font_size")).x
			assert_float(width).override_failure_message("%s (%d px) in %s" % [text, width, locale]).is_less(room)


func test_a_tag_sets_coins_in_thousands_from_ten_thousand_and_in_millions_from_a_million() -> void:
	assert_str(FarmRegister.short_coins(9500)).is_equal("9,500")
	assert_str(FarmRegister.short_coins(60000)).is_equal("60K")
	assert_str(FarmRegister.short_coins(950000)).is_equal("950K")
	assert_str(FarmRegister.short_coins(62400)).is_equal("62K")
	assert_str(FarmRegister.short_coins(999700)).is_equal("1M")
	assert_str(FarmRegister.short_coins(1500000)).is_equal("1.5M")
	assert_str(FarmRegister.short_coins(5000000)).is_equal("5M")


func test_clicking_a_farm_lays_out_its_deed_and_buys_nothing() -> void:
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	assert_bool(deed.visible).is_false()
	sheet.press(&"K-5")
	assert_array(Array(SaveManager.save.farms_owned)).is_empty()
	assert_int(SaveManager.save.coins).is_equal(10000000)
	assert_bool(_building(sheet, "K-5").owned).is_false()
	assert_bool(deed.visible).is_true()
	assert_str(sheet.deed_site()).is_equal(&"K-5")
	assert_str(deed.site).is_equal(&"K-5")
	assert_str((deed.get_node("Page/Form/Title") as Label).text).is_equal("Weiler Marsh Holding")
	assert_str((deed.get_node("Page/Form/Site") as Label).text).is_equal("FARM SITE K-5")
	assert_str((deed.get_node("Page/Form/Coins") as Label).text).is_equal("$60,000")
	assert_str((deed.get_node("Page/Form/Cabbages") as Label).text).is_equal("800 cabbages")
	assert_dict(deed.bill).is_equal(FarmRegister.PRICES[0])
	assert_bool(deed.stamped).is_false()
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_true()


func test_stamping_the_deed_buys_the_farm() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)
	sheet.press(FarmRegister.STAMP)
	assert_array(Array(SaveManager.save.farms_owned)).is_equal(["K-5"])
	assert_int(SaveManager.save.coins).is_equal(10000000 - FarmRegister.PRICES[0].coins)
	assert_int(SaveManager.save.stock).is_equal(30000 - FarmRegister.PRICES[0].stock)
	_play_out(sheet)
	assert_bool(_building(sheet, "K-5").get_node("Owned").visible).is_true()
	assert_bool(_building(sheet, "K-4").owned).is_false()
	assert_bool(sheet.get_node("Flash").visible).is_true()  # The flash of the acquisition, on the site.
	assert_float(sheet.get_node("Flash").position.x).is_equal_approx(_building(sheet, "K-5").position.x, 0.001)
	assert_bool((sheet.get_node("Deed") as FarmDeed).stamped).is_true()
	sheet.press(&"K-5")  # Ours already: no deed, nothing more is paid.
	assert_str(sheet.deed_site()).is_equal(&"")
	assert_int(SaveManager.save.coins).is_equal(10000000 - FarmRegister.PRICES[0].coins)


func test_the_token_and_the_land_change_when_the_stamp_has_landed_and_the_pattern_spreads_from_the_token() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	sheet.press(FarmRegister.STAMP)
	assert_bool(_building(sheet, "K-5").owned).is_false()  # Paid for; the stamp is still falling.
	assert_str(_tag(sheet, "K-5").text).is_equal("$60K + 800")
	assert_float(_reach(sheet)["K-5"]).is_equal(0.0)
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + FarmRegister.HIT_PAUSE + 0.01)
	assert_bool(_building(sheet, "K-5").owned).is_true()
	assert_str(_tag(sheet, "K-5").text).is_equal("ACQUIRED")
	assert_float(_reach(sheet)["K-5"]).is_equal(0.0)  # The spread starts at the token.
	sheet._spread_tween.custom_step(FarmRegister.PARCEL_TIME * 0.3)
	assert_float(_reach(sheet)["K-5"]).is_between(1.0, FarmRegister.PARCEL_RADIUS - 1.0)
	sheet._spread_tween.custom_step(FarmRegister.PARCEL_TIME)
	assert_float(_reach(sheet)["K-5"]).is_equal(FarmRegister.PARCEL_RADIUS)
	assert_float(_reach(sheet)["K-4"]).is_equal(0.0)
	assert_float(FarmRegister.PARCEL_TIME).is_between(0.4, 1.2)  # A short reveal.
	assert_float(FarmRegister.HIT_PAUSE).is_between(0.05, 0.15)


func test_an_owned_farms_parcel_shows_the_cabbage_pattern_after_a_reload() -> void:
	var sheet := _register()
	_buy(sheet, "K-3")
	sheet._spread_tween.custom_step(10.0)
	assert_float(_reach(sheet)["K-3"]).is_equal(FarmRegister.PARCEL_RADIUS)
	var loaded := _register()  # The same save, a fresh sheet.
	var reach := _reach(loaded)
	for site: String in SITES:
		assert_float(reach[site]).is_equal(FarmRegister.PARCEL_RADIUS if site == "K-3" else 0.0)
	assert_float(reach["HQ"]).is_greater(0.0)  # The head office is company land from the start.
	assert_bool(loaded._moving.is_empty()).is_true()  # Without the moment.


func test_the_land_layer_greys_the_country_over_the_sheets_own_art() -> void:
	var sheet := _register()
	var layer := sheet.get_node("Page/Sheet/Layers/Parcels") as TextureRect
	assert_object(layer.texture).is_same((sheet.get_node("Page/Sheet/Art") as TextureRect).texture)
	assert_str(((layer.material as ShaderMaterial).shader as Shader).resource_path).is_equal("res://assets/shaders/farm_parcels.gdshader")
	# Every site reaches at least to the next one, so neighbours share a fence and leave no gap.
	for site: StringName in sheet._sites:
		var nearest := 1e9
		for other: StringName in sheet._sites:
			if other != site:
				nearest = minf(nearest, sheet._pixel(site).distance_to(sheet._pixel(other)))
		assert_float(FarmRegister.PARCEL_RADIUS).is_greater(nearest / 2.0)


func test_the_stamp_stays_up_when_the_price_cannot_be_paid() -> void:
	SaveManager.save.coins = 10
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-1")
	assert_str((deed.get_node("Page/Form/CoinsShort") as Label).text).is_equal("SHORT $59,990")
	assert_str((deed.get_node("Page/Form/CabbagesShort") as Label).text).is_equal("")
	sheet.press(FarmRegister.STAMP)
	assert_array(Array(SaveManager.save.farms_owned)).is_empty()
	assert_int(SaveManager.save.coins).is_equal(10)
	assert_object(sheet._dealing).is_null()
	assert_bool((deed.get_node("Stamp") as Node3D).visible).is_false()
	assert_bool(deed.stamped).is_false()
	assert_bool(_building(sheet, "K-1").owned).is_false()
	assert_bool(sheet.get_node("Flash").visible).is_false()
	assert_str(_tag(sheet, "K-1").text).is_equal("$60K + 800")
	assert_bool(sheet._moving.has(&"K-1")).is_true()  # It shakes its head.
	assert_object(deed._blinking).is_not_null()  # What is short flashes.
	assert_str(sheet.deed_site()).is_equal(&"K-1")  # The deed stays.


func test_the_deed_marks_what_is_short_as_the_save_changes() -> void:
	SaveManager.save.coins = 59000
	SaveManager.save.stock = 790
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-1")
	assert_str((deed.get_node("Page/Form/CoinsShort") as Label).text).is_equal("SHORT $1,000")
	assert_str((deed.get_node("Page/Form/CabbagesShort") as Label).text).is_equal("SHORT 10")
	SaveManager.save.coins = 60000
	sheet._process(0.0)
	assert_str((deed.get_node("Page/Form/CoinsShort") as Label).text).is_equal("")
	assert_str((deed.get_node("Page/Form/CabbagesShort") as Label).text).is_equal("SHORT 10")


func test_a_farm_not_for_sale_gets_a_deed_without_a_stamp_box() -> void:
	SaveManager.save = _rich([])
	SaveManager.save.farms_owned = PackedStringArray(["K-1"])
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
	assert_bool(deed.visible).is_true()
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_true()
	assert_str((deed.get_node("Page/Form/Strip/Word") as Label).text).is_equal("NOT FOR SALE")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	assert_dict(deed.bill).is_empty()
	assert_str(sheet.spot_at(_box(sheet))).is_equal(&"")  # Nothing to stamp.
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(1)
	assert_int(SaveManager.save.coins).is_equal(10000000)
	# The card comes: the deed lying there gets its price and its stamp box.
	SaveManager.save.stamped.append("negotiation")
	sheet._process(0.0)
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)


func test_a_deed_not_for_sale_says_the_owners_need_persuading_until_the_card_and_unavailable_after_five_farms() -> void:
	var save := _rich([])
	save.farms_owned = PackedStringArray(["K-1"])
	assert_str(FarmRegister.reason(save)).is_equal("The owners will need persuading.")
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4"])
	save.stamped.append("negotiation")
	assert_str(FarmRegister.reason(save)).is_equal("The owners will need persuading.")  # BRIBERY is not stamped.
	save.farms_owned.append("K-5")
	save.stamped.append("bribery")
	assert_str(FarmRegister.reason(save)).is_equal("The owner is unavailable.")
	TranslationServer.set_locale("de")
	assert_str(FarmRegister.reason(save)).is_equal("Der Eigentümer ist nicht erreichbar.")
	save.farms_owned = PackedStringArray(["K-1"])
	save.stamped = PackedStringArray(["consolidation"])
	assert_str(FarmRegister.reason(save)).is_equal("Die Eigentümer müssen erst überzeugt werden.")
	SaveManager.save = save
	var sheet := _register()
	sheet.press(&"K-2")
	assert_str((sheet.get_node("Deed/Page/Form/Reason") as Label).text).is_equal("Die Eigentümer müssen erst überzeugt werden.")
	assert_bool((sheet.get_node("Deed/Page/Form/Reason") as Label).visible).is_true()


func test_clicking_elsewhere_or_the_same_farm_again_puts_the_deed_away() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	sheet.press(&"")  # The bare sheet.
	assert_str(sheet.deed_site()).is_equal(&"")
	sheet.press(&"K-5")
	sheet.press(&"K-5")
	assert_str(sheet.deed_site()).is_equal(&"")
	sheet.press(&"K-5")
	sheet.press(&"K-4")  # Another farm: its deed instead.
	assert_str(sheet.deed_site()).is_equal(&"K-4")
	assert_array(Array(SaveManager.save.farms_owned)).is_empty()


func test_no_click_is_taken_while_a_purchase_plays_out() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	sheet.press(FarmRegister.STAMP)
	sheet.press(&"K-4")
	sheet.press(&"")
	assert_str(sheet.deed_site()).is_equal(&"K-5")
	assert_str(sheet.spot_at(_box(sheet))).is_equal(&"")  # The box is stamped once.
	_play_out(sheet)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(1)
	sheet.press(&"K-4")
	assert_str(sheet.deed_site()).is_equal(&"K-4")


func test_the_deed_lies_beside_its_farm_inside_the_sheet_and_never_on_the_farm() -> void:
	var paper := Rect2(Vector2.ZERO, MapSheet.SIZE * MapSheet.PIXELS_PER_METRE)
	var sites: Array = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).country_map.farm_sites
	for site: Dictionary in sites:
		var at := Vector2(site.x, site.y)
		var deed := Rect2(FarmRegister.deed_corner(at), FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE)
		assert_bool(paper.encloses(deed)).override_failure_message("%s: off the sheet" % site.id).is_true()
		var hit := Rect2(FarmRegister.HIT.position + at, FarmRegister.HIT.size)
		assert_bool(deed.intersects(hit)).override_failure_message("%s: its deed covers it" % site.id).is_false()
		assert_float(absf(deed.get_center().y - at.y)).is_less(FarmDeed.SIZE.y * FarmDeed.PIXELS_PER_METRE / 2.0)  # Level with it.


func test_the_deed_covers_what_lies_under_it_and_tucks_those_tokens_away() -> void:
	var sheet := _register()
	sheet.press(&"K-4")  # Its deed lies to the right, over K-7.
	var under := sheet._pixel(&"K-7")
	assert_bool(Rect2(sheet._deed_corner, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE).has_point(under)).is_true()
	assert_str(sheet.spot_at(under)).is_equal(&"")
	assert_str(sheet.spot_at(sheet._pixel(&"K-4"))).is_equal(&"K-4")
	sheet._moving[&"K-7"].custom_step(1.0)
	assert_bool(sheet.thing_up(sheet._index(&"K-7"))).is_false()
	assert_bool(sheet.thing_up(sheet._index(&"K-4"))).is_true()
	sheet.press(&"")
	sheet._moving[&"K-7"].custom_step(1.0)
	assert_bool(sheet.thing_up(sheet._index(&"K-7"))).is_true()
	assert_str(sheet.spot_at(under)).is_equal(&"K-7")


func test_the_hint_slip_is_silent_while_a_deed_lies_on_the_sheet() -> void:
	var sheet := _register()
	assert_str(sheet.hint(&"K-1")).is_not_empty()
	sheet.press(&"K-1")
	assert_str(sheet.hint(&"K-1")).is_empty()
	assert_str(sheet.hint(FarmRegister.STAMP)).is_empty()
	sheet.press(&"")
	assert_str(sheet.hint(&"K-1")).is_not_empty()


func test_the_deed_goes_at_once_when_its_sheet_is_rolled_up() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	sheet.open = 0.9
	sheet._process(0.0)
	assert_str(sheet.deed_site()).is_equal(&"")
	assert_bool((sheet.get_node("Deed") as FarmDeed).visible).is_false()


func test_a_bought_farm_shows_as_owned_when_the_save_is_loaded_without_the_moment() -> void:
	SaveManager.save.farms_owned = PackedStringArray(["K-3", "K-6"])
	var sheet := _register()
	for site: String in SITES:
		var ours := site in ["K-3", "K-6"]
		assert_bool(_building(sheet, site).owned).is_equal(ours)
		assert_str(_tag(sheet, site).text).is_equal("ACQUIRED" if ours else "$450K + 3,500")
	assert_bool(sheet.get_node("Flash").visible).is_false()
	assert_bool(sheet._moving.is_empty()).is_true()
	# The company's ink on what is ours.
	assert_bool(_tag(sheet, "K-3").get_theme_color(&"font_color").is_equal_approx(FarmRegister.OXBLOOD)).is_true()
	assert_bool(_tag(sheet, "K-1").get_theme_color(&"font_color").is_equal_approx(FarmRegister.OXBLOOD)).is_false()


func test_a_farm_that_arrives_any_other_way_shows_as_owned_too() -> void:
	var sheet := _register()
	DebugKeys.press(KEY_5, SaveManager.save)
	sheet._process(0.0)
	assert_bool(_building(sheet, "K-1").owned).is_true()
	assert_str(_tag(sheet, "K-2").text).is_equal("$200K + 2,000")


func test_once_five_are_owned_the_other_sites_are_not_for_sale_and_a_click_buys_nothing() -> void:
	SaveManager.save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	var sheet := _register()
	for site: String in ["K-6", "K-7", "K-8"]:
		assert_str(_tag(sheet, site).text).is_equal("NOT FOR SALE")
		sheet.press(StringName(site))
		sheet.press(FarmRegister.STAMP)
		assert_bool(_building(sheet, site).owned).is_false()
	sheet.press(&"")  # The deed away: the hint slip speaks again.
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)
	assert_int(SaveManager.save.coins).is_equal(10000000)
	assert_str(sheet.hint(&"K-7")).is_equal("Kalden Holding. Not for sale. The owner is unavailable.")


func test_the_hint_of_a_farm_not_for_sale_gives_the_same_reason_as_its_deed() -> void:
	SaveManager.save = _rich([])
	SaveManager.save.farms_owned = PackedStringArray(["K-1"])
	var sheet := _register()
	assert_str(sheet.hint(&"K-2")).is_equal("Mittelfeld Holding. Not for sale. " + FarmRegister.reason(SaveManager.save))
	assert_str(sheet.hint(&"K-2")).contains("The owners will need persuading.")
	TranslationServer.set_locale("de")
	assert_str(sheet.hint(&"K-2")).ends_with("Unverkäuflich. Die Eigentümer müssen erst überzeugt werden.")


func test_the_hint_names_the_site_with_its_price_what_is_short_and_what_is_ours() -> void:
	var sheet := _register()
	assert_str(sheet.hint(&"K-1")).is_equal("Grauhaven Holding. Price: $60,000, 800 cabbages. Click for the deed.")
	SaveManager.save.coins = 59000
	SaveManager.save.stock = 790
	assert_str(sheet.hint(&"K-1")).is_equal("Grauhaven Holding. Price: $60,000, 800 cabbages. Short: $1,000, 10 cabbages.")
	SaveManager.save.coins = 60000
	assert_str(sheet.hint(&"K-1")).is_equal("Grauhaven Holding. Price: $60,000, 800 cabbages. Short: 10 cabbages.")
	SaveManager.save.farms_owned.append("K-1")
	assert_str(sheet.hint(&"K-1")).is_equal("Grauhaven Holding. Company property.")


func test_the_tags_and_the_hint_are_german_in_german_and_still_say_cabbages() -> void:
	TranslationServer.set_locale("de")
	var sheet := _register()
	assert_str(sheet.hint(&"K-1")).is_equal("Grauhaven Holding. Preis: $60,000, 800 Kohlköpfe. Klicken für die Urkunde.")
	_buy(sheet, "K-1")
	assert_str(_tag(sheet, "K-1").text).is_equal("ERWORBEN")
	SaveManager.save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	sheet._process(0.0)
	assert_str(_tag(sheet, "K-8").text).is_equal("UNVERKÄUFLICH")
	for text: String in [sheet.hint(&"K-8"), sheet.hint(&"K-1")]:
		assert_bool(text.to_lower().contains("einheit")).is_false()


func test_a_site_is_pointed_at_on_its_disc_and_its_two_tags_and_nowhere_else() -> void:
	var sheet := _register()
	var sites: Array = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).country_map.farm_sites
	assert_int(sites.size()).is_equal(8)
	for site: Dictionary in sites:
		for pixel: Vector2 in [Vector2(site.x, site.y), Vector2(site.name_tag.x, site.name_tag.y), Vector2(site.price_tag.x, site.price_tag.y)]:
			assert_str(sheet.spot_at(pixel)).is_equal(site.id)
	assert_str(sheet.spot_at(Vector2(300, 300))).is_equal(&"")  # The sea.
	assert_str(sheet.spot_at(Vector2(-1, -1))).is_equal(&"")  # Off the paper.
	assert_str(sheet.spot_at(Vector2(1304, 1295))).is_equal(&"")  # The capital.


func test_a_hovered_site_stands_taller_and_comes_down_when_the_mouse_leaves() -> void:
	var sheet := _register()
	sheet.hover(&"K-2")
	sheet._moving[&"K-2"].custom_step(1.0)
	assert_float(sheet._raised(&"K-2")).is_equal_approx(FarmRegister.HOVER_SCALE, 0.001)
	sheet.hover(&"back")  # Anything that is not one of its sites.
	sheet._moving[&"K-2"].custom_step(1.0)
	assert_float(sheet._raised(&"K-2")).is_equal_approx(1.0, 0.001)


func test_an_acquisition_sounds_its_seal_and_a_refusal_only_the_tokens_wobble() -> void:
	var sheet := _register()
	var acquire := sheet.get_node("Flash/Acquire") as SoundCue
	var refuse := sheet.get_node("Flash/Refuse") as SoundCue
	assert_object(acquire.stream).is_not_null()
	assert_object(refuse.stream).is_not_null()
	_buy(sheet, "K-5")
	assert_bool(acquire.playing).is_true()
	assert_bool(refuse.playing).is_false()
	acquire.stop()
	SaveManager.save.coins = 10
	sheet.press(&"K-1")
	sheet.press(FarmRegister.STAMP)
	assert_bool(refuse.playing).is_true()
	assert_bool(acquire.playing).is_false()


func test_every_step_of_the_purchase_has_its_sound_in_order() -> void:
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	for cue: String in ["Slide", "Strike", "Denied", "Roll"]:
		assert_object((deed.get_node(cue) as SoundCue).stream).override_failure_message(cue).is_not_null()
	sheet.press(&"K-5")
	assert_bool((deed.get_node("Slide") as SoundCue).playing).is_true()  # The deed slides in.
	sheet.press(FarmRegister.STAMP)
	assert_bool((deed.get_node("Strike") as SoundCue).playing).is_false()  # The stamp is still falling.
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + 0.01)
	assert_bool((deed.get_node("Strike") as SoundCue).playing).is_true()  # The desk press's thunk.
	assert_bool((sheet.get_node("Flash/Acquire") as SoundCue).playing).is_false()  # The hit pause.
	sheet._dealing.custom_step(FarmRegister.HIT_PAUSE)
	assert_bool((sheet.get_node("Flash/Acquire") as SoundCue).playing).is_true()  # The token's thunk.
	assert_bool(FarmRegister.lamp_held).is_true()
	sheet._dealing.custom_step(FarmRegister.LAMP_AFTER)
	assert_bool(FarmRegister.lamp_held).is_false()  # The Field Line lights its lamp now, its relay heard at the map.
	assert_bool((deed.get_node("Roll") as SoundCue).playing).is_false()
	sheet._dealing.custom_step(FarmRegister.DEED_LEAVE_AFTER)
	assert_bool((deed.get_node("Roll") as SoundCue).playing).is_true()  # The deed rolls itself up.
	# The same thunk as the desk's approval press.
	var desk: Node = auto_free(load("res://entities/upgrade_desk/upgrade_desk.tscn").instantiate())
	var press := (desk.get_node("Stamp") as AudioStreamPlayer3D).stream as AudioStreamRandomizer
	var strike := (deed.get_node("Strike") as SoundCue).stream as AudioStreamRandomizer
	assert_object(strike.get_stream(0)).is_same(press.get_stream(0))


func test_only_the_first_farm_is_for_sale_before_negotiation() -> void:
	var save := _rich([])
	assert_bool(FarmRegister.for_sale(save, &"K-4")).is_true()
	assert_bool(FarmRegister.buy(save, &"K-4")).is_true()
	var coins := save.coins
	for site: String in SITES:
		assert_bool(FarmRegister.for_sale(save, StringName(site))).override_failure_message(site).is_false()
		assert_bool(FarmRegister.buy(save, StringName(site))).is_false()
		assert_str(FarmRegister.tag_text(save, StringName(site))).is_equal("ACQUIRED" if site == "K-4" else "NOT FOR SALE")
	assert_array(Array(save.farms_owned)).is_equal(["K-4"])
	assert_int(save.coins).is_equal(coins)
	assert_dict(FarmRegister.price(save)).is_empty()
	assert_dict(FarmRegister.short(save)).is_empty()  # Nothing is short: it is not sold.


func test_negotiation_opens_farms_two_to_four_at_their_price() -> void:
	var save := _rich(["negotiation"])
	for nth in 4:
		assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.PRICES[nth])
		assert_bool(FarmRegister.buy(save, StringName(SITES[nth]))).is_true()
	assert_int(save.farms_owned.size()).is_equal(4)
	assert_bool(FarmRegister.for_sale(save, &"K-5")).is_false()  # The fifth waits for more than talk.


func test_the_fifth_farm_needs_bribery() -> void:
	var save := _rich(["negotiation"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4"])
	assert_bool(FarmRegister.buy(save, &"K-5")).is_false()
	assert_str(FarmRegister.tag_text(save, &"K-5")).is_equal("NOT FOR SALE")
	save.stamped.append("bribery")
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.PRICES[4])
	assert_bool(FarmRegister.buy(save, &"K-5")).is_true()
	assert_bool(Events.due("no_more_sellers", save)).is_true()


func test_bribery_alone_does_not_open_the_farms_negotiation_opens() -> void:
	var save := _rich(["bribery"])
	save.farms_owned = PackedStringArray(["K-1"])
	assert_bool(FarmRegister.for_sale(save, &"K-2")).is_false()


func test_the_first_farm_needs_no_card_and_every_later_one_that_is_sold_waits_for_a_card_of_the_desk() -> void:
	assert_array(FarmRegister.GATES).is_equal(["", "negotiation", "negotiation", "negotiation", "bribery"])
	var ids := UpgradeDesk.CARDS.map(func(card: Dictionary) -> String: return card.id)
	assert_array(ids).contains(["negotiation", "bribery"])


## A rich save with `owned` farms and both cards stamped: the next farm's owner hears offers. The
## purse holds any price (the coin limit is its own rule below).
func _haggling(owned := 1) -> SaveGame:
	var save := _rich()
	save.coin_limit = 100000000
	save.farms_owned = PackedStringArray(SITES.slice(0, owned))
	return save


## Every text printed on the deed's form.
func _printed(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for label in node.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			out.append((label as Label).text)
	return out


func _form(sheet: FarmRegister, label: String) -> Label:
	return sheet.get_node("Deed/Page/Form/" + label) as Label


func test_the_first_farm_is_bought_without_haggling() -> void:
	var save := _rich()
	assert_str(FarmRegister.tender(save)).is_empty()
	assert_int(FarmRegister.offers_left(save)).is_equal(0)
	assert_int(FarmRegister.offer(save, 100)).is_equal(-1)
	assert_int(save.stock).is_equal(30000)
	var sheet := _register()
	sheet.press(&"K-1")
	assert_bool((sheet.get_node("Deed/Page/Form/Offer") as Control).visible).is_false()
	assert_bool((sheet.get_node("Deed/Page/Form/Mood") as Control).visible).is_false()
	assert_str(sheet.spot_at(sheet._deed_corner + FarmDeed.OFFER_BOX.get_center())).is_equal(&"")
	assert_str(_form(sheet, "SmallPrint").text).is_equal(FarmDeed.SMALL_PRINT)
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.coins).is_equal(10000000 - FarmRegister.PRICES[0].coins)


func test_a_farm_behind_a_card_can_be_stamped_at_the_asking_price_without_any_offer() -> void:
	var save := _haggling()
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.PRICES[1])
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()
	assert_int(save.coins).is_equal(10000000 - FarmRegister.PRICES[1].coins)
	assert_int(save.stock).is_equal(30000 - FarmRegister.PRICES[1].stock)


func test_an_offers_cabbages_are_gone_whether_it_lands_or_not() -> void:
	for amount: int in [1, 10000]:
		var save := _haggling()
		var mood := FarmRegister.offer(save, amount)
		assert_bool(FarmRegister.landed(mood)).is_equal(amount == 10000)
		assert_int(save.stock).is_equal(30000 - amount)
		assert_int(save.coins).is_equal(10000000)
		assert_array(Array(save.haggle_offers)).is_equal([amount])


func test_too_few_cabbages_raise_the_price() -> void:
	var save := _haggling()
	FarmRegister.offer(save, FarmRegister.wanted(save, 0) - 1)
	assert_int(FarmRegister.price(save).coins).is_greater(FarmRegister.PRICES[1].coins)
	assert_int(FarmRegister.price(save).stock).is_equal(FarmRegister.PRICES[1].stock)  # The cabbages of the price never move.


func test_enough_cabbages_lower_the_price() -> void:
	var save := _haggling()
	FarmRegister.offer(save, FarmRegister.wanted(save, 0))
	assert_int(FarmRegister.price(save).coins).is_equal(176000)  # 12% off the $200,000 asked.
	assert_int(FarmRegister.price(save).stock).is_equal(FarmRegister.PRICES[1].stock)
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()
	assert_int(save.coins).is_equal(10000000 - 176000)


func test_a_miss_costs_less_than_a_success_saves_and_a_near_miss_least() -> void:
	var steps := FarmRegister.MOOD_STEP
	assert_int(steps.size()).is_equal(FarmRegister.Mood.size())
	for mood in steps.size():
		assert_bool(steps[mood] < 0).is_equal(FarmRegister.landed(mood))
		assert_int(absi(steps[mood])).is_less_equal(-steps[FarmRegister.Mood.INTRIGUED])
		if mood > 0:
			assert_int(steps[mood]).is_less_equal(steps[mood - 1])  # A better mood is never dearer.
	assert_int(steps[FarmRegister.Mood.LISTENING]).is_less(steps[FarmRegister.Mood.UNIMPRESSED])
	assert_int(steps[FarmRegister.Mood.INTRIGUED]).is_between(-15, -10)
	assert_int(steps[FarmRegister.Mood.UNIMPRESSED]).is_between(6, 10)


func test_the_owners_mood_goes_by_the_offer_as_a_share_of_his_number() -> void:
	var moods := FarmRegister.Mood
	for case: Array in [[1, moods.INSULTED], [39, moods.INSULTED], [40, moods.UNIMPRESSED], [74, moods.UNIMPRESSED],
			[75, moods.LISTENING], [99, moods.LISTENING], [100, moods.INTRIGUED], [159, moods.INTRIGUED],
			[160, moods.DELIGHTED], [5000, moods.DELIGHTED]]:
		assert_int(FarmRegister.mood_of(case[0], 100)).override_failure_message("%d of 100" % case[0]).is_equal(case[1])


func test_the_owners_mood_is_the_only_clue_and_never_the_number() -> void:
	SaveManager.save = _haggling()
	SaveManager.save.created = 7  # His number is no notch of the dial (asserted below).
	var sheet := _register()
	sheet.press(&"K-2")
	var numbers: Array[String] = []
	for nth in FarmRegister.ROUNDS:
		var wins: int = FarmRegister.moods(SaveManager.save).filter(FarmRegister.landed).size()
		var wants := FarmRegister.wanted(SaveManager.save, wins)
		assert_bool(wants in FarmRegister.ladder(FarmRegister.HAGGLES[1].least)).is_false()
		numbers.append(str(wants))
		sheet.press(FarmRegister.MORE)
		sheet.press(FarmRegister.OFFER)
		_play_out(sheet)
		var mood: int = FarmRegister.moods(SaveManager.save)[-1]
		assert_bool((sheet.get_node("Deed/Page/Form/Mood/Imprint") as Control).visible).is_true()
		assert_str(_form(sheet, "Mood/Imprint/Word").text).is_equal(FarmDeed.MOODS["stock"][mood])
		for text in _printed(sheet.get_node("Deed/Page")):
			for number in numbers:
				assert_bool(text.contains(number)).override_failure_message("\"%s\" gives away %s" % [text, number]).is_false()
		assert_str(sheet.hint(&"K-2")).is_empty()
	assert_int(numbers.size()).is_equal(FarmRegister.ROUNDS)


func test_the_owner_wants_a_quarter_more_after_each_success() -> void:
	var save := _haggling()
	var first := FarmRegister.wanted(save, 0)
	for wins in 4:
		assert_float(FarmRegister.wanted(save, wins + 1) / float(FarmRegister.wanted(save, wins))).is_equal_approx(1.25, 0.02)
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, first))).is_true()
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, first))).is_false()  # The same again is no longer enough.
	assert_int(FarmRegister.moods(save)[1]).is_equal(FarmRegister.Mood.LISTENING)  # Just short.
	var missed := _haggling()
	FarmRegister.offer(missed, 1)
	assert_bool(FarmRegister.landed(FarmRegister.offer(missed, first))).is_true()  # A miss makes him no greedier.


func test_the_fifth_offer_is_the_last() -> void:
	var save := _haggling()
	for nth in FarmRegister.ROUNDS:
		assert_int(FarmRegister.offers_left(save)).is_equal(FarmRegister.ROUNDS - nth)
		assert_int(FarmRegister.offer(save, 1)).is_equal(FarmRegister.Mood.INSULTED)
	assert_int(FarmRegister.ROUNDS).is_equal(5)
	assert_int(FarmRegister.offers_left(save)).is_equal(0)
	assert_int(FarmRegister.offer(save, 10000)).is_equal(-1)
	assert_int(save.stock).is_equal(30000 - 5)
	assert_int(FarmRegister.price(save).coins).is_equal(280000)  # Careless to the end: the ceiling, 40% on top.
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()  # And still for sale at that.


func test_the_price_stops_forty_percent_under_the_asking_price_and_no_offer_is_heard_there() -> void:
	var save := _haggling()
	for price: int in [176000, 152000, 128000, 120000]:
		FarmRegister.offer(save, 2000)
		assert_int(FarmRegister.price(save).coins).is_equal(price)
	assert_int(FarmRegister.offers_left(save)).is_equal(0)  # A fifth offer could only be lost.
	assert_int(FarmRegister.offer(save, 2000)).is_equal(-1)
	assert_int(save.stock).is_equal(30000 - 4 * 2000)


## Every coin limit a save can reach, lowest first, as [the limit, what the step that gives it costs]:
## the start, the desk card's (UpgradeDesk.LIMIT_RAISE), then the projector's TREASURY steps.
func _coin_limits() -> Array:
	var limit := SaveGame.new().coin_limit
	var out := [[limit, 0], [limit * UpgradeDesk.LIMIT_RAISE, 0]]
	for node: Dictionary in Projector.NODES:
		if node.get("add", {}).has("coin_limit"):
			out.append([out[-1][0] + node.add.coin_limit, node.price])
	return out


func test_a_missed_offer_raises_the_price_at_the_limit_a_player_has_and_the_next_treasury_step_holds_it() -> void:
	var limits := _coin_limits()
	for owned: int in [1, 2, 3, 4]:
		var save := _haggling(owned)
		var asked: int = FarmRegister.PRICES[owned].coins
		var at := 0
		while limits[at][0] < asked:  # The first limit that holds the asking price: what a player has.
			at += 1
		save.coin_limit = limits[at][0]
		FarmRegister.offer(save, 1)
		assert_int(FarmRegister.price(save).coins).override_failure_message("farm %d: a miss is free" % (owned + 1)).is_greater(asked)
		for more in 4:
			FarmRegister.offer(save, 1)
		var ceiling := roundi(asked * 1.4)
		assert_int(FarmRegister.price(save).coins).is_equal(ceiling)
		# No dead end: every step up to the limit that holds the ceiling costs no more than the limit before it.
		while limits[at][0] < ceiling:
			at += 1
			assert_int(limits[at][1]).override_failure_message("farm %d: the step to $%d" % [owned + 1, limits[at][0]]).is_less_equal(limits[at - 1][0])


func test_no_farm_or_country_costs_more_coins_than_the_highest_coin_limit_holds() -> void:
	var top: int = _coin_limits()[-1][0]
	for bill: Dictionary in FarmRegister.SEIZURES + WorldRegister.COUNTRIES.values():
		assert_int(bill.coins).override_failure_message(str(bill)).is_less_equal(top)
	for bill: Dictionary in FarmRegister.PRICES:  # Even after five careless offers.
		assert_int(roundi(bill.coins * (100 + FarmRegister.PRICE_CEILING) / 100.0)).is_less_equal(top)


func test_an_offer_and_a_stamped_purchase_are_written_to_the_save_at_once() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	SaveManager.save.last_played = 0  # SaveManager.write_save stamps the time (the file itself is not written in tests).
	sheet.press(FarmRegister.OFFER)
	assert_int(SaveManager.save.last_played).is_greater(0)  # Quitting now does not take the offer back.
	_play_out(sheet)
	SaveManager.save.last_played = 0
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.last_played).is_greater(0)


func test_offers_purchases_and_seizures_go_into_the_playtest_log() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	sheet.press(FarmRegister.OFFER)  # 30 cabbages for the second farm.
	_play_out(sheet)
	var coins: int = FarmRegister.price(SaveManager.save).coins
	sheet.press(FarmRegister.STAMP)
	_play_out(sheet)
	SaveManager.save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	SaveManager.save.stamped.append("world_map")
	sheet.refresh()
	_buy(sheet, "K-7")
	var rows := SaveManager.save.playtest_log.map(func(row: Dictionary) -> Array: return [row.kind, row.id, row.price, row.currency])
	assert_array(rows).contains_exactly([
		["offer", "2", 30, "stock"],
		["farm_bought", "K-2", coins, "coins"], ["farm_bought", "K-2", 2000, "stock"],
		["seizure", "K-7", 6000000, "coins"], ["seizure", "K-7", 9000, "stock"]])


func test_a_dearer_farm_hides_a_larger_and_wider_number() -> void:
	assert_int(FarmRegister.HAGGLES.size()).is_equal(FarmRegister.PRICES.size())
	assert_dict(FarmRegister.HAGGLES[0]).is_empty()
	for nth in range(2, 4):  # The farms haggled in cabbages; the fifth is in coins.
		var dear: Dictionary = FarmRegister.HAGGLES[nth]
		var cheap: Dictionary = FarmRegister.HAGGLES[nth - 1]
		assert_int(dear.low).is_greater(cheap.low)
		assert_int(dear.high).is_greater(cheap.high)
		assert_float(dear.high / float(dear.low)).is_greater(cheap.high / float(cheap.low))
	var bribe: Dictionary = FarmRegister.HAGGLES[4]
	assert_float(bribe.high / float(bribe.low)).is_greater(FarmRegister.HAGGLES[3].high / float(FarmRegister.HAGGLES[3].low))
	for owned in range(1, 5):
		var haggle: Dictionary = FarmRegister.HAGGLES[owned]
		var seen := {}
		for created in 200:
			var save := _haggling(owned)
			save.created = 1731542400 + created * 3600
			var wants := FarmRegister.wanted(save, 0)
			assert_int(wants).is_between(haggle.low, haggle.high)
			seen[wants] = true
		assert_int(seen.size()).is_greater(30)  # Another save, another number.
		# The dial reaches what he wants even after four successes, in steps of at most a half more.
		var dial := FarmRegister.ladder(haggle.least)
		assert_int(dial[0]).is_less(haggle.low)
		assert_float(float(dial[-1])).is_greater(haggle.high * pow(FarmRegister.GREED, 4))
		for i in range(1, dial.size()):
			assert_float(dial[i] / float(dial[i - 1])).is_between(1.2, 1.51)


func test_the_dial_clicks_through_round_amounts() -> void:
	assert_array(Array(FarmRegister.ladder(30))).is_equal([30, 40, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1000])
	assert_int(FarmRegister.ladder(30000)[0]).is_equal(30000)
	assert_int(FarmRegister.ladder(30000)[-1]).is_equal(1000000)


func test_reloading_does_not_change_what_the_owner_has_in_mind() -> void:
	var save := _haggling()
	save.created = 1731542400
	FarmRegister.offer(save, 40)
	FarmRegister.offer(save, 10000)
	var path := "user://haggle_reload_test.tres"
	assert_int(ResourceSaver.save(save, path)).is_equal(OK)
	var loaded: SaveGame = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for wins in 4:
		assert_int(FarmRegister.wanted(loaded, wins)).is_equal(FarmRegister.wanted(save, wins))
	assert_array(Array(loaded.haggle_offers)).is_equal([40, 10000])  # The rounds used.
	assert_int(loaded.haggle_price).is_equal(save.haggle_price)  # The price they left.
	assert_array(FarmRegister.moods(loaded)).is_equal(FarmRegister.moods(save))
	assert_int(FarmRegister.offers_left(loaded)).is_equal(3)
	# The number is in no field of the save: it follows from the day the save was made.
	var other := _haggling()
	other.created = save.created + 1
	var differs := false
	for wins in 4:
		differs = differs or FarmRegister.wanted(other, wins) != FarmRegister.wanted(save, wins)
	assert_bool(differs).is_true()


func test_a_negotiation_in_progress_survives_closing_the_deed_and_a_reload() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	for click in 3:
		sheet.press(FarmRegister.MORE)
	sheet.press(FarmRegister.OFFER)
	_play_out(sheet)
	var price: int = FarmRegister.price(SaveManager.save).coins
	assert_int(price).is_not_equal(200000)
	sheet.press(&"")  # The deed away.
	assert_str(sheet.deed_site()).is_equal(&"")
	var loaded := _register()  # The same save, a fresh sheet.
	assert_str(_tag(loaded, "K-3").text).is_equal("$%s + 2,000" % FarmRegister.short_coins(price))
	loaded.press(&"K-3")  # Any site: it is the next farm's owner who haggles.
	assert_str(_form(loaded, "Coins").text).is_equal("$" + FarmScreen._thousands(price))
	assert_str(_form(loaded, "Asked").text).is_equal("ASKED $200,000")
	assert_bool(_form(loaded, "Asked").visible).is_true()
	assert_str(_form(loaded, "Offer/Round").text).is_equal("2 / 5")
	assert_str(_form(loaded, "Offer/Value/Number").text).is_equal("75")  # The dial where the last offer left it.
	assert_str(_form(loaded, "Log").text).is_equal("75  " + FarmDeed.MOODS["stock"][FarmRegister.moods(SaveManager.save)[0]])
	assert_bool((loaded.get_node("Deed/Page/Form/Mood/Imprint") as Control).visible).is_true()


func test_half_of_a_missed_offer_comes_back_once_rejected_goods_are_recovered() -> void:
	var save := _haggling()
	save.stamped.append("rejected_goods")
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, 30))).is_false()
	assert_int(save.stock).is_equal(30000 - 15)
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, 10000))).is_true()
	assert_int(save.stock).is_equal(30000 - 15 - 10000)  # An offer that lands is still fully spent.
	assert_str(FarmRegister.RECOVER).is_equal("rejected_goods")
	var card := UpgradeDesk.card_data(FarmRegister.RECOVER)
	assert_int(card.farms).is_equal(2)
	assert_array(card.needs).is_equal(["negotiation"])
	assert_array(UpgradeDesk.card_data("bribery").needs).is_equal([FarmRegister.RECOVER])
	var bribe := _haggling(4)
	bribe.stamped.append("rejected_goods")
	FarmRegister.offer(bribe, 30000)
	assert_int(bribe.coins).is_equal(10000000 - 15000)  # Half of a missed envelope too.
	assert_str(FarmRegister.haggle_note(bribe)).is_equal("Half of a refused offer is returned.")


func test_a_bribe_is_haggled_in_coins() -> void:
	var save := _haggling(4)
	assert_str(FarmRegister.tender(save)).is_equal("coins")
	assert_str(FarmRegister.tender(_haggling(1))).is_equal("stock")
	var wants := FarmRegister.wanted(save, 0)
	assert_int(wants).is_between(FarmRegister.HAGGLES[4].low, FarmRegister.HAGGLES[4].high)
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, wants - 1))).is_false()
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, wants))).is_true()
	assert_int(save.coins).is_equal(10000000 - 2 * wants + 1)  # Both envelopes are gone.
	assert_int(save.stock).is_equal(30000)
	assert_int(FarmRegister.price(save).coins).is_equal(5000000 + 50000 * FarmRegister.MOOD_STEP[FarmRegister.mood_of(wants - 1, wants)] - 600000)
	assert_int(FarmRegister.price(save).stock).is_equal(9000)
	SaveManager.save = save
	var sheet := _register()
	sheet.press(&"K-5")
	assert_str(_form(sheet, "Offer/Head").text).is_equal("IN THE ENVELOPE")
	assert_str(_form(sheet, "Offer/Submit/Word").text).is_equal("PASS THE ENVELOPE")
	assert_str(_form(sheet, "Mood/Imprint/Word").text).is_equal("UNDERSTOOD")
	assert_str(_form(sheet, "Offer/Value/Number").text).starts_with("$")
	assert_str(_form(sheet, "Log").text).contains("CONSIDERED")


func test_an_offer_the_desk_does_not_hold_is_refused_and_changes_nothing() -> void:
	var save := _haggling()
	save.stock = 29
	assert_int(FarmRegister.offer(save, 30)).is_equal(-1)
	assert_int(FarmRegister.offer(save, 30, Vector2i.ZERO)).is_equal(-1)
	save.stock = 33
	assert_int(FarmRegister.offer(save, 30, Vector2i(4, 0))).is_equal(-1)  # 4 of them lie on the mat.
	assert_int(save.stock).is_equal(33)
	assert_array(Array(save.haggle_offers)).is_empty()
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.PRICES[1])
	SaveManager.save = save
	save.stock = 0
	var sheet := _register()
	sheet.press(&"K-2")
	sheet.press(FarmRegister.OFFER)
	assert_object(sheet._dealing).is_null()
	assert_object((sheet.get_node("Deed") as FarmDeed)._blinking).is_not_null()
	assert_bool((sheet.get_node("Deed/Denied") as SoundCue).playing).is_true()


func test_buying_the_farm_closes_its_negotiation_and_the_next_owner_starts_at_his_asking_price() -> void:
	var save := _haggling()
	FarmRegister.offer(save, 10000)
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()
	assert_array(Array(save.haggle_offers)).is_empty()
	assert_int(save.haggle_price).is_equal(0)
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.PRICES[2])
	assert_int(FarmRegister.offers_left(save)).is_equal(FarmRegister.ROUNDS)
	# A farm that comes any other way closes it too.
	SaveManager.save = _haggling()
	var sheet := _register()
	FarmRegister.offer(SaveManager.save, 10000)
	DebugKeys.press(KEY_5, SaveManager.save)
	sheet._process(0.0)
	assert_dict(FarmRegister.price(SaveManager.save)).is_equal(FarmRegister.PRICES[2])


func test_the_dial_turns_a_notch_a_click_and_stops_at_its_ends() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
	for spot: StringName in [FarmRegister.LESS, FarmRegister.MORE, FarmRegister.OFFER]:
		assert_str(sheet.spot_at(sheet._deed_corner + (FarmDeed.BOXES[spot] as Rect2).get_center())).is_equal(spot)
	assert_str(_form(sheet, "Offer/Value/Number").text).is_equal("30")
	assert_str(_form(sheet, "Offer/Round").text).is_equal("1 / 5")
	assert_str(_form(sheet, "SmallPrint").text).is_equal("Cabbages offered are not returned.")
	sheet.press(FarmRegister.LESS)  # Already at the bottom.
	assert_str(_form(sheet, "Offer/Value/Number").text).is_equal("30")
	assert_bool((deed.get_node("Dial") as SoundCue).playing).is_false()
	sheet.press(FarmRegister.MORE)
	assert_str(_form(sheet, "Offer/Value/Number").text).is_equal("40")
	assert_bool((deed.get_node("Dial") as SoundCue).playing).is_true()
	for click in 20:
		sheet.press(FarmRegister.MORE)
	assert_str(_form(sheet, "Offer/Value/Number").text).is_equal("1,000")
	assert_int(SaveManager.save.stock).is_equal(30000)  # Turning the dial offers nothing.
	assert_str(sheet.deed_site()).is_equal(&"K-2")
	sheet.hover(FarmRegister.MORE)
	assert_object((deed.get_node("Page/Form/Offer/More") as Control).get_theme_stylebox(&"panel")).is_same(deed.hot_box)
	assert_object((deed.get_node("Page/Form/Box") as Control).get_theme_stylebox(&"panel")).is_not_same(deed.hot_box)


func test_submitting_an_offer_stamps_the_owners_mood_on_the_deed_and_the_price_changes_as_the_stamp_lands() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
	sheet.press(FarmRegister.OFFER)  # 30 cabbages: a miss.
	assert_int(SaveManager.save.stock).is_equal(30000 - 30)  # Gone at once.
	assert_bool((deed.get_node("Stamp") as Node3D).visible).is_true()
	assert_float((deed.get_node("Stamp") as Node3D).position.z).is_equal_approx(FarmDeed.MOOD_AT.y / FarmDeed.PIXELS_PER_METRE, 0.001)
	assert_str(_form(sheet, "Coins").text).is_equal("$200,000")  # The stamp is still falling.
	assert_bool((deed.get_node("Page/Form/Mood/Imprint") as Control).visible).is_false()
	sheet.press(FarmRegister.STAMP)  # No click meanwhile.
	assert_array(Array(SaveManager.save.farms_owned)).is_equal(["K-1"])
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + 0.01)
	var price: int = FarmRegister.price(SaveManager.save).coins
	assert_int(price).is_greater(200000)
	assert_str(_form(sheet, "Coins").text).is_equal("$" + FarmScreen._thousands(price))
	assert_bool((deed.get_node("Page/Form/Mood/Imprint") as Control).visible).is_true()
	assert_bool((deed.get_node("MoodStamp") as SoundCue).playing).is_true()
	assert_bool((deed.get_node("Denied") as SoundCue).playing).is_true()  # A miss: the dry thud.
	assert_bool((deed.get_node("Agreed") as SoundCue).playing).is_false()
	assert_bool(deed.stamped).is_false()  # Nothing is bought by it.
	_play_out(sheet)
	assert_object(sheet._dealing).is_null()
	for click in 11:
		sheet.press(FarmRegister.MORE)
	sheet.press(FarmRegister.OFFER)  # 1,000: more than he ever asks.
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + 0.01)
	assert_bool((deed.get_node("Agreed") as SoundCue).playing).is_true()
	assert_str(_form(sheet, "Mood/Imprint/Word").text).is_equal("DELIGHTED")
	_play_out(sheet)
	sheet.press(FarmRegister.STAMP)  # The deed is stamped at the price it shows.
	assert_int(SaveManager.save.coins).is_equal(10000000 - FarmRegister.MOOD_STEP[FarmRegister.mood_of(30, FarmRegister.wanted(_haggling(), 0))] * 2000 - 200000 + 24000)
	assert_float((deed.get_node("Stamp") as Node3D).position.z).is_equal_approx(FarmDeed.STAMP_BOX.get_center().y / FarmDeed.PIXELS_PER_METRE, 0.001)
	for cue: String in ["Dial", "MoodStamp", "Agreed"]:
		assert_object((deed.get_node(cue) as SoundCue).stream).override_failure_message(cue).is_not_null()


func test_after_the_last_offer_the_dial_gives_way_to_no_further_offers_and_the_deed_can_still_be_stamped() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	for nth in FarmRegister.ROUNDS:
		sheet.press(FarmRegister.OFFER)
		_play_out(sheet)
	assert_bool(_form(sheet, "Offer/Closed").visible).is_true()
	assert_bool((sheet.get_node("Deed/Page/Form/Offer/Submit") as Control).visible).is_false()
	assert_str(_form(sheet, "Offer/Round").text).is_equal("5 / 5")
	assert_int(_form(sheet, "Log").text.split("\n").size()).is_equal(5)
	assert_str(sheet.spot_at(sheet._deed_corner + FarmDeed.OFFER_BOX.get_center())).is_equal(&"")
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)


func test_a_save_that_owns_more_farms_than_its_cards_allow_keeps_them() -> void:
	SaveManager.save = _rich([])
	SaveManager.save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3"])
	var sheet := _register()
	for site: String in ["K-1", "K-2", "K-3"]:
		assert_bool(_building(sheet, site).owned).is_true()
		assert_str(_tag(sheet, site).text).is_equal("ACQUIRED")
	assert_str(_tag(sheet, "K-4").text).is_equal("NOT FOR SALE")
	assert_int(SaveManager.save.farms_owned.size()).is_equal(3)


func test_the_tags_print_not_for_sale_until_the_card_is_stamped_and_the_price_right_after() -> void:
	SaveManager.save = _rich([])
	var sheet := _register()
	_buy(sheet, "K-1")
	assert_str(_tag(sheet, "K-2").text).is_equal("NOT FOR SALE")
	assert_str(sheet.hint(&"K-2")).is_equal(_building(sheet, "K-2").title + ". Not for sale. The owners will need persuading.")
	sheet.press(&"K-2")  # A deed nobody can stamp: nothing bought.
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(1)
	sheet.press(&"")
	SaveManager.save.stamped.append("negotiation")
	sheet._process(0.0)
	assert_str(_tag(sheet, "K-2").text).is_equal("$200K + 2,000")
	_buy(sheet, "K-2")
	assert_str(_tag(sheet, "K-2").text).is_equal("ACQUIRED")


func test_a_farm_that_waits_for_its_card_says_not_for_sale_in_german_too() -> void:
	TranslationServer.set_locale("de")
	var save := _rich([])
	save.farms_owned = PackedStringArray(["K-1"])
	assert_str(FarmRegister.tag_text(save, &"K-2")).is_equal("UNVERKÄUFLICH")
	assert_str(FarmRegister.hint_text(save, &"K-2", "X")).is_equal("X. Unverkäuflich. Die Eigentümer müssen erst überzeugt werden.")


func test_the_home_country_is_ours_once_the_last_three_farms_are_seized() -> void:
	var save := _rich(["negotiation", "bribery", "world_map"])
	save.coin_limit = 1000000000
	save.coins = 1000000000
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	assert_int(FarmRegister.SEIZURES.size()).is_equal(Events.HOME_SITES - Events.HOME_SELLERS)
	for nth in FarmRegister.SEIZURES.size():
		var bill := FarmRegister.SEIZURES[nth]
		var coins := save.coins
		var stock := save.stock
		assert_bool(Events.due("home_country", save)).is_false()
		assert_dict(FarmRegister.seizure(save)).is_equal(bill)
		assert_bool(FarmRegister.buy(save, StringName(SITES[Events.HOME_SELLERS + nth]))).is_true()
		assert_int(save.coins).is_equal(coins - bill.coins)
		assert_int(save.stock).is_equal(stock - bill.stock)
	assert_int(Events.home_farms(save)).is_equal(Events.HOME_SITES)
	assert_bool(Events.due("home_country", save)).is_true()
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(UpgradeDesk.card_data("no_taxes")))).is_true()
	# Nothing is left to take at home.
	assert_dict(FarmRegister.price(save)).is_empty()
	assert_dict(FarmRegister.seizure(save)).is_empty()


func test_a_seizure_costs_more_with_every_farm_seized_and_more_than_the_last_farm_bought() -> void:
	var last: Dictionary = FarmRegister.PRICES[-1]
	for bill in FarmRegister.SEIZURES:
		assert_int(bill.coins).is_greater(last.coins)
		assert_int(bill.stock).is_greater_equal(last.stock)
		last = bill


func test_farms_abroad_do_not_change_what_the_next_home_farm_costs_to_seize() -> void:
	var save := _rich(["negotiation", "bribery", "world_map"])
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	WorldRegister.annex(save, &"ostrevia")
	WorldRegister.annex(save, &"sulvania")
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.SEIZURES[0])
	save.farms_owned.append("K-6")
	assert_dict(FarmRegister.price(save)).is_equal(FarmRegister.SEIZURES[1])


func test_a_farm_nobody_sells_is_taken_with_a_seizure_order_stamped_like_a_purchase_and_nobody_haggles() -> void:
	SaveManager.save = _rich(["negotiation", "bribery", "world_map"])
	SaveManager.save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	var sheet := _register()
	assert_str(_tag(sheet, "K-7").text).is_equal("$%s + %s" % [FarmRegister.short_coins(FarmRegister.SEIZURES[0].coins), FarmScreen._thousands(FarmRegister.SEIZURES[0].stock)])
	sheet.press(&"K-7")
	var deed: FarmDeed = sheet.get_node("Deed")
	assert_str((deed.get_node("Page/Form/FormLine") as Label).text).is_equal("FORM 3-S  SEIZURE ORDER")
	assert_str((deed.get_node("Page/Form/PriceHead") as Label).text).is_equal("COST OF THE OPERATION")
	assert_str((deed.get_node("Page/Form/SmallPrint") as Label).text).is_equal("The owner's signature is not required.")
	assert_str((deed.get_node("Page/Form/Imprint/Word") as Label).text).is_equal("SEIZED")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_true()
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_bool((deed.get_node("Page/Form/Offer") as Control).visible).is_false()
	assert_str(FarmRegister.tender(SaveManager.save)).is_equal("")
	assert_int(FarmRegister.offers_left(SaveManager.save)).is_equal(0)
	sheet.press(FarmRegister.STAMP)
	assert_array(Array(SaveManager.save.farms_owned)).contains(["K-7"])
	assert_int(SaveManager.save.farms_owned.size()).is_equal(Events.HOME_SELLERS + 1)
