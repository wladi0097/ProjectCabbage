extends GdUnitTestSuite

const ROUND_TRIP_PATH := "user://save_game_test_round_trip.tres"


func after_test() -> void:
	if FileAccess.file_exists(ROUND_TRIP_PATH):
		DirAccess.remove_absolute(ROUND_TRIP_PATH)


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


func test_the_playtest_csv_has_a_header_and_one_row_per_log_line() -> void:
	var save := SaveGame.new()
	save.coins = 42
	save.playtest_log.append(save.log_entry(95, "card", "price_slate", 12, "coins"))
	save.playtest_log.append({t = 100, kind = "session"})
	var csv := save.playtest_csv()
	var lines := csv.split("\n")

	assert_str(lines[0]).is_equal(",".join(SaveGame.LOG_COLUMNS))
	assert_str(lines[1]).starts_with("95,card,price_slate,12,coins,42,")
	assert_str(lines[2]).is_equal("100,session" + ",".repeat(SaveGame.LOG_COLUMNS.size() - 2))
	assert_str(csv).ends_with("\n")


func test_snapshots_older_than_an_hour_thin_to_one_per_five_minutes_and_every_purchase_stays() -> void:
	var save := SaveGame.new()
	var entries: Array[Dictionary] = []
	for t in range(0, 7200, 30):
		entries.append(save.log_entry(t, "snapshot"))
		if t % 60 == 0:
			entries.append(save.log_entry(t, "node", "pack_1"))
	var thin := SaveGame.thin_log(entries, 7200)
	var snapshots := thin.filter(func(e: Dictionary) -> bool: return e.kind == "snapshot").size()

	# 12 five-minute snapshots from the first hour, all 120 of the last hour, all 120 purchases.
	assert_int(snapshots).is_equal(12 + 120)
	assert_int(thin.size() - snapshots).is_equal(120)


func test_thinning_keeps_the_first_snapshot_of_each_five_minutes() -> void:
	var save := SaveGame.new()
	var entries: Array[Dictionary] = [save.log_entry(0, "snapshot"), save.log_entry(30, "snapshot"),
			save.log_entry(300, "snapshot"), save.log_entry(330, "snapshot")]
	var kept := SaveGame.thin_log(entries, 10000).map(func(e: Dictionary) -> int: return e.t)
	assert_array(kept).is_equal([0, 300])


func test_thinning_again_at_the_next_autosave_drops_nothing_more() -> void:
	var save := SaveGame.new()
	var entries: Array[Dictionary] = []
	for t in range(0, 7200, 30):
		entries.append(save.log_entry(t, "snapshot"))
	var once := SaveGame.thin_log(entries, 7200)
	assert_int(SaveGame.thin_log(once, 7200).size()).is_equal(once.size())


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
