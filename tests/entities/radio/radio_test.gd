extends GdUnitTestSuite


func test_the_radio_only_arrives_once_its_card_is_stamped() -> void:
	var save := SaveGame.new()
	assert_bool(Radio.bought(save)).is_false()
	save.stamped.append("radio")
	assert_bool(Radio.bought(save)).is_true()


func test_the_playlist_is_every_audio_file_in_name_order() -> void:
	var files: PackedStringArray = ["b.ogg", "a.OGG", "notes.txt", "c.mp3", "d.wav", "e.ogg.import"]
	assert_array(Radio.track_paths(files)).is_equal(PackedStringArray(["a.OGG", "b.ogg", "c.mp3", "d.wav"]))


func test_after_the_last_song_the_radio_starts_over() -> void:
	assert_int(Radio.next_track(0, 3)).is_equal(1)
	assert_int(Radio.next_track(2, 3)).is_equal(0)


func test_with_no_songs_the_track_stays_at_the_first() -> void:
	assert_int(Radio.next_track(4, 0)).is_equal(0)


func test_a_crossfade_takes_the_new_song_from_silent_to_full() -> void:
	assert_float(Radio.fade_gain(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(Radio.fade_gain(1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(Radio.fade_gain(2.0)).is_equal_approx(1.0, 0.0001)
	assert_float(Radio.fade_gain(-1.0)).is_equal_approx(0.0, 0.0001)


func test_a_crossfade_keeps_the_loudness_without_a_dip_in_the_middle() -> void:
	for t: float in [0.1, 0.5, 0.8]:
		var power := pow(Radio.fade_gain(t), 2) + pow(Radio.fade_gain(1.0 - t), 2)
		assert_float(power).is_equal_approx(1.0, 0.0001)


func test_silence_is_only_counted_while_the_radio_is_bought_and_stopped() -> void:
	assert_float(Radio.silent_after(1.0, 0.5, true, false)).is_equal_approx(1.5, 0.0001)
	assert_float(Radio.silent_after(1.0, 0.5, true, true)).is_equal(1.0)
	assert_float(Radio.silent_after(1.0, 0.5, false, false)).is_equal(1.0)


func test_a_war_pauses_the_radio_and_only_a_radio_left_on_plays_again_after_it() -> void:
	assert_bool(Radio.playing(true, true)).is_false()  # Paused while the war is on.
	assert_bool(Radio.playing(true, false)).is_true()  # On before: back after.
	assert_bool(Radio.playing(false, false)).is_false()  # Off before: stays off.
	assert_bool(Radio.playing(false, true)).is_false()
