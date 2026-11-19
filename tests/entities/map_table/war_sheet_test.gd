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
	WarSheet.at_war = false  # A sheet never added to the tree ends no war on its own.
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


## The figure of the sheet not in the fight yet, number k.
func _figure(sheet: WarSheet, k := 0) -> Node3D:
	return sheet.figures()[k]


## Art pixel of cell-space point `p` on the map.
func _at(p: Vector2) -> Vector2:
	return WarSheet.pixel_of_cell(p)


## The after-action report slides in after the end's stamp and its grade lands.
func _report_in(sheet: WarSheet, wait: float) -> WarReport:
	sheet._dealing.custom_step(wait + 0.01)
	var report: WarReport = sheet.get_node("Report")
	report._moving.custom_step(10.0)
	return report


## The report is filed and the sheet leaves.
func _filed(sheet: WarSheet) -> void:
	assert_bool(sheet.file_report()).is_true()
	sheet._dealing.custom_step(WarReport.SLIDE_TIME + 0.01)


func _settled() -> void:
	await get_tree().create_timer(WarSheet.SETTLE_TIME + 0.05).timeout


func test_a_war_won_takes_that_one_farm_and_costs_nothing_more() -> void:
	var save := _at_war()
	assert_bool(WarSheet.win(save, &"K-7")).is_true()
	assert_array(Array(save.farms_owned)).is_equal(["K-1", "K-2", "K-3", "K-4", "K-5", "K-7"])
	assert_int(save.coins).is_equal(50000000)
	assert_bool(WarSheet.win(save, &"K-7")).is_false()  # Once.


func test_the_figures_taken_stand_on_the_desk_left_of_the_sheet_and_the_paper_has_no_lettering_but_its_title_block() -> void:
	var sheet := _sheet()
	assert_int(sheet.figures().size()).is_equal(3)
	for holder in sheet.figures():
		assert_bool(sheet.on_desk(holder)).is_true()
		assert_float(WarSheet.pixel_of(holder.position).x).is_less(0.0)  # Left of the paper.
	var words := sheet.get_node("Page/Sheet").find_children("*", "Label", true, false) \
			.filter(func(l: Label) -> bool: return l.is_visible_in_tree() and not sheet.get_node("Page/Sheet/TitleBlock").is_ancestor_of(l))
	assert_array(words).is_empty()  # The whole sheet is the battlefield.
	assert_bool(sheet.busy()).is_true()  # The table does not roll it up under the war.


func test_the_home_wars_fight_on_their_maps_in_order_and_a_war_without_one_on_the_test_map() -> void:
	assert_str(_sheet({field_associate = 1}, &"K-7")._map.scene_file_path).is_equal("res://entities/war/maps/K-6.tscn")  # The first, whichever farm.
	_owning(6)
	assert_str(_sheet({field_associate = 1}, &"K-8")._map.scene_file_path).is_equal("res://entities/war/maps/K-7.tscn")
	var sheet := _sheet({field_associate = 1}, &"K-8")
	_owning(0)
	sheet.begin(&"K-8", {field_associate = 1})  # The same sheet, a war with no map of its own (K-1's).
	assert_str(sheet._map.scene_file_path).is_equal("res://entities/war/maps/test_map.tscn")
	assert_int(sheet.get_node("Things/Board").get_child_count()).is_equal(1)


func test_a_war_on_another_farms_map_starts_without_the_last_wars_figures() -> void:
	var sheet := _sheet({field_associate = 1}, &"K-7")
	sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	sheet.begin(&"K-8", {field_associate = 1})
	assert_array(sheet._view.units).is_empty()
	assert_int(sheet.figures().size()).is_equal(1)


func test_the_printed_grid_and_the_fight_grid_share_their_origin_and_cell() -> void:
	var sheet := _sheet()
	assert_vector(WarSheet.pixel_of(sheet._board.position)).is_equal_approx(WarSheet.GRID_AT, Vector2.ONE * 0.01)
	assert_vector(WarSheet.pixel_of_cell(Vector2(20, 11))).is_equal_approx(WarSheet.GRID_AT + Vector2(3200, 1760), Vector2.ONE * 0.01)
	var svg := FileAccess.get_file_as_string("res://assets/sprites/maps/war_map.svg")
	assert_str(svg).contains("M0 20V1780").contains("M160 20V1780").contains("M0 20H3200")  # Heavy lines on the cells.


func test_declaring_war_puts_the_way_out_and_the_currency_column_away_until_the_war_ends() -> void:
	SaveManager.save.stamped.append_array(["map_readout", "farm_shortcut"])
	var table := _table_at_war()
	var war := table.sheet_of(&"war") as WarSheet
	for i in 30:
		await get_tree().process_frame
	for exit: String in ["DeskButton", "FarmButton", "Tally"]:
		assert_float((table.get_node(exit) as Node3D).scale.x).override_failure_message(exit).is_less(0.01)
	assert_bool(table.sheet_of(table.held()).visible).is_false()  # The country's roll in the holder lifted away.
	assert_bool((war.get_node("Control") as Node3D).visible).is_true()  # The control box stands beside the sheet.
	war.place(FA, 0)
	war.start_fight()
	_fight_for(war, 200.0)
	_report_in(war, 10.0)
	_filed(war)
	for exit: String in ["DeskButton", "FarmButton", "Tally"]:
		assert_float((table.get_node(exit) as Node3D).scale.x).override_failure_message(exit).is_equal(1.0)
	assert_bool((war.get_node("Control") as Node3D).visible).is_false()


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


func test_a_figure_set_down_in_a_zone_stands_right_there() -> void:
	var sheet := _sheet()  # K-6: one zone, cells (0, 2) to (3, 9).
	var holder := _figure(sheet)
	assert_bool(sheet.move(holder, _at(Vector2(1.3, 4.6)))).is_true()
	await _settled()
	assert_bool(sheet.in_zone(holder)).is_true()
	assert_vector(WarSheet.cell_at(WarSheet.pixel_of(holder.position))).is_equal_approx(Vector2(1.3, 4.6), Vector2.ONE * 0.001)
	assert_int(sheet.fight.units.size()).is_equal(0)  # Not in the fight before START: it can still move.


func test_a_figure_set_down_near_a_zone_slides_into_it() -> void:
	var sheet := _sheet()
	var holder := _figure(sheet)
	assert_bool(sheet.move(holder, _at(Vector2(3.7, 5.0)))).is_true()  # 0.7 cells right of the zone.
	await _settled()
	assert_bool(sheet.in_zone(holder)).is_true()


func test_a_figure_set_down_off_the_zones_on_the_paper_stands_there_and_start_is_refused() -> void:
	var sheet := _sheet()
	sheet.place(FA, 0)
	var holder := _figure(sheet, 0)
	if sheet.in_zone(holder):
		holder = _figure(sheet, 1)
	assert_bool(sheet.move(holder, _at(Vector2(6.0, 1.0)))).is_false()
	await _settled()
	assert_bool(sheet.on_desk(holder)).is_false()
	assert_int(sheet.strays()).is_equal(1)
	assert_bool(sheet.can_start()).is_false()
	assert_str(sheet.hint(WarSheet.START)).contains("hatched zones")
	assert_bool(sheet.start_fight()).is_false()
	sheet.move(holder, Vector2(-200.0, 900.0))  # Back onto the desk: that is fine.
	await _settled()
	assert_bool(sheet.on_desk(holder)).is_true()
	assert_bool(sheet.can_start()).is_true()
	assert_bool(sheet.start_fight()).is_true()
	assert_int(sheet.fight.units.size()).is_equal(1)  # Only the one in the zone fights.
	assert_int(sheet.left()).is_equal(2)


func test_start_needs_a_figure_in_a_zone_and_is_shut_once_started() -> void:
	var sheet := _sheet()
	assert_bool(sheet.can_start()).is_false()  # Nobody in a zone yet.
	assert_str(sheet.hint(WarSheet.START)).is_equal("Set staff down in a hatched zone first.")
	assert_bool(sheet.start_fight()).is_false()
	sheet.place(FA, 0)
	assert_bool(sheet.start_fight()).is_true()
	assert_bool(sheet.can_start()).is_false()
	assert_bool(sheet.can_place()).is_false()
	assert_bool(sheet.place(FA, 0)).is_false()
	assert_bool(sheet.pick_up(_figure(sheet))).is_false()
	assert_int(sheet.left()).is_equal(2)


func test_figures_can_be_picked_up_again_and_moved_before_start() -> void:
	var sheet := _sheet()
	var holder := _figure(sheet)
	sheet.move(holder, _at(Vector2(1.5, 3.0)))
	assert_bool(sheet.move(holder, Vector2(-200.0, 700.0))).is_false()  # Back to the desk.
	await _settled()
	assert_bool(sheet.on_desk(holder)).is_true()
	assert_bool(sheet.can_start()).is_false()


func test_the_zones_glow_while_a_figure_is_held() -> void:
	var sheet := _sheet()
	var zone: GeometryInstance3D = sheet._map.zones()[0].get_node("Mesh")
	sheet._process(0.0)
	assert_float(zone.get_instance_shader_parameter(&"glow")).is_equal(0.0)
	sheet.pick_up(_figure(sheet))
	sheet._mouse_pixel = _at(Vector2(10.0, 1.0))
	sheet._process(0.0)
	assert_float(zone.get_instance_shader_parameter(&"glow")).is_equal(WarSheet.GLOW)
	sheet._mouse_pixel = _at(Vector2(1.0, 5.0))  # Over it: it would land there.
	sheet._process(0.0)
	assert_float(zone.get_instance_shader_parameter(&"glow")).is_equal(WarSheet.GLOW_HOT)
	sheet.drop(sheet._mouse_pixel)
	sheet._process(0.0)
	assert_float(zone.get_instance_shader_parameter(&"glow")).is_equal(0.0)


func test_with_tactics_figures_set_down_in_a_zone_after_start_join_the_fight_at_once() -> void:
	SaveManager.save.stamped.append("tactics")
	var sheet := _sheet()
	sheet.place(FA, 0)
	sheet.start_fight()
	assert_bool(sheet.move(_figure(sheet), _at(Vector2(6.0, 1.0)))).is_false()  # Off the zones: refused.
	assert_bool(sheet.place(FA, 0)).is_true()
	assert_int(sheet.fight.units.size()).is_equal(2)


func test_the_control_box_shows_the_clock_and_start_only_while_the_war_may_start() -> void:
	var sheet := _sheet()
	var control: WarControl = sheet.get_node("Control")
	sheet._process(0.0)
	assert_float(control.seconds_left).is_equal(WarRules.fight_seconds(SaveManager.save))
	assert_bool(control.start_enabled).is_false()
	sheet.place(FA, 0)
	sheet._process(0.0)
	assert_bool(control.start_enabled).is_true()
	assert_int(control.state).is_equal(WarControl.State.READY)
	sheet.start_fight()
	_fight_for(sheet, 1.0)
	assert_int(control.state).is_equal(WarControl.State.RUNNING)
	assert_float(control.seconds_left).is_equal_approx(WarRules.fight_seconds(SaveManager.save) - 1.0, 0.01)
	assert_bool(control.flee_allowed).is_false()  # No RETREAT card: ABORT is dead in the fight.


func test_abort_before_start_gives_every_figure_and_the_wars_coins_back() -> void:
	var save := SaveManager.save
	save.army = {field_associate = 4}
	var coins := save.coins
	var sheet := _sheet()  # (Made before the declaration, as the game makes it at load.)
	assert_bool(FarmRegister.declare(save, &"K-6", {field_associate = 3})).is_true()
	assert_int(save.coins).is_less(coins)
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	sheet.place(FA, 0)
	assert_bool(sheet.abort()).is_true()
	assert_int(save.coins).is_equal(coins)
	assert_dict(save.army).is_equal({field_associate = 4})
	assert_dict(save.war_pending).is_empty()
	assert_bool(save.farms_owned.has("K-6")).is_false()
	assert_array(wanted).is_equal([[WorldRegister.HOME, &"K-6"]])
	assert_bool(sheet.busy()).is_false()


func test_no_report_after_an_abort_before_start() -> void:
	var save := SaveManager.save
	save.army = {field_associate = 3}
	var sheet := _sheet()
	FarmRegister.declare(save, &"K-6", {field_associate = 3})
	sheet.place(FA, 0)
	sheet.abort()
	assert_bool((sheet.get_node("Report") as WarReport).visible).is_false()
	assert_bool(sheet.file_report()).is_false()
	assert_dict(save.war_grades).is_empty()


func test_a_song_starts_with_start_and_never_the_same_one_twice_in_a_row() -> void:
	var sheet := _sheet()
	var music: AudioStreamPlayer = sheet.get_node("Music")
	assert_bool(music.playing).is_false()  # Planning is quiet.
	sheet.place(FA, 0)
	sheet.start_fight()
	assert_bool(music.playing).is_true()
	assert_str(music.bus).is_equal("WarMusic")  # Not ducked with the desk's music.
	var songs := music.stream as AudioStreamRandomizer
	assert_int(songs.streams_count).is_equal(3)
	assert_int(songs.playback_mode).is_equal(AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS)


func test_the_song_fades_out_when_the_fight_ends() -> void:
	var sheet := _sheet()
	var music: AudioStreamPlayer = sheet.get_node("Music")
	sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	sheet._music_fade.custom_step(WarSheet.MUSIC_FADE + 0.01)
	assert_bool(music.playing).is_false()


func test_the_report_is_filed_only_once_its_grade_is_on_it_and_the_grade_is_kept() -> void:
	var sheet := _sheet({field_associate = 2})
	for i in 2:
		sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	assert_bool(sheet.file_report()).is_false()  # Only the end's stamp so far.
	sheet._dealing.custom_step(WarSheet.LEAVE_AFTER + 0.01)
	assert_bool(sheet.file_report()).is_false()  # Sliding in, no grade yet.
	var report: WarReport = sheet.get_node("Report")
	report._moving.custom_step(10.0)
	assert_bool((report.get_node("Page/Form/Grade") as Control).visible).is_true()
	var grade: String = SaveManager.save.war_grades[&"K-6"]
	assert_str((report.get_node("Page/Form/Grade/Word") as Label).text).is_equal(grade)
	assert_bool(sheet.file_report()).is_true()
	assert_bool(sheet.file_report()).is_false()  # Once.


func test_quitting_before_start_brings_every_figure_taken_and_the_wars_coins_back() -> void:
	var save := SaveManager.save
	save.army = {field_associate = 3}
	var sheet := _sheet()
	var coins := save.coins
	FarmRegister.declare(save, &"K-6", {field_associate = 3})
	assert_int(save.coins).is_less(coins)
	assert_dict(save.war_pending).is_equal({field_associate = 3})
	sheet.place(FA, 0)
	sheet.free()  # The game closes.
	_sheet({})  # It loads again: the war sheet is made with no war on.
	assert_dict(save.army).is_equal({field_associate = 3})
	assert_dict(save.war_pending).is_empty()
	assert_int(save.coins).is_equal(coins)  # The war never started: its coins come back too, as ABORT gives them.


func test_quitting_after_start_brings_back_only_the_figures_never_placed() -> void:
	var save := SaveManager.save
	save.army = {field_associate = 3}
	var sheet := _sheet()
	FarmRegister.declare(save, &"K-6", {field_associate = 3})
	sheet.place(FA, 0)
	sheet.start_fight()
	var coins := save.coins
	assert_dict(save.war_pending).is_equal({field_associate = 2})  # The one placed is committed.
	save.return_war_pending()  # The game closed and loads again.
	assert_dict(save.army).is_equal({field_associate = 2})
	assert_int(save.coins).is_equal(coins)  # Started: the war's coins stay spent.


func test_survivors_of_a_won_war_go_back_into_the_army_and_the_farm_is_ours() -> void:
	SaveManager.save.army = {field_associate = 0}
	var sheet := _sheet({field_associate = 4})
	SaveManager.save.war_pending = {field_associate = 4}
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
	assert_dict(SaveManager.save.war_pending).is_empty()
	assert_bool(SaveManager.save.farms_owned.has("K-6")).is_true()
	assert_bool((sheet.get_node("Page/Sheet/Imprint") as Label).visible).is_false()  # No victory stamp on the paper.
	assert_int(SaveManager.save.wars_won).is_equal(1)  # Counted for the memos.
	assert_bool(FarmRegister.lamp_held).is_true()  # The Field Line waits for the farm's moment.
	assert_array(wanted).is_empty()
	var report := _report_in(sheet, WarSheet.LEAVE_AFTER)
	assert_bool(report.visible).is_true()
	assert_array(wanted).is_empty()  # The report waits to be filed.
	_filed(sheet)
	assert_array(wanted).is_equal([[WorldRegister.HOME, &"K-6"]])  # The farm's moment on its country's sheet.
	assert_bool(sheet.busy()).is_false()
	assert_bool(report.visible).is_false()


func test_the_tutorial_farm_falls_once_its_fence_is_broken() -> void:
	var sheet := _sheet({field_associate = 2})
	for i in 2:
		sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	assert_int(sheet.fight.state).is_equal(WarFight.State.WON)
	var walls := sheet.fight.buildings.filter(func(b: Dictionary) -> bool: return b.kind == "wall_wood")
	assert_bool(walls.any(func(b: Dictionary) -> bool: return not b.alive)).is_true()  # They broke through.


func test_a_lost_war_leaves_the_farm_unowned_and_the_placed_figures_gone() -> void:
	_owning(6)  # The second war at home: K-7's map, its tower.
	var sheet := _sheet({field_associate = 3}, &"K-7")
	var wanted := []
	sheet.sheet_wanted.connect(func(id: StringName, farm: StringName) -> void: wanted.append([id, farm]))
	sheet.place(FA, 0)
	sheet.start_fight()
	_fight_for(sheet, WarRules.fight_seconds(SaveManager.save))
	assert_int(sheet.fight.state).is_equal(WarFight.State.LOST)
	assert_int(SaveManager.save.army[FA]).is_equal(2)  # Only the two never placed.
	assert_bool(SaveManager.save.farms_owned.has("K-7")).is_false()
	assert_bool((sheet.get_node("Page/Sheet/Imprint") as Label).visible).is_false()  # No stamp on the paper: the report says it.
	assert_bool(FarmRegister.lamp_held).is_false()
	_report_in(sheet, WarSheet.LOST_AFTER)
	assert_array(wanted).is_empty()
	_filed(sheet)
	assert_array(wanted).is_equal([[WorldRegister.HOME, &"K-7"]])  # Back to the country, nothing taken.


func test_a_retreat_brings_its_share_of_the_figures_placed_home() -> void:
	_owning(0)  # A war with no map of its own (K-1's): the test map, three zones.
	SaveManager.save.stamped.append("retreat")
	var sheet := _sheet({field_associate = 5}, &"K-8")
	for i in 4:
		sheet.place(FA, 1)
	sheet.start_fight()
	_fight_for(sheet, 0.5)
	assert_bool(sheet.can_abort()).is_true()  # ABORT is the flee now.
	assert_bool(sheet.abort()).is_true()
	sheet._process(0.0)
	assert_int(SaveManager.save.army[FA]).is_equal(1 + 1)  # floor(4 * 30%), and the one never placed.
	assert_str(_text(sheet, "Imprint")).is_equal("WITHDRAWN")
	assert_str(SaveManager.save.war_grades[&"K-8"]).is_equal(WarReport.REGRETTABLE)
	assert_int(SaveManager.save.wars_lost).is_equal(1)
	assert_int(SaveManager.save.quick_retreats).is_equal(1)  # Half a second in: a quick one.
	var report := _report_in(sheet, WarSheet.LOST_AFTER)
	assert_str((report.get_node("Page/Form/Staff/field_associate/Lost") as Label).text).is_equal("3")  # 4 placed, 1 home.
	assert_bool(SaveManager.save.farms_owned.has("K-8")).is_false()


func test_abort_is_dead_in_the_fight_without_the_retreat_card() -> void:
	var sheet := _sheet()
	sheet.place(FA, 0)
	sheet.start_fight()
	assert_bool(sheet.can_retreat()).is_false()
	assert_bool(sheet.can_abort()).is_false()
	assert_bool(sheet.abort()).is_false()
	assert_int(sheet.fight.state).is_equal(WarFight.State.RUNNING)
	assert_str(sheet.hint(WarSheet.ABORT)).is_equal("Not authorised.")


func test_a_war_declared_without_figures_has_no_fight_and_the_way_back_stays() -> void:
	var sheet := _sheet({})
	assert_object(sheet.fight).is_null()
	assert_bool(sheet.busy()).is_false()


func test_the_war_sheet_is_german_in_german() -> void:
	TranslationServer.set_locale("de")
	for key: String in ["ACQUISITION UNSUCCESSFUL", "WITHDRAWN", "VICTORY", "Not authorised.", "%d%% of staff placed return",
			"Staff are standing outside the hatched zones. Move them in, or back onto the desk.",
			"Set staff down in a hatched zone first.", "Commence the engagement. Staff placed are committed.",
			"Call it off. Staff and the war's fee are refunded."]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)


## A save owning the first `owned` home farms, at war: the next war at home is on map K-(owned + 1).
func _owning(owned: int) -> SaveGame:
	var save := _at_war()
	save.farms_owned = PackedStringArray()
	for k in owned:
		save.farms_owned.append("K-%d" % (k + 1))
	SaveManager.save = save
	return save


func _title(sheet: WarSheet, label: String) -> Label:
	return sheet.get_node("Page/Sheet/TitleBlock/Box/" + label) as Label


func test_the_title_block_names_the_site_and_says_sheet_n_of_19() -> void:
	_owning(6)
	var sheet := _sheet({field_associate = 1}, &"K-8")  # The second war: K-7's map.
	assert_str(_title(sheet, "Code").text).is_equal("SITE K-7")
	assert_str(_title(sheet, "Site").text).is_equal("THE SUPERVISED PLOT")
	assert_str(_title(sheet, "Sheet").text).is_equal("SHEET 2 OF 19")
	_owning(5)
	sheet.begin(&"K-6", {field_associate = 1})
	assert_str(_title(sheet, "Sheet").text).is_equal("SHEET 1 OF 19")
	sheet.begin(&"endmark-1", {field_associate = 1})
	assert_str(_title(sheet, "Sheet").text).is_equal("SHEET 19 OF 19")
	TranslationServer.set_locale("de")
	sheet.begin(&"K-6", {field_associate = 1})
	assert_str(_title(sheet, "Sheet").text).is_equal("BLATT 1 VON 19")


func test_the_title_block_is_printed_on_the_corner_cells_no_map_uses_clear_of_the_weight() -> void:
	var sheet := _sheet()
	var block := (sheet.get_node("Page/Sheet/TitleBlock") as Control).get_rect()
	var cells := Rect2(WarSheet.pixel_of_cell(Vector2(WarSheet.TITLE_CELLS.position)), Vector2(WarSheet.TITLE_CELLS.size) * WarMap.CELL * 1000.0)
	assert_bool(cells.encloses(block)).is_true()
	assert_float(block.end.y).is_less_equal(cells.end.y - 90.0)  # The drafting weight sits on the corner.
	var box := sheet.get_node("Page/Sheet/TitleBlock/Box") as VBoxContainer
	var sites: Array[String] = []
	for path in WarMap.map_paths():
		var map: WarMap = load(path).instantiate()
		sites.append(map.site_name)
		map.free()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		sheet.begin(&"endmark-1", {field_associate = 1})  # SHEET 19 OF 19: the widest number.
		for site in sites:  # Every map's name, with the rest of the block.
			var high := 0.0
			for child: Control in box.get_children():
				high += box.get_theme_constant(&"separation")
				var label := child as Label
				if label == null:
					high += child.custom_minimum_size.y
					continue
				var text := tr(site) if label.name == &"Site" else tr(label.text)
				var font := label.get_theme_font(&"font")
				var size := label.get_theme_font_size(&"font_size")
				high += font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x, size).y
				for word in text.split(" "):
					var wide := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
					assert_float(wide).override_failure_message(word).is_less_equal(box.size.x)
			assert_float(high).override_failure_message("%s %s: %d px" % [locale, site, high]).is_less_equal(block.size.y - 10.0)


func test_the_new_structure_slip_appears_only_on_a_buildings_first_map_and_goes_at_start() -> void:
	_owning(6)
	var sheet := _sheet({field_associate = 1}, &"K-8")  # K-7's map: the first tower.
	assert_str(sheet.debut).is_equal("cannon")
	assert_str(sheet._slip.words()[1]).is_equal("SUPERVISOR'S TOWER")
	sheet._laying.custom_step(10.0)  # The sheet has rolled out.
	assert_bool(sheet._slip.visible).is_true()
	sheet.place(FA, 0)
	assert_bool(sheet.start_fight()).is_true()
	sheet._slip._moving.custom_step(1.0)
	assert_bool(sheet._slip.visible).is_false()
	_owning(5)
	var first := _sheet({field_associate = 1}, &"K-6")  # Only what the first war already shows.
	assert_str(first.debut).is_equal("")
	first._laying.custom_step(10.0)
	assert_bool(first._slip.visible).is_false()


func test_every_structure_slip_is_german_in_german_and_fits_its_paper() -> void:
	var sheet := _sheet()
	var slip: WarSlip = sheet._slip
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for kind: String in WarMap.DEBUT_KINDS:
			slip.debut(kind)
			var said: Array = WarSlip.STRUCTURES[kind]
			if locale == "de":
				for key: String in said:
					assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
			for part: String in ["Title"]:
				var label := slip.get_node("Page/Form/" + part) as Label
				var font := label.get_theme_font(&"font")
				var size := label.get_theme_font_size(&"font_size")
				var room := font.get_multiline_string_size(tr(label.text), HORIZONTAL_ALIGNMENT_LEFT, label.size.x, size) \
						if label.autowrap_mode != TextServer.AUTOWRAP_OFF else font.get_string_size(tr(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, size)
				assert_float(room.x).override_failure_message(tr(label.text)).is_less_equal(label.size.x)
				assert_float(room.y).override_failure_message(tr(label.text)).is_less_equal(label.size.y)  # Both lines show.
				assert_float(room.y).override_failure_message(tr(label.text)).is_less_equal(label.size.y + 6.0)


func test_a_hovered_defence_shows_its_range_ring_and_the_mailing_unit_its_dead_zone() -> void:
	_owning(7)
	var sheet := _sheet({field_associate = 1}, &"K-8")  # The test map: a tower and a mailing unit.
	var ink: WarInk = sheet._ink
	var rung := 0
	for i in sheet.fight.buildings.size():
		var kind: String = sheet.fight.buildings[i].kind
		if kind not in ["cannon", "mortar"]:
			continue
		rung += 1
		var centre := WarSheet.pixel_of_cell(sheet.fight.centre(i))
		sheet._point(centre, &"")
		sheet._process(0.0)
		assert_vector(ink.ring_at).is_equal(centre)
		assert_float(ink.ring_radius).is_equal_approx(WarFight.BUILDINGS[kind].range * 160.0, 0.01)
		assert_float(ink.dead_radius).is_equal_approx(2.0 * 160.0 if kind == "mortar" else 0.0, 0.01)
	assert_int(rung).is_equal(2)
	sheet._point(Vector2(10.0, 10.0), &"")  # Off every defence: rubbed out.
	sheet._process(0.0)
	assert_float(ink.ring_radius).is_equal(0.0)
	sheet.place(FA, 0)
	sheet.start_fight()
	for i in sheet.fight.buildings.size():
		if sheet.fight.buildings[i].kind == "cannon":
			sheet._point(WarSheet.pixel_of_cell(sheet.fight.centre(i)), &"")
	sheet._process(0.0)
	assert_float(ink.ring_radius).is_equal(0.0)  # Planning only.


func test_the_path_line_follows_the_way_the_fight_walks_the_figure() -> void:
	SaveManager.save.stamped.append(WarSheet.ROUTE_CARD)
	var sheet := _sheet({field_associate = 1}, &"K-6")
	var spot := Rect2(sheet.fight.zones[0]).get_center()
	assert_bool(sheet.pick_up(_figure(sheet))).is_true()
	sheet._point(_at(spot), &"")
	sheet._process(0.0)
	var line: PackedVector2Array = sheet._pencil.path
	var fight := WarFight.new(sheet._map.layout(), sheet._map.grid_size, 90.0)
	fight.place_at(FA, WarRules.unit_stats(SaveManager.save, FA), spot)
	fight.start()
	fight.tick(WarFight.STEP)
	var walked := PackedVector2Array([_at(spot)])
	for p: Vector2 in fight.units[0].path:
		walked.append(_at(p))
	assert_int(walked.size()).is_greater(3)
	assert_array(Array(line)).is_equal(Array(walked))
	var target: Dictionary = fight.buildings[fight.units[0].target]
	assert_str(target.kind).is_equal("farmhouse")  # K-6: no defence, the farmhouse through the fence.
	assert_bool(Rect2(Vector2(target.cell), Vector2(target.size)).has_point(WarSheet.cell_at(line[-1]))).is_true()
	sheet.drop(_at(spot))
	sheet._process(0.0)
	assert_array(Array(sheet._pencil.path)).is_empty()  # Set down: rubbed out.
	assert_bool(sheet._pencil_overlay.visible).is_false()


func test_no_path_line_is_pencilled_before_the_route_card_and_one_is_with_it() -> void:
	var sheet := _sheet({field_associate = 2}, &"K-6")
	var spot := Rect2(sheet.fight.zones[0]).get_center()
	sheet.pick_up(_figure(sheet))
	sheet._point(_at(spot), &"")
	sheet._process(0.0)
	assert_array(Array(sheet._pencil.path)).is_empty()
	assert_bool(sheet._pencil_overlay.visible).is_false()
	sheet.drop(_at(spot))
	SaveManager.save.stamped.append(WarSheet.ROUTE_CARD)
	sheet._path_wait = 0.0
	sheet.pick_up(_figure(sheet, 1))
	sheet._point(_at(spot + Vector2(0.5, 0.5)), &"")
	sheet._process(0.0)
	assert_int(sheet._pencil.path.size()).is_greater(1)
	assert_bool(sheet._pencil_overlay.visible).is_true()


func test_the_path_line_is_drawn_over_every_piece_on_the_board() -> void:
	var sheet := _sheet()
	var material := (sheet.get_node("PencilOverlay") as MeshInstance3D).material_override as StandardMaterial3D
	assert_bool(material.no_depth_test).is_true()
	assert_int(material.render_priority).is_greater(0)
	assert_int(material.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_object(sheet.get_node("PencilPage/Sheet/Pencil")).is_instanceof(WarInk)


func test_the_boss_arrival_plays_only_on_endmark_isle() -> void:
	var sheet := _sheet({field_associate = 1}, &"endmark-1")
	assert_bool(sheet.staging).is_true()
	assert_bool(sheet.can_place()).is_false()  # FINAL ACQUISITION first.
	assert_str(sheet._final.words()[0]).is_equal("FORM 9-F  FINAL ACQUISITION")
	assert_bool(sheet.place(FA, 0)).is_false()
	assert_bool(sheet.proceed()).is_true()
	assert_bool(sheet.staging).is_false()
	assert_bool(sheet.place(FA, 0)).is_true()
	assert_bool(sheet.proceed()).is_false()  # Once.
	for farm: StringName in [&"K-6", &"veldmark-1", &"nordhal-2"]:
		sheet.begin(farm, {field_associate = 1})
		assert_bool(sheet.staging).override_failure_message(farm).is_false()
		assert_bool(sheet._final.visible).is_false()


func test_the_new_war_sheet_words_are_german_in_german() -> void:
	TranslationServer.set_locale("de")
	for key: String in ["FORM 9-T", "SITE %s", "SHEET %d OF %d", "SCALE 1:100", "DRAWN: ACQUISITIONS", "APPROVED: PENDING OUTCOME",
			"NEW STRUCTURE ON SITE", "Removed at START.", "FORM 9-F  FINAL ACQUISITION", "Click to proceed.", "ENDMARK ISLE",
			"The last farm that is not ours. After this there is nothing left to acquire. The Board will be watching the clock."]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)


func test_picking_up_a_figure_puts_the_desks_glove_on_it_holding_it() -> void:
	var sheet := _sheet()
	var holder := _figure(sheet)
	var glove: HandModel = sheet.get_node("Glove")
	sheet.pick_up(holder)
	sheet._process(0.016)
	assert_bool(glove.visible).is_true()
	assert_int(glove.pose).is_equal(HandModel.Pose.GRAB)
	assert_float(glove.global_position.distance_to(holder.global_position)).is_less(0.3)
	assert_bool(Hand.stand_in).is_true()  # The glove stands in for the cursor.
	sheet.drop(_at(Vector2(1.3, 4.6)))


func test_a_figure_dropped_in_a_zone_stands_there_and_the_glove_lets_go() -> void:
	var sheet := _sheet()
	var holder := _figure(sheet)
	var glove: HandModel = sheet.get_node("Glove")
	sheet.pick_up(holder)
	sheet._process(0.016)
	assert_bool(sheet.drop(_at(Vector2(1.3, 4.6)))).is_true()
	sheet._process(0.016)
	assert_int(glove.pose).is_equal(HandModel.Pose.OPEN)
	assert_bool(Hand.stand_in).is_false()
	await _settled()
	assert_bool(sheet.in_zone(holder)).is_true()


## The table at war, the camera at the map: the war sheet takes the mouse.
func _war_at_map() -> WarSheet:
	var table := _table_at_war()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var war := table.sheet_of(&"war") as WarSheet
	war._process(0.0)
	return war


## Where the glove's anchor for its pose is (once the pose has settled).
func _anchor(glove: HandModel) -> Vector3:
	return glove.global_transform * (HandModel.ANCHORS[glove.pose] as Vector3)


func test_at_the_war_table_the_glove_is_the_cursor_open_with_nothing_held() -> void:
	var war := _war_at_map()
	var glove: HandModel = war.get_node("Glove")
	war._process(0.016)
	assert_bool(glove.visible).is_true()
	assert_int(glove.pose).is_equal(HandModel.Pose.OPEN)
	assert_bool(Hand.stand_in).is_true()  # The OS cursor stays hidden.
	war.pick_up(_figure(war))
	war._process(0.016)
	assert_int(glove.pose).is_equal(HandModel.Pose.GRAB)  # The desk's cabbage grab.


func test_over_start_and_abort_the_glove_points_its_fingertip_onto_the_button() -> void:
	var war := _war_at_map()
	var glove: HandModel = war.get_node("Glove")
	var control: WarControl = war.get_node("Control")
	for part: StringName in [WarSheet.START, WarSheet.ABORT]:
		war._point(Vector2.ZERO, part)
		war._process(2.0)  # Long enough for the pose to settle.
		assert_int(glove.pose).is_equal(HandModel.Pose.POINT)
		assert_float(_anchor(glove).distance_to(control.part_position(part))).override_failure_message(part).is_less(0.05)
	war._point(Vector2(800.0, 500.0), &"")
	war._process(0.016)
	assert_int(glove.pose).is_equal(HandModel.Pose.OPEN)


func test_the_glove_is_hidden_away_from_the_war_table() -> void:
	var sheet := _sheet()
	var glove: HandModel = sheet.get_node("Glove")
	sheet._process(0.016)
	assert_bool(glove.visible).is_false()
	sheet.move(_figure(sheet), _at(Vector2(1.3, 4.6)))
	sheet._process(WarSheet.LET_GO + 0.01)
	assert_bool(glove.visible).is_false()
	assert_bool(Hand.stand_in).is_false()


func test_the_end_of_a_fight_leaves_abort_unlit_and_no_hint_slip_over_the_report() -> void:
	var table := _table_at_war()
	var war := table.sheet_of(&"war") as WarSheet
	war._point(Vector2.ZERO, WarSheet.ABORT)
	assert_str(table._hovered).is_equal(WarSheet.ABORT)
	war.place(FA, 0)
	war.start_fight()
	_fight_for(war, 200.0)
	assert_str(war._hot).is_empty()
	assert_str((war.get_node("Control") as WarControl)._hover).is_empty()
	assert_str(table._hovered).is_empty()


func test_an_abort_right_after_declaring_brings_the_countrys_roll_back_for_good() -> void:
	var table := _table_at_war()
	var war := table.sheet_of(&"war") as WarSheet
	var roll := table.sheet_of(table.held())
	war._process(0.0)  # The roll in the holder starts to lift away.
	assert_bool(war.abort()).is_true()
	await get_tree().create_timer(WarSheet.AWAY_TIME * 2.0 + 0.2).timeout
	assert_bool(roll.visible).is_true()


func test_an_overlay_over_the_war_puts_the_figure_held_back_and_gives_the_cursor_back() -> void:
	var table := _table_at_war()
	var war := table.sheet_of(&"war") as WarSheet
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	war._process(0.0)
	var holder := _figure(war)
	var from := holder.position
	assert_bool(war.pick_up(holder)).is_true()
	war._process(0.016)
	assert_bool(Hand.stand_in).is_true()
	var overlay: Control = auto_free(Control.new())
	overlay.add_to_group(&"blocks_hand")
	add_child(overlay)
	war._process(0.016)
	assert_object(war._held).is_null()
	assert_bool(Hand.stand_in).is_false()
	assert_vector(Vector2(holder.position.x, holder.position.z)).is_equal_approx(Vector2(from.x, from.z), Vector2.ONE * 0.001)


## The duck's depth on bus `bus_name`: (dB down, dB more above its shelf; 0 while switched off).
func _duck_on(bus_name: String) -> Vector2:
	var bus := AudioServer.get_bus_index(bus_name)
	var out := Vector2.ZERO
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if not AudioServer.is_bus_effect_enabled(bus, i):
			continue
		if effect is AudioEffectAmplify:
			out.x = (effect as AudioEffectAmplify).volume_db
		elif effect is AudioEffectHighShelfFilter:
			out.y = 2.0 * linear_to_db((effect as AudioEffectHighShelfFilter).gain)  # The shelf's gain counts twice.
	return out


func test_while_a_war_is_on_every_other_sound_sits_in_the_background_and_eases_back_after() -> void:
	var volumes := [AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))]
	var sheet := _sheet()
	sheet._process(WarSheet.DUCK_IN / 2.0)
	assert_float(_duck_on("SFX").x).is_equal_approx(WarSheet.DUCK_DB / 2.0, 0.01)  # Easing in.
	sheet._process(WarSheet.DUCK_IN / 2.0)
	for bus_name: String in ["Music", "SFX"]:
		assert_vector(_duck_on(bus_name)).is_equal_approx(Vector2(WarSheet.DUCK_DB, WarSheet.MUFFLE_DB), Vector2(0.01, 0.01))
	assert_float(_duck_on("War").x).is_equal(0.0)  # The war itself stays in front.
	assert_array([AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))]).is_equal(volumes)  # The sliders' volumes are left alone.
	assert_bool(sheet.abort()).is_true()
	sheet._process(WarSheet.DUCK_OUT / 2.0)
	assert_float(_duck_on("Music").x).is_equal_approx(WarSheet.DUCK_DB / 2.0, 0.01)  # Easing out.
	sheet._process(WarSheet.DUCK_OUT / 2.0)
	for bus_name: String in ["Music", "SFX"]:
		assert_vector(_duck_on(bus_name)).is_equal(Vector2.ZERO)


func test_a_war_cut_off_by_leaving_the_scene_gives_every_sound_back_at_once() -> void:
	var sheet := _sheet()
	sheet._process(WarSheet.DUCK_IN)
	assert_float(_duck_on("Music").x).is_equal_approx(WarSheet.DUCK_DB, 0.01)
	remove_child(sheet)  # auto_free frees it.
	assert_vector(_duck_on("Music")).is_equal(Vector2.ZERO)


func test_every_war_sound_plays_on_the_war_bus() -> void:
	var sheet := _sheet()
	var players := sheet.find_children("*", "AudioStreamPlayer3D", true, false)
	assert_int(players.size()).is_greater_equal(25)
	for player: AudioStreamPlayer3D in players:
		assert_str(player.bus).override_failure_message(str(sheet.get_path_to(player))).is_equal("War")


func test_under_the_war_duck_desk_sounds_are_damped_but_still_heard() -> void:
	var sheet := _sheet()
	sheet._process(WarSheet.DUCK_IN)
	for bus_name: String in ["Music", "SFX"]:
		var bus := AudioServer.get_bus_index(bus_name)
		for i in AudioServer.get_bus_effect_count(bus):
			# A low-pass took a coin's clink 41 dB down (measured): only a shelf with a floor muffles.
			assert_bool(AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter and AudioServer.is_bus_effect_enabled(bus, i)) \
					.override_failure_message(bus_name).is_false()
		var depth := _duck_on(bus_name)
		assert_float(depth.x).is_equal_approx(-12.0, 0.01)  # Damped,
		assert_float(depth.x + depth.y).is_greater_equal(-20.0)  # even the highest clink at most 20 dB down,
		assert_float(depth.y).is_less(-3.0)  # and muffled.
	assert_float(WarSheet.DUCK_HZ).is_equal(800.0)


func test_no_boss_paper_comes_while_a_war_is_on_it_waits_until_the_sheet_has_left() -> void:
	var sheet := _sheet()
	BossReport.hold = 0.0
	sheet._process(0.016)
	assert_float(BossReport.hold).is_greater_equal(0.5)  # Held back the whole war.
	assert_bool(sheet.abort()).is_true()
	BossReport.hold = 0.0
	sheet._process(0.016)
	assert_float(BossReport.hold).is_equal(0.0)  # Left: the paper may come.


func test_a_war_counts_as_on_from_the_fight_set_up_until_the_sheet_has_left() -> void:
	var sheet := _sheet()
	assert_bool(WarSheet.at_war).is_true()
	assert_bool(sheet.abort()).is_true()
	assert_bool(WarSheet.at_war).is_false()


func test_once_the_after_action_report_of_a_won_war_is_in_the_war_glove_gives_the_cursor_back() -> void:
	_glove_gives_the_cursor_back("won")


func test_once_the_after_action_report_of_a_retreat_is_in_the_war_glove_gives_the_cursor_back() -> void:
	SaveManager.save.stamped.append("retreat")
	_glove_gives_the_cursor_back("retreat")


## The war ends `ending` ("won", "retreat") at the map: once its report is in, the glove is gone.
func _glove_gives_the_cursor_back(ending: String) -> void:
	var war := _war_at_map()
	var glove: HandModel = war.get_node("Glove")
	war.place(FA, 0)
	if ending == "won":
		war.place(FA, 0)
		war.place(FA, 0)
	war.start_fight()
	war._process(0.016)
	assert_bool(glove.visible).is_true()  # The glove during the fight.
	if ending == "won":
		_fight_for(war, 200.0)
	else:
		_fight_for(war, 0.5)
		assert_bool(war.abort()).is_true()
		war._process(0.0)
	assert_bool(war.fight.state in [WarFight.State.WON, WarFight.State.LOST]).is_true()
	_report_in(war, WarSheet.LOST_AFTER)
	war._process(0.016)
	assert_bool(glove.visible).is_false()
	assert_bool(Hand.stand_in).is_false()  # The OS cursor is back.
	_filed(war)
	assert_bool(Hand.stand_in).is_false()


func test_file_report_lights_under_the_mouse_once_the_grade_is_on() -> void:
	var sheet := _sheet()
	var report: WarReport = sheet.get_node("Report")
	var box: Control = report.get_node("Page/Form/File")
	report.lay(Vector3.ZERO)
	report._moving.custom_step(WarReport.SLIDE_TIME + 0.01)  # In, the grade not landed yet.
	var centre := box.get_rect().get_center() / WarReport.PAGE_PER_METRE
	var on_box := report.global_transform * Vector3(centre.x - WarReport.SIZE.x / 2.0, 0.0, centre.y)
	var up := report.global_basis.y.normalized()
	assert_bool(report.on_file(on_box + up, -up)).is_false()  # Not before the grade has landed.
	report._moving.custom_step(10.0)
	assert_bool(report.on_file(on_box + up, -up)).is_true()
	var top := report.global_transform * Vector3(0.0, 0.0, 0.1)
	assert_bool(report.on_file(top + up, -up)).is_false()
	report.hover(true)
	assert_object(box.modulate).is_equal(WarReport.HOT)
	report.put_away()
	assert_object(box.modulate).is_equal(Color.WHITE)


func test_a_new_structure_slip_bears_only_its_name_and_hovered_shows_its_card() -> void:
	_owning(6)
	var sheet := _sheet({field_associate = 1}, &"K-8")  # K-7's map: the first tower.
	sheet._laying.custom_step(10.0)
	assert_array(Array(sheet._slip.words()).slice(1, 4)).is_equal(["SUPERVISOR'S TOWER", "", ""])  # Only its name.
	var slip_middle := WarSheet.pixel_of(sheet._slip.position + Vector3(0.0, 0.0, sheet._slip.size().y / 2.0))
	assert_bool(sheet.on_slip(slip_middle)).is_true()
	assert_bool(sheet.on_slip(WarSheet.pixel_of_cell(Vector2(5, 5)))).is_false()  # On the battlefield.
	var note: Control = sheet.get_node("Note/Center")
	sheet._show_note(true)
	sheet._note_fade.custom_step(1.0)
	assert_float(note.modulate.a).is_equal(1.0)
	var paper: PaperNote = sheet.get_node("Note/Center/Paper")
	assert_str(paper._title).is_equal("SUPERVISOR'S TOWER")
	assert_str(paper._form).is_equal("NEW STRUCTURE ON SITE")
	var card := WarSlip.card("cannon")
	assert_str(card.body).is_equal("Someone is always watching. Occasionally, someone throws something.\n"
			+ "Shoots the nearest figure within 6 squares and stays on it until it falls or walks away.")
	assert_dict(UpgradeDesk.costs(card)).is_empty()  # Nothing to pay: no price box on it.
	sheet.place(FA, 0)
	assert_bool(sheet.start_fight()).is_true()
	assert_bool(sheet.on_slip(slip_middle)).is_false()  # Started: the slip goes, and its card with it.


func test_the_new_structure_slip_is_a_small_card_lying_clear_of_the_control_box_and_every_figure_place() -> void:
	var sheet := _sheet()
	var slip: WarSlip = sheet._slip
	var size := slip.size()
	assert_float(size.x * size.y).is_less(sheet._final.size().x * sheet._final.size().y / 8.0)
	var card := Rect2(Vector2(slip.position.x - size.x / 2.0, slip.position.z), size)
	var control: Node3D = sheet.get_node("Control")
	var box: AABB = control.transform * (control.get_node("Body") as MeshInstance3D).get_aabb()
	assert_bool(card.intersects(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))).is_false()
	for k in 11:  # The largest army.
		var spot := WarSheet._local(WarSheet.desk_pixel(k))
		assert_bool(card.grow(0.04).has_point(Vector2(spot.x, spot.z))).override_failure_message(str(k)).is_false()
	assert_float(card.end.x).is_less(-WarSheet.SIZE.x / 2.0)  # On the desk, off the paper.


## An ended war as WarReport.summary gives it: won or not, `deployed` (unit -> figures), defences
## destroyed of 3, a retreat, seconds fought.
func _ended(won: bool, deployed: Dictionary, destroyed := 1, retreat := false, seconds := 30.0) -> Dictionary:
	return {won = won, deployed = deployed, defences = Vector2i(destroyed, 3), retreat = retreat, seconds = seconds,
			grade = WarReport.ACCEPTABLE if won else WarReport.REGRETTABLE}


func test_winning_a_war_with_a_single_figure_counts_as_a_skeleton_crew_win() -> void:
	var save := SaveGame.new()
	WarSheet.tally(save, &"K-6", _ended(true, {field_associate = 1}))
	WarSheet.tally(save, &"K-7", _ended(true, {field_associate = 2}))
	assert_int(save.wars_won).is_equal(2)
	assert_int(save.solo_wins).is_equal(1)


func test_winning_a_war_with_only_field_associates_counts_once_pult_crews_are_hired() -> void:
	var save := SaveGame.new()
	WarSheet.tally(save, &"K-6", _ended(true, {field_associate = 3}))
	assert_int(save.associate_wins).is_equal(0)  # Nothing else to send yet.
	save.stamped.append(WarRules.UNIT_CARD.pult_crew)
	WarSheet.tally(save, &"K-7", _ended(true, {field_associate = 3, pult_crew = 1}))
	assert_int(save.associate_wins).is_equal(0)
	WarSheet.tally(save, &"K-8", _ended(true, {field_associate = 3}))
	assert_int(save.associate_wins).is_equal(1)


func test_only_a_retreat_within_three_seconds_of_start_is_a_quick_retreat() -> void:
	var save := SaveGame.new()
	WarSheet.tally(save, &"K-6", _ended(false, {field_associate = 2}, 0, true, WarSheet.QUICK_RETREAT))
	WarSheet.tally(save, &"K-6", _ended(false, {field_associate = 2}, 0, true, WarSheet.QUICK_RETREAT + 1.0))
	assert_int(save.wars_lost).is_equal(2)
	assert_int(save.quick_retreats).is_equal(1)
	assert_int(save.untouched_losses).is_equal(0)  # A retreat is no loss without a fight.


func test_losing_a_war_without_destroying_a_defence_is_counted_and_one_that_broke_something_is_not() -> void:
	var save := SaveGame.new()
	WarSheet.tally(save, &"K-6", _ended(false, {field_associate = 2}, 0))
	WarSheet.tally(save, &"K-6", _ended(false, {field_associate = 2}, 1))
	assert_int(save.untouched_losses).is_equal(1)


func test_the_win_that_takes_a_countrys_last_farm_abroad_annexes_it_and_home_never_counts() -> void:
	var save := SaveGame.new()
	WorldRegister.annex(save, WorldRegister.HOME)
	WarSheet.tally(save, &"K-8", _ended(true, {field_associate = 2}))
	assert_int(save.countries_annexed).is_equal(0)
	save.farms_owned.append("veldmark-1")
	WarSheet.tally(save, &"veldmark-1", _ended(true, {field_associate = 2}))
	assert_int(save.countries_annexed).is_equal(0)  # One of its two.
	save.farms_owned.append("veldmark-2")
	WarSheet.tally(save, &"veldmark-2", _ended(true, {field_associate = 2}))
	assert_int(save.countries_annexed).is_equal(1)


func test_an_exemplary_win_is_counted() -> void:
	var save := SaveGame.new()
	var report := _ended(true, {field_associate = 2})
	WarSheet.tally(save, &"K-6", report)
	report.grade = WarReport.EXEMPLARY
	WarSheet.tally(save, &"K-7", report)
	assert_int(save.wars_exemplary).is_equal(1)


## A save in chapter 4 with a bandit camp standing (no farm war under way).
func _camp() -> SaveGame:
	var save := _at_war()
	save.stamped.append(BanditCamp.CARD)
	BanditCamp.tick(save, 0.016)
	save.bandit_fee = 1000
	return save


func test_a_camp_fight_lays_the_camps_map_with_its_defences_buffed_and_no_farm_named() -> void:
	SaveManager.save = _camp()
	var sheet := _sheet({field_associate = 3}, BanditCamp.SITE)
	var buff := BanditCamp.buff(SaveManager.save)
	var plain := WarFight.new(sheet._map.layout(), sheet._map.grid_size, 90.0)
	for i in plain.buildings.size():
		assert_float(sheet.fight.buildings[i].max_hp).is_equal_approx(plain.buildings[i].max_hp * buff, 0.01)
	var box := "Page/Sheet/TitleBlock/Box/"
	assert_str((sheet.get_node(box + "Code") as Label).text).is_equal("UNREST LEVEL 1")
	assert_str((sheet.get_node(box + "Site") as Label).text).is_equal("BANDIT CAMP")
	assert_str(sheet.debut).is_empty()
	assert_bool(sheet.staging).is_false()


func test_a_camp_fights_staff_take_the_buffed_defences_harder_hits() -> void:
	SaveManager.save = _camp()
	var sheet := _sheet({field_associate = 3}, BanditCamp.SITE)
	assert_bool(sheet.place(FA, 0)).is_true()
	assert_bool(sheet.start_fight()).is_true()
	var full: float = WarRules.unit_stats(SaveManager.save, FA).hp
	assert_float(sheet.fight.units[0].max_hp).is_equal_approx(full / BanditCamp.buff(SaveManager.save), 0.01)


func test_a_farm_war_in_chapter_4_is_not_buffed() -> void:
	var save := _at_war()
	save.stamped.append(BanditCamp.CARD)
	SaveManager.save = save
	var sheet := _sheet()
	var plain := WarFight.new(sheet._map.layout(), sheet._map.grid_size, 90.0)
	for i in plain.buildings.size():
		assert_float(sheet.fight.buildings[i].max_hp).is_equal(plain.buildings[i].max_hp)


func test_a_camps_report_prints_the_recovery_and_what_it_paid_never_a_farm() -> void:
	var won: Dictionary = WarSheet.camp_lines({coins = 1500000000, findings = 3000000, stock = 250000}, true)
	assert_str(won.site).is_equal("RECOVERY OPERATION")
	assert_str(won.outcome).is_equal("PROPERTY RECOVERED")
	assert_str(won.remark).starts_with("Recovered: $")
	assert_str(WarSheet.camp_lines({}, false).outcome).is_equal("RECOVERY UNSUCCESSFUL")
