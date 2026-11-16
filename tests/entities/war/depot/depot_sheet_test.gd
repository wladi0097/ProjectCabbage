extends GdUnitTestSuite

const SCENE := preload("res://entities/war/depot/depot_sheet.tscn")

var _real_save: SaveGame
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation", "war_mode"])
	save.storage_cap = 100000
	save.stock = 50000
	save.findings = 100000
	SaveManager.save = save


func after_test() -> void:
	SaveManager.save = _real_save
	TranslationServer.set_locale(_locale)


func _sheet() -> DepotSheet:
	var sheet: DepotSheet = auto_free(SCENE.instantiate())
	add_child(sheet)
	sheet.open = 1.0
	for i in sheet.thing_count():
		sheet.raise_thing(1.0, i)
	return sheet


## The art pixel in the middle of `unit`'s HIRE AND TRAIN button.
func _hire(sheet: DepotSheet, unit := "field_associate") -> Vector2:
	return sheet._art_rect(sheet._columns[unit].get_node("Hire")).get_center()


func test_a_click_on_hire_and_train_buys_one_figure_and_starts_its_training() -> void:
	var sheet := _sheet()
	var stock := SaveManager.save.stock
	var spot := sheet.spot_at(_hire(sheet))
	assert_str(spot).is_equal(&"buy:field_associate")
	sheet.press(spot)
	assert_int(SaveManager.save.stock).is_equal(stock - WarRules.unit_cabbage_price("field_associate"))
	assert_int(SaveManager.save.army_training.size()).is_equal(1)
	assert_bool((sheet.get_node("Hire") as SoundCue).playing).is_true()
	assert_bool((sheet.get_node("Things/trainee_field_associate") as Node3D).visible).is_true()  # It lands grey.
	assert_bool((sheet.get_node("Land") as SoundCue).playing).is_true()


func test_a_refused_hire_at_the_army_cap_buys_nothing_and_says_why() -> void:
	SaveManager.save.army = {field_associate = WarRules.army_cap(SaveManager.save)}
	var sheet := _sheet()
	var stock := SaveManager.save.stock
	assert_str((sheet._columns["field_associate"].get_node("Note") as Label).text).is_equal("STAFF AT CAPACITY")
	sheet.press(sheet.spot_at(_hire(sheet)))
	assert_int(SaveManager.save.stock).is_equal(stock)
	assert_bool(SaveManager.save.army_training.is_empty()).is_true()
	assert_bool((sheet.get_node("Jam") as SoundCue).playing).is_true()
	assert_str((sheet.get_node("Page/Sheet/Staff") as Label).text).is_equal("STAFF %d / %d" % [WarRules.army_cap(SaveManager.save), WarRules.army_cap(SaveManager.save)])


func test_the_grey_trainees_bar_fills_with_its_training_says_the_seconds_left_and_counts_the_rest_of_the_queue() -> void:
	var sheet := _sheet()
	for i in 3:
		sheet.requisition("field_associate")
	var save := SaveManager.save
	save.army_training[0].left = WarRules.training_seconds(save, "field_associate") / 2.0
	sheet._process(0.0)
	var column: Control = sheet._columns["field_associate"]
	var line := column.get_node("Line") as Control
	var fill := line.get_node("Fill") as Control
	assert_float(fill.size.x).is_equal_approx((line.size.x - 2.0 * fill.position.x) / 2.0, 0.5)  # Half the track.
	assert_float(line.size.y).is_greater_equal(24.0)  # A bar, readable from the map camera.
	assert_float(line.size.x).is_greater_equal(80.0)
	var trainee := column.get_node("Trainee") as Control
	assert_float(line.position.y).is_greater(trainee.position.y)  # Right under the trainee's feet...
	assert_float(absf(line.position.x + line.size.x / 2.0 - trainee.position.x)).is_less(20.0)  # ...and centred on it.
	var left := column.get_node("Left") as Label
	assert_bool(left.visible).is_true()
	assert_str(left.text).is_equal("%d s" % ceili(WarRules.training_seconds(save, "field_associate") / 2.0))
	assert_bool((column.get_node("More") as Label).visible).is_true()
	assert_str((column.get_node("More") as Label).text).is_equal("+2")


func test_a_finished_trainee_jumps_into_the_big_figure_and_the_ready_count_goes_up() -> void:
	var sheet := _sheet()
	sheet.requisition("field_associate")
	WarRules.tick_training(SaveManager.save, WarRules.training_seconds(SaveManager.save, "field_associate") + 0.1)
	sheet._process(0.0)
	assert_bool((sheet.get_node("Things/jumper_field_associate") as Node3D).visible).is_true()  # Mid-jump.
	assert_bool((sheet.get_node("Hop") as SoundCue).playing).is_true()
	assert_bool((sheet.get_node("Things/trainee_field_associate") as Node3D).visible).is_false()  # Nobody else queued.
	assert_str((sheet._columns["field_associate"].get_node("Ready") as Label).text).is_equal("1×")


func test_a_hidden_depot_sheet_stops_re_rendering_its_page() -> void:
	var sheet := _sheet()
	sheet._process(0.0)
	var page := sheet.get_node("Page") as SubViewport
	assert_int(page.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)
	sheet.hide()
	sheet._process(0.0)
	assert_int(page.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func test_figures_that_finished_training_while_the_depot_was_closed_show_in_the_count_without_a_jump() -> void:
	var sheet := _sheet()
	sheet.requisition("field_associate")
	sheet.hide()
	WarRules.tick_training(SaveManager.save, WarRules.training_seconds(SaveManager.save, "field_associate") + 0.1)
	sheet._process(0.0)
	sheet.show()
	sheet._process(0.0)
	assert_bool((sheet.get_node("Things/jumper_field_associate") as Node3D).visible).is_false()
	assert_bool((sheet.get_node("Hop") as SoundCue).playing).is_false()
	assert_str((sheet._columns["field_associate"].get_node("Ready") as Label).text).is_equal("1×")


func test_a_loaded_save_shows_its_trainee_in_place_without_a_landing() -> void:
	WarRules.buy(SaveManager.save, "field_associate")
	var sheet := _sheet()
	var trainee := sheet.get_node("Things/trainee_field_associate") as Node3D
	assert_bool(trainee.visible).is_true()
	assert_bool(sheet._landing.has("field_associate")).is_false()
	var column: Control = sheet._columns["field_associate"]
	var at: Vector2 = column.position + (column.get_node("Trainee") as Control).position
	assert_vector(sheet.pixel_at(trainee.global_position)).is_equal_approx(at, Vector2.ONE * 0.5)


## Moves the map table's mouse (as it hands it on) onto research node `node_id` of the selected
## unit's tree, or off the tree (`node_id` "").
func _mouse_on_node(sheet: DepotSheet, node_id: String) -> void:
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	var wheel: Array = tree._wheel()
	var at: Vector2 = sheet._art_rect(tree).position + wheel[0] + DepotResearch.node_data(node_id).at * wheel[1] if node_id != "" else Vector2(3000, 100)
	sheet.take_mouse(InputEventMouseMotion.new(), at)
	# The page's GUI takes pushed input on its next frame: what the tree then sees, set directly.
	tree._process(0.0)  # Lays the tree out (which nodes show).
	tree._hover(at - sheet._art_rect(tree).position if node_id != "" else UpgradeTree.OFF)


func test_hovering_a_research_node_shows_the_trees_own_popup_and_no_hint_slip() -> void:
	var sheet := _sheet()
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	assert_float(tree.popup_scale).is_greater(1.0)  # Read from the map camera.
	_mouse_on_node(sheet, "fa_hp_1")
	assert_str(tree._hovered).is_equal("fa_hp_1")  # The tree draws its popup beside it.
	assert_bool(sheet.has_method(&"hovered_spot")).is_false()  # The map's slip says nothing about it.
	assert_str(sheet.hint(&"research:fa_hp_1")).is_empty()
	_mouse_on_node(sheet, "")
	assert_str(tree._hovered).is_equal("")


func test_short_of_cabbages_the_requisition_box_says_so() -> void:
	SaveManager.save.stock = 0
	var sheet := _sheet()
	assert_str((sheet._columns["field_associate"].get_node("Note") as Label).text).is_equal("NOT ENOUGH CABBAGES")


func test_the_sheet_shows_only_hired_unit_types_the_depot_deals_in() -> void:
	SaveManager.save.stamped.append("unit_senior")
	var sheet := _sheet()
	assert_array(sheet._columns.keys()).is_equal(Depot.IN_SERVICE)
	for unit: String in Depot.IN_SERVICE:
		var hired := unit in ["field_associate", "senior_asset"]
		assert_bool(sheet._columns[unit].visible).override_failure_message(unit).is_equal(hired)
		assert_bool((sheet.get_node("Things/" + unit) as Node3D).visible).override_failure_message(unit).is_equal(hired)
	# Hired ones fill the slots from the left, in depot order.
	assert_float(sheet._columns["senior_asset"].position.x).is_equal(DepotSheet.COLUMN_LEFT + DepotSheet.COLUMN_WIDTH + DepotSheet.COLUMN_GAP)


func test_with_every_unit_hired_the_columns_stay_full_size_across_the_top_above_the_research() -> void:
	SaveManager.save.stamped.append_array(["unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	var sheet := _sheet()
	var head := (sheet.get_node("Page/Sheet/ResearchHead") as Control).position
	for unit: String in Depot.IN_SERVICE:
		var column: Control = sheet._columns[unit]
		assert_vector(column.scale).override_failure_message(unit).is_equal(Vector2.ONE)
		assert_float(column.size.x).is_equal(DepotSheet.COLUMN_WIDTH)
		assert_float(column.position.y + column.size.y).override_failure_message(unit).is_less(head.y)
	var last: Control = sheet._columns["courier"]
	assert_float(last.position.x + last.size.x).is_less_equal(MapSheet.SIZE.x * MapSheet.PIXELS_PER_METRE - DepotSheet.COLUMN_LEFT)
	var figure := sheet.get_node("Things/courier") as Node3D
	assert_vector(sheet.pixel_at(figure.global_position)).is_equal_approx(sheet._stage("courier"), Vector2.ONE * 0.5)
	for unit: String in Depot.IN_SERVICE:  # Big ones are printed smaller: none spills onto its HIRE AND TRAIN button.
		var model := sheet.get_node("Things/%s/Model" % unit) as VisualInstance3D
		var box := ((sheet.get_node("Things") as Node3D).global_transform.affine_inverse() * model.global_transform) * model.get_aabb()
		assert_float(maxf(box.size.x, box.size.z)).override_failure_message(unit).is_less_equal(DepotSheet.FIGURE_FOOT + 0.001)


func test_the_research_area_spans_the_sheet_below_the_columns_left_of_the_title_block() -> void:
	var sheet := _sheet()
	var tree := sheet.get_node("Page/Sheet/Tree") as Control
	var title := (sheet.get_node("Page/Sheet/Title") as Control).position
	assert_float(tree.position.x).is_equal(DepotSheet.COLUMN_LEFT)
	assert_float(tree.position.x + tree.size.x).is_less_equal(title.x)
	assert_float(tree.size.x).is_greater(MapSheet.SIZE.x * MapSheet.PIXELS_PER_METRE * 0.6)


func test_the_general_programme_holds_the_four_war_chains_off_its_department_paid_in_coins() -> void:
	var chains := {war_time_ = 3, war_training_ = 3, war_cap_ = 3, war_retreat_ = 5}
	for prefix: String in chains:
		var parent := "dept_general"
		var price := 0
		for step in range(1, int(chains[prefix]) + 1):
			var node := DepotResearch.node_data("%s%d" % [prefix, step])
			assert_str(node.parent).override_failure_message(node.id).is_equal(parent)
			assert_int(node.price).override_failure_message(node.id).is_greater(price)
			assert_str(UpgradeTree.currency_of(node)).is_equal("coins")
			parent = node.id
			price = node.price
		assert_dict(DepotResearch.node_data("%s%d" % [prefix, int(chains[prefix]) + 1])).is_empty()
	var general: Vector2 = DepotResearch.node_data("dept_general").at
	assert_float(general.y).is_less(0.0)  # Above the hub...
	for unit: String in Depot.IN_SERVICE:  # ...the units' plates below it.
		assert_float(DepotResearch.node_data(DepotResearch.dept_of(unit)).at.y).is_greater(0.0)
	for node: Dictionary in DepotResearch.NODES:
		if DepotResearch.is_general(node.id):
			assert_float(node.at.y).override_failure_message(node.id).is_less(0.1)


func test_the_general_programme_shows_with_the_war_card_and_exit_interviews_need_the_withdrawal_protocol() -> void:
	var save := SaveManager.save
	save.coins = 100000000
	assert_bool(DepotResearch.is_shown("war_time_1", save)).is_true()
	save.stamped.erase("war_mode")
	assert_bool(DepotResearch.is_shown("war_time_1", save)).is_false()
	assert_bool(DepotResearch.is_shown("dept_general", save)).is_false()
	save.stamped.append("war_mode")
	assert_str(DepotResearch.locked_by("war_retreat_1", save)).is_equal("retreat")
	assert_str(DepotResearch.requirement("war_retreat_1", save)[0]).is_equal("LOCKED")
	assert_bool(DepotResearch.buy("war_retreat_1", save)).is_false()
	save.stamped.append("retreat")
	assert_bool(DepotResearch.buy("war_retreat_1", save)).is_true()


func test_buying_a_general_node_pays_coins_into_tree_bought_and_war_rules_feel_it() -> void:
	var save := SaveManager.save
	save.coins = 100000000
	var cap := WarRules.army_cap(save)
	var fight := WarRules.fight_seconds(save)
	var sheet := _sheet()
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	tree._holding = "war_cap_1"
	tree._process(UpgradeTree.HOLD_TIME + 0.01)
	assert_bool(save.tree_bought.has("war_cap_1")).is_true()
	assert_int(save.coins).is_equal(100000000 - DepotResearch.price_of("war_cap_1", save))
	assert_int(WarRules.army_cap(save)).is_equal(cap + WarRules.NODE_CAP)
	assert_bool(DepotResearch.buy("war_time_1", save)).is_true()
	assert_float(WarRules.fight_seconds(save)).is_greater(fight)
	assert_bool(save.unit_research.is_empty()).is_true()  # Kept apart from the unit research.
	assert_bool(DepotResearch.is_bought("war_cap_1", save)).is_true()


func test_every_general_node_has_english_and_german_text_and_never_says_units() -> void:
	var german := {}
	var table := FileAccess.open("res://ressources/translations/game.csv", FileAccess.READ)
	while not table.eof_reached():
		var row := table.get_csv_line()
		if row.size() >= 3 and not row[2].is_empty():
			german[row[0]] = true
	for node: Dictionary in DepotResearch.NODES:
		if DepotResearch.is_dept(node.id) or DepotResearch.is_general(node.id):
			for text: String in [node.title, node.body]:
				assert_bool(german.has(text)).override_failure_message("%s: no German for %s" % [node.id, text]).is_true()
				assert_bool(text.to_lower().contains("unit")).override_failure_message("%s says units" % node.id).is_false()


func test_one_research_tree_holds_a_department_with_its_branch_for_every_hired_unit_and_nothing_for_the_rest() -> void:
	SaveManager.save.stamped.append_array(["unit_senior", "unit_courier"])
	var sheet := _sheet()
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	tree._process(0.0)  # Works out what shows.
	var hired := ["field_associate", "senior_asset", "courier"]
	for unit: String in Depot.IN_SERVICE:
		var dept := DepotResearch.dept_of(unit)
		assert_bool(DepotResearch.is_dept(dept)).override_failure_message(unit).is_true()
		assert_bool(tree._shown.has(dept)).override_failure_message(unit).is_equal(unit in hired)
		for node: Dictionary in WarRules.RESEARCH:
			if node.unit == unit:
				assert_bool(tree._shown.has(node.id)).override_failure_message(node.id).is_equal(unit in hired)
	assert_bool(DepotResearch.can_hold("dept_field_associate", SaveManager.save)).is_false()  # Info only.


func test_each_units_research_hangs_off_its_own_department() -> void:
	assert_int(DepotResearch.ALL.size()).is_equal(WarRules.RESEARCH.size())
	for node: Dictionary in DepotResearch.ALL:
		var rule := WarRules.research_node(node.id)
		var parent: String = rule.parent if rule.parent != "" else DepotResearch.dept_of(rule.unit)
		assert_str(node.parent).override_failure_message(node.id).is_equal(parent)
	assert_int(DepotResearch.DEPTS.size()).is_equal(Depot.IN_SERVICE.size())
	# A root is reachable as soon as its unit is hired; it never asks for its department.
	assert_bool(DepotResearch.is_reachable("fa_hp_0", SaveManager.save)).is_true()
	assert_array(DepotResearch.requirement("fa_hp_0", SaveManager.save)).is_empty()
	assert_bool(DepotResearch.is_reachable("sa_hp_0", SaveManager.save)).is_false()  # Not hired.


func test_the_research_is_an_org_chart_hub_on_top_plates_in_a_row_in_column_order_and_each_units_nodes_below_its_plate() -> void:
	var plates: Array[Vector2] = []
	for unit: String in Depot.IN_SERVICE:  # The columns' order, left to right.
		plates.append(DepotResearch.node_data(DepotResearch.dept_of(unit)).at)
	for i in plates.size():
		assert_float(plates[i].y).is_greater(0.0)  # Below the hub (the root, at 0, 0).
		assert_float(plates[i].y).is_equal(plates[0].y)  # One row.
		if i > 0:
			assert_float(plates[i].x).is_greater(plates[i - 1].x)
	var half := (plates[1].x - plates[0].x) / 2.0
	for node: Dictionary in DepotResearch.ALL:
		var plate: Vector2 = DepotResearch.node_data(DepotResearch.dept_of(DepotResearch.unit_of(node.id))).at
		assert_float(node.at.y).override_failure_message(node.id).is_greater(plate.y)
		assert_float(absf(node.at.x - plate.x)).override_failure_message(node.id).is_less(half)  # In its own slot.
		var parent: Dictionary = DepotResearch.node_data(node.parent)
		assert_float(node.at.y).override_failure_message(node.id).is_greater(parent.at.y)  # Going down.


func test_every_node_plate_and_title_fits_the_research_box_at_home_without_meeting_another_in_english_and_german() -> void:
	SaveManager.save.stamped.append_array(["unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	var sheet := _sheet()
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	var wheel: Array = tree._wheel()
	var r: float = wheel[2]
	var title_size := int(clampf(r * 0.6, 9.0, 34.0))  # As UpgradeTree._draw_node prints a node's title.
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		var boxes: Array[Rect2] = [Rect2(wheel[0] - Vector2.ONE * r * 1.1, Vector2.ONE * r * 2.2)]  # The hub.
		var ids: Array[String] = ["hub"]
		for node: Dictionary in DepotResearch.NODES:
			var at: Vector2 = wheel[0] + node.at * wheel[1]
			var own: Array[Rect2] = []
			if node.get("dept", false):
				own.append(UpgradeTree.plate(node.title, at, r))
			else:
				own.append(Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0))
				var wide := UpgradeTree.FONT.get_string_size(tr(node.title), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
				own.append(Rect2(at.x - wide / 2.0, at.y - r - 8.0 - title_size * 0.95, wide, title_size * 0.95))
			for box in own:
				assert_bool(Rect2(Vector2.ZERO, tree.size).encloses(box)).override_failure_message(locale + " " + node.id).is_true()
				for i in boxes.size():
					assert_bool(boxes[i].grow(r * 0.2).intersects(box)).override_failure_message("%s %s meets %s" % [locale, node.id, ids[i]]).is_false()
			for box in own:
				boxes.append(box)
				ids.append(node.id)
	assert_int(title_size).is_greater_equal(24)  # Readable from the map camera at 720p.


func test_a_unit_with_research_it_can_buy_carries_a_mark_on_its_column() -> void:
	SaveManager.save.stamped.append("unit_senior")
	SaveManager.save.findings = DepotResearch.price_of("fa_hp_0", SaveManager.save)
	SaveManager.save.unit_research.append_array(["sa_hp_0", "sa_hp_1", "sa_damage_1", "sa_speed_1", "sa_hp_2"])
	var sheet := _sheet()
	assert_bool(DepotSheet.has_news(SaveManager.save, "field_associate")).is_true()
	assert_bool(sheet._columns["field_associate"].get_node("News").visible).is_true()
	assert_bool(sheet._columns["senior_asset"].get_node("News").visible).is_false()  # All approved.
	SaveManager.save.findings = 0
	sheet._process(0.0)
	assert_bool(sheet._columns["field_associate"].get_node("News").visible).is_false()


func test_every_column_word_fits_its_box_in_english_and_german_and_short_ones_keep_the_full_size() -> void:
	SaveManager.save.stamped.append_array(["unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	SaveManager.save.army = {field_associate = WarRules.army_cap(SaveManager.save)}  # The longest note.
	var sheet := _sheet()
	assert_int((sheet._columns["courier"].get_node("Name") as Label).get_theme_font_size(&"font_size")).is_equal(54)
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		sheet.refresh()
		for unit: String in Depot.IN_SERVICE:
			for path: String in ["Name", "Hire/Word", "Note", "Hp/Text", "Damage/Text", "Speed/Text", "Target/Text"]:
				var label := sheet._columns[unit].get_node(path) as Label
				var size := label.get_theme_font_size(&"font_size")
				assert_bool(DepotSheet.fits(label, size)).override_failure_message("%s %s %s" % [locale, unit, path]).is_true()
				assert_int(size).override_failure_message("%s %s %s" % [locale, unit, path]).is_greater(DepotSheet.MIN_FIT)


func test_a_senior_asset_is_refused_when_only_one_place_is_left() -> void:
	SaveManager.save.stamped.append("unit_senior")
	SaveManager.save.army = {field_associate = 2}
	assert_str(DepotSheet.refusal(SaveManager.save, "senior_asset")).is_equal("STAFF AT CAPACITY")
	assert_str(DepotSheet.refusal(SaveManager.save, "field_associate")).is_equal("")


func test_the_columns_figure_stands_on_its_stage_and_the_plates_print_its_stats() -> void:
	SaveManager.save.unit_research.append("fa_hp_1")
	var sheet := _sheet()
	var column: Control = sheet._columns["field_associate"]
	var figure := sheet.get_node("Things/field_associate") as Node3D
	var stage: Vector2 = column.position + (column.get_node("Stage") as Control).position
	assert_vector(sheet.pixel_at(figure.global_position)).is_equal_approx(stage, Vector2.ONE * 0.5)
	var stats := WarRules.unit_stats(SaveManager.save, "field_associate")
	assert_str((column.get_node("Hp/Text") as Label).text).is_equal("HP %d" % roundi(stats.hp))
	assert_str((column.get_node("Target/Text") as Label).text).is_equal("NEAREST DEFENCE")


func test_research_is_bought_on_the_shared_upgrade_tree_by_holding_parent_first_for_findings() -> void:
	var sheet := _sheet()
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	assert_object(tree.rules).is_same(DepotResearch)
	var findings := SaveManager.save.findings
	assert_bool(DepotResearch.can_hold("fa_hp_1", SaveManager.save)).is_false()  # Its parent first.
	tree._holding = "fa_hp_0"
	tree._process(UpgradeTree.HOLD_TIME + 0.01)
	assert_bool(SaveManager.save.unit_research.has("fa_hp_0")).is_true()
	assert_int(SaveManager.save.findings).is_equal(findings - DepotResearch.price_of("fa_hp_0", SaveManager.save))
	assert_bool((sheet.get_node("Research") as SoundCue).playing).is_true()
	assert_bool(DepotResearch.can_hold("fa_hp_1", SaveManager.save)).is_true()


func test_short_of_findings_a_research_node_cannot_be_bought() -> void:
	SaveManager.save.findings = 0
	assert_bool(DepotResearch.buy("fa_hp_0", SaveManager.save)).is_false()
	assert_bool(SaveManager.save.unit_research.is_empty()).is_true()


func test_the_column_starts_top_left_and_the_title_block_bottom_right_carries_the_form_and_headcount() -> void:
	var sheet := _sheet()
	var column := sheet._columns["field_associate"]
	assert_float(column.position.x).is_equal(DepotSheet.COLUMN_LEFT)
	assert_float(DepotSheet.COLUMN_LEFT).is_less(200.0)  # A paper margin, not a gap.
	assert_float(column.position.y).is_less(200.0)  # Nothing above the column.
	for part: String in ["Title", "FormLine", "Staff", "StaffNote"]:
		var label := sheet.get_node("Page/Sheet/" + part) as Control
		assert_bool(Rect2(2490, 840, 600, 880).encloses(Rect2(label.position, label.size))).override_failure_message(part).is_true()


func test_the_title_block_stands_beside_the_programme_as_tall_as_it() -> void:
	var sheet := _sheet()
	var head := sheet.get_node("Page/Sheet/ResearchHead") as Control
	var tree := sheet.get_node("Page/Sheet/Tree") as Control
	var title := sheet.get_node("Page/Sheet/Title") as Control
	var note := sheet.get_node("Page/Sheet/StaffNote") as Control
	assert_float(title.position.y).is_equal_approx(head.position.y, 30.0)  # Tops level...
	assert_float(note.position.y + note.size.y).is_equal_approx(tree.position.y + tree.size.y, 30.0)  # ...bottoms level.
	assert_float(tree.position.x + tree.size.x).is_less(title.position.x)  # Side by side.
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		SaveManager.save.army = {field_associate = 10}
		sheet.refresh()
		var staff := sheet.get_node("Page/Sheet/Staff") as Label
		assert_bool(DepotSheet.fits(staff, staff.get_theme_font_size(&"font_size"))).override_failure_message(locale).is_true()


func test_hovering_the_figure_lifts_it_and_leaving_settles_it_back() -> void:
	var sheet := _sheet()
	var figure := sheet.get_node("Things/field_associate") as Node3D
	var spot := sheet.spot_at(sheet._stage("field_associate"))
	assert_str(spot).is_equal(&"figure:field_associate")
	sheet.hover(spot)
	sheet._turning["field_associate"].custom_step(10.0)
	assert_float(figure.position.y).is_equal_approx(DepotSheet.FIGURE_LIFT, 0.0001)
	sheet.hover(&"")
	sheet._turning["field_associate"].custom_step(10.0)
	assert_float(figure.position.y).is_equal_approx(0.0, 0.0001)
	assert_vector(figure.rotation).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)


func test_the_ready_figures_are_counted_big_right_under_the_figure() -> void:
	SaveManager.save.army = {field_associate = 3}
	var sheet := _sheet()
	var count := sheet._columns["field_associate"].get_node("Ready") as Label
	assert_str(count.text).is_equal("3×")
	var stage := (sheet._columns["field_associate"].get_node("Stage") as Control).position
	assert_float(count.position.y).is_greater(stage.y)  # Below the figure's foot...
	assert_float(count.position.x + count.size.x / 2.0).is_equal_approx(stage.x, 1.0)  # ...and centred under it.


func test_the_price_under_the_button_is_the_cabbage_icon_and_the_number() -> void:
	var sheet := _sheet()
	var price := sheet._columns["field_associate"].get_node("Price")
	assert_object((price.get_node("Icon") as TextureRect).texture).is_equal(load("res://assets/sprites/icons/cabbage_icon.svg"))
	assert_str((price.get_node("Amount") as Label).text).is_equal(Num.text(WarRules.unit_cabbage_price("field_associate")))


func test_a_trainee_waiting_behind_another_units_shows_no_seconds_and_an_empty_bar() -> void:
	SaveManager.save.stamped.append("unit_senior")
	var sheet := _sheet()
	sheet.requisition("field_associate")
	sheet.requisition("senior_asset")
	sheet._process(0.0)
	var column: Control = sheet._columns["senior_asset"]
	assert_int(DepotSheet.seconds_left(SaveManager.save, "senior_asset")).is_equal(-1)
	assert_bool((column.get_node("Left") as Label).visible).is_false()
	assert_float((column.get_node("Line/Fill") as Control).size.x).is_equal(0.0)
	assert_float(DepotSheet.bar_fill(94.0, 5.0, 2.0)).is_equal(84.0)  # Never past the track.


func test_hovering_the_paragraph_mark_on_a_column_says_development_is_available() -> void:
	var sheet := _sheet()  # Findings 100,000: BODY ARMOUR is covered.
	var news := sheet._columns["field_associate"].get_node("News") as Control
	assert_bool(news.visible).is_true()
	var spot := sheet.spot_at(sheet._art_rect(news).get_center())
	assert_str(spot).is_equal(&"news:field_associate")
	assert_str(sheet.hint(spot)).starts_with("Development available")
	assert_bool(sheet.spot_box(spot).is_equal_approx(sheet._art_rect(news))).is_true()  # The slip lies beside the mark.


func test_the_hire_hint_lies_beside_its_own_columns_button_and_trainee_bar() -> void:
	SaveManager.save.stamped.append_array(["unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	var sheet := _sheet()
	for unit: String in Depot.IN_SERVICE:
		var box := sheet.spot_box(StringName("buy:" + unit))
		var column: Control = sheet._columns[unit]
		for part: String in ["Hire", "Line", "Note"]:
			assert_bool(box.encloses(sheet._art_rect(column.get_node(part)))).override_failure_message(unit + " " + part).is_true()


func test_hovering_the_grey_trainee_says_when_it_is_ready_and_how_many_wait_behind_it() -> void:
	var sheet := _sheet()
	for i in 3:
		sheet.requisition("field_associate")
	var save := SaveManager.save
	save.army_training[0].left = 7.0
	sheet._process(0.0)
	var column: Control = sheet._columns["field_associate"]
	var at: Vector2 = column.position + (column.get_node("Trainee") as Control).position + Vector2(0.0, -40.0)
	var spot := sheet.spot_at(at)
	assert_str(spot).is_equal(&"trainee:field_associate")
	assert_str(sheet.hint(spot)).is_equal("IN TRAINING. Available for deployment in 7 s. 2 more awaiting induction.")
	assert_bool(sheet.spot_box(spot).encloses(sheet._art_rect(column.get_node("Line")))).is_true()  # The slip clears the bar.
	save.army_training.clear()
	assert_str(sheet.spot_at(at)).is_not_equal(&"trainee:field_associate")  # Nobody training: nothing to hover.



func test_a_unit_hired_while_the_sheet_lies_open_shows_its_figure_with_its_column() -> void:
	var sheet := _sheet()
	assert_bool((sheet.get_node("Things/senior_asset") as Node3D).visible).is_false()
	SaveManager.save.stamped.append("unit_senior")
	sheet.refresh()
	assert_bool(sheet._columns["senior_asset"].visible).is_true()
	assert_bool((sheet.get_node("Things/senior_asset") as Node3D).visible).is_true()


func test_a_training_node_bought_mid_training_keeps_the_trainees_bar_where_it_was() -> void:
	var save := SaveManager.save
	assert_bool(WarRules.buy(save, "field_associate")).is_true()
	save.army_training[0].left = WarRules.training_seconds(save, "field_associate") / 2.0
	save.tree_bought.append("war_training_1")
	assert_array(DepotSheet.training_of(save, "field_associate")).is_equal([0.5])
