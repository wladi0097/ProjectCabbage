extends GdUnitTestSuite

const CabbageScript := preload("res://entities/cabbage/cabbage.gd")
const SCENE := preload("res://entities/cabbage/cabbage.tscn")

var _save: SaveGame


func before_test() -> void:
	_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _save


func spawn(setup := Callable()) -> Cabbage:
	var cabbage := SCENE.instantiate() as Cabbage
	if setup.is_valid():
		setup.call(cabbage)
	add_child(auto_free(cabbage))
	return cabbage


func base_mass() -> float:
	var raw := SCENE.instantiate() as Cabbage
	var mass := raw.mass
	raw.free()
	return mass


func base_radius() -> float:
	var raw := SCENE.instantiate() as Cabbage
	var radius := ((raw.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius
	raw.free()
	return radius


func radius_of(cabbage: Cabbage) -> float:
	return ((cabbage.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius


func test_a_grab_presses_the_cabbage_fully_flat_at_first() -> void:
	assert_float(CabbageScript.squish_at(0.0)).is_equal_approx(CabbageScript.SQUISH, 0.0001)


func test_a_grab_squash_springs_back_past_round_once() -> void:
	assert_float(CabbageScript.squish_at(0.2)).is_less(0.0)


func test_a_grab_squash_has_settled_by_squish_time() -> void:
	assert_float(absf(CabbageScript.squish_at(0.5))).is_less(0.02)
	assert_float(CabbageScript.squish_at(CabbageScript.SQUISH_TIME)).is_equal(0.0)
	assert_float(CabbageScript.squish_at(5.0)).is_equal(0.0)


func test_a_squashed_cabbage_bulges_sideways_and_keeps_its_volume() -> void:
	var squashed := CabbageScript.squish_scale(0.18)

	assert_float(squashed.y).is_equal_approx(0.82, 0.0001)
	assert_float(squashed.x).is_greater(1.0)
	assert_float(squashed.x * squashed.y * squashed.z).is_equal_approx(1.0, 0.0001)


func test_an_unsquashed_cabbage_is_its_normal_shape() -> void:
	assert_vector(CabbageScript.squish_scale(0.0)).is_equal(Vector3.ONE)


func test_a_held_cabbage_never_carries_faster_than_its_top_speed() -> void:
	var velocity := Vector3.ZERO
	for i in 600:
		velocity = CabbageScript.carry_velocity(velocity, Vector3(50, 0, 0), 1.0 / 60.0, 18.0, 60.0, 5.5)

	assert_float(velocity.length()).is_equal_approx(5.5, 0.0001)


func test_a_held_cabbage_gains_at_most_its_acceleration_cap_per_step() -> void:
	var velocity := CabbageScript.carry_velocity(Vector3.ZERO, Vector3(50, 0, 0), 1.0 / 60.0, 18.0, 60.0, 5.5)

	assert_float(velocity.length()).is_equal_approx(1.0, 0.0001)


func test_a_held_cabbage_pulls_harder_the_further_it_lags_behind() -> void:
	var near := CabbageScript.carry_velocity(Vector3.ZERO, Vector3(0.05, 0, 0), 1.0, 18.0, 60.0, 5.5)
	var far := CabbageScript.carry_velocity(Vector3.ZERO, Vector3(0.2, 0, 0), 1.0, 18.0, 60.0, 5.5)

	assert_float(near.x).is_equal_approx(0.9, 0.0001)
	assert_float(far.x).is_equal_approx(3.6, 0.0001)


func test_a_held_cabbage_at_the_hand_and_at_rest_stays_put() -> void:
	assert_vector(CabbageScript.carry_velocity(Vector3.ZERO, Vector3.ZERO, 0.1, 18.0, 60.0, 5.5)).is_equal(Vector3.ZERO)


func test_a_binned_cabbage_hops_from_where_it_was_to_the_bottom_of_the_bin() -> void:
	var from := Vector3(1.2, 0.87, 0.9)
	var into := Vector3(0.95, 0.82, 1.04)

	assert_vector(CabbageScript.hop_at(from, into, 1.2, 0.0)).is_equal_approx(from, Vector3.ONE * 0.0001)
	assert_vector(CabbageScript.hop_at(from, into, 1.2, 1.0)).is_equal_approx(into, Vector3.ONE * 0.0001)


func test_a_binned_cabbage_tops_out_over_the_rim() -> void:
	var from := Vector3(1.2, 0.87, 0.9)
	var into := Vector3(0.95, 0.82, 1.04)

	assert_float(CabbageScript.hop_at(from, into, 1.2, 0.45).y).is_equal_approx(1.2, 0.0001)


func test_a_binned_cabbage_ends_in_a_straight_drop_from_above_the_bin() -> void:
	var from := Vector3(1.2, 0.87, 0.9)
	var into := Vector3(0.95, 0.82, 1.04)
	var late := CabbageScript.hop_at(from, into, 1.2, 0.75)

	assert_float(late.x).is_equal_approx(into.x, 0.0001)
	assert_float(late.z).is_equal_approx(into.z, 0.0001)
	assert_float(late.y).is_greater(1.0)


func test_a_cabbage_already_above_the_rim_does_not_dip_down_to_it() -> void:
	var from := Vector3(1.2, 1.5, 0.9)
	var into := Vector3(0.95, 0.82, 1.04)

	assert_float(CabbageScript.hop_at(from, into, 1.2, 0.45).y).is_equal_approx(1.5, 0.0001)


func test_a_mini_weighs_about_a_quarter_of_a_full_cabbage() -> void:
	assert_float(pow(CabbageScript.MINI_SCALE, 3.0)).is_equal_approx(0.25, 0.01)


func test_a_cabbage_is_within_the_size_spread_of_the_standard_unit() -> void:
	var cabbage := spawn()
	var mass := base_mass()

	assert_float(cabbage.mass).is_between(mass * pow(1.0 - CabbageScript.SIZE_SPREAD, 3.0) - 0.0001,
			mass * pow(1.0 + CabbageScript.SIZE_SPREAD, 3.0) + 0.0001)


func test_a_mini_unit_is_mini_scale_smaller_in_mass_and_collider() -> void:
	var small := spawn(func(c: Cabbage) -> void: c.mini = true)
	var smallest := (1.0 - CabbageScript.SIZE_SPREAD) * CabbageScript.MINI_SCALE
	var biggest := (1.0 + CabbageScript.SIZE_SPREAD) * CabbageScript.MINI_SCALE

	assert_float(small.mass).is_between(base_mass() * pow(smallest, 3.0) - 0.0001, base_mass() * pow(biggest, 3.0) + 0.0001)
	assert_float(radius_of(small)).is_between(base_radius() * smallest - 0.0001, base_radius() * biggest + 0.0001)


func test_a_cabbage_mass_grows_with_the_cube_of_its_collider() -> void:
	var cabbage := spawn()

	assert_float(cabbage.mass / base_mass()).is_equal_approx(pow(radius_of(cabbage) / base_radius(), 3.0), 0.0001)


func test_sizing_one_cabbage_leaves_the_shared_collider_alone() -> void:
	spawn(func(c: Cabbage) -> void: c.mini = true)

	assert_float(base_radius()).is_equal_approx(0.11, 0.0001)


func test_a_research_unit_glows_cold_cyan() -> void:
	var research := spawn(func(c: Cabbage) -> void: c.research = true)
	var lights := research.find_children("*", "OmniLight3D", false, false)

	assert_object(research.get_node("Mesh").material_override).is_same(CabbageScript.RESEARCH_MATERIAL)
	assert_int(lights.size()).is_equal(1)
	assert_that((lights[0] as OmniLight3D).light_color).is_equal(CabbageScript.RESEARCH_LIGHT)


func test_a_rotten_unit_is_grey_and_never_glows_even_if_marked_research() -> void:
	var rotten := spawn(func(c: Cabbage) -> void:
		c.rotten = true
		c.research = true)

	assert_object(rotten.get_node("Mesh").material_override).is_same(CabbageScript.ROTTEN_MATERIAL)
	assert_array(rotten.find_children("*", "OmniLight3D", false, false)).is_empty()


func test_a_fresh_unit_keeps_its_green_leaf_material() -> void:
	var material: Material = spawn().get_node("Mesh").material_override
	assert_object(material).is_not_same(CabbageScript.ROTTEN_MATERIAL)
	assert_object(material).is_not_same(CabbageScript.RESEARCH_MATERIAL)


func test_a_sold_golden_units_ring_outlives_the_unit_freed_at_the_window() -> void:
	var golden := spawn(func(c: Cabbage) -> void: c.golden = true)
	var ring: Node = golden.get_node("GoldSale")
	golden.ring_golden_sale()

	assert_object(ring.get_parent()).is_same(golden.get_parent())
	assert_bool(golden.has_node("GoldSale")).is_false()
	ring.free()


## The scene must set the cap after the cue's script: Godot drops a script value written before it.
func test_at_most_three_golden_sale_bells_ring_at_once() -> void:
	assert_int((spawn().get_node("GoldSale") as SoundCue).max_instances).is_equal(3)


func test_bumps_and_grabs_keep_their_rate_caps_and_impact_curve() -> void:
	var bump := spawn().get_node("Bump") as SoundCue
	assert_float(bump.min_interval).is_equal(0.08)
	assert_float(bump.silent_strength).is_equal(0.4)
	assert_float(bump.full_strength).is_equal(3.0)
	assert_float((bump.get_parent().get_node("Grab") as SoundCue).min_interval).is_equal(0.1)

func test_every_cabbage_joins_the_cabbages_group() -> void:
	assert_bool(spawn().is_in_group(&"cabbages")).is_true()


func test_a_cabbage_in_flight_can_be_caught() -> void:
	var cabbage := spawn()
	cabbage.in_flight = true

	assert_bool((cabbage.get_node("Interactable") as Interactable).catchable).is_true()


func test_catching_a_cabbage_in_flight_counts_a_catch_and_ends_the_flight() -> void:
	var cabbage := spawn()
	cabbage.set_physics_process(false)
	cabbage.in_flight = true
	(cabbage.get_node("Interactable") as Interactable).grabbed.emit()

	assert_int(SaveManager.save.catches).is_equal(1)
	assert_bool(cabbage.in_flight).is_false()
	assert_bool((cabbage.get_node("Interactable") as Interactable).catchable).is_false()


func test_grabbing_a_cabbage_that_is_not_flying_is_no_catch() -> void:
	var cabbage := spawn()
	cabbage.set_physics_process(false)
	(cabbage.get_node("Interactable") as Interactable).grabbed.emit()

	assert_int(SaveManager.save.catches).is_equal(0)


## Something on the desk (the table's collider) for a flying unit to touch.
func desk() -> StaticBody3D:
	var body := StaticBody3D.new()
	add_child(auto_free(body))
	return body


## A unit in flight at `height` (its centre), the physics held still so only the test moves it.
func flying_at(height: float, setup := Callable()) -> Cabbage:
	var cabbage := spawn(setup)
	cabbage.freeze = true
	cabbage.set_physics_process(false)
	cabbage.global_position = Vector3(1.6, height, 0.5)
	cabbage.in_flight = true
	return cabbage


func test_a_flying_cabbage_that_lands_on_the_desk_is_no_longer_catchable() -> void:
	var cabbage := flying_at(0.85)
	cabbage.body_entered.emit(desk())

	assert_bool(cabbage.in_flight).is_false()
	assert_bool((cabbage.get_node("Interactable") as Interactable).catchable).is_false()


func test_a_cabbage_that_grazes_the_ramp_on_the_way_out_is_still_catchable() -> void:
	var tally := miss_log()
	var cabbage := flying_at(1.0)
	cabbage.body_entered.emit(desk())

	assert_bool(cabbage.in_flight).is_true()
	assert_int(tally.misses).is_equal(0)


func test_two_cabbages_bumping_in_the_air_is_no_miss() -> void:
	var tally := miss_log()
	var cabbage := flying_at(0.9)
	var other := flying_at(0.9)
	cabbage.body_entered.emit(other)

	assert_bool(cabbage.in_flight).is_true()
	assert_int(tally.misses).is_equal(0)


func test_a_flying_cabbage_coming_to_rest_atop_a_pile_has_landed() -> void:
	var tally := miss_log()
	var cabbage := flying_at(1.05)
	cabbage.body_entered.emit(spawn())
	assert_bool(cabbage.in_flight).is_true()
	for i in 10:
		cabbage._physics_process(1.0 / 60.0)
	assert_bool(cabbage.in_flight).is_true()

	for i in 10:
		cabbage._physics_process(1.0 / 60.0)
	assert_bool(cabbage.in_flight).is_false()
	assert_int(tally.misses).is_equal(1)


func test_a_cabbage_still_moving_through_the_air_never_settles() -> void:
	var cabbage := flying_at(1.2)
	cabbage.freeze = false
	cabbage.linear_velocity = Vector3(1.0, 0.0, 0.0)
	cabbage.gravity_scale = 0.0
	for i in 60:
		cabbage._physics_process(1.0 / 60.0)

	assert_bool(cabbage.in_flight).is_true()


func test_a_cabbage_never_bumps_into_the_chute_lever_handle_but_the_hand_still_finds_it() -> void:
	var lever := preload("res://entities/chute_lever/chute_lever.tscn").instantiate()
	var handle := lever.get_node("Arm/Handle") as StaticBody3D
	var cabbage := spawn()

	assert_int(handle.collision_layer & cabbage.collision_mask).is_equal(0)
	assert_int(handle.collision_mask).is_equal(0)
	assert_int(handle.collision_layer & ~2).is_not_equal(0)  # The hand's ray skips only the play area (2).
	lever.free()


## Counts the misses reported to the "catch_combo" group (a bare CatchCombo: no scene, no label).
class MissLog:
	extends CatchCombo
	var misses := 0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func missed() -> void:
		misses += 1

	func caught(_at: Vector3) -> void:
		pass


func miss_log() -> MissLog:
	var tally := MissLog.new()
	tally.add_to_group(&"catch_combo")
	add_child(auto_free(tally))
	return tally


func test_a_chute_unit_landing_uncaught_is_a_miss() -> void:
	var tally := miss_log()
	flying_at(0.85).body_entered.emit(desk())

	assert_int(tally.misses).is_equal(1)


func test_a_caught_unit_is_no_miss_when_it_later_touches_something() -> void:
	var tally := miss_log()
	var cabbage := spawn()
	cabbage.set_physics_process(false)
	cabbage.in_flight = true
	(cabbage.get_node("Interactable") as Interactable).grabbed.emit()
	cabbage.body_entered.emit(desk())

	assert_int(tally.misses).is_equal(0)


func test_a_unit_bumping_about_on_the_mat_is_no_miss() -> void:
	var tally := miss_log()
	spawn().body_entered.emit(null)

	assert_int(tally.misses).is_equal(0)


func test_a_mini_falling_from_upstairs_never_breaks_the_streak() -> void:
	var tally := miss_log()
	flying_at(0.8, func(c: Cabbage) -> void: c.mini = true).body_entered.emit(desk())

	assert_int(tally.misses).is_equal(0)


func test_a_held_cabbage_floats_and_falls_again_once_let_go() -> void:
	var cabbage := spawn()
	var interactable := cabbage.get_node("Interactable") as Interactable
	interactable.grabbed.emit()

	assert_float(cabbage.gravity_scale).is_equal(0.0)

	interactable.released.emit()

	assert_float(cabbage.gravity_scale).is_equal(1.0)


func test_a_sold_cabbage_is_out_of_reach_and_out_of_the_physics() -> void:
	var cabbage := spawn()
	cabbage.suck_out(Vector3(0, 1, -3), 0.5)

	assert_bool(cabbage.sold).is_true()
	assert_bool((cabbage.get_node("Interactable") as Interactable).enabled).is_false()
	assert_bool(cabbage.freeze).is_true()
	assert_int(cabbage.collision_layer).is_equal(0)
	assert_int(cabbage.collision_mask).is_equal(0)


func test_a_refused_cabbage_is_away_but_not_sold() -> void:
	var cabbage := spawn()
	cabbage.send_away(Vector3(0, 1, -3), 0.5)

	assert_bool(cabbage.away).is_true()
	assert_bool(cabbage.sold).is_false()


func test_a_cabbage_thrown_back_in_falls_and_collides_again() -> void:
	var cabbage := spawn()
	var layer := cabbage.collision_layer
	cabbage.send_away(Vector3(0, 1, -3), 0.5)
	cabbage.throw_in(Vector3(0, 1, -1), Vector3(0, 1, 2), 0.2, 1.0)

	assert_bool(cabbage.freeze).is_false()
	assert_int(cabbage.collision_layer).is_equal(layer)
	assert_vector(cabbage.linear_velocity).is_equal(Vector3(0, 1, 2))
	assert_bool(cabbage.away).is_true()


func test_a_hidden_unit_thrown_back_in_shows_as_it_is_thrown() -> void:
	var cabbage := spawn()
	cabbage.visible = false
	cabbage.throw_in(Vector3(0, 1, -1), Vector3(0, 1, 2), 0.2, 1.0)

	assert_bool(cabbage.visible).is_true()


func test_a_weightless_unit_closes_the_gap_to_the_hand_in_one_step_up_to_its_top_speed() -> void:
	assert_vector(Cabbage.free_velocity(Vector3(0.1, 0, 0), 0.02)).is_equal_approx(Vector3(5, 0, 0), Vector3.ONE * 0.001)
	assert_float(Cabbage.free_velocity(Vector3(10, 0, 0), 0.02).length()).is_equal_approx(Cabbage.FREE_SPEED, 0.001)


func test_a_mid_air_catch_spins_the_cabbage_once_fast_then_settling() -> void:
	assert_float(Cabbage.catch_spin_at(0.0)).is_equal(0.0)
	assert_float(Cabbage.catch_spin_at(1.0)).is_equal_approx(TAU, 0.0001)
	assert_float(Cabbage.catch_spin_at(0.25)).is_greater(TAU * 0.5)


func test_a_grown_mini_is_full_size_again_but_still_no_stock() -> void:
	var small := spawn(func(c: Cabbage) -> void: c.mini = true)
	var mini_radius := radius_of(small)
	small.grow()

	assert_bool(small.mini).is_false()
	assert_bool(small.is_stock()).is_false()
	assert_float(radius_of(small)).is_equal_approx(mini_radius / CabbageScript.MINI_SCALE, 0.0001)
	assert_float(small.mass / base_mass()).is_equal_approx(pow(radius_of(small) / base_radius(), 3.0), 0.0001)


func test_only_a_plain_unit_comes_out_of_the_stock() -> void:
	assert_bool(spawn().is_stock()).is_true()
	assert_bool(spawn(func(c: Cabbage) -> void: c.mini = true).is_stock()).is_false()


func test_a_golden_unit_leaving_stock_takes_one_off_the_golden_stock_too() -> void:
	var save := SaveGame.new()
	save.stock = 10
	save.golden_stock = 2
	var gold: Cabbage = auto_free(Cabbage.new())
	gold.golden = true
	gold.leave_stock(save)
	var plain: Cabbage = auto_free(Cabbage.new())
	plain.leave_stock(save)
	assert_int(save.stock).is_equal(8)
	assert_int(save.golden_stock).is_equal(1)


func test_a_unit_leaves_the_stock_only_once_and_the_stock_never_goes_below_zero() -> void:
	var save := SaveGame.new()
	save.stock = 1
	var unit: Cabbage = auto_free(Cabbage.new())
	unit.leave_stock(save)
	unit.leave_stock(save)
	assert_int(save.stock).is_equal(0)
	var other: Cabbage = auto_free(Cabbage.new())
	other.leave_stock(save)
	assert_int(save.stock).is_equal(0)
	assert_bool(unit.in_stock()).is_false()


func test_a_mini_leaving_the_mat_is_no_stock_at_all() -> void:
	var save := SaveGame.new()
	var tiny: Cabbage = auto_free(Cabbage.new())
	tiny.mini = true
	tiny.leave_stock(save)
	assert_int(save.stock).is_equal(SaveGame.new().stock)


func test_a_golden_unit_is_drawn_in_cold_metallic_gold() -> void:
	var gold := spawn(func(c: Cabbage) -> void: c.golden = true)
	assert_object(gold.get_node("Mesh").material_override).is_equal(CabbageScript.GOLD_MATERIAL)
	assert_float((CabbageScript.GOLD_MATERIAL as StandardMaterial3D).metallic).is_greater(0.5)


func test_a_cabbage_counts_as_the_players_unless_a_hand_lobbed_it_or_the_tube_sent_it() -> void:
	var cabbage: Cabbage = auto_free(CabbageScript.new())
	assert_bool(cabbage.by_player()).is_true()
	cabbage.lobbed = true
	assert_bool(cabbage.by_player()).is_false()
	cabbage.lobbed = false
	cabbage.tubed = true
	assert_bool(cabbage.by_player()).is_false()



func test_a_condensed_cabbage_takes_two_cabbages_from_stock_when_it_leaves() -> void:
	var save := SaveGame.new()
	save.stock = 10
	var dense := spawn(func(c: Cabbage) -> void: c.units = 2)
	dense.leave_stock(save)
	dense.leave_stock(save)  # Only once.
	assert_int(save.stock).is_equal(8)


func test_a_condensed_golden_cabbage_takes_two_golden_cabbages_from_stock() -> void:
	var save := SaveGame.new()
	save.stock = 10
	save.golden_stock = 5
	var dense := spawn(func(c: Cabbage) -> void:
		c.golden = true
		c.units = 2)
	dense.leave_stock(save)
	assert_int(save.stock).is_equal(8)
	assert_int(save.golden_stock).is_equal(3)


func test_a_condensed_cabbage_is_no_bigger_than_a_plain_one_and_twice_as_heavy() -> void:
	for units: int in [2, 8, 16, 32]:
		var dense := spawn(func(c: Cabbage) -> void: c.units = units)
		# The same size spread as a plain one, whatever it holds: only its count tells.
		assert_float(radius_of(dense)).override_failure_message("x%d" % units).is_between(
				base_radius() * (1.0 - CabbageScript.SIZE_SPREAD) - 0.0001, base_radius() * (1.0 + CabbageScript.SIZE_SPREAD) + 0.0001)
		assert_float((dense.get_node("Mesh") as MeshInstance3D).basis.get_scale().x).is_less_equal(1.5 * (1.0 + CabbageScript.SIZE_SPREAD) + 0.0001)
	var two := spawn(func(c: Cabbage) -> void: c.units = 2)
	assert_float(two.mass / base_mass()).is_equal_approx(2.0 * pow(radius_of(two) / base_radius(), 3.0), 0.0001)


func test_past_eight_cabbages_in_one_it_gets_no_heavier_to_carry_and_sounds_no_lower() -> void:
	assert_int(CabbageScript.heft(1)).is_equal(1)
	assert_int(CabbageScript.heft(8)).is_equal(8)
	assert_int(CabbageScript.heft(32)).is_equal(8)
	assert_float(CabbageScript.heavy_pitch(32)).is_equal(CabbageScript.heavy_pitch(8))
	var eight := spawn(func(c: Cabbage) -> void: c.units = 8)
	var many := spawn(func(c: Cabbage) -> void: c.units = 32)
	assert_float(many.max_accel).is_equal_approx(eight.max_accel, 0.0001)
	assert_float(many.mass / pow(radius_of(many), 3.0)).is_equal_approx(eight.mass / pow(radius_of(eight), 3.0), 0.001)


func test_a_condensed_cabbage_drags_behind_the_hand_but_still_reaches_the_window_speed() -> void:
	var plain := spawn()
	var dense := spawn(func(c: Cabbage) -> void: c.units = 2)
	assert_float(dense.max_accel).is_less(plain.max_accel * 0.85)
	assert_float(dense.max_accel).is_greater(plain.max_accel * 0.7)
	assert_float(dense.max_speed).is_equal(plain.max_speed)  # The throw itself is as fast.


func test_a_condensed_cabbage_wears_a_belt_printed_with_what_it_holds() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 3)
	dense._process(0.0)
	var belt := dense.get_node("Belt") as MeshInstance3D
	assert_bool(belt.visible).is_true()
	assert_bool(dense.is_processing()).is_true()
	assert_float((belt.get_instance_shader_parameter(&"to_mesh_z") as Vector4).w).is_equal(3.0)


func test_every_count_up_to_thirty_two_has_its_own_print_on_the_belt() -> void:
	for count in range(2, 33):
		assert_int(CabbageScript.belt_row(count)).is_equal(count)
	var atlas := load("res://assets/textures/cabbage_belt/cabbage_belt_print.png") as Texture2D
	assert_int(atlas.get_height() % (CabbageScript.BELT_MOST + 1)).is_equal(0)


func test_a_single_cabbage_wears_no_belt() -> void:
	var plain := spawn()
	assert_bool((plain.get_node("Belt") as MeshInstance3D).visible).is_false()
	assert_bool(plain.is_processing()).is_false()


func test_the_belt_stays_level_while_the_cabbage_rolls() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 4)
	var belt := dense.get_node("Belt") as MeshInstance3D
	dense.global_basis = Basis.from_euler(Vector3(0.3, 1.1, -0.7))
	dense._process(0.0)
	var level := belt.global_basis
	var told: Vector4 = belt.get_instance_shader_parameter(&"to_mesh_x")
	dense.global_basis = Basis.from_euler(Vector3(2.4, -0.5, 1.9))
	dense.global_position = Vector3(0.4, 0.9, 0.2)
	dense._process(0.0)
	assert_bool(belt.global_basis.is_equal_approx(level)).is_true()
	assert_vector(belt.global_position).is_equal_approx(dense.global_position, Vector3.ONE * 0.0001)
	# The paper keeps still; only the shader learns how the cabbage turned inside it.
	assert_bool((belt.get_instance_shader_parameter(&"to_mesh_x") as Vector4).is_equal_approx(told)).is_false()


func test_the_belt_faces_the_camera_upright() -> void:
	var up := Vector3(0.0, 0.48, -0.88).normalized()
	var level := CabbageScript.belt_basis(up, Vector3(0.1, 0.9, 0.5).normalized())
	assert_vector(level.y).is_equal_approx(up, Vector3.ONE * 0.0001)
	assert_float(level.z.dot(Vector3(0.1, 0.9, 0.5))).is_greater(0.0)
	assert_float(level.determinant()).is_equal_approx(1.0, 0.0001)


func test_the_belt_adds_nothing_to_the_cabbages_collision() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 8)
	assert_int(dense.find_children("*", "CollisionShape3D", true, false).size()).is_equal(1)
	assert_int(dense.find_children("*", "CollisionObject3D", true, false).size()).is_equal(0)
	assert_object(dense.get_node("Belt")).is_not_instanceof(CollisionObject3D)


## The belt shader's sums (assets/shaders/cabbage_belt.gdshader), ported: how far out the paper sits
## in belt-space direction `d` for a mesh turned by `turn` (belt to mesh space) at `scale`.
const BELT_REACH := 0.11
const BELT_CLEAR := 0.002
const BELT_HALF := 0.038
const BELT_FADE := 0.01
const BELT_SPAN := 1
const BELT_STEP := 0.07
const BELT_BEND := 1.0
const BELT_ELEVS := 6
const BELT_ELEV := 0.07


func belt_reach_at(reach: Image, shape: int, turn: Basis, scale: float, d: Vector3) -> float:
	var m := turn * d
	# Bilinear, clamped at the edges, like the shader's filter_linear read.
	var fx := (atan2(m.z, m.x) / TAU + 0.5) * 128.0 - 0.5
	var fy := clampf(acos(clampf(m.y, -1.0, 1.0)) / PI * 64.0, 0.5, 63.5) - 0.5
	var x0 := floori(fx)
	var y0 := floori(fy)
	var texel := func(x: int, y: int) -> float: return reach.get_pixel(clampi(x, 0, 127), clampi(y, 0, 63) + shape * 64).r
	var top: float = lerpf(texel.call(x0, y0), texel.call(x0 + 1, y0), fx - x0)
	var bottom: float = lerpf(texel.call(x0, y0 + 1), texel.call(x0 + 1, y0 + 1), fx - x0)
	return lerpf(top, bottom, fy - y0) * BELT_REACH * scale


func belt_hug(reach: Image, shape: int, turn: Basis, scale: float, dir: Vector2) -> float:
	var hug := 0.0
	for j in range(-BELT_SPAN, BELT_SPAN + 1):
		var turned := dir.rotated(j * BELT_STEP)
		for k in range(-BELT_ELEVS, BELT_ELEVS + 1):
			var e := k * BELT_ELEV
			var far := belt_reach_at(reach, shape, turn, scale, Vector3(turned.x * cos(e), sin(e), turned.y * cos(e)))
			var let_go := 1.0 - 0.25 * smoothstep(BELT_HALF, BELT_HALF + BELT_FADE, absf(far * sin(e)))
			hug = maxf(hug, far * cos(e) * cos(BELT_BEND * j * BELT_STEP) * let_go)
	return hug + BELT_CLEAR


## The belt mesh (examples/cabbage_belt_geo.py): an arc BELT_ARC either side of its front, BELT_SEG
## segments across.
const BELT_ARC := deg_to_rad(60.0)
const BELT_SEG := 32


## The paper's inner face at each of the belt mesh's vertex angles (from +Z toward +X), for a cabbage
## mesh `shape` turned by `turn` (mesh to belt space) at `scale`.
func belt_ring(reach: Image, shape: int, turn: Basis, scale: float) -> Array[Vector2]:
	var ring: Array[Vector2] = []
	for i in BELT_SEG + 1:
		var angle := -BELT_ARC + 2.0 * BELT_ARC * i / BELT_SEG
		var dir := Vector2(sin(angle), cos(angle))
		ring.append(dir * belt_hug(reach, shape, turn.inverse(), scale, dir))
	return ring


## Every leaf point of mesh `shape` (corners and centres of its faces), in mesh space.
func leaf_points(shape: int) -> PackedVector3Array:
	var faces := CabbageScript.MESHES[shape].get_faces()
	var leaves := PackedVector3Array()
	for t in range(0, faces.size(), 3):
		leaves.append_array([faces[t], faces[t + 1], faces[t + 2], (faces[t] + faces[t + 1] + faces[t + 2]) / 3.0])
	return leaves


func test_no_leaf_of_any_cabbage_pokes_through_its_belt_however_it_rolls_and_the_paper_rests_on_the_leaves() -> void:
	var reach := (load("res://assets/textures/cabbage_belt/cabbage_belt_reach.png") as Texture2D).get_image()
	var half := (load("res://assets/meshes/Props/cabbage_belt.res") as Mesh).get_aabb().size.y / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var scale := 1.5 * (1.0 + CabbageScript.SIZE_SPREAD)
	for shape in CabbageScript.MESHES.size():
		var leaves := leaf_points(shape)
		for roll in 24:
			var turn := Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU)
			var ring := belt_ring(reach, shape, turn, scale)
			var through := 0
			var resting := 0
			for leaf in leaves:
				var p := turn * leaf * scale
				var angle := atan2(p.x, p.z)
				if absf(p.y) > half or absf(angle) >= BELT_ARC:
					continue  # Above, below or past the ends of the paper.
				var i := mini(floori((angle + BELT_ARC) / (2.0 * BELT_ARC) * BELT_SEG), BELT_SEG - 1)
				var a := ring[i]
				var b := ring[i + 1]
				var flat := Vector2(p.x, p.z)
				# Outside the chord between the two vertices round it: through the paper.
				var inside := -(b - a).cross(flat - a) / (b - a).length()
				if inside < 0.0:
					through += 1
				elif inside < 0.01:
					resting += 1
			assert_int(through).override_failure_message("cabbage %d, roll %d: %d leaf points through the belt" % [shape, roll, through]).is_equal(0)
			# Snug, not a loose hoop: some leaves come within a centimetre of the paper.
			assert_int(resting).override_failure_message("cabbage %d, roll %d: the belt floats off the leaves" % [shape, roll]).is_greater(0)


func test_the_belts_ends_tuck_in_round_the_cabbages_sides() -> void:
	var reach := (load("res://assets/textures/cabbage_belt/cabbage_belt_reach.png") as Texture2D).get_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var scale := 1.5
	var tucked := 0
	var ends := 0
	var furthest := -INF
	for shape in CabbageScript.MESHES.size():
		var leaves := leaf_points(shape)
		for roll in 12:
			var turn := Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU)
			var ring := belt_ring(reach, shape, turn, scale)
			var outline := Vector2(INF, -INF)  # The cabbage's sides as the camera sees them (belt x).
			for leaf in leaves:
				var x := (turn * leaf * scale).x
				outline = Vector2(minf(outline.x, x), maxf(outline.y, x))
			var paper := Vector2(INF, -INF)
			for point in ring:
				paper = Vector2(minf(paper.x, point.x), maxf(paper.y, point.x))
			tucked += int(paper.x >= outline.x) + int(paper.y <= outline.y)
			ends += 2
			furthest = maxf(furthest, maxf(outline.x - paper.x, paper.y - outline.y))
	# Most ends stop inside the outline; none stands out past it by a centimetre (a full ring with a
	# wide sample window stood up to 3 cm out).
	assert_float(float(tucked) / ends).is_greater_equal(0.8)
	assert_float(furthest).is_less(0.01)


func test_a_condensed_cabbage_sounds_lower_the_more_cabbages_it_holds() -> void:
	assert_float(CabbageScript.heavy_pitch(1)).is_equal(1.0)
	assert_float(CabbageScript.heavy_pitch(2)).is_between(0.8, 0.9)
	assert_float(CabbageScript.heavy_pitch(4)).is_between(0.7, 0.8)
	var dense := spawn(func(c: Cabbage) -> void: c.units = 2)
	assert_float((dense.get_node("Bump") as SoundCue).pitch_scale).is_equal_approx(CabbageScript.heavy_pitch(2), 0.0001)
	assert_float((dense.get_node("Grab") as SoundCue).pitch_scale).is_equal_approx(CabbageScript.heavy_pitch(2), 0.0001)
	assert_float((spawn().get_node("Bump") as SoundCue).pitch_scale).is_equal(1.0)
