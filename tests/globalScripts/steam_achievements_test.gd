extends GdUnitTestSuite

const Steam := preload("res://globalScripts/steam_achievements.gd")
const Memo := preload("res://entities/milestone/milestone_memo.gd")


func test_a_memos_steam_api_name_is_its_id_upper_cased() -> void:
	assert_str(Steam.api_name("units_25")).is_equal("UNITS_25")


func test_every_memo_has_its_own_valid_steam_api_name() -> void:
	var valid := RegEx.create_from_string("^[A-Z0-9_]+$")
	var names := {}
	for memo: Dictionary in Memo.MEMOS:
		var api := Steam.api_name(memo.id)
		assert_object(valid.search(api)).override_failure_message(api).is_not_null()
		assert_bool(names.has(api)).override_failure_message(api).is_false()
		names[api] = true
