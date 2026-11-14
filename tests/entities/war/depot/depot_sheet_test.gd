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


func test_the_grey_trainees_line_follows_its_training_and_the_rest_of_the_queue_is_a_count() -> void:
	var sheet := _sheet()
	for i in 3:
		sheet.requisition("field_associate")
	var save := SaveManager.save
	save.army_training[0].left = WarRules.training_seconds(save, "field_associate") / 2.0
	sheet._process(0.0)
	var column: Control = sheet._columns["field_associate"]
	var line := column.get_node("Line") as Control
	assert_float((line.get_node("Fill") as Control).size.x).is_equal_approx(line.size.x / 2.0, 0.5)
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


func test_a_loaded_save_shows_its_trainee_in_place_without_a_landing() -> void:
	WarRules.buy(SaveManager.save, "field_associate")
	var sheet := _sheet()
	var trainee := sheet.get_node("Things/trainee_field_associate") as Node3D
	assert_bool(trainee.visible).is_true()
	assert_bool(sheet._landing.has("field_associate")).is_false()
	var column: Control = sheet._columns["field_associate"]
	var at: Vector2 = column.position + (column.get_node("Trainee") as Control).position
	assert_vector(sheet.pixel_at(trainee.global_position)).is_equal_approx(at, Vector2.ONE * 0.5)


## Moves the map table's mouse (as it hands it on) onto research node `node_id` of `unit`'s tree,
## or off every tree (`node_id` "").
func _mouse_on_node(sheet: DepotSheet, node_id: String, unit := "field_associate") -> void:
	var tree := sheet._columns[unit].get_node("Tree") as UpgradeTree
	var wheel: Array = tree._wheel()
	var at: Vector2 = sheet._art_rect(tree).position + wheel[0] + DepotResearch.node_data(node_id).at * wheel[1] if node_id != "" else Vector2(3000, 100)
	sheet.take_mouse(InputEventMouseMotion.new(), at)
	# The page's GUI takes pushed input on its next frame: what the tree then sees, set directly.
	tree._process(0.0)  # Lays the tree out (which nodes show).
	tree._hover(at - sheet._art_rect(tree).position if node_id != "" else UpgradeTree.OFF)


func test_hovering_a_research_node_names_it_in_the_hint_slip_and_leaving_drops_it() -> void:
	var sheet := _sheet()
	var tree := sheet._columns["field_associate"].get_node("Tree") as UpgradeTree
	assert_bool(tree.popup_shown).is_false()  # Nothing drawn on the paper: the slip says it.
	_mouse_on_node(sheet, "fa_hp_1")
	assert_str(sheet.hovered_spot()).is_equal(&"research:fa_hp_1")
	var slip := sheet.hint(sheet.hovered_spot())
	assert_str(slip).contains("BODY ARMOUR")
	assert_str(slip).contains("30% more damage")
	assert_str(slip).contains("Cost: ¶%s." % FarmScreen._thousands(DepotResearch.price_of("fa_hp_1", SaveManager.save)))
	_mouse_on_node(sheet, "")
	assert_str(sheet.hovered_spot()).is_equal(&"")


func test_the_hint_for_a_research_node_says_what_it_waits_for_or_that_it_is_approved() -> void:
	var save := SaveManager.save
	assert_str(DepotSheet.research_hint(save, "fa_damage_1")).contains("Needs BODY ARMOUR first.")
	save.unit_research.append("fa_hp_1")
	assert_str(DepotSheet.research_hint(save, "fa_hp_1")).ends_with("Approved.")


func test_short_of_cabbages_the_requisition_box_says_so() -> void:
	SaveManager.save.stock = 0
	var sheet := _sheet()
	assert_str((sheet._columns["field_associate"].get_node("Note") as Label).text).is_equal("NOT ENOUGH CABBAGES")


func test_the_sheet_shows_only_hired_unit_types_the_depot_deals_in() -> void:
	SaveManager.save.stamped.append_array(["unit_compliance", "unit_senior", "unit_pult"])
	var sheet := _sheet()
	assert_array(sheet._columns.keys()).is_equal(["field_associate"])
	assert_bool(sheet._columns["field_associate"].visible).is_true()
	assert_bool((sheet.get_node("Things/field_associate") as Node3D).visible).is_true()


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
	var tree := sheet._columns["field_associate"].get_node("Tree") as UpgradeTree
	assert_object(tree.rules).is_equal(DepotResearch)
	var findings := SaveManager.save.findings
	assert_bool(DepotResearch.can_hold("fa_damage_1", SaveManager.save)).is_false()  # Its parent first.
	tree._holding = "fa_hp_1"
	tree._process(UpgradeTree.HOLD_TIME + 0.01)
	assert_bool(SaveManager.save.unit_research.has("fa_hp_1")).is_true()
	assert_int(SaveManager.save.findings).is_equal(findings - DepotResearch.price_of("fa_hp_1", SaveManager.save))
	assert_bool((sheet.get_node("Research") as SoundCue).playing).is_true()
	assert_bool(DepotResearch.can_hold("fa_damage_1", SaveManager.save)).is_true()


func test_the_research_tree_holds_every_field_associate_node_and_only_those() -> void:
	var ids := DepotResearch.NODES.map(func(node: Dictionary) -> String: return node.id)
	for node in WarRules.RESEARCH:
		assert_bool(ids.has(node.id)).override_failure_message(node.id).is_equal(node.unit == "field_associate")
	for node: Dictionary in DepotResearch.NODES:
		assert_str(node.parent).is_equal(WarRules.research_node(node.id).parent)


func test_short_of_findings_a_research_node_cannot_be_bought() -> void:
	SaveManager.save.findings = 0
	assert_bool(DepotResearch.buy("fa_hp_1", SaveManager.save)).is_false()
	assert_bool(SaveManager.save.unit_research.is_empty()).is_true()


func test_the_column_starts_top_left_and_the_title_block_bottom_right_carries_the_form_and_headcount() -> void:
	var sheet := _sheet()
	var column := sheet._columns["field_associate"]
	assert_float(column.position.x).is_equal(DepotSheet.COLUMN_LEFT)
	assert_float(DepotSheet.COLUMN_LEFT).is_less(200.0)  # A paper margin, not a gap.
	assert_float(column.position.y).is_less(200.0)  # Nothing above the column.
	for part: String in ["Title", "FormLine", "Staff", "StaffNote"]:
		var label := sheet.get_node("Page/Sheet/" + part) as Control
		assert_bool(Rect2(2290, 1360, 800, 330).encloses(Rect2(label.position, label.size))).override_failure_message(part).is_true()


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
	assert_str((price.get_node("Amount") as Label).text).is_equal(FarmScreen._thousands(WarRules.unit_cabbage_price("field_associate")))
