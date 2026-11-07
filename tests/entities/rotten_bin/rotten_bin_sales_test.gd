extends GdUnitTestSuite

const Bin := preload("res://entities/rotten_bin/rotten_bin.gd")
const Nodes := preload("res://entities/projector/projector.gd")
const Report := preload("res://entities/boss_report/boss_report.gd")
const BIN_SCENE := preload("res://entities/rotten_bin/rotten_bin.tscn")
const BEFORE_COMBO: Array[String] = ["price_slate", "radio", "desk_space", "junior_associate", "acceptance_meter",
		"mini_cabbages", "quality_assurance", "street_posters", "projector", "research_inspection",
		"pricing_consultant", "research_cabbage", "mini_tube"]


func dealt_up_to_combo() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(BEFORE_COMBO)
	save.tray_unlocked = true
	return save


func test_a_cabbage_over_the_mouth_and_low_enough_falls_in() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.95, 0.76, 1.2), Vector3(1.0, 0.9, 1.1), 0.25)).is_true()


func test_a_cabbage_carried_high_over_the_bin_does_not_fall_in() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.95, 0.76, 1.2), Vector3(1.0, 1.3, 1.1), 0.25)).is_false()


func test_a_cabbage_beside_the_bin_does_not_fall_in() -> void:
	assert_bool(Bin.in_mouth(Vector3(0.95, 0.76, 1.2), Vector3(0.5, 0.9, 1.1), 0.25)).is_false()


func test_binning_pays_no_rebate_until_one_is_bought() -> void:
	assert_int(Bin.rebate_for(0.0, 4)).is_equal(0)


func test_a_rebate_pays_its_share_of_the_chalked_price_rounded() -> void:
	assert_int(Bin.rebate_for(1.0, 4)).is_equal(4)
	assert_int(Bin.rebate_for(0.2, 10)).is_equal(2)
	assert_int(Bin.rebate_for(0.45, 5)).is_equal(2)


func test_disposal_rebate_tiers_climb_from_20_to_120_percent_in_25_point_steps() -> void:
	var save := SaveGame.new()
	var tiers: Array[float] = []
	for id in ["bin_rebate", "bin_rebate_2", "bin_rebate_3", "bin_rebate_4", "bin_rebate_5"]:
		Nodes.apply(id, save)
		tiers.append(save.bin_rebate)
	var want: Array[float] = [0.2, 0.45, 0.7, 0.95, 1.2]

	for i in want.size():
		assert_float(tiers[i]).is_equal_approx(want[i], 0.0001)


func test_a_fresh_save_gets_no_rotten_units() -> void:
	assert_bool(Bin.rotten_due(SaveGame.new())).is_false()


func test_no_rotten_units_before_the_catch_combo_is_stamped() -> void:
	assert_bool(Bin.rotten_due(dealt_up_to_combo())).is_false()


func test_stamping_the_catch_combo_starts_rot_and_its_boss_note() -> void:
	var save := dealt_up_to_combo()
	save.stamped.append("catch_combo")

	assert_bool(Bin.rotten_due(save)).is_true()
	assert_array(Report.due(save)).contains(["rotten_units"])


func test_the_bin_arrives_free_with_the_first_rotten_units() -> void:
	var save := dealt_up_to_combo()
	save.stamped.append("catch_combo")
	var coins := save.coins
	var findings := save.findings
	var was: SaveGame = SaveManager.save
	SaveManager.save = save
	var bin: Node3D = auto_free(BIN_SCENE.instantiate())
	add_child(bin)
	assert_bool(bin.visible).is_false()

	bin._process(0.0)

	assert_bool(save.rotten_unlocked).is_true()
	assert_bool(bin.visible).is_true()
	assert_int(save.coins).is_equal(coins)
	assert_int(save.findings).is_equal(findings)
	SaveManager.save = was


func test_a_save_with_rotten_units_already_on_loads_with_the_bin_on_the_desk() -> void:
	var save := dealt_up_to_combo()
	save.rotten_unlocked = true
	var was: SaveGame = SaveManager.save
	SaveManager.save = save
	var bin: Node3D = auto_free(BIN_SCENE.instantiate())
	add_child(bin)

	assert_bool(bin.visible).is_true()
	SaveManager.save = was
