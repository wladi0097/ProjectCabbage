extends GdUnitTestSuite

const MapSettings := preload("res://worlds/components/map_specific_settings.gd")


func test_scaling_quality_off_renders_at_full_resolution_and_each_step_renders_smaller() -> void:
	assert_float(MapSettings.render_scale(0)).is_equal(1.0)
	for quality in range(1, MapSettings.RENDER_SCALES.size()):
		assert_float(MapSettings.render_scale(quality)).is_less(MapSettings.render_scale(quality - 1))


func test_an_out_of_range_scaling_quality_falls_back_to_the_nearest_step() -> void:
	assert_float(MapSettings.render_scale(-3)).is_equal(1.0)
	assert_float(MapSettings.render_scale(99)).is_equal(MapSettings.RENDER_SCALES[-1])


func test_fsr_only_upscales_when_it_is_on_and_the_render_is_scaled_down() -> void:
	assert_int(MapSettings.scaling_mode(true, 2)).is_equal(Viewport.SCALING_3D_MODE_FSR2)
	assert_int(MapSettings.scaling_mode(true, 0)).is_equal(Viewport.SCALING_3D_MODE_BILINEAR)
	assert_int(MapSettings.scaling_mode(false, 2)).is_equal(Viewport.SCALING_3D_MODE_BILINEAR)


func test_higher_shadow_quality_never_lowers_filter_atlas_or_softness() -> void:
	for quality in range(SettingsResource.ShadowQuality.LOW, SettingsResource.ShadowQuality.HIGH):
		assert_int(MapSettings.shadow_filter(quality + 1)).is_greater(MapSettings.shadow_filter(quality))
		assert_int(MapSettings.shadow_atlas_size(quality + 1)).is_greater_equal(MapSettings.shadow_atlas_size(quality))
		assert_float(MapSettings.sun_angular_distance(quality + 1)) \
				.is_greater_equal(MapSettings.sun_angular_distance(quality))


func test_an_out_of_range_shadow_quality_is_clamped_to_low_or_high() -> void:
	assert_int(MapSettings.shadow_level(-1)).is_equal(SettingsResource.ShadowQuality.LOW)
	assert_int(MapSettings.shadow_level(7)).is_equal(SettingsResource.ShadowQuality.HIGH)


func test_high_shadows_split_the_sun_four_ways_and_lower_ones_keep_the_authored_mode() -> void:
	var authored := DirectionalLight3D.SHADOW_ORTHOGONAL
	assert_int(MapSettings.directional_shadow_mode(SettingsResource.ShadowQuality.HIGH, authored)) \
			.is_equal(DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	assert_int(MapSettings.directional_shadow_mode(SettingsResource.ShadowQuality.MEDIUM, authored)).is_equal(authored)
	assert_int(MapSettings.directional_shadow_mode(SettingsResource.ShadowQuality.LOW, authored)).is_equal(authored)


func test_the_brightness_setting_scales_the_maps_own_grade() -> void:
	var environment := Environment.new()
	MapSettings.brighten(environment, 1.2, 0.9)
	assert_bool(environment.adjustment_enabled).is_true()
	assert_float(environment.adjustment_brightness).is_equal_approx(1.08, 0.0001)
