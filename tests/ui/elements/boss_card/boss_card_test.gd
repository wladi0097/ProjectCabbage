extends GdUnitTestSuite

const SCENE := "res://ui/elements/boss_card/boss_card.tscn"


static func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i in points.size():
		sum += points[i].cross(points[(i + 1) % points.size()])
	return absf(sum) * 0.5


func _card() -> BossCard:
	var card: BossCard = auto_free(load(SCENE).instantiate())
	add_child(card)
	return card


func test_a_higher_level_card_shakes_harder() -> void:
	for level in range(1, 5):
		assert_float(BossCard.style(level).shake).is_greater(BossCard.style(level - 1).shake)
		assert_float(BossCard.style(level).wiggle).is_greater(BossCard.style(level - 1).wiggle)


func test_the_type_grows_on_every_card() -> void:
	for level in range(1, 5):
		assert_int(BossCard.style(level).font_size).is_greater(BossCard.style(level - 1).font_size)


func test_the_paper_tears_from_the_third_card_on_and_worse_each_time() -> void:
	var whole := BossCard.SIZE.x * BossCard.SIZE.y
	assert_float(_area(BossCard.outline(BossCard.style(0).tear))).is_equal_approx(whole, 0.1)
	assert_float(_area(BossCard.outline(BossCard.style(1).tear))).is_equal_approx(whole, 0.1)
	var last := whole
	for level in range(2, 5):
		var area := _area(BossCard.outline(BossCard.style(level).tear))
		assert_float(area).is_less(last)
		last = area


func test_only_the_last_card_is_handwritten() -> void:
	for level in 4:
		assert_bool(BossCard.style(level).hand).is_false()
	assert_bool(BossCard.style(4).hand).is_true()
	assert_str(BossCard.bbcode("MORE.", 4)).contains("hand=1")


func test_the_directors_text_cannot_break_the_wiggle() -> void:
	assert_str(BossCard.bbcode("[b]MORE[/b]", 0)).is_equal("[tremor amp=0.6 freq=3.0 hand=0][lb]b]MORE[lb]/b][/tremor]")


func test_a_card_plays_its_voice_line_and_returns_once_clicked_away() -> void:
	var card := _card()
	var state := {done = false}
	(func() -> void:
		await card.show_card("MORE.", 2, 3)
		state.done = true).call()
	await await_millis(100)
	assert_bool(card.up).is_true()
	assert_object(card.get_node("Voice").stream).is_same(card.voices[2])
	card.dismiss()
	await await_millis(int(BossCard.OUT_TIME * 1000) + 300)
	assert_bool(state.done).is_true()
	assert_bool(card.up).is_false()


func test_a_card_goes_by_itself_once_its_time_is_up() -> void:
	var card := _card()
	var state := {done = false}
	(func() -> void:
		await card.show_card("MORE CABBAGES.", 1, 0)
		state.done = true).call()
	await await_millis(int((BossCard.MIN_HOLD + BossCard.OUT_TIME) * 1000) + 400)
	assert_bool(state.done).is_true()


func test_the_remaining_counter_hides_at_minus_one() -> void:
	var card := _card()
	var label: Label = card.get_node("Remaining")
	card.set_remaining(12)
	assert_bool(label.visible).is_true()
	assert_str(label.text).ends_with(": 12")
	card.set_remaining(-1)
	assert_bool(label.visible).is_false()


func test_the_ticker_and_the_prompt_show_what_they_are_told() -> void:
	var card := _card()
	card.set_ticker("99.999999%*")
	assert_str((card.get_node("Ticker/Box/Value") as Label).text).is_equal("99.999999%*")
	assert_bool(card.get_node("Ticker").visible).is_true()
	card.set_ticker("")
	assert_bool(card.get_node("Ticker").visible).is_false()
	card.show_prompt(true)
	assert_bool(card.get_node("Prompt").visible).is_true()
	card.show_prompt(false)
	assert_bool(card.get_node("Prompt").visible).is_false()


func test_the_hum_rises_with_its_level_and_zero_is_silence() -> void:
	var card := _card()
	var hum: AudioStreamPlayer = card.get_node("Hum")
	card.set_hum(0.2)
	var quiet := hum.volume_db
	card.set_hum(0.9)
	assert_float(hum.volume_db).is_greater(quiet)
	assert_bool(hum.playing).is_true()
	card.set_hum(0.0)
	assert_bool(hum.playing).is_false()


func test_the_hum_and_the_heartbeat_loop() -> void:
	var card := _card()
	assert_int((card.get_node("Hum").stream as AudioStreamWAV).loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int((card.get_node("Heartbeat").stream as AudioStreamWAV).loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	card.heartbeat(true)
	assert_bool(card.get_node("Heartbeat").playing).is_true()
	card.heartbeat(false)
	assert_bool(card.get_node("Heartbeat").playing).is_false()


func test_every_voice_slot_holds_a_line() -> void:
	var card := _card()
	assert_int(card.voices.size()).is_equal(5)
	for v in card.voices:
		assert_object(v).is_not_null()


func test_no_text_on_the_paper_is_red() -> void:
	var card := _card()
	for label: Label in [card.get_node("Paper/Letterhead"), card.get_node("Paper/Signatory")]:
		var ink := label.get_theme_color("font_color")
		assert_float(ink.r - ink.g).is_less(0.1)
	var body: RichTextLabel = card.get_node("Paper/Body")
	for lvl in 5:
		card.show_card("MORE.", lvl, 0)
		var ink := body.get_theme_color("default_color")
		assert_float(ink.r - ink.g).is_less(0.1)
		card.dismiss()
		await await_millis(int(BossCard.OUT_TIME * 1000) + 200)


func test_the_prompt_sits_on_a_dark_strip_so_it_reads_on_a_fully_green_screen() -> void:
	var prompt := _card().get_node("Prompt") as Label
	var strip := prompt.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_object(strip).is_not_null()
	assert_float(strip.bg_color.a).is_greater(0.6)
	assert_float(strip.bg_color.get_luminance()).is_less(0.1)

