extends GdUnitTestSuite

const SCENE := "res://entities/map_table/map_table.tscn"
const DESK := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))
const WorldRegister := preload("res://entities/map_table/world_register.gd")
const WarSheet := preload("res://entities/map_table/war_sheet.gd")
const HOME := &"kohlmark"

var _real_save: SaveGame
var _camera: Camera3D
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = _chapter_3()
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	FarmTv.away = false
	_camera = Camera3D.new()
	_camera.transform = DESK
	_camera.fov = 40.0
	add_child(auto_free(_camera))
	_camera.make_current()


func after_test() -> void:
	SaveManager.save = _real_save
	FarmTv.away = false
	BossReport.up = false
	FarmRegister.lamp_held = false
	TranslationServer.set_locale(_locale)


func _chapter_3() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation"])
	return save


func _table() -> MapTable:
	var table: MapTable = auto_free(load(SCENE).instantiate())
	add_child(table)
	return table


## The table of a save with the world map card stamped: the world sheet's roll is in the holder.
func _table_with_world() -> MapTable:
	SaveManager.save.stamped.append("world_map")
	return _table()


## A save at war: five home farms, the war card, a purse and a store that pay for any war, three
## field associates ready.
func _at_war() -> void:
	var save := SaveManager.save
	save.army = {field_associate = 3}
	save.stamped.append_array(["negotiation", "bribery", "war_mode"])
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	save.coin_limit = 100000000
	save.coins = 50000000
	save.storage_cap = 100000
	save.stock = 50000


## Runs a sheet's arrival in progress to its end.
func _land(table: MapTable) -> void:
	if table._arrive_tween != null:
		table._arrive_tween.custom_step(10.0)


## Runs the swap in progress to its end, and any swap queued behind it.
func _finish(table: MapTable) -> void:
	for i in 4:
		if table.swapping:
			table._swap_tween.custom_step(10.0)


## Farm site K-1's centre on the country sheet's art (px).
func _k1(country: MapSheet) -> Vector2:
	return country.pixel_at((country.get_node("Things").get_child(0) as Node3D).global_position)


## Where `point` lands on the screen from the map view: -1..1 across and down is inside the frame.
func _on_screen(table: MapTable, point: Vector3, aspect := 16.0 / 9.0) -> Vector2:
	var local := (table.get_node("View") as Node3D).global_transform.affine_inverse() * point
	var half_h := tan(deg_to_rad(20.0))
	return Vector2(local.x / -local.z / (half_h * aspect), -local.y / -local.z / half_h)


func _lying_open(table: MapTable) -> Array[StringName]:
	var out: Array[StringName] = []
	for sheet in table.sheets():
		if sheet.open > 0.0:
			out.append(sheet.id)
	return out


func _at_map(table: MapTable) -> void:
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._process(0.0)


## A left click at screen point `at`.
func _click(table: MapTable, at: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	table._input(click)


## Lays out the declaration of war for `farm` on the open country sheet (every figure ready goes)
## and stamps it, to the war sheet.
func _start_war(table: MapTable, farm: StringName) -> void:
	var country := table.sheet_of(table.shown) as FarmRegister
	country.press(farm)
	country.press(FarmRegister.STAMP)
	country._dealing.custom_step(10.0)
	_finish(table)


## The war's end plays out: its after-action report slides in, its grade lands, and it is filed.
func _file_report(war: WarSheet) -> void:
	war._dealing.custom_step(10.0)
	(war.get_node("Report") as WarReport)._moving.custom_step(10.0)
	assert_bool(war.file_report()).is_true()
	war._dealing.custom_step(10.0)


## Fights the war on the open war sheet to a win: three field associates in its first zone.
func _win_war(table: MapTable) -> WarSheet:
	var war := table.sheet_of(&"war") as WarSheet
	war.begin(war.farm, {field_associate = 3})
	for i in 3:
		war.place("field_associate", 0)
	war.start_fight()
	war.fight.tick(WarRules.fight_seconds(SaveManager.save))
	war._process(0.0)
	return war


func test_only_the_home_countrys_sheet_is_on_the_map_table_when_it_opens() -> void:
	var table := _table()
	assert_array(_lying_open(table)).is_equal([HOME])
	assert_float(table.sheet_of(HOME).open).is_equal(1.0)
	for sheet in table.sheets():
		assert_bool(table.on_table(sheet.id)).override_failure_message(sheet.id).is_equal(sheet.id == HOME)
		assert_bool(sheet.visible).override_failure_message(sheet.id).is_equal(sheet.id == HOME)
	assert_str(table.held()).is_equal(&"")  # The top level: the holder is empty.
	assert_object(table.sheet_of(&"ostrevia")).is_null()  # No other country's sheet is loaded.


func test_a_locked_sheet_cannot_be_shown_or_picked() -> void:
	var table := _table()
	var eye: Vector3 = table.get_node("View").global_position
	for id: StringName in [&"world", &"ostrevia", &"war", &"moon"]:
		table.show_sheet(id)
		assert_bool(table.swapping).override_failure_message(id).is_false()
		assert_str(table.shown).is_equal(HOME)
	assert_str(table.pick(eye, table.get_node("Holder/Slot").global_position - eye)).is_equal(&"")  # An empty holder.
	assert_str(table._queued).is_equal(&"")


func test_the_world_sheet_and_every_country_abroad_come_with_the_world_map_card() -> void:
	var save := _chapter_3()
	assert_bool(MapTable.sheet_unlocked(HOME, save)).is_true()
	for id: StringName in [&"world", &"ostrevia", &"endmark"]:
		assert_bool(MapTable.sheet_unlocked(id, save)).override_failure_message(id).is_false()
	save.stamped.append(MapTable.WORLD_CARD)
	assert_str(MapTable.WORLD_CARD).is_equal("world_map")
	assert_object(UpgradeDesk.card_data(MapTable.WORLD_CARD)).is_not_null()
	for id: StringName in WorldRegister.COUNTRIES.keys() + [&"world"]:
		assert_bool(MapTable.sheet_unlocked(id, save)).override_failure_message(id).is_true()
	assert_bool(MapTable.sheet_unlocked(&"war", save)).is_false()  # Only with a farm to fight for.
	assert_bool(MapTable.sheet_unlocked(&"moon", save)).is_false()


func test_the_sheet_that_lay_open_last_lies_open_again_after_a_reload_and_a_war_comes_back_as_its_country() -> void:
	var save := _chapter_3()
	save.map_sheet = "sulvania"
	assert_str(MapTable.start_sheet(save)).is_equal(HOME)  # Not unlocked any more (an edited save).
	save.stamped.append(MapTable.WORLD_CARD)
	assert_str(MapTable.start_sheet(save)).is_equal(&"sulvania")
	save.map_sheet = "war"
	assert_str(MapTable.start_sheet(save)).is_equal(HOME)
	SaveManager.save = save
	save.map_sheet = "sulvania"
	var table := _table()
	assert_str(table.shown).is_equal(&"sulvania")
	assert_str(table.held()).is_equal(&"world")
	_at_war()
	SaveManager.save.map_sheet = "kohlmark"
	var again := _table()
	_start_war(again, &"K-7")
	assert_str(again.shown).is_equal(&"war")
	assert_str(SaveManager.save.map_sheet).is_equal("kohlmark")  # The war is not kept: its country is.


func test_a_save_with_the_world_map_card_stamped_has_the_world_roll_in_the_holder() -> void:
	var table := _table_with_world()
	var world := table.sheet_of(&"world")
	assert_str(table.held()).is_equal(&"world")
	assert_bool(table.on_table(&"world")).is_true()
	assert_bool(world.visible).is_true()
	assert_object(table._arrive_tween).is_null()  # No arrival: it is there.
	assert_bool(world.get_node("Core").global_position.is_equal_approx(table.get_node("Holder/Slot").global_position)).is_true()
	assert_bool(world.get_node("Core/Tag").visible).is_true()
	assert_str((world.get_node("Core/Tag/Name") as Label3D).text).is_equal("WORLD")
	assert_bool((table.get_node("Arrive") as SoundCue).playing).is_false()


func test_stamping_the_world_map_card_drops_the_world_roll_into_the_holder_the_next_time_the_camera_is_at_the_map() -> void:
	var table := _table()
	var world := table.sheet_of(&"world")
	var arrive := table.get_node("Arrive") as SoundCue
	SaveManager.save.stamped.append("world_map")
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()  # At the desk nothing arrives: nobody would see it.
	_at_map(table)
	assert_object(table._arrive_tween).is_not_null()
	assert_bool(table.on_table(&"world")).is_false()  # Still in the air: not to be picked yet.
	var eye: Vector3 = table.get_node("View").global_position
	assert_str(table.pick(eye, table.get_node("Holder/Slot").global_position - eye)).is_equal(&"")
	assert_bool(arrive.playing).is_false()
	table._arrive_tween.custom_step(MapTable.ARRIVE_AFTER + MapTable.ARRIVE_TIME + 0.01)
	assert_bool(arrive.playing).is_true()  # The clack as it lands in its saddle.
	assert_bool(world.visible).is_true()
	assert_str(table.held()).is_equal(&"world")
	_land(table)
	assert_bool(world.get_node("Core").global_position.is_equal_approx(table.get_node("Holder/Slot").global_position)).is_true()
	assert_str(table.pick(eye, table.get_node("Holder/Slot").global_position - eye)).is_equal(MapTable.HOLDER)
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()  # It arrives once.


func test_the_holder_carries_the_sheet_one_level_up_and_a_click_on_it_goes_back() -> void:
	WorldRegister.annex(SaveManager.save, HOME)  # Sulvania borders it: reachable.
	var table := _table_with_world()
	_at_map(table)
	var slot: Vector3 = table.get_node("Holder/Slot").global_position
	_click(table, _camera.unproject_position(slot))  # The WORLD roll: up to the world sheet.
	_finish(table)
	assert_str(table.shown).is_equal(&"world")
	assert_str(table.held()).is_equal(&"")  # The world is the top level.
	assert_object(table.sheet_of(HOME)).is_null()  # The country's sheet left the table and was freed.
	table.sheet_of(&"world").press(&"sulvania")  # A country of the world: down to its sheet.
	_finish(table)
	assert_str(table.shown).is_equal(&"sulvania")
	assert_str(table.held()).is_equal(&"world")
	assert_array(_lying_open(table)).is_equal([&"sulvania"])
	_click(table, _camera.unproject_position(slot))
	_finish(table)
	assert_str(table.shown).is_equal(&"world")
	assert_object(table.sheet_of(&"sulvania")).is_null()


func test_clicking_a_reachable_country_on_the_world_sheet_opens_its_sheet_and_an_unreachable_one_does_not() -> void:
	WorldRegister.annex(SaveManager.save, HOME)
	var table := _table_with_world()
	table.show_sheet(&"world")
	_finish(table)
	_at_map(table)
	var world := table.sheet_of(&"world")
	var far: Node3D = (world as WorldRegister)._sites[&"endmark"]
	_click(table, _camera.unproject_position(far.global_position))  # Not yet reachable: refused.
	_finish(table)
	assert_str(table.shown).is_equal(&"world")
	var token: Node3D = (world as WorldRegister)._sites[&"sulvania"]
	_click(table, _camera.unproject_position(token.global_position))
	_finish(table)
	assert_str(table.shown).is_equal(&"sulvania")
	assert_object(table.sheet_of(&"sulvania") as FarmRegister).is_not_null()
	assert_int(SaveManager.save.farms_owned.size()).is_equal(8)  # Looking costs nothing.


func test_hovering_a_country_on_the_world_sheet_starts_loading_its_sheet() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	_finish(table)
	table._hover(&"morrow")
	assert_int(ResourceLoader.load_threaded_get_status(MapTable.COUNTRY_SCENE % &"morrow")).is_not_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	table.show_sheet(&"morrow")
	_finish(table)
	assert_str(table.shown).is_equal(&"morrow")


func test_starting_a_war_rolls_out_the_war_sheet_for_that_farm() -> void:
	_at_war()
	var table := _table()
	_start_war(table, &"K-7")
	assert_str(table.shown).is_equal(&"war")
	assert_str(table.held()).is_equal(HOME)  # Its country, rolled up in the holder.
	var war := table.sheet_of(&"war") as WarSheet
	assert_str(war.farm).is_equal(&"K-7")
	assert_str(war._map.scene_file_path).is_equal(WarMap.MAPS + "K-6.tscn")  # The first war at home, whichever farm.
	assert_int(SaveManager.save.farms_owned.size()).is_equal(5)


func test_losing_the_war_costs_only_what_the_declaration_paid() -> void:
	_at_war()
	SaveManager.save.farms_owned.append("K-6")  # The second war at home: K-7's map, its tower, one associate is not enough.
	var table := _table()
	var coins := SaveManager.save.coins - int(WorldRegister.COUNTRIES[HOME].wars[1].coins)
	var stock := SaveManager.save.stock
	_start_war(table, &"K-7")
	_at_map(table)
	var war := table.sheet_of(&"war") as WarSheet
	war.begin(war.farm, {field_associate = 1})
	_click(table, _camera.unproject_position(table.get_node("Holder/Slot").global_position))
	_finish(table)
	assert_str(table.shown).is_equal(&"war")  # No way out while the war is on.
	war.place("field_associate", 0)
	war.start_fight()
	war.fight.tick(WarRules.fight_seconds(SaveManager.save))
	war._process(0.0)
	_file_report(war)
	_finish(table)
	assert_str(table.shown).is_equal(HOME)
	assert_int(SaveManager.save.coins).is_equal(coins)
	assert_int(SaveManager.save.stock).is_equal(stock)
	assert_bool(SaveManager.save.farms_owned.has("K-7")).is_false()
	assert_bool(((table.sheet_of(HOME) as FarmRegister)._sites[&"K-7"]).owned).is_false()


func test_winning_the_war_takes_that_one_farm_and_its_moment_plays_back_on_its_country_sheet() -> void:
	_at_war()
	var table := _table()
	_start_war(table, &"K-7")
	var war := _win_war(table)
	assert_array(Array(SaveManager.save.farms_owned)).is_equal(["K-1", "K-2", "K-3", "K-4", "K-5", "K-7"])
	assert_bool(FarmRegister.lamp_held).is_true()  # The Field Line waits for the moment.
	_file_report(war)
	_finish(table)
	assert_str(table.shown).is_equal(HOME)
	var country := table.sheet_of(HOME) as FarmRegister
	assert_bool(country._sites[&"K-7"].owned).is_true()
	assert_bool((country.get_node("Flash/Swap") as SoundCue).playing).is_true()
	country._dealing.custom_step(10.0)
	assert_bool(FarmRegister.lamp_held).is_false()
	assert_bool(country._sites[&"K-6"].owned).is_false()  # That one farm only.


func test_a_war_abroad_comes_back_to_that_country_with_the_world_in_the_holder_again() -> void:
	_at_war()
	SaveManager.save.stamped.append("world_map")
	WorldRegister.annex(SaveManager.save, HOME)
	SaveManager.save.map_sheet = "ostrevia"
	var table := _table()
	assert_str(table.held()).is_equal(&"world")
	_start_war(table, &"ostrevia-2")
	assert_str(table.held()).is_equal(&"ostrevia")  # The world roll made room.
	_file_report(_win_war(table))
	_finish(table)
	assert_str(table.shown).is_equal(&"ostrevia")
	assert_str(table.held()).is_equal(&"")
	_at_map(table)  # The holder lacks the world: it drops back in.
	_land(table)
	assert_str(table.held()).is_equal(&"world")


func test_only_one_sheet_lies_open_at_a_time() -> void:
	var table := _table_with_world()
	for id: StringName in [&"world", HOME, &"world", &"veldmark"]:
		table.show_sheet(id)
		_finish(table)
		assert_array(_lying_open(table)).is_equal([id])
		assert_str(table.shown).is_equal(id)
		assert_bool(table.swapping).is_false()


func test_at_most_one_country_sheet_is_alive_at_a_time() -> void:
	var table := _table_with_world()
	for id: StringName in [&"world", &"veldmark", &"world", &"morrow"]:
		table.show_sheet(id)
		_finish(table)
		var countries := table.sheets().filter(func(sheet: MapSheet) -> bool: return sheet is FarmRegister)
		assert_int(countries.size()).override_failure_message(id).is_less_equal(1)


func test_asking_for_the_sheet_that_is_already_out_changes_nothing() -> void:
	var table := _table()
	table.show_sheet(HOME)
	assert_bool(table.swapping).is_false()
	assert_str(table.shown).is_equal(HOME)
	assert_float(table.sheet_of(HOME).open).is_equal(1.0)


func test_a_swap_asked_for_during_a_swap_waits_and_runs_right_after_it() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	var running := table._swap_tween
	table.show_sheet(&"sulvania")
	assert_object(table._swap_tween).is_same(running)  # The running swap is left alone.
	assert_str(table.shown).is_equal(&"world")
	running.custom_step(10.0)
	assert_bool(table.swapping).is_true()  # The next sheet's swap began as the first one ended.
	assert_str(table.shown).is_equal(&"sulvania")
	_finish(table)
	assert_array(_lying_open(table)).is_equal([&"sulvania"])


func test_of_several_swaps_asked_for_during_a_swap_only_the_last_one_runs() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	table.show_sheet(&"sulvania")
	table.show_sheet(&"moon")  # No such sheet: not a request.
	table.show_sheet(&"world")  # Back to the one already on its way: nothing more to do.
	_finish(table)
	assert_bool(table.swapping).is_false()
	assert_array(_lying_open(table)).is_equal([&"world"])


func test_the_roll_in_the_holder_rests_in_its_saddle_clear_of_the_desk_the_wall_and_the_open_sheets_core() -> void:
	var table := _table_with_world()
	var radius := MapSheet.roll_radius(0.0)
	var slot: Vector3 = table.get_node("Holder/Slot").global_position
	assert_bool(table.sheet_of(&"world").get_node("Core").global_position.is_equal_approx(slot)).is_true()
	assert_float(slot.y - radius).is_greater(0.75 + 0.01)  # Over the desk top.
	assert_float(slot.x + radius).is_less(5.88)  # Short of the wall.
	assert_float(slot.x).is_greater((table.get_node("Lay") as Node3D).global_position.x)  # The wall side of the sheet.
	# The open sheet's core, on its caps along the top edge, is clear of the roll and of the weights.
	var core: Vector3 = table.sheet_of(table.shown).get_node("Core").global_position
	assert_float(slot.x - core.x).is_greater(radius + MapSheet.CAP)
	for weight: Node3D in table.get_node("Weights").get_children():
		assert_float(absf(weight.position.x - core.x)).is_greater(0.061 + 0.028)  # The weight's and the core tube's radius.


## Hovers farm site `site` of the open sheet and lets the table place the hint slip.
func _hover_site(table: MapTable, sheet: FarmRegister, site: StringName) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _camera.unproject_position(sheet.point_at(sheet._pixel(site)))
	table._input(move)
	table._process(0.0)


func test_a_farms_hint_lies_beside_that_farm() -> void:
	var table := _table()
	_at_map(table)
	var home := table.sheet_of(HOME) as FarmRegister
	_hover_site(table, home, &"K-1")
	assert_bool(table._hint.visible).is_true()
	var site := table._on_screen_box(home, home.spot_box(&"K-1"))
	var slip := Rect2(table._hint.position, table._hint.size)
	assert_bool(site.grow(MapTable.HINT_GAP + 1.0).intersects(slip)).override_failure_message("%s, %s" % [site, slip]).is_true()


func test_a_hint_near_the_sheet_edge_flips_to_stay_on_the_paper() -> void:
	var paper := Rect2(0, 0, 1000, 600)
	var slip := Vector2(400, 200)
	# Room on the right: there, level with the farm's top.
	assert_vector(MapTable.beside(Rect2(100, 100, 100, 100), slip, paper)).is_equal(Vector2(200 + MapTable.HINT_GAP, 100))
	# At the right edge: on the left instead.
	assert_vector(MapTable.beside(Rect2(800, 100, 100, 100), slip, paper)).is_equal(Vector2(800 - MapTable.HINT_GAP - 400, 100))
	# At the bottom edge: slid up beside it, still on the paper.
	var low := MapTable.beside(Rect2(100, 500, 100, 80), slip, paper)
	assert_bool(paper.encloses(Rect2(low, slip))).is_true()
	assert_bool(Rect2(low, slip).intersects(Rect2(100, 500, 100, 80))).is_false()
	# Too wide for either side: below it.
	assert_vector(MapTable.beside(Rect2(350, 100, 300, 100), slip, paper)).is_equal(Vector2(350, 200 + MapTable.HINT_GAP))


func test_the_hint_never_covers_the_hovered_farms_tags() -> void:
	var table := _table()
	_at_map(table)
	var home := table.sheet_of(HOME) as FarmRegister
	for site: StringName in home._sites:  # As the table lays it, with its real text.
		_hover_site(table, home, site)
		var slip := Rect2(table._hint.position, table._hint.size)
		assert_bool(slip.intersects(table._on_screen_box(home, home.spot_box(site)))).override_failure_message(site).is_false()
		assert_bool(get_viewport().get_visible_rect().encloses(slip)).override_failure_message(site).is_true()
	# Every country's sites, lying where the home sheet lies: the slip at its width and six lines.
	var window := get_viewport().get_visible_rect().grow(-MapTable.HINT_MARGIN)
	for id: StringName in WorldRegister.COUNTRIES:
		var country: FarmRegister = auto_free(load(MapTable.COUNTRY_SCENE % id).instantiate())
		add_child(country)
		country.global_transform = home.global_transform
		var room := table._on_screen_box(country, Rect2(Vector2.ZERO, MapSheet.SIZE * MapSheet.PIXELS_PER_METRE)).intersection(window)
		for site: StringName in country._sites:
			var box := table._on_screen_box(country, country.spot_box(site))
			var slip := Rect2(MapTable.beside(box, Vector2(MapTable.SPOT_HINT_WIDTH, 6.0 * 34.0), room), Vector2(MapTable.SPOT_HINT_WIDTH, 6.0 * 34.0))
			assert_bool(slip.intersects(box)).override_failure_message("%s: the slip covers %s" % [id, site]).is_false()
			assert_bool(room.encloses(slip)).override_failure_message("%s: %s runs off" % [id, site]).is_true()


func test_the_map_view_shows_the_to_desk_plate_the_weights_beside_the_sheet_and_the_roll_in_the_holder_with_its_tag() -> void:
	var table := _table_with_world()
	var points: Array[Vector3] = []
	var back := (table.get_node("DeskButton/Plate") as Node3D).global_position
	for side: float in [-1.0, 1.0]:
		points.append(back + Vector3(0.0, 0.0, MapTable.BACK_HALF.x * side))
	for weight: Node3D in table.get_node("Weights").get_children():  # Hopped aside during a swap.
		points.append(weight.position + Vector3(0.0, 0.0, signf(weight.position.z - 1.75) * (MapTable.WEIGHT_ASIDE + 0.061)))
	# The roll in its saddle, lifted under the mouse, with its name tag.
	var slot: Vector3 = table.get_node("Holder/Slot").global_position
	points.append(slot + Vector3(MapSheet.roll_radius(0.0), MapTable.HOVER_LIFT, 0.0))
	points.append((table.sheet_of(&"world").get_node("Core/Tag/Name") as Node3D).global_position)
	for point in points:
		var at := _on_screen(table, point)
		assert_float(maxf(absf(at.x), absf(at.y))).override_failure_message("%s is off the screen" % point).is_less(1.0)


func test_a_click_on_a_farm_token_lands_on_that_farm_at_home_and_abroad() -> void:
	var table := _table_with_world()
	_at_map(table)
	for id: StringName in [HOME, &"sulvania"]:
		table.show_sheet(id)
		_finish(table)
		var sites := table.sheet_of(id).get_node("Things").get_children()
		assert_int(sites.size()).is_equal(WorldRegister.COUNTRIES[id].farms)
		for site: MapBuilding in sites:
			var at := _camera.unproject_position(site.global_position)
			assert_str(table.pick(_camera.project_ray_origin(at), _camera.project_ray_normal(at))).is_equal(site.site)


func test_a_click_at_the_map_finds_the_to_desk_plate_the_roll_in_the_holder_and_the_farm_sites_but_not_the_bare_sheet() -> void:
	var table := _table_with_world()
	var eye: Vector3 = table.get_node("View").global_position
	assert_str(table.pick(eye, table.get_node("DeskButton/Plate").global_position - eye)).is_equal(MapTable.BACK)
	assert_str(table.pick(eye, table.get_node("Holder/Slot").global_position - eye)).is_equal(MapTable.HOLDER)
	var country := table.sheet_of(HOME)
	var site: MapBuilding = country.get_node("Things").get_child(0)
	assert_str(table.pick(eye, site.global_position - eye)).is_equal(site.site)
	var bare := country.point_at(Vector2(site.position.x * 1000.0 + 1600.0, site.position.z * 1000.0) + Vector2(0, -400))
	assert_str(table.pick(eye, bare - eye)).is_equal(&"")


func test_whatever_the_mouse_takes_hold_of_at_the_map_gives_a_paper_tick() -> void:
	var table := _table_with_world()
	var hover := table.get_node("Hover") as SoundCue
	assert_bool(hover.playing).is_false()
	table._hover(MapTable.HOLDER)
	assert_bool(hover.playing).is_true()
	assert_str(table._hint.text).is_equal(table.sheet_of(&"world").hint_title())


func test_the_map_table_stays_hidden_until_chapter_3_opens() -> void:
	SaveManager.save = SaveGame.new()
	var table := _table()
	assert_bool(table.visible).is_false()
	table.go_to_map()
	assert_bool(FarmTv.away).is_false()
	SaveManager.save.stamped.append("consolidation")
	table._process(0.0)
	assert_bool(table.visible).is_true()


func test_the_map_table_opens_with_the_last_card_of_chapter_2_and_not_with_the_farm() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm", "standing_seed_order"])
	assert_bool(MapTable.unlocked(save)).is_false()
	assert_bool(MapTable.unlocked(_chapter_3())).is_true()


func test_the_weights_leave_the_sheet_before_it_rolls_and_end_on_the_new_sheets_corners() -> void:
	var table := _table_with_world()
	var weights := table.get_node("Weights").get_children()
	var corners: Array[Vector3] = []
	for weight: Node3D in weights:
		corners.append(weight.position)
	var paper := Rect2(3.6, 0.15, 1.8, 3.2)  # The sheet on the desk: x, z.
	table.show_sheet(&"world")
	table._swap_tween.custom_step(MapTable.ROLL_UP_AT + MapTable.ROLL_UP_TIME)
	for weight: Node3D in weights:
		assert_bool(paper.has_point(Vector2(weight.position.x, weight.position.z))) \
				.override_failure_message("%s is still on the sheet as it rolls up" % weight.name).is_false()
	_finish(table)
	for i in weights.size():
		var weight: Node3D = weights[i]
		assert_bool(weight.position.is_equal_approx(corners[i])).is_true()
		assert_bool(weight.scale.is_equal_approx(Vector3.ONE)).is_true()
		assert_bool(paper.has_point(Vector2(corners[i].x, corners[i].z))).is_true()


func test_a_whole_swap_takes_between_one_and_a_half_and_two_seconds() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	var time := 0.0
	while table.swapping and time < 5.0:
		table._swap_tween.custom_step(0.01)
		time += 0.01
	assert_float(time).is_between(1.5, 2.0)


func test_the_swaps_steps_come_one_after_the_other() -> void:
	assert_float(MapTable.ROLL_UP_AT).is_greater(MapTable.WEIGHTS_OFF_AT)
	assert_float(MapTable.STOW_AT).is_greater_equal(MapTable.ROLL_UP_AT + MapTable.ROLL_UP_TIME - 0.05)
	assert_float(MapTable.LAND_AT).is_greater(MapTable.STOW_AT)
	assert_float(MapTable.UNROLL_AT).is_greater(MapTable.LAND_AT)
	assert_float(MapTable.WEIGHTS_ON_AT).is_greater(MapTable.UNROLL_AT)
	assert_float(MapTable.POP_AT).is_greater(MapTable.WEIGHTS_ON_AT)


func test_the_camera_comes_home_from_the_map_exactly_to_the_desk_view() -> void:
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var view: Transform3D = table.get_node("View").global_transform
	assert_bool(_camera.transform.is_equal_approx(view)).is_true()
	table.back_to_desk()
	table._pan_tween.custom_step(10.0)
	assert_bool(_camera.transform.is_equal_approx(DESK)).is_true()


func test_the_hand_and_the_pull_tab_stay_away_until_the_camera_is_home_again() -> void:
	var table := _table()
	table.go_to_map()
	assert_bool(FarmTv.away).is_true()  # Leaving: gone at once.
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	assert_bool(FarmTv.away).is_true()
	assert_bool(table.get_node("Cursor").visible).is_true()
	table.back_to_desk()
	table._pan_tween.custom_step(MapTable.PAN_TIME * 0.5)
	assert_bool(FarmTv.away).is_true()  # Panning back: still gone.
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	assert_bool(FarmTv.away).is_false()
	assert_bool(table.get_node("Cursor").visible).is_false()


func test_the_camera_does_not_leave_for_the_map_while_it_is_at_the_farm_tv() -> void:
	var table := _table()
	FarmTv.away = true
	table.go_to_map()
	assert_object(table._pan_tween).is_null()
	assert_bool(_camera.transform.is_equal_approx(DESK)).is_true()


func test_the_map_view_looks_almost_straight_down_with_the_wall_along_the_top() -> void:
	var view: Transform3D = _table().get_node("View").global_transform
	var forward := -view.basis.z
	assert_float(rad_to_deg(asin(-forward.y))).is_between(75.0, 85.0)
	assert_float(forward.x).is_greater(0.0)  # Tilted towards the side wall.
	assert_float(view.basis.y.x).is_greater(0.9)  # Screen-up is +X: the wall.
	assert_bool(view.basis.x.is_equal_approx(Vector3.BACK)).is_true()  # Screen-right is +Z.


func test_the_open_sheet_with_its_border_is_inside_the_frame_at_16_9_and_21_9() -> void:
	# FramedCamera: the 16:9 frame is always in view (more at the sides when wider, more above and
	# below when narrower).
	var table := _table()
	for aspect: float in [16.0 / 9.0, 21.0 / 9.0]:
		for x: float in [3.6, 5.4]:
			for z: float in [0.15, 3.35]:
				var at := _on_screen(table, Vector3(x, 0.752, z), aspect)
				assert_float(maxf(absf(at.x), absf(at.y))).override_failure_message("the sheet's corner at %s, %s is off the screen" % [x, z]).is_less(0.98)


func test_a_declaration_of_war_lies_whole_on_the_screen_at_16_9_16_10_21_9_and_720p_beside_any_farm() -> void:
	# FramedCamera: at or above 16:9 the height is kept, below it the 16:9 width.
	_at_war()
	var table := _table()
	var sheet := table.sheet_of(HOME) as FarmRegister
	var paper := FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE * FarmDeed.WAR_SCALE
	var up := sheet.global_basis.y.normalized() * FarmRegister.DEED_LIFT
	for screen: Vector2i in [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(1280, 720)]:
		var aspect := float(screen.x) / screen.y
		var half := Vector2(tan(deg_to_rad(20.0)) * aspect, tan(deg_to_rad(20.0)))
		if aspect < 16.0 / 9.0:
			half = Vector2(tan(deg_to_rad(20.0)) * 16.0 / 9.0, tan(deg_to_rad(20.0)) * 16.0 / 9.0 / aspect)
		for x in range(150, 3100, 100):
			for y: float in [120.0, 900.0, 1680.0]:
				var corner := FarmRegister.deed_corner(Vector2(x, y), FarmDeed.WAR_SCALE)
				for k: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
					var point := sheet.point_at(corner + paper * k) + up
					var local := (table.get_node("View") as Node3D).global_transform.affine_inverse() * point
					var at := Vector2(local.x / -local.z / half.x, -local.y / -local.z / half.y)
					assert_float(maxf(absf(at.x), absf(at.y))).override_failure_message("%s: the paper beside %d, %d is off the screen at %s" % [screen, x, y, at]).is_less(0.99)
	# And it is big: well over half the screen's height at 16:9.
	var top := _on_screen(table, sheet.point_at(FarmRegister.deed_corner(Vector2(800, 900), FarmDeed.WAR_SCALE)) + up)
	var foot := _on_screen(table, sheet.point_at(FarmRegister.deed_corner(Vector2(800, 900), FarmDeed.WAR_SCALE) + Vector2(0, paper.y)) + up)
	assert_float(absf(foot.y - top.y) / 2.0).is_greater(0.6)


func test_the_open_sheet_takes_more_than_three_quarters_of_the_screens_height() -> void:
	var table := _table()
	var tall := (_on_screen(table, Vector3(3.6, 0.752, 1.75)).y - _on_screen(table, Vector3(5.4, 0.752, 1.75)).y) / 2.0
	assert_float(tall).is_between(0.76, 0.85)


func test_the_to_desk_button_goes_in_when_clicked_and_lies_where_the_click_is_taken() -> void:
	var table := _table()
	var button: Node3D = table.get_node("DeskButton")
	var back: Vector3 = table.get_node("DeskButton/Plate").global_position
	assert_float(Vector2(button.global_position.x, button.global_position.z).distance_to(Vector2(back.x, back.z))).is_less(0.001)
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var click := InputEventMouseButton.new()
	click.position = _camera.unproject_position(back)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	table._input(click)
	assert_bool(table._at_map).is_false()
	await get_tree().create_timer(button.PRESS_TIME * button.DOWN).timeout
	assert_float(button.get_node("Button").position.y).is_less(0.0)


func test_the_holdings_indicator_stands_at_the_map_only_once_its_card_is_stamped() -> void:
	var table := _table()
	var tally: Node3D = table.get_node("Tally")
	assert_bool(MapTable.tally_unlocked(SaveManager.save)).is_false()
	assert_bool(tally.visible).is_false()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	assert_bool(tally.visible).is_false()  # At the map without the card: still none.
	assert_object(table._arrive_tween).is_null()
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	assert_str(MapTable.TALLY_CARD).is_equal("map_readout")
	assert_bool(MapTable.tally_unlocked(SaveManager.save)).is_true()
	table._process(0.0)
	assert_object(table._arrive_tween).is_not_null()


func test_the_holdings_indicator_drops_into_its_place_with_a_thud_the_next_time_the_camera_is_at_the_map() -> void:
	var table := _table()
	var tally: Node3D = table.get_node("Tally")
	var rest := tally.position
	var thud := table.get_node("TallyArrive") as SoundCue
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()  # At the desk nothing arrives: nobody would see it.
	assert_bool(tally.visible).is_false()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	table._arrive_tween.custom_step(MapTable.ARRIVE_AFTER + 0.01)
	assert_bool(tally.visible).is_true()
	assert_float(tally.position.y).is_greater(rest.y + 0.3)  # In the air.
	assert_bool(thud.playing).is_false()
	table._arrive_tween.custom_step(MapTable.ARRIVE_TIME + 0.01)
	assert_bool(thud.playing).is_true()
	_land(table)
	assert_bool(tally.position.is_equal_approx(rest)).is_true()
	assert_bool(tally.scale.is_equal_approx(Vector3.ONE)).is_true()
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()  # It arrives once.


func test_a_save_with_the_holdings_indicators_card_stamped_has_it_on_the_table_without_an_arrival() -> void:
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	var table := _table()
	assert_bool((table.get_node("Tally") as Node3D).visible).is_true()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()
	assert_bool((table.get_node("TallyArrive") as SoundCue).playing).is_false()


func test_the_holdings_indicator_stands_where_the_loose_buttons_stood_and_clear_of_the_sheet() -> void:
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	var table := _table()
	var tally: Node3D = table.get_node("Tally")
	var box := tally.global_transform * (tally.get_node("Model") as MeshInstance3D).get_aabb()
	var button: Node3D = table.get_node("DeskButton")
	var plinth := button.global_transform * (button.get_node("Plinth") as MeshInstance3D).get_aabb()
	# Screen-up is +X (the wall), screen-right is +Z: its console reaches up to the loose buttons'
	# place, left of the paper (z 0.15).
	assert_float(box.end.x).is_greater(plinth.get_center().x)
	assert_float(box.end.z).is_less(0.15 - 0.03)
	assert_float(plinth.end.z).is_less(0.15 - 0.03)
	for corner: Vector3 in [box.position, box.end, plinth.position, plinth.end]:
		var at := _on_screen(table, Vector3(corner.x, box.end.y, corner.z))
		assert_float(maxf(absf(at.x), absf(at.y))).override_failure_message("%s is off the screen" % corner).is_less(0.98)
	# The weights hop aside during a swap: none lands on the button or the tally.
	for weight: Node3D in table.get_node("Weights").get_children():
		var aside := weight.position + Vector3(0.0, 0.0, signf(weight.position.z - 1.75) * MapTable.WEIGHT_ASIDE)
		for prop: AABB in [box, plinth]:
			assert_bool(prop.grow(0.061).has_point(Vector3(aside.x, prop.get_center().y, aside.z))).is_false()


func test_the_corners_work_light_is_off_at_the_desk_and_on_at_the_map() -> void:
	var table := _table()
	var key: Light3D = table.get_node("Lights/Key")
	assert_bool(key.visible).is_false()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	assert_bool(key.visible).is_true()
	assert_float(key.light_energy).is_greater(1.0)
	assert_bool(key.shadow_enabled).is_true()
	table.back_to_desk()
	table._pan_tween.custom_step(10.0)
	assert_bool(key.visible).is_false()


func test_the_work_light_is_cold_and_desaturated_never_warm() -> void:
	var table := _table()
	for light: Light3D in table.get_node("Lights").get_children():
		assert_float(light.light_color.b).is_greater(light.light_color.r)
		assert_float(light.light_color.s).is_less(0.3)


func test_esc_brings_the_camera_home_from_the_map_and_is_not_taken_at_the_desk() -> void:
	var table := _table()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	table._input(esc)  # On the desk: not ours.
	assert_object(table._pan_tween).is_null()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._input(esc)
	table._pan_tween.custom_step(10.0)
	assert_bool(FarmTv.away).is_false()
	assert_bool(_camera.transform.is_equal_approx(DESK)).is_true()


func test_a_ray_at_the_open_sheet_gives_its_art_pixel_and_one_beside_it_or_during_a_swap_gives_none() -> void:
	var table := _table_with_world()
	var eye: Vector3 = table.get_node("View").global_position
	var site := table.sheet_of(HOME).point_at(Vector2(1564, 994))  # Farm site K-1.
	assert_bool(table.sheet_pixel(eye, site - eye).is_equal_approx(Vector2(1564, 994))).is_true()
	assert_vector(table.sheet_pixel(eye, Vector3(4.5, 0.75, -0.2) - eye)).is_equal(Vector2(-1, -1))  # The desk beside it.
	assert_vector(table.sheet_pixel(eye, Vector3.UP)).is_equal(Vector2(-1, -1))
	table.show_sheet(&"world")
	assert_vector(table.sheet_pixel(eye, site - eye)).is_equal(Vector2(-1, -1))
	_finish(table)
	assert_bool(table.sheet_pixel(eye, site - eye).is_equal_approx(Vector2(1564, 994))).is_true()  # The same spot of the world sheet.


func test_the_camera_counts_as_away_from_leaving_for_the_map_until_it_is_home_again() -> void:
	var table := _table()
	assert_bool(table.is_away()).is_false()
	table.go_to_map()
	assert_bool(table.is_away()).is_true()
	table._pan_tween.custom_step(10.0)
	table.back_to_desk()
	table._pan_tween.custom_step(MapTable.PAN_TIME * 0.5)
	assert_bool(table.is_away()).is_true()
	table._pan_tween.custom_step(10.0)
	assert_bool(table.is_away()).is_false()
	# Kept at the desk by the farm TV: never away at the map.
	FarmTv.away = true
	table.go_to_map()
	assert_bool(table.is_away()).is_false()


func test_a_click_on_a_farm_site_at_the_map_lays_out_its_deed_and_a_click_on_its_stamp_box_buys_the_farm() -> void:
	SaveManager.save.coins = 1000000
	SaveManager.save.storage_cap = 5000
	SaveManager.save.stock = 5000
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var country := table.sheet_of(HOME) as FarmRegister
	var at := _camera.unproject_position(country.point_at(_k1(country)))
	var move := InputEventMouseMotion.new()
	move.position = at
	table._input(move)
	assert_str(table._hovered).is_equal(&"K-1")
	assert_str(table._hint.text).contains(country.hint(&"K-1").get_slice(".", 0))
	assert_str(table._hint.text).contains("84K")  # K-1, beside the head office (FarmRegister.WORTH)
	var click := InputEventMouseButton.new()
	click.position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	table._input(click)
	assert_array(Array(SaveManager.save.farms_owned)).is_empty()  # The click only lays out the deed.
	assert_str(country.deed_site()).is_equal(&"K-1")
	table._process(0.0)
	assert_bool(table._hint.visible).is_false()  # The deed says it all: no slip over it.
	click.position = _camera.unproject_position(country.point_at(country._deed_corner + FarmDeed.STAMP_BOX.get_center()))
	table._input(click)
	assert_str(table._hovered).is_equal(FarmRegister.STAMP)
	assert_array(Array(SaveManager.save.farms_owned)).is_equal(["K-1"])
	assert_int(SaveManager.save.coins).is_equal(1000000 - roundi(FarmRegister.PRICES[0].coins * FarmRegister.worth(&"K-1")))
	country._dealing.custom_step(10.0)
	move.position = at
	table._input(move)
	table._process(0.0)
	assert_str(table._hovered).is_equal(&"")  # Ours now: the farm no longer reacts to the mouse.
	assert_bool(table._hint.visible).is_false()
	table.back_to_desk()
	assert_str(country._hot).is_equal(&"")  # Let down when the camera leaves.


func test_a_sheet_is_not_rolled_up_while_a_purchase_plays_out_on_it() -> void:
	SaveManager.save.coins = 1000000
	SaveManager.save.storage_cap = 5000
	SaveManager.save.stock = 5000
	var table := _table_with_world()
	var country := table.sheet_of(HOME) as FarmRegister
	assert_bool(country.busy()).is_false()
	country.press(&"K-1")
	country.press(FarmRegister.STAMP)
	assert_bool(country.busy()).is_true()
	table.show_sheet(&"world")
	assert_bool(table.swapping).is_false()
	assert_str(table.shown).is_equal(HOME)
	country._dealing.custom_step(10.0)  # The deed has left: the token stands, owned, on the open sheet.
	assert_bool(country.busy()).is_false()
	table.show_sheet(&"world")
	assert_str(table.shown).is_equal(&"world")


func test_a_click_on_the_bare_sheet_at_the_map_puts_the_deed_away() -> void:
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var country := table.sheet_of(HOME) as FarmRegister
	var click := InputEventMouseButton.new()
	click.position = _camera.unproject_position(country.point_at(_k1(country)))
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	table._input(click)
	assert_str(country.deed_site()).is_equal(&"K-1")
	click.position = _camera.unproject_position(country.point_at(Vector2(2600, 1000)))  # The sea.
	table._input(click)
	assert_str(table._hovered).is_equal(&"")
	assert_str(country.deed_site()).is_equal(&"")


func test_every_sound_moment_of_the_map_table_has_its_sound() -> void:
	var table := _table()
	for cue: String in ["Swap", "Arrive", "ViewIn", "ViewOut", "Hover", "DeskButton/Press"]:
		assert_object((table.get_node(cue) as SoundCue).stream).override_failure_message(cue).is_not_null()


func test_a_swap_sounds_from_its_first_step_and_asking_for_the_open_sheet_is_silent() -> void:
	var table := _table_with_world()
	var swap := table.get_node("Swap") as SoundCue
	table.show_sheet(table.shown)
	assert_bool(swap.playing).is_false()
	table.show_sheet(&"world")
	assert_bool(swap.playing).is_true()


func test_the_work_light_sounds_coming_up_and_clicks_off_when_it_starts_to_dim_on_the_way_home() -> void:
	var table := _table()
	var off := table.get_node("ViewOut") as SoundCue
	table.go_to_map()
	assert_bool((table.get_node("ViewIn") as SoundCue).playing).is_true()
	table._pan_tween.custom_step(10.0)
	table.back_to_desk()
	assert_bool(off.playing).is_false()  # The light is still full: the camera has only just left.
	table._pan_tween.custom_step(MapTable.light_off_after(1.0) + 0.01)
	assert_bool(off.playing).is_true()
	assert_float(MapTable.light_off_after(1.0)).is_equal_approx(MapTable.PAN_TIME * (1.0 - MapTable.LIGHT_FULL), 0.0001)
	assert_float(MapTable.light_off_after(0.3)).is_zero()  # Turned back early, the light is already dimming.


func test_the_to_desk_button_clacks_when_pressed() -> void:
	var table := _table()
	var button: Node3D = table.get_node("DeskButton")
	button.press()
	assert_bool((button.get_node("Press") as SoundCue).playing).is_true()


func test_what_stands_on_a_sheet_is_tucked_away_while_it_is_rolled_and_stands_once_it_lies_open() -> void:
	var table := _table_with_world()
	var country := table.sheet_of(HOME)
	var world := table.sheet_of(&"world")
	assert_int(country.thing_count()).is_greater(0)
	for i in country.thing_count():
		assert_bool(country.thing_up(i)).is_true()
	for i in world.thing_count():
		assert_bool(world.thing_up(i)).is_false()
	table.show_sheet(&"world")
	_finish(table)
	for i in country.thing_count():
		assert_bool(country.thing_up(i)).is_false()
	for i in world.thing_count():
		assert_bool(world.thing_up(i)).is_true()


func test_the_things_are_tucked_away_before_the_sheet_starts_to_roll() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	table._swap_tween.custom_step(MapTable.ROLL_UP_AT)
	var country := table.sheet_of(HOME)
	assert_float(country.open).is_equal(1.0)
	assert_bool(country.thing_up(0)).is_false()  # The first of the wave is already down.


## The map table and the farm TV wired to each other, as in MainStoryWorld.
func _table_and_tv() -> Array:
	SaveManager.save.stamped.append("family_farm")
	var tv: FarmTv = auto_free(load("res://entities/farm_tv/farm_tv.tscn").instantiate())
	add_child(tv)
	var table := _table()
	table.farm_tv = tv
	tv.map = table
	return [table, tv]


func _ray_at(marker: Node3D) -> Array:
	var at := marker.global_position
	return [at + Vector3.UP, Vector3.DOWN]


func test_to_farm_stands_above_to_desk_only_once_the_farm_shortcut_card_is_stamped() -> void:
	var table := _table()
	var farm: Node3D = table.get_node("FarmButton/Plate")
	var ray := _ray_at(farm)
	assert_bool(table.get_node("FarmButton").visible).is_false()
	assert_str(table.pick(ray[0], ray[1])).is_not_equal(MapTable.FARM)
	SaveManager.save.stamped.append(MapTable.SHORTCUT_CARD)
	table._process(0.0)
	assert_bool(table.get_node("FarmButton").visible).is_true()
	assert_str(table.pick(ray[0], ray[1])).is_equal(MapTable.FARM)
	var back := _ray_at(table.get_node("DeskButton/Plate"))
	assert_str(table.pick(back[0], back[1])).is_equal(MapTable.BACK)  # TO DESK is still TO DESK.
	# On top of it in the map view: further up the screen (+X), on the same column, its plates apart.
	var desk_button: Node3D = table.get_node("DeskButton")
	var farm_button: Node3D = table.get_node("FarmButton")
	assert_float(farm_button.position.x - desk_button.position.x).is_greater(MapTable.BACK_HALF.y * 2.0)
	assert_float(farm_button.position.z).is_equal_approx(desk_button.position.z, 0.001)
	assert_str((farm_button.get_node("Stencil") as Label3D).text).is_equal("TO FARM")


## The map table and the farm TV wired, the shortcut stamped, the camera at the map.
func _shortcut_at_map() -> Array:
	var both := _table_and_tv()
	SaveManager.save.stamped.append(MapTable.SHORTCUT_CARD)
	var table: MapTable = both[0]
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	return both


func test_the_shortcut_to_the_farm_dips_to_dark_instead_of_flying_across_the_room() -> void:
	var both := _shortcut_at_map()
	var table: MapTable = both[0]
	var tv: FarmTv = both[1]
	var dark: ColorRect = tv.get_node("Dip/Dark")
	var at_map := _camera.transform
	table.to_farm()
	assert_bool(FarmTv.away).is_true()
	tv._dip_tween.custom_step(FarmTv.DIP_OUT * 0.5)
	# Going dark, and the camera has not moved at all.
	assert_float(dark.color.a).is_between(0.2, 0.8)
	assert_bool(_camera.transform.is_equal_approx(at_map)).is_true()
	tv._dip_tween.custom_step(FarmTv.DIP_OUT * 0.5 + 0.001)
	# Dark: the camera has cut to the last small stretch of the desk's own glide to the TV.
	assert_float(dark.color.a).is_greater(0.95)
	var view := get_viewport().get_visible_rect().size
	var tv_view := FarmTv.tv_view(tv.screen_frame(), view.x / view.y)
	assert_bool(_camera.transform.is_equal_approx(FarmTv.view_at(table._desk_view, tv_view, FarmTv.SETTLE_FROM))).is_true()
	assert_float(_camera.transform.origin.distance_to(tv_view.origin)).is_less(0.25)


func test_the_shortcut_ends_at_the_farm_view() -> void:
	var both := _shortcut_at_map()
	var table: MapTable = both[0]
	var tv: FarmTv = both[1]
	table.to_farm()
	tv._dip_tween.custom_step(10.0)
	tv._tween.custom_step(10.0)
	table._process(0.0)
	var view := get_viewport().get_visible_rect().size
	assert_bool(_camera.transform.is_equal_approx(FarmTv.tv_view(tv.screen_frame(), view.x / view.y))).is_true()
	assert_float((tv.get_node("Dip/Dark") as ColorRect).color.a).is_equal(0.0)
	assert_bool(table.is_away()).is_false()
	assert_bool((table.get_node("Lights/Key") as Light3D).visible).is_false()  # The map's light is off.
	assert_bool(FarmTv.away).is_true()  # At the TV: the hand stays away.


func test_esc_during_the_shortcut_to_the_farm_does_not_jump_the_camera() -> void:
	var both := _shortcut_at_map()
	var table: MapTable = both[0]
	var tv: FarmTv = both[1]
	var at_map := _camera.transform
	table.to_farm()
	tv._dip_tween.custom_step(FarmTv.DIP_OUT * 0.5)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	table._input(esc)  # The map has let go: nothing.
	tv._input(esc)  # The dip eats it.
	assert_bool(_camera.transform.is_equal_approx(at_map)).is_true()
	assert_bool(tv.dipping()).is_true()
	tv._dip_tween.custom_step(10.0)
	tv._tween.custom_step(10.0)
	var view := get_viewport().get_visible_rect().size
	assert_bool(_camera.transform.is_equal_approx(FarmTv.tv_view(tv.screen_frame(), view.x / view.y))).is_true()


func test_the_first_farm_bought_takes_the_camera_to_the_farm_tv_once_its_deed_has_left_and_later_ones_do_not() -> void:
	var both := _table_and_tv()  # No shortcut card: TO FARM is not on the table yet.
	var table: MapTable = both[0]
	var tv: FarmTv = both[1]
	var save := SaveManager.save
	save.stamped.append_array(["negotiation", "bribery"])
	save.coins = 10000000
	save.coin_limit = 100000000
	save.storage_cap = 30000
	save.stock = 30000
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var country := table.sheet_of(HOME) as FarmRegister
	country.press(&"K-4")
	country.press(FarmRegister.STAMP)
	country._dealing.custom_step(FarmRegister.deed_gone_after() - 0.05)
	assert_bool(tv.dipping()).is_false()  # The acquisition is seen at the map first.
	country._dealing.custom_step(0.1)
	assert_bool(tv.dipping()).is_true()  # The same dip as TO FARM.
	tv._dip_tween.custom_step(10.0)
	tv._tween.custom_step(10.0)
	assert_bool(table.is_away()).is_false()
	assert_bool(tv._at_tv).is_true()
	tv._pan(false)  # Back at the desk, then at the map for the second farm.
	tv._tween.custom_step(10.0)
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	country.press(&"K-6")
	country.press(FarmRegister.STAMP)
	country._dealing.custom_step(10.0)
	assert_bool(tv.dipping()).is_false()
	assert_bool(table.is_away()).is_true()


func test_to_farm_does_nothing_without_a_farm_tv_to_go_to() -> void:
	var table := _table()
	SaveManager.save.stamped.append(MapTable.SHORTCUT_CARD)
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table.to_farm()  # No farm TV wired: the camera stays at the map.
	assert_bool(table.is_away()).is_true()


func test_the_depot_stays_away_until_hostile_acquisitions_are_authorised() -> void:
	var table := _table()
	_at_map(table)
	assert_bool((table.get_node("Depot") as Node3D).visible).is_false()
	assert_bool(MapTable.sheet_unlocked(MapTable.DEPOT, SaveManager.save)).is_false()
	table.open_depot()
	_finish(table)
	assert_str(table.shown).is_equal(HOME)


func test_the_depot_drops_in_the_first_time_the_camera_is_at_the_map_and_only_then() -> void:
	SaveManager.save.stamped.append("war_mode")
	var table := _table()
	var depot := table.get_node("Depot") as Depot
	assert_bool(depot.visible).is_false()  # Not at the desk.
	_at_map(table)
	assert_bool(depot.dropping()).is_true()
	assert_bool(SaveManager.save.depot_dropped).is_true()
	depot._drop_tween.custom_step(10.0)
	assert_bool(depot.visible).is_true()
	assert_bool((depot.get_node("Drop") as SoundCue).playing).is_true()
	table.queue_free()
	FarmTv.away = false
	var again := _table()  # A reload: it stands there already, without the moment.
	assert_bool((again.get_node("Depot") as Node3D).visible).is_true()
	_at_map(again)
	assert_bool((again.get_node("Depot") as Depot).dropping()).is_false()


func test_the_depot_stands_right_of_the_sheet_and_whole_inside_the_frame_at_16_9() -> void:
	var table := _table()
	var depot := table.get_node("Depot") as Node3D
	var box := depot.global_transform * (depot.get_node("Body") as MeshInstance3D).get_aabb()
	assert_float(box.position.z).is_greater(3.29)  # Right of the paper's printed frame.
	for corner: Vector3 in [box.position, box.end, Vector3(box.position.x, box.end.y, box.end.z), Vector3(box.end.x, box.end.y, box.position.z)]:
		var at := _on_screen(table, corner)
		assert_float(maxf(absf(at.x), absf(at.y))).override_failure_message("%s is off the screen" % corner).is_less(0.98)


func test_a_click_on_the_depot_rolls_out_the_depot_sheet_and_the_holder_leads_back() -> void:
	SaveManager.save.stamped.append("war_mode")
	SaveManager.save.depot_dropped = true
	var table := _table()
	_at_map(table)
	var depot := (table.get_node("Depot") as Node3D).global_position + Vector3.UP * 0.06
	assert_str(table.pick(_camera.project_ray_origin(_camera.unproject_position(depot)), _camera.project_ray_normal(_camera.unproject_position(depot)))).is_equal(MapTable.DEPOT)
	_click(table, _camera.unproject_position(depot))
	_finish(table)
	assert_str(table.shown).is_equal(MapTable.DEPOT)
	assert_str(table.held()).is_equal(HOME)  # The sheet it replaced, rolled up: the way back.
	assert_str(SaveManager.save.map_sheet).is_equal(String(HOME))  # A reload opens the country again.
	_at_map(table)
	_click(table, _camera.unproject_position(table.get_node("Holder/Slot").global_position))
	_finish(table)
	assert_str(table.shown).is_equal(HOME)
	assert_str(table.held()).is_equal(&"")


func test_a_click_on_the_depot_while_its_sheet_is_open_brings_back_the_map_it_was_opened_from() -> void:
	SaveManager.save.stamped.append("war_mode")
	SaveManager.save.depot_dropped = true
	var table := _table()
	_at_map(table)
	table.open_depot()
	_finish(table)
	assert_str(table.shown).is_equal(MapTable.DEPOT)
	table.hover_spot(MapTable.DEPOT)
	assert_str(table._hint.text).is_equal("Back to the map")
	table.open_depot()
	_finish(table)
	assert_str(table.shown).is_equal(HOME)
	assert_str(table.held()).is_equal(&"")
	table.hover_spot(&"")
	table.hover_spot(MapTable.DEPOT)
	assert_str(table._hint.text).is_equal("Personnel depot")


func test_staff_train_every_frame_wherever_the_camera_is() -> void:
	SaveManager.save.stamped.append("war_mode")
	SaveManager.save.storage_cap = 100000
	SaveManager.save.stock = 50000
	var table := _table()
	assert_bool(WarRules.buy(SaveManager.save, "field_associate")).is_true()
	table._process(WarRules.training_seconds(SaveManager.save, "field_associate") + 0.1)  # At the desk.
	assert_dict(SaveManager.save.army).is_equal({field_associate = 1})
	assert_bool(SaveManager.save.army_training.is_empty()).is_true()


func test_the_camera_glides_in_on_the_negotiation_letter_without_rolling_and_back_when_it_closes() -> void:
	SaveManager.save.coins = 1000000
	SaveManager.save.storage_cap = 5000
	SaveManager.save.stock = 5000
	SaveManager.save.stamped.append("negotiation")
	SaveManager.save.farms_owned = PackedStringArray(["K-1"])
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var map_view := _camera.transform
	var country := table.sheet_of(HOME) as FarmRegister
	country.press(&"K-2")
	table._process(0.0)
	assert_float(table._zoom).is_equal(0.0)  # The deed alone: no glide.
	country.press(FarmRegister.HAGGLE)
	table._process(0.0)
	table._zoom_tween.custom_step(FarmRegister.DEED_SLIDE_TIME)
	assert_float(table._zoom).is_between(0.01, 0.99)  # Eased, not a jump.
	table._zoom_tween.custom_step(MapTable.FOCUS_TIME)
	assert_float(table._zoom).is_equal(1.0)
	assert_float(_camera.quaternion.angle_to(map_view.basis.get_rotation_quaternion())).is_less(0.001)  # No roll, no turn.
	assert_float(_camera.position.distance_to(map_view.origin)).is_greater(0.3)  # Closer in.
	# The letter fills most of the screen now: its corners are on screen, far apart.
	var corners := country.focus()
	var size := table.get_viewport().get_visible_rect().size
	var ys: Array[float] = []
	for corner in corners:
		var at := _camera.unproject_position(corner)
		assert_bool(Rect2(Vector2.ZERO, size).grow(1.0).has_point(at)).override_failure_message(str(at)).is_true()
		ys.append(at.y)
	assert_float(ys.max() - ys.min()).is_greater(size.y * 0.8)
	# Clicks still find the letter's boxes through the moved camera.
	var deed := country.get_node("Deed") as FarmDeed
	deed._moving.custom_step(10.0)
	deed._haggle_moving.custom_step(10.0)  # The letter at rest, where the camera glided to.
	var hit_at := _camera.unproject_position((country.get_node("Deed/Haggle") as Node3D).global_transform * NegotiationLetter.point(NegotiationLetter.SEND_BOX.get_center()))
	var move := InputEventMouseMotion.new()
	move.position = hit_at
	table._input(move)
	assert_bool(table._hovered == FarmRegister.SEND).override_failure_message("hovered [%s] at %s" % [table._hovered, hit_at]).is_true()
	country.press(FarmRegister.RETURN)  # The letter goes: the camera glides back.
	table._process(0.0)
	table._zoom_tween.custom_step(MapTable.FOCUS_TIME)
	assert_float(table._zoom).is_equal(0.0)
	assert_bool(_camera.transform.is_equal_approx(map_view)).is_true()


func test_before_the_holdings_indicator_the_buttons_stand_alone() -> void:
	SaveManager.save.stamped.append(MapTable.SHORTCUT_CARD)
	var table := _table()
	_at_map(table)
	assert_bool((table.get_node("Tally") as Node3D).visible).is_false()
	assert_bool((table.get_node("DeskButton") as Node3D).visible).is_true()
	assert_bool((table.get_node("FarmButton") as Node3D).visible).is_true()
	assert_array(table.buttons()).is_equal([table.get_node("DeskButton"), table.get_node("FarmButton")])
	var back := _ray_at(table.get_node("DeskButton/Plate"))
	assert_str(table.pick(back[0], back[1])).is_equal(MapTable.BACK)


func test_with_the_holdings_indicator_the_buttons_sit_on_its_console() -> void:
	SaveManager.save.stamped.append_array([MapTable.TALLY_CARD, MapTable.SHORTCUT_CARD])
	var table := _table()
	_at_map(table)
	var tally: Node3D = table.get_node("Tally")
	var desk: Node3D = tally.get_node("Console/DeskButton")
	var farm: Node3D = tally.get_node("Console/FarmButton")
	assert_bool((table.get_node("DeskButton") as Node3D).visible).is_false()
	assert_bool((table.get_node("FarmButton") as Node3D).visible).is_false()
	assert_bool(desk.is_visible_in_tree()).is_true()
	assert_bool(farm.is_visible_in_tree()).is_true()
	assert_array(table.buttons()).is_equal([desk, farm])
	# On the tally's own housing, above its windows (screen-up is +X), TO FARM above TO DESK.
	var box := tally.global_transform * (tally.get_node("Model") as MeshInstance3D).get_aabb()
	for button: Node3D in [desk, farm]:
		assert_bool(box.has_point(button.global_position)).is_true()
		assert_float(button.global_position.x).is_greater((tally.get_node("Windows/Coins") as Node3D).global_position.x)
	assert_float(farm.global_position.x - desk.global_position.x).is_greater(MapTable.BACK_HALF.y * 2.0)
	assert_str((farm.get_node("Stencil") as Label3D).text).is_equal("TO FARM")


func test_the_console_takes_the_buttons_over_at_the_holdings_indicators_landing_thud() -> void:
	var table := _table()
	_at_map(table)
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	table._process(0.0)
	table._arrive_tween.custom_step(MapTable.ARRIVE_AFTER + 0.01)
	assert_bool((table.get_node("DeskButton") as Node3D).visible).is_true()  # Still loose while it falls.
	assert_array(table.buttons()).is_equal([table.get_node("DeskButton"), table.get_node("FarmButton")])
	table._arrive_tween.custom_step(MapTable.ARRIVE_TIME + 0.01)
	assert_bool((table.get_node("TallyArrive") as SoundCue).playing).is_true()
	assert_bool((table.get_node("DeskButton") as Node3D).visible).is_false()
	assert_object(table.buttons()[0]).is_same(table.get_node("Tally/Console/DeskButton"))


func test_to_farm_on_the_console_shows_only_after_its_card() -> void:
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	var table := _table()
	_at_map(table)
	var farm: Node3D = table.get_node("Tally/Console/FarmButton")
	var ray := _ray_at(farm.get_node("Plate"))
	# Its socket stands blanked off: no cap, a bare plate, and nothing to click.
	assert_bool(farm.is_visible_in_tree()).is_true()
	assert_bool((farm.get_node("Button") as Node3D).visible).is_false()
	assert_bool((farm.get_node("Stencil") as Node3D).visible).is_false()
	assert_str(table.pick(ray[0], ray[1])).is_not_equal(MapTable.FARM)
	SaveManager.save.stamped.append(MapTable.SHORTCUT_CARD)
	table._process(0.0)
	assert_bool((farm.get_node("Button") as Node3D).visible).is_true()
	assert_bool((farm.get_node("Stencil") as Node3D).visible).is_true()
	assert_str(table.pick(ray[0], ray[1])).is_equal(MapTable.FARM)
	assert_bool((table.get_node("FarmButton") as Node3D).visible).is_false()  # Not the loose one.


func test_the_console_buttons_still_take_the_camera_where_they_say() -> void:
	SaveManager.save.stamped.append(MapTable.TALLY_CARD)
	var both := _shortcut_at_map()
	var table: MapTable = both[0]
	var tv: FarmTv = both[1]
	table._process(0.0)
	var desk: Node3D = table.get_node("Tally/Console/DeskButton")
	var farm: Node3D = table.get_node("Tally/Console/FarmButton")
	# Hovered, a plate's stencil lightens and its slip says where it goes.
	var hover := InputEventMouseMotion.new()
	hover.position = _camera.unproject_position((farm.get_node("Plate") as Node3D).global_position)
	table._input(hover)
	assert_str(table._hovered).is_equal(MapTable.FARM)
	assert_str((table.get_node("HintLayer/Hint") as Label).text).is_equal("Straight to the farm")
	assert_float((farm.get_node("Stencil") as Label3D).modulate.v).is_greater((desk.get_node("Stencil") as Label3D).modulate.v)
	_click(table, hover.position)
	assert_bool(tv.dipping()).is_true()  # TO FARM: the dip to the farm TV.
	await get_tree().create_timer(desk.PRESS_TIME * desk.DOWN).timeout
	assert_float((farm.get_node("Button") as Node3D).position.y).is_less(0.0)
	tv._dip_tween.custom_step(10.0)
	tv._tween.custom_step(10.0)
	# Back at the map, TO DESK on the console glides home.
	table.arrive()
	table._pan_tween.custom_step(10.0)
	var back := _camera.unproject_position((desk.get_node("Plate") as Node3D).global_position)
	hover.position = back
	table._input(hover)
	assert_str((table.get_node("HintLayer/Hint") as Label).text).is_equal("Back to the desk")
	_click(table, back)
	assert_bool(table._at_map).is_false()
	assert_bool((desk.get_node("Press") as SoundCue).playing).is_true()


func test_the_depot_research_tree_hovers_with_its_own_popup_and_the_map_shows_no_hint_slip() -> void:
	SaveManager.save.stamped.append("war_mode")
	SaveManager.save.depot_dropped = true
	var table := _table()
	_at_map(table)
	table.open_depot()
	_finish(table)
	var sheet := table.sheet_of(MapTable.DEPOT) as DepotSheet
	var tree := sheet.get_node("Page/Sheet/Tree") as UpgradeTree
	var wheel: Array = tree._wheel()
	var node: Vector2 = sheet._art_rect(tree).position + wheel[0] + DepotResearch.node_data("fa_hp_1").at * wheel[1]
	var move := InputEventMouseMotion.new()
	move.position = _camera.unproject_position(sheet.point_at(node))
	tree._process(0.0)  # Lays the tree out (which nodes show).
	tree._hover(node - sheet._art_rect(tree).position)  # What the page's GUI hands the tree (it takes pushed input on its next frame).
	table._input(move)
	table._process(0.0)
	assert_str(tree._hovered).is_equal("fa_hp_1")  # The tree's own popup names it.
	assert_bool(table._hint.visible).is_false()
	move.position = _camera.unproject_position(sheet.point_at(Vector2(2600, 700)))  # Bare paper.
	table._input(move)
	table._process(0.0)
	assert_bool(table._hint.visible).is_false()


func test_the_depot_hire_hint_lies_beside_the_hovered_columns_button_on_the_left_and_on_the_right() -> void:
	SaveManager.save.stamped.append_array(["war_mode", "unit_charge", "unit_senior", "unit_pult", "unit_courier"])
	SaveManager.save.depot_dropped = true
	var table := _table()
	_at_map(table)
	table.open_depot()
	_finish(table)
	var sheet := table.sheet_of(MapTable.DEPOT) as DepotSheet
	# The test window is square: the courier column lies past its edge, so the pult crew stands in for the right.
	for unit: String in ["field_associate", "pult_crew"]:
		var spot := StringName("buy:" + unit)
		var move := InputEventMouseMotion.new()
		move.position = _camera.unproject_position(sheet.point_at(sheet._art_rect(sheet._columns[unit].get_node("Hire")).get_center()))
		table._input(move)
		table._process(0.0)
		assert_str(table._hovered).is_equal(spot)
		assert_bool(table._hint.visible).is_true()
		var slip := Rect2(table._hint.position, table._hint.size)
		var box := table._on_screen_box(sheet, sheet.spot_box(spot))
		assert_bool(slip.intersects(box)).override_failure_message(unit + ": covers its button").is_false()
		assert_bool(slip.grow(MapTable.HINT_GAP + 2.0).intersects(box)).override_failure_message(unit + ": not beside it").is_true()

