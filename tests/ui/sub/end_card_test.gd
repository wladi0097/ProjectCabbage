extends GdUnitTestSuite

const SCENE := "res://ui/sub/end_card.tscn"


func after_test() -> void:
	Engine.time_scale = 1.0


func test_the_end_card_lets_the_logo_sink_in_for_seconds_before_the_credits_roll_slowly() -> void:
	var at := EndCard.timeline()
	assert_float(at.scroll - at.logo_full).is_between(7.0, 8.0)
	assert_float(EndCard.SPEED).is_between(25.0, 40.0)
	assert_float(at.thud).is_less(at.logo_in)
	assert_float(at.thud).is_greater(0.0)


func test_the_end_card_rolls_the_same_credits_as_the_credits_menu() -> void:
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	var lines := card.get_node("Roll/Credits").get_children().filter(func(n: Node) -> bool: return n is Label).map(func(l: Label) -> String: return l.text)
	assert_array(lines).contains(["MADE BY", "No more Sleep"])
	assert_str(lines[-1]).is_equal("THANK YOU FOR YOUR COOPERATION.")


func test_the_end_card_says_finished_once_the_credits_are_through() -> void:
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	Engine.time_scale = 100.0
	card.play()
	await await_signal_on(card, "finished", [], 5000)
	Engine.time_scale = 1.0
	assert_float(card.get_node("Roll/Logo").modulate.a).is_equal_approx(1.0, 0.01)


func test_the_credits_stop_with_the_closing_line_in_the_middle_of_the_screen() -> void:
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	Engine.time_scale = 100.0
	card.play()
	await await_signal_on(card, "finished", [], 5000)
	var closing: Label = card.get_node("Roll/Credits/Closing")
	var middle := closing.get_global_rect().get_center().y
	assert_float(middle).is_equal_approx(card.get_viewport().get_visible_rect().size.y * 0.5, 1.0)


func test_holding_a_key_rolls_the_credits_eight_times_as_fast_but_not_the_logo() -> void:
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	Input.parse_input_event(_space(true))
	Input.flush_buffered_events()
	assert_float(card.speed()).is_equal(0.0)  # The logo's hold: nothing rolls.
	card.scrolling = true
	assert_float(card.speed()).is_equal(EndCard.SPEED * 8.0)
	Input.parse_input_event(_space(false))
	Input.flush_buffered_events()
	assert_float(card.speed()).is_equal(EndCard.SPEED)
	card.scrolling = false


static func _space(down: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = down
	return key


func test_holding_a_mouse_button_rolls_the_credits_eight_times_as_fast_too() -> void:
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	card.scrolling = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	assert_float(card.speed()).is_equal(EndCard.SPEED * 8.0)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	assert_float(card.speed()).is_equal(EndCard.SPEED)
	card.scrolling = false


func test_the_audio_speeds_up_with_the_fast_credits_eased_and_comes_back_down() -> void:
	var rate := EndCard.rate_toward(1.0, true, EndCard.RATE_EASE / 2.0)
	assert_float(rate).is_greater(1.0)
	assert_float(rate).is_less(EndCard.FAST)  # Eased, no jump.
	rate = EndCard.rate_toward(rate, true, EndCard.RATE_EASE)
	assert_float(rate).is_equal(EndCard.FAST)
	rate = EndCard.rate_toward(rate, false, EndCard.RATE_EASE)
	assert_float(rate).is_equal(1.0)


func test_a_song_from_the_radio_plays_under_the_credits_and_the_logo_comes_with_a_sound() -> void:
	var list := EndCard.songs()
	assert_array(list).is_not_empty()
	assert_str(EndCard.pick_song(list, 0.0)).is_equal(list[0])
	assert_str(EndCard.pick_song(list, 0.9999)).is_equal(list[-1])
	assert_str(EndCard.pick_song(PackedStringArray(), 0.5)).is_empty()
	var card: EndCard = auto_free(load(SCENE).instantiate())
	assert_str(str((card.get_node("Song") as AudioStreamPlayer).bus)).is_equal("Music")
	assert_object((card.get_node("LogoSwell") as AudioStreamPlayer).stream).is_not_null()


func test_a_handed_in_player_follows_the_credits_speed() -> void:
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	var hum: AudioStreamPlayer = auto_free(AudioStreamPlayer.new())
	hum.pitch_scale = 1.15
	card.pitched = [hum]
	card.rate = EndCard.FAST
	card.scrolling = false
	card._process(0.0)
	assert_float(hum.pitch_scale).is_equal_approx(1.15 * EndCard.FAST, 0.001)
	card._process(1.0)  # Not rolling: back down.
	assert_float(hum.pitch_scale).is_equal_approx(1.15, 0.001)


func test_qa_names_and_music_titles_lie_in_rows_of_three_and_the_rest_one_per_line() -> void:
	assert_bool(EndCard.in_columns("QA", "Michael L.")).is_true()
	assert_bool(EndCard.in_columns("Music", "\"Jazz Brunch\"")).is_true()
	assert_bool(EndCard.in_columns("Music", "Kevin MacLeod (incompetech.com)")).is_false()
	assert_bool(EndCard.in_columns("Music", "Licensed under Creative Commons: By Attribution 4.0 License")).is_false()
	assert_bool(EndCard.in_columns("Fonts", "Oswald by Vernon Adams, Kalapi Gajjar, Cyreal")).is_false()
	var card: EndCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	var grids := card.find_children("*", "GridContainer", true, false)
	assert_int(grids.size()).is_equal(2)  # QA's, the music's.
	for grid: GridContainer in grids:
		assert_int(grid.columns).is_equal(3)

