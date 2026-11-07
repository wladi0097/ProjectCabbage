extends GdUnitTestSuite

const Bin := preload("res://entities/rotten_bin/rotten_bin.gd")


func test_a_unit_lying_beside_the_mouth_drops_in_however_far_below_the_rim() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.0, 0.76, 0.0), Vector3(0.1, 0.0, 0.0), 0.2)).is_true()


func test_a_unit_exactly_at_the_reach_is_not_in_the_mouth() -> void:
	assert_bool(Bin.in_mouth(Vector3.ZERO, Vector3(0.2, 0.9, 0.0), 0.2)).is_false()


func test_a_unit_carried_at_the_top_height_is_not_in_the_bin_yet() -> void:
	assert_bool(Bin.in_mouth(Vector3.ZERO, Vector3(0.0, Bin.TOP_Y + 0.001, 0.0), 0.2)).is_false()


func test_a_rebate_is_a_rounded_share_of_the_chalked_price() -> void:
	assert_int(Bin.rebate_for(0.5, 5)).is_equal(3)
	assert_int(Bin.rebate_for(0.25, 6)).is_equal(2)
	assert_int(Bin.rebate_for(2.0, 7)).is_equal(14)


func _bin_with_cabbage(setup: Callable) -> Array:
	var save := SaveGame.new()
	save.rotten_unlocked = true
	save.stock = 5
	SaveManager.save = save
	var bin: RottenBin = auto_free(preload("res://entities/rotten_bin/rotten_bin.tscn").instantiate())
	add_child(bin)
	var cabbage := preload("res://entities/cabbage/cabbage.tscn").instantiate() as Cabbage
	cabbage.rotten = true
	add_child(auto_free(cabbage))
	cabbage.global_position = bin.global_position + Vector3(0.03, 0.1, 0.0)
	setup.call(cabbage)
	bin._physics_process(1.0)
	return [cabbage, save]


func test_a_unit_rolled_or_bumped_into_the_mouth_is_popped_back_out_not_binned() -> void:
	var was: SaveGame = SaveManager.save
	var got := _bin_with_cabbage(func(_c: Cabbage) -> void: pass)
	var cabbage: Cabbage = got[0]

	assert_bool(cabbage.sold).is_false()
	assert_int((got[1] as SaveGame).stock).is_equal(5)
	assert_float(cabbage.linear_velocity.y).is_greater(0.0)
	SaveManager.save = was


func test_a_unit_the_player_lets_go_of_over_the_mouth_is_binned() -> void:
	var was: SaveGame = SaveManager.save
	var got := _bin_with_cabbage(func(c: Cabbage) -> void: c.get_node("Interactable").released.emit())

	assert_bool((got[0] as Cabbage).sold).is_true()
	assert_int((got[1] as SaveGame).stock).is_equal(4)
	SaveManager.save = was


func test_a_hired_hands_lob_is_binned_but_its_mark_runs_out() -> void:
	var was: SaveGame = SaveManager.save
	var lobbed := _bin_with_cabbage(func(c: Cabbage) -> void: c.aim_for_bin(0.5))
	var stale := _bin_with_cabbage(func(c: Cabbage) -> void: c.aim_for_bin(-0.1))

	assert_bool((lobbed[0] as Cabbage).sold).is_true()
	assert_bool((stale[0] as Cabbage).sold).is_false()
	SaveManager.save = was


func test_a_rejected_unit_never_pops_toward_the_screen_bottom() -> void:
	assert_float(Bin.reject_velocity(Vector3.ZERO, Vector3(0.0, 0.0, 0.05)).z).is_less_equal(0.0)
	assert_float(Bin.reject_velocity(Vector3.ZERO, Vector3.ZERO).z).is_less(0.0)
	assert_float(Bin.reject_velocity(Vector3.ZERO, Vector3(0.05, 0.0, 0.0)).x).is_greater(0.0)
