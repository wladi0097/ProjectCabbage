extends GdUnitTestSuite


func _assert_drums(value: float, count: int, expected: Array) -> void:
	var got := TallyMachine.drum_positions(value, count)
	assert_int(got.size()).is_equal(count)
	for k in count:
		assert_float(got[k]).override_failure_message("drum %d for %s: %s" % [k, value, got]) \
				.is_equal_approx(expected[k], 0.0001)


func test_at_rest_each_drum_shows_one_digit_of_the_total_ones_first() -> void:
	_assert_drums(1234.0, 5, [4, 3, 2, 1, 0])
	_assert_drums(0.0, 5, [0, 0, 0, 0, 0])


func test_the_ones_drum_rolls_smoothly_between_whole_numbers() -> void:
	_assert_drums(15.25, 5, [5.25, 1, 0, 0, 0])


func test_a_drum_only_turns_while_every_drum_to_its_right_rolls_from_nine_to_zero() -> void:
	_assert_drums(19.5, 5, [9.5, 1.5, 0, 0, 0])
	_assert_drums(999.5, 5, [9.5, 9.5, 9.5, 0.5, 0])
	_assert_drums(1299.5, 5, [9.5, 9.5, 2.5, 1, 0])


func test_a_total_too_big_for_the_drums_rolls_over_like_an_odometer() -> void:
	_assert_drums(1234567.0, 5, [7, 6, 5, 4, 3])
	_assert_drums(999999999.0, 9, [9, 9, 9, 9, 9, 9, 9, 9, 9])
	_assert_drums(1000000000.0, 9, [0, 0, 0, 0, 0, 0, 0, 0, 0])


func test_a_negative_total_shows_all_zeros() -> void:
	_assert_drums(-42.0, 5, [0, 0, 0, 0, 0])


func test_the_tally_and_findings_drum_ticks_wait_at_least_30_ms_between_plays() -> void:
	for scene: PackedScene in [preload("res://entities/tally_machine/tally_machine.tscn"),
			preload("res://entities/tally_machine/findings_counter.tscn")]:
		var machine: Node = auto_free(scene.instantiate())
		assert_float((machine.get_node("Tick") as SoundCue).min_interval).is_equal_approx(0.03, 0.0001)


func test_the_machine_is_lettered_with_the_most_it_holds_and_reads_full_at_the_limit() -> void:
	assert_str(TallyMachine.limit_text("$", 40000)).is_equal("MAX $40K")
	assert_str(TallyMachine.limit_text("¶", 8000)).is_equal("MAX ¶8,000")
	assert_str(TallyMachine.limit_text("$", 16000000)).is_equal("MAX $16M")
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_str(TallyMachine.limit_text("$", 40000, true)).is_equal("FULL $40K")
	TranslationServer.set_locale("de")
	assert_str(TallyMachine.limit_text("$", 40000, true)).is_equal("VOLL $40K")
	TranslationServer.set_locale(was)


func test_both_counters_show_their_limit_and_light_full_only_at_it() -> void:
	var real := SaveManager.save
	var save := SaveGame.new()
	SaveManager.save = save
	for path: String in ["res://entities/tally_machine/tally_machine.tscn", "res://entities/tally_machine/findings_counter.tscn"]:
		var machine: TallyMachine = auto_free((load(path) as PackedScene).instantiate())
		add_child(machine)
		var limit: int = save.get(SaveGame.LIMITS[machine.field])
		save.set(machine.field, 0)
		machine._process(0.0)
		assert_bool(machine._limit.visible).override_failure_message(path).is_true()
		assert_bool(machine._full.visible).is_false()
		assert_bool(machine._lamp.visible).is_false()
		assert_str(machine._limit.text).is_equal(TallyMachine.limit_text(machine.mark, limit))
		save.set(machine.field, limit)
		machine._process(0.0)
		assert_bool(machine._full.visible).override_failure_message(path).is_true()
		assert_bool(machine._lamp.visible).is_true()
		assert_bool(machine._limit.visible).is_false()
		machine.refuse()  # The buzzer and the flash.
		assert_bool(machine._flash.is_running()).is_true()
	SaveManager.save = real


func test_a_refusal_shows_full_and_the_warning_light_for_its_flash_even_while_the_save_has_room() -> void:
	# Coins and tokens lying unbanked on the desk fill the purse: income is refused before the save is full.
	var real := SaveManager.save
	var save := SaveGame.new()
	SaveManager.save = save
	for path: String in ["res://entities/tally_machine/tally_machine.tscn", "res://entities/tally_machine/findings_counter.tscn"]:
		var machine: TallyMachine = auto_free((load(path) as PackedScene).instantiate())
		add_child(machine)
		machine._process(0.0)
		assert_bool(machine._full.visible).override_failure_message(path).is_false()
		machine.refuse()
		machine._process(0.0)
		assert_bool(machine._full.visible).override_failure_message(path).is_true()
		assert_bool(machine._lamp.visible).override_failure_message(path).is_true()
		assert_bool(machine._limit.visible).is_false()
		assert_str(machine._full.text).is_equal(TallyMachine.limit_text(machine.mark, save.get(SaveGame.LIMITS[machine.field]), true))
		machine._flash.custom_step(TallyMachine.FLASH + 0.01)
		machine._process(0.0)
		assert_bool(machine._full.visible).override_failure_message(path).is_false()  # MAX again: there is room.
		assert_bool(machine._lamp.visible).is_false()
		assert_bool(machine._limit.visible).is_true()
	SaveManager.save = real


func test_no_limit_climbs_past_what_its_counters_drums_can_show() -> void:
	for path: String in ["res://entities/tally_machine/tally_machine.tscn", "res://entities/tally_machine/findings_counter.tscn"]:
		var machine: TallyMachine = auto_free((load(path) as PackedScene).instantiate())
		var limit: StringName = SaveGame.LIMITS[machine.field]
		var top: int = SaveGame.new().get(limit) * UpgradeDesk.LIMIT_RAISE  # The start, the desk card, then every tree step.
		for node: Dictionary in Projector.NODES + FarmTree.NODES:
			top += node.get("add", {}).get(limit, 0)
		assert_int(top).override_failure_message("%s: %d on %d drums" % [path, top, machine.drums]).is_less(int(pow(10.0, machine.drums)))
