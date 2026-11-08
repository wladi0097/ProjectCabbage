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
