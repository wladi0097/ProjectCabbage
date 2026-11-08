extends GdUnitTestSuite

var desk := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))
var screen := Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(-3.75, 1.08, 0.1))
var tv := FarmTv.tv_view(screen)


func test_the_remote_arrives_with_the_family_farm_card() -> void:
	var save := SaveGame.new()
	assert_bool(FarmTv.bought(save)).is_false()
	save.stamped.append("family_farm")
	assert_bool(FarmTv.bought(save)).is_true()


func test_the_tv_view_looks_at_the_glass_nearly_from_the_front_left_of_the_desk() -> void:
	assert_float(-tv.basis.z.y).is_between(-0.25, -0.1)
	assert_float(tv.origin.x).is_less(desk.origin.x)


func test_the_set_fills_most_of_the_views_width_without_the_glass_overfilling_its_height() -> void:
	var half_tan := tan(deg_to_rad(FarmTv.DESK_FOV) / 2.0)
	for aspect: float in [16.0 / 9.0, 21.0 / 9.0]:
		var view := FarmTv.tv_view(screen, aspect)
		var depth := (view.origin - screen.origin).dot(view.basis.z)
		var width := FarmTv.CASE_HALF_W / (depth * half_tan * aspect)
		var height := FarmTv.SCREEN_HALF.y / (depth * half_tan)
		assert_float(width).is_less_equal(FarmTv.WIDTH_FILL + 0.001)
		assert_float(height).is_less_equal(FarmTv.FILL + 0.001)
		assert_float(maxf(width / FarmTv.WIDTH_FILL, height / FarmTv.FILL)).is_equal_approx(1.0, 0.001)
		assert_float(width).override_failure_message("aspect %.2f" % aspect).is_greater(0.65)


func test_the_glass_is_at_least_80_percent_of_the_sets_width() -> void:
	assert_float(FarmTv.SCREEN_HALF.x / FarmTv.CASE_HALF_W).is_greater_equal(0.8)


func test_the_pan_runs_from_the_desk_to_the_tv_and_clamps_beyond() -> void:
	assert_bool(FarmTv.view_at(desk, tv, 0.0).is_equal_approx(desk)).is_true()
	assert_bool(FarmTv.view_at(desk, tv, 1.0).is_equal_approx(tv)).is_true()
	assert_bool(FarmTv.view_at(desk, tv, 2.0).is_equal_approx(tv)).is_true()
	assert_bool(FarmTv.view_at(desk, tv, -1.0).is_equal_approx(desk)).is_true()


func test_the_pan_eases_in_and_is_halfway_at_its_middle() -> void:
	var span := tv.origin.x - desk.origin.x
	assert_float(FarmTv.view_at(desk, tv, 0.5).origin.x).is_equal_approx(desk.origin.x + span / 2.0, 0.0001)
	assert_float(absf(FarmTv.view_at(desk, tv, 0.1).origin.x - desk.origin.x)).is_less(0.1 * absf(span))


func test_a_click_on_the_glass_maps_to_its_uv_from_the_top_left() -> void:
	var centre := FarmTv.glass_uv(screen, tv.origin, screen.origin - tv.origin)
	assert_bool(centre.is_equal_approx(Vector2(0.5, 0.5))).is_true()
	var top_left := screen * Vector3(-FarmTv.SCREEN_HALF.x, FarmTv.SCREEN_HALF.y, 0.0)
	assert_bool(FarmTv.glass_uv(screen, tv.origin, top_left - tv.origin).is_equal_approx(Vector2.ZERO)).is_true()


func test_the_tv_view_is_centred_right_of_the_glass_so_the_back_button_shows() -> void:
	assert_float(FarmTv.glass_uv(screen, tv.origin, -tv.basis.z).x).is_greater(0.5)


func test_only_uvs_between_zero_and_one_are_on_the_glass() -> void:
	assert_bool(FarmTv.on_glass(Vector2(0.5, 0.5))).is_true()
	assert_bool(FarmTv.on_glass(Vector2(1.1, 0.5))).is_false()
	assert_bool(FarmTv.on_glass(Vector2(0.5, -0.01))).is_false()


func test_a_ray_along_the_glass_misses_it() -> void:
	assert_vector(FarmTv.glass_uv(screen, tv.origin, tv.basis.x)).is_equal(Vector2(-1, -1))


func test_the_back_button_is_hit_at_its_centre_and_not_from_the_glass_or_the_views_centre() -> void:
	var back := Transform3D(screen.basis, screen * (FarmTv.BACK_CENTRE - FarmTv.SCREEN_CENTRE))
	assert_bool(FarmTv.on_glass(FarmTv.rect_uv(back, FarmTv.BACK_HALF, tv.origin, back.origin - tv.origin))).is_true()
	assert_bool(FarmTv.on_glass(FarmTv.rect_uv(back, FarmTv.BACK_HALF, tv.origin, screen.origin - tv.origin))).is_false()
	assert_bool(FarmTv.on_glass(FarmTv.rect_uv(back, FarmTv.BACK_HALF, tv.origin, -tv.basis.z))).is_false()


func test_the_crt_warp_keeps_the_centre_and_mid_edges_and_pushes_corners_out() -> void:
	assert_bool(FarmTv.screen_pixel(Vector2(0.5, 0.5)).is_equal_approx(FarmTv.SCREEN_PIXELS / 2.0)).is_true()
	assert_bool(FarmTv.screen_pixel(Vector2(1.0, 0.5)).is_equal_approx(Vector2(FarmTv.SCREEN_PIXELS.x, FarmTv.SCREEN_PIXELS.y / 2.0))).is_true()
	assert_float(FarmTv.screen_pixel(Vector2(1.0, 1.0)).x).is_greater(FarmTv.SCREEN_PIXELS.x)


func test_the_back_button_sits_on_the_narrow_panel_right_of_the_glass() -> void:
	assert_float(FarmTv.BACK_CENTRE.x - FarmTv.BACK_HALF.x).is_greater(FarmTv.SCREEN_CENTRE.x + FarmTv.SCREEN_HALF.x)
	assert_float(FarmTv.BACK_HALF.x).is_less(0.03)


func test_the_tv_lets_the_mouse_through_to_an_open_menu_or_a_boss_report() -> void:
	assert_bool(FarmTv.takes_input(true, false, false)).is_true()
	assert_bool(FarmTv.takes_input(true, false, true)).is_false()
	assert_bool(FarmTv.takes_input(true, true, false)).is_false()
	assert_bool(FarmTv.takes_input(false, false, false)).is_false()


func test_the_back_to_the_desk_hint_hides_while_a_boss_report_is_up() -> void:
	assert_bool(FarmTv.hint_shown(true, false)).is_true()
	assert_bool(FarmTv.hint_shown(true, true)).is_false()
	assert_bool(FarmTv.hint_shown(false, false)).is_false()


func test_the_tv_shows_the_fields_on_channel_one_unless_the_save_says_channel_two() -> void:
	var save := SaveGame.new()
	assert_int(FarmTv.shown_channel(save)).is_equal(1)
	save.farm_channel = 2
	assert_int(FarmTv.shown_channel(save)).is_equal(2)
	save.farm_channel = 7
	assert_int(FarmTv.shown_channel(save)).is_equal(1)


func test_a_ray_at_a_channel_keys_face_hits_it_and_one_at_the_glass_or_the_other_key_misses() -> void:
	for i in 2:
		var key := Transform3D(screen.basis, screen * (FarmTv.CHANNEL_CENTRES[i] - FarmTv.SCREEN_CENTRE))
		var other := screen * (FarmTv.CHANNEL_CENTRES[1 - i] - FarmTv.SCREEN_CENTRE)
		assert_bool(FarmTv.on_glass(FarmTv.rect_uv(key, FarmTv.CHANNEL_HALF, tv.origin, key.origin - tv.origin))).is_true()
		assert_bool(FarmTv.on_glass(FarmTv.rect_uv(key, FarmTv.CHANNEL_HALF, tv.origin, screen.origin - tv.origin))).is_false()
		assert_bool(FarmTv.on_glass(FarmTv.rect_uv(key, FarmTv.CHANNEL_HALF, tv.origin, other - tv.origin))).is_false()


func test_the_channel_keys_sit_at_the_top_of_the_right_panel_above_back_inside_the_glass_height() -> void:
	var back_top := FarmTv.BACK_CENTRE.y + FarmTv.BACK_HALF.y
	var last_bottom := FarmTv.SCREEN_CENTRE.y + FarmTv.SCREEN_HALF.y  # The TV view frames the glass's height.
	for centre: Vector3 in FarmTv.CHANNEL_CENTRES:
		assert_float(centre.x - FarmTv.CHANNEL_HALF.x).is_greater(FarmTv.SCREEN_CENTRE.x + FarmTv.SCREEN_HALF.x)
		assert_float(centre.y + FarmTv.CHANNEL_HALF.y).is_less_equal(last_bottom)
		last_bottom = centre.y - FarmTv.CHANNEL_HALF.y
	assert_float(last_bottom).is_greater(back_top)


func test_the_channel_keys_are_built_like_back_on_the_same_column_and_face() -> void:
	for centre: Vector3 in FarmTv.CHANNEL_CENTRES:
		assert_float(centre.x).is_equal_approx(FarmTv.BACK_CENTRE.x, 0.0001)
		assert_float(centre.z).is_equal_approx(FarmTv.BACK_CENTRE.z, 0.0001)
	assert_float(FarmTv.CHANNEL_HALF.x).is_equal_approx(FarmTv.BACK_HALF.x, 0.002)


func test_the_power_lamp_is_lit_only_while_the_camera_is_at_the_tv() -> void:
	# The set's power runs 0 on the desk to 1 at the TV (it fades with the pan, never blinks).
	assert_float(FarmTv.lamp_glow(0.0)).is_equal(0.0)
	assert_float(FarmTv.lamp_glow(1.0)).is_greater(1.0)
	assert_float(FarmTv.lamp_glow(0.5)).is_between(FarmTv.lamp_glow(0.0), FarmTv.lamp_glow(1.0))
	assert_float(FarmTv.lamp_glow(-1.0)).is_equal(0.0)


func test_the_channel_showing_lights_its_key_only_while_the_set_is_on_and_a_hovered_key_always_lights() -> void:
	assert_float(FarmTv.key_glow(1, 0.0)).is_equal(0.0)
	assert_float(FarmTv.key_glow(1, 1.0)).is_greater(0.0)
	assert_float(FarmTv.key_glow(0, 1.0)).is_equal(0.0)
	assert_float(FarmTv.key_glow(2, 1.0)).is_greater(FarmTv.key_glow(1, 1.0))


func test_the_channel_showing_glows_clearly_and_hovered_clearly_brighter() -> void:
	assert_float(FarmTv.key_glow(1, 1.0)).is_greater_equal(1.0)
	assert_float(FarmTv.key_glow(2, 1.0)).is_greater_equal(FarmTv.key_glow(1, 1.0) * 2.0)


func test_the_channel_keys_glow_a_pale_phosphor_green() -> void:
	var set_scene: FarmTv = auto_free(load("res://entities/farm_tv/farm_tv.tscn").instantiate())
	for key in ["Corner/Tv/Channel1", "Corner/Tv/Channel2"]:
		var glow: Color = (set_scene.get_node(key).material_override as StandardMaterial3D).emission
		assert_float(glow.g).is_greater(glow.r + 0.15)
		assert_float(glow.s).is_less(0.5)  # Desaturated: the cabbage stays the one saturated green.


func test_the_cursor_points_on_back_and_the_keys_follows_the_screen_on_the_glass_and_is_the_arrow_elsewhere() -> void:
	assert_int(FarmTv.tv_cursor(true, false, Input.CURSOR_ARROW)).is_equal(Input.CURSOR_POINTING_HAND)
	assert_int(FarmTv.tv_cursor(false, true, Input.CURSOR_DRAG)).is_equal(Input.CURSOR_DRAG)
	assert_int(FarmTv.tv_cursor(false, false, Input.CURSOR_DRAG)).is_equal(Input.CURSOR_ARROW)


func test_every_screen_cursor_has_a_glove_image() -> void:
	for shape: Input.CursorShape in [FarmScreen.POINT, FarmScreen.OPEN_HAND, FarmScreen.GRAB]:
		assert_bool(FarmTv.CURSORS.has(shape)).is_true()
		assert_object(FarmTv.CURSORS[shape][0]).is_not_null()


func test_the_pull_tab_only_returns_once_the_camera_is_back_at_the_desk() -> void:
	assert_bool(FarmTv.away_at(true, 0.0)).is_true()  # Leaving for the TV: gone at once.
	assert_bool(FarmTv.away_at(true, 1.0)).is_true()
	assert_bool(FarmTv.away_at(false, 0.4)).is_true()  # Panning back: still gone.
	assert_bool(FarmTv.away_at(false, 0.0)).is_false()  # Home.


func test_the_power_lamp_is_dark_with_the_set_off_and_lit_once_it_is_on() -> void:
	var set_scene: FarmTv = auto_free(load("res://entities/farm_tv/farm_tv.tscn").instantiate())
	var led: StandardMaterial3D = set_scene.get_node("Corner/Tv/Led").material_override
	assert_float(led.emission_energy_multiplier).is_equal(0.0)
	assert_bool(led.emission_enabled).is_true()


func test_back_sits_at_the_foot_of_the_panel_inside_the_glass_height() -> void:
	assert_float(FarmTv.BACK_CENTRE.y - FarmTv.BACK_HALF.y).is_greater_equal(FarmTv.SCREEN_CENTRE.y - FarmTv.SCREEN_HALF.y)
	assert_float(FarmTv.BACK_CENTRE.y).is_less(FarmTv.SCREEN_CENTRE.y)


func test_only_the_back_button_takes_the_camera_back_to_the_desk() -> void:
	assert_bool(FarmTv.leaves_tv(true)).is_true()
	assert_bool(FarmTv.leaves_tv(false)).is_false()


func test_switching_channels_takes_only_a_short_burst_of_static() -> void:
	assert_float(FarmTv.STATIC_TIME).is_less_equal(0.15)


func test_a_scene_reload_starts_with_the_camera_at_the_desk_not_the_tv() -> void:
	FarmTv.away = true  # Static: it outlives reload_current_scene (a reset or a debug start).
	var camera := Camera3D.new()
	add_child(auto_free(camera))
	camera.make_current()
	add_child(auto_free(load("res://entities/farm_tv/farm_tv.tscn").instantiate()))
	assert_bool(FarmTv.away).is_false()
