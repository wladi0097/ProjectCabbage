extends GdUnitTestSuite

const Events := preload("res://globalScripts/game_events.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")
const CONTINENT := [&"kohlmark", &"ostrevia", &"veldmark", &"sulvania"]
const OVERSEAS := [&"grauland", &"lower_provinces", &"morrow", &"nordhal", &"endmark"]

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


## A save at the world sheet that can pay for any country: the world map card stamped, five home farms.
func _rich() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation", "negotiation", "bribery", "world_map"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	save.coins = 1000000000
	save.storage_cap = 100000
	save.stock = 100000
	return save


func _own(save: SaveGame, countries: Array) -> void:
	for country: StringName in countries:
		WorldRegister.annex(save, country)


func _sheet() -> WorldRegister:
	var sheet: WorldRegister = auto_free(load("res://entities/map_table/world_sheet.tscn").instantiate())
	add_child(sheet)
	sheet.open = 1.0  # Lying open on the table.
	for i in sheet.thing_count():
		sheet.raise_thing(1.0, i)
	return sheet


## The world as the map draws it (tools/make_maps.py), by country id.
func _drawn() -> Dictionary:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).world_map
	var out := {}
	for country: Dictionary in world.countries:
		out[country.id] = country
	for holding: Dictionary in world.farm_sites:
		out[holding.id].farms = holding.farms
		out[holding.id].point = Vector2(holding.x, holding.y)
	return out


func _names(ids: Array) -> Array:
	var out := ids.map(func(id: Variant) -> String: return String(id))
	out.sort()
	return out


func test_the_rules_know_the_world_as_the_map_draws_it() -> void:
	var drawn := _drawn()
	assert_array(_names(WorldRegister.COUNTRIES.keys())).is_equal(_names(drawn.keys()))
	for id: String in drawn:
		var rules: Dictionary = WorldRegister.COUNTRIES[StringName(id)]
		assert_int(rules.farms).override_failure_message(id).is_equal(int(drawn[id].farms))
		assert_int(rules.rank).override_failure_message(id).is_equal(int(drawn[id].distance_rank))
		assert_array(_names(rules.sea)).override_failure_message(id).is_equal(_names(drawn[id].sea_links))
		assert_array(_names(rules.land + rules.sea)).override_failure_message(id).is_equal(_names(drawn[id].adjacent))


func test_the_countries_hold_every_farm_of_the_game_and_no_farm_twice() -> void:
	var ids := {}
	for country: StringName in WorldRegister.COUNTRIES:
		for id in WorldRegister.farm_ids(country):
			ids[id] = true
	assert_int(ids.size()).is_equal(Events.FARMS)
	assert_array(Array(WorldRegister.farm_ids(&"kohlmark"))).is_equal(["K-1", "K-2", "K-3", "K-4", "K-5", "K-6", "K-7", "K-8"])
	assert_array(Array(WorldRegister.farm_ids(&"sulvania"))).is_equal(["sulvania-1", "sulvania-2", "sulvania-3"])


func test_the_home_country_is_ours_from_the_start_however_few_of_its_farms_are_owned() -> void:
	var save := SaveGame.new()
	assert_bool(WorldRegister.owns(save, &"kohlmark")).is_true()
	assert_bool(WorldRegister.owns(save, &"ostrevia")).is_false()
	assert_str(WorldRegister.tag_text(_rich(), &"kohlmark")).is_equal("5/8")


func test_only_a_country_next_to_an_owned_one_can_be_taken() -> void:
	var save := _rich()
	for country: StringName in [&"ostrevia", &"veldmark", &"sulvania"]:
		assert_bool(WorldRegister.takeable(save, country)).override_failure_message(country).is_true()
	for country: StringName in OVERSEAS:
		assert_bool(WorldRegister.takeable(save, country)).override_failure_message(country).is_false()
	save.stamped.append("sea_lanes")  # Even with the sea open: nothing of ours touches them.
	assert_str(WorldRegister.reach(save, &"morrow")).is_equal(WorldRegister.NOT_ADJACENT)
	var coins := save.coins
	assert_bool(WorldRegister.take(save, &"morrow")).is_false()
	assert_int(save.coins).is_equal(coins)
	assert_int(save.farms_owned.size()).is_equal(5)


func test_a_nearer_country_costs_less_than_a_farther_one() -> void:
	var by_rank := WorldRegister.COUNTRIES.keys()
	by_rank.sort_custom(func(a: StringName, b: StringName) -> bool: return WorldRegister.COUNTRIES[a].rank < WorldRegister.COUNTRIES[b].rank)
	assert_str(by_rank[0]).is_equal("kohlmark")
	assert_str(by_rank[-1]).is_equal("endmark")
	for i in range(2, by_rank.size()):
		var near := WorldRegister.price(by_rank[i - 1])
		var far := WorldRegister.price(by_rank[i])
		assert_int(far.coins).override_failure_message(by_rank[i]).is_greater(near.coins)
		assert_int(far.stock).override_failure_message(by_rank[i]).is_greater(near.stock)
	# And none costs less than the last home farm was seized for.
	assert_int(WorldRegister.price(by_rank[1]).coins).is_greater(FarmRegister.SEIZURES[-1].coins)


func test_the_sea_cannot_be_crossed_before_sea_lanes() -> void:
	var save := _rich()
	_own(save, [&"ostrevia", &"veldmark", &"sulvania"])
	for country: StringName in [&"grauland", &"lower_provinces"]:
		assert_str(WorldRegister.reach(save, country)).override_failure_message(country).is_equal(WorldRegister.NO_SEA_LANES)
		assert_bool(WorldRegister.take(save, country)).is_false()
	save.stamped.append("sea_lanes")
	assert_bool(WorldRegister.take(save, &"grauland")).is_true()
	# From there on by land: Morrow borders Grauland.
	save.stamped.remove_at(save.stamped.find("sea_lanes"))
	assert_bool(WorldRegister.takeable(save, &"morrow")).is_true()
	assert_str(WorldRegister.reach(save, &"lower_provinces")).is_equal(WorldRegister.NO_SEA_LANES)


func test_every_drawn_sea_lane_needs_the_sea_lanes_card() -> void:
	var lanes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json")).world_map.sea_lanes
	assert_int(lanes.size()).is_equal(4)
	for lane: Dictionary in lanes:
		assert_array(WorldRegister.COUNTRIES[StringName(lane.a)].sea).override_failure_message(lane.id).contains([StringName(lane.b)])
		assert_array(WorldRegister.COUNTRIES[StringName(lane.b)].sea).override_failure_message(lane.id).contains([StringName(lane.a)])
	assert_str(UpgradeDesk.card_data(WorldRegister.SEA_CARD).title).is_equal("SEA LANES")


func test_taking_a_country_brings_all_its_farms() -> void:
	var save := _rich()
	var bill := WorldRegister.price(&"sulvania")
	var coins := save.coins
	var stock := save.stock
	assert_bool(WorldRegister.take(save, &"sulvania")).is_true()
	assert_array(Array(save.farms_owned).slice(5)).is_equal(["sulvania-1", "sulvania-2", "sulvania-3"])
	assert_int(save.coins).is_equal(coins - bill.coins)
	assert_int(save.stock).is_equal(stock - bill.stock)
	assert_bool(WorldRegister.owns(save, &"sulvania")).is_true()
	assert_str(WorldRegister.tag_text(save, &"sulvania")).is_equal("3/3")
	# Farms abroad are no home farms: the country notice and the first law still wait for Kohlmark's.
	assert_int(Events.home_farms(save)).is_equal(5)
	assert_bool(Events.due("home_country", save)).is_false()
	assert_bool(WorldRegister.take(save, &"sulvania")).is_false()  # Only once.
	assert_int(save.farms_owned.size()).is_equal(8)


func test_a_country_that_cannot_be_paid_for_is_not_taken_and_costs_nothing() -> void:
	var save := _rich()
	save.coins = WorldRegister.price(&"ostrevia").coins - 1
	assert_bool(WorldRegister.take(save, &"ostrevia")).is_false()
	assert_dict(WorldRegister.short(save, &"ostrevia")).is_equal({coins = 1})
	save.coins += 1
	save.stock = WorldRegister.price(&"ostrevia").stock + 3
	assert_bool(WorldRegister.take(save, &"ostrevia", Vector2i(4, 0))).is_false()  # 4 of them lie on the mat.
	assert_int(save.farms_owned.size()).is_equal(5)
	assert_bool(WorldRegister.take(save, &"ostrevia", Vector2i(3, 0))).is_true()


func test_the_final_island_falls_only_after_nordhal() -> void:
	var save := _rich()
	save.stamped.append("sea_lanes")
	_own(save, [&"ostrevia", &"veldmark", &"sulvania", &"grauland"])
	assert_str(WorldRegister.reach(save, &"endmark")).is_equal(WorldRegister.NOT_ADJACENT)
	_own(save, [&"nordhal"])
	# Nordhal is ours, two countries are not: the island is taken last of all.
	assert_str(WorldRegister.reach(save, &"endmark")).is_equal(WorldRegister.NOT_YET)
	assert_bool(WorldRegister.take(save, &"endmark")).is_false()
	_own(save, [&"morrow", &"lower_provinces"])
	assert_bool(WorldRegister.take(save, &"endmark")).is_true()
	assert_int(save.farms_owned.size()).is_equal(Events.FARMS - 3)  # All but the three home farms not seized.


func test_the_final_island_needs_the_sea_lanes_too() -> void:
	var save := _rich()
	_own(save, [&"ostrevia", &"veldmark", &"sulvania", &"grauland", &"lower_provinces", &"morrow", &"nordhal"])
	assert_str(WorldRegister.reach(save, &"endmark")).is_equal(WorldRegister.NO_SEA_LANES)


func test_a_countrys_cabbages_fit_the_biggest_store_with_a_full_mat_of_condensed_cabbages_out() -> void:
	var biggest := SaveGame.new().storage_cap
	var condensed := 2  # The card CONDENSE CABBAGES.
	for node: Dictionary in Projector.NODES:
		biggest += int(node.get("add", {}).get("storage_cap", 0))
		condensed += int(node.get("add", {}).get("condense", 0))
	for country: StringName in WorldRegister.COUNTRIES:
		assert_int(WorldRegister.price(country).stock + Projector.MAT_MAX * condensed).override_failure_message(country).is_less_equal(biggest)
	for bill in FarmRegister.SEIZURES:
		assert_int(bill.stock + Projector.MAT_MAX * condensed).is_less_equal(biggest)


func test_the_debug_key_gives_the_farms_abroad_nearest_country_first_after_the_home_sites() -> void:
	var save := _rich()
	assert_str(WorldRegister.next_farm(save)).is_equal("K-6")
	save.farms_owned.append_array(["K-6", "K-7", "K-8"])
	assert_str(WorldRegister.next_farm(save)).is_equal("ostrevia-1")
	_own(save, [&"ostrevia"])
	assert_str(WorldRegister.next_farm(save)).is_equal("veldmark-1")
	_own(save, WorldRegister.COUNTRIES.keys())
	assert_str(WorldRegister.next_farm(save)).is_equal("")
	assert_int(save.farms_owned.size()).is_equal(Events.FARMS)


func test_the_hint_names_the_country_its_farms_its_cost_and_what_is_short_or_why_not() -> void:
	var save := _rich()
	assert_str(WorldRegister.hint_text(save, &"kohlmark", "Kohlmark")).is_equal("Kohlmark. Company property.")
	assert_str(WorldRegister.hint_text(save, &"ostrevia", "Ostrevia")).is_equal(
			"Ostrevia. Farms: 2. Cost: %s. Click for the order." % FarmRegister.words(WorldRegister.price(&"ostrevia")))
	save.coins = WorldRegister.price(&"ostrevia").coins - 500
	assert_str(WorldRegister.hint_text(save, &"ostrevia", "Ostrevia")).ends_with("Short: $500.")
	assert_str(WorldRegister.hint_text(save, &"grauland", "Grauland")).is_equal("Grauland. Farms: 2. We do not border this country. Yet.")
	_own(save, [&"sulvania"])
	assert_str(WorldRegister.hint_text(save, &"grauland", "Grauland")).is_equal("Grauland. Farms: 2. The sea is not ours to cross yet.")


func test_every_country_has_its_token_outline_overlay_and_count_tag_on_the_sheet() -> void:
	var sheet := _sheet()
	var drawn := _drawn()
	for country: StringName in WorldRegister.COUNTRIES:
		assert_bool(sheet._sites.has(country)).override_failure_message(country).is_true()
		assert_float(sheet._pixel(country).distance_to(drawn[String(country)].point)).is_less(1.0)
		assert_int(sheet._outline(country).points.size()).is_equal(drawn[String(country)].outline[0].size())
		assert_object(sheet._layer(country)).is_not_null()
		assert_str(sheet._tag(country).text).is_equal(WorldRegister.tag_text(SaveManager.save, country))
		assert_bool(ResourceLoader.exists(WorldRegister.OWNED_ART % country)).is_true()
		# The click outline holds the holding point: a click on the token is a click on the country.
		assert_str(sheet.spot_at(sheet._pixel(country))).is_equal(country)
	assert_str(sheet.spot_at(Vector2(1600, 60))).is_equal("")  # The sea.


func test_the_hint_slip_lies_in_the_sea_clear_of_every_country() -> void:
	var sheet := _sheet()
	# The slip at the map camera: 400 px wide and up to four lines, about 1.7 art pixels a screen pixel.
	var slip := Rect2(sheet.hint_pixel(), Vector2(760, 240))
	assert_bool(Rect2(Vector2.ZERO, MapSheet.SIZE * MapSheet.PIXELS_PER_METRE).encloses(slip)).is_true()
	for country: StringName in WorldRegister.COUNTRIES:
		for corner in sheet._outline(country).points:
			assert_bool(slip.has_point(corner)).override_failure_message(country).is_false()
		assert_bool(slip.has_point(sheet._pixel(country))).override_failure_message(country).is_false()


func test_only_the_home_country_wears_the_cabbage_pattern_at_first_and_its_art_is_the_only_one_loaded() -> void:
	var sheet := _sheet()
	for country: StringName in WorldRegister.COUNTRIES:
		var home := country == WorldRegister.HOME
		assert_bool(sheet._layer(country).visible).override_failure_message(country).is_equal(home)
		assert_bool(sheet._layer(country).texture != null).override_failure_message(country).is_equal(home)
		assert_bool(sheet._sites[country].owned).override_failure_message(country).is_equal(home)


func test_an_owned_country_shows_its_pattern_token_and_count_after_a_reload() -> void:
	_own(SaveManager.save, [&"veldmark"])
	var sheet := _sheet()
	var layer := sheet._layer(&"veldmark")
	assert_bool(layer.visible).is_true()
	assert_object(layer.texture).is_not_null()
	assert_float((layer.material as ShaderMaterial).get_shader_parameter("reach")).is_equal(WorldRegister.FULL)
	assert_bool(sheet._sites[&"veldmark"].owned).is_true()
	assert_str(sheet._tag(&"veldmark").text).is_equal("2/2")
	assert_bool(sheet._deed.visible).is_false()


func test_hovering_a_country_that_can_be_taken_shows_its_outline_and_lifts_its_token() -> void:
	var sheet := _sheet()
	sheet.hover(&"ostrevia")
	assert_bool(sheet._outline(&"ostrevia").visible).is_true()
	sheet._moving[&"ostrevia"].custom_step(1.0)
	assert_float(sheet._raised(&"ostrevia")).is_equal_approx(FarmRegister.HOVER_SCALE, 0.001)
	sheet.hover(&"grauland")  # Across the sea: named by the slip, not lit.
	assert_bool(sheet._outline(&"ostrevia").visible).is_false()
	assert_bool(sheet._outline(&"grauland").visible).is_false()
	assert_str(sheet.hint(&"grauland")).contains("We do not border")
	sheet.hover(&"kohlmark")  # Ours already.
	assert_bool(sheet._outline(&"kohlmark").visible).is_false()


func test_clicking_a_country_lays_out_its_annexation_order_and_takes_nothing() -> void:
	var sheet := _sheet()
	sheet.press(&"sulvania")
	assert_str(sheet.deed_site()).is_equal("sulvania")
	assert_bool(sheet._deed.visible).is_true()
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)
	assert_str((sheet._deed.get_node("Page/Form/FormLine") as Label).text).is_equal("FORM 7-A  ANNEXATION ORDER")
	assert_str((sheet._deed.get_node("Page/Form/Title") as Label).text).is_equal("Sulvania")
	assert_str((sheet._deed.get_node("Page/Form/Site") as Label).text).is_equal("FARMS x3")
	assert_str((sheet._deed.get_node("Page/Form/Coins") as Label).text).is_equal("$" + FarmScreen._thousands(WorldRegister.price(&"sulvania").coins))
	assert_bool((sheet._deed.get_node("Page/Form/Box") as Control).visible).is_true()
	assert_bool((sheet._deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_bool((sheet._deed.get_node("Page/Form/Offer") as Control).visible).is_false()  # Nobody is asked.
	assert_str(sheet.hint(&"ostrevia")).is_equal("")  # The order says it all.
	sheet.press(&"")  # A click elsewhere puts it away.
	assert_str(sheet.deed_site()).is_equal("")


func test_stamping_the_order_takes_the_country_and_its_pattern_spreads_from_its_holding_point() -> void:
	var sheet := _sheet()
	sheet.press(&"ostrevia")
	sheet.press(FarmRegister.STAMP)
	# Paid at the click; the land changes when the stamp has landed.
	assert_int(SaveManager.save.farms_owned.size()).is_equal(7)
	assert_bool(FarmRegister.lamp_held).is_true()
	assert_bool(sheet._sites[&"ostrevia"].owned).is_false()
	assert_bool(sheet._layer(&"ostrevia").visible).is_false()
	sheet.press(&"veldmark")  # No click is taken while it plays out.
	assert_str(sheet.deed_site()).is_equal("ostrevia")
	sheet._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + FarmRegister.HIT_PAUSE + 0.01)
	var layer := sheet._layer(&"ostrevia")
	var ink := layer.material as ShaderMaterial
	assert_bool(sheet._sites[&"ostrevia"].owned).is_true()
	assert_str(sheet._tag(&"ostrevia").text).is_equal("2/2")
	assert_bool(layer.visible).is_true()
	assert_object(layer.texture).is_not_null()
	assert_str((sheet._deed.get_node("Page/Form/Imprint/Word") as Label).text).is_equal("ANNEXED")
	assert_float(ink.get_shader_parameter("reach")).is_equal(0.0)
	assert_float((ink.get_shader_parameter("from") as Vector2).distance_to(sheet._pixel(&"ostrevia"))).is_less(0.5)
	sheet._spread_tween.custom_step(WorldRegister.SPREAD_TIME * 0.5)
	assert_float(ink.get_shader_parameter("reach")).is_between(1.0, sheet.span(&"ostrevia"))
	sheet._spread_tween.custom_step(WorldRegister.SPREAD_TIME)
	assert_float(ink.get_shader_parameter("reach")).is_equal(WorldRegister.FULL)
	sheet._dealing.custom_step(10.0)
	assert_bool(FarmRegister.lamp_held).is_false()  # The Field Line may light its two lamps.
	assert_str(sheet.deed_site()).is_equal("")
	assert_object(sheet._dealing).is_null()


func test_an_annexation_is_written_to_the_save_at_once_and_goes_into_the_playtest_log() -> void:
	var sheet := _sheet()
	sheet.press(&"ostrevia")
	SaveManager.save.last_played = 0  # SaveManager.write_save stamps the time (the file itself is not written in tests).
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.last_played).is_greater(0)
	var rows := SaveManager.save.playtest_log.map(func(row: Dictionary) -> Array: return [row.kind, row.id, row.price, row.currency])
	assert_array(rows).contains_exactly([["annexation", "ostrevia", 9000000, "coins"], ["annexation", "ostrevia", 12000, "stock"]])


func test_the_stamp_stays_up_when_the_country_cannot_be_paid_for() -> void:
	SaveManager.save.coins = 1000
	var sheet := _sheet()
	sheet.press(&"ostrevia")
	assert_str((sheet._deed.get_node("Page/Form/CoinsShort") as Label).text).contains("SHORT")
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)
	assert_object(sheet._dealing).is_null()
	assert_bool(sheet._deed.stamped).is_false()
	assert_str(sheet.deed_site()).is_equal("ostrevia")


func test_a_country_out_of_reach_gets_an_order_with_a_strip_and_no_stamp_box() -> void:
	var sheet := _sheet()
	sheet.press(&"nordhal")
	var deed := sheet._deed
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_true()
	assert_str((deed.get_node("Page/Form/Strip/Word") as Label).text).is_equal("NOT ADJACENT")
	assert_str((deed.get_node("Page/Form/Reason") as Label).text).is_equal("We do not border this country. Yet.")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	var box := sheet._deed_corner + FarmDeed.STAMP_BOX.get_center()
	assert_str(sheet.spot_at(box)).is_equal("")  # Nothing to stamp.
	sheet.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)


func test_a_country_across_the_water_says_the_sea_is_not_ours_until_sea_lanes_is_stamped() -> void:
	_own(SaveManager.save, [&"sulvania"])
	var sheet := _sheet()
	sheet.press(&"grauland")
	var deed := sheet._deed
	assert_str((deed.get_node("Page/Form/Strip/Word") as Label).text).is_equal("NO SEA LANES")
	assert_str((deed.get_node("Page/Form/Reason") as Label).text).is_equal("The sea is not ours to cross yet.")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	# The card is stamped while the order lies there: it is printed again, with its price and stamp box.
	SaveManager.save.stamped.append("sea_lanes")
	sheet._process(0.0)
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_true()
	assert_str(sheet.spot_at(sheet._deed_corner + FarmDeed.STAMP_BOX.get_center())).is_equal(FarmRegister.STAMP)


func test_every_line_of_the_orders_is_in_the_translation_table() -> void:
	var table := FileAccess.get_file_as_string("res://ressources/translations/game.csv")
	var keys: Array = [WorldRegister.NOT_ADJACENT, WorldRegister.NO_SEA_LANES, WorldRegister.NOT_YET, "FARMS x%d", "SEA LANES"]
	keys.append_array(WorldRegister.REASONS.values())
	for form: Dictionary in FarmDeed.FORMS.values():
		keys.append_array(form.values())
	for key: String in keys:
		var quoted := '"%s"' % key if key.contains(",") else key
		assert_bool(table.contains("\n%s,%s," % [quoted, quoted])).override_failure_message(key).is_true()
