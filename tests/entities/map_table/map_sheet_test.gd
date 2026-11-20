extends GdUnitTestSuite

const WorldRegister := preload("res://entities/map_table/world_register.gd")
## Every sheet: the world's, the war's and each country's own.
const SHEETS := ["world", "war", "kohlmark", "ostrevia", "veldmark", "sulvania", "grauland", "nordhal", "morrow", "lower_provinces", "endmark"]

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func _sheet(id: String) -> MapSheet:
	var path := "res://entities/map_table/%s_sheet.tscn" % id if id in ["world", "war"] else MapTable.COUNTRY_SCENE % id
	var sheet: MapSheet = auto_free(load(path).instantiate())
	add_child(sheet)
	return sheet


func _labels_json() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://reports/maps/labels.json"))


## A country's farm sites as its sheet was generated from them (tools/make_map_sheets.py).
func _farm_sites(country: String) -> Array:
	return _labels_json().country_maps[country].farm_sites


## The world sheet's holding points, one per country, as the sheet was generated from them.
func _holdings() -> Array:
	return _labels_json().world_map.farm_sites


## The world sheet's countries (their neighbours, click outlines, distance from home) and its drawn sea lanes.
func _world() -> Dictionary:
	return _labels_json().world_map


func _country(id: String) -> Dictionary:
	for country: Dictionary in _world().countries:
		if country.id == id:
			return country
	return {}


func _labels(sheet: MapSheet) -> Array[Label]:
	var out: Array[Label] = []
	for label: Label in sheet.get_node("Page/Sheet").find_children("*", "Label", true, false):
		out.append(label)
	return out


func _texts(sheet: MapSheet) -> Array[String]:
	var out: Array[String] = []
	for label in _labels(sheet):
		out.append(label.text)
	return out


func test_a_roll_grows_thicker_as_it_takes_up_paper_from_the_bare_core() -> void:
	assert_float(MapSheet.roll_radius(1.0)).is_equal_approx(MapSheet.CORE, 0.0001)
	assert_float(MapSheet.roll_radius(0.5)).is_greater(MapSheet.roll_radius(1.0))
	assert_float(MapSheet.roll_radius(0.0)).is_greater(MapSheet.roll_radius(0.5))
	assert_float(MapSheet.roll_radius(0.0)).is_between(0.05, 0.09)  # Chunky, and it fits the holder's saddle.


func test_the_shader_rolls_the_paper_with_the_scripts_core_pitch_and_length() -> void:
	var paper: ShaderMaterial = _sheet("war").get_node("Paper").material_override
	assert_float(paper.get_shader_parameter("core")).is_equal_approx(MapSheet.CORE, 0.0001)
	assert_float(paper.get_shader_parameter("pitch")).is_equal_approx(MapSheet.PITCH, 0.0001)
	assert_float(paper.get_shader_parameter("sheet_length")).is_equal_approx(MapSheet.SIZE.y, 0.0001)


func test_every_sheet_has_its_art_its_own_paper_and_a_name() -> void:
	var papers := []
	for id: String in SHEETS:
		var sheet := _sheet(id)
		assert_str(sheet.id).is_equal(id)
		assert_str(sheet.title).is_not_empty()
		assert_object((sheet.get_node("Page/Sheet/Art") as TextureRect).texture).override_failure_message(id).is_not_null()
		var paper: Material = sheet.get_node("Paper").material_override
		assert_bool(papers.has(paper)).is_false()  # Each sheet rolls by itself.
		papers.append(paper)


func test_a_countrys_sheet_is_its_farm_register_and_wears_its_name() -> void:
	for id: String in SHEETS.slice(2):
		var sheet := _sheet(id)
		assert_object(sheet as FarmRegister).override_failure_message(id).is_not_null()
		assert_str(sheet.title).is_equal(_country(id).country)
		assert_str(sheet.tag_name()).is_equal(_country(id).country.to_upper())
		assert_bool((sheet as FarmRegister).head_office != Vector3.ZERO).override_failure_message(id).is_equal(id == "kohlmark")  # Only home has the head office.
	assert_str(_sheet("world").tag_name()).is_equal("WORLD")
	assert_str(_sheet("war").tag_name()).is_equal("WAR")


func test_the_lettering_is_printed_on_the_paper_so_it_rolls_up_with_it() -> void:
	for id: String in SHEETS:
		var sheet := _sheet(id)
		if id != "war":  # The war sheet is all battlefield: no lettering on its paper.
			assert_int(_labels(sheet).size()).override_failure_message(id).is_greater(20)
		# The only lettering off the paper is the name tag on its roll (and the war's control box, a desk prop,
		# the world sheet's bandit camp marker, a pin stuck in it with its paper tag, and its unrest clock lying on it).
		var off_paper := sheet.find_children("*", "Label3D", true, false).filter(func(l: Node) -> bool:
			for prop: String in ["Control", "Camp", "UnrestClock"]:
				if sheet.has_node(prop) and sheet.get_node(prop).is_ancestor_of(l):
					return false
			return true)
		assert_array(off_paper).is_equal([sheet.get_node("Core/Tag/Name")])
		var paper: ShaderMaterial = sheet.get_node("Paper").material_override
		assert_object(paper.get_shader_parameter("sheet_tex")).is_not_null()


func test_the_sheets_carry_their_title_blocks_farm_names_and_country_names_and_the_war_sheet_only_its_title_block() -> void:
	for id: String in SHEETS.slice(2):
		var texts := _texts(_sheet(id))
		assert_array(texts).override_failure_message(id).contains([_labels_json().country_maps[id].capital.name])
		for site: Dictionary in _farm_sites(id):
			assert_array(texts).contains([site.name])  # Its name tag; the price tag is FarmRegister's.
	assert_array(_texts(_sheet("kohlmark"))).contains(["KOHLMARK - NATIONAL FARM REGISTER", "WIRSINGEN"])
	assert_array(_texts(_sheet("world"))).contains(
			["WORLD MARKETS - GENERAL CHART", "Kohlmark", "The Lower Provinces", "Endmark Isle", "Grey Sea"])
	var war := _sheet("war")  # The paper is the battlefield: only a retreat's stamp and the small title block in its corner.
	var block := war.get_node("Page/Sheet/TitleBlock")
	assert_array(_labels(war).filter(func(l: Label) -> bool: return not block.is_ancestor_of(l)).map(func(l: Label) -> String: return l.text)) 			.is_equal(["WITHDRAWN"])


func test_lettering_too_small_to_read_from_the_map_camera_is_left_off_outside_the_title_block() -> void:
	# 1 px of the art is 1 mm of the desk. The title blocks sit in the sheets' bottom right.
	for id: String in SHEETS:
		var sheet := _sheet(id)
		var art := sheet.get_node("Page/Sheet") as Control
		for label in _labels(sheet):
			var centre := art.get_global_transform().affine_inverse() * label.get_global_rect().get_center()
			if label.get_theme_font_size(&"font_size") < 19:
				assert_bool(centre.x > 2200.0 and centre.y > 1300.0) \
						.override_failure_message("%s: %s is too small to read" % [id, label.text]).is_true()


func test_the_product_is_called_cabbage_on_every_sheet_never_unit() -> void:
	for id: String in SHEETS:
		for text in _texts(_sheet(id)):
			assert_bool(text.to_lower().contains("unit")).override_failure_message(text).is_false()


func test_names_and_numbers_are_left_as_they_are_in_every_language() -> void:
	for label in _labels(_sheet("kohlmark")):
		if label.text in ["Rotkohlheim Holding", "WIRSINGEN", "N", "20 km", "1 : 240 000"]:
			assert_int(label.auto_translate_mode).override_failure_message(label.text).is_equal(Node.AUTO_TRANSLATE_MODE_DISABLED)
		if label.text in ["KOHLMARK - NATIONAL FARM REGISTER", "SHEET", "Trunk Road B-12"]:
			assert_int(label.auto_translate_mode).override_failure_message(label.text).is_not_equal(Node.AUTO_TRANSLATE_MODE_DISABLED)


func test_every_translated_piece_of_lettering_is_in_the_translation_table() -> void:
	var keys := {}
	var table := FileAccess.open("res://ressources/translations/game.csv", FileAccess.READ)
	while not table.eof_reached():
		var row := table.get_csv_line()
		if row.size() >= 3 and not row[2].is_empty():
			keys[row[0]] = true
	for id: String in SHEETS:
		var sheet := _sheet(id)
		assert_bool(keys.has(sheet.title)).override_failure_message("no German for %s" % sheet.title).is_true()
		if sheet.roll_name != "":
			assert_bool(keys.has(sheet.roll_name)).override_failure_message("no German for %s" % sheet.roll_name).is_true()
		for label in _labels(sheet):
			if label.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
				assert_bool(keys.has(label.text)).override_failure_message("%s: no German for %s" % [id, label.text]).is_true()


func test_a_point_on_the_desk_maps_to_the_arts_pixels_from_the_top_left_a_millimetre_each() -> void:
	var sheet := _sheet("kohlmark")
	# Lying as on the map table: top edge towards the wall (+X), map-right along +Z.
	sheet.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(5.4, 0.752, 1.75))
	assert_bool(sheet.pixel_at(Vector3(5.4, 0.752, 0.15)).is_equal_approx(Vector2.ZERO)).is_true()
	assert_bool(sheet.pixel_at(Vector3(3.6, 0.752, 3.35)).is_equal_approx(Vector2(3200, 1800))).is_true()
	assert_bool(sheet.pixel_at(Vector3(4.5, 0.752, 1.75)).is_equal_approx(Vector2(1600, 900))).is_true()
	assert_bool(sheet.pixel_at(Vector3(4.5, 0.752, 1.751)).is_equal_approx(Vector2(1601, 900))).is_true()
	for pixel: Vector2 in [Vector2(1564, 994), Vector2(0, 0), Vector2(3200, 1800)]:
		assert_bool(sheet.pixel_at(sheet.point_at(pixel)).is_equal_approx(pixel)).is_true()


func test_only_pixels_inside_the_viewbox_are_on_the_paper() -> void:
	assert_bool(MapSheet.on_paper(Vector2(1600, 900))).is_true()
	assert_bool(MapSheet.on_paper(Vector2(-1, 900))).is_false()
	assert_bool(MapSheet.on_paper(Vector2(1600, 1801))).is_false()


func test_a_farm_token_stands_on_its_farm_sites_pixel_in_every_country() -> void:
	for id: String in SHEETS.slice(2):
		var sheet := _sheet(id)
		assert_int(sheet.thing_count()).is_equal(WorldRegister.COUNTRIES[StringName(id)].farms)
		for site: Dictionary in _farm_sites(id):
			var nearest := INF
			for thing: Node3D in sheet.get_node("Things").get_children():
				nearest = minf(nearest, sheet.pixel_at(thing.global_position).distance_to(Vector2(site.x, site.y)))
			assert_float(nearest).override_failure_message("no token on %s" % site.id).is_less(1.0)


func test_a_farm_sites_name_fits_its_name_tag_without_being_set_smaller_than_it_needs() -> void:
	for id: String in SHEETS.slice(2):
		var by_text := {}
		for label in _labels(_sheet(id)):
			by_text[label.text] = label
		for site: Dictionary in _farm_sites(id):
			var label: Label = by_text[site.name]
			var size := label.get_theme_font_size(&"font_size")
			var width := label.get_theme_font(&"font").get_string_size(site.name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			assert_float(width).override_failure_message("%s overflows its tag" % site.name).is_less(site.name_tag.w)
			assert_int(size).override_failure_message("%s is set too small" % site.name).is_greater_equal(24)


func test_more_art_can_be_laid_over_a_sheets_base_under_its_lettering() -> void:
	for id: String in SHEETS:
		var sheet := _sheet(id)
		var page := sheet.get_node("Page/Sheet")
		assert_int(page.get_node("Art").get_index()).is_equal(0)
		assert_int(page.get_node("Layers").get_index()).is_equal(1)
		for label in _labels(sheet):  # Lettering in a group (the war sheet's tray rows): the group's place.
			var top: Node = label
			while top.get_parent() != page:
				top = top.get_parent()
			assert_int(top.get_index()).is_greater(1)


func test_a_sheet_is_printed_again_when_the_language_changes() -> void:
	var sheet := _sheet("world")
	var page: SubViewport = sheet.get_node("Page")
	page.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sheet.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_int(page.render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)
	page.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sheet.reprint()  # And on request: a layer was shown or hidden.
	assert_int(page.render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)


func test_a_rolled_sheet_wears_its_name_tag_and_an_open_one_does_not() -> void:
	var sheet := _sheet("sulvania")
	sheet.open = 0.0
	assert_bool(sheet.get_node("Core/Tag").visible).is_true()
	assert_str((sheet.get_node("Core/Tag/Name") as Label3D).text).is_equal("SULVANIA")
	sheet.open = 1.0
	assert_bool(sheet.get_node("Core/Tag").visible).is_false()


func test_a_token_stands_on_each_farm_site_and_one_on_each_country_of_the_world() -> void:
	assert_int(_sheet("kohlmark").thing_count()).is_equal(8)
	assert_int(_sheet("world").thing_count()).is_equal(9)
	assert_int(_sheet("war").thing_count()).is_equal(1)  # Its fighting map, standing up as one.
	for thing: Node3D in _sheet("sulvania").get_node("Things").get_children():
		assert_float(thing.position.x).is_between(-MapSheet.SIZE.x / 2.0, MapSheet.SIZE.x / 2.0)
		assert_float(thing.position.z).is_between(0.0, MapSheet.SIZE.y)


func test_the_things_on_a_sheet_pop_up_from_map_left_to_map_right() -> void:
	var sheet := _sheet("kohlmark")
	var last := -INF
	for i in sheet.thing_count():
		assert_float(sheet._standing[i].position.x).is_greater_equal(last)
		last = sheet._standing[i].position.x


func test_a_tucked_thing_is_hidden_and_a_raised_one_stands_at_its_own_size() -> void:
	var sheet := _sheet("world")
	assert_bool(sheet.thing_up(0)).is_false()  # Rolled up until the table lays it out.
	sheet.raise_thing(1.0, 0)
	assert_bool(sheet.thing_up(0)).is_true()
	assert_bool(sheet._standing[0].scale.is_equal_approx(sheet._stand_scale[0])).is_true()
	sheet.raise_thing(0.0, 0)
	assert_bool(sheet.thing_up(0)).is_false()


func test_the_props_are_in_the_shared_machine_paint_and_metal_and_only_an_owned_look_is_cabbage_green() -> void:
	var shared := ["res://assets/materials/machine_paint_matte.tres", "res://assets/materials/machine_metal.tres"]
	var greens := 0
	for scene: String in ["drafting_weight", "chart_holder", "roll_core", "farm_token", "site_token", "desk_button"]:
		var node: Node = auto_free(load("res://entities/map_table/props/%s.tscn" % scene).instantiate())
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				assert_array(shared).contains([mesh.mesh.surface_get_material(surface).resource_path])
				for colour: Color in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
					var green := colour.s > 0.45 and colour.g > colour.r + 0.05 and colour.g > colour.b + 0.05
					greens += int(green)
					assert_bool(green and mesh.name != "Owned").override_failure_message("%s/%s is green" % [scene, mesh.name]).is_false()
	assert_int(greens).is_greater(0)  # The owned looks are.


func test_the_flash_of_an_acquisition_is_paper_pale_not_coloured() -> void:
	var flash: MeshInstance3D = auto_free(load("res://entities/map_table/map_flash.tscn").instantiate())
	assert_float((flash.get_surface_override_material(0) as StandardMaterial3D).albedo_color.s).is_less(0.1)


func test_a_thing_on_a_sheet_shows_its_for_sale_look_until_it_is_owned_and_its_owned_look_after() -> void:
	for scene: String in ["farm_token", "site_token"]:
		var thing: MapBuilding = auto_free(load("res://entities/map_table/props/%s.tscn" % scene).instantiate())
		assert_bool(thing.get_node("ForSale").visible and not thing.get_node("Owned").visible).is_true()
		thing.owned = true
		assert_bool(thing.get_node("Owned").visible and not thing.get_node("ForSale").visible).is_true()
		thing.owned = false
		assert_bool(thing.get_node("ForSale").visible and not thing.get_node("Owned").visible).is_true()


func test_an_open_sheets_core_lies_on_its_end_caps_and_a_rolled_ones_in_the_rolls_middle_wearing_its_band() -> void:
	assert_float(MapSheet.core_height(1.0)).is_equal(MapSheet.CAP)
	assert_float(MapSheet.core_height(0.0)).is_equal(MapSheet.roll_radius(0.0))
	var sheet := _sheet("world")
	sheet.open = 0.0
	assert_bool(sheet.get_node("Core/Band").visible).is_true()
	assert_float(sheet.get_node("Core").position.y).is_equal_approx(MapSheet.roll_radius(0.0), 0.0001)
	sheet.open = 1.0
	assert_bool(sheet.get_node("Core/Band").visible).is_false()  # No roll left to wear it.
	assert_float(sheet.get_node("Core").position.y).is_equal_approx(MapSheet.CAP, 0.0001)


func test_the_things_on_a_sheet_stay_small_and_leave_the_tags_below_them_clear() -> void:
	# What a thing stands in, by its sheet: a farm site's disc on a country's sheet (r 100 mm at
	# least), a country's holding ring on the world map (r 45 mm). The name tag sits 120 mm below a farm site.
	for entry: Array in [["kohlmark", 0.2], ["sulvania", 0.2], ["world", 0.09]]:
		var sheet := _sheet(entry[0])
		for i in sheet.thing_count():
			sheet.raise_thing(1.0, i)
		for thing: Node3D in sheet.get_node("Things").get_children():
			for mesh: MeshInstance3D in thing.find_children("*", "MeshInstance3D", true, false):
				var size := mesh.get_aabb().size * thing.scale.x  # Round things: turned, they are no wider.
				assert_float(maxf(size.x, size.z)).override_failure_message(
						"%s/%s is too big" % [entry[0], thing.name]).is_less(entry[1])


func test_the_world_map_has_one_holding_point_per_country_and_they_hold_all_24_farms() -> void:
	var holdings := _holdings()
	assert_int(holdings.size()).is_equal(9)
	var farms := 0
	for holding: Dictionary in holdings:
		farms += int(holding.farms)
	assert_int(farms).is_equal(24)


func test_a_countrys_token_stands_on_its_holding_point_with_its_farm_count_printed_beside_it() -> void:
	var sheet := _sheet("world")
	var by_text := {}
	for label in _labels(sheet):
		by_text[label.text] = by_text.get(label.text, []) + [label]
	for holding: Dictionary in _holdings():
		var nearest := INF
		for thing: Node3D in sheet.get_node("Things").get_children():
			nearest = minf(nearest, sheet.pixel_at(thing.global_position).distance_to(Vector2(holding.x, holding.y)))
		assert_float(nearest).override_failure_message("no token on %s" % holding.id).is_less(1.0)
		var tag := Vector2(holding.count_tag.x, holding.count_tag.y)
		var printed := false
		# The rules print it (WorldRegister.tag_text): the farms owned of the country's farms.
		for label: Label in by_text.get(WorldRegister.tag_text(SaveManager.save, StringName(holding.id)), []):
			printed = printed or (label.position + label.size / 2.0).distance_to(tag) < 1.0
		assert_bool(printed).override_failure_message("no farm count beside %s" % holding.id).is_true()


func test_a_world_token_stands_half_again_as_big_as_its_built_size() -> void:
	var sheet := _sheet("world")
	for i in sheet.thing_count():
		assert_float(sheet._stand_scale[i].x).is_equal_approx(1.5, 0.001)


func test_the_world_has_nine_countries_and_the_last_is_the_final_island() -> void:
	var ids: Array = _world().countries.map(func(c: Dictionary) -> String: return c.id)
	assert_array(ids).is_equal(["kohlmark", "ostrevia", "veldmark", "sulvania", "grauland", "nordhal", "morrow", "lower_provinces", "endmark"])


func test_the_final_island_is_reached_only_from_nordhal() -> void:
	assert_array(_country("endmark").adjacent).is_equal(["nordhal"])
	assert_array(_country("endmark").sea_links).is_equal(["nordhal"])
	var lanes: Array = _world().sea_lanes.filter(func(l: Dictionary) -> bool: return "endmark" in [l.a, l.b])
	assert_int(lanes.size()).is_equal(1)
	assert_array([lanes[0].a, lanes[0].b]).is_equal(["nordhal", "endmark"])


func test_no_country_but_nordhal_borders_the_final_island() -> void:
	for country: Dictionary in _world().countries:
		assert_bool("endmark" in country.adjacent).override_failure_message(country.id).is_equal(country.id == "nordhal")


func test_the_final_island_is_the_farthest_country_from_home() -> void:
	for country: Dictionary in _world().countries:
		if country.id != "endmark":
			assert_int(int(country.distance_rank)).override_failure_message(country.id).is_less(int(_country("endmark").distance_rank))


func test_the_final_island_holds_the_24th_farm_and_nordhal_two() -> void:
	for holding: Dictionary in _holdings():
		if holding.id == "endmark":
			assert_int(int(holding.farms)).is_equal(1)
		if holding.id == "nordhal":
			assert_int(int(holding.farms)).is_equal(2)


func test_four_sea_lanes_are_drawn_and_each_joins_two_countries_that_are_neighbours_by_sea() -> void:
	var lanes: Array = _world().sea_lanes
	assert_array(lanes.map(func(l: Dictionary) -> String: return l.id)).is_equal(
			["sulvania-grauland", "sulvania-lower_provinces", "lower_provinces-morrow", "nordhal-endmark"])
	for lane: Dictionary in lanes:
		assert_array(_country(lane.a).sea_links).contains([lane.b])
		assert_array(_country(lane.b).sea_links).contains([lane.a])


func test_every_country_of_the_world_has_a_click_outline_and_an_owned_overlay() -> void:
	for country: Dictionary in _world().countries:
		assert_int(country.outline[0].size()).override_failure_message(country.id).is_greater(10)
		assert_bool(ResourceLoader.exists("res://assets/sprites/maps/world_owned/%s.svg" % country.id)).override_failure_message(country.id).is_true()


func test_the_final_islands_holding_point_and_count_tag_lie_inside_its_click_outline() -> void:
	var outline := PackedVector2Array()
	for point: Array in _country("endmark").outline[0]:
		outline.append(Vector2(point[0], point[1]))
	for holding: Dictionary in _holdings():
		if holding.id == "endmark":
			assert_bool(Geometry2D.is_point_in_polygon(Vector2(holding.x, holding.y), outline)).is_true()
			assert_bool(Geometry2D.is_point_in_polygon(Vector2(holding.count_tag.x, holding.count_tag.y), outline)).is_true()
