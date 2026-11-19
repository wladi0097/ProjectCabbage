extends GdUnitTestSuite

var _saved: SaveGame
var _save: SaveGame


func before_test() -> void:
	_saved = SaveManager.save
	_save = SaveGame.new()
	SaveManager.save = _save


func after_test() -> void:
	SaveManager.save = _saved


func _unit(is_mini := false, is_research := false) -> Cabbage:
	var cabbage: Cabbage = auto_free(Cabbage.new())
	cabbage.mini = is_mini
	cabbage.research = is_research
	return cabbage


func _bay() -> QaBay:
	return auto_free(QaBay.new())


func _slip(at: Vector3, value: int, resting := true) -> Node3D:
	var slip: Node3D = auto_free(Node3D.new())
	add_child(slip)
	slip.global_position = at
	slip.set_meta(&"value", value)
	slip.set_meta(&"resting", resting)
	return slip


func test_a_plain_unit_yields_the_findings_per_cabbage() -> void:
	_save.findings_per_cabbage = 2
	assert_float(QaBay.findings_for(_unit(), _save)).is_equal(2.0)


func test_a_research_unit_yields_research_mult_times_the_findings() -> void:
	_save.findings_per_cabbage = 2
	_save.research_mult = 3.0
	assert_float(QaBay.findings_for(_unit(false, true), _save)).is_equal(6.0)


func test_a_mini_is_worth_its_exact_share_of_the_findings() -> void:
	_save.mini_value = 0.25
	_save.findings_per_cabbage = 2
	assert_float(QaBay.findings_for(_unit(true), _save)).is_equal_approx(0.5, 0.0001)


func test_minis_fractions_of_a_finding_add_up_on_the_bay_tally() -> void:
	_save.mini_value = 0.25
	_save.findings_per_cabbage = 2
	var bay := _bay()
	var total := 0
	for i in 4:
		total += bay._take(_unit(true))
	assert_int(total).is_equal(2)


func test_mini_value_upgrades_raise_a_research_minis_findings() -> void:
	_save.findings_per_cabbage = 3
	var findings_at := func(value: float) -> int:
		_save.mini_value = value
		var bay := _bay()
		var total := 0
		for i in 12:
			total += bay._take(_unit(true))
		return total
	var base: int = findings_at.call(0.25)
	var portion_review: int = findings_at.call(0.33)
	var half_unit: int = findings_at.call(0.5)
	assert_int(base).is_equal(9)
	assert_int(portion_review).is_greater(base)
	assert_int(half_unit).is_equal(18)


func test_a_research_mini_yields_two_units_of_findings_with_the_micro_sample_protocol() -> void:
	_save.findings_per_cabbage = 3
	_save.mini_value = 0.25
	_save.stamped.append("micro_samples")
	assert_int(_bay()._take(_unit(true))).is_equal(6)


func test_the_micro_sample_protocol_stacks_with_the_mini_value_upgrades() -> void:
	_save.findings_per_cabbage = 1
	_save.stamped.append("micro_samples")
	_save.mini_value = 0.25
	assert_float(QaBay.findings_for(_unit(true), _save)).is_equal_approx(2.0, 0.0001)
	_save.mini_value = 0.33
	assert_float(QaBay.findings_for(_unit(true), _save)).is_equal_approx(2.64, 0.0001)
	_save.mini_value = 0.5
	assert_float(QaBay.findings_for(_unit(true), _save)).is_equal_approx(4.0, 0.0001)


func test_a_tally_yields_the_whole_findings_and_keeps_the_fraction() -> void:
	var counted := QaBay.tally(0.5, 0.75)
	assert_int(counted[0]).is_equal(1)
	assert_float(counted[1]).is_equal_approx(0.25, 0.0001)
	assert_int(QaBay.tally(0.0, 0.99)[0]).is_equal(0)
	assert_int(QaBay.tally(0.0, 3.0 * (1.0 / 3.0))[0]).is_equal(1)


func test_a_unit_taken_in_costs_one_stock_and_a_mini_costs_none() -> void:
	_save.stock = 5
	_bay()._take(_unit())
	assert_int(_save.stock).is_equal(4)
	_bay()._take(_unit(true))
	assert_int(_save.stock).is_equal(4)


func test_a_research_unit_taken_in_is_counted() -> void:
	_bay()._take(_unit(false, true))
	_bay()._take(_unit())
	assert_int(_save.research_units).is_equal(1)


func test_the_bay_has_room_only_while_a_bench_is_free() -> void:
	var bay := _bay()
	_save.qa_slots = 2
	bay._jobs = [1.0] as Array[float]
	assert_bool(bay.has_room()).is_true()
	bay._jobs = [1.0, 0.5] as Array[float]
	assert_bool(bay.has_room()).is_false()


func test_a_bay_not_delivered_yet_has_no_room() -> void:
	var bay := _bay()
	bay.visible = false
	assert_bool(bay.has_room()).is_false()


func test_a_vacuum_takes_only_resting_slips_within_its_reach() -> void:
	var bay := _bay()
	var near := _slip(Vector3(0.05, 0.76, 0.0), 1)
	var flying := _slip(Vector3(0.0, 0.76, 0.02), 5, false)
	var far := _slip(Vector3(0.3, 0.76, 0.0), 10)
	bay._slips = [near, flying, far] as Array[Node3D]

	var got := bay.vacuum_at(Vector3.ZERO, 0.07, 8)

	assert_array(got).contains_exactly([near])
	assert_bool(near.visible).is_false()
	assert_array(bay.resting_spots()).has_size(1)


func test_a_vacuum_takes_no_more_slips_than_its_bag_has_room_for() -> void:
	var bay := _bay()
	bay._slips = [_slip(Vector3.ZERO, 1), _slip(Vector3.ZERO, 1), _slip(Vector3.ZERO, 1)] as Array[Node3D]
	assert_array(bay.vacuum_at(Vector3.ZERO, 0.07, 2)).has_size(2)
	assert_array(bay.vacuum_at(Vector3.ZERO, 0.07, 0)).is_empty()


func test_slips_in_a_vacuum_bag_still_count_as_pending_findings() -> void:
	var bay := _bay()
	bay._slips = [_slip(Vector3.ZERO, 5), _slip(Vector3.ZERO, 1, false)] as Array[Node3D]
	bay.vacuum_at(Vector3.ZERO, 0.07, 8)
	assert_int(bay.pending_findings()).is_equal(6)


func test_quitting_files_the_units_on_the_benches_and_the_unfiled_slips() -> void:
	var bay := _bay()
	_save.findings = 3
	bay._jobs = [2.0, 0.5] as Array[float]
	bay._yields = [6, 1] as Array[int]
	bay._slips = [_slip(Vector3.ZERO, 10), _slip(Vector3.ZERO, 5, false)] as Array[Node3D]

	bay._file_pending()

	assert_int(_save.findings).is_equal(3 + 7 + 15)
	assert_int(bay.pending_findings()).is_equal(0)
	assert_array(bay._jobs).is_empty()


## The window: records what the street is asked to throw back, never touches its own scene.
class FakeWindow extends SaleWindow:
	var thrown: Array[Cabbage] = []

	func split() -> void:
		pass

	func _send_back(cabbage: Cabbage, _wait: float, _refused_unit := false) -> void:
		thrown.append(cabbage)


## The bay scene in the tree, delivered, with a fake window and counter.
func _bay_in_tree() -> QaBay:
	_save.stamped = PackedStringArray(["quality_assurance"])
	var bay: QaBay = auto_free(preload("res://entities/qa_bay/qa_bay.tscn").instantiate())
	bay.window = auto_free(FakeWindow.new())
	bay.counter = auto_free(Node3D.new())
	add_child(bay)
	bay.set_process(false)  # The hand's sweep needs a camera.
	return bay


func test_a_finished_cabbage_ejects_only_the_findings_that_still_fit_under_the_research_limit() -> void:
	var bay := _bay_in_tree()
	_save.findings = _save.findings_limit - 7
	bay._eject(5)
	assert_int(bay.pending_findings()).is_equal(5)
	bay._eject(5)  # Only 2 more fit beside the 5 already out.
	assert_int(bay.pending_findings()).is_equal(7)
	bay._eject(5)  # Full: nothing comes out.
	assert_int(bay.pending_findings()).is_equal(7)
	bay._file_pending()
	assert_int(_save.findings).is_equal(_save.findings_limit)


func test_a_slip_high_on_the_pile_is_swept_up_where_it_shows_under_the_hand() -> void:
	var bay := _bay_in_tree()
	var intake := Node3D.new()
	intake.name = "Intake"
	bay.counter.add_child(intake)
	add_child(bay.counter)
	var rise := Vector3(0.0, 1.0, 0.55)  # the game camera's mouse ray per metre up
	var low := _slip(Vector3(0.0, QaBay.DESK_Y + 0.01, 0.5), 1)
	var high := _slip(Vector3(0.0, QaBay.DESK_Y + 0.25, 0.5), 5)
	var far := _slip(Vector3(0.0, QaBay.DESK_Y + 0.01, 0.1), 10)
	bay._slips = [low, high, far] as Array[Node3D]
	# The hand drawn right over the high slip: its ray meets the desk 0.14 m short of the slip's foot.
	var hand := Vector3(0.0, QaBay.DESK_Y, 0.5 - 0.25 * 0.55)
	bay._sweep(hand, hand, rise)
	assert_bool(high.get_meta(&"resting")).is_false()
	assert_bool(low.get_meta(&"resting")).is_true()
	assert_bool(far.get_meta(&"resting")).is_true()


func test_a_slip_landing_under_a_still_hand_is_taken() -> void:
	var bay := _bay_in_tree()
	var intake := Node3D.new()
	intake.name = "Intake"
	bay.counter.add_child(intake)
	add_child(bay.counter)
	var rise := Vector3(0.0, 1.0, 0.55)
	var hand := Vector3(0.0, QaBay.DESK_Y, 0.5)
	var other := _slip(Vector3(0.6, QaBay.DESK_Y + 0.01, 0.5), 1)
	var flying := _slip(Vector3(0.0, QaBay.DESK_Y + 0.01, 0.5), 5, false)
	bay._slips = [other, flying] as Array[Node3D]
	bay._sweep(hand, hand, rise)
	bay._sweep(hand, hand, rise)
	bay._settle_slip(flying)
	bay._sweep(hand, hand, rise)
	assert_bool(flying.get_meta(&"resting")).is_false()
	assert_bool(other.get_meta(&"resting")).is_true()


## A mini as the tube hands it over: hidden, frozen, out of the physics.
func _tube_mini() -> Cabbage:
	var cabbage: Cabbage = auto_free(preload("res://entities/cabbage/cabbage.tscn").instantiate())
	cabbage.mini = true
	add_child(cabbage)
	cabbage.freeze = true
	cabbage.collision_layer = 0
	cabbage.visible = false
	return cabbage


func test_a_tube_mini_for_research_appears_in_the_mouth_and_takes_a_bench_like_a_thrown_one() -> void:
	var bay := _bay_in_tree()
	var unit := _tube_mini()
	_save.findings = 0

	bay.file_direct(unit)

	assert_bool(unit.visible).is_true()
	assert_vector(unit.global_position).is_equal_approx(bay.mouth(), Vector3.ONE * 0.0001)
	assert_bool(unit.sold).is_true()
	assert_array(bay._jobs).has_size(1)
	assert_int(_save.findings).is_equal(0)
	assert_array((bay.window as FakeWindow).thrown).is_empty()


func test_a_tube_mini_for_a_full_bay_is_thrown_back_onto_the_mat_like_a_refused_unit_unseen_until_thrown() -> void:
	var bay := _bay_in_tree()
	bay._jobs = [0.5] as Array[float]
	var unit := _tube_mini()

	bay.file_direct(unit)

	assert_array((bay.window as FakeWindow).thrown).contains_exactly([unit])
	assert_bool(unit.visible).is_false()
	assert_bool(unit.sold).is_false()
	assert_bool(unit.away).is_true()
	assert_array(bay._jobs).has_size(1)


func test_the_flap_lies_flat_when_open_and_stands_up_when_shut() -> void:
	assert_float(QaBay.flap_angle(0.0)).is_equal(0.0)
	assert_float(QaBay.flap_angle(1.0)).is_equal_approx(-PI / 2.0, 0.0001)


func test_a_grown_mini_taken_in_costs_no_stock_and_yields_a_full_units_findings() -> void:
	_save.stock = 5
	_save.findings_per_cabbage = 3
	var unit := _unit()
	unit.grown = true
	assert_int(_bay()._take(unit)).is_equal(3)
	assert_int(_save.stock).is_equal(5)


func test_a_golden_unit_yields_golden_lab_times_the_findings() -> void:
	_save.findings_per_cabbage = 2
	var gold := _unit()
	gold.golden = true
	assert_float(QaBay.findings_for(gold, _save)).is_equal(20.0)
	_save.golden_lab = 25.0
	assert_float(QaBay.findings_for(gold, _save)).is_equal(50.0)


func test_findings_count_as_earned_when_they_are_filed_and_only_what_fit_under_the_limit() -> void:
	var bay := _bay_in_tree()
	bay._take(_unit())
	assert_int(_save.findings_earned).is_equal(0)  # On the bench: not earned yet.
	_save.findings = _save.findings_limit - 7
	bay._eject(5)
	bay._eject(5)  # Only 2 more fit: 3 are lost.
	bay._file_pending()
	assert_int(_save.findings).is_equal(_save.findings_limit)
	assert_int(_save.findings_earned).is_equal(7)


func test_the_autosave_counts_the_findings_on_the_benches_in_slips_and_held_back() -> void:
	var bay := _bay_in_tree()
	bay._yields.append(4)  # A unit on a bench.
	bay._backlog = 3  # Held back: the desk in front is full.
	bay._slips.append(_slip(Vector3.ZERO, 2))
	assert_int(bay.unfiled()).is_equal(9)
	assert_int(SaveManager.pending_findings.call()).is_equal(9)
	bay._slips.clear()


func test_a_golden_unit_taken_in_is_counted_as_analysed() -> void:
	var gold := _unit()
	gold.golden = true
	_bay()._take(gold)
	_bay()._take(_unit())
	assert_int(_save.golden_analysed).is_equal(1)


func test_managerial_research_gives_more_findings_only_for_cabbages_the_player_flicked_in() -> void:
	_save.findings_per_cabbage = 10
	_save.own_lab = 1.2
	assert_float(QaBay.findings_for(_unit(), _save)).is_equal_approx(12.0, 0.0001)
	var lobbed := _unit()
	lobbed.lobbed = true  # A lab hand's delivery.
	assert_float(QaBay.findings_for(lobbed, _save)).is_equal(10.0)
	var tubed := _unit(true)
	tubed.tubed = true  # A tube mini.
	assert_float(QaBay.findings_for(tubed, _save)).is_equal_approx(10.0 * _save.mini_value, 0.0001)
	var research := _unit(false, true)
	assert_float(QaBay.findings_for(research, _save)).is_equal_approx(10.0 * _save.research_mult * 1.2, 0.0001)


## The jewel lamps that show: lit (busy) or dark glass (free); hidden lamps are blanked-off sockets.
func _lamps(bay: QaBay) -> Array[String]:
	var out: Array[String] = []
	for lamp: MeshInstance3D in bay.get_node("Gauge/Lamps").get_children():
		if lamp.visible:
			out.append("busy" if lamp.get_surface_override_material(0) == bay.lamp_busy else "free")
	return out


func test_the_load_gauge_has_a_jewel_lamp_socket_for_each_of_the_five_benches_the_lab_can_have() -> void:
	assert_int(_bay_in_tree().get_node("Gauge/Lamps").get_child_count()).is_equal(QaBay.MAX_BENCHES)
	assert_int(QaBay.MAX_BENCHES).is_equal(5)


func test_every_lamp_lens_faces_out_of_the_console_so_it_sits_round_in_its_socket() -> void:
	var bay := _bay_in_tree()
	var lenses: Array[Node] = bay.get_node("Gauge/Lamps").get_children()
	lenses.append(bay.get_node("BusyLamp"))
	for lens: MeshInstance3D in lenses:
		# The lens is a squashed sphere: its flat axis (local y) must be the console face's normal.
		var sphere := lens.mesh as SphereMesh
		assert_float(sphere.height).is_less(sphere.radius * 2.0)
		var flat := (bay.global_basis.inverse() * lens.global_basis.y).normalized()
		assert_float(flat.dot(QaBay.NEEDLE_AXIS.normalized())).override_failure_message(
				"%s shows its edge" % lens.name).is_greater(0.999)


func test_the_load_gauge_lights_one_jewel_lamp_per_cabbage_on_the_benches() -> void:
	_save.qa_slots = 3
	var bay := _bay_in_tree()
	assert_array(_lamps(bay)).contains_exactly(["free", "free", "free"])
	bay._admit(_tube_mini())
	bay._show_load()
	assert_array(_lamps(bay)).contains_exactly(["busy", "free", "free"])
	bay._admit(_tube_mini())
	bay._admit(_tube_mini())
	bay._show_load()
	assert_array(_lamps(bay)).contains_exactly(["busy", "busy", "busy"])


func test_a_bench_not_bought_yet_is_a_blanked_off_socket_and_buying_it_fills_the_next_one() -> void:
	var bay := _bay_in_tree()
	var lamps := bay.get_node("Gauge/Lamps").get_children()
	var first: Vector3 = lamps[0].position
	assert_array(_lamps(bay)).contains_exactly(["free"])
	_save.qa_slots = 5
	bay._show_load()
	assert_array(_lamps(bay)).contains_exactly(["free", "free", "free", "free", "free"])
	assert_vector(lamps[0].position).is_equal(first)
	for i in lamps.size():
		assert_bool(lamps[i].visible).is_true()


## A collision box's extent along world x, with the bay where MainStoryWorld puts it.
func _world_x(bay: QaBay, path: String) -> Vector2:
	var node: CollisionShape3D = bay.get_node(path)
	var half: float = (node.shape as BoxShape3D).size.x / 2.0
	var x := _bay_world_x() + node.position.x
	return Vector2(x - half, x + half)


func _bay_world_x() -> float:
	var state := (load("res://worlds/MainStoryWorld.tscn") as PackedScene).get_state()
	for n in state.get_node_count():
		if state.get_node_name(n) == &"QaBay":
			for p in state.get_node_property_count(n):
				if state.get_node_property_name(n, p) == &"transform":
					return (state.get_node_property_value(n, p) as Transform3D).origin.x
	return NAN


func test_the_bays_right_wall_ends_where_the_windows_sale_side_begins() -> void:
	var bay := _bay_in_tree()
	assert_float(_world_x(bay, "Body/Cheek").y).is_less_equal(SaleWindow.SPLIT_X + 0.0001)
	assert_float(_world_x(bay, "Body/Cheek").y).is_greater(SaleWindow.SPLIT_X - 0.01)


func test_a_whole_cabbage_fits_through_the_mouth_between_the_console_and_the_right_wall() -> void:
	var bay := _bay_in_tree()
	var inside := _world_x(bay, "Chamber/Shape")
	assert_float(_world_x(bay, "Body/Panel").y).is_less_equal(inside.x)
	assert_float(_world_x(bay, "Body/Cheek").x).is_greater_equal(inside.y)
	# A full cabbage is shown at 1.5 x its 0.18 m mesh.
	assert_float(inside.y - inside.x).is_greater(0.27)


func test_a_findings_payout_comes_as_the_fewest_tokens_each_drawn_as_its_own_denomination() -> void:
	var bay := _bay_in_tree()
	var drawn: Array[String] = []
	for value in CoinPile.coin_values(166):
		drawn.append(QaBay.slip_template(value))
	assert_array(drawn).contains_exactly_in_any_order(["Slip100", "Slip50", "Slip10", "Slip5", "Slip1"])
	for template in drawn:
		assert_object(bay.get_node_or_null(template)).is_not_null()


func test_a_hundred_findings_payout_ejects_one_hundred_token_bigger_than_a_fifty_and_a_ten() -> void:
	var bay := _bay_in_tree()
	bay._eject(100)
	assert_array(bay._slips).has_size(1)
	assert_int(bay._slips[0].get_meta(&"value")).is_equal(100)
	var token := bay._slips[0] as MeshInstance3D
	var hundred: MeshInstance3D = bay.get_node("Slip100")
	assert_object(token.get_surface_override_material(0)).is_same(hundred.get_surface_override_material(0))
	var size := func(template: String) -> float: return (bay.get_node(template) as Node3D).scale.x
	assert_float(size.call("Slip100")).is_greater(size.call("Slip50"))
	assert_float(size.call("Slip50")).is_greater(size.call("Slip10"))
	var look := func(template: String) -> Material: return (bay.get_node(template) as MeshInstance3D).get_surface_override_material(0)
	assert_object(look.call("Slip100")).is_not_equal(look.call("Slip10"))
	assert_object(look.call("Slip50")).is_not_equal(look.call("Slip10"))
	assert_object(look.call("Slip100")).is_not_equal(look.call("Slip50"))


func test_findings_tokens_stop_at_ten_thousand_even_with_the_coins_past_it_open() -> void:
	assert_bool(CoinPile.coin_values(5000000).all(func(v: int) -> bool: return QaBay.slip_template(v) == "Slip10000")).is_true()
	assert_str(QaBay.slip_template(1000000000)).is_equal("Slip10000")
	var tens_k: Array[int] = [10000, 10000, 10000, 10000, 10000]
	assert_array(CoinPile.merge_pick(tens_k, 1000000000)).is_empty()  # The bay merges with the default: no ¶50K.


func test_a_big_findings_payout_comes_as_a_handful_of_high_tokens_each_bigger_than_the_last() -> void:
	var bay := _bay_in_tree()
	var ten_k := CoinPile.coin_values(10000)
	assert_array(ten_k).has_size(20)
	assert_bool(ten_k.all(func(v: int) -> bool: return QaBay.slip_template(v) == "Slip500")).is_true()
	var templates := {}
	for amount: int in [26000, 140000, 400000, 5000000]:
		for value in CoinPile.coin_values(amount):
			templates[QaBay.slip_template(value)] = true
	assert_array(templates.keys()).contains(["Slip1000", "Slip5000", "Slip10000"])
	var previous := 0.0
	for denomination in CoinPile.DENOMINATIONS.slice(0, CoinPile.OLD_COINS):
		var template: MeshInstance3D = bay.get_node(QaBay.slip_template(denomination))
		assert_float(template.scale.x).is_greater(previous)
		previous = template.scale.x
	for high in ["Slip500", "Slip1000", "Slip5000", "Slip10000"]:
		var look: Material = (bay.get_node(high) as MeshInstance3D).get_surface_override_material(0)
		assert_str(look.resource_path).starts_with("res://assets/materials/findings_token_")
	_save.findings_limit = 40000  # Room for it (the archive card's limit).
	bay._eject(10000)
	assert_array(bay._slips).has_size(20)
	var total := 0
	for slip in bay._slips:
		total += slip.get_meta(&"value")
	assert_int(total).is_equal(10000)



func test_a_condensed_cabbage_in_the_lab_gives_twice_the_findings() -> void:
	_save.findings_per_cabbage = 3
	var dense := _unit()
	dense.units = 2
	assert_float(QaBay.findings_for(dense, _save)).is_equal(6.0)
	assert_float(QaBay.findings_for(_unit(), _save)).is_equal(3.0)
	_save.stock = 10
	assert_int(_bay()._take(dense)).is_equal(6)
	assert_int(_save.stock).is_equal(8)


func test_a_condensed_research_cabbage_counts_as_two_research_cabbages_analysed() -> void:
	_save.findings_per_cabbage = 1
	var dense := _unit(false, true)
	dense.units = 2
	assert_float(QaBay.findings_for(dense, _save)).is_equal(2.0 * roundf(_save.research_mult))
	_bay()._take(dense)
	assert_int(_save.research_units).is_equal(2)


func test_a_token_lands_right_in_front_of_the_mouth_and_a_full_spot_sends_the_next_one_further_out() -> void:
	var thick := QaBay.SLIP_HALF * 2.0
	var first: Vector2i = QaBay.slip_cell({}, thick)
	assert_int(first.y).is_equal(0)
	var piles := {first: QaBay.SLIP_REACH}
	var next: Vector2i = QaBay.slip_cell(piles, thick)
	assert_that(next).is_not_equal(first)
	assert_int(maxi(absi(next.x - first.x), absi(next.y - first.y))).is_equal(1)
	# Still room for a thin token on a spot that a thick one no longer fits on.
	assert_that(QaBay.slip_cell({first: QaBay.SLIP_REACH - thick}, thick)).is_equal(first)
	assert_that(QaBay.slip_cell({first: QaBay.SLIP_REACH - thick}, thick * 2.0)).is_not_equal(first)


func test_no_token_comes_to_rest_above_the_reach_height_and_findings_are_held_back_while_the_desk_is_full() -> void:
	var bay := _bay_in_tree()
	for i in 60:
		bay._eject(3)
	var cells := QaBay.slip_cells()
	assert_int(bay._slips.size()).is_less_equal(cells.x * cells.y * 3)
	var piles := bay._piles()
	assert_int(piles.size()).is_equal(cells.x * cells.y)
	for cell: Vector2i in piles:
		assert_float(piles[cell]).is_less_equal(QaBay.SLIP_REACH + 0.0001)
		assert_bool(Rect2i(Vector2i.ZERO, cells).has_point(cell)).is_true()
	# Nothing is lost while tokens are held back.
	assert_int(bay._backlog).is_equal(180 - bay._slips.size())
	assert_int(bay.pending_findings()).is_equal(180)


func test_held_back_findings_drop_as_the_fewest_tokens_when_room_appears_and_nothing_is_lost() -> void:
	var bay := _bay_in_tree()
	for i in 60:
		bay._eject(3)
	var out := bay._slips.size()
	for slip: Node3D in bay._slips.duplicate():
		bay._file(slip)
	assert_int(_save.findings).is_equal(out)
	bay._drop()
	assert_int(bay._backlog).is_equal(0)
	assert_int(bay._slips.size()).is_equal(CoinPile.coin_values(180 - out).size())
	assert_int(_save.findings + bay.pending_findings()).is_equal(180)


func test_a_token_whose_pile_was_taken_from_under_it_drops_onto_the_desk() -> void:
	var bay := _bay_in_tree()
	bay._eject(2)
	var low := bay._slips[0]
	var high := bay._slips[1]
	assert_that(high.get_meta(&"cell")).is_equal(low.get_meta(&"cell"))
	for slip: Node3D in [low, high]:
		slip.set_meta(&"resting", true)
	bay._restack()
	assert_float(high.global_position.y).is_greater(low.global_position.y)
	bay._file(low)
	bay._restack()
	assert_float(high.global_position.y).is_equal_approx(QaBay.DESK_Y + float(high.get_meta(&"thick")) * 0.5, 0.0001)


func test_findings_tokens_merge_like_coins_and_the_merged_token_keeps_their_worth() -> void:
	var bay := _bay_in_tree()
	var tokens: Array[Node3D] = []
	for i in 5:
		var slip := _slip(Vector3(0.0, QaBay.DESK_Y + 0.01, 0.5), 1)
		slip.set_meta(&"cell", Vector2i(0, 0))
		slip.set_meta(&"thick", 0.01)
		tokens.append(slip)
	tokens.append(_slip(Vector3(0.0, QaBay.DESK_Y + 0.01, 0.5), 10))
	tokens[-1].set_meta(&"cell", Vector2i(1, 0))
	tokens[-1].set_meta(&"thick", 0.01)
	bay._slips = tokens
	assert_bool(bay.merge_once(100)).is_true()
	assert_int(bay.pending_findings()).is_equal(15)
	assert_bool(tokens[5].get_meta(&"resting")).is_true()  # The ¶10 is not part of it.
	bay._merged(tokens.slice(0, 5) as Array[Node3D], 5, Vector3(0.0, QaBay.DESK_Y + 0.05, 0.5))
	assert_int(bay.pending_findings()).is_equal(15)
	assert_int(bay._slips.size()).is_equal(2)
	assert_bool(bay._slips.any(func(s: Node3D) -> bool: return s.get_meta(&"value") == 5)).is_true()


func test_merging_findings_tokens_wobble_in_place_before_they_fly_together() -> void:
	var bay := _bay_in_tree()
	var tokens: Array[Node3D] = []
	for i in 5:
		var slip := _slip(Vector3(0.2 * i, QaBay.DESK_Y + 0.005, 0.5), 1)
		slip.set_meta(&"cell", Vector2i(i, 0))
		slip.set_meta(&"thick", 0.01)
		tokens.append(slip)
	bay._slips = tokens.duplicate()
	var far := tokens[0]  # the spot is the newest token's (tokens[4])
	var rest := far.global_position
	assert_bool(bay.merge_once(100)).is_true()
	await await_millis(int(CoinPile.MERGE_SHAKE * 600.0))
	# Mid-wobble: no further than the wobble from where it lay (the flight would have taken it centimetres).
	assert_float(far.global_position.distance_to(rest)).is_less_equal(CoinPile.MERGE_SHAKE_SIZE + 0.0005)
	await await_millis(int((CoinPile.MERGE_SHAKE + CoinPile.MERGE_TIME * 0.5) * 1000.0))
	assert_float(far.global_position.distance_to(rest)).is_greater(0.05)  # Then off together.


func test_a_running_research_light_multiplies_the_findings_of_a_cabbage_taken_into_the_lab() -> void:
	assert_float(QaBay.boosted(6.0, false, {}, _save)).is_equal(6.0)
	assert_float(QaBay.boosted(6.0, false, {lab_lamp = 5.0}, _save)).is_equal(30.0)


func test_golden_cabbages_skip_the_research_light_until_its_projector_node() -> void:
	assert_float(QaBay.boosted(20.0, true, {lab_lamp = 5.0}, _save)).is_equal(20.0)
	_save.tree_bought.append(QaBay.LAB_GOLD)
	assert_float(QaBay.boosted(20.0, true, {lab_lamp = 5.0}, _save)).is_equal(100.0)


func test_quitting_mid_merge_frees_the_slips_without_the_merge_touching_them_again() -> void:
	var bay := _bay_in_tree()
	var tokens: Array[Node3D] = []
	for i in 5:
		var slip := _slip(Vector3(0.2 * i, QaBay.DESK_Y + 0.005, 0.5), 1)
		slip.set_meta(&"cell", Vector2i(i, 0))
		slip.set_meta(&"thick", 0.01)
		tokens.append(slip)
	bay._slips = tokens.duplicate()
	assert_bool(bay.merge_once(100)).is_true()
	var merge: Tween = bay._merges[-1]
	bay._file_pending()  # Quitting: every slip filed and freed.
	assert_bool(merge.is_valid()).is_false()  # The flight is cut off with them.
	await await_millis(int((CoinPile.MERGE_SHAKE + CoinPile.MERGE_TIME) * 1000.0) + 100)
	for slip: Variant in tokens:
		assert_bool(is_instance_valid(slip)).is_false()
	assert_int(_save.findings).is_equal(5)
