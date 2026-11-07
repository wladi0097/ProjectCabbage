extends GdUnitTestSuite


func test_a_hit_at_or_below_the_silent_strength_makes_no_sound() -> void:
	assert_float(SoundCue.level_for(0.2, 0.2, 1.0)).is_equal(0.0)
	assert_float(SoundCue.level_for(0.1, 0.2, 1.0)).is_equal(0.0)


func test_a_hit_at_or_above_full_strength_plays_at_full_volume() -> void:
	assert_float(SoundCue.level_for(1.0, 0.2, 1.0)).is_equal(1.0)
	assert_float(SoundCue.level_for(5.0, 0.2, 1.0)).is_equal(1.0)


func test_volume_rises_evenly_between_silent_and_full_strength() -> void:
	assert_float(SoundCue.level_for(0.6, 0.2, 1.0)).is_equal_approx(0.5, 0.0001)


func test_a_sound_already_playing_at_its_game_wide_cap_drops_the_next_cue() -> void:
	assert_bool(SoundCue.has_room(3, 4)).is_true()
	assert_bool(SoundCue.has_room(4, 4)).is_false()
