extends GdUnitTestSuite

const ROUND_TRIP_PATH := "user://save_game_test_round_trip.tres"
const LOG_PATH := "user://save_game_test_log.csv"


func after_test() -> void:
	for path in [ROUND_TRIP_PATH, LOG_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_a_new_game_starts_with_ten_units_to_sell_two_dollars_chalked_and_nothing_unlocked() -> void:
	var save := SaveGame.new()
	assert_int(save.stock).is_equal(10)
	assert_int(save.coins).is_equal(0)
	assert_int(save.sold).is_equal(0)
	assert_int(save.sale_price).is_equal(2)
	assert_int(save.desk_capacity).is_equal(1)
	assert_int(save.pack_size).is_equal(10)
	assert_int(save.hands).is_equal(0)
	assert_float(save.marketing).is_equal(1.0)
	assert_float(save.demand_mood).is_equal(1.0)
	assert_bool(save.buy_unlocked or save.slate_unlocked or save.tray_unlocked or save.supply_shock).is_false()
	assert_array(save.stamped).is_empty()
	assert_array(save.tree_bought).is_empty()
	assert_array(save.playtest_log).is_empty()


func test_a_save_from_before_migrations_existed_loads_at_migration_zero_so_every_fix_up_runs() -> void:
	assert_int(SaveGame.new().migration).is_equal(0)
	assert_int(SaveGame.MIGRATION).is_greater(0)


func test_every_saved_field_survives_a_write_and_a_read_back() -> void:
	var save := SaveGame.new()
	var changed := {}
	for property: Dictionary in save.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = _another_value(save, property.name)
		save.set(property.name, value)
		changed[property.name] = value
	assert_dict(changed).is_not_empty()
	assert_int(ResourceSaver.save(save, ROUND_TRIP_PATH)).is_equal(OK)

	var loaded := SafeResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_object(loaded).is_not_null()
	for field: String in changed:
		if changed[field] is float:
			assert_float(loaded.get(field)).override_failure_message(field).is_equal_approx(changed[field], 0.0001)
		else:
			assert_that(loaded.get(field)).override_failure_message(field).is_equal(changed[field])


func test_a_save_from_the_old_squeeze_cycle_still_loads_and_its_squeeze_is_on_for_good() -> void:
	var text := '[gd_resource type="Resource" script_class="SaveGame" format=3]

' 			+ '[ext_resource type="Script" path="res://ressources/save/save_game.gd" id="1"]

' 			+ '[resource]
script = ExtResource("1")
coins = 30
supply_shock = true
squeeze_left = 20.0
' 			+ 'stamped = PackedStringArray("family_farm")
'
	FileAccess.open(ROUND_TRIP_PATH, FileAccess.WRITE).store_string(text)
	var loaded := SafeResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_object(loaded).is_not_null()
	assert_int(loaded.coins).is_equal(30)
	# It was in the old 1 min lull; now there is none.
	assert_float(SupplyConsole.crate_share(loaded.supply_shock, SupplyConsole.squeezing(loaded))).is_equal(SupplyConsole.SQUEEZE_SHARE)


func test_a_log_line_records_what_happened_and_the_state_right_after_it() -> void:
	var save := SaveGame.new()
	save.coins = 42
	save.marketing = 1.23456
	var entry := save.log_entry(95, "card", "price_slate", 12, "coins")
	assert_int(entry.t).is_equal(95)
	assert_str(entry.kind).is_equal("card")
	assert_str(entry.id).is_equal("price_slate")
	assert_int(entry.price).is_equal(12)
	assert_str(entry.currency).is_equal("coins")
	assert_int(entry.coins).is_equal(42)
	assert_float(entry.marketing).is_equal_approx(1.235, 0.00001)


func test_every_log_column_is_in_every_log_entry() -> void:
	var entry := SaveGame.new().log_entry(95, "minute")
	for column: String in SaveGame.LOG_COLUMNS:
		assert_bool(entry.has(column)).override_failure_message(column).is_true()


func test_a_log_entry_snapshots_the_playtest_counters_with_clock_seconds_rounded() -> void:
	var save := SaveGame.new()
	save.hand_sold = 3
	save.tv_seconds = 12.6
	save.coins_earned = 400
	var entry := save.log_entry(95, "minute")
	assert_int(entry.hand_sold).is_equal(3)
	assert_int(entry.tv_seconds).is_equal(13)
	assert_int(entry.coins_earned).is_equal(400)


func test_a_log_line_has_one_cell_per_column_and_blanks_for_what_an_entry_lacks() -> void:
	var save := SaveGame.new()
	save.coins = 42
	assert_str(SaveGame.log_line(save.log_entry(95, "card", "price_slate", 12, "coins"))).starts_with("95,card,price_slate,12,coins,42,")
	assert_str(SaveGame.log_line({t = 100, kind = "session"})).is_equal("100,session" + ",".repeat(SaveGame.LOG_COLUMNS.size() - 2))


func test_the_log_file_is_appended_under_one_header_and_reads_back_as_numbers() -> void:
	var save := SaveGame.new()
	save.coins = 42
	save.marketing = 1.23456
	SaveGame.append_log(LOG_PATH, save.log_entry(95, "card", "price_slate", 12, "coins"))
	SaveGame.append_log(LOG_PATH, save.log_entry(100, "session", "0"))
	var text := FileAccess.get_file_as_string(LOG_PATH)
	assert_int(text.split("
", false).size()).is_equal(3)
	assert_str(text).starts_with(SaveGame.log_header() + "
")
	var entries := SaveGame.parse_log(text)
	assert_int(entries.size()).is_equal(2)
	assert_int(entries[0].t).is_equal(95)
	assert_int(entries[0].coins).is_equal(42)
	assert_float(entries[0].marketing).is_equal_approx(1.235, 0.00001)
	assert_str(entries[0].id).is_equal("price_slate")
	assert_str(entries[1].id).is_equal("0")


func test_a_log_from_a_build_with_other_columns_gets_a_new_header_and_both_parts_read() -> void:
	var old := "t,kind,id,price,currency,coins
95,card,radio,6,coins,30
"
	assert_bool(SaveGame.needs_header(old)).is_true()
	assert_bool(SaveGame.needs_header("")).is_false()
	var both := old + SaveGame.log_header() + "
" + SaveGame.log_line(SaveGame.new().log_entry(120, "minute")) + "
"
	assert_bool(SaveGame.needs_header(both)).is_false()
	var entries := SaveGame.parse_log(both)
	assert_int(entries.size()).is_equal(2)
	assert_int(entries[0].coins).is_equal(30)
	assert_bool(entries[0].has("hand_sold")).is_false()
	assert_str(entries[1].kind).is_equal("minute")


func test_the_save_file_never_holds_the_playtest_log() -> void:
	var save := SaveGame.new()
	for t in 600:
		save.playtest_log.append(save.log_entry(t * 60, "minute"))
	assert_int(ResourceSaver.save(save, ROUND_TRIP_PATH)).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(ROUND_TRIP_PATH)).not_contains("playtest_log")


func _another_value(save: SaveGame, field: String) -> Variant:
	var value: Variant = save.get(field)
	match typeof(value):
		TYPE_BOOL:
			return not value
		TYPE_INT:
			return value + 7
		TYPE_FLOAT:
			return value + 0.5
		TYPE_STRING:
			return "round trip"
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(["price_slate", "radio"])
		TYPE_PACKED_FLOAT32_ARRAY:
			return PackedFloat32Array([1.5, -1.0])
		TYPE_PACKED_INT32_ARRAY:
			return PackedInt32Array([3, 7])
		TYPE_ARRAY:
			var log_lines: Array[Dictionary] = [save.log_entry(95, "card", "price_slate", 12, "coins")]
			return log_lines
	fail("no round-trip value for %s (type %d)" % [field, typeof(value)])
	return value
