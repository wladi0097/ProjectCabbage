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
	assert_str(TallyMachine.limit_text("¶", 8000)).is_equal("MAX ¶8K")
	assert_str(TallyMachine.limit_text("$", 16000000)).is_equal("MAX $16M")
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_str(TallyMachine.limit_text("$", 40000, true)).is_equal("FULL $40K")
	TranslationServer.set_locale("de")
	assert_str(TallyMachine.limit_text("$", 40000, true)).is_equal("VOLL $40K")
	TranslationServer.set_locale(was)


const COUNTERS: Array[String] = ["res://entities/tally_machine/tally_machine.tscn", "res://entities/tally_machine/findings_counter.tscn"]

var _real_save: SaveGame
var _real_coins: Callable
var _real_findings: Callable
## What lies unbanked on the desk for the counters under test.
var _unbanked := 0


func before_test() -> void:
	_real_save = SaveManager.save
	_real_coins = SaveManager.pending_coins
	_real_findings = SaveManager.pending_findings
	SaveManager.save = SaveGame.new()
	_unbanked = 0
	SaveManager.pending_coins = func() -> int: return _unbanked
	SaveManager.pending_findings = func() -> int: return _unbanked


func after_test() -> void:
	SaveManager.save = _real_save
	SaveManager.pending_coins = _real_coins
	SaveManager.pending_findings = _real_findings


func _counter(path: String) -> TallyMachine:
	var machine: TallyMachine = auto_free((load(path) as PackedScene).instantiate())
	add_child(machine)
	SaveManager.save.set(machine.field, 0)
	machine._process(0.0)
	return machine


func _fill(machine: TallyMachine, full := true) -> void:
	var save := SaveManager.save
	save.set(machine.field, save.get(SaveGame.LIMITS[machine.field]) if full else 0)
	machine._process(0.0)


## The buzzer sounded since the last ask (and is silenced for the next).
func _buzzed(machine: TallyMachine) -> bool:
	var was := machine._buzzer.playing
	machine._buzzer.stop()
	return was


func test_both_counters_show_their_limit_and_light_full_only_at_it() -> void:
	for path in COUNTERS:
		var machine := _counter(path)
		var limit: int = SaveManager.save.get(SaveGame.LIMITS[machine.field])
		assert_bool(machine._limit.visible).override_failure_message(path).is_true()
		assert_bool(machine._full.visible).is_false()
		assert_str(machine._limit.text).is_equal(TallyMachine.limit_text(machine.mark, limit))
		_fill(machine)
		assert_bool(machine._full.visible).override_failure_message(path).is_true()
		assert_bool(machine._limit.visible).is_false()
		assert_str(machine._full.text).is_equal(TallyMachine.limit_text(machine.mark, limit, true))


func test_the_full_buzzer_sounds_once_when_the_purse_fills_and_not_again_while_it_stays_full() -> void:
	for path in COUNTERS:
		var machine := _counter(path)
		assert_bool(_buzzed(machine)).override_failure_message(path).is_false()
		_fill(machine)
		assert_bool(_buzzed(machine)).override_failure_message(path).is_true()
		for _payout in 50:  # Hired hands keep selling into the full purse, long past the quiet time.
			machine.refuse()
			machine._process(2.0)
			assert_bool(_buzzed(machine)).override_failure_message(path).is_false()


func test_the_full_plate_stays_steady_without_flashing_while_the_purse_is_full() -> void:
	for path in COUNTERS:
		var machine := _counter(path)
		_fill(machine)
		var ink := machine._full.modulate
		for _payout in 20:
			machine.refuse()
			machine._process(0.1)
			assert_bool(machine._full.visible).override_failure_message(path).is_true()
			assert_that(machine._full.modulate).is_equal(ink)


func test_a_full_counter_says_so_in_red_letters_only_with_no_warning_light() -> void:
	for path in COUNTERS:
		var machine := _counter(path)
		_fill(machine)
		assert_array(machine.find_children("*", "Light3D", true, false)).override_failure_message(path).is_empty()


func test_income_refused_because_unbanked_pieces_fill_the_purse_buzzes_once_and_shows_full_until_they_no_longer_fill_it() -> void:
	for path in COUNTERS:
		var machine := _counter(path)
		var limit: int = SaveManager.save.get(SaveGame.LIMITS[machine.field])
		_unbanked = limit  # All of it lies on the desk: the save itself is empty.
		machine.refuse()
		assert_bool(_buzzed(machine)).override_failure_message(path).is_true()
		for banked: int in [0, 1, limit]:  # Banked piece by piece: still full, still quiet.
			SaveManager.save.set(machine.field, banked)
			_unbanked = limit - banked
			machine.refuse()
			machine._process(TallyMachine.QUIET)
			assert_bool(machine._full.visible).override_failure_message(path).is_true()
			assert_bool(_buzzed(machine)).override_failure_message(path).is_false()
		_unbanked = 0
		_fill(machine, false)
		assert_bool(machine._full.visible).override_failure_message(path).is_false()  # MAX again: there is room.
		assert_bool(machine._limit.visible).is_true()


func test_the_buzzer_sounds_again_only_after_there_was_room_in_between() -> void:
	for path in COUNTERS:
		var machine := _counter(path)
		_fill(machine)
		assert_bool(_buzzed(machine)).override_failure_message(path).is_true()
		machine._process(TallyMachine.QUIET * 3.0)  # Full all the while: no room, no buzz.
		assert_bool(_buzzed(machine)).override_failure_message(path).is_false()
		_fill(machine, false)  # Money spent.
		assert_bool(_buzzed(machine)).is_false()
		_fill(machine)
		assert_bool(_buzzed(machine)).override_failure_message(path).is_true()


func test_a_purse_hovering_at_its_limit_does_not_buzz_again_within_the_quiet_time() -> void:
	assert_float(TallyMachine.QUIET).is_equal(30.0)
	for path in COUNTERS:
		var machine := _counter(path)
		_fill(machine)
		assert_bool(_buzzed(machine)).override_failure_message(path).is_true()
		for _second in 29:  # Spends a little, earns it back, every second.
			_fill(machine, false)
			machine._process(0.5)
			_fill(machine)
			machine._process(0.5)
			assert_bool(machine._full.visible).override_failure_message(path).is_true()
			assert_bool(_buzzed(machine)).override_failure_message(path).is_false()
		_fill(machine, false)
		machine._process(1.5)
		_fill(machine)
		assert_bool(_buzzed(machine)).override_failure_message(path).is_true()


func test_each_counter_fills_and_buzzes_on_its_own() -> void:
	var coins := _counter(COUNTERS[0])
	var findings := _counter(COUNTERS[1])
	_fill(coins)
	findings._process(0.0)
	assert_bool(_buzzed(coins)).is_true()
	assert_bool(_buzzed(findings)).is_false()
	assert_bool(findings._full.visible).is_false()
	_fill(findings)
	assert_bool(_buzzed(findings)).is_true()
	assert_bool(_buzzed(coins)).is_false()


func test_no_limit_climbs_past_what_its_counters_drums_can_show() -> void:
	for path: String in ["res://entities/tally_machine/tally_machine.tscn", "res://entities/tally_machine/findings_counter.tscn"]:
		var machine: TallyMachine = auto_free((load(path) as PackedScene).instantiate())
		var limit: StringName = SaveGame.LIMITS[machine.field]
		var top: int = SaveGame.new().get(limit) * UpgradeDesk.LIMIT_RAISE  # The start, the desk card, then every tree step.
		for node: Dictionary in Projector.NODES + FarmTree.NODES:
			top += node.get("add", {}).get(limit, 0)
		assert_int(top).override_failure_message("%s: %d on %d drums" % [path, top, machine.drums]).is_less(int(pow(10.0, machine.drums)))


func test_after_print_larger_numbers_both_counters_show_a_green_readout_over_the_drums() -> void:
	for path: String in COUNTERS:
		var machine := _counter(path)
		assert_bool((machine.get_node("Readout") as Node3D).visible).is_false()
		SaveManager.save.stamped.append(DigitalReadout.CARD)
		machine._process(0.0)
		assert_bool((machine.get_node("Readout") as Node3D).visible).is_true()
		SaveManager.save.stamped = PackedStringArray()


func test_the_coin_readout_prints_past_what_nine_drums_hold() -> void:
	SaveManager.save.stamped.append(DigitalReadout.CARD)
	SaveManager.save.coin_limit = 9000000000000
	var machine := _counter(COUNTERS[0])
	SaveManager.save.coins = 4500000000
	machine._shown = 4500000000.0
	machine._process(0.0)
	assert_str((machine.get_node("Readout/Figures/Ink") as Label3D).text).is_equal("$4.5B")


func test_a_full_purse_still_reads_full_in_red_beside_the_digital_readout() -> void:
	SaveManager.save.stamped.append(DigitalReadout.CARD)
	for path: String in COUNTERS:
		var machine := _counter(path)
		_fill(machine)
		assert_bool((machine.get_node("Full") as Label3D).visible).is_true()
		assert_bool((machine.get_node("Readout") as Node3D).visible).is_true()
