extends GdUnitTestSuite

const SCENE := preload("res://entities/cabbage_gun/cabbage_gun.tscn")

var _save: SaveGame
var _camera: Camera3D


func before_test() -> void:
	_save = SaveManager.save
	SaveManager.save = SaveGame.new()
	_camera = auto_free(Camera3D.new())
	add_child(_camera)
	_camera.make_current()


func after_test() -> void:
	SaveManager.save = _save


func spawn() -> CabbageGun:
	var gun := SCENE.instantiate() as CabbageGun
	_camera.add_child(gun)
	return gun


func click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _camera.get_viewport().get_visible_rect().size / 2.0
	return event


func shots_of(gun: CabbageGun) -> Array:
	var shots := []
	gun.fired.connect(func(hit: Convertible) -> void: shots.append(hit))
	return shots


func test_the_gun_stays_hidden_until_raised() -> void:
	var gun := spawn()
	assert_bool(gun.visible).is_false()
	await gun.raise()
	assert_bool(gun.visible).is_true()


func test_the_gun_does_not_fire_while_unarmed() -> void:
	var gun := spawn()
	await gun.raise()
	var shots := shots_of(gun)
	gun._unhandled_input(click())
	assert_int(shots.size()).is_equal(0)


func test_an_armed_click_into_empty_air_fires_a_miss() -> void:
	var gun := spawn()
	await gun.raise()
	gun.armed = true
	var shots := shots_of(gun)
	gun._unhandled_input(click())
	assert_array(shots).is_equal([null])


func test_a_shot_converts_the_convertible_under_the_crosshair() -> void:
	var gun := spawn()
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -4.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	target.add_child(mesh)
	var convertible := Convertible.new()
	var drops: Node3D = auto_free(Node3D.new())
	add_child(drops)
	convertible.drop_parent = drops
	target.add_child(convertible)
	add_child(auto_free(target))
	await gun.raise()
	await get_tree().physics_frame
	gun.armed = true
	var shots := shots_of(gun)
	gun._unhandled_input(click())
	assert_array(shots).is_equal([convertible])
	assert_bool(convertible.is_converted).is_true()


func test_turned_to_the_player_the_barrel_looks_at_the_camera() -> void:
	var gun := spawn()
	await gun.raise()
	await gun.turn_to_player(0.2)
	var barrel := -(gun.get_node("Rig/Pivot") as Node3D).global_basis.z.normalized()
	assert_float(barrel.dot(_camera.global_basis.z)).is_greater(0.95)


func test_the_shot_at_the_player_shows_and_sounds_nothing() -> void:
	var gun := spawn()
	await gun.raise()
	await gun.turn_to_player(0.1)
	gun.armed = true
	var shots := shots_of(gun)
	gun._unhandled_input(click())
	assert_array(shots).is_equal([null])
	assert_bool((gun.get_node("Shot") as AudioStreamPlayer).playing).is_false()
	assert_bool((gun.get_node("Rig/Pivot/Kick/Muzzle/Flash") as Node3D).visible).is_false()
	assert_bool((gun.get_node("Trail") as Node3D).visible).is_false()
	assert_float(gun._needle_dip.x).is_equal(0.0)
	assert_bool((gun.get_node("Rig/Pivot/Kick") as Node3D).transform.is_equal_approx(Transform3D.IDENTITY)).is_true()


## The camera goes up close to the TV and the map; the gun is built small and near enough that no
## station's scenery comes between it and the camera.
func test_the_gun_stays_closer_to_the_camera_than_any_stations_scenery() -> void:
	var gun := spawn()
	await gun.raise()
	assert_float(-Convertible.bounds(gun).position.z).is_less(CabbageGun.MAX_DEPTH)
	await gun.turn_to_player(0.1)
	assert_float(-Convertible.bounds(gun).position.z).is_less(CabbageGun.MAX_DEPTH)


func test_the_liquid_settles_after_the_gun_stops_moving() -> void:
	var state := Vector4(0.4, -0.3, 2.0, 1.0)
	for i in 600:
		state = CabbageGun.slosh_step(state, Vector2.ZERO, 1.0 / 60.0)
	assert_float(state.length()).is_less(0.01)


func test_a_shove_tips_the_liquid_and_it_swings_back_past_level() -> void:
	var state := Vector4.ZERO
	for i in 6:
		state = CabbageGun.slosh_step(state, Vector2(60.0, 0.0), 1.0 / 60.0)
	assert_float(state.x).is_greater(0.02)
	var lowest := state.x
	for i in 60:
		state = CabbageGun.slosh_step(state, Vector2.ZERO, 1.0 / 60.0)
		lowest = minf(lowest, state.x)
	assert_float(lowest).is_less(-0.01)


func test_the_liquid_never_tips_steeper_than_its_limit() -> void:
	var state := Vector4.ZERO
	for i in 120:
		state = CabbageGun.slosh_step(state, Vector2(5000.0, -5000.0), 1.0 / 60.0)
		assert_float(Vector2(state.x, state.y).length()).is_less_equal(CabbageGun.SLOSH_MAX + 0.0001)


func test_a_shot_sloshes_the_liquid_in_the_canister() -> void:
	var gun := spawn()
	await gun.raise()
	await get_tree().create_timer(3.0).timeout
	var calm := Vector2(gun._slosh.x, gun._slosh.y).length()
	gun.armed = true
	gun._unhandled_input(click())
	await get_tree().create_timer(0.12).timeout
	assert_float(Vector2(gun._slosh.x, gun._slosh.y).length()).is_greater(calm + 0.02)


func barrel_of(pose: Transform3D) -> Vector3:
	return -pose.basis.z.normalized()


func test_turning_to_the_player_the_muzzle_swings_past_the_screens_right() -> void:
	for t: float in [0.3, 0.5, 0.7]:
		assert_float(barrel_of(CabbageGun.turn_pose(Transform3D.IDENTITY, t)).x).is_greater(0.2)


func test_the_gun_shakes_more_mid_turn_than_at_rest_facing_the_player() -> void:
	var mid := 0.0
	var held := 0.0
	for i in 200:
		var time := i * 0.05
		mid = maxf(mid, barrel_of(CabbageGun.turn_pose(Transform3D.IDENTITY, 0.5, time)).angle_to(barrel_of(CabbageGun.turn_pose(Transform3D.IDENTITY, 0.5))))
		held = maxf(held, barrel_of(CabbageGun.turn_pose(Transform3D.IDENTITY, 1.0, time)).angle_to(Vector3.BACK))
	assert_float(mid).is_greater(held * 1.5)


func test_pointed_at_the_player_the_gun_keeps_a_small_nervous_tremble() -> void:
	var widest := 0.0
	for i in 200:
		widest = maxf(widest, barrel_of(CabbageGun.turn_pose(Transform3D.IDENTITY, 1.0, i * 0.05)).angle_to(Vector3.BACK))
	assert_float(widest).is_between(0.004, 0.03)


func test_the_gun_still_trembles_after_the_turn_has_ended() -> void:
	var gun := spawn()
	await gun.raise()
	await gun.turn_to_player(0.1)
	var pivot := gun.get_node("Rig/Pivot") as Node3D
	var pose := pivot.transform
	await get_tree().create_timer(0.3).timeout
	assert_bool(pivot.transform.is_equal_approx(pose)).is_false()
	assert_float(barrel_of(pivot.global_transform).dot(_camera.global_basis.z)).is_greater(0.99)


func test_a_shots_trail_runs_from_the_muzzle_to_where_the_shot_lands() -> void:
	var from := Vector3(0.3, -0.2, -0.1)
	var to := Vector3(-1.0, 0.5, -4.0)
	var pose := CabbageGun.trail_pose(from, to, Vector3.UP)
	assert_bool(pose.origin.is_equal_approx(from)).is_true()
	assert_bool((pose * Vector3(0.0, 0.0, -1.0)).is_equal_approx(to)).is_true()
	var straight_up := CabbageGun.trail_pose(Vector3.ZERO, Vector3(0.0, 3.0, 0.0), Vector3.UP)
	assert_bool((straight_up * Vector3(0.0, 0.0, -1.0)).is_equal_approx(Vector3(0.0, 3.0, 0.0))).is_true()


func test_a_shot_shows_a_trail_that_is_gone_a_moment_later() -> void:
	var gun := spawn()
	await gun.raise()
	gun.armed = true
	gun._unhandled_input(click())
	var trail := gun.get_node("Trail") as Node3D
	assert_bool(trail.visible).is_true()
	await get_tree().create_timer(CabbageGun.TRAIL_TIME + 0.15).timeout
	assert_bool(trail.visible).is_false()


func test_a_miss_draws_its_trail_out_to_the_guns_full_range() -> void:
	var gun := spawn()
	await gun.raise()
	gun.armed = true
	gun._unhandled_input(click())
	var trail := gun.get_node("Trail") as Node3D
	var end := trail.global_transform * Vector3(0.0, 0.0, -1.0)
	assert_float(end.distance_to(_camera.global_position)).is_equal_approx(CabbageGun.RANGE, 0.5)


func test_a_shot_drops_the_gauge_needle_and_it_wobbles_back_to_rest_in_under_a_second() -> void:
	var state := CabbageGun.needle_kick(Vector2.ZERO)
	assert_float(state.x).is_equal_approx(CabbageGun.NEEDLE_KICK, 0.0001)
	var lowest := state.x
	var settled_at := 0.0
	for i in 120:
		state = CabbageGun.needle_step(state, 1.0 / 60.0)
		lowest = minf(lowest, state.x)
		if absf(state.x) > 0.03:
			settled_at = (i + 1) / 60.0
	# It swings past rest before it settles, and is still within 0.5 to 0.8 s.
	assert_float(lowest).is_less(-0.05)
	assert_float(settled_at).is_between(0.3, 0.8)
	assert_float(state.length()).is_less(0.01)


func test_quick_shots_stack_the_needles_drop_up_to_a_cap() -> void:
	var one := CabbageGun.needle_kick(Vector2.ZERO)
	var two := CabbageGun.needle_kick(CabbageGun.needle_step(one, 1.0 / 60.0))
	assert_float(two.x).is_greater(one.x + 0.2)
	var state := Vector2.ZERO
	for i in 10:
		state = CabbageGun.needle_kick(state)
	assert_float(state.x).is_equal_approx(CabbageGun.NEEDLE_MAX, 0.0001)


func test_a_shot_swings_the_needle_on_the_gauge() -> void:
	var gun := spawn()
	await gun.raise()
	var needle := gun.get_node("Rig/Pivot/Kick/Needle") as Node3D
	await get_tree().process_frame
	var rest := needle.rotation.z
	gun.armed = true
	gun._unhandled_input(click())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(needle.rotation.z).is_greater(rest + 0.3)
