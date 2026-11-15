extends GdUnitTestSuite

const Bin := preload("res://entities/rotten_bin/rotten_bin.gd")
const Report := preload("res://entities/boss_report/boss_report.gd")
const BIN_SCENE := preload("res://entities/rotten_bin/rotten_bin.tscn")
const BEFORE_COMBO: Array[String] = ["price_slate", "radio", "desk_space", "junior_associate", "acceptance_meter",
		"mini_cabbages", "quality_assurance", "street_posters", "projector", "research_inspection",
		"pricing_consultant", "research_cabbage", "mini_tube"]

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


func _dealt_up_to_combo() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(BEFORE_COMBO)
	save.tray_unlocked = true
	return save


func test_a_cabbage_over_the_mouth_and_low_enough_falls_in() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.95, 0.76, 1.2), Vector3(1.0, 0.9, 1.1), 0.25)).is_true()


func test_a_cabbage_beside_the_bin_does_not_fall_in() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.95, 0.76, 1.2), Vector3(0.5, 0.9, 1.1), 0.25)).is_false()


func test_a_unit_lying_beside_the_mouth_drops_in_however_far_below_the_rim() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.0, 0.76, 0.0), Vector3(0.1, 0.0, 0.0), 0.2)).is_true()


func test_a_unit_exactly_at_the_reach_is_not_in_the_mouth() -> void:
	assert_bool(Bin.in_mouth(Vector3.ZERO, Vector3(0.2, 0.9, 0.0), 0.2)).is_false()


func test_a_unit_carried_at_the_top_height_is_not_in_the_bin_yet() -> void:
	assert_bool(Bin.in_mouth(Vector3.ZERO, Vector3(0.0, Bin.TOP_Y + 0.001, 0.0), 0.2)).is_false()


func test_binning_pays_no_rebate_until_one_is_bought() -> void:
	assert_int(Bin.bin_coins_for(PackedStringArray())).is_equal(0)
	assert_int(SaveGame.new().bin_coins).is_equal(0)


func test_an_old_save_with_rebate_tiers_bought_gets_their_flat_dollars() -> void:
	var save := SaveGame.new()
	save.tree_bought = PackedStringArray(["bin_mouth", "bin_rebate", "bin_rebate_2"])
	UpgradeDesk.migrate(save)
	assert_int(save.bin_coins).is_equal(3)


func test_a_binned_rotten_unit_pops_its_rebate_out_as_coins_whatever_the_price() -> void:
	var pile: CoinPile = auto_free(CoinPile.new())
	pile.multimesh = MultiMesh.new()
	add_child(pile)
	pile.set_process(false)  # No camera here for the hand's sweep (Godot turns _process on at ready).
	pile.pop_out(Vector3(0.9, 0.9, 1.0), Vector3(0.8, 0.76, 0.75), 5)
	assert_int(pile.pending_value()).is_equal(5)


func test_a_fresh_save_gets_no_rotten_units() -> void:
	assert_bool(Bin.rotten_due(SaveGame.new())).is_false()


func test_no_rotten_units_before_the_catch_combo_is_stamped() -> void:
	assert_bool(Bin.rotten_due(_dealt_up_to_combo())).is_false()


func test_stamping_the_catch_combo_starts_rot_and_its_boss_note() -> void:
	var save := _dealt_up_to_combo()
	save.stamped.append("catch_combo")

	assert_bool(Bin.rotten_due(save)).is_true()
	assert_array(Report.due(save)).contains(["rotten_units"])


func test_the_bin_arrives_free_with_the_first_rotten_units() -> void:
	var save := _dealt_up_to_combo()
	save.stamped.append("catch_combo")
	var coins := save.coins
	var findings := save.findings
	SaveManager.save = save
	var bin: Node3D = auto_free(BIN_SCENE.instantiate())
	add_child(bin)
	assert_bool(bin.visible).is_false()

	bin._process(0.0)

	assert_bool(save.rotten_unlocked).is_true()
	assert_bool(bin.visible).is_true()
	assert_int(save.coins).is_equal(coins)
	assert_int(save.findings).is_equal(findings)


func test_a_save_with_rotten_units_already_on_loads_with_the_bin_on_the_desk() -> void:
	var save := _dealt_up_to_combo()
	save.rotten_unlocked = true
	SaveManager.save = save
	var bin: Node3D = auto_free(BIN_SCENE.instantiate())
	add_child(bin)

	assert_bool(bin.visible).is_true()


func _bin_with_cabbage(setup: Callable) -> Array:
	var save := SaveGame.new()
	save.rotten_unlocked = true
	save.stock = 5
	SaveManager.save = save
	var bin: RottenBin = auto_free(BIN_SCENE.instantiate())
	add_child(bin)
	var cabbage := preload("res://entities/cabbage/cabbage.tscn").instantiate() as Cabbage
	cabbage.rotten = true
	add_child(auto_free(cabbage))
	cabbage.global_position = bin.global_position + Vector3(0.03, 0.1, 0.0)
	setup.call(cabbage)
	bin._physics_process(1.0)
	return [cabbage, save]


func test_a_unit_rolled_or_bumped_into_the_mouth_is_popped_back_out_not_binned() -> void:
	var got := _bin_with_cabbage(func(_c: Cabbage) -> void: pass)
	var cabbage: Cabbage = got[0]

	assert_bool(cabbage.sold).is_false()
	assert_int((got[1] as SaveGame).stock).is_equal(5)
	assert_float(cabbage.linear_velocity.y).is_greater(0.0)


func test_a_unit_the_player_lets_go_of_over_the_mouth_is_binned() -> void:
	var got := _bin_with_cabbage(func(c: Cabbage) -> void: c.get_node("Interactable").released.emit())

	assert_bool((got[0] as Cabbage).sold).is_true()
	assert_int((got[1] as SaveGame).stock).is_equal(4)


func test_a_unit_let_go_away_from_the_bin_that_rolls_in_is_popped_back_out() -> void:
	var got := _bin_with_cabbage(func(c: Cabbage) -> void:
		var at := c.global_position
		c.global_position = at + Vector3(0.6, 0.0, -0.3)
		c.get_node("Interactable").released.emit()
		c.global_position = at)

	assert_bool((got[0] as Cabbage).sold).is_false()
	assert_int((got[1] as SaveGame).stock).is_equal(5)


func test_a_short_toss_just_past_the_mouth_still_counts_as_aimed_at_the_bin() -> void:
	assert_bool(Bin.let_go_over(Vector3.ZERO, Vector3(0.25, 1.0, 0.0), 0.2)).is_true()
	assert_bool(Bin.let_go_over(Vector3.ZERO, Vector3(0.5, 0.9, 0.0), 0.2)).is_false()


func test_a_hired_hands_lob_is_binned_but_its_mark_runs_out() -> void:
	var lobbed := _bin_with_cabbage(func(c: Cabbage) -> void: c.aim_for_bin(0.5))
	var stale := _bin_with_cabbage(func(c: Cabbage) -> void: c.aim_for_bin(-0.1))

	assert_bool((lobbed[0] as Cabbage).sold).is_true()
	assert_bool((stale[0] as Cabbage).sold).is_false()


func test_a_rejected_unit_never_pops_toward_the_screen_bottom() -> void:
	assert_float(Bin.reject_velocity(Vector3.ZERO, Vector3(0.0, 0.0, 0.05)).z).is_less_equal(0.0)
	assert_float(Bin.reject_velocity(Vector3.ZERO, Vector3.ZERO).z).is_less(0.0)
	assert_float(Bin.reject_velocity(Vector3.ZERO, Vector3(0.05, 0.0, 0.0)).x).is_greater(0.0)


func test_the_fine_notice_says_when_a_rotten_cabbage_burst_on_the_sales_desk() -> void:
	# The untranslated lines (the notice draws them through tr).
	assert_str(FineNotice.notice_line(true)).is_equal("A rotten cabbage burst on the sales desk.")
	assert_str(FineNotice.notice_line(false)).is_equal("A rotten cabbage was offered to the public.")
