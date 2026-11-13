extends GdUnitTestSuite

const SettingsUi := preload("res://ui/sub/settings_ui.gd")
const MapSettings := preload("res://worlds/components/map_specific_settings.gd")
const SCENE := preload("res://ui/sub/settings_ui.tscn")


func items_of(option_name: String) -> PackedStringArray:
	var menu: Node = auto_free(SCENE.instantiate())
	var option := menu.find_child(option_name, true, false) as OptionButton
	var items := PackedStringArray()
	for i in option.item_count:
		items.append(option.get_item_text(i))
	return items


func test_a_saved_language_selects_its_entry_and_an_unknown_one_falls_back_to_english() -> void:
	assert_int(SettingsUi.language_index("en")).is_equal(0)
	assert_int(SettingsUi.language_index("xx")).is_equal(0)
	assert_str(SettingsUi.LANGUAGES.keys()[SettingsUi.language_index("de")]).is_equal("de")


func test_a_saved_choice_missing_from_a_dropdown_selects_its_first_entry() -> void:
	assert_int(SettingsUi.item_index(["30", "60"], "60")).is_equal(1)
	assert_int(SettingsUi.item_index(["30", "60"], "75")).is_equal(0)


func test_the_default_resolution_and_frame_cap_are_entries_in_their_dropdowns() -> void:
	var defaults := SettingsResource.new()
	assert_array(items_of("Resolution")).contains([defaults.display_size])
	assert_array(items_of("MaxFps")).contains([defaults.max_fps])


func test_every_resolution_entry_reads_as_width_x_height() -> void:
	for text in items_of("Resolution"):
		var sides := text.split(" x ")
		assert_bool(sides.size() == 2 and sides[0].is_valid_int() and sides[1].is_valid_int()) \
				.override_failure_message(text).is_true()


func test_every_frame_cap_entry_is_a_number_or_unlimited() -> void:
	for text in items_of("MaxFps"):
		assert_bool(text == "∞" or text.to_int() > 0).override_failure_message(text).is_true()


func test_every_scaling_quality_entry_has_a_render_scale() -> void:
	assert_int(items_of("ScalingQuality").size()).is_equal(MapSettings.RENDER_SCALES.size())


func test_the_shadow_dropdown_lists_low_medium_high_in_setting_order() -> void:
	var items := items_of("ShadowQuality")
	assert_int(items.size()).is_equal(SettingsResource.ShadowQuality.size())
	assert_str(items[SettingsResource.ShadowQuality.LOW]).is_equal("settings.shadows.low")
	assert_str(items[SettingsResource.ShadowQuality.MEDIUM]).is_equal("settings.shadows.medium")
	assert_str(items[SettingsResource.ShadowQuality.HIGH]).is_equal("settings.shadows.high")


func test_the_screen_mode_dropdown_lists_the_modes_in_setting_order() -> void:
	var items := items_of("ScreenMode")
	assert_int(items.size()).is_equal(SettingsResource.ScreenMode.size())
	assert_str(items[SettingsResource.ScreenMode.EXCLUSIVE_FULLSCREEN]).is_equal("settings.screenMode.fullscreen")
	assert_str(items[SettingsResource.ScreenMode.WINDOWED]).is_equal("settings.screenMode.window")
	assert_str(items[SettingsResource.ScreenMode.BORDERLESS]).is_equal("settings.screenMode.borderless")


func test_the_lowest_scaling_preset_is_called_cabbage_not_potato_in_english_and_german() -> void:
	var key: String = items_of("ScalingQuality")[-1]
	assert_str(key).is_equal("settings.fidelityFX.potato")  # Saved by index: the key stays.
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var en := TranslationServer.translate(key)
	TranslationServer.set_locale("de")
	var de := TranslationServer.translate(key)
	TranslationServer.set_locale(locale)
	assert_str(en).is_equal("Cabbage")
	assert_str(de).is_equal("Kohlkopf")
