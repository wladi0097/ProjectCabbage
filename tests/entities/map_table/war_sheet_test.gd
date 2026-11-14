extends GdUnitTestSuite

const WarSheet := preload("res://entities/map_table/war_sheet.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")
const DESK := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))
const FA := "field_associate"

var _real_save: SaveGame
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = _at_war()
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	FarmTv.away = false


func after_test() -> void:
	FarmRegister.lamp_held = false
	BossReport.hold = 0.0
	FarmTv.away = false
	SaveManager.save = _real_save
	TranslationServer.set_locale(_locale)


## Five home farms and the war card: the figures for a war are handed over by its declaration.
func _at_war() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation", "negotiation", "bribery", "war_mode"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	save.coin_limit = 100000000
	save.coins = 50000000
	return save


## The war sheet on its own, its war on `farm` begun with `chosen`.
func _sheet(chosen := {field_associate = 3}, farm := &"K-6") -> WarSheet:
	var sheet: WarSheet = auto_free(load("res://entities/map_table/war_sheet.tscn").instantiate())
	add_child(sheet)
	sheet.open = 1.0
	sheet.begin(farm, chosen)
	return sheet


## The map table, at war on K-6 with `chosen` (as the declaration rolls the war sheet out).
func _table_at_war(chosen := {field_associate = 3}) -> MapTable:
	var camera := Camera3D.new()
	camera.transform = DESK
	add_child(auto_free(camera))
	camera.make_current()
	var table: MapTable = auto_free(load("res://entities/map_table/map_table.tscn").instantiate())
	add_child(table)
	table.show_sheet(&"war", &"K-6", chosen)
	for i in 4:
		if table.swapping:
			table._swap_tween.custom_step(10.0)
	return table


func _text(sheet: WarSheet, label: String) -> String:
	return (sheet.get_node("Page/Sheet/" + label) as Label).text


## Plays `sheet`'s fight for `seconds`, then lets the sheet see how it stands.
func _fight_for(sheet: WarSheet, seconds: float) -> void:
	sheet.fight.tick(seconds)
	sheet._process(0.0)


func test_a_war_won_takes_that_one_farm_and_costs_nothing_more() -> void:
	var save := _at_war()
	assert_bool(WarSheet.win(save, &"K-7")).is_true()
	assert_array(Array(save.farms_owned)).is_equal(["K-1", "K-2", "K-3", "K-4", "K-5", "K-7"])
	assert_int(save.coins).is_equal(50000000)
	assert_bool(WarSheet.win(save, &"K-7")).is_false()  # Once.


func test_the_figures_taken_stand_in_the_tray_with_their_count_and_stats() -> void:
	var sheet := _sheet()
	assert_str(_text(sheet, "Farm")).contains("K-6")
	assert_bool((sheet.get_node("Page/Sheet/Row0") as Control).visible).is_true()
	assert_bool((sheet.get_node("Page/Sheet/Row1") as Control).visible).is_false()  # One unit type taken.
	assert_str((sheet.get_node("Page/Sheet/Row0/Name") as Label).text).is_equal("FIELD ASSOCIATE")
	assert_str((sheet.get_node("Page/Sheet/Row0/Count") as Label).text).is_equal("x 3")
	var stats := (sheet.get_node("Page/Sheet/Row0/Stats") as Label).text
	assert_str(stats).contains("HP 150").contains("DAMAGE 25").contains("SPEED 1.2").contains("TARGET: DEFENCES")
	assert_int(sheet.get_node("Field/Tray").get_child_count()).is_equal(3)
	assert_str(_text(sheet, "Clock")).is_equal("1:30")
	assert_bool(sheet.busy()).is_true()  # The table does not roll it up under the war.


func test_declaring_war_puts_the_way_out_and_the_currency_column_away_until_the_war_ends() -> void:
	SaveManager.save.stamped.append_array(["map_readout", "farm_shortcut"])
	var table := _table_at_war()
	var war := table.sheet_of(&"war") as WarSheet
	for i in 30:
		await get_tree().process_frame
	for exit: String in ["DeskButton", "FarmButton", "Tally"]:
		assert_float((table.get_node(exit) as Node3D).scale.x).override_failure_message(exit).is_less(0.01)
	assert_bool(table.sheet_of(table.held()).visible).is_false()  # The country's roll in the holder lifted away.
	war.place(FA, 0)
	war.start_fight()
	_fight_for(war, 200.0)
	war._dealing.custom_step(10.0)
	for exit: String in ["DeskButton", "FarmButton", "Tally"]:
		assert_float((table.get_node(exit) as Node3D).scale.x).override_failure_message(exit).is_equal(1.0)


func test_while_the_war_is_on_the_sheet_takes_the_mouse_and_esc_leads_nowhere() -> void:
	var table := _table_at_war()
	var war := table.sheet_of(&"war") as WarSheet
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	assert_bool(war._taking()).is_true()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	war._input(esc)
	assert_bool(war.get_viewport().is_input_handled()).is_true()  # The table never hears it.


func test_a_figure_dropped_on_a_landing_spot_is_placed_and_anywhere_else_goes_back() -> void:
	var sheet := _sheet()
	assert_bool(sheet.pick_up(FA)).is_true()
	assert_bool(sheet.drop(-1)).is_false()
	assert_int(sheet.tray[FA]).is_equal(3)
	assert_int(sheet.fight.units.size()).is_equal(0)
	assert_bool(sheet.place(FA, 2)).is_true()
	assert_int(sheet.tray[FA]).is_equal(2)
	assert_int(sheet.fight.units.size()).is_equal(1)
	assert_int(sheet.get_node("Field/Tray").get_child_count()).is_equal(2)
	assert_str((sheet.get_node("Page/Sheet/Row0/Count") as Label).text).is_equal("x 2")


func test_the_landing_spots_glow_while_a_figure_is_held() -> void:
	var sheet := _sheet()
	var spot: MeshInstance3D = sheet._map.landings()[0].get_node("Mesh")
	sheet._process(0.0)
	assert_object(spot.material_overlay).is_null()
	sheet.pick_up(FA)
	sheet._process(0.0)
	assert_object(spot.material_overlay).is_not_null()
	# The mouse over a landing spot, with the figure held: that is where it lands.
	var centre := sheet.landing_rect(1).get_center()
	assert_str(sheet.spot_under(centre)).is_equal(&"landing1")
	sheet.drop(1)
	sheet._process(0.0)
	assert_object(spot.material_overlay).is_null()


func test_placing_after_start_is_refused_without_tactics() -> void:
	var sheet := _sheet()
	assert_bool(sheet.start_fight()).is_false()  # Nobody placed yet.
	sheet.place(FA, 0)
	assert_bool(sheet.start_fight()).is_true()
	assert_bool(sheet.can_place()).is_false()
	assert_bool(sheet.place(FA, 0)).is_false()
	assert_int(sheet.tray[FA]).is_equal(2)
	assert_str(_text(sheet, "Start")).is_equal("ENGAGED")


func test_with_tactics_figures_may_still_be_placed_after_start() -> void:
	SaveManager.save.stamped.append("tactics")
	var sheet := _sheet()
	sheet.place(FA, 0)
	sheet.start_fight()
	assert_bool(sheet.place(FA, 1)).is_true()
	assert_int(sheet.fight.units.size()).is_equal(2)


func test_survivors_of_a_won_war_go_back_into_the_army_and_the_farm_is_ours() -> void:
	SaveManager.save.army = {field_associate = 0}
	var sheet := _sheet({field_associate = 4})
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	for i in 3:
		sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	assert_int(sheet.fight.state).is_equal(WarFight.State.WON)
	var survivors: int = sheet.fight.survivors().get(FA, 0)
	assert_int(survivors).is_greater(0)
	assert_int(SaveManager.save.army[FA]).is_equal(survivors + 1)  # And the one never placed.
	assert_bool(SaveManager.save.farms_owned.has("K-6")).is_true()
	assert_str(_text(sheet, "Imprint")).is_equal("VICTORY")
	assert_bool(FarmRegister.lamp_held).is_true()  # The Field Line waits for the farm's moment.
	assert_array(wanted).is_empty()
	sheet._dealing.custom_step(WarSheet.LEAVE_AFTER + 0.01)
	assert_array(wanted).is_equal([[WorldRegister.HOME, &"K-6"]])
	assert_bool(sheet.busy()).is_false()


func test_a_lost_war_leaves_the_farm_unowned_and_the_placed_figures_gone() -> void:
	var sheet := _sheet({field_associate = 3})
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	assert_int(sheet.fight.state).is_equal(WarFight.State.LOST)
	assert_int(SaveManager.save.army[FA]).is_equal(2)  # Only the two never placed.
	assert_bool(SaveManager.save.farms_owned.has("K-6")).is_false()
	assert_str(_text(sheet, "Imprint")).is_equal("ACQUISITION UNSUCCESSFUL")
	assert_bool(FarmRegister.lamp_held).is_false()
	sheet._dealing.custom_step(WarSheet.LOST_AFTER + 0.01)
	assert_array(wanted).is_equal([[WorldRegister.HOME, &"K-6"]])  # Back to the country, nothing taken.


func test_a_retreat_brings_its_share_of_the_figures_placed_home() -> void:
	SaveManager.save.stamped.append("retreat")
	var sheet := _sheet({field_associate = 5})
	for i in 4:
		sheet.place(FA, 1)
	sheet.start_fight()
	_fight_for(sheet, 0.5)
	assert_bool(sheet.call_retreat()).is_true()
	sheet._process(0.0)
	assert_int(SaveManager.save.army[FA]).is_equal(1 + 1)  # floor(4 * 30%), and the one never placed.
	assert_str(_text(sheet, "Imprint")).is_equal("WITHDRAWN")
	assert_bool(SaveManager.save.farms_owned.has("K-6")).is_false()


func test_retreat_is_not_authorised_without_its_card() -> void:
	var sheet := _sheet()
	sheet.place(FA, 0)
	sheet.start_fight()
	assert_bool(sheet.can_retreat()).is_false()
	assert_bool(sheet.call_retreat()).is_false()
	assert_str(_text(sheet, "RetreatNote")).is_equal("Not authorised.")
	assert_str(sheet.spot_under(WarSheet.RETREAT_BOX.get_center())).is_equal(&"")


func test_a_war_declared_without_figures_has_no_fight_and_the_way_back_stays() -> void:
	var sheet := _sheet({})
	assert_object(sheet.fight).is_null()
	assert_bool(sheet.busy()).is_false()


func test_the_war_sheet_is_german_in_german_and_never_says_units() -> void:
	TranslationServer.set_locale("de")
	var sheet := _sheet()
	assert_str((sheet.get_node("Page/Sheet/Row0/Stats") as Label).text).not_contains("units")
	for key: String in ["PERSONNEL IN THEATRE", "ENGAGEMENT CONTROL", "TIME REMAINING", "START", "ENGAGED", "RETREAT",
			"ACQUISITION UNSUCCESSFUL", "WITHDRAWN", "VICTORY", "FIELD ASSOCIATE", "HP %d  ·  DAMAGE %d  ·  SPEED %s",
			"TARGET: %s", "DEFENCES", "Not authorised.", "%d%% of staff placed return", "Overtime is not authorised.",
			"Commits all staff placed. No refunds.", "THEATRE OF OPERATIONS - FARM SITE"]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
