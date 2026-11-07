extends GdUnitTestSuite

const Demo := preload("res://globalScripts/demo.gd")
const Events := preload("res://globalScripts/game_events.gd")

var _demo_was: bool


func before_test() -> void:
	_demo_was = ProjectSettings.get_setting("game/demo", false)


func after_test() -> void:
	ProjectSettings.set_setting("game/demo", _demo_was)


func test_the_game_demo_setting_turns_the_demo_on_in_the_editor() -> void:
	ProjectSettings.set_setting("game/demo", true)
	assert_bool(Demo.active()).is_true()
	ProjectSettings.set_setting("game/demo", false)
	assert_bool(Demo.active()).is_false()


func test_the_demo_is_shorter_and_cheaper_than_the_full_game() -> void:
	assert_int(Demo.SHOCK_AFTER).is_less(Events.SHOCK_AFTER)
	for id: String in Demo.CARD_PRICES:
		assert_int(Demo.CARD_PRICES[id]).override_failure_message(id).is_less(UpgradeDesk.CARDS.filter(
				func(card: Dictionary) -> bool: return card.id == id)[0].price)


func test_the_demo_export_leaves_out_every_full_game_folder_and_the_full_export_keeps_them() -> void:
	var presets := ConfigFile.new()
	assert_int(presets.load("res://export_presets.cfg")).is_equal(OK)
	var demos := 0
	for section: String in presets.get_sections():
		if not presets.has_section_key(section, "exclude_filter"):
			continue
		var excluded := (presets.get_value(section, "exclude_filter") as String).split(",")
		for i in excluded.size():
			excluded[i] = excluded[i].strip_edges()
		var is_demo := (presets.get_value(section, "custom_features", "") as String).split(",").has("demo")
		demos += 1 if is_demo else 0
		for dir: String in Demo.FULL_ONLY_DIRS:
			var pattern := dir.trim_prefix("res://") + "*"
			assert_bool(excluded.has(pattern)).override_failure_message(section + " " + pattern).is_equal(is_demo)
	assert_int(demos).is_greater(0)
