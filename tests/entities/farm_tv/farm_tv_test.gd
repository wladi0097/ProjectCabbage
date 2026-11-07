extends GdUnitTestSuite

var desk := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))
var screen := Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(-2.6, 1.08, 0.2))
var tv := FarmTv.tv_view(screen)


func test_the_remote_arrives_with_the_family_farm_card() -> void:
	var save := SaveGame.new()
	assert_bool(FarmTv.bought(save)).is_false()
	save.stamped.append("family_farm")
	assert_bool(FarmTv.bought(save)).is_true()


func test_the_tv_view_looks_down_a_little_at_the_glass_left_of_the_desk() -> void:
	assert_float(-tv.basis.z.y).is_between(-0.3, 0.0)
	assert_float(tv.origin.x).is_less(desk.origin.x)


func test_the_glass_fills_about_two_thirds_of_the_tv_views_height() -> void:
	var depth := (tv.origin - screen.origin).dot(tv.basis.z)
	var seen := 2.0 * FarmTv.SCREEN_HALF.y / (2.0 * depth * tan(deg_to_rad(FarmTv.DESK_FOV) / 2.0))
	assert_float(seen).is_between(0.6, 0.72)


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
