extends GdUnitTestSuite

const SCENE := "res://entities/map_table/map_table.tscn"
const DESK := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))

var _real_save: SaveGame
var _camera: Camera3D


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = _chapter_3()
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


func _chapter_3() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["consolidation"])
	return save


func _table() -> MapTable:
	var table: MapTable = auto_free(load(SCENE).instantiate())
	add_child(table)
	return table


## The table of a save with the world map card stamped: the world sheet's roll is in the rack.
func _table_with_world() -> MapTable:
	SaveManager.save.stamped.append("world_map")
	return _table()


## Runs a sheet's arrival in progress to its end.
func _land(table: MapTable) -> void:
	if table._arrive_tween != null:
		table._arrive_tween.custom_step(10.0)


## Runs the swap in progress to its end, and any swap queued behind it.
func _finish(table: MapTable) -> void:
	for i in 4:
		if table.swapping:
			table._swap_tween.custom_step(10.0)


func _lying_open(table: MapTable) -> Array[StringName]:
	var out: Array[StringName] = []
	for sheet in table.sheets():
		if sheet.open > 0.0:
			out.append(sheet.id)
	return out


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


func test_only_the_country_sheet_is_on_the_map_table_when_it_opens() -> void:
	var table := _table()
	assert_array(_lying_open(table)).is_equal([&"country"])
	assert_float(table.sheet_of(&"country").open).is_equal(1.0)
	for sheet in table.sheets():
		assert_bool(table.on_table(sheet.id)).override_failure_message(sheet.id).is_equal(sheet.id == &"country")
		assert_bool(sheet.visible).override_failure_message(sheet.id).is_equal(sheet.id == &"country")


func test_a_locked_sheets_label_holder_in_the_rack_is_blank() -> void:
	var names: Node3D = _table().get_node("Rack/ChartRack/Names")
	assert_bool((names.get_child(0) as Node3D).visible).is_true()  # KOHLMARK, the sheet lying open.
	assert_bool((names.get_child(1) as Node3D).visible).is_false()
	assert_bool((names.get_child(2) as Node3D).visible).is_false()


func test_a_locked_sheet_cannot_be_shown_or_picked() -> void:
	var table := _table()
	var eye: Vector3 = table.get_node("View").global_position
	for id: StringName in [&"world", &"district"]:
		table.show_sheet(id)
		assert_bool(table.swapping).override_failure_message(id).is_false()
		assert_str(table.shown).is_equal(&"country")
	for slot: String in ["Rack/Slot1", "Rack/Slot2"]:
		assert_str(table.pick(eye, table.get_node(slot).global_position - eye)).override_failure_message(slot).is_equal(&"")
	# Asked for during a swap, it is not remembered either. (No swap can run with one sheet: the rule is show_sheet's.)
	assert_str(table._queued).is_equal(&"")


func test_the_world_sheet_comes_with_the_world_map_card_and_the_district_sheet_with_none() -> void:
	var save := _chapter_3()
	assert_bool(MapTable.sheet_unlocked(&"country", save)).is_true()
	assert_bool(MapTable.sheet_unlocked(&"world", save)).is_false()
	save.stamped.append("world_map")
	assert_bool(MapTable.sheet_unlocked(&"world", save)).is_true()
	assert_object(UpgradeDesk.card_data(MapTable.SHEET_CARDS[&"world"])).is_not_null()  # The card exists.
	for card: Dictionary in UpgradeDesk.CARDS:
		save.stamped.append(card.id)
	assert_bool(MapTable.sheet_unlocked(&"district", save)).is_false()


func test_a_save_with_the_world_map_card_stamped_has_the_world_sheet_in_the_rack() -> void:
	var table := _table_with_world()
	var world := table.sheet_of(&"world")
	assert_bool(table.on_table(&"world")).is_true()
	assert_bool(world.visible).is_true()
	assert_object(table._arrive_tween).is_null()  # No arrival: it is there.
	assert_bool(world.get_node("Core").global_position.is_equal_approx(table.get_node("Rack/Slot1").global_position)).is_true()
	assert_bool((table.get_node("Rack/ChartRack/Names").get_child(1) as Node3D).visible).is_true()
	assert_bool((table.get_node("Arrive") as SoundCue).playing).is_false()


func test_stamping_the_world_map_card_puts_the_world_sheet_in_the_rack_the_next_time_the_camera_is_at_the_map() -> void:
	var table := _table()
	var world := table.sheet_of(&"world")
	var arrive := table.get_node("Arrive") as SoundCue
	SaveManager.save.stamped.append("world_map")
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()  # At the desk nothing arrives: nobody would see it.
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	assert_object(table._arrive_tween).is_not_null()
	assert_bool(table.on_table(&"world")).is_false()  # Still in the air: not to be picked yet.
	table.show_sheet(&"world")
	assert_bool(table.swapping).is_false()
	assert_bool(arrive.playing).is_false()
	table._arrive_tween.custom_step(MapTable.ARRIVE_AFTER + MapTable.ARRIVE_TIME + 0.01)
	assert_bool(arrive.playing).is_true()  # The clack as it lands in its saddle.
	assert_bool(world.visible).is_true()
	assert_bool(table.on_table(&"world")).is_true()
	assert_bool((table.get_node("Rack/ChartRack/Names").get_child(1) as Node3D).visible).is_true()
	_land(table)
	assert_bool(world.get_node("Core").global_position.is_equal_approx(table.get_node("Rack/Slot1").global_position)).is_true()
	var eye: Vector3 = table.get_node("View").global_position
	assert_str(table.pick(eye, table.get_node("Rack/Slot1").global_position - eye)).is_equal(&"world")
	table.show_sheet(&"world")
	_finish(table)
	assert_array(_lying_open(table)).is_equal([&"world"])


func test_the_district_sheet_stays_off_the_table() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		SaveManager.save.stamped.append(card.id)
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	table._process(0.0)
	_land(table)
	table._process(0.0)
	assert_object(table._arrive_tween).is_null()
	assert_bool(table.on_table(&"district")).is_false()
	assert_bool(table.sheet_of(&"district").visible).is_false()
	table.show_sheet(&"district")
	assert_str(table.shown).is_equal(&"country")


func test_only_one_sheet_lies_open_at_a_time() -> void:
	var table := _table_with_world()
	for id: StringName in [&"world", &"country", &"world"]:
		table.show_sheet(id)
		_finish(table)
		assert_array(_lying_open(table)).is_equal([id])
		assert_str(table.shown).is_equal(id)
		assert_bool(table.swapping).is_false()


func test_asking_for_the_sheet_that_is_already_out_changes_nothing() -> void:
	var table := _table()
	table.show_sheet(&"country")
	assert_bool(table.swapping).is_false()
	assert_str(table.shown).is_equal(&"country")
	assert_float(table.sheet_of(&"country").open).is_equal(1.0)


func test_asking_for_a_sheet_that_does_not_exist_changes_nothing() -> void:
	var table := _table()
	table.show_sheet(&"moon")
	assert_bool(table.swapping).is_false()
	assert_str(table.shown).is_equal(&"country")


func test_a_swap_asked_for_during_a_swap_waits_and_runs_right_after_it() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	var running := table._swap_tween
	table.show_sheet(&"country")
	assert_object(table._swap_tween).is_same(running)  # The running swap is left alone.
	assert_str(table.shown).is_equal(&"world")
	running.custom_step(10.0)
	assert_bool(table.swapping).is_true()  # The next sheet's swap began as the first one ended.
	assert_str(table.shown).is_equal(&"country")
	_finish(table)
	assert_array(_lying_open(table)).is_equal([&"country"])


func test_of_several_swaps_asked_for_during_a_swap_only_the_last_one_runs() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	table.show_sheet(&"country")
	table.show_sheet(&"district")  # Not on the table: not a request.
	table.show_sheet(&"world")  # Back to the one already on its way: nothing more to do.
	_finish(table)
	assert_bool(table.swapping).is_false()
	assert_array(_lying_open(table)).is_equal([&"world"])


func test_a_rolled_sheet_waits_in_its_own_slot_of_the_rack_at_the_wall() -> void:
	var table := _table_with_world()
	table.show_sheet(&"world")
	_finish(table)
	var lay: Vector3 = table.get_node("Lay").global_position
	var world := table.sheet_of(&"world")
	assert_bool(world.global_position.is_equal_approx(lay)).is_true()
	for sheet in table.sheets():
		if sheet == world:
			continue
		var slot: Vector3 = table.get_node("Rack/Slot%d" % sheet.get_index()).global_position
		assert_float(sheet.global_position.x).is_equal_approx(slot.x, 0.001)
		assert_float(sheet.global_position.y + MapSheet.roll_radius(0.0)).is_equal_approx(slot.y, 0.001)
		assert_float(slot.x).is_greater(lay.x)  # The wall side of the sheet.


func test_a_rolled_sheet_rests_in_its_saddle_clear_of_the_desk_the_wall_and_the_roll_next_to_it() -> void:
	var table := _table_with_world()
	var radius := MapSheet.roll_radius(0.0)
	var slots: Array[Vector3] = []
	for i in 3:
		slots.append(table.get_node("Rack/Slot%d" % i).global_position)
	for sheet in table.sheets():
		if sheet.id != table.shown:  # The roll's middle (its core) lies on its slot.
			assert_bool(sheet.get_node("Core").global_position.is_equal_approx(slots[sheet.get_index()])).is_true()
	for i in 3:
		assert_float(slots[i].y - radius).is_greater(0.75 + 0.01)  # Over the desk top.
		assert_float(slots[i].x + radius).is_less(5.88)  # Short of the wall.
		if i > 0:
			assert_float(slots[i].distance_to(slots[i - 1])).is_greater(2.0 * radius + 0.01)
	# The open sheet's core, on its caps along the top edge, is clear of the lowest roll and of the weights.
	var core: Vector3 = table.sheet_of(table.shown).get_node("Core").global_position
	assert_float(slots[0].x - core.x).is_greater(radius + MapSheet.CAP)
	for weight: Node3D in table.get_node("Weights").get_children():
		assert_float(absf(weight.position.x - core.x)).is_greater(0.061 + 0.028)  # The weight's and the core tube's radius.


func test_the_to_desk_button_goes_in_when_clicked_and_lies_where_the_click_is_taken() -> void:
	var table := _table()
	var button: Node3D = table.get_node("DeskButton")
	var back: Vector3 = table.get_node("Back").global_position
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


func test_the_hint_slip_for_a_farm_site_lies_on_the_sea_clear_of_every_sites_disc_and_tags() -> void:
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var country := table.sheet_of(&"country") as FarmRegister
	var move := InputEventMouseMotion.new()
	move.position = _camera.unproject_position(country.point_at(Vector2(1084, 934)))  # K-1.
	table._input(move)
	table._process(0.0)
	assert_bool(table._hint.visible).is_true()
	var corner := _camera.unproject_position(country.point_at(MapTable.SPOT_HINT_PIXEL))
	assert_bool(table._hint.position.is_equal_approx(corner)).is_true()
	# On the art (1 px = 1 mm): the slip at its width, padded, and six lines tall.
	var art_per_px := 1000.0 / _camera.unproject_position(country.point_at(Vector2(1000, 0))).distance_to(
			_camera.unproject_position(country.point_at(Vector2.ZERO)))
	var slip := Rect2(MapTable.SPOT_HINT_PIXEL, Vector2(MapTable.SPOT_HINT_WIDTH + 20.0, 6.0 * 34.0 + 20.0) * art_per_px)
	assert_bool(MapSheet.on_paper(slip.end)).is_true()
	for thing: MapBuilding in country.get_node("Things").get_children():
		var hit := Rect2(FarmRegister.HIT.position + Vector2(thing.position.x + 1.6, thing.position.z) * 1000.0, FarmRegister.HIT.size)
		assert_bool(slip.intersects(hit)).override_failure_message("the slip covers %s" % thing.title).is_false()


func test_what_stands_on_a_sheet_is_tucked_away_while_it_is_rolled_and_stands_once_it_lies_open() -> void:
	var table := _table_with_world()
	var country := table.sheet_of(&"country")
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
	var country := table.sheet_of(&"country")
	assert_float(country.open).is_equal(1.0)
	assert_bool(country.thing_up(0)).is_false()  # The first of the wave is already down.


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


func test_the_map_view_frames_the_sheet_the_rack_and_the_to_desk_plate_on_every_screen_shape() -> void:
	var table := _table()
	var view: Transform3D = table.get_node("View").global_transform
	var points: Array[Vector3] = [table.get_node("Back").global_position]
	for x: float in [3.6, 5.4]:
		for z: float in [0.15, 3.35]:
			points.append(Vector3(x, 0.75, z))
	for z: float in [0.15, 3.35]:
		points.append(Vector3(5.88, table.get_node("Rack/Slot2").position.y + MapSheet.roll_radius(0.0), z))  # The top roll's ends, at the wall.
	# FramedCamera: the 16:9 frame is always in view (more at the sides when wider, more above and
	# below when narrower).
	var half_h := tan(deg_to_rad(20.0))
	var half_w := half_h * 16.0 / 9.0
	for point in points:
		var local := view.affine_inverse() * point
		assert_float(absf(local.x / -local.z)).override_failure_message("%s is off the side" % point).is_less(half_w * 0.97)
		assert_float(absf(local.y / -local.z)).override_failure_message("%s is off the top or bottom" % point).is_less(half_h * 0.97)


func test_a_click_at_the_map_finds_the_to_desk_plate_the_rolls_in_the_rack_and_the_farm_sites_but_not_the_bare_sheet() -> void:
	var table := _table_with_world()
	var eye: Vector3 = table.get_node("View").global_position
	assert_str(table.pick(eye, table.get_node("Back").global_position - eye)).is_equal(MapTable.BACK)
	assert_str(table.pick(eye, table.get_node("Rack/Slot1").global_position - eye)).is_equal(&"world")
	assert_str(table.pick(eye, table.get_node("Rack/Slot2").global_position - eye)).is_equal(&"")  # No third roll.
	var country := table.sheet_of(&"country")
	assert_str(table.pick(eye, country.point_at(Vector2(300, 300)) - eye)).is_equal(&"")  # The open sheet's sea.
	var site: MapBuilding = country.get_node("Things").get_child(0)
	assert_str(table.pick(eye, site.global_position - eye)).is_equal(site.site)
	assert_str(site.site).is_equal(&"K-1")
	assert_str(table.pick(eye, table.get_node("Rack/Slot0").global_position - eye)).is_equal(&"")  # Its empty slot.


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
	var site := table.sheet_of(&"country").point_at(Vector2(1564, 994))  # Farm site K-1.
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
	var country := table.sheet_of(&"country") as FarmRegister
	var at := _camera.unproject_position(country.point_at(Vector2(1084, 934)))  # K-1.
	var move := InputEventMouseMotion.new()
	move.position = at
	table._input(move)
	assert_str(table._hovered).is_equal(&"K-1")
	assert_str(table._hint.text).contains("Grauhaven Holding")
	assert_str(table._hint.text).contains("60,000")
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
	assert_int(SaveManager.save.coins).is_equal(1000000 - FarmRegister.PRICES[0].coins)
	country._dealing.custom_step(10.0)
	move.position = at
	table._input(move)
	table._process(0.0)
	assert_str(table._hint.text).is_equal(FarmRegister.hint_text(SaveManager.save, &"K-1", "Grauhaven Holding"))  # The slip again: ours.
	table.back_to_desk()
	assert_str(country._hot).is_equal(&"")  # Let down when the camera leaves.


func test_a_sheet_is_not_rolled_up_while_a_purchase_plays_out_on_it() -> void:
	SaveManager.save.coins = 1000000
	SaveManager.save.storage_cap = 5000
	SaveManager.save.stock = 5000
	var table := _table_with_world()
	var country := table.sheet_of(&"country") as FarmRegister
	assert_bool(country.busy()).is_false()
	country.press(&"K-1")
	country.press(FarmRegister.STAMP)
	assert_bool(country.busy()).is_true()
	table.show_sheet(&"world")
	assert_bool(table.swapping).is_false()
	assert_str(table.shown).is_equal(&"country")
	country._dealing.custom_step(10.0)  # The deed has left: the token stands, owned, on the open sheet.
	assert_bool(country.busy()).is_false()
	table.show_sheet(&"world")
	assert_str(table.shown).is_equal(&"world")


func test_a_click_on_the_bare_sheet_at_the_map_puts_the_deed_away() -> void:
	var table := _table()
	table.go_to_map()
	table._pan_tween.custom_step(10.0)
	var country := table.sheet_of(&"country") as FarmRegister
	var click := InputEventMouseButton.new()
	click.position = _camera.unproject_position(country.point_at(Vector2(1084, 934)))  # K-1.
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


func test_whatever_the_mouse_takes_hold_of_at_the_map_gives_a_paper_tick() -> void:
	var table := _table_with_world()
	var hover := table.get_node("Hover") as SoundCue
	assert_bool(hover.playing).is_false()
	table._hover(&"world")
	assert_bool(hover.playing).is_true()


func test_the_to_desk_button_clacks_when_pressed() -> void:
	var table := _table()
	var button: Node3D = table.get_node("DeskButton")
	button.press()
	assert_bool((button.get_node("Press") as SoundCue).playing).is_true()
