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
	# As dense as the one holding 8: compared as a ratio, the densities are in the thousands (float precision).
	assert_float((many.mass / pow(radius_of(many), 3.0)) / (eight.mass / pow(radius_of(eight), 3.0))).is_equal_approx(1.0, 0.0001)


func test_a_condensed_cabbage_drags_behind_the_hand_but_still_reaches_the_window_speed() -> void:
	var plain := spawn()
	var dense := spawn(func(c: Cabbage) -> void: c.units = 2)
	assert_float(dense.max_accel).is_less(plain.max_accel * 0.85)
	assert_float(dense.max_accel).is_greater(plain.max_accel * 0.7)
	assert_float(dense.max_speed).is_equal(plain.max_speed)  # The throw itself is as fast.


func test_a_condensed_cabbage_shows_the_number_it_holds_on_its_leaves() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 4)
	var number := dense.get_node("Number") as Decal
	assert_bool(number.visible).is_true()
	assert_bool(dense.is_processing()).is_true()
	assert_object(number.texture_albedo).is_same(CabbageScript.count_texture(4))
	assert_object(number.modulate).is_equal(CabbageScript.count_colour(4))


func test_every_count_gets_its_own_digits_and_the_same_count_shares_them() -> void:
	var seen := {}
	for count in range(2, 33):
		var image := CabbageScript.count_texture(count).get_image()
		seen[image.get_data()] = count
		assert_object(CabbageScript.count_texture(count)).is_same(CabbageScript.count_texture(count))
	assert_int(seen.size()).is_equal(31)


func test_the_digits_are_white_so_the_tint_alone_colours_them() -> void:
	var image := CabbageScript.count_texture(8).get_image()
	var white := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.1:
				assert_float(pixel.s).is_less(0.05)  # Grey rim or white face, no colour of its own.
			if pixel.a > 0.95 and pixel.v > 0.95:
				white += 1
	assert_int(white).is_greater(100)


func test_the_numbers_colour_depends_on_how_many_it_holds() -> void:
	assert_object(CabbageScript.count_colour(2)).is_equal(CabbageScript.count_colour(3))
	var tiers := {}
	for count: int in [2, 4, 8, 16, 32]:
		tiers[CabbageScript.count_colour(count)] = count
	assert_int(tiers.size()).is_equal(5)
	assert_object(CabbageScript.count_colour(7)).is_equal(CabbageScript.count_colour(4))
	assert_object(CabbageScript.count_colour(31)).is_equal(CabbageScript.count_colour(16))


func test_the_numbers_stay_cold_and_pale_never_as_loud_as_the_cabbage() -> void:
	for colour: Color in CabbageScript.COUNT_COLOURS:
		assert_float(colour.s).is_less(0.6)
		assert_float(colour.v).is_greater(0.9)


func test_a_single_mini_or_rotten_cabbage_shows_no_number() -> void:
	for dressed: Callable in [func(_c: Cabbage) -> void: pass,
			func(c: Cabbage) -> void: c.mini = true,
			func(c: Cabbage) -> void: c.rotten = true]:
		var plain := spawn(dressed)
		assert_bool((plain.get_node("Number") as Decal).visible).is_false()
		assert_bool(plain.is_processing()).is_false()


func test_the_number_stays_upright_to_the_camera_while_the_cabbage_rolls() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 4)
	var number := dense.get_node("Number") as Decal
	dense.global_basis = Basis.from_euler(Vector3(0.3, 1.1, -0.7))
	dense._process(0.0)
	var level := number.global_basis
	dense.global_basis = Basis.from_euler(Vector3(2.4, -0.5, 1.9))
	dense.global_position = Vector3(0.4, 0.9, 0.2)
	dense._process(0.0)
	assert_bool(number.global_basis.is_equal_approx(level)).is_true()
	assert_float(number.global_position.distance_to(dense.global_position)).is_equal_approx(CabbageScript.NUMBER_LIFT, 0.0001)


func test_the_number_projects_along_the_view_with_its_top_toward_the_cameras_up() -> void:
	var view := Basis.from_euler(Vector3(-1.0, 0.2, 0.0))
	var level := CabbageScript.number_basis(view)
	# A decal projects down its -y and reads its texture's top at -z.
	assert_vector(-level.y).is_equal_approx(-view.z, Vector3.ONE * 0.0001)
	assert_vector(-level.z).is_equal_approx(view.y, Vector3.ONE * 0.0001)
	assert_float(level.determinant()).is_equal_approx(1.0, 0.0001)


func test_the_number_prints_only_on_cabbages_not_the_desk() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 8)
	var mask := (dense.get_node("Number") as Decal).cull_mask
	assert_int(mask & 1).is_equal(0)  # The desk, the mat and everything else draw on layer 1.
	assert_int(mask & (dense.get_node("Mesh") as MeshInstance3D).layers).is_not_equal(0)


func test_the_number_adds_nothing_to_the_cabbages_collision() -> void:
	var dense := spawn(func(c: Cabbage) -> void: c.units = 8)
	assert_int(dense.find_children("*", "CollisionShape3D", true, false).size()).is_equal(1)
	assert_int(dense.find_children("*", "CollisionObject3D", true, false).size()).is_equal(0)


func test_a_condensed_cabbage_sounds_lower_the_more_cabbages_it_holds() -> void:
	assert_float(CabbageScript.heavy_pitch(1)).is_equal(1.0)
	assert_float(CabbageScript.heavy_pitch(2)).is_between(0.8, 0.9)
	assert_float(CabbageScript.heavy_pitch(4)).is_between(0.7, 0.8)
	var dense := spawn(func(c: Cabbage) -> void: c.units = 2)
	assert_float((dense.get_node("Bump") as SoundCue).pitch_scale).is_equal_approx(CabbageScript.heavy_pitch(2), 0.0001)
	assert_float((dense.get_node("Grab") as SoundCue).pitch_scale).is_equal_approx(CabbageScript.heavy_pitch(2), 0.0001)
	assert_float((spawn().get_node("Bump") as SoundCue).pitch_scale).is_equal(1.0)


func test_after_the_quarantine_card_rotten_and_regular_cabbages_pass_through_each_other() -> void:
	SaveManager.save.stamped.append(Cabbage.SHIELD_CARD)
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	var plain := spawn()
	var golden := spawn(func(c: Cabbage) -> void: c.golden = true)  # Every kind but rotten counts as regular.
	var other_rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	for regular: Cabbage in [plain, golden]:
		assert_array(rotten.get_collision_exceptions()).contains([regular])
		assert_array(regular.get_collision_exceptions()).contains([rotten, other_rotten])
	assert_array(rotten.get_collision_exceptions()).not_contains([other_rotten])  # Two rotten ones still meet.
	assert_array(plain.get_collision_exceptions()).not_contains([golden])


func test_a_quarantined_rotten_cabbage_keeps_its_weight_and_still_meets_the_desk_the_hands_and_the_player() -> void:
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	var layers := Vector2i(rotten.collision_layer, rotten.collision_mask)
	var mass := rotten.mass
	SaveManager.save.stamped.append(Cabbage.SHIELD_CARD)
	rotten._physics_process(0.016)
	assert_bool(rotten._quarantined).is_true()
	assert_that(Vector2i(rotten.collision_layer, rotten.collision_mask)).is_equal(layers)
	assert_float(rotten.mass).is_equal(mass)


func test_without_the_quarantine_card_rotten_and_regular_cabbages_collide_as_ever() -> void:
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	spawn()
	assert_array(rotten.get_collision_exceptions()).is_empty()


func test_a_rotten_cabbage_out_when_the_card_is_stamped_is_quarantined_on_its_next_step() -> void:
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	var plain := spawn()
	SaveManager.save.stamped.append(Cabbage.SHIELD_CARD)
	rotten._physics_process(0.016)
	assert_array(plain.get_collision_exceptions()).contains([rotten])


func _tick(cabbage: Cabbage, seconds: float) -> void:
	for i in roundi(seconds):
		cabbage._physics_process(1.0)


func test_a_rotten_cabbage_left_on_the_desk_bursts_after_three_minutes() -> void:
	SaveManager.save.stock = 3
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)

	_tick(rotten, Cabbage.FUSE - 1.0)
	assert_bool(rotten.is_queued_for_deletion()).is_false()

	_tick(rotten, 1.0)
	assert_bool(rotten.is_queued_for_deletion()).is_true()
	assert_int(SaveManager.save.stock).is_equal(2)


func test_holding_a_rotten_cabbage_pauses_its_count_but_does_not_reset_it() -> void:
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	_tick(rotten, 10.0)
	rotten._on_grabbed()
	assert_bool(rotten.burning()).is_false()
	assert_float(rotten.fuse).is_equal(Cabbage.FUSE - 10.0)

	rotten._on_released()
	assert_bool(rotten.burning()).is_true()
	_tick(rotten, 10.0)
	assert_float(rotten.fuse).is_equal(Cabbage.FUSE - 20.0)


func test_a_rotten_cabbage_already_binned_or_sold_never_bursts() -> void:
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	rotten.sold = true
	_tick(rotten, Cabbage.FUSE + 10.0)
	assert_float(rotten.fuse).is_equal(Cabbage.FUSE)


func test_a_fresh_cabbage_never_bursts() -> void:
	var fresh := spawn()
	_tick(fresh, Cabbage.FUSE + 10.0)
	assert_bool(fresh.is_queued_for_deletion()).is_false()


func test_a_burst_leaves_a_grey_green_puff_and_pushes_nothing() -> void:
	var rotten := spawn(func(c: Cabbage) -> void: c.rotten = true)
	var count_before := find_children("*", "CPUParticles3D", false, false).size()
	rotten.burst()
	assert_int(rotten.collision_layer).is_equal(0)
	assert_int(rotten.collision_mask).is_equal(0)
	assert_int(find_children("*", "CPUParticles3D", false, false).size()).is_equal(count_before + 1)


func test_a_rotten_cabbage_only_swells_in_its_last_thirty_seconds_slowly_at_first() -> void:
	assert_float(Cabbage.swell_at(Cabbage.FUSE)).is_equal(1.0)
	assert_float(Cabbage.swell_at(Cabbage.SWELL_FROM)).is_equal(1.0)
	assert_float(Cabbage.swell_at(0.0)).is_equal_approx(1.0 + Cabbage.SWELL, 0.0001)
	assert_float(Cabbage.swell_at(Cabbage.SWELL_FROM / 2.0) - 1.0).is_less(Cabbage.SWELL / 2.0)


func test_a_rotten_cabbage_shakes_harder_toward_the_burst_and_quivers_at_the_end() -> void:
	assert_float(Cabbage.shake_at(60.0)).is_equal(0.0)
	assert_float(Cabbage.shake_at(25.0)).is_less(Cabbage.shake_at(10.0))
	assert_float(Cabbage.shake_at(3.0)).is_greater(Cabbage.shake_at(6.0))
