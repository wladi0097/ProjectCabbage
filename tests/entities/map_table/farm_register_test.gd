extends GdUnitTestSuite

const Events := preload("res://globalScripts/game_events.gd")
const Report := preload("res://entities/boss_report/boss_report.gd")
const DebugKeys := preload("res://worlds/components/debug_keys.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")
const WarSheet := preload("res://entities/map_table/war_sheet.gd")
const SITES := ["K-1", "K-2", "K-3", "K-4", "K-5", "K-6", "K-7", "K-8"]
## The farms a negotiation save (_haggling) owns, in order: never K-2, the site at list price (worth
## 1.0) the negotiation is tested on.
const HAGGLED_BESIDE := ["K-1", "K-3", "K-4", "K-6"]

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


## A country's own sheet (the home country's unless told), lying open with its things standing.
func _register(country := WorldRegister.HOME) -> FarmRegister:
	var sheet: FarmRegister = auto_free(load("res://entities/map_table/countries/%s.tscn" % country).instantiate())
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


## How much of each parcel shows the pattern on the land layer (0..1), by site; the head office's
## share is "HQ" (absent on a sheet without one).
func _reach(sheet: FarmRegister) -> Dictionary:
	var progress: PackedFloat32Array = _ink(sheet).get_shader_parameter(&"progress")
	var out := {}
	for i in sheet._sites.size():
		out[String(sheet._sites.keys()[i])] = progress[i]
	if sheet.head_office != Vector3.ZERO:
		out["HQ"] = progress[sheet._sites.size()]
	return out


func _ink(sheet: FarmRegister) -> ShaderMaterial:
	return (sheet.get_node("Page/Sheet/Layers/Parcels") as CanvasItem).material


## The sheet's baked parcels (tools/bake_parcels.gd), RGB8: per pixel its place, how far the spread
## comes to reach it (0..255) and whether it is land.
func _parcels(sheet: FarmRegister) -> Image:
	var image := (_ink(sheet).get_shader_parameter(&"parcels") as Texture2D).get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGB8)
	return image


## The places of `sheet` on the art (px) in the baked order: its sites, then the head office.
func _places(sheet: FarmRegister) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for site: StringName in sheet._sites:
		out.append(sheet._pixel(site))
	if sheet.head_office != Vector3.ZERO:
		out.append(Vector2(sheet.head_office.x, sheet.head_office.y))
	return out


## The baked pixel of art pixel `pixel`.
func _baked(image: Image, pixel: Vector2) -> Vector2i:
	return Vector2i(pixel * image.get_width() / (MapSheet.SIZE.x * MapSheet.PIXELS_PER_METRE))


## `country`'s farm sites as its sheet was generated from them (reports/maps/labels.json).
func _sites(country: StringName) -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).country_maps[String(country)].farm_sites


func _tag(sheet: FarmRegister, site: String) -> Label:
	return sheet.get_node("Page/Sheet/Price_" + site)


func _building(sheet: FarmRegister, site: String) -> MapBuilding:
	return sheet._sites[StringName(site)]


func test_a_farm_is_bought_with_its_price_in_coins_and_cabbages_and_only_once() -> void:
	var save := _rich()
	var bill := FarmRegister.price(save, &"K-3")
	assert_bool(FarmRegister.buy(save, &"K-3")).is_true()
	assert_array(Array(save.farms_owned)).is_equal(["K-3"])
	assert_int(save.coins).is_equal(10000000 - bill.coins)
	assert_int(save.stock).is_equal(30000 - bill.stock)
	assert_bool(FarmRegister.buy(save, &"K-3")).is_false()
	assert_array(Array(save.farms_owned)).is_equal(["K-3"])
	assert_int(save.coins).is_equal(10000000 - bill.coins)


func test_a_farms_price_still_rises_with_each_farm_owned_whichever_site_is_bought() -> void:
	for watched: String in SITES:
		var save := _rich()
		var last := {coins = 0, stock = 0}
		for site: String in ["K-7", "K-2", "K-8", "K-1", "K-4", "K-6", "K-3"].filter(func(s: String) -> bool: return s != watched).slice(0, 5):
			var bill := FarmRegister.price(save, StringName(watched))
			assert_int(bill.coins).override_failure_message(watched).is_greater(last.coins)
			assert_int(bill.stock).override_failure_message(watched).is_greater(last.stock)
			last = bill
			assert_bool(FarmRegister.buy(save, StringName(site))).is_true()


func test_home_farms_differ_in_price_some_cheaper_some_dearer() -> void:
	var save := _rich()
	var coins := {}
	for site: String in SITES:
		coins[site] = FarmRegister.asking(save, StringName(site)).coins
	assert_int(coins.values().min()).is_less_equal(roundi(FarmRegister.PRICES[0].coins * 0.75))  # The furthest from the head office.
	assert_int(coins.values().max()).is_greater_equal(roundi(FarmRegister.PRICES[0].coins * 1.35))  # By the head office.
	assert_int(coins.values().reduce(func(seen: Array, c: int) -> Array: return seen if c in seen else seen + [c], []).size()).is_greater_equal(6)
	for nth in FarmRegister.PRICES.size():  # Coins and cabbages, the same share, for every farm.
		save.farms_owned.resize(nth)
		for site: String in SITES:
			var bill := FarmRegister.asking(save, StringName(site))
			var worth := FarmRegister.worth(StringName(site))
			assert_int(bill.coins).is_equal(roundi(FarmRegister.PRICES[nth].coins * worth / 1000.0) * 1000)
			assert_int(bill.stock).is_equal(roundi(FarmRegister.PRICES[nth].stock * worth / 10.0) * 10)
	# Near the head office dearer, far out cheaper; every home site has its own worth.
	assert_float(FarmRegister.worth(&"K-1")).is_greater(FarmRegister.worth(&"K-8"))
	assert_int(FarmRegister.WORTH.size()).is_equal(Events.HOME_SITES)


func test_the_five_cheapest_home_farms_cost_about_what_the_flat_price_did() -> void:
	# A player who buys the cheapest site first pays about the old flat price over the five sold
	# (tools/pace.py ch3 mirrors it): the dear sites are the ones left to war.
	var cheapest: Array = FarmRegister.WORTH.values()
	cheapest.sort()
	cheapest = cheapest.slice(0, Events.HOME_SELLERS)
	assert_float(cheapest[-1]).is_equal(1.0)  # The fifth, the dearest farm of all, at its list price.
	assert_float(cheapest.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / cheapest.size()).is_between(0.8, 1.0)


func test_there_is_a_price_for_every_farm_that_is_sold_at_home() -> void:
	assert_int(FarmRegister.PRICES.size()).is_equal(Events.HOME_SELLERS)
	assert_int(FarmRegister.GATES.size()).is_equal(Events.HOME_SELLERS)


func test_a_farm_that_cannot_be_paid_for_is_refused_and_costs_nothing() -> void:
	for lacking: String in ["coins", "stock"]:
		var save := _rich()
		save.set(lacking, FarmRegister.price(save, &"K-1")[lacking] - 1)
		var coins := save.coins
		var stock := save.stock
		assert_bool(FarmRegister.buy(save, &"K-1")).is_false()
		assert_array(Array(save.farms_owned)).is_empty()
		assert_int(save.coins).is_equal(coins)
		assert_int(save.stock).is_equal(stock)
		assert_dict(FarmRegister.short(save, &"K-1")).is_equal({lacking: 1})


func test_cabbages_out_of_the_store_cannot_pay_for_a_farm() -> void:
	var save := _rich()
	save.stock = FarmRegister.price(save, &"K-1").stock + 3
	assert_bool(FarmRegister.buy(save, &"K-1", Vector2i(4, 0))).is_false()  # 4 of them lie on the mat.
	assert_bool(FarmRegister.buy(save, &"K-1", Vector2i(3, 0))).is_true()
	assert_int(save.stock).is_equal(3)


func test_the_last_three_home_farms_cannot_be_bought() -> void:
	var save := _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	for i in Events.HOME_SELLERS:
		assert_bool(FarmRegister.buy(save, StringName(SITES[i]))).is_true()
	assert_int(Events.HOME_SITES - Events.HOME_SELLERS).is_equal(3)
	var coins := save.coins
	for site: String in SITES.slice(Events.HOME_SELLERS):
		assert_bool(FarmRegister.for_sale(save, StringName(site))).override_failure_message(site).is_false()
		assert_bool(FarmRegister.buy(save, StringName(site))).override_failure_message(site).is_false()
	assert_int(save.farms_owned.size()).is_equal(Events.HOME_SELLERS)
	assert_int(save.coins).is_equal(coins)
	assert_dict(FarmRegister.price(save, &"K-6")).is_empty()


func test_war_on_a_farm_needs_the_war_card() -> void:
	var save := _rich()
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	assert_str(FarmRegister.WAR_CARD).is_equal("war_mode")
	for site: StringName in [&"K-6", &"ostrevia-1"]:
		assert_bool(FarmRegister.war_ready(save, site)).override_failure_message(site).is_false()
		assert_dict(FarmRegister.war_bill(save, site)).is_empty()
		assert_str(FarmRegister.tag_text(save, site)).is_equal("NOT FOR SALE")
	save.stamped.append(FarmRegister.WAR_CARD)
	assert_bool(FarmRegister.war_ready(save, &"K-6")).is_true()
	assert_dict(FarmRegister.war_bill(save, &"K-6")).is_equal(WorldRegister.COUNTRIES[WorldRegister.HOME].wars[0])
	assert_bool(FarmRegister.war_ready(save, &"ostrevia-1")).is_true()
	assert_bool(FarmRegister.war_ready(save, &"K-1")).is_false()  # Ours already.


func test_a_home_farm_is_taken_by_war_only_once_nobody_sells_any_more() -> void:
	var save := _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS - 1))
	assert_bool(FarmRegister.war_ready(save, &"K-8")).is_false()  # The fifth is still for sale: it is bought.
	assert_bool(FarmRegister.for_sale(save, &"K-8")).is_true()
	save.farms_owned.append("K-5")
	assert_bool(FarmRegister.war_ready(save, &"K-8")).is_true()


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


func test_the_price_tag_prints_the_sites_price_as_the_next_farm_in_coins_and_cabbages() -> void:
	var sheet := _register()
	for site: String in SITES:
		var bill := FarmRegister.asking(SaveManager.save, StringName(site))
		assert_str(_tag(sheet, site).text).is_equal("$%s + %s" % [FarmRegister.short_coins(bill.coins), FarmScreen._thousands(bill.stock)])
	assert_str(_tag(sheet, "K-2").text).is_equal("$60K + 800")
	assert_str(_tag(sheet, "K-1").text).is_equal("$84K + 1,120")  # Beside the head office.
	assert_str(_tag(sheet, "K-8").text).is_equal("$42K + 560")  # The furthest from the head office.
	_buy(sheet, "K-4")
	assert_str(_tag(sheet, "K-4").text).is_equal("ACQUIRED")
	assert_str(_tag(sheet, "K-2").text).is_equal("$200K + 2,000")
	assert_str(_tag(sheet, "K-1").text).is_equal("$280K + 2,800")
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
	var sites: Array = _sites(WorldRegister.HOME)
	var box: Dictionary = sites[0].price_tag
	# The print stands 10 px right of the tag's middle; the eyelet takes the left 27 px, 6 px stay free on the right.
	var room := minf((box.w / 2.0 - 27.0 + 10.0) * 2.0, (box.w / 2.0 - 6.0 - 10.0) * 2.0)
	var texts: Array[String] = []
	for owned in FarmRegister.PRICES.size():
		var save := _rich()
		save.farms_owned.resize(owned)
		for site: String in SITES:
			texts.append(FarmRegister.tag_text(save, StringName(site)))
	texts.append("$1.5M + 9,000")  # Millions fit too (the pacing sim wants $1.5M and $5M).
	for entry: Dictionary in WorldRegister.COUNTRIES.values():  # What a war is expected to cost.
		for bill: Dictionary in entry.wars:
			texts.append("$" + FarmRegister.short_coins(bill.coins))
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for text in texts + [TranslationServer.translate("ACQUIRED"), TranslationServer.translate("NOT FOR SALE"),
				TranslationServer.translate(WorldRegister.NOT_ADJACENT), TranslationServer.translate(WorldRegister.NO_SEA_LANES)]:
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
	assert_str((deed.get_node("Page/Form/Title") as Label).text).is_equal(_building(sheet, "K-5").title)
	assert_str((deed.get_node("Page/Form/Site") as Label).text).is_equal("FARM SITE K-5")
	assert_str((deed.get_node("Page/Form/Coins") as Label).text).is_equal("$75,000")
	assert_str((deed.get_node("Page/Form/Cabbages") as Label).text).is_equal("1,000 cabbages")
	assert_dict(deed.bill).is_equal(FarmRegister.asking(SaveManager.save, &"K-5"))
	assert_bool(deed.stamped).is_false()
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_true()


func test_stamping_the_deed_buys_the_farm() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)
	sheet.press(FarmRegister.STAMP)
	assert_array(Array(SaveManager.save.farms_owned)).is_equal(["K-5"])
	assert_int(SaveManager.save.coins).is_equal(10000000 - 75000)
	assert_int(SaveManager.save.stock).is_equal(30000 - 1000)
	_play_out(sheet)
	assert_bool(_building(sheet, "K-5").get_node("Owned").visible).is_true()
	assert_bool(_building(sheet, "K-4").owned).is_false()
	assert_bool(sheet.get_node("Flash").visible).is_true()  # The flash of the acquisition, on the site.
	assert_float(sheet.get_node("Flash").position.x).is_equal_approx(_building(sheet, "K-5").position.x, 0.001)
	assert_bool((sheet.get_node("Deed") as FarmDeed).stamped).is_true()
	sheet.press(&"K-5")  # Ours already: no deed, nothing more is paid.
	assert_str(sheet.deed_site()).is_equal(&"")
	assert_int(SaveManager.save.coins).is_equal(10000000 - 75000)


func test_the_token_and_the_land_change_when_the_stamp_has_landed_and_the_pattern_spreads_from_the_token() -> void:
	var sheet := _register()
	sheet.press(&"K-5")
	sheet.press(FarmRegister.STAMP)
	assert_bool(_building(sheet, "K-5").owned).is_false()  # Paid for; the stamp is still falling.
	assert_str(_tag(sheet, "K-5").text).is_equal("$75K + 1,000")
	assert_float(_reach(sheet)["K-5"]).is_equal(0.0)
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + FarmRegister.HIT_PAUSE + 0.01)
	assert_bool(_building(sheet, "K-5").owned).is_true()
	assert_str(_tag(sheet, "K-5").text).is_equal("ACQUIRED")
	assert_float(_reach(sheet)["K-5"]).is_equal(0.0)  # The spread starts at the token.
	sheet._spread_tween.custom_step(FarmRegister.PARCEL_TIME * 0.3)
	assert_float(_reach(sheet)["K-5"]).is_between(0.01, 0.99)
	sheet._spread_tween.custom_step(FarmRegister.PARCEL_TIME)
	assert_float(_reach(sheet)["K-5"]).is_equal(1.0)
	assert_float(_reach(sheet)["K-4"]).is_equal(0.0)
	assert_float(FarmRegister.PARCEL_TIME).is_between(0.4, 1.2)  # A short reveal.
	assert_float(FarmRegister.HIT_PAUSE).is_between(0.05, 0.15)


func test_an_owned_farms_parcel_shows_the_cabbage_pattern_after_a_reload() -> void:
	var sheet := _register()
	_buy(sheet, "K-3")
	sheet._spread_tween.custom_step(10.0)
	assert_float(_reach(sheet)["K-3"]).is_equal(1.0)
	var loaded := _register()  # The same save, a fresh sheet.
	var reach := _reach(loaded)
	for site: String in SITES:
		assert_float(reach[site]).is_equal(1.0 if site == "K-3" else 0.0)
	assert_float(reach["HQ"]).is_equal(1.0)  # The head office's share is company land from the start.
	assert_bool(loaded._moving.is_empty()).is_true()  # Without the moment.


func test_the_land_layer_greys_the_country_over_the_sheets_own_art() -> void:
	var sheet := _register()
	var layer := sheet.get_node("Page/Sheet/Layers/Parcels") as TextureRect
	assert_object(layer.texture).is_same((sheet.get_node("Page/Sheet/Art") as TextureRect).texture)
	assert_str(((layer.material as ShaderMaterial).shader as Shader).resource_path).is_equal("res://assets/shaders/farm_parcels.gdshader")


func test_every_land_pixel_of_a_country_belongs_to_exactly_one_farm() -> void:
	for country: StringName in WorldRegister.COUNTRIES:
		var sheet := _register(country)
		assert_str((_ink(sheet).get_shader_parameter(&"parcels") as Texture2D).resource_path).contains(String(country))
		var places := _places(sheet).size()
		assert_int(places).is_less_equal(FarmRegister.PLACES)
		var owned := PackedInt32Array()
		owned.resize(256)
		var data := _parcels(sheet).get_data()
		for i in range(0, data.size(), 3):
			if data[i + 2] > 0:  # Land.
				owned[data[i]] += 1
		assert_int(Array(owned.slice(places)).reduce(func(a: int, b: int) -> int: return a + b, 0)) \
				.override_failure_message("%s: land of no farm" % country).is_equal(0)
		for place in places:  # And every farm has land of its own.
			assert_int(owned[place]).override_failure_message("%s: place %d has no land" % [country, place]).is_greater(0)


func test_a_country_with_two_farms_is_split_in_two() -> void:
	var sheet := _register(&"grauland")
	assert_int(sheet._sites.size()).is_equal(2)
	var data := _parcels(sheet).get_data()
	var owned := [0, 0]
	for i in range(0, data.size(), 3):
		if data[i + 2] > 0:
			owned[data[i]] += 1
	for place in 2:  # Two halves, neither a sliver.
		assert_float(owned[place] / float(owned[0] + owned[1])).is_between(0.25, 0.75)


func test_a_parcel_fills_from_its_farm_outward() -> void:
	for country: StringName in WorldRegister.COUNTRIES:
		var sheet := _register(country)
		var image := _parcels(sheet)
		var places := _places(sheet)
		for place in places.size():
			# Its token's spot is its own and where the spread starts (the bake knows where it stands).
			var at := image.get_pixelv(_baked(image, places[place]))
			assert_int(at.r8).override_failure_message("%s: place %d stands on other land" % [country, place]).is_equal(place)
			assert_int(at.g8).is_less(10)
		# Its land farther from the token is reached later, the far end last.
		var data := image.get_data()
		var near := Vector2.ZERO  # Sum, count.
		var far := Vector2.ZERO
		var last := PackedInt32Array()
		last.resize(places.size())
		for i in range(0, data.size(), 3):
			if data[i + 2] > 0:
				var place := data[i]
				var cell := floori(i / 3.0)
				var gap := Vector2(cell % image.get_width(), floori(cell / float(image.get_width()))).distance_to(Vector2(_baked(image, places[place])))
				last[place] = maxi(last[place], data[i + 1])
				if gap < 15.0:
					near += Vector2(data[i + 1], 1)
				elif gap > 60.0:
					far += Vector2(data[i + 1], 1)
		assert_float(near.x / near.y).override_failure_message(String(country)).is_less(far.x / far.y)
		for place in places.size():
			assert_int(last[place]).is_equal(255)


func test_the_stamp_stays_up_when_the_price_cannot_be_paid() -> void:
	SaveManager.save.coins = 10
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
	assert_str((deed.get_node("Page/Form/CoinsShort") as Label).text).is_equal("SHORT $59,990")
	assert_str((deed.get_node("Page/Form/CabbagesShort") as Label).text).is_equal("")
	sheet.press(FarmRegister.STAMP)
	assert_array(Array(SaveManager.save.farms_owned)).is_empty()
	assert_int(SaveManager.save.coins).is_equal(10)
	assert_object(sheet._dealing).is_null()
	assert_bool((deed.get_node("Stamp") as Node3D).visible).is_false()
	assert_bool(deed.stamped).is_false()
	assert_bool(_building(sheet, "K-2").owned).is_false()
	assert_bool(sheet.get_node("Flash").visible).is_false()
	assert_str(_tag(sheet, "K-2").text).is_equal("$60K + 800")
	assert_bool(sheet._moving.has(&"K-2")).is_true()  # It shakes its head.
	assert_object(deed._blinking).is_not_null()  # What is short flashes.
	assert_str(sheet.deed_site()).is_equal(&"K-2")  # The deed stays.


func test_the_deed_marks_what_is_short_as_the_save_changes() -> void:
	SaveManager.save.coins = 59000
	SaveManager.save.stock = 790
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
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


func test_the_deed_lies_beside_its_farm_inside_the_sheet_and_never_on_the_farm_in_every_country() -> void:
	var paper := Rect2(Vector2.ZERO, MapSheet.SIZE * MapSheet.PIXELS_PER_METRE)
	var sites: Array = []
	for country: StringName in WorldRegister.COUNTRIES:
		sites.append_array(_sites(country))
	assert_int(sites.size()).is_equal(Events.FARMS)
	for site: Dictionary in sites:
		var at := Vector2(site.x, site.y)
		var deed := Rect2(FarmRegister.deed_corner(at), FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE)
		assert_bool(paper.encloses(deed)).override_failure_message("%s: off the sheet" % site.id).is_true()
		var hit := Rect2(FarmRegister.HIT.position + at, FarmRegister.HIT.size)
		assert_bool(deed.intersects(hit)).override_failure_message("%s: its deed covers it" % site.id).is_false()
		assert_float(absf(deed.get_center().y - at.y)).is_less(FarmDeed.SIZE.y * FarmDeed.PIXELS_PER_METRE / 2.0)  # Level with it.


func test_the_deed_covers_what_lies_under_it_and_tucks_those_tokens_away() -> void:
	var sheet := _register()
	# A farm whose deed lies over another one's token.
	var pair := []
	for site: StringName in sheet._sites:
		var paper := Rect2(FarmRegister.deed_corner(sheet._pixel(site)), FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE)
		for other: StringName in sheet._sites:
			if pair.is_empty() and other != site and paper.has_point(sheet._pixel(other)):
				pair = [site, other]
	assert_array(pair).is_not_empty()
	var clicked: StringName = pair[0]
	var covered: StringName = pair[1]
	sheet.press(clicked)
	var under := sheet._pixel(covered)
	assert_str(sheet.spot_at(under)).is_equal(&"")
	assert_str(sheet.spot_at(sheet._pixel(clicked))).is_equal(clicked)
	sheet._moving[covered].custom_step(1.0)
	assert_bool(sheet.thing_up(sheet._index(covered))).is_false()
	assert_bool(sheet.thing_up(sheet._index(clicked))).is_true()
	sheet.press(&"")
	sheet._moving[covered].custom_step(1.0)
	assert_bool(sheet.thing_up(sheet._index(covered))).is_true()
	assert_str(sheet.spot_at(under)).is_equal(covered)


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
		var bill := FarmRegister.asking(SaveManager.save, StringName(site))  # The third farm, at each site's worth.
		assert_str(_tag(sheet, site).text).is_equal("ACQUIRED" if ours else "$%s + %s" % [FarmRegister.short_coins(bill.coins), FarmScreen._thousands(bill.stock)])
	assert_str(_tag(sheet, "K-2").text).is_equal("$450K + 3,500")
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
	assert_str(sheet.hint(&"K-7")).is_equal(_building(sheet, "K-7").title + ". Not for sale. The owner is unavailable.")


func test_the_hint_of_a_farm_not_for_sale_gives_the_same_reason_as_its_deed() -> void:
	SaveManager.save = _rich([])
	SaveManager.save.farms_owned = PackedStringArray(["K-1"])
	var sheet := _register()
	assert_str(sheet.hint(&"K-2")).is_equal(_building(sheet, "K-2").title + ". Not for sale. " + FarmRegister.reason(SaveManager.save))
	assert_str(sheet.hint(&"K-2")).contains("The owners will need persuading.")
	TranslationServer.set_locale("de")
	assert_str(sheet.hint(&"K-2")).ends_with("Unverkäuflich. Die Eigentümer müssen erst überzeugt werden.")


func test_the_hint_names_the_site_with_its_price_and_what_is_ours_never_what_is_short() -> void:
	var sheet := _register()
	var called := _building(sheet, "K-2").title
	assert_str(sheet.hint(&"K-2")).is_equal(called + ". Price: $60,000, 800 cabbages. Click for the deed.")
	SaveManager.save.coins = 59000
	SaveManager.save.stock = 790
	assert_str(sheet.hint(&"K-2")).is_equal(called + ". Price: $60,000, 800 cabbages. Click for the deed.")
	SaveManager.save.farms_owned.append("K-2")
	assert_str(sheet.hint(&"K-2")).is_equal(called + ". Company property.")


func test_the_tags_and_the_hint_are_german_in_german_and_still_say_cabbages() -> void:
	TranslationServer.set_locale("de")
	var sheet := _register()
	assert_str(sheet.hint(&"K-2")).is_equal(_building(sheet, "K-2").title + ". Preis: $60,000, 800 Kohlköpfe. Klicken für die Urkunde.")
	_buy(sheet, "K-1")
	assert_str(_tag(sheet, "K-1").text).is_equal("ERWORBEN")
	SaveManager.save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	sheet._process(0.0)
	assert_str(_tag(sheet, "K-8").text).is_equal("UNVERKÄUFLICH")
	for text: String in [sheet.hint(&"K-8"), sheet.hint(&"K-1")]:
		assert_bool(text.to_lower().contains("einheit")).is_false()


func test_a_site_is_pointed_at_on_its_disc_and_its_two_tags_and_nowhere_else() -> void:
	for country: StringName in [WorldRegister.HOME, &"sulvania"]:
		var sheet := _register(country)
		var sites := _sites(country)
		assert_int(sites.size()).is_equal(WorldRegister.COUNTRIES[country].farms)
		for site: Dictionary in sites:
			for pixel: Vector2 in [Vector2(site.x, site.y), Vector2(site.name_tag.x, site.name_tag.y), Vector2(site.price_tag.x, site.price_tag.y)]:
				assert_str(sheet.spot_at(pixel)).is_equal(site.id)
		assert_str(sheet.spot_at(Vector2(-1, -1))).is_equal(&"")  # Off the paper.
		var capital: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).country_maps[String(country)].capital
		assert_str(sheet.spot_at(Vector2(capital.x, capital.y))).is_equal(&"")  # The capital.


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
	assert_bool((deed.get_node("Strike") as SoundCue).playing).is_true()  # The deed stamp's slam.
	assert_bool((sheet.get_node("Flash/Acquire") as SoundCue).playing).is_false()  # The hit pause.
	sheet._dealing.custom_step(FarmRegister.HIT_PAUSE)
	assert_bool((sheet.get_node("Flash/Acquire") as SoundCue).playing).is_true()  # The token's thunk.
	assert_bool(FarmRegister.lamp_held).is_true()
	sheet._dealing.custom_step(FarmRegister.LAMP_AFTER)
	assert_bool(FarmRegister.lamp_held).is_false()  # The Field Line lights its lamp now, its relay heard at the map.
	assert_bool((deed.get_node("Roll") as SoundCue).playing).is_false()
	sheet._dealing.custom_step(FarmRegister.DEED_LEAVE_AFTER)
	assert_bool((deed.get_node("Roll") as SoundCue).playing).is_true()  # The deed rolls itself up.
	# The deed's stamp is its own, heavier slam, not the desk's approval press.
	var desk: Node = auto_free(load("res://entities/upgrade_desk/upgrade_desk.tscn").instantiate())
	var press := (desk.get_node("Stamp") as AudioStreamPlayer3D).stream as AudioStreamRandomizer
	var strike := (deed.get_node("Strike") as SoundCue).stream as AudioStreamRandomizer
	assert_object(strike.get_stream(0)).is_not_same(press.get_stream(0))


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
	assert_dict(FarmRegister.price(save, &"K-1")).is_empty()
	assert_dict(FarmRegister.short(save, &"K-1")).is_empty()  # Nothing is short: it is not sold.


func test_negotiation_opens_farms_two_to_four_at_their_price() -> void:
	var save := _rich(["negotiation"])
	for nth in 4:
		assert_dict(FarmRegister.price(save, StringName(SITES[nth]))).is_equal(FarmRegister.asking(save, StringName(SITES[nth]))).is_not_empty()
		assert_bool(FarmRegister.buy(save, StringName(SITES[nth]))).is_true()
	assert_int(save.farms_owned.size()).is_equal(4)
	assert_bool(FarmRegister.for_sale(save, &"K-5")).is_false()  # The fifth waits for more than talk.


func test_the_fifth_farm_needs_bribery() -> void:
	var save := _rich(["negotiation"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4"])
	assert_bool(FarmRegister.buy(save, &"K-5")).is_false()
	assert_str(FarmRegister.tag_text(save, &"K-5")).is_equal("NOT FOR SALE")
	save.stamped.append("bribery")
	assert_dict(FarmRegister.price(save, &"K-5")).is_equal({coins = 6250000, stock = 11250})  # 5,000,000 + 9,000 at K-5's worth.
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
	save.farms_owned = PackedStringArray(HAGGLED_BESIDE.slice(0, owned))
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


## A label on the negotiation letter lying over the deed.
func _record(sheet: FarmRegister, label: String) -> Label:
	return sheet.get_node("Deed/Haggle/Page/Form/" + label) as Label


## The letter's reply slips, oldest first.
func _slips(sheet: FarmRegister) -> Control:
	return sheet.get_node("Deed/Haggle/Page/Form/Slips") as Control


## A label of reply slip `i` (-1: the newest).
func _slip(sheet: FarmRegister, i: int, label: String) -> Label:
	return _slips(sheet).get_child(i).get_node(label) as Label


## Clicks the crate `bundles` times: each click lays a bundle on the offer (or is refused).
func _lay_bundles(sheet: FarmRegister, bundles: int) -> void:
	for i in bundles:
		sheet.press(FarmRegister.CRATE)
		sheet.release(FarmRegister.CRATE)


## The art pixel in the middle of a box of the laid-out deed (FarmDeed.DEED_BOXES) or, while it lies
## over the deed, of the negotiation record (FarmDeed.HAGGLE_BOXES).
func _spot(sheet: FarmRegister, spot: StringName) -> Vector2:
	if FarmDeed.HAGGLE_BOXES.has(spot):
		return sheet._deed_corner + FarmDeed.HAGGLE_PAGE * (FarmDeed.HAGGLE_BOXES[spot] as Rect2).get_center()
	return sheet._deed_corner + (FarmDeed.DEED_BOXES[spot] as Rect2).get_center()


func test_the_first_farm_is_bought_without_haggling() -> void:
	var save := _rich()
	assert_str(FarmRegister.tender(save, &"K-2")).is_empty()
	assert_int(FarmRegister.offers_left(save, &"K-2")).is_equal(0)
	assert_int(FarmRegister.offer(save, &"K-2", 100)).is_equal(-1)
	assert_int(save.stock).is_equal(30000)
	var sheet := _register()
	sheet.press(&"K-1")
	assert_bool((sheet.get_node("Deed/Page/Form/Start") as Control).visible).is_false()
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.HAGGLE))).is_equal(&"")
	assert_str(_form(sheet, "SmallPrint").text).is_equal(FarmDeed.SMALL_PRINT)
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.coins).is_equal(10000000 - 84000)


func test_a_farm_behind_a_card_can_be_stamped_at_the_asking_price_without_any_offer() -> void:
	var save := _haggling()
	assert_dict(FarmRegister.price(save, &"K-2")).is_equal(FarmRegister.PRICES[1])
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()
	assert_int(save.coins).is_equal(10000000 - FarmRegister.PRICES[1].coins)
	assert_int(save.stock).is_equal(30000 - FarmRegister.PRICES[1].stock)


func test_an_offers_cabbages_are_gone_whether_it_lands_or_not() -> void:
	for amount: int in [1, 10000]:
		var save := _haggling()
		var mood := FarmRegister.offer(save, &"K-2", amount)
		assert_bool(FarmRegister.landed(mood)).is_equal(amount == 10000)
		assert_int(save.stock).is_equal(30000 - amount)
		assert_int(save.coins).is_equal(10000000)
		assert_array(Array(FarmRegister.offers(save, &"K-2"))).is_equal([amount])


func test_too_few_cabbages_raise_the_price_its_cabbages_with_its_coins() -> void:
	var save := _haggling()
	FarmRegister.offer(save, &"K-2", FarmRegister.wanted(save, 0, &"K-2") - 1)
	var share: float = FarmRegister.price(save, &"K-2").coins / float(FarmRegister.PRICES[1].coins)
	assert_float(share).is_greater(1.0)
	assert_int(FarmRegister.price(save, &"K-2").stock).is_equal(roundi(FarmRegister.PRICES[1].stock * share))


func test_enough_cabbages_lower_the_price_its_cabbages_with_its_coins() -> void:
	var save := _haggling()
	FarmRegister.offer(save, &"K-2", FarmRegister.wanted(save, 0, &"K-2"))
	assert_int(FarmRegister.price(save, &"K-2").coins).is_equal(176000)  # 12% off the $200,000 asked.
	assert_int(FarmRegister.price(save, &"K-2").stock).is_equal(1760)  # And 12% off the 2,000 cabbages.
	var stock := save.stock
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()
	assert_int(save.coins).is_equal(10000000 - 176000)
	assert_int(save.stock).is_equal(stock - 1760)


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
	SaveManager.save.created = 7
	var sheet := _register()
	sheet.press(&"K-2")
	var numbers: Array[String] = []
	for nth in FarmRegister.ROUNDS:
		var wins: int = FarmRegister.moods(SaveManager.save, &"K-2").filter(FarmRegister.landed).size()
		numbers.append(str(FarmRegister.wanted(SaveManager.save, wins, &"K-2")))
		_lay_bundles(sheet, nth + 1)
		sheet.press(FarmRegister.SEND)
		_play_out(sheet)
		var mood: int = FarmRegister.moods(SaveManager.save, &"K-2")[-1]
		assert_str(_slip(sheet, -1, "Imprint/Word").text).is_equal(FarmDeed.MOODS["stock"][mood])
		for text in _printed(sheet.get_node("Deed/Page")):
			for number in numbers:
				assert_bool(text.contains(number)).override_failure_message("\"%s\" gives away %s" % [text, number]).is_false()
		assert_str(sheet.hint(&"K-2")).is_empty()
	assert_int(numbers.size()).is_equal(FarmRegister.ROUNDS)


func test_the_owners_reply_never_names_a_number() -> void:
	for paid_in: String in FarmRegister.REPLIES:
		for lines: Array in FarmRegister.REPLIES[paid_in]:
			for line: String in lines:
				for locale: String in ["en", "de"]:
					TranslationServer.set_locale(locale)
					assert_bool(RegEx.create_from_string("\\d").search(tr(line)) == null).override_failure_message(tr(line)).is_true()


func test_the_owner_wants_a_quarter_more_after_each_success() -> void:
	var save := _haggling()
	var first := FarmRegister.wanted(save, 0, &"K-2")
	for wins in 4:
		assert_float(FarmRegister.wanted(save, wins + 1, &"K-2") / float(FarmRegister.wanted(save, wins, &"K-2"))).is_equal_approx(1.25, 0.02)
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, &"K-2", first))).is_true()
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, &"K-2", first))).is_false()  # The same again is no longer enough.
	assert_int(FarmRegister.moods(save, &"K-2")[1]).is_equal(FarmRegister.Mood.LISTENING)  # Just short.
	var missed := _haggling()
	FarmRegister.offer(missed, &"K-2", 1)
	assert_bool(FarmRegister.landed(FarmRegister.offer(missed, &"K-2", first))).is_true()  # A miss makes him no greedier.


func test_the_fifth_offer_is_the_last() -> void:
	var save := _haggling()
	for nth in FarmRegister.ROUNDS:
		assert_int(FarmRegister.offers_left(save, &"K-2")).is_equal(FarmRegister.ROUNDS - nth)
		assert_int(FarmRegister.offer(save, &"K-2", 1)).is_equal(FarmRegister.Mood.INSULTED)
	assert_int(FarmRegister.ROUNDS).is_equal(5)
	assert_int(FarmRegister.offers_left(save, &"K-2")).is_equal(0)
	assert_int(FarmRegister.offer(save, &"K-2", 10000)).is_equal(-1)
	assert_int(save.stock).is_equal(30000 - 5)
	assert_int(FarmRegister.price(save, &"K-2").coins).is_equal(280000)  # Careless to the end: the ceiling, 40% on top.
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()  # And still for sale at that.


func test_the_price_stops_forty_percent_under_the_asking_price_and_no_offer_is_heard_there() -> void:
	var save := _haggling()
	for price: int in [176000, 152000, 128000, 120000]:
		FarmRegister.offer(save, &"K-2", 2000)
		assert_int(FarmRegister.price(save, &"K-2").coins).is_equal(price)
	assert_int(FarmRegister.offers_left(save, &"K-2")).is_equal(0)  # A fifth offer could only be lost.
	assert_int(FarmRegister.offer(save, &"K-2", 2000)).is_equal(-1)
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
		for site: String in SITES:  # The cheapest site and the dearest alike.
			var save := _haggling(owned)
			if save.farms_owned.has(site):
				continue
			var asked: int = FarmRegister.asking(save, StringName(site)).coins
			var at := 0
			while limits[at][0] < asked:  # The first limit that holds the asking price: what a player has.
				at += 1
			save.coin_limit = limits[at][0]
			FarmRegister.offer(save, StringName(site), 1)
			assert_int(FarmRegister.price(save, StringName(site)).coins).override_failure_message("farm %d at %s: a miss is free" % [owned + 1, site]).is_greater(asked)
			for more in 4:
				FarmRegister.offer(save, StringName(site), 1)
			var ceiling := roundi(asked * 1.4)
			assert_int(FarmRegister.price(save, StringName(site)).coins).is_equal(ceiling)
			# No dead end: every step up to the limit that holds the ceiling costs no more than the limit before it.
			while limits[at][0] < ceiling:
				at += 1
				assert_int(limits[at][1]).override_failure_message("farm %d at %s: the step to $%d" % [owned + 1, site, limits[at][0]]).is_less_equal(limits[at - 1][0])


func test_no_farm_or_war_costs_more_coins_than_the_highest_coin_limit_holds() -> void:
	var top: int = _coin_limits()[-1][0]
	for entry: Dictionary in WorldRegister.COUNTRIES.values():
		for bill: Dictionary in entry.wars:
			assert_int(bill.coins).override_failure_message(str(bill)).is_less_equal(top)
	for bill: Dictionary in FarmRegister.PRICES:  # Even the dearest site after five careless offers.
		assert_int(roundi(bill.coins * FarmRegister.WORTH.values().max() * (100 + FarmRegister.PRICE_CEILING) / 100.0)).is_less_equal(top)


func test_an_offer_and_a_stamped_purchase_are_written_to_the_save_at_once() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	SaveManager.save.last_played = 0  # SaveManager.write_save stamps the time (the file itself is not written in tests).
	_lay_bundles(sheet, 1)
	sheet.press(FarmRegister.SEND)
	assert_int(SaveManager.save.last_played).is_greater(0)  # Quitting now does not take the offer back.
	_play_out(sheet)
	SaveManager.save.last_played = 0
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.last_played).is_greater(0)


func test_offers_purchases_and_wars_started_go_into_the_playtest_log() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	_lay_bundles(sheet, 1)
	sheet.press(FarmRegister.SEND)  # One bundle of 25 cabbages for the second farm.
	_play_out(sheet)
	var bill := FarmRegister.price(SaveManager.save, &"K-2")
	sheet.press(FarmRegister.STAMP)
	_play_out(sheet)
	SaveManager.save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	SaveManager.save.stamped.append(FarmRegister.WAR_CARD)
	SaveManager.save.army = {field_associate = 1}
	sheet.refresh()
	var war := FarmRegister.war_bill(SaveManager.save, &"K-7")
	_buy(sheet, "K-7")  # The declaration of war: its coins, and the war starts.
	var rows := SaveManager.save.playtest_log.map(func(row: Dictionary) -> Array: return [row.kind, row.id, row.price, row.currency])
	assert_array(rows).contains_exactly([
		["offer", "2", 25, "stock"],
		["farm_bought", "K-2", bill.coins, "coins"], ["farm_bought", "K-2", bill.stock, "stock"],
		["war_declared", "K-7", war.coins, "coins"], ["war", "K-7", 0, ""]])


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
			var wants := FarmRegister.wanted(save, 0, &"K-2")
			assert_int(wants).is_between(haggle.low, haggle.high)
			seen[wants] = true
		assert_int(seen.size()).is_greater(30)  # Another save, another number.


func test_a_typical_offer_is_a_handful_of_bundles_and_a_full_offer_reaches_him_after_three_successes() -> void:
	var cheapest: float = FarmRegister.WORTH.values().min()
	for owned in range(1, 5):
		var haggle: Dictionary = FarmRegister.HAGGLES[owned]
		var save := _haggling(owned)
		assert_int(FarmRegister.bundle(save)).is_equal(haggle.bundle)
		assert_float(float(haggle.bundle)).is_less(haggle.low * cheapest)  # One bundle never lands at once.
		# Cabbages: 3 to 10 bundles; the bribe's coin stacks are fewer and heavier.
		assert_float((haggle.low + haggle.high) / 2.0 / haggle.bundle).is_between(3.0 if owned < 4 else 2.5, 10.0)
		# After three successes the price is a step off the floor at most; a full offer still lands then.
		assert_float(float(haggle.bundle * NegotiationLetter.MOST)).is_greater(haggle.high * pow(FarmRegister.GREED, 3))
	assert_int(FarmRegister.bundle(_rich())).is_equal(0)  # The first farm: nobody haggles.


func test_reloading_does_not_change_what_the_owner_has_in_mind() -> void:
	var save := _haggling()
	save.created = 1731542400
	FarmRegister.offer(save, &"K-2", 40)
	FarmRegister.offer(save, &"K-2", 10000)
	var path := "user://haggle_reload_test.tres"
	assert_int(ResourceSaver.save(save, path)).is_equal(OK)
	var loaded: SaveGame = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for wins in 4:
		assert_int(FarmRegister.wanted(loaded, wins, &"K-2")).is_equal(FarmRegister.wanted(save, wins, &"K-2"))
	assert_array(Array(FarmRegister.offers(loaded, &"K-2"))).is_equal([40, 10000])  # The rounds used.
	assert_dict(FarmRegister.price(loaded, &"K-2")).is_equal(FarmRegister.price(save, &"K-2"))  # The price they left.
	assert_array(FarmRegister.moods(loaded, &"K-2")).is_equal(FarmRegister.moods(save, &"K-2"))
	assert_int(FarmRegister.offers_left(loaded, &"K-2")).is_equal(3)
	# The number is in no field of the save: it follows from the day the save was made.
	var other := _haggling()
	other.created = save.created + 1
	var differs := false
	for wins in 4:
		differs = differs or FarmRegister.wanted(other, wins, &"K-2") != FarmRegister.wanted(save, wins, &"K-2")
	assert_bool(differs).is_true()


func test_a_negotiation_in_progress_survives_closing_the_deed_and_a_reload() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	_lay_bundles(sheet, 3)
	sheet.press(FarmRegister.SEND)
	_play_out(sheet)
	var price: int = FarmRegister.price(SaveManager.save, &"K-2").coins
	assert_int(price).is_not_equal(200000)
	sheet.press(&"")  # The deed away.
	assert_str(sheet.deed_site()).is_equal(&"")
	var loaded := _register()  # The same save, a fresh sheet.
	assert_str(_tag(loaded, "K-2").text).is_equal("$%s + %s" % [FarmRegister.short_coins(price), FarmScreen._thousands(FarmRegister.price(SaveManager.save, &"K-2").stock)])
	assert_str(_tag(loaded, "K-3").text).is_equal("$230K + 2,300")  # Another owner: still his own asking price.
	loaded.press(&"K-2")
	assert_str(_form(loaded, "Coins").text).is_equal("$" + FarmScreen._thousands(price))
	assert_str(_form(loaded, "Asked").text).is_equal("ASKED $200,000")
	assert_bool(_form(loaded, "Asked").visible).is_true()
	assert_str(_record(loaded, "Pile/Head").text).is_equal("OFFER 2 OF 5")
	assert_int(_slips(loaded).get_child_count()).is_equal(1)
	var mood: int = FarmRegister.moods(SaveManager.save, &"K-2")[0]
	assert_str(_slip(loaded, 0, "Imprint/Word").text).is_equal(FarmDeed.MOODS["stock"][mood])
	assert_str(_slip(loaded, 0, "Line").text).is_equal(FarmRegister.reply(SaveManager.save, &"K-2", 0, mood, "stock"))
	assert_str(_slip(loaded, 0, "About").text).is_equal("re: 75 cabbages")
	assert_int((loaded.get_node("Deed") as FarmDeed).negotiation.count).is_equal(0)  # Nothing lies on a fresh offer.


func test_half_of_a_missed_offer_comes_back_once_rejected_goods_are_recovered() -> void:
	var save := _haggling()
	save.stamped.append("rejected_goods")
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, &"K-2", 30))).is_false()
	assert_int(save.stock).is_equal(30000 - 15)
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, &"K-2", 10000))).is_true()
	assert_int(save.stock).is_equal(30000 - 15 - 10000)  # An offer that lands is still fully spent.
	assert_str(FarmRegister.RECOVER).is_equal("rejected_goods")
	var card := UpgradeDesk.card_data(FarmRegister.RECOVER)
	assert_int(card.farms).is_equal(2)
	assert_array(card.needs).is_equal(["negotiation"])
	assert_array(UpgradeDesk.card_data("bribery").needs).is_equal([FarmRegister.RECOVER])
	var bribe := _haggling(4)
	bribe.stamped.append("rejected_goods")
	FarmRegister.offer(bribe, &"K-2", 30000)
	assert_int(bribe.coins).is_equal(10000000 - 15000)  # Half of a missed envelope too.
	assert_str(FarmRegister.haggle_note(bribe, &"K-2")).is_equal("Half of a refused offer is returned.")


func test_a_bribe_is_haggled_in_coins() -> void:
	var save := _haggling(4)
	assert_str(FarmRegister.tender(save, &"K-2")).is_equal("coins")
	assert_str(FarmRegister.tender(_haggling(1), &"K-2")).is_equal("stock")
	var wants := FarmRegister.wanted(save, 0, &"K-2")
	assert_int(wants).is_between(FarmRegister.HAGGLES[4].low, FarmRegister.HAGGLES[4].high)
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, &"K-2", wants - 1))).is_false()
	assert_bool(FarmRegister.landed(FarmRegister.offer(save, &"K-2", wants))).is_true()
	assert_int(save.coins).is_equal(10000000 - 2 * wants + 1)  # Both envelopes are gone.
	assert_int(save.stock).is_equal(30000)
	assert_int(FarmRegister.price(save, &"K-2").coins).is_equal(5000000 + 50000 * FarmRegister.MOOD_STEP[FarmRegister.mood_of(wants - 1, wants)] - 600000)
	assert_int(FarmRegister.price(save, &"K-2").stock).is_equal(roundi(9000 * FarmRegister.price(save, &"K-2").coins / 5000000.0))  # The cabbages move with the coins.
	SaveManager.save = save
	var sheet := _register()
	sheet.press(&"K-2")
	assert_str(_record(sheet, "Send/Word").text).is_equal("PASS THE ENVELOPE")
	assert_str(_slip(sheet, 0, "Imprint/Word").text).is_equal("CONSIDERED")
	assert_str(_slip(sheet, 1, "Imprint/Word").text).is_equal("UNDERSTOOD")
	assert_str(_slip(sheet, 1, "About").text).is_equal("re: $" + FarmScreen._thousands(wants))
	assert_bool(FarmRegister.REPLIES["coins"][FarmRegister.Mood.INTRIGUED].has(_slip(sheet, 1, "Line").text)).is_true()
	_lay_bundles(sheet, 2)  # Coins from the purse: stacks, not cabbages.
	var letter := (sheet.get_node("Deed") as FarmDeed).negotiation
	assert_int(letter.offered()).is_equal(2 * FarmRegister.HAGGLES[4].bundle)
	assert_bool((letter.get_node("Bundles").get_child(0) as OfferBundle).coins).is_true()
	assert_str(_record(sheet, "Pile/Total").text).is_equal("$" + FarmScreen._thousands(2 * FarmRegister.HAGGLES[4].bundle))


func test_a_dear_farms_owner_is_harder_to_talk_down() -> void:
	for owned in range(1, 5):
		var save := _haggling(owned)
		var cheap := 0
		var dear := 0
		for created in 100:  # Each owner draws his own number; the dear site's is the larger on average.
			save.created = 1731542400 + created * 3600
			cheap += FarmRegister.wanted(save, 0, &"K-8")
			dear += FarmRegister.wanted(save, 0, &"K-5")
			var haggle: Dictionary = FarmRegister.HAGGLES[owned]
			assert_int(FarmRegister.wanted(save, 0, &"K-5")).is_between(floori(haggle.low * FarmRegister.worth(&"K-5")), ceili(haggle.high * FarmRegister.worth(&"K-5")))
		assert_float(dear / float(cheap)).is_greater(1.5)
		# One step off the price is the dear farm's share of its own price.
		var asked: int = FarmRegister.asking(save, &"K-5").coins
		assert_int(FarmRegister.price_after(save, &"K-5", FarmRegister.Mood.INTRIGUED)).is_equal(asked - roundi(asked * 0.12))


func test_a_farm_we_own_does_not_react_to_the_mouse() -> void:
	SaveManager.save.farms_owned = PackedStringArray(["K-3"])
	var sheet := _register()
	var at := sheet._pixel(&"K-3")
	assert_str(sheet.spot_at(at)).is_equal(&"")  # No spot: MapTable gives it no hover sound, cursor or hint slip.
	assert_str(sheet.spot_at(sheet._pixel(&"K-4"))).is_equal(&"K-4")  # A farm not ours still does.
	sheet.hover(sheet.spot_at(at))
	assert_float(sheet._raised(&"K-3")).is_equal_approx(1.0, 0.001)  # Not lifted.
	sheet.press(sheet.spot_at(at))
	assert_str(sheet.deed_site()).is_equal(&"")  # No deed.


func test_each_farm_keeps_its_own_negotiation() -> void:
	SaveManager.save = _haggling()
	var save := SaveManager.save
	FarmRegister.offer(save, &"K-2", 10000)
	assert_str(FarmRegister.tender(save, &"K-7")).is_equal("stock")  # Every other owner still hears offers.
	FarmRegister.offer(save, &"K-7", 1)
	FarmRegister.offer(save, &"K-7", 1)
	assert_array(Array(FarmRegister.offers(save, &"K-2"))).is_equal([10000])
	assert_array(Array(FarmRegister.offers(save, &"K-7"))).is_equal([1, 1])
	assert_int(FarmRegister.offers_left(save, &"K-2")).is_equal(FarmRegister.ROUNDS - 1)
	assert_int(FarmRegister.offers_left(save, &"K-7")).is_equal(FarmRegister.ROUNDS - 2)
	assert_int(FarmRegister.price(save, &"K-2").coins).is_less(200000)
	assert_int(FarmRegister.price(save, &"K-7").coins).is_greater(FarmRegister.asking(save, &"K-7").coins)  # The bad offers stick to his farm.
	var sheet := _register()
	sheet.press(&"K-7")
	assert_bool((sheet.get_node("Deed/Page/Form/Start") as Control).visible).is_true()
	assert_str(_form(sheet, "Start/Word").text).is_equal("RESUME HAGGLING")
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.HAGGLE))).is_equal(FarmRegister.HAGGLE)
	assert_int(_slips(sheet).get_child_count()).is_equal(2)
	sheet.press(&"K-2")  # Another owner's letter: his own replies.
	assert_int(_slips(sheet).get_child_count()).is_equal(1)
	assert_str(_record(sheet, "Owner").text).is_equal("Owner: " + FarmRegister.owner_of(&"K-2"))
	assert_bool(FarmRegister.buy(save, &"K-7")).is_true()  # A farm bought: every owner starts over.
	assert_dict(save.haggles).is_empty()
	assert_dict(FarmRegister.price(save, &"K-2")).is_equal(FarmRegister.asking(save, &"K-2"))


func test_haggling_with_one_owner_leaves_another_owners_price_alone() -> void:
	var save := _haggling()
	var asked := FarmRegister.asking(save, &"K-8")
	for amount: int in [1, 10000, 1]:
		FarmRegister.offer(save, &"K-2", amount)
	assert_dict(FarmRegister.price(save, &"K-8")).is_equal(asked)
	assert_int(FarmRegister.offers_left(save, &"K-8")).is_equal(FarmRegister.ROUNDS)
	assert_array(FarmRegister.moods(save, &"K-8")).is_empty()


func test_what_one_owner_wants_says_nothing_about_the_next() -> void:
	var differs := 0
	for created in 20:
		var save := _haggling()
		save.created = 1731542400 + created * 3600
		var two := FarmRegister.wanted(save, 0, &"K-2") / FarmRegister.worth(&"K-2")
		var seven := FarmRegister.wanted(save, 0, &"K-7") / FarmRegister.worth(&"K-7")
		differs += int(absf(two - seven) > 2.0)
	assert_int(differs).is_greater(10)


func test_every_home_owner_has_his_own_name() -> void:
	var names := {}
	for site: String in SITES:
		assert_str(FarmRegister.owner_of(StringName(site))).override_failure_message(site).is_not_empty()
		names[FarmRegister.owner_of(StringName(site))] = true
	assert_int(names.size()).is_equal(SITES.size())


func test_the_owners_reply_matches_his_mood() -> void:
	var save := _haggling()
	for paid_in: String in FarmRegister.REPLIES:
		assert_int(FarmRegister.REPLIES[paid_in].size()).is_equal(FarmRegister.Mood.size())
		for mood in FarmRegister.Mood.size():
			for nth in FarmRegister.ROUNDS:
				var line := FarmRegister.reply(save, &"K-2", nth, mood, paid_in)
				assert_bool(FarmRegister.REPLIES[paid_in][mood].has(line)).override_failure_message(line).is_true()
				assert_str(FarmRegister.reply(save, &"K-2", nth, mood, paid_in)).is_equal(line)  # The same every time.
	TranslationServer.set_locale("de")
	for paid_in: String in FarmRegister.REPLIES:
		for lines: Array in FarmRegister.REPLIES[paid_in]:
			for line: String in lines:
				assert_str(tr(line)).override_failure_message(line).is_not_equal(line)


func test_an_old_save_with_the_single_haggle_field_loads_onto_that_owners_farm() -> void:
	var old := _haggling()
	old.haggle_site = "K-2"
	old.haggle_offers = PackedInt32Array([40, 10000])
	old.haggle_price = 183000
	var path := "user://haggle_old_save_test.tres"
	assert_int(ResourceSaver.save(old, path)).is_equal(OK)
	var loaded: SaveGame = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_array(Array(FarmRegister.offers(loaded, &"K-2"))).is_equal([40, 10000])
	assert_int(FarmRegister.price(loaded, &"K-2").coins).is_equal(183000)
	assert_dict(FarmRegister.price(loaded, &"K-3")).is_equal(FarmRegister.asking(loaded, &"K-3"))
	assert_int(FarmRegister.offers_left(loaded, &"K-3")).is_equal(FarmRegister.ROUNDS)
	assert_str(loaded.haggle_site).is_empty()  # Moved, not kept twice.
	assert_int(ResourceSaver.save(loaded, path)).is_equal(OK)
	var again: SaveGame = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_array(Array(FarmRegister.offers(again, &"K-2"))).is_equal([40, 10000])
	assert_array(Array(again.haggle_offers)).is_empty()
	var fresh := SaveGame.new()  # A save that never haggled reads nothing.
	assert_dict(FarmRegister.haggle(fresh, &"K-2")).is_empty()


func test_an_offer_the_desk_does_not_hold_is_refused_and_changes_nothing() -> void:
	var save := _haggling()
	save.stock = 29
	assert_int(FarmRegister.offer(save, &"K-2", 30)).is_equal(-1)
	assert_int(FarmRegister.offer(save, &"K-2", 30, Vector2i.ZERO)).is_equal(-1)
	save.stock = 33
	assert_int(FarmRegister.offer(save, &"K-2", 30, Vector2i(4, 0))).is_equal(-1)  # 4 of them lie on the mat.
	assert_int(save.stock).is_equal(33)
	assert_array(Array(FarmRegister.offers(save, &"K-2"))).is_empty()
	assert_dict(FarmRegister.price(save, &"K-2")).is_equal(FarmRegister.PRICES[1])
	SaveManager.save = save
	save.stock = 24  # Less than one bundle.
	var sheet := _register()
	sheet.press(&"K-2")
	_lay_bundles(sheet, 1)
	assert_int((sheet.get_node("Deed") as FarmDeed).negotiation.count).is_equal(0)  # The crate gives nothing out.
	sheet.press(FarmRegister.SEND)
	assert_object(sheet._dealing).is_null()
	assert_object((sheet.get_node("Deed") as FarmDeed)._blinking).is_not_null()
	assert_bool((sheet.get_node("Deed/Denied") as SoundCue).playing).is_true()


func test_buying_the_farm_closes_its_negotiation_and_the_next_owner_starts_at_his_asking_price() -> void:
	var save := _haggling()
	FarmRegister.offer(save, &"K-2", 10000)
	assert_bool(FarmRegister.buy(save, &"K-2")).is_true()
	assert_dict(save.haggles).is_empty()
	assert_dict(FarmRegister.price(save, &"K-8")).is_equal(FarmRegister.asking(save, &"K-8"))
	assert_int(FarmRegister.offers_left(save, &"K-8")).is_equal(FarmRegister.ROUNDS)
	# A farm that comes any other way closes it too.
	SaveManager.save = _haggling()
	var sheet := _register()
	FarmRegister.offer(SaveManager.save, &"K-2", 10000)
	DebugKeys.press(KEY_5, SaveManager.save)
	sheet._process(0.0)
	assert_dict(SaveManager.save.haggles).is_empty()
	assert_dict(FarmRegister.price(SaveManager.save, &"K-8")).is_equal(FarmRegister.asking(SaveManager.save, &"K-8"))


func test_a_cabbage_from_the_crate_lies_on_the_offer_and_taking_it_back_lowers_the_offer() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	var letter := deed.negotiation
	sheet.press(&"K-2")
	sheet.press(FarmRegister.HAGGLE)
	for spot: StringName in [FarmRegister.CRATE, FarmRegister.PILE, FarmRegister.SEND, FarmRegister.RETURN]:
		assert_str(sheet.spot_at(_spot(sheet, spot))).is_equal(spot)
	assert_str(_record(sheet, "Pile/Head").text).is_equal("OFFER 1 OF 5")
	assert_str(_record(sheet, "Pile/Total").text).is_equal("0 cabbages")
	assert_str(_record(sheet, "Note").text).is_equal("Cabbages offered are not returned.")
	# Dragged from the crate onto the offer: it follows the mouse there and lies down.
	sheet.spot_at(_spot(sheet, FarmRegister.CRATE))
	sheet.press(FarmRegister.CRATE)
	assert_bool(letter.holding()).is_true()
	sheet.drag(_spot(sheet, FarmRegister.PILE))
	sheet.release(FarmRegister.PILE)
	assert_int(letter.count).is_equal(1)
	assert_str(_record(sheet, "Pile/Total").text).is_equal("25 cabbages")
	assert_bool((letter.get_node("Thud") as SoundCue).playing).is_true()
	# Dragged and let go anywhere else: back into the crate.
	sheet.spot_at(_spot(sheet, FarmRegister.CRATE))
	sheet.press(FarmRegister.CRATE)
	sheet.drag(_spot(sheet, FarmRegister.RETURN))
	sheet.release(FarmRegister.RETURN)
	assert_int(letter.count).is_equal(1)
	_lay_bundles(sheet, 2)  # Clicked: straight onto the offer.
	assert_str(_record(sheet, "Pile/Total").text).is_equal("75 cabbages")
	assert_int(SaveManager.save.stock).is_equal(30000)  # Nothing is offered until it is sent.
	sheet.spot_at(_spot(sheet, FarmRegister.PILE))
	sheet.press(FarmRegister.PILE)  # A click on the offer takes one back.
	assert_int(letter.count).is_equal(2)
	assert_str(_record(sheet, "Pile/Total").text).is_equal("50 cabbages")
	sheet.hover(FarmRegister.CRATE)
	assert_object((deed.get_node("Haggle/Page/Form/Crate") as Control).get_theme_stylebox(&"panel")).is_same(letter.hot_box)
	assert_object((deed.get_node("Page/Form/Box") as Control).get_theme_stylebox(&"panel")).is_not_same(deed.hot_box)
	sheet.press(FarmRegister.RETURN)  # The letter goes; what lay on it goes back to the crate.
	assert_int(letter.count).is_equal(0)


func test_the_offer_holds_no_more_than_stock_and_its_room() -> void:
	SaveManager.save = _haggling()
	SaveManager.save.stock = 60  # Two bundles of 25.
	var sheet := _register()
	var letter := (sheet.get_node("Deed") as FarmDeed).negotiation
	sheet.press(&"K-2")
	_lay_bundles(sheet, 3)
	assert_int(letter.count).is_equal(2)
	assert_bool((sheet.get_node("Deed/Denied") as SoundCue).playing).is_true()
	SaveManager.save.stock = 30000
	_lay_bundles(sheet, NegotiationLetter.MOST + 3)
	assert_int(letter.count).is_equal(NegotiationLetter.MOST)


func test_a_sent_offer_costs_the_cabbages_on_the_paper() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	_lay_bundles(sheet, 4)
	sheet.press(FarmRegister.SEND)
	assert_int(SaveManager.save.stock).is_equal(30000 - 4 * 25)
	assert_array(Array(FarmRegister.offers(SaveManager.save, &"K-2"))).is_equal([100])
	assert_int((sheet.get_node("Deed") as FarmDeed).negotiation.count).is_equal(0)  # Carried off the paper.


func test_a_sent_offer_brings_his_reply_slip_and_the_stamp_comes_down_on_his_mood() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
	_lay_bundles(sheet, 1)
	sheet.press(FarmRegister.SEND)  # 25 cabbages: a miss.
	assert_int(SaveManager.save.stock).is_equal(30000 - 25)  # Gone at once.
	assert_int(_slips(sheet).get_child_count()).is_equal(0)  # The pile goes first; his reply follows.
	assert_str(_form(sheet, "Coins").text).is_equal("$200,000")
	sheet.press(FarmRegister.STAMP)  # No click meanwhile.
	assert_array(Array(SaveManager.save.farms_owned)).is_equal(["K-1"])
	sheet._dealing.custom_step(FarmRegister.SEND_TIME + 0.01)
	assert_int(_slips(sheet).get_child_count()).is_equal(1)
	var price: int = FarmRegister.price(SaveManager.save, &"K-2").coins
	assert_int(price).is_greater(200000)
	assert_str(_form(sheet, "Coins").text).is_equal("$" + FarmScreen._thousands(price))
	var stamp := deed.get_node("Stamp") as Node3D
	assert_bool(stamp.visible).is_true()
	var on := FarmDeed.HAGGLE_PAGE * deed.negotiation.stamp_spot()
	assert_float(stamp.position.z).is_equal_approx(on.y / FarmDeed.PIXELS_PER_METRE, 0.001)
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + 0.01)
	assert_bool((deed.get_node("MoodStamp") as SoundCue).playing).is_true()
	assert_bool((deed.get_node("PriceUp") as SoundCue).playing).is_true()  # A miss: the price goes up.
	assert_bool((deed.get_node("Agreed") as SoundCue).playing).is_false()
	assert_bool(deed.stamped).is_false()  # Nothing is bought by it.
	_play_out(sheet)
	assert_object(sheet._dealing).is_null()
	_lay_bundles(sheet, NegotiationLetter.MOST)
	sheet.press(FarmRegister.SEND)  # 375: more than he ever asks.
	sheet._dealing.custom_step(FarmRegister.SEND_TIME + FarmRegister.STAMP_DROP_TIME + 0.02)
	assert_bool((deed.get_node("Agreed") as SoundCue).playing).is_true()
	assert_str(_slip(sheet, 1, "Imprint/Word").text).is_equal("DELIGHTED")
	_play_out(sheet)
	var bill := FarmRegister.price(SaveManager.save, &"K-2")
	sheet.press(FarmRegister.STAMP)  # The deed is stamped at the price it shows.
	assert_int(SaveManager.save.coins).is_equal(10000000 - bill.coins)
	assert_float(stamp.position.z).is_equal_approx(FarmDeed.STAMP_BOX.get_center().y / FarmDeed.PIXELS_PER_METRE, 0.001)


func test_after_the_last_offer_the_offer_gives_way_to_no_further_offers_and_the_deed_can_still_be_stamped() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	for nth in FarmRegister.ROUNDS:
		_lay_bundles(sheet, 1)
		sheet.press(FarmRegister.SEND)
		_play_out(sheet)
	assert_bool(_record(sheet, "Pile/Closed").visible).is_true()
	assert_bool((sheet.get_node("Deed/Haggle/Page/Form/Send") as Control).visible).is_false()
	assert_bool((sheet.get_node("Deed/Haggle/Crate") as Node3D).visible).is_false()
	assert_str(_record(sheet, "Pile/Head").text).is_equal("YOUR OFFER")
	assert_int(_slips(sheet).get_child_count()).is_equal(5)
	sheet.press(FarmRegister.HAGGLE)
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.SEND))).is_equal(&"")
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.CRATE))).is_equal(&"")
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.RETURN))).is_equal(FarmRegister.RETURN)
	sheet.press(FarmRegister.RETURN)
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)


func test_the_replies_pile_up_in_order_the_newest_lowest() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	sheet.press(&"K-2")
	for bundles: int in [1, 2, 3]:
		_lay_bundles(sheet, bundles)
		sheet.press(FarmRegister.SEND)
		_play_out(sheet)
	var said := FarmRegister.moods(SaveManager.save, &"K-2")
	for i in 3:
		assert_str(_slip(sheet, i, "About").text).is_equal("re: %d cabbages" % (25 * (i + 1)))
		assert_str(_slip(sheet, i, "Imprint/Word").text).is_equal(FarmDeed.MOODS["stock"][said[i]])
		if i > 0:
			assert_float((_slips(sheet).get_child(i) as Control).position.y).is_greater((_slips(sheet).get_child(i - 1) as Control).position.y)


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


func test_the_home_country_is_ours_once_its_last_three_farms_are_won_in_war() -> void:
	var save := _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	save.coin_limit = 1000000000
	save.coins = 1000000000
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	var wars: Array = WorldRegister.COUNTRIES[WorldRegister.HOME].wars
	assert_int(wars.size()).is_equal(Events.HOME_SITES - Events.HOME_SELLERS)
	for nth in wars.size():
		var site := StringName(SITES[Events.HOME_SELLERS + nth])
		assert_bool(Events.due("home_country", save)).is_false()
		assert_dict(FarmRegister.war_bill(save, site)).is_equal(wars[nth])
		assert_bool(WarSheet.win(save, site)).is_true()  # Paid at the declaration, not here.
	assert_int(Events.home_farms(save)).is_equal(Events.HOME_SITES)
	assert_bool(Events.due("home_country", save)).is_true()
	# Nothing is left to take at home.
	assert_dict(FarmRegister.price(save, &"K-2")).is_empty()
	for site: String in SITES:
		assert_dict(FarmRegister.war_bill(save, StringName(site))).is_empty()


func test_farms_abroad_do_not_change_what_the_next_home_war_costs() -> void:
	var save := _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	WorldRegister.annex(save, &"ostrevia")
	WorldRegister.annex(save, &"sulvania")
	var wars: Array = WorldRegister.COUNTRIES[WorldRegister.HOME].wars
	assert_dict(FarmRegister.war_bill(save, &"K-8")).is_equal(wars[0])
	save.farms_owned.append("K-6")
	assert_dict(FarmRegister.war_bill(save, &"K-8")).is_equal(wars[1])


## The home country at war: five farms bought, the war card, field associates ready.
func _at_war(staff := 3) -> FarmRegister:
	SaveManager.save = _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	SaveManager.save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	SaveManager.save.army = {field_associate = staff} if staff > 0 else {}
	return _register()


## The art pixel in the middle of the laid-out declaration's [-] (or [+]) box of its first staff row.
func _staff_box(sheet: FarmRegister, more := false) -> Vector2:
	var box := FarmDeed.MORE_IN_ROW if more else FarmDeed.LESS_IN_ROW
	return sheet._deed_corner + FarmDeed.STAFF_AT + box.get_center()


func test_a_farm_nobody_sells_gets_a_declaration_of_war_whose_stamp_charges_coins_and_takes_the_chosen_staff() -> void:
	var sheet := _at_war()
	var bill: Dictionary = WorldRegister.COUNTRIES[WorldRegister.HOME].wars[0]
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	assert_str(_tag(sheet, "K-7").text).is_equal("$" + FarmRegister.short_coins(bill.coins))
	assert_str(sheet.hint(&"K-7")).contains("Click to declare war")
	sheet.press(&"K-7")
	var deed: FarmDeed = sheet.get_node("Deed")
	assert_str((deed.get_node("Page/Form/FormLine") as Label).text).is_equal("FORM 9-W  DECLARATION OF WAR")
	assert_str((deed.get_node("Page/Form/PriceHead") as Label).text).is_equal("COST OF WAR")
	assert_str((deed.get_node("Page/Form/Cabbages") as Label).text).is_equal("")  # Coins only.
	assert_str((deed.get_node("Page/Form/Imprint/Word") as Label).text).is_equal("WAR")
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_bool((deed.get_node("Page/Form/Start") as Control).visible).is_false()  # Nobody haggles over a war.
	var row := deed.get_node("Page/Form/Staff/field_associate")
	assert_str((row.get_node("Have") as Label).text).is_equal("HAVE 3")
	assert_str((row.get_node("Take") as Label).text).is_equal("3")  # Everybody ready goes, unless told otherwise.
	assert_bool((deed.get_node("Figures/field_associate") as Node3D).is_visible_in_tree()).is_true()
	assert_str(sheet.spot_at(_staff_box(sheet))).is_equal(&"staff_less:field_associate")
	sheet.press(sheet.spot_at(_staff_box(sheet)))
	assert_str((row.get_node("Take") as Label).text).is_equal("2")
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)
	sheet.press(FarmRegister.STAMP)
	_play_out(sheet)
	assert_array(wanted).is_equal([[FarmRegister.WAR, &"K-7"]])  # The table rolls out the war sheet for it.
	assert_dict(sheet.committed).is_equal({field_associate = 2})
	assert_dict(SaveManager.save.army).is_equal({field_associate = 1})
	assert_int(SaveManager.save.farms_owned.size()).is_equal(Events.HOME_SELLERS)
	assert_int(SaveManager.save.coins).is_equal(10000000 - bill.coins)
	assert_int(SaveManager.save.stock).is_equal(30000)  # No cabbages: they went into the staff.


func test_a_declaration_with_nobody_chosen_cannot_be_stamped() -> void:
	var sheet := _at_war(1)
	var coins := SaveManager.save.coins
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	sheet.press(&"K-7")
	sheet.press(&"staff_less:field_associate")
	sheet.press(&"staff_less:field_associate")  # Not below none.
	assert_int(int(sheet._take.field_associate)).is_equal(0)
	sheet.press(FarmRegister.STAMP)
	_play_out(sheet)
	assert_array(wanted).is_empty()
	assert_int(SaveManager.save.coins).is_equal(coins)
	assert_dict(SaveManager.save.army).is_equal({field_associate = 1})
	assert_bool((sheet.get_node("Deed/Denied") as SoundCue).playing).is_true()


func test_a_declaration_cannot_send_more_staff_than_are_ready() -> void:
	var sheet := _at_war(2)
	sheet.press(&"K-7")
	sheet.press(&"staff_more:field_associate")
	assert_int(int(sheet._take.field_associate)).is_equal(2)
	assert_bool(FarmRegister.can_declare(SaveManager.save, &"K-7", {field_associate = 3})).is_false()
	assert_bool(FarmRegister.can_declare(SaveManager.save, &"K-7", {field_associate = 2})).is_true()


func test_a_declaration_short_of_coins_is_refused_and_nothing_changes() -> void:
	var save := _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	save.army = {field_associate = 3}
	save.coins = 1000
	assert_bool(FarmRegister.declare(save, &"K-7", {field_associate = 3})).is_false()
	assert_int(save.coins).is_equal(1000)
	assert_dict(save.army).is_equal({field_associate = 3})


func test_a_declaration_scouts_the_farms_defences() -> void:
	var sheet := _at_war()
	sheet.press(&"K-7")
	var deed: FarmDeed = sheet.get_node("Deed")
	assert_bool((deed.get_node("Scout") as Node3D).visible).is_true()
	assert_int(deed.get_node("Scout").get_child_count()).is_equal(1)
	assert_str((deed.get_node("Page/Form/Defences") as Label).text).contains("CANNONS 2")
	assert_str((deed.get_node("Page/Form/Defences") as Label).text).contains("MORTARS 1")


func test_a_farm_abroad_out_of_reach_gets_a_war_order_with_a_strip_and_no_stamp_box() -> void:
	SaveManager.save = _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	SaveManager.save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))  # Kohlmark is not wholly ours.
	var sheet := _register(&"ostrevia")
	assert_str(_tag(sheet, "ostrevia-1").text).is_equal(WorldRegister.NOT_ADJACENT)
	sheet.press(&"ostrevia-1")
	var deed: FarmDeed = sheet.get_node("Deed")
	assert_str((deed.get_node("Page/Form/FormLine") as Label).text).is_equal("FORM 9-W  DECLARATION OF WAR")
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_true()
	assert_bool((deed.get_node("Page/Form/Staff") as Control).visible).is_false()  # Nothing to send yet.
	assert_str((deed.get_node("Page/Form/Strip/Word") as Label).text).is_equal(WorldRegister.NOT_ADJACENT)
	assert_str((deed.get_node("Page/Form/Reason") as Label).text).is_equal("No country next to this one is wholly ours. Yet.")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	assert_str(sheet.spot_at(_box(sheet))).is_equal(&"")
	# The country next door becomes wholly ours while the order lies there: it gets its cost and its stamp box.
	WorldRegister.annex(SaveManager.save, WorldRegister.HOME)
	sheet._process(0.0)
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)
	assert_dict(deed.bill).is_equal(WorldRegister.COUNTRIES[&"ostrevia"].wars[0])


func test_nothing_abroad_is_bought_or_haggled_over() -> void:
	var save := _rich(["negotiation", "bribery", "rejected_goods", FarmRegister.WAR_CARD])
	save.farms_owned = PackedStringArray(SITES.slice(0, 3))  # The next home farm is for sale.
	for country: StringName in WorldRegister.COUNTRIES:
		if country != WorldRegister.HOME:
			for site in WorldRegister.farm_ids(country):
				assert_bool(FarmRegister.for_sale(save, StringName(site))).override_failure_message(site).is_false()
				assert_bool(FarmRegister.buy(save, StringName(site))).override_failure_message(site).is_false()
	assert_int(save.farms_owned.size()).is_equal(3)


func test_a_farm_won_in_war_plays_its_moment_once_its_country_sheet_lies_open_again() -> void:
	SaveManager.save = _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	SaveManager.save.farms_owned = PackedStringArray(SITES.slice(0, Events.HOME_SELLERS))
	var sheet := _register()
	assert_bool(WarSheet.win(SaveManager.save, &"K-6")).is_true()
	sheet.expect(&"K-6")  # Won while the sheet lay rolled up: not shown as ours yet.
	assert_bool(_building(sheet, "K-6").owned).is_false()
	sheet.celebrate(&"K-6")
	assert_bool(_building(sheet, "K-6").owned).is_true()
	assert_str(_tag(sheet, "K-6").text).is_equal("ACQUIRED")
	assert_bool((sheet.get_node("Flash/Swap") as SoundCue).playing).is_true()
	assert_bool((sheet.get_node("Flash/SpreadShort") as SoundCue).playing).is_true()
	FarmRegister.lamp_held = true
	sheet._dealing.custom_step(FarmRegister.LAMP_AFTER + 0.01)
	assert_bool(FarmRegister.lamp_held).is_false()  # The Field Line lights its lamp.
	sheet._spread_tween.custom_step(10.0)
	assert_float(_reach(sheet)["K-6"]).is_equal(1.0)


func test_when_a_countrys_last_farm_is_taken_its_whole_land_turns() -> void:
	SaveManager.save = _rich(["negotiation", "bribery", FarmRegister.WAR_CARD])
	WorldRegister.annex(SaveManager.save, WorldRegister.HOME)
	SaveManager.save.farms_owned.append("ostrevia-1")
	var sheet := _register(&"ostrevia")
	assert_float(_reach(sheet)["ostrevia-1"]).is_equal(1.0)
	assert_bool(WarSheet.win(SaveManager.save, &"ostrevia-2")).is_true()
	sheet.expect(&"ostrevia-2")
	sheet.celebrate(&"ostrevia-2")
	assert_bool((sheet.get_node("Flash/SpreadLong") as SoundCue).playing).is_true()
	sheet._spread_tween.custom_step(FarmRegister.PARCEL_TIME)
	assert_float(_reach(sheet)["ostrevia-2"]).is_less(1.0)  # The last farm spreads longer.
	sheet._spread_tween.custom_step(10.0)
	for site: String in ["ostrevia-1", "ostrevia-2"]:  # Every parcel shows: all of the land.
		assert_float(_reach(sheet)[site]).is_equal(1.0)


func test_start_haggling_lays_the_negotiation_record_over_the_deed_and_back_to_the_deed_takes_it_away() -> void:
	SaveManager.save = _haggling()
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	sheet.press(&"K-2")
	assert_bool(deed.haggling).is_false()
	assert_str(_form(sheet, "Start/Word").text).is_equal("START HAGGLING")
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.SEND))).is_not_equal(FarmRegister.SEND)  # The letter is not out yet.
	assert_str(sheet.spot_at(_spot(sheet, FarmRegister.HAGGLE))).is_equal(FarmRegister.HAGGLE)
	sheet.press(FarmRegister.HAGGLE)
	assert_bool(deed.haggling).is_true()
	assert_bool((deed.get_node("Haggle") as Node3D).visible).is_true()
	assert_str(sheet.deed_site()).is_equal(&"K-2")
	assert_str(sheet.spot_at(_box(sheet))).is_not_equal(FarmRegister.STAMP)  # The letter covers the stamp box.
	_lay_bundles(sheet, 1)
	sheet.press(FarmRegister.SEND)
	_play_out(sheet)
	assert_int(FarmRegister.offers(SaveManager.save, &"K-2").size()).is_equal(1)
	assert_bool(deed.haggling).is_true()  # It stays out for the next offer.
	sheet.press(FarmRegister.RETURN)
	assert_bool(deed.haggling).is_false()
	assert_str(_form(sheet, "Start/Word").text).is_equal("RESUME HAGGLING")
	assert_str(sheet.spot_at(_box(sheet))).is_equal(FarmRegister.STAMP)
	sheet.press(FarmRegister.HAGGLE)
	sheet.press(&"")  # A click on nothing puts both papers away.
	assert_str(sheet.deed_site()).is_equal(&"")
	sheet.press(&"K-2")
	assert_bool(deed.haggling).is_false()  # The deed comes back alone.


func test_every_box_on_the_deed_and_the_record_takes_a_click_right_into_its_corners_through_the_tilted_camera() -> void:
	# The papers lie over the sheet (DEED_LIFT) and the camera looks down at an angle: a click is
	# on the paper's pixel the mouse is over, not on the sheet's pixel under it.
	SaveManager.save = _haggling()
	var sheet := _register()
	var deed := sheet.get_node("Deed") as FarmDeed
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	var middle := sheet.point_at(Vector2(1600, 900))
	camera.look_at_from_position(middle + Vector3(0.0, 2.2, 1.6), middle)
	camera.make_current()
	for site: StringName in [&"K-2", &"K-8"]:  # A deed on either side of the camera.
		sheet.press(site)
		deed._moving.custom_step(10.0)
		for haggling: bool in [false, true]:
			if haggling:
				sheet.press(FarmRegister.HAGGLE)
				deed._haggle_moving.custom_step(10.0)
			var boxes: Dictionary = FarmDeed.HAGGLE_BOXES if haggling else FarmDeed.DEED_BOXES
			var paper := (deed.get_node("Haggle") if haggling else deed) as Node3D
			for spot: StringName in boxes:
				var inner := (boxes[spot] as Rect2).grow(-3.0)
				for at: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end, inner.get_center()]:
					var local := Vector3(at.x, 0.0, at.y) / FarmDeed.PIXELS_PER_METRE
					if not haggling:
						local.x -= FarmDeed.SIZE.x / 2.0  # The deed's origin is the middle of its top edge.
					var screen := camera.unproject_position(paper.global_transform * local)
					var hit: Variant = Plane(Vector3.UP, sheet.global_position.y).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
					assert_str(sheet.spot_at(sheet.pixel_at(hit))).override_failure_message("%s %s at %s" % [site, spot, at]).is_equal(spot)
		sheet.press(&"")
