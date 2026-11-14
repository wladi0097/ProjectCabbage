extends GdUnitTestSuite

const ASSOCIATE := preload("res://entities/associate/associate.tscn")
const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const Feeder := preload("res://worlds/components/cabbage_feeder.gd")
## Somewhere off the mat toward the bottom right, like a parked hand.
const ENTRY := Vector3(1.15, 1.2, 1.75)
## MainStoryWorld's QaBay at (-0.08, 0.75, -0.8): mouth (0.055, 0.89, -0.84), front plane z -0.64,
## opening x -0.07..0.335 local, y 0.76..1.035.
const BAY_MOUTH := Vector3(0.055, 0.89, -0.84)
const BAY_FRONT_Z := -0.64
const BAY_OPENING := Rect2(-0.07, 0.76, 0.405, 0.275)
const BAY_X := -0.08
const CABBAGE_RADIUS := 0.11
## The world camera (MainStoryWorld) and its 16:9 frame.
const CAMERA_AT := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.4826, -0.8758), Vector3(0, 0.8758, 0.4826)), Vector3(0.25, 3.2, 1.6))
## MainStoryWorld's RottenBin x.
const BIN_X := 0.95

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


func _cabbage(at: Vector3, rotten := false, research := false, golden := false) -> Cabbage:
	var cabbage := CABBAGE.instantiate() as Cabbage
	cabbage.rotten = rotten
	cabbage.research = research
	cabbage.golden = golden
	add_child(auto_free(cabbage))
	cabbage.global_position = at
	return cabbage


func _grip(cabbage: Cabbage) -> Interactable:
	return cabbage.get_node("Interactable") as Interactable


func _hand(research := false) -> Associate:
	var hand := ASSOCIATE.instantiate() as Associate
	hand.research = research
	add_child(auto_free(hand))
	hand.set_process(false)
	return hand


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity"))


## Height at which a lob from `from` to `aim` in `time` seconds crosses the plane z = `z`.
func _height_at_z(from: Vector3, aim: Vector3, time: float, z: float) -> float:
	var v := Feeder.ballistic_velocity(from, aim, time)
	var t := (z - from.z) / v.z
	return from.y + v.y * t - 0.5 * _gravity() * t * t


func test_a_hand_takes_the_nearest_free_cabbage_on_the_mat() -> void:
	var near := _cabbage(Vector3(1.2, 0.87, 0.9))
	_cabbage(Vector3(0.9, 0.87, 0.6))

	assert_object(Associate.pick_target([near], ENTRY, null)).is_same(near)
	assert_object(Associate.pick_target(get_tree().get_nodes_in_group(&"cabbages"), ENTRY, null)).is_same(near)


func test_a_hand_leaves_the_cabbage_the_player_holds() -> void:
	var held := _cabbage(Vector3(1.2, 0.87, 0.9))
	var other := _cabbage(Vector3(0.9, 0.87, 0.6))

	assert_object(Associate.pick_target([held, other], ENTRY, _grip(held))).is_same(other)


func test_a_hand_never_goes_for_a_cabbage_another_hand_has_claimed() -> void:
	var claimed := _cabbage(Vector3(1.2, 0.87, 0.9))
	var other := _cabbage(Vector3(0.2, 0.87, 0.0))

	assert_object(Associate.pick_target([claimed, other], ENTRY, null, [claimed])).is_same(other)


func test_sold_frozen_flying_and_moving_cabbages_are_not_targets() -> void:
	var sold := _cabbage(Vector3(1.2, 0.87, 0.9))
	sold.sold = true
	var frozen := _cabbage(Vector3(0.9, 0.87, 0.6))
	frozen.freeze = true
	var away := _cabbage(Vector3(0.8, 0.87, 0.5))
	away.away = true
	var flying := _cabbage(Vector3(0.7, 0.87, 0.4))
	flying.in_flight = true
	var rolling := _cabbage(Vector3(0.6, 0.87, 0.3))
	rolling.linear_velocity = Vector3.RIGHT * (Associate.REST_SPEED + 0.1)

	assert_object(Associate.pick_target([sold, frozen, away, flying, rolling], ENTRY, null)).is_null()


func test_a_stray_cabbage_off_the_mat_is_not_a_target() -> void:
	var stray := _cabbage(Vector3(-1.2, 0.87, 0.3))

	assert_object(Associate.pick_target([stray], ENTRY, null)).is_null()


func test_rotten_units_are_taken_like_the_rest_until_the_spoilage_memo() -> void:
	var rotten := _cabbage(Vector3(1.1, 0.87, 1.0), true)

	assert_object(Associate.pick_target([rotten], ENTRY, null)).is_same(rotten)
	assert_object(Associate.pick_target([rotten], ENTRY, null, [], true)).is_null()


func test_the_spoilage_memo_keeps_hands_off_rotten_units_until_they_bin_them() -> void:
	var save := SaveGame.new()
	assert_bool(Associate.skips_rotten(save)).is_false()

	save.stamped.append("spoilage_memo")
	assert_bool(Associate.skips_rotten(save)).is_true()

	save.hands_bin = 1
	assert_bool(Associate.skips_rotten(save)).is_false()


func test_a_research_hand_never_takes_a_rotten_unit() -> void:
	var rotten := _cabbage(Vector3(1.1, 0.87, 1.0), true)

	assert_object(Associate.pick_target([rotten], ENTRY, null, [], false, true)).is_null()


func test_before_lab_priority_research_units_go_to_whichever_hand_is_nearest() -> void:
	var unit := _cabbage(Vector3(0.6, 0.87, 0.75), false, true)
	var plain := _cabbage(Vector3(0.0, 0.87, 0.3))
	var lab_entry := Associate.park_spot(0, true)

	assert_object(Associate.pick_target([plain, unit], ENTRY, null)).is_same(unit)
	assert_object(Associate.pick_target([plain, unit], lab_entry, null, [], false, true)).is_same(plain)


func test_under_lab_priority_money_hands_leave_research_units_alone() -> void:
	var unit := _cabbage(Vector3(0.6, 0.87, 0.75), false, true)
	var plain := _cabbage(Vector3(0.0, 0.87, 0.3))

	assert_object(Associate.pick_target([plain, unit], ENTRY, null, [], false, false, true)).is_same(plain)
	assert_object(Associate.pick_target([unit], ENTRY, null, [], false, false, true)).is_null()


func test_under_lab_priority_research_hands_take_research_units_before_nearer_plain_ones() -> void:
	var unit := _cabbage(Vector3(0.6, 0.87, 0.75), false, true)
	var plain := _cabbage(Vector3(0.0, 0.87, 0.3))
	var lab_entry := Associate.park_spot(0, true)

	assert_object(Associate.pick_target([plain, unit], lab_entry, null, [], false, true, true)).is_same(unit)
	assert_object(Associate.pick_target([plain, unit], lab_entry, null, [unit], false, true, true)).is_same(plain)


func test_no_hand_takes_a_golden_cabbage_until_its_projector_node_is_bought() -> void:
	var gold := _cabbage(Vector3(1.2, 0.87, 0.9), false, false, true)
	var plain := _cabbage(Vector3(0.6, 0.87, 0.3))
	var lab_entry := Associate.park_spot(0, true)

	assert_object(Associate.pick_target([gold, plain], ENTRY, null)).is_same(plain)
	assert_object(Associate.pick_target([gold], ENTRY, null)).is_null()
	assert_object(Associate.pick_target([gold], lab_entry, null, [], false, true)).is_null()
	assert_object(Associate.pick_target([gold], lab_entry, null, [], false, true, true)).is_null()


func test_with_its_node_a_hand_takes_a_golden_cabbage_like_any_other() -> void:
	var gold := _cabbage(Vector3(1.2, 0.87, 0.9), false, false, true)
	_cabbage(Vector3(0.6, 0.87, 0.3))

	assert_object(Associate.pick_target(get_tree().get_nodes_in_group(&"cabbages"), ENTRY, null, [], false, false, false, true)).is_same(gold)
	assert_object(Associate.pick_target([gold], Associate.park_spot(0, true), null, [], false, true, false, true)).is_same(gold)


func test_bullion_clearance_frees_golden_cabbages_for_hired_hands_and_the_sample_protocol_for_lab_hands_only() -> void:
	var save := SaveGame.new()
	assert_bool(Associate.takes_golden(save, false)).is_false()
	assert_bool(Associate.takes_golden(save, true)).is_false()

	save.tree_bought.append(Associate.GOLD_SALE)
	assert_bool(Associate.takes_golden(save, false)).is_true()
	assert_bool(Associate.takes_golden(save, true)).is_false()

	save.tree_bought = PackedStringArray([Associate.GOLD_LAB])
	assert_bool(Associate.takes_golden(save, false)).is_false()
	assert_bool(Associate.takes_golden(save, true)).is_true()


func test_the_golden_hand_nodes_hang_under_the_golden_branch_and_cost_coins() -> void:
	assert_that(Projector.node_data(Associate.GOLD_SALE).get("parent")).is_equal("gold_sale_1")
	assert_that(Projector.node_data(Associate.GOLD_LAB).get("parent")).is_equal("gold_lab_1")
	for id: String in [Associate.GOLD_SALE, Associate.GOLD_LAB]:
		assert_int(int(Projector.node_data(id).price)).is_between(5000, 20000)


func test_a_hired_hand_without_the_clearance_leaves_a_golden_cabbage_and_looks_again() -> void:
	SaveManager.save.hands = 1
	_cabbage(Vector3(0.6, 0.87, 0.3), false, false, true)
	var hand := _hand()

	hand._set_off()

	assert_object(hand._target).is_null()
	assert_float(hand._wait).is_equal(Associate.RETRY)


func test_a_hand_is_snatched_from_only_when_the_player_holds_its_own_cabbage() -> void:
	var mine := _cabbage(Vector3(1.2, 0.87, 0.9))
	var other := _cabbage(Vector3(0.9, 0.87, 0.6))

	assert_bool(Associate.snatched(mine, _grip(mine))).is_true()
	assert_bool(Associate.snatched(other, _grip(mine))).is_false()
	assert_bool(Associate.snatched(mine, null)).is_false()
	assert_bool(Associate.snatched(null, _grip(mine))).is_false()


func test_a_hand_gives_up_when_its_cabbage_is_taken_sold_or_gone() -> void:
	var target := _cabbage(Vector3(1.2, 0.87, 0.9))
	assert_bool(Associate.gives_up(target, null)).is_false()
	assert_bool(Associate.gives_up(target, _grip(target))).is_true()
	assert_bool(Associate.gives_up(null, null)).is_true()

	target.sold = true
	assert_bool(Associate.gives_up(target, null)).is_true()


func test_a_hand_whose_cabbage_is_sold_from_under_it_gives_up_the_reach_without_error() -> void:
	SaveManager.save.hands = 1
	var target := _cabbage(Vector3(0.2, 0.87, 0.0))
	var hand := _hand()
	hand._set_off()
	assert_object(hand._target).is_same(target)

	target.free()
	hand._process(0.016)

	assert_int(hand._phase).is_equal(Associate.Phase.WITHDRAW)
	assert_object(hand._target).is_null()


func test_a_hand_gives_up_on_a_cabbage_that_rolled_off_the_mat() -> void:
	var target := _cabbage(Vector3(-1.2, 0.87, 0.3))

	assert_bool(Associate.gives_up(target, null)).is_true()


func test_rotten_units_go_in_the_bin_only_once_waste_handling_is_bought_and_the_bin_is_on_the_desk() -> void:
	var rotten := _cabbage(Vector3(1.1, 0.87, 1.0), true)
	var plain := _cabbage(Vector3(0.9, 0.87, 0.6))
	var bin := auto_free(RottenBin.new()) as RottenBin

	assert_object(Associate.bin_for(rotten, 0, bin)).is_null()
	assert_object(Associate.bin_for(rotten, 1, bin)).is_same(bin)
	assert_object(Associate.bin_for(plain, 1, bin)).is_null()
	assert_object(Associate.bin_for(rotten, 1, null)).is_null()

	bin.visible = false
	assert_object(Associate.bin_for(rotten, 1, bin)).is_null()


func test_a_carried_cabbage_stays_pickable_but_collides_with_nothing() -> void:
	var cabbage := _cabbage(Vector3(1.2, 0.87, 0.9))

	assert_int(Associate.CARRIED_LAYER & Hand.PLAY_AREA_LAYER).is_equal(0)
	assert_int(Associate.CARRIED_LAYER & cabbage.collision_mask).is_equal(0)


func test_every_lob_lands_in_the_right_third_of_the_window_gap() -> void:
	var right := SaleWindow.GAP_X.y - 0.3 * (SaleWindow.GAP_X.y - SaleWindow.GAP_X.x)
	for roll: float in [0.0, 1.0]:
		for jitter: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
			assert_float(Associate.aim_at(roll, jitter).x).is_between(right - 0.02, 1.7)


func test_every_lob_clears_the_sill_and_stays_under_the_wall_above_the_gap() -> void:
	for roll: float in [0.0, 1.0]:
		for jitter: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
			var aim := Associate.aim_at(roll, jitter)
			var from := Vector3(aim.x, Associate.RELEASE_Y, Associate.RELEASE_Z)
			for lob: float in [Associate.LOB_TIME - Associate.LOB_JITTER, Associate.LOB_TIME + Associate.LOB_JITTER]:
				assert_float(_height_at_z(from, aim, lob, -0.6)).is_between(0.8, 1.12)


func test_a_research_hand_tosses_its_unit_cleanly_through_the_qa_bay_mouth() -> void:
	var from := BAY_MOUTH + Associate.RESEARCH_RELEASE
	for jitter: float in [-1.0, 1.0]:
		var aim := Associate.bay_aim(BAY_MOUTH, jitter)
		var y := _height_at_z(from, aim, Associate.BAY_LOB, BAY_FRONT_Z)
		assert_float(y).is_between(BAY_OPENING.position.y + CABBAGE_RADIUS, BAY_OPENING.end.y - CABBAGE_RADIUS)
		assert_float(aim.x).is_between(BAY_X + BAY_OPENING.position.x + CABBAGE_RADIUS, BAY_X + BAY_OPENING.end.x - CABBAGE_RADIUS)


func test_idle_hands_rest_inside_the_bottom_screen_edge_clear_of_the_bin() -> void:
	var view := auto_free(SubViewport.new()) as SubViewport
	view.size = Vector2i(1920, 1080)
	add_child(view)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.transform = CAMERA_AT
	view.add_child(camera)
	for research: bool in [false, true]:
		for i in (Associate.MAX_RESEARCH if research else Associate.MAX_VISIBLE):
			var spot := Associate.park_spot(i, research)
			var on_screen := camera.unproject_position(spot) / Vector2(view.size)
			assert_float(absf(spot.x - BIN_X)).is_greater_equal(Associate.BIN_CLEAR)
			assert_float(on_screen.x).is_between(0.03, 0.97)
			assert_float(on_screen.y).is_between(0.8, 0.97)


func test_research_hands_pile_left_of_every_money_hand_so_their_lanes_never_cross() -> void:
	var research_right := -INF
	for i in Associate.MAX_RESEARCH:
		research_right = maxf(research_right, Associate.park_spot(i, true).x)
	for i in Associate.MAX_VISIBLE:
		assert_float(Associate.park_spot(i, false).x).is_greater(research_right)


func test_every_pile_row_of_money_hands_rests_a_layer_higher_on_the_one_before() -> void:
	for i in range(Associate.PILE_ROW, Associate.MAX_VISIBLE):
		var below := Associate.park_spot(i - Associate.PILE_ROW, false)
		assert_float(Associate.park_spot(i, false).y).is_greater_equal(below.y + Associate.PILE_LAYER - 1e-4)


func test_each_research_hand_rests_a_layer_above_the_last() -> void:
	for i in range(1, Associate.MAX_RESEARCH):
		assert_float(Associate.park_spot(i, true).y).is_equal_approx(Associate.park_spot(i - 1, true).y + Associate.PILE_LAYER, 1e-4)


func test_a_parked_hand_keeps_its_spot_and_is_turned_no_more_than_the_pile_allows() -> void:
	for i in Associate.MAX_VISIBLE:
		assert_vector(Associate.park_spot(i, false)).is_equal(Associate.park_spot(i, false))
		assert_float(absf(Associate.park_turn(i))).is_less_equal(Associate.PILE_TURN + 1e-4)


func test_hiring_a_hand_adds_exactly_one_to_the_payroll() -> void:
	var save := SaveGame.new()
	Associate.add_hand(save)
	Associate.add_hand(save)

	assert_int(save.hands).is_equal(2)


func test_each_hand_first_sets_off_a_stagger_later_than_the_one_before() -> void:
	var first := _hand()
	var second := ASSOCIATE.instantiate() as Associate
	second.index = 1
	add_child(auto_free(second))
	second.set_process(false)

	assert_float(first._wait).is_equal(Associate.FIRST_WAIT)
	assert_float(second._wait).is_equal(Associate.FIRST_WAIT + Associate.STAGGER)


func test_a_hand_sets_off_again_every_associate_interval_divided_by_its_output() -> void:
	SaveManager.save.hands = 1
	SaveManager.save.associate_interval = 8.0
	SaveManager.save.hand_output = 2.0
	var cabbage := _cabbage(Vector3(0.2, 0.87, 0.0))
	var hand := _hand()

	hand._set_off()

	assert_object(hand._target).is_same(cabbage)
	assert_float(hand._wait).is_between(4.0 * (1.0 - Associate.WAIT_JITTER), 4.0 * (1.0 + Associate.WAIT_JITTER))


func test_past_ten_hands_the_visible_ones_share_the_extra_hands_trips() -> void:
	SaveManager.save.hands = Associate.MAX_VISIBLE * 2
	SaveManager.save.associate_interval = 8.0
	_cabbage(Vector3(0.2, 0.87, 0.0))
	var hand := _hand()

	hand._set_off()

	assert_float(hand._wait).is_between(4.0 * (1.0 - Associate.WAIT_JITTER), 4.0 * (1.0 + Associate.WAIT_JITTER))


func test_with_nothing_to_take_a_hand_looks_again_a_second_later() -> void:
	SaveManager.save.hands = 1
	var hand := _hand()

	hand._set_off()

	assert_object(hand._target).is_null()
	assert_float(hand._wait).is_equal(Associate.RETRY)


func test_a_research_hand_waits_while_there_is_no_qa_bay_with_room() -> void:
	SaveManager.save.research_hands = 1
	_cabbage(Vector3(0.2, 0.87, 0.0))
	var hand := _hand(true)

	hand._set_off()

	assert_object(hand._target).is_null()
	assert_float(hand._wait).is_equal(Associate.RETRY)


func test_hand_speed_upgrades_scale_every_move() -> void:
	SaveManager.save.associate_speed = 2.0
	var hand := _hand()
	var start := hand._tip

	hand._move(start + Vector3.RIGHT * 10.0, Associate.REACH_SPEED, 1.0)

	assert_float(hand._tip.distance_to(start)).is_equal_approx(Associate.REACH_SPEED * 2.0, 1e-4)


func test_the_associates_grab_sound_waits_a_tenth_of_a_second_between_plays() -> void:
	var associate: Node = auto_free(ASSOCIATE.instantiate())
	assert_float((associate.get_node("Grab") as SoundCue).min_interval).is_equal(0.1)



func test_two_handed_policy_makes_each_hand_throw_two_cabbages_a_trip() -> void:
	var save := SaveGame.new()
	assert_bool(Associate.throws_again(1, save.hand_trip, false)).is_false()  # One a trip to start.
	save.stamped = PackedStringArray(["projector", "junior_associate", "big_ideas"])
	save.tree_bought = PackedStringArray(["hire_associate_2", "hire_associate_3", "hire_associate_4", "hire_associate_5",
			"hire_associate_6", "hire_associate_7", "headcount_2"])
	save.coins = Projector.node_data("two_handed").price
	assert_bool(Projector.buy("two_handed", save)).is_true()
	assert_int(save.hand_trip).is_equal(2)
	assert_bool(Associate.throws_again(1, save.hand_trip, false)).is_true()
	assert_bool(Associate.throws_again(2, save.hand_trip, false)).is_false()
	assert_bool(Associate.throws_again(1, save.hand_trip, true)).is_false()  # Lab hands go home.


func test_a_hand_that_has_thrown_goes_for_a_second_cabbage_without_going_home_first() -> void:
	SaveManager.save.hands = 1
	SaveManager.save.hand_trip = 2
	var hand := _hand()
	var first := _cabbage(Vector3(0.6, 0.87, 0.4))
	var second := _cabbage(Vector3(0.9, 0.87, 0.5))
	first.freeze = false
	second.freeze = false
	hand._set_off()
	var taken: Cabbage = hand._target
	assert_object(taken).is_not_null()
	# What the hand's trip does once it is over the cabbage, then at the release point.
	hand._take()
	hand._throw()
	assert_int(hand._thrown).is_equal(1)
	assert_bool(Associate.throws_again(hand._thrown, SaveManager.save.hand_trip, false)).is_true()
	taken.sold = true  # It went out of the window.
	assert_bool(hand._pick(hand._tip)).is_true()
	assert_object(hand._target).is_same(second if taken == first else first)
	assert_int(hand._phase).is_equal(Associate.Phase.REACH)


# ---- The HANDLING ASSIGNMENT SCHEDULE (entities/hand_schedule/): kinds struck for a kind of hand.
func test_a_regular_hand_leaves_a_cabbage_kind_its_schedule_forbids() -> void:
	var plain := _cabbage(Vector3(1.2, 0.87, 0.9))
	var blue := _cabbage(Vector3(0.0, 0.87, 0.3), false, true)

	assert_object(Associate.pick_target([plain, blue], ENTRY, null, [], false, false, false, false, PackedStringArray(["regular"]))).is_same(blue)
	assert_object(Associate.pick_target([plain], ENTRY, null, [], false, false, false, false, PackedStringArray(["regular"]))).is_null()
	assert_object(Associate.pick_target([plain, blue], ENTRY, null, [], false, false, false, false, PackedStringArray(["research"]))).is_same(plain)


func test_research_hands_still_take_what_regular_hands_are_forbidden() -> void:
	var save := SaveManager.save
	save.stamped.append(HandSchedule.CARD)
	save.tree_bought.append(HandSchedule.NODES.research)
	HandSchedule.toggle(save, false, "research")
	var blue := _cabbage(Vector3(0.6, 0.87, 0.3), false, true)
	var lab_entry := Associate.park_spot(0, true)

	assert_object(Associate.pick_target([blue], ENTRY, null, [], false, false, false, false, HandSchedule.forbidden(save, false))).is_null()
	assert_object(Associate.pick_target([blue], lab_entry, null, [], false, true, false, false, HandSchedule.forbidden(save, true))).is_same(blue)


func test_a_lab_hand_struck_for_plain_cabbages_takes_only_the_blue_ones() -> void:
	var plain := _cabbage(Vector3(-0.2, 0.87, 0.9))
	var blue := _cabbage(Vector3(1.2, 0.87, 0.0), false, true)
	var lab_entry := Associate.park_spot(0, true)

	assert_object(Associate.pick_target([plain, blue], lab_entry, null, [], false, true, false, false, PackedStringArray(["regular"]))).is_same(blue)


func test_the_schedule_never_lets_a_hand_take_gold_it_is_not_cleared_for() -> void:
	var gold := _cabbage(Vector3(1.2, 0.87, 0.9), false, false, true)
	var lab_entry := Associate.park_spot(0, true)

	# Nothing struck, no clearance: left alone. Cleared and struck: left alone too.
	assert_object(Associate.pick_target([gold], ENTRY, null, [], false, false, false, false, PackedStringArray())).is_null()
	assert_object(Associate.pick_target([gold], lab_entry, null, [], false, true, false, false, PackedStringArray())).is_null()
	assert_object(Associate.pick_target([gold], ENTRY, null, [], false, false, false, true, PackedStringArray(["golden"]))).is_null()
	assert_object(Associate.pick_target([gold], ENTRY, null, [], false, false, false, true, PackedStringArray(["regular"]))).is_same(gold)


func test_the_schedule_does_not_cover_rotten_cabbages_the_memo_and_the_bin_protocol_do() -> void:
	var rotten := _cabbage(Vector3(1.2, 0.87, 0.9), true)
	var all := PackedStringArray(HandSchedule.KINDS)

	assert_object(Associate.pick_target([rotten], ENTRY, null, [], false, false, false, false, all)).is_same(rotten)
	assert_object(Associate.pick_target([rotten], ENTRY, null, [], true, false, false, false, all)).is_null()


func test_a_hired_hand_struck_for_every_plain_cabbage_stays_home_and_looks_again() -> void:
	var save := SaveManager.save
	save.hands = 1
	save.stamped.append(HandSchedule.CARD)
	HandSchedule.toggle(save, false, "regular")
	HandSchedule.toggle(save, true, "regular")
	_cabbage(Vector3(0.6, 0.87, 0.3))
	var hand := _hand()

	hand._set_off()

	assert_object(hand._target).is_null()
	assert_float(hand._wait).is_equal(Associate.RETRY)


func test_a_hand_lets_a_cabbage_lie_that_is_struck_while_it_reaches_for_it() -> void:
	var save := SaveManager.save
	save.stamped.append(HandSchedule.CARD)
	var plain := _cabbage(Vector3(0.6, 0.87, 0.3))

	assert_bool(Associate.struck(plain, save, false)).is_false()
	HandSchedule.toggle(save, false, "regular")
	assert_bool(Associate.struck(plain, save, false)).is_true()
	assert_bool(Associate.struck(plain, save, true)).override_failure_message("lab hands were not struck").is_false()
	assert_bool(Associate.struck(null, save, false)).override_failure_message("a freed target").is_false()
