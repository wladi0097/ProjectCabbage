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


func test_a_flying_cabbage_that_hits_something_is_no_longer_catchable() -> void:
	var cabbage := spawn()
	cabbage.in_flight = true
	cabbage.body_entered.emit(cabbage)

	assert_bool(cabbage.in_flight).is_false()
	assert_bool((cabbage.get_node("Interactable") as Interactable).catchable).is_false()


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
	var cabbage := spawn()
	cabbage.in_flight = true
	cabbage.body_entered.emit(cabbage)

	assert_int(tally.misses).is_equal(1)


func test_a_caught_unit_is_no_miss_when_it_later_touches_something() -> void:
	var tally := miss_log()
	var cabbage := spawn()
	cabbage.set_physics_process(false)
	cabbage.in_flight = true
	(cabbage.get_node("Interactable") as Interactable).grabbed.emit()
	cabbage.body_entered.emit(cabbage)

	assert_int(tally.misses).is_equal(0)


func test_a_unit_bumping_about_on_the_mat_is_no_miss() -> void:
	var tally := miss_log()
	spawn().body_entered.emit(null)

	assert_int(tally.misses).is_equal(0)


func test_a_mini_falling_from_upstairs_never_breaks_the_streak() -> void:
	var tally := miss_log()
	var cabbage := spawn(func(c: Cabbage) -> void: c.mini = true)
	cabbage.in_flight = true
	cabbage.body_entered.emit(cabbage)

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
