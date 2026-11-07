extends GdUnitTestSuite


func test_fresh_settings_play_everything_at_full_volume_capped_at_60_fps_with_vsync() -> void:
	var settings := SettingsResource.new()
	assert_float(settings.master_volume).is_equal(1.0)
	assert_float(settings.music_volume).is_equal(1.0)
	assert_float(settings.sfx_volume).is_equal(1.0)
	assert_bool(settings.master_muted or settings.music_muted or settings.sfx_muted).is_false()
	assert_bool(settings.vsync).is_true()
	assert_str(settings.max_fps).is_equal("60")
	assert_bool(settings.radio_filter).is_true()
	assert_int(settings.shadow_quality).is_equal(SettingsResource.ShadowQuality.HIGH)


func test_with_no_language_chosen_the_game_follows_the_system_language() -> void:
	assert_str(SettingsResource.new().language).is_equal(OS.get_locale_language())


func test_the_screen_mode_toggle_goes_windowed_from_any_fullscreen_and_fullscreen_from_windowed() -> void:
	assert_int(SettingsResource.toggled_screen_mode(SettingsResource.ScreenMode.WINDOWED)).is_equal(SettingsResource.ScreenMode.EXCLUSIVE_FULLSCREEN)
	assert_int(SettingsResource.toggled_screen_mode(SettingsResource.ScreenMode.EXCLUSIVE_FULLSCREEN)).is_equal(SettingsResource.ScreenMode.WINDOWED)
	assert_int(SettingsResource.toggled_screen_mode(SettingsResource.ScreenMode.BORDERLESS)).is_equal(SettingsResource.ScreenMode.WINDOWED)


func test_an_fps_cap_leaves_two_frames_of_headroom_and_infinity_uncaps() -> void:
	assert_int(SettingsResource.engine_max_fps("60")).is_equal(62)
	assert_int(SettingsResource.engine_max_fps("144")).is_equal(146)
	assert_int(SettingsResource.engine_max_fps("∞")).is_equal(0)
