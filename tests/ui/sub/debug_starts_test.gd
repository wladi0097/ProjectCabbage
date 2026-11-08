extends GdUnitTestSuite

const DebugStarts := preload("res://ui/sub/debug_starts.gd")


func _key(physical: Key, keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = physical
	key.keycode = keycode
	key.pressed = true
	return key


func test_the_key_left_of_one_opens_the_start_points_on_any_layout() -> void:
	assert_bool(DebugStarts.is_toggle(_key(KEY_QUOTELEFT, KEY_NONE))).is_true()
	assert_bool(DebugStarts.is_toggle(_key(KEY_NONE, KEY_ASCIICIRCUM))).is_true()
	assert_bool(DebugStarts.is_toggle(_key(KEY_1, KEY_1))).is_false()


func test_start_points_are_listed_in_file_name_order() -> void:
	var list := DebugStarts.entries()
	assert_int(list.size()).is_greater(0)
	var sorted := list.duplicate()
	sorted.sort()
	assert_array(Array(list)).is_equal(Array(sorted))


func test_every_prepared_start_point_still_loads_as_a_save() -> void:
	for path in DebugStarts.entries():
		var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
		assert_object(save).override_failure_message("%s does not load" % path).is_not_null()


func test_a_start_points_label_keeps_its_number_and_reads_as_words() -> void:
	assert_str(DebugStarts.label_of("res://x/20_farm_just_bought.tres")).is_equal("20  Farm Just Bought")
	assert_str(DebugStarts.label_of("res://x/late_game.tres")).is_equal("Late Game")


func test_a_typed_name_becomes_a_safe_file_name() -> void:
	assert_str(DebugStarts.stem_for("  30 Farm CH2!/.. ")).is_equal("30_farm_ch2")


func test_a_saved_start_point_drops_the_playtest_log_but_keeps_the_rest() -> void:
	var save := SaveGame.new()
	save.coins = 1234
	save.playtest_log = [{kind = "snapshot"}]
	var copy := DebugStarts.prepared(save)
	assert_int(copy.coins).is_equal(1234)
	assert_array(copy.playtest_log).is_empty()
	assert_array(save.playtest_log).has_size(1)
