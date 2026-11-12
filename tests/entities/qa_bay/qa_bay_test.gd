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


func test_the_findings_a_unit_yields_count_towards_the_findings_ever_earned() -> void:
	_bay()._take(_unit())
	_bay()._take(_unit(false, true))
	assert_int(_save.findings_earned).is_equal(1 + roundi(_save.research_mult))


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


func test_the_load_gauge_reads_cabbages_on_the_benches_out_of_benches() -> void:
	assert_str(QaBay.load_text(1, 3)).is_equal("1/3")


func test_the_load_gauge_shows_a_cell_per_bench_and_lights_one_per_cabbage_in_the_lab() -> void:
	_save.qa_slots = 2
	var bay := _bay_in_tree()
	var cells: MeshInstance3D = bay.get_node("Gauge/Cells")
	var count: Label3D = bay.get_node("Gauge/Count")
	assert_str(count.text).is_equal("0/2")
	bay._admit(_tube_mini())
	bay._show_load()
	assert_str(count.text).is_equal("1/2")
	assert_float(cells.get_instance_shader_parameter(&"filled")).is_equal(1.0)
	assert_float(cells.get_instance_shader_parameter(&"cells")).is_equal(2.0)


func test_the_load_gauge_grows_a_cell_when_a_bench_is_added() -> void:
	var bay := _bay_in_tree()
	assert_str(bay.get_node("Gauge/Count").text).is_equal("0/1")
	_save.qa_slots += 1
	bay._show_load()
	assert_str(bay.get_node("Gauge/Count").text).is_equal("0/2")
	assert_float(bay.get_node("Gauge/Cells").get_instance_shader_parameter(&"cells")).is_equal(2.0)


func test_the_load_gauge_count_turns_bright_only_when_every_bench_is_busy() -> void:
	_save.qa_slots = 2
	var bay := _bay_in_tree()
	var count: Label3D = bay.get_node("Gauge/Count")
	bay._admit(_tube_mini())
	bay._show_load()
	assert_that(count.modulate).is_equal(QaBay.GAUGE_FREE)
	bay._admit(_tube_mini())
	bay._show_load()
	assert_that(count.modulate).is_equal(QaBay.GAUGE_FULL)
