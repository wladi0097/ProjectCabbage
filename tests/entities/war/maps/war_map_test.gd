extends GdUnitTestSuite
## The campaign's map order and what it decides: sheet numbers, debuts, the final war.

const World := preload("res://entities/map_table/world_register.gd")
const WarSheet := preload("res://entities/map_table/war_sheet.gd")


func test_the_campaign_is_nineteen_wars_from_k6_to_endmark_isle_in_country_order() -> void:
	var maps := WarMap.campaign()
	assert_int(maps.size()).is_equal(19)
	assert_array(Array(maps.slice(0, 4))).is_equal(["K-6", "K-7", "K-8", "veldmark-1"])
	assert_str(maps[-1]).is_equal("endmark-1")


func test_each_map_has_its_sheet_number_in_the_campaign() -> void:
	assert_int(WarMap.sheet_number("K-6")).is_equal(1)
	assert_int(WarMap.sheet_number("K-7")).is_equal(2)
	assert_int(WarMap.sheet_number("veldmark-2")).is_equal(5)
	assert_int(WarMap.sheet_number("grauland-1")).is_equal(11)
	assert_int(WarMap.sheet_number("endmark-1")).is_equal(19)
	assert_int(WarMap.sheet_number("K-2")).is_equal(0)  # Bought, never fought.


func test_only_endmark_isle_is_the_final_war() -> void:
	for id in WarMap.campaign():
		assert_bool(WarMap.is_final(id)).override_failure_message(id).is_equal(id == "endmark-1")


func test_a_building_type_debuts_only_on_its_first_map_in_the_campaign() -> void:
	assert_array(WarMap.debuts("K-6")).is_empty()  # Picket and the farmhouse are the first war itself.
	assert_array(WarMap.debuts("K-7")).is_equal(["cannon"])
	var seen := {}
	for id in WarMap.campaign():
		var here := WarMap.kinds_in(WarMap.path_of(id))
		for kind: String in WarMap.debuts(id):
			assert_bool(seen.has(kind)).override_failure_message("%s debuts twice, again on %s" % [kind, id]).is_false()
			assert_bool(here.has(kind)).is_true()
		for kind: String in WarMap.DEBUT_KINDS:
			if here.has(kind):
				seen[kind] = true


func test_the_tutorial_maps_carry_their_site_names_and_briefings() -> void:
	var save := SaveGame.new()
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	assert_dict(WarMap.brief_for(&"K-6", save)).is_equal({site_name = "THE HOLDOUT",
			briefing = "One farmhouse. One fence. No further questions.", final = false})
	save.farms_owned.append("K-6")
	assert_str(WarMap.brief_for(&"K-8", save).site_name).is_equal("THE SUPERVISED PLOT")  # The second war is K-7's map.


func test_every_site_name_and_briefing_is_german_in_german() -> void:
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	for path in WarMap.map_paths():
		var map: WarMap = load(path).instantiate()
		for key: String in [map.site_name, map.briefing]:
			if key != "":
				assert_str(tr(key)).override_failure_message("%s: %s" % [path, key]).is_not_equal(key)
		map.free()
	TranslationServer.set_locale(locale)


func test_no_map_puts_a_piece_under_the_war_sheets_title_block() -> void:
	for path in WarMap.map_paths():
		var map: WarMap = load(path).instantiate()
		for piece: Dictionary in map.layout():
			var cells := Rect2i(piece.cell, piece.size)
			assert_bool(cells.intersects(WarSheet.TITLE_CELLS)).override_failure_message(
					"%s: %s at %s" % [path, piece.kind, piece.cell]).is_false()
		map.free()
