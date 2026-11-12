extends GdUnitTestSuite

const Feeder := preload("res://worlds/components/cabbage_feeder.gd")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


func test_the_chute_sends_a_unit_while_the_mat_has_room_and_stock_is_left() -> void:
	assert_bool(Feeder.should_dispense(0, 0, 1, 10)).is_true()
	assert_bool(Feeder.should_dispense(1, 1, 3, 2)).is_true()


func test_a_full_mat_stops_the_chute() -> void:
	assert_bool(Feeder.should_dispense(1, 1, 1, 10)).is_false()
	assert_bool(Feeder.should_dispense(1, 3, 1, 10)).is_false()


func test_the_chute_never_sends_more_units_than_there_is_stock() -> void:
	assert_bool(Feeder.should_dispense(0, 0, 1, 0)).is_false()
	assert_bool(Feeder.should_dispense(1, 1, 3, 1)).is_false()
	assert_bool(Feeder.should_dispense(0, 2, 1, 2)).is_false()


func test_rotten_units_on_the_mat_take_no_place_from_fresh_ones() -> void:
	assert_bool(Feeder.should_dispense(0, 2, 1, 10)).is_true()


func test_the_wait_after_a_sale_spreads_over_half_to_one_and_a_half_times_the_delay() -> void:
	assert_float(Feeder.restock_wait(2.0, 0.0)).is_equal(1.0)
	assert_float(Feeder.restock_wait(2.0, 0.5)).is_equal(2.0)
	assert_float(Feeder.restock_wait(2.0, 1.0)).is_equal(3.0)


func test_no_unit_comes_down_rotten_before_rotten_units_are_unlocked() -> void:
	assert_bool(Feeder.is_rotten(false, 0.0)).is_false()


func test_once_unlocked_one_unit_in_eight_comes_down_rotten() -> void:
	assert_bool(Feeder.is_rotten(true, 0.0)).is_true()
	assert_bool(Feeder.is_rotten(true, 1.0 / Feeder.ROTTEN_EVERY - 0.001)).is_true()
	assert_bool(Feeder.is_rotten(true, 1.0 / Feeder.ROTTEN_EVERY)).is_false()
	assert_bool(Feeder.is_rotten(true, 0.5)).is_false()


func test_with_two_rotten_units_on_the_mat_the_chute_sends_fresh_ones_only() -> void:
	assert_bool(Feeder.is_rotten(true, 0.0, Feeder.MAX_ROTTEN - 1)).is_true()
	assert_bool(Feeder.is_rotten(true, 0.0, Feeder.MAX_ROTTEN)).is_false()


func test_research_units_only_come_once_the_card_is_stamped() -> void:
	assert_bool(Feeder.is_research(false, 0.0, 0.1)).is_false()


func test_a_stamped_research_card_makes_research_chance_of_the_units_research_units() -> void:
	assert_bool(Feeder.is_research(true, 0.05, 0.1)).is_true()
	assert_bool(Feeder.is_research(true, 0.1, 0.1)).is_false()
	assert_bool(Feeder.is_research(true, 0.5, 0.1)).is_false()


## The chute without its scene: records whether each unit rolled was owed as a research unit.
class TestFeeder extends Feeder:
	var rolled: Array[bool] = []

	func _roll() -> void:
		rolled.append(_research_due)
		_research_due = false


func _feeder_on_a_full_mat(save: SaveGame) -> TestFeeder:
	save.stock = 20
	save.desk_capacity = 1
	var feeder: TestFeeder = auto_free(TestFeeder.new())
	var on_mat: Cabbage = auto_free(Cabbage.new())
	feeder._on_desk = [on_mat] as Array[Cabbage]
	feeder._cooldown = 5.0
	return feeder


func test_stamping_the_research_card_rolls_a_research_unit_at_once_even_onto_a_full_mat() -> void:
	var save := SaveGame.new()
	SaveManager.save = save
	var feeder := _feeder_on_a_full_mat(save)
	feeder._physics_process(0.016)
	assert_array(feeder.rolled).is_empty()

	save.stamped.append("research_cabbage")
	feeder._physics_process(0.016)
	feeder._physics_process(0.016)

	assert_array(feeder.rolled).contains_exactly([true])


func test_a_bigger_research_share_rolls_another_research_unit_at_once() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["research_cabbage"])
	SaveManager.save = save
	var feeder := _feeder_on_a_full_mat(save)
	feeder._physics_process(0.016)
	assert_array(feeder.rolled).is_empty()

	save.research_chance += 0.05
	feeder._physics_process(0.016)

	assert_array(feeder.rolled).contains_exactly([true])


func test_a_flung_cabbage_lands_on_its_target_after_the_flight_time() -> void:
	var from := Vector3(1.5, 0.9, 0.8)
	var to := Vector3(0.6, 0.85, 0.5)
	var t := Feeder.FLIGHT_TIME
	var velocity := Feeder.ballistic_velocity(from, to, t)
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	assert_vector(from + velocity * t + 0.5 * gravity * t * t).is_equal_approx(to, Vector3.ONE * 0.0001)


## The chute's script with nothing of its scene running, to fling units by hand.
class BareFeeder extends Feeder:
	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


func _fling_one(catchable: bool) -> Cabbage:
	var feeder: BareFeeder = auto_free(BareFeeder.new())
	add_child(feeder)
	var cabbage: Cabbage = auto_free(preload("res://entities/cabbage/cabbage.tscn").instantiate())
	add_child(cabbage)
	cabbage.freeze = true
	feeder._fling(cabbage, cabbage.get_node("Interactable") as Interactable, catchable)
	return cabbage


func test_a_unit_off_the_chute_is_catchable_in_mid_air() -> void:
	assert_bool(_fling_one(true).in_flight).is_true()


func test_a_research_unit_owed_by_a_purchase_lands_without_being_a_catch_or_a_miss() -> void:
	assert_bool(_fling_one(false).in_flight).is_false()


func test_a_blocked_chute_drops_no_units() -> void:
	assert_bool(Feeder.should_dispense(0, 0, 1, 10, true)).is_false()


func test_a_blocked_chute_rolls_nothing_while_stock_piles_up() -> void:
	var save := SaveGame.new()
	save.stock = 20
	save.chute_blocked = true
	SaveManager.save = save
	var feeder: TestFeeder = auto_free(TestFeeder.new())
	for i in 3:
		feeder._physics_process(1.0)
	assert_array(feeder.rolled).is_empty()


func test_lifting_the_lever_lets_units_come_down_again() -> void:
	var save := SaveGame.new()
	save.stock = 20
	save.chute_blocked = true
	SaveManager.save = save
	var feeder: TestFeeder = auto_free(TestFeeder.new())
	feeder._physics_process(1.0)
	save.chute_blocked = false
	feeder._physics_process(1.0)
	assert_array(feeder.rolled).has_size(1)


func test_golden_units_come_down_at_their_share_of_the_stock_left_off_the_mat() -> void:
	# 2 golden of 10 in stock, 2 units on the mat (none golden): 2 of the 8 left are golden.
	assert_bool(Feeder.is_golden(2, 0, 10, 2, 0.24)).is_true()
	assert_bool(Feeder.is_golden(2, 0, 10, 2, 0.26)).is_false()
	assert_bool(Feeder.is_golden(0, 0, 10, 0, 0.0)).is_false()


func test_golden_units_already_on_the_mat_are_not_sent_again() -> void:
	assert_bool(Feeder.is_golden(1, 1, 10, 1, 0.0)).is_false()
	assert_bool(Feeder.is_golden(3, 0, 3, 3, 0.0)).is_false()


func test_the_playtest_clocks_count_time_with_no_stock_a_full_mat_and_a_shut_chute() -> void:
	var save := SaveGame.new()
	save.stock = 0
	Feeder.clock(save, 2.0, false)
	save.stock = 5
	save.chute_blocked = true
	Feeder.clock(save, 3.0, true)
	assert_float(save.empty_seconds).is_equal_approx(2.0, 0.0001)
	assert_float(save.mat_full_seconds).is_equal_approx(3.0, 0.0001)
	assert_float(save.chute_shut_seconds).is_equal_approx(3.0, 0.0001)
