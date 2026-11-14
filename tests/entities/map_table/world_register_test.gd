extends GdUnitTestSuite

const Events := preload("res://globalScripts/game_events.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")
const CONTINENT := [&"ostrevia", &"veldmark", &"sulvania"]
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


## A save at the world sheet: the war and world map cards stamped, five home farms, a full purse.
func _rich() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation", "negotiation", "bribery", "war_mode", "world_map"])
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


func _labels() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json"))


## The world as the map draws it (tools/make_maps.py), by country id.
func _drawn() -> Dictionary:
	var world: Dictionary = _labels().world_map
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


## Every war's price in the order a player meets them: nearest country first, its farms in turn.
func _ladder() -> Array:
	var by_rank := WorldRegister.COUNTRIES.keys()
	by_rank.sort_custom(func(a: StringName, b: StringName) -> bool: return WorldRegister.COUNTRIES[a].rank < WorldRegister.COUNTRIES[b].rank)
	var out := []
	for country: StringName in by_rank:
		for bill: Dictionary in WorldRegister.COUNTRIES[country].wars:
			out.append([country, bill])
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
			assert_str(WorldRegister.country_of(id)).is_equal(country)
	assert_int(ids.size()).is_equal(Events.FARMS)
	assert_array(Array(WorldRegister.farm_ids(&"kohlmark"))).is_equal(["K-1", "K-2", "K-3", "K-4", "K-5", "K-6", "K-7", "K-8"])
	assert_array(Array(WorldRegister.farm_ids(&"lower_provinces"))).is_equal(["lower_provinces-1", "lower_provinces-2"])
	assert_str(WorldRegister.country_of("lower_provinces-2")).is_equal(&"lower_provinces")


func test_every_farm_that_is_not_bought_has_one_war_price() -> void:
	for country: StringName in WorldRegister.COUNTRIES:
		var entry: Dictionary = WorldRegister.COUNTRIES[country]
		var bought := Events.HOME_SELLERS if country == WorldRegister.HOME else 0
		assert_int(entry.wars.size()).override_failure_message(country).is_equal(entry.farms - bought)


## Starting a war costs coins only: its cabbages go into the soldiers (WarRules.UNIT_PRICE).
func test_starting_a_war_costs_coins_only() -> void:
	for pair: Array in _ladder():
		assert_array(pair[1].keys()).override_failure_message(str(pair)).is_equal(["coins"])


func test_every_war_costs_more_than_the_one_before_it_nearest_country_first() -> void:
	var ladder := _ladder()
	assert_str(ladder[0][0]).is_equal("kohlmark")
	assert_str(ladder[-1][0]).is_equal("endmark")
	for i in range(1, ladder.size()):
		assert_int(ladder[i][1].coins).override_failure_message("%s, war %d" % [ladder[i][0], i]).is_greater(ladder[i - 1][1].coins)


func test_the_next_war_in_a_country_costs_by_how_many_of_its_farms_are_ours_whichever_is_next() -> void:
	var save := _rich()
	_own(save, [WorldRegister.HOME])
	var wars: Array = WorldRegister.COUNTRIES[&"sulvania"].wars
	assert_dict(WorldRegister.war_price(save, &"sulvania")).is_equal(wars[0])
	save.farms_owned.append("sulvania-3")
	assert_dict(WorldRegister.war_price(save, &"sulvania")).is_equal(wars[1])
	save.farms_owned.append("sulvania-1")
	assert_dict(WorldRegister.war_price(save, &"sulvania")).is_equal(wars[2])
	save.farms_owned.append("sulvania-2")
	assert_dict(WorldRegister.war_price(save, &"sulvania")).is_empty()  # All ours.
	assert_dict(WorldRegister.war_price(_rich(), WorldRegister.HOME)).is_equal(WorldRegister.COUNTRIES[WorldRegister.HOME].wars[0])
	var four := _rich()
	four.farms_owned.resize(4)
	assert_dict(WorldRegister.war_price(four, WorldRegister.HOME)).is_empty()  # Still bought at home.


func test_a_farm_abroad_can_be_attacked_only_next_to_a_country_that_is_wholly_ours() -> void:
	var save := _rich()  # Five of Kohlmark's eight: not wholly ours.
	for country: StringName in CONTINENT + OVERSEAS:
		assert_str(WorldRegister.reach(save, country)).override_failure_message(country).is_equal(WorldRegister.NOT_ADJACENT)
	assert_str(WorldRegister.reach(save, WorldRegister.HOME)).is_equal("")  # At home always.
	_own(save, [WorldRegister.HOME])
	for country: StringName in CONTINENT:
		assert_str(WorldRegister.reach(save, country)).override_failure_message(country).is_equal("")
	save.stamped.append("sea_lanes")  # Even with the sea open: nothing of ours touches them.
	for country: StringName in [&"morrow", &"nordhal", &"endmark"]:
		assert_str(WorldRegister.reach(save, country)).override_failure_message(country).is_equal(WorldRegister.NOT_ADJACENT)
	# A war out of reach costs nothing and cannot be won.
	var coins := save.coins
	assert_dict(FarmRegister.war_bill(save, &"morrow-1")).is_empty()
	assert_int(save.coins).is_equal(coins)


func test_the_sea_is_crossed_only_with_sea_lanes() -> void:
	var save := _rich()
	_own(save, [WorldRegister.HOME, &"sulvania"])
	for country: StringName in [&"grauland", &"lower_provinces"]:
		assert_str(WorldRegister.reach(save, country)).override_failure_message(country).is_equal(WorldRegister.NO_SEA_LANES)
		assert_dict(FarmRegister.war_bill(save, StringName(String(country) + "-1"))).is_empty()
	save.stamped.append(WorldRegister.SEA_CARD)
	assert_str(WorldRegister.reach(save, &"grauland")).is_equal("")
	assert_dict(FarmRegister.war_bill(save, &"grauland-1")).is_equal(WorldRegister.COUNTRIES[&"grauland"].wars[0])
	# From Grauland on by land: Morrow borders it, without the card.
	save.stamped.remove_at(save.stamped.find(WorldRegister.SEA_CARD))
	_own(save, [&"grauland"])
	assert_str(WorldRegister.reach(save, &"morrow")).is_equal("")
	assert_str(WorldRegister.reach(save, &"lower_provinces")).is_equal(WorldRegister.NO_SEA_LANES)


func test_endmark_isle_can_be_attacked_once_all_of_nordhal_is_ours() -> void:
	var save := _rich()
	save.stamped.append(WorldRegister.SEA_CARD)
	_own(save, [WorldRegister.HOME, &"ostrevia", &"veldmark", &"sulvania", &"grauland", &"lower_provinces", &"morrow"])
	save.farms_owned.append("nordhal-1")
	assert_str(WorldRegister.reach(save, &"endmark")).is_equal(WorldRegister.NOT_ADJACENT)
	save.farms_owned.append("nordhal-2")
	assert_str(WorldRegister.reach(save, &"endmark")).is_equal("")
	assert_dict(FarmRegister.war_bill(save, &"endmark-1")).is_equal(WorldRegister.COUNTRIES[&"endmark"].wars[0])


func test_every_drawn_sea_lane_needs_the_sea_lanes_card() -> void:
	var lanes: Array = _labels().world_map.sea_lanes
	assert_int(lanes.size()).is_equal(4)
	for lane: Dictionary in lanes:
		assert_array(WorldRegister.COUNTRIES[StringName(lane.a)].sea).override_failure_message(lane.id).contains([StringName(lane.b)])
		assert_array(WorldRegister.COUNTRIES[StringName(lane.b)].sea).override_failure_message(lane.id).contains([StringName(lane.a)])
	assert_str(UpgradeDesk.card_data(WorldRegister.SEA_CARD).title).is_equal("SEA LANES")


func test_the_debug_key_gives_the_farms_abroad_nearest_country_first_after_the_home_sites() -> void:
	var save := _rich()
	assert_str(WorldRegister.next_farm(save)).is_equal("K-6")
	save.farms_owned.append_array(["K-6", "K-7", "K-8"])
	var nearest: StringName = _ladder()[Events.HOME_SITES - Events.HOME_SELLERS][0]
	assert_str(WorldRegister.next_farm(save)).is_equal(String(nearest) + "-1")
	_own(save, WorldRegister.COUNTRIES.keys())
	assert_str(WorldRegister.next_farm(save)).is_equal("")
	assert_int(save.farms_owned.size()).is_equal(Events.FARMS)


func test_the_world_sheet_shows_no_price_for_a_country() -> void:
	var save := _rich()
	for country: StringName in WorldRegister.COUNTRIES:
		var text := WorldRegister.hint_text(save, country, "X")
		assert_bool(text.contains("$")).override_failure_message(text).is_false()
		assert_str(text).is_equal("X. Farms: %d of %d. Click for its farm register." % [WorldRegister.farms_of(save, country), WorldRegister.COUNTRIES[country].farms])
	var sheet := _sheet()
	assert_str(sheet.hint(&"ostrevia")).is_equal(WorldRegister.hint_text(SaveManager.save, &"ostrevia", "Ostrevia"))
	for label: Label in sheet.get_node("Page/Sheet").find_children("*", "Label", true, false):
		assert_bool(label.text.contains("$")).override_failure_message(label.text).is_false()


func test_hovering_a_country_only_shows_its_outline_and_lifts_its_token_whether_or_not_it_can_be_attacked() -> void:
	var sheet := _sheet()
	for country: StringName in [&"ostrevia", &"endmark", &"kohlmark"]:
		sheet.hover(country)
		assert_bool(sheet._outline(country).visible).override_failure_message(country).is_true()
		sheet._moving[country].custom_step(1.0)
		assert_float(sheet._raised(country)).is_equal_approx(FarmRegister.HOVER_SCALE, 0.001)
	assert_bool(sheet._outline(&"ostrevia").visible).is_false()  # Only the one under the mouse.
	sheet.hover(&"")
	assert_bool(sheet._outline(&"kohlmark").visible).is_false()
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)


func test_clicking_a_country_on_the_world_sheet_opens_that_countrys_sheet() -> void:
	var sheet := _sheet()
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	for country: StringName in [&"sulvania", &"endmark"]:  # Any country can be opened and looked at.
		sheet.press(country)
	sheet.press(&"")  # The sea: nothing.
	assert_array(wanted).is_equal([[&"sulvania", &""], [&"endmark", &""]])
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)
	assert_int(SaveManager.save.coins).is_equal(1000000000)


func test_every_country_has_its_token_outline_overlay_count_tag_and_own_sheet() -> void:
	var sheet := _sheet()
	var drawn := _drawn()
	for country: StringName in WorldRegister.COUNTRIES:
		assert_bool(sheet._sites.has(country)).override_failure_message(country).is_true()
		assert_float(sheet._pixel(country).distance_to(drawn[String(country)].point)).is_less(1.0)
		assert_int(sheet._outline(country).points.size()).is_equal(drawn[String(country)].outline[0].size())
		assert_object(sheet._layer(country)).is_not_null()
		assert_str(sheet._tag(country).text).is_equal(WorldRegister.tag_text(SaveManager.save, country))
		assert_bool(ResourceLoader.exists(WorldRegister.OWNED_ART % country)).is_true()
		assert_bool(ResourceLoader.exists(MapTable.COUNTRY_SCENE % country)).override_failure_message(country).is_true()
		# The click outline holds the holding point: a click on the token is a click on the country.
		assert_str(sheet.spot_at(sheet._pixel(country))).is_equal(country)


func test_every_country_looks_the_same_on_the_world_sheet_and_on_its_own_sheet() -> void:
	# A country's own sheet is its piece of the world sheet, scaled up the same both ways, north up:
	# its outline lies on its own sheet, and its farm sites and capital lie in its outline on the world.
	var drawn := _drawn()
	var maps: Dictionary = _labels().country_maps
	var paper := Rect2(Vector2.ZERO, MapSheet.SIZE * MapSheet.PIXELS_PER_METRE)
	for country: StringName in WorldRegister.COUNTRIES:
		var own: Dictionary = maps[String(country)]
		var origin := Vector2(own.world_origin[0], own.world_origin[1])
		var scale: float = own.scale
		var outline := PackedVector2Array()
		for point: Array in drawn[String(country)].outline[0]:
			outline.append(Vector2(point[0], point[1]))
			assert_bool(paper.grow(1.0).has_point((Vector2(point[0], point[1]) - origin) * scale)).override_failure_message(country).is_true()
		for spot: Dictionary in own.farm_sites + [own.capital]:
			var on_world := Vector2(spot.x, spot.y) / scale + origin
			assert_bool(Geometry2D.is_point_in_polygon(on_world, outline)).override_failure_message("%s: %s" % [country, spot]).is_true()


func test_every_country_fills_at_least_a_third_of_its_own_sheet() -> void:
	var maps: Dictionary = _labels().country_maps
	for country: StringName in WorldRegister.COUNTRIES:
		assert_float(float(maps[String(country)].coverage)).override_failure_message(country).is_greater_equal(1.0 / 3.0)


func test_the_hint_slip_keeps_clear_of_a_countrys_token_its_count_and_its_name() -> void:
	var sheet := _sheet()
	for country: StringName in WorldRegister.COUNTRIES:
		var box := sheet.spot_box(country)  # What the slip lies beside, never over.
		assert_bool(box.has_point(sheet._pixel(country))).override_failure_message(country).is_true()
		assert_bool(box.encloses(MapSheet.lettering(sheet._tag(country)))).override_failure_message(country).is_true()
		var named := sheet.get_node("Page/Sheet").get_children().filter(
				func(label: Node) -> bool: return label is Label and label.text == sheet._sites[country].title)
		assert_int(named.size()).override_failure_message(country).is_greater_equal(1)
		for label: Label in named:
			assert_bool(box.encloses(MapSheet.lettering(label))).override_failure_message(country).is_true()


func _patchy(sheet: WorldRegister, country: StringName) -> bool:
	return (sheet._layer(country).material as ShaderMaterial).get_shader_parameter("patchy")


func test_at_first_only_the_home_country_shows_patches_of_cabbage_and_its_art_is_the_only_one_loaded() -> void:
	var sheet := _sheet()  # Five of Kohlmark's eight, nothing abroad.
	for country: StringName in WorldRegister.COUNTRIES:
		var home := country == WorldRegister.HOME
		assert_bool(sheet._layer(country).visible).override_failure_message(country).is_equal(home)
		assert_bool(sheet._layer(country).texture != null).override_failure_message(country).is_equal(home)
		assert_bool(sheet._sites[country].owned).override_failure_message(country).is_false()
	assert_bool(_patchy(sheet, WorldRegister.HOME)).is_true()


func test_a_country_shows_one_of_three_looks_none_some_or_all_of_its_farms_never_a_percentage() -> void:
	var save := _rich()
	assert_int(WorldRegister.share(save, &"sulvania")).is_equal(WorldRegister.Share.NONE)
	save.farms_owned.append("sulvania-2")
	assert_int(WorldRegister.share(save, &"sulvania")).is_equal(WorldRegister.Share.SOME)
	save.farms_owned.append("sulvania-1")  # Two of three: still the same look as one of three.
	assert_int(WorldRegister.share(save, &"sulvania")).is_equal(WorldRegister.Share.SOME)
	save.farms_owned.append("sulvania-3")
	assert_int(WorldRegister.share(save, &"sulvania")).is_equal(WorldRegister.Share.ALL)
	assert_int(WorldRegister.share(save, WorldRegister.HOME)).is_equal(WorldRegister.Share.SOME)  # Five of eight.
	_own(save, [WorldRegister.HOME])
	assert_int(WorldRegister.share(save, WorldRegister.HOME)).is_equal(WorldRegister.Share.ALL)


func test_a_country_shows_fully_green_only_when_every_farm_is_ours() -> void:
	var sheet := _sheet()
	var layer := sheet._layer(&"veldmark")
	assert_bool(layer.visible).is_false()  # None ours: plain.
	SaveManager.save.farms_owned.append("veldmark-1")
	sheet._process(0.0)
	assert_bool(layer.visible).is_true()  # One of two: patches.
	assert_object(layer.texture).is_not_null()
	assert_bool(_patchy(sheet, &"veldmark")).is_true()
	assert_bool(sheet._sites[&"veldmark"].owned).is_false()
	assert_str(sheet._tag(&"veldmark").text).is_equal("1/2")
	SaveManager.save.farms_owned.append("veldmark-2")
	sheet._process(0.0)
	assert_bool(layer.visible).is_true()  # Both: wholly green.
	assert_bool(_patchy(sheet, &"veldmark")).is_false()
	assert_float((layer.material as ShaderMaterial).get_shader_parameter("reach")).is_equal(WorldRegister.FULL)
	assert_bool(sheet._sites[&"veldmark"].owned).is_true()
	assert_str(sheet._tag(&"veldmark").text).is_equal("2/2")
	var loaded := _sheet()  # And after a reload.
	assert_bool(loaded._layer(&"veldmark").visible).is_true()
	assert_bool(_patchy(loaded, &"veldmark")).is_false()
	assert_bool(loaded._sites[&"veldmark"].owned).is_true()


func test_every_line_of_the_war_orders_is_in_the_translation_table() -> void:
	var table := FileAccess.get_file_as_string("res://ressources/translations/game.csv")
	var keys: Array = [WorldRegister.NOT_ADJACENT, WorldRegister.NO_SEA_LANES, "SEA LANES", "%s. Farms: %d of %d. Click for its farm register."]
	keys.append_array(WorldRegister.REASONS.values())
	for form: Dictionary in FarmDeed.FORMS.values():
		keys.append_array(form.values())
	for key: String in keys:
		var quoted := '"%s"' % key if key.contains(",") else key
		assert_bool(table.contains("\n%s,%s," % [quoted, quoted])).override_failure_message(key).is_true()
