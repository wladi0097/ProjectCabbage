extends GdUnitTestSuite

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func _deed() -> FarmDeed:
	var deed: FarmDeed = auto_free(load("res://entities/map_table/farm_deed.tscn").instantiate())
	add_child(deed)
	return deed


func _text(deed: FarmDeed, label: String) -> String:
	return (deed.get_node("Page/Form/" + label) as Label).text


func _rect(deed: FarmDeed, node: String) -> Rect2:
	return (deed.get_node("Page/Form/" + node) as Control).get_rect()


func test_the_deed_names_the_farm_its_site_and_its_price_in_coins_and_cabbages() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 1500000, stock = 5500})
	assert_str(_text(deed, "FormLine")).is_equal("FORM 3-D  DEED OF TRANSFER")
	assert_str(_text(deed, "Title")).is_equal("Kalden Farm")
	assert_str(_text(deed, "Site")).is_equal("FARM SITE K-8")
	assert_str(_text(deed, "Coins")).is_equal("$1,500,000")
	assert_str(_text(deed, "Cabbages")).is_equal("5,500 cabbages")
	assert_str(_text(deed, "CoinsShort")).is_empty()
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_true()
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_bool((deed.get_node("Page/Form/Imprint") as Control).visible).is_false()


func test_the_price_on_the_deed_can_be_printed_again() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 1500000, stock = 5500})
	deed.print_price({coins = 1200000, stock = 5000}, {stock = 40})
	assert_dict(deed.bill).is_equal({coins = 1200000, stock = 5000})
	assert_str(_text(deed, "Coins")).is_equal("$1,200,000")
	assert_str(_text(deed, "Cabbages")).is_equal("5,000 cabbages")
	assert_str(_text(deed, "CabbagesShort")).is_equal("SHORT 40")
	assert_int((deed.get_node("Page") as SubViewport).render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)


func test_the_deed_is_german_in_german_and_still_says_cabbages() -> void:
	TranslationServer.set_locale("de")
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 60000, stock = 800}, {coins = 5})
	assert_str(_text(deed, "Site")).is_equal("HOFSTELLE K-8")
	assert_str(_text(deed, "Cabbages")).is_equal("800 Kohlköpfe")
	assert_str(_text(deed, "CoinsShort")).is_equal("ES FEHLEN $5")
	for key: String in ["FORM 3-D  DEED OF TRANSFER", "PURCHASE PRICE", "STAMP HERE", "The seller confirms that the transfer is voluntary."]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
		assert_bool(tr(key).to_lower().contains("einheit")).is_false()


func test_a_deed_nobody_sells_wears_the_not_for_sale_strip_its_reason_and_no_stamp_box() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {}, {}, "The owner is unavailable.")
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_true()
	assert_str(_text(deed, "Strip/Word")).is_equal("NOT FOR SALE")
	assert_str(_text(deed, "Reason")).is_equal("The owner is unavailable.")
	assert_bool((deed.get_node("Page/Form/Reason") as Control).visible).is_true()
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	assert_str(_text(deed, "Coins")).is_empty()


func test_the_stamp_box_is_where_a_click_stamps_and_nowhere_else_on_the_form() -> void:
	var deed := _deed()
	assert_bool(_rect(deed, "Box").is_equal_approx(FarmDeed.STAMP_BOX)).is_true()
	assert_bool(FarmDeed.in_stamp_box(FarmDeed.STAMP_BOX.get_center())).is_true()
	assert_bool(FarmDeed.in_stamp_box(Vector2(100, 100))).is_false()
	assert_bool(Rect2(Vector2.ZERO, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE).encloses(FarmDeed.STAMP_BOX)).is_true()
	# The stamp comes down in the middle of the box.
	var middle := FarmDeed.STAMP_BOX.get_center() / FarmDeed.PIXELS_PER_METRE
	var stamp := (deed.get_node("Stamp") as Node3D).position
	assert_float(stamp.x).is_equal_approx(middle.x - FarmDeed.SIZE.x / 2.0, 0.001)
	assert_float(stamp.z).is_equal_approx(middle.y, 0.001)


func test_the_negotiations_band_lies_clear_of_everything_else_printed_on_the_form() -> void:
	var deed := _deed()
	for room: String in ["Offer", "Mood"]:
		for printed: String in ["Title", "Site", "Coins", "Cabbages", "CoinsShort", "CabbagesShort", "SmallPrint", "Log", "Box"]:
			assert_bool(_rect(deed, room).intersects(_rect(deed, printed))).override_failure_message("%s lies on %s" % [room, printed]).is_false()
	assert_bool(_rect(deed, "Offer").intersects(_rect(deed, "Mood"))).is_false()
	assert_bool(_rect(deed, "Log").intersects(_rect(deed, "Box"))).is_false()
	# Every box a click takes is where its panel is printed, and no two overlap.
	var panels := {&"deed_less": "Offer/Less", &"deed_more": "Offer/More", &"deed_offer": "Offer/Submit", &"deed_stamp": "Box"}
	assert_array(FarmDeed.BOXES.keys()).contains_exactly_in_any_order(panels.keys())
	for spot: StringName in panels:
		var box: Rect2 = FarmDeed.BOXES[spot]
		assert_bool((deed.get_node("Page/Form/" + panels[spot]) as Control).get_global_rect().is_equal_approx(box)).override_failure_message(spot).is_true()
		assert_str(FarmDeed.box_at(box.get_center())).is_equal(spot)
	assert_str(FarmDeed.box_at(Vector2(100, 100))).is_equal(&"")
	assert_bool(_rect(deed, "Mood").has_point(FarmDeed.MOOD_AT)).is_true()


func test_a_deed_nobody_haggles_over_keeps_its_band_empty() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 60000, stock = 800})
	for part: String in ["Offer", "Mood", "Log", "Asked"]:
		assert_bool((deed.get_node("Page/Form/" + part) as Control).visible).override_failure_message(part).is_false()
	assert_str(_text(deed, "SmallPrint")).is_equal("The seller confirms that the transfer is voluntary.")
	deed.print_haggle("stock", 150, PackedInt32Array([100]), [1], 4, 60000, "Cabbages offered are not returned.")
	deed.fill("Kalden Farm", &"K-7", {coins = 60000, stock = 800})  # The next deed is a fresh form.
	assert_bool((deed.get_node("Page/Form/Offer") as Control).visible).is_false()
	assert_bool((deed.get_node("Page/Form/SmallPrint") as Control).visible).is_true()
	assert_str(_text(deed, "SmallPrint")).is_equal("The seller confirms that the transfer is voluntary.")


func test_the_band_prints_the_offer_on_the_dial_the_round_and_the_owners_mood_after_each_offer() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 200000, stock = 2000})
	deed.print_haggle("stock", 1500, PackedInt32Array(), [], 5, 200000, "Cabbages offered are not returned.")
	assert_str(_text(deed, "Offer/Head")).is_equal("CABBAGES OFFERED")
	assert_str(_text(deed, "Offer/Value/Number")).is_equal("1,500")
	assert_str(_text(deed, "Offer/Round")).is_equal("1 / 5")
	assert_str(_text(deed, "Offer/Submit/Word")).is_equal("SUBMIT OFFER")
	assert_str(_text(deed, "SmallPrint")).is_equal("Cabbages offered are not returned.")
	assert_bool((deed.get_node("Page/Form/Mood/Imprint") as Control).visible).is_false()  # The first offer is blind.
	assert_bool((deed.get_node("Page/Form/Asked") as Control).visible).is_false()
	deed.print_price({coins = 192000, stock = 2000})
	deed.print_haggle("stock", 150, PackedInt32Array([100, 150]), [1, 3], 3, 200000)
	assert_str(_text(deed, "Offer/Round")).is_equal("3 / 5")
	assert_str(_text(deed, "Mood/Imprint/Word")).is_equal("INTRIGUED")  # The last one, stamped.
	assert_str(_text(deed, "Log")).is_equal("100  UNIMPRESSED\n150  INTRIGUED")
	assert_bool((deed.get_node("Page/Form/SmallPrint") as Control).visible).is_false()  # The list takes its place.
	assert_str(_text(deed, "Asked")).is_equal("ASKED $200,000")
	assert_bool((deed.get_node("Page/Form/Asked") as Control).visible).is_true()
	deed.print_haggle("stock", 150, PackedInt32Array([1, 1, 1, 1, 1]), [0, 0, 0, 0, 0], 0, 200000)
	assert_bool((deed.get_node("Page/Form/Offer/Closed") as Control).visible).is_true()
	assert_str(_text(deed, "Offer/Closed")).is_equal("NO FURTHER OFFERS")
	for part: String in ["Less", "Value", "More", "Submit"]:
		assert_bool((deed.get_node("Page/Form/Offer/" + part) as Control).visible).is_false()


func test_a_bribe_reads_in_coins_with_its_own_five_moods() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 5000000, stock = 9000})
	deed.print_haggle("coins", 150000, PackedInt32Array([40000]), [0], 4, 5000000)
	assert_str(_text(deed, "Offer/Head")).is_equal("IN THE ENVELOPE")
	assert_str(_text(deed, "Offer/Value/Number")).is_equal("$150,000")
	assert_str(_text(deed, "Offer/Submit/Word")).is_equal("PASS THE ENVELOPE")
	assert_str(_text(deed, "Mood/Imprint/Word")).is_equal("UNSEEN")
	assert_str(_text(deed, "Log")).is_equal("$40,000  UNSEEN")
	for words: Array in FarmDeed.MOODS.values():
		assert_int(words.size()).is_equal(FarmRegister.Mood.size())
	assert_array(FarmDeed.MOODS["stock"]).is_equal(["INSULTED", "UNIMPRESSED", "LISTENING", "INTRIGUED", "DELIGHTED"])


func test_everything_the_band_prints_fits_in_english_and_german_and_says_cabbages() -> void:
	var deed := _deed()
	var word := deed.get_node("Page/Form/Mood/Imprint/Word") as Label
	var listed := deed.get_node("Page/Form/Log") as Label
	var fits := func(label: Label, text: String, room: float) -> void:
		var width := label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
		assert_float(width).override_failure_message("%s (%d px of %d)" % [text, width, room]).is_less(room)
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for paid_in: String in FarmDeed.MOODS:
			for mood: String in FarmDeed.MOODS[paid_in]:
				if locale == "de":
					assert_str(tr(mood)).override_failure_message(mood).is_not_equal(mood)
				fits.call(word, tr(mood), word.size.x - 30.0)  # Inside the stamp's frame.
				fits.call(listed, "%s  %s" % [FarmDeed.amount_text(paid_in, 1500000 if paid_in == "coins" else 1000), tr(mood)], listed.size.x)
		fits.call(deed.get_node("Page/Form/Offer/Value/Number"), "$1,500,000", 264.0 - 12.0)
		for line: Array in [["Offer/Head", "CABBAGES OFFERED"], ["Offer/Head", "IN THE ENVELOPE"], ["Offer/Submit/Word", "SUBMIT OFFER"],
				["Offer/Submit/Word", "PASS THE ENVELOPE"], ["Mood/Head", "OWNER'S MOOD"], ["Asked", "ASKED %s"]]:
			var label := deed.get_node("Page/Form/" + line[0]) as Label
			if locale == "de":
				assert_str(tr(line[1])).override_failure_message(line[1]).is_not_equal(line[1])
			fits.call(label, tr(line[1]).replace("%s", "$5,000,000"), label.size.x)
		for key: String in ["NO FURTHER OFFERS", "Cabbages offered are not returned.", "Envelopes are not returned.", "Half of a refused offer is returned."]:
			if locale == "de":
				assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
			assert_bool(tr(key).to_lower().contains("einheit") or tr(key).to_lower().contains("unit")).is_false()


func test_the_stamp_comes_down_where_it_is_sent_and_a_mood_sounds_its_own_thump() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 200000, stock = 2000})
	deed.strike(0.1, FarmDeed.MOOD_AT)
	var stamp := deed.get_node("Stamp") as Node3D
	assert_float(stamp.position.x).is_equal_approx(FarmDeed.MOOD_AT.x / FarmDeed.PIXELS_PER_METRE - FarmDeed.SIZE.x / 2.0, 0.001)
	assert_float(stamp.position.z).is_equal_approx(FarmDeed.MOOD_AT.y / FarmDeed.PIXELS_PER_METRE, 0.001)
	deed.stamp_mood(true)
	assert_bool((deed.get_node("MoodStamp") as SoundCue).playing).is_true()
	assert_bool((deed.get_node("Agreed") as SoundCue).playing).is_true()
	assert_bool((deed.get_node("Strike") as SoundCue).playing).is_false()  # The ACQUIRED thunk stays the purchase's.
	assert_bool(deed.stamped).is_false()
	assert_bool((deed.get_node("Ring") as Node3D).visible).is_true()
	deed.strike(0.1)  # The stamp box again.
	assert_float(stamp.position.z).is_equal_approx(FarmDeed.STAMP_BOX.get_center().y / FarmDeed.PIXELS_PER_METRE, 0.001)


func test_the_stamp_prints_acquired_in_place_of_the_box() -> void:
	var deed := _deed()
	deed.fill("Kalden Farm", &"K-8", {coins = 60000, stock = 800})
	deed.strike(0.1)
	assert_bool((deed.get_node("Stamp") as Node3D).visible).is_true()
	assert_bool(deed.stamped).is_false()
	deed.imprint()
	assert_bool(deed.stamped).is_true()
	assert_bool((deed.get_node("Page/Form/Imprint") as Control).visible).is_true()
	assert_str(_text(deed, "Imprint/Word")).is_equal("ACQUIRED")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	assert_bool((deed.get_node("Ring") as Node3D).visible).is_true()
	deed.fill("Kalden Farm", &"K-7", {coins = 60000, stock = 800})  # The next deed is a fresh form.
	assert_bool(deed.stamped).is_false()
	assert_bool((deed.get_node("Page/Form/Imprint") as Control).visible).is_false()


func test_the_deed_rolls_itself_up_and_is_gone() -> void:
	var deed := _deed()
	deed.slide(Vector3(2, 0, 0), Vector3.ZERO, 0.3)
	deed._moving.custom_step(1.0)
	assert_bool(deed.visible).is_true()
	assert_bool(deed.position.is_equal_approx(Vector3.ZERO)).is_true()
	assert_float(deed.rotation.y).is_equal_approx(0.0, 0.001)  # Squared up.
	deed.roll_away(Vector3(2, 0, 0), 0.3, 0.3)
	deed._moving.custom_step(0.3)
	assert_float(deed.open).is_equal_approx(0.0, 0.001)
	assert_bool(deed.visible).is_true()
	deed._moving.custom_step(1.0)
	assert_bool(deed.visible).is_false()
	deed.slide(Vector3(2, 0, 0), Vector3.ZERO, 0.3)  # The next one lies flat again.
	assert_float(deed.open).is_equal(1.0)
