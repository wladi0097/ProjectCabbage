extends GdUnitTestSuite

const SaveManagerScript := preload("res://globalScripts/save_manager.gd")

var _player_save: SaveGame


func before_test() -> void:
	_player_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _player_save


func test_a_test_run_never_writes_the_players_save() -> void:
	assert_bool(SaveManagerScript.writes_allowed()).is_false()


func test_saves_live_in_appdata_projectcabbage_not_under_godot() -> void:
	assert_str(OS.get_user_data_dir().replace("\\", "/")) \
			.is_equal(OS.get_data_dir().replace("\\", "/").path_join("ProjectCabbage"))


func test_a_save_from_the_old_godot_folder_is_copied_over_once_and_never_over_a_newer_one() -> void:
	var old := OS.get_user_data_dir().path_join("adopt_test_old")
	var new := OS.get_user_data_dir().path_join("adopt_test_new")
	DirAccess.make_dir_recursive_absolute(old)
	DirAccess.make_dir_recursive_absolute(new)
	FileAccess.open(old.path_join("savegame.tres"), FileAccess.WRITE).store_string("old save")
	FileAccess.open(old.path_join("settings.tres"), FileAccess.WRITE).store_string("old settings")
	FileAccess.open(new.path_join("settings.tres"), FileAccess.WRITE).store_string("new settings")

	SaveManagerScript.adopt_old_files(old, new)

	assert_str(FileAccess.get_file_as_string(new.path_join("savegame.tres"))).is_equal("old save")
	assert_str(FileAccess.get_file_as_string(new.path_join("settings.tres"))).is_equal("new settings")
	for dir in [old, new]:
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)


func test_play_time_counts_whole_seconds_on_top_of_the_saved_time() -> void:
	assert_int(SaveManagerScript.played_seconds(100, 5000, 5000)).is_equal(100)
	assert_int(SaveManagerScript.played_seconds(100, 5000, 7999)).is_equal(102)
	assert_int(SaveManagerScript.played_seconds(100, 5000, 8000)).is_equal(103)


func test_time_away_is_zero_for_a_save_never_played_or_a_clock_set_back() -> void:
	assert_int(SaveManagerScript.away_seconds(0, 1_700_000_000)).is_equal(0)
	assert_int(SaveManagerScript.away_seconds(1_700_000_100, 1_700_000_000)).is_equal(0)
	assert_int(SaveManagerScript.away_seconds(1_700_000_000, 1_700_003_600)).is_equal(3600)


func test_the_master_bus_mutes_when_muted_or_unfocused_with_mute_on_focus_exit() -> void:
	assert_bool(SaveManagerScript.master_bus_muted(true, false, false)).is_false()
	assert_bool(SaveManagerScript.master_bus_muted(true, true, false)).is_false()
	assert_bool(SaveManagerScript.master_bus_muted(false, false, false)).is_false()
	assert_bool(SaveManagerScript.master_bus_muted(false, true, false)).is_true()
	assert_bool(SaveManagerScript.master_bus_muted(true, false, true)).is_true()


func test_a_new_save_carries_this_builds_version_and_needs_no_migration() -> void:
	var fresh: SaveGame = SaveManager._new_save()
	var now := int(Time.get_unix_time_from_system())
	assert_str(fresh.version).is_equal(str(ProjectSettings.get_setting("application/config/version")))
	assert_int(fresh.migration).is_equal(SaveGame.MIGRATION)
	assert_int(fresh.created).is_between(now - 5, now)


func test_a_logged_purchase_lands_in_the_save_at_the_current_play_time() -> void:
	SaveManager.save.play_seconds = 500
	SaveManager.save.coins = 30
	SaveManager.log_event("card", "radio", 6, "coins")
	var entry: Dictionary = SaveManager.save.playtest_log.back()
	assert_int(SaveManager.save.playtest_log.size()).is_equal(1)
	assert_str(entry.kind).is_equal("card")
	assert_str(entry.id).is_equal("radio")
	assert_int(entry.coins).is_equal(30)
	assert_int(entry.t).is_greater_equal(500)


const TEMP_DIR := "user://save_manager_test"


func _temp(file: String) -> String:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	return TEMP_DIR.path_join(file)


func _clear_temp() -> void:
	for file in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(file))
	DirAccess.remove_absolute(TEMP_DIR)


func test_every_full_minute_of_play_logs_one_minute_row() -> void:
	SaveManager._minute_timer = 0.0
	for k in 5:
		SaveManager._process(25.0)
	var minutes := SaveManager.save.playtest_log.filter(func(e: Dictionary) -> bool: return e.kind == "minute")
	assert_int(minutes.size()).is_equal(2)


## A save from before the log moved out, as that build wrote it: the log inside the save.
func _old_save_text() -> String:
	return '[gd_resource type="Resource" script_class="SaveGame" format=3]\n\n' \
			+ '[ext_resource type="Script" path="res://ressources/save/save_game.gd" id="1"]\n\n' \
			+ '[resource]\nscript = ExtResource("1")\ncoins = 30\nstamped = PackedStringArray("acceptance_meter")\n' \
			+ 'playtest_log = Array[Dictionary]([{"t": 10, "kind": "session", "id": "0", "coins": 0, "marketing": 1.0}, ' \
			+ '{"t": 20, "kind": "card", "id": "acceptance_meter", "price": 40, "currency": "coins", "coins": 5, "marketing": 1.2}])\n'


func test_an_old_saves_in_save_log_moves_to_the_log_file_once_and_the_ledger_still_reads_it() -> void:
	var save_path := _temp("old_save.tres")
	var log_path := _temp("log.csv")
	FileAccess.open(save_path, FileAccess.WRITE).store_string(_old_save_text())
	var old := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_int(old.playtest_log.size()).is_equal(2)

	assert_bool(SaveManagerScript.adopt_log(old, log_path, true)).is_true()
	# Still in memory for this session: the migration and the ledger read it.
	assert_bool(UpgradeDesk.meter_logged(old.playtest_log)).is_true()
	assert_int(SaveGame.parse_log(FileAccess.get_file_as_string(log_path)).size()).is_equal(2)

	ResourceSaver.save(old, save_path)
	var again := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_bool(SaveManagerScript.adopt_log(again, log_path, true)).is_false()
	assert_int(again.playtest_log.size()).is_equal(2)
	# That build logged no coins_earned: the income chart has no line to draw (insufficient data).
	assert_array(Array(Ledger.rate_points(again.playtest_log, ["coins_earned"], 30, again.coins_earned, 60))).is_empty()
	assert_int(Ledger.requisitions(again).size()).is_equal(1)
	_clear_temp()


func test_writing_the_save_leaves_the_log_file_as_it_was() -> void:
	var log_path := _temp("log.csv")
	var save := SaveGame.new()
	SaveGame.append_log(log_path, save.log_entry(5, "session", "0"))
	var written := FileAccess.get_file_as_string(log_path)
	save.playtest_log.append(save.log_entry(6, "minute"))
	ResourceSaver.save(save, _temp("save.tres"))
	assert_str(FileAccess.get_file_as_string(log_path)).is_equal(written)
	_clear_temp()


func test_a_new_game_moves_the_log_to_prev_and_the_next_entry_starts_a_fresh_one() -> void:
	var log_path := _temp("log.csv")
	var prev := _temp("log_prev.csv")
	var save := SaveGame.new()
	SaveGame.append_log(log_path, save.log_entry(5, "session", "0"))
	FileAccess.open(prev, FileAccess.WRITE).store_string("older\n")
	SaveManagerScript.rotate_log(log_path, prev)
	assert_bool(FileAccess.file_exists(log_path)).is_false()
	assert_int(SaveGame.parse_log(FileAccess.get_file_as_string(prev)).size()).is_equal(1)
	SaveGame.append_log(log_path, save.log_entry(1, "minute"))
	assert_int(SaveGame.parse_log(FileAccess.get_file_as_string(log_path)).size()).is_equal(1)
	_clear_temp()


func test_a_playtest_report_zips_the_save_the_logs_and_an_info_sheet() -> void:
	for file: String in SaveManagerScript.REPORT_FILES:
		FileAccess.open(_temp(file), FileAccess.WRITE).store_string("contents of " + file)
	var zip_path := _temp("report.zip")
	assert_int(SaveManagerScript.pack_report(zip_path, TEMP_DIR, SaveManagerScript.REPORT_FILES, "build: full\n")).is_equal(OK)

	var zip := ZIPReader.new()
	assert_int(zip.open(zip_path)).is_equal(OK)
	assert_array(Array(zip.get_files())).contains_exactly_in_any_order(
			["savegame.tres", "playtest_log.csv", "playtest_log_prev.csv", "info.txt"])
	assert_str(zip.read_file("playtest_log.csv").get_string_from_utf8()).is_equal("contents of playtest_log.csv")
	assert_str(zip.read_file("info.txt").get_string_from_utf8()).is_equal("build: full\n")
	zip.close()
	_clear_temp()


func test_a_playtest_report_skips_a_log_that_isnt_there() -> void:
	FileAccess.open(_temp("savegame.tres"), FileAccess.WRITE).store_string("save")
	var zip_path := _temp("report.zip")
	SaveManagerScript.pack_report(zip_path, TEMP_DIR, SaveManagerScript.REPORT_FILES, "")
	var zip := ZIPReader.new()
	zip.open(zip_path)
	assert_array(Array(zip.get_files())).contains_exactly_in_any_order(["savegame.tres", "info.txt"])
	zip.close()
	_clear_temp()
