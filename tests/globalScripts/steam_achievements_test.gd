extends GdUnitTestSuite

const Achievements := preload("res://globalScripts/steam_achievements.gd")
const Memo := preload("res://entities/milestone/milestone_memo.gd")


func test_a_memos_steam_api_name_is_its_id_upper_cased() -> void:
	assert_str(Achievements.api_name("units_25")).is_equal("UNITS_25")


func test_every_memo_has_its_own_valid_steam_api_name() -> void:
	var valid := RegEx.create_from_string("^[A-Z0-9_]+$")
	var names := {}
	for memo: Dictionary in Memo.MEMOS:
		var api := Achievements.api_name(memo.id)
		assert_object(valid.search(api)).override_failure_message(api).is_not_null()
		assert_bool(names.has(api)).override_failure_message(api).is_false()
		names[api] = true


## Stands in for GodotSteam's singleton: records what reached it.
class FakeSteam:
	extends RefCounted
	var achieved: Array[String] = []
	var stores := 0

	func setAchievement(achievement_name: String) -> bool:
		achieved.append(achievement_name)
		return true

	func storeStats() -> bool:
		stores += 1
		return true


func after_test() -> void:
	Profile.clear()


func test_the_full_game_starts_steam_as_its_own_app_and_the_demo_leaves_it_to_steam() -> void:
	assert_int(Achievements.app_id(false)).is_equal(5613070)
	assert_int(Achievements.app_id(true)).is_equal(0)


func test_the_game_runs_without_steam() -> void:
	# Tests run headless, so the autoload never starts Steam, whether or not the extension is loaded.
	assert_object(SteamAchievements.steam).is_null()
	SteamAchievements.unlock("units_25")
	SteamAchievements.sync(PackedStringArray(["units_25", "units_100"]))
	var fresh: Node = auto_free(Achievements.new())
	fresh.unlock("units_25")
	assert_object(fresh.steam).is_null()


func test_filed_memos_sync_to_steam_on_startup() -> void:
	Profile.clear()
	Profile.file(PackedStringArray(["units_25", "units_100"]))
	var achievements: Node = auto_free(Achievements.new())
	var fake := FakeSteam.new()
	achievements.start(fake)
	assert_array(fake.achieved).is_equal(["UNITS_25", "UNITS_100"])
	assert_int(fake.stores).is_equal(1)


func test_an_unlock_stores_the_stats() -> void:
	Profile.clear()
	var achievements: Node = auto_free(Achievements.new())
	var fake := FakeSteam.new()
	achievements.start(fake)
	achievements.unlock("units_25")
	assert_array(fake.achieved).is_equal(["UNITS_25"])
	assert_int(fake.stores).is_equal(1)
