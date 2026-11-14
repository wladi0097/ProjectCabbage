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
	deed.fill("Kaletten Farm", &"K-8", {coins = 1500000, stock = 5500})
	assert_str(_text(deed, "FormLine")).is_equal("FORM 3-D  DEED OF TRANSFER")
	assert_str(_text(deed, "Title")).is_equal("Kaletten Farm")
	assert_str(_text(deed, "Site")).is_equal("FARM SITE K-8")
	assert_str(_text(deed, "Coins")).is_equal("$1,500,000")
	assert_str(_text(deed, "Cabbages")).is_equal("5,500 cabbages")
	assert_str(_text(deed, "CoinsShort")).is_empty()
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_true()
	assert_bool((deed.get_node("Page/Form/Strip") as Control).visible).is_false()
	assert_bool((deed.get_node("Page/Form/Imprint") as Control).visible).is_false()


func test_the_price_on_the_deed_can_be_printed_again() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 1500000, stock = 5500})
	deed.print_price({coins = 1200000, stock = 5000}, {stock = 40})
	assert_dict(deed.bill).is_equal({coins = 1200000, stock = 5000})
	assert_str(_text(deed, "Coins")).is_equal("$1,200,000")
	assert_str(_text(deed, "Cabbages")).is_equal("5,000 cabbages")
	assert_str(_text(deed, "CabbagesShort")).is_equal("SHORT 40")
	assert_int((deed.get_node("Page") as SubViewport).render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)


func test_the_deed_is_german_in_german_and_still_says_cabbages() -> void:
	TranslationServer.set_locale("de")
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 60000, stock = 800}, {coins = 5})
	assert_str(_text(deed, "Site")).is_equal("HOFSTELLE K-8")
	assert_str(_text(deed, "Cabbages")).is_equal("800 Kohlköpfe")
	assert_str(_text(deed, "CoinsShort")).is_equal("ES FEHLEN $5")
	for key: String in ["FORM 3-D  DEED OF TRANSFER", "PURCHASE PRICE", "STAMP HERE", "The seller confirms that the transfer is voluntary."]:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
		assert_bool(tr(key).to_lower().contains("einheit")).is_false()


func test_a_deed_nobody_sells_wears_the_not_for_sale_strip_its_reason_and_no_stamp_box() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {}, {}, "The owner is unavailable.")
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


## A label on the negotiation record's page.
func _record(deed: FarmDeed, label: String) -> String:
	return (deed.get_node("Haggle/Page/Form/" + label) as Label).text


func _shown(deed: FarmDeed, node: String) -> bool:
	return deed.get_node(node).get(&"visible")


func test_the_record_lies_over_the_deed_where_its_constants_say() -> void:
	var deed := _deed()
	var record := deed.get_node("Haggle") as Node3D
	assert_float(record.position.x).is_equal_approx(FarmDeed.HAGGLE_AT.x / FarmDeed.PIXELS_PER_METRE - FarmDeed.SIZE.x / 2.0, 0.0005)
	assert_float(record.position.z).is_equal_approx(FarmDeed.HAGGLE_AT.y / FarmDeed.PIXELS_PER_METRE, 0.0005)
	assert_float(record.position.y).is_equal_approx(FarmDeed.HAGGLE_LIFT, 0.0005)
	assert_float(record.rotation.y).is_equal_approx(-FarmDeed.HAGGLE_TURN, 0.0005)
	# Every corner of its page lands on the deed's pixel the page transform says, in 3D too.
	for corner: Vector2 in [Vector2.ZERO, Vector2(820, 0), Vector2(0, 1040), Vector2(820, 1040)]:
		var on_deed := FarmDeed.HAGGLE_PAGE * corner
		var world := record.transform * Vector3(corner.x / FarmDeed.PIXELS_PER_METRE, 0.0, corner.y / FarmDeed.PIXELS_PER_METRE)
		assert_float(world.x).is_equal_approx(on_deed.x / FarmDeed.PIXELS_PER_METRE - FarmDeed.SIZE.x / 2.0, 0.0005)
		assert_float(world.z).is_equal_approx(on_deed.y / FarmDeed.PIXELS_PER_METRE, 0.0005)
		assert_bool(FarmDeed.page(on_deed).is_equal_approx(corner)).is_true()


func test_every_box_is_where_its_panel_is_printed_and_takes_clicks_right_into_its_corners() -> void:
	var deed := _deed()
	var panels := {&"deed_stamp": "Page/Form/Box", &"deed_haggle": "Page/Form/Start", &"deed_crate": "Haggle/Page/Form/Crate",
			&"deed_pile": "Haggle/Page/Form/Pile", &"deed_send": "Haggle/Page/Form/Send", &"deed_return": "Haggle/Page/Form/Return"}
	assert_array(FarmDeed.DEED_BOXES.keys() + FarmDeed.HAGGLE_BOXES.keys()).contains_exactly_in_any_order(panels.keys())
	for spot: StringName in panels:
		var on_record := FarmDeed.HAGGLE_BOXES.has(spot)
		var box: Rect2 = FarmDeed.HAGGLE_BOXES[spot] if on_record else FarmDeed.DEED_BOXES[spot]
		assert_bool((deed.get_node(panels[spot]) as Control).get_global_rect().is_equal_approx(box)).override_failure_message(spot).is_true()
		var inner := box.grow(-2.0)
		for point: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end, box.get_center()]:
			var pixel := FarmDeed.HAGGLE_PAGE * point if on_record else point
			assert_str(FarmDeed.box_at(pixel, on_record)).override_failure_message("%s at %s" % [spot, point]).is_equal(spot)
	assert_str(FarmDeed.box_at(Vector2(100, 100))).is_equal(&"")
	# While the record lies over the deed the deed's boxes under it take nothing.
	assert_str(FarmDeed.box_at(FarmDeed.HAGGLE_BOX.get_center(), true)).is_not_equal(&"deed_haggle")
	assert_str(FarmDeed.box_at(FarmDeed.STAMP_BOX.get_center(), true)).is_not_equal(&"deed_stamp")
	assert_bool(FarmDeed.covers(FarmDeed.HAGGLE_PAGE * Vector2(810, 1035), true)).is_true()
	assert_bool(_rect(deed, "Start").intersects(_rect(deed, "SmallPrint"))).is_false()
	assert_bool(_rect(deed, "Start").intersects(_rect(deed, "Cabbages"))).is_false()


func test_the_letters_parts_lie_clear_of_each_other() -> void:
	var deed := _deed()
	var rect := func(node: String) -> Rect2: return (deed.get_node("Haggle/Page/Form/" + node) as Control).get_rect()
	var parts := ["Pile", "Send", "Crate", "Stock", "Return", "Slips", "Owner", "Price"]
	for i in parts.size():
		for j in range(i + 1, parts.size()):
			assert_bool(rect.call(parts[i]).intersects(rect.call(parts[j]))).override_failure_message("%s lies on %s" % [parts[i], parts[j]]).is_false()
	for printed: String in ["Opening", "Note"]:  # Before the first reply, in the slips' place.
		assert_bool(rect.call("Slips").encloses(rect.call(printed).grow(-12.0))).override_failure_message(printed).is_true()
	# Five slips fit between the rules, and the stamp lands on each one's own stamp box.
	var last := Rect2(NegotiationLetter.SLIP_AT + Vector2(0.0, NegotiationLetter.SLIP_STEP * (FarmRegister.ROUNDS - 1)), Vector2(732, 84))
	assert_float(last.end.y).is_less_equal(rect.call("Rule2").position.y)
	assert_bool(Rect2(8, 6, 190, 36).has_point(NegotiationLetter.SLIP_STAMP)).is_true()
	assert_float(NegotiationLetter.SLIP_STEP).is_greater_equal(84.0)  # No slip covers the one before it.
	for i in NegotiationLetter.MOST:  # Every bundle lies inside the offer, under its head.
		assert_bool(NegotiationLetter.PILE_BOX.grow(-30.0).has_point(NegotiationLetter.pile_place(i))).override_failure_message(str(i)).is_true()
		assert_float(NegotiationLetter.pile_place(i).y).is_greater(rect.call("Pile").position.y + 60.0)


func test_a_deed_nobody_haggles_over_has_no_start_haggling_box() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 60000, stock = 800})
	for part: String in ["Page/Form/Start", "Page/Form/Asked", "Haggle"]:
		assert_bool(_shown(deed, part)).override_failure_message(part).is_false()
	assert_str(_text(deed, "SmallPrint")).is_equal("The seller confirms that the transfer is voluntary.")
	deed.print_haggle("stock", 25, "H. Wirsing", [], 5, 60000, 30000)
	assert_bool(_shown(deed, "Page/Form/Start")).is_true()
	deed.fill("Kaletten Farm", &"K-7", {coins = 60000, stock = 800})  # The next deed is a fresh form.
	assert_bool(_shown(deed, "Page/Form/Start")).is_false()
	assert_str(_text(deed, "SmallPrint")).is_equal("The seller confirms that the transfer is voluntary.")


func test_start_haggling_says_how_the_negotiation_stands() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 200000, stock = 2000})
	deed.print_haggle("stock", 25, "G. Lattich", [], 5, 200000, 30000)
	assert_str(_text(deed, "Start/Word")).is_equal("START HAGGLING")
	var one := [{offered = 30, mood = "INSULTED", line = "Closer. Not close."}]
	deed.print_haggle("stock", 25, "G. Lattich", one, 4, 200000, 30000)
	assert_str(_text(deed, "Start/Word")).is_equal("RESUME HAGGLING")
	deed.print_haggle("stock", 25, "G. Lattich", one + one + one + one + one, 0, 200000, 30000)
	assert_str(_text(deed, "Start/Word")).is_equal("NEGOTIATION RECORD")


func test_the_record_slides_over_the_deed_and_away_and_a_new_deed_comes_without_it() -> void:
	var deed := _deed()
	var record := deed.get_node("Haggle") as Node3D
	var rest := record.position
	deed.fill("Kaletten Farm", &"K-8", {coins = 200000, stock = 2000})
	deed.lay_haggle(true, 1.5, 0.3)
	assert_bool(deed.haggling).is_true()
	assert_bool(record.visible).is_true()
	assert_float(record.position.x).is_equal_approx(rest.x + 1.5, 0.001)  # Comes in from the side.
	assert_bool((deed.get_node("Slide") as SoundCue).playing).is_true()
	deed._haggle_moving.custom_step(1.0)
	assert_bool(record.position.is_equal_approx(rest)).is_true()
	deed.lay_haggle(false, 1.5, 0.3)
	assert_bool(deed.haggling).is_false()
	deed._haggle_moving.custom_step(1.0)
	assert_bool(record.visible).is_false()
	deed.lay_haggle(true, 1.5, 0.3)
	deed.slide(Vector3(2, 0, 0), Vector3.ZERO, 0.3)  # Another farm's deed.
	assert_bool(deed.haggling).is_false()
	assert_bool(record.visible).is_false()
	assert_bool(record.position.is_equal_approx(rest)).is_true()


func test_the_letter_names_the_owner_the_price_and_a_reply_slip_per_offer_with_its_mood() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 200000, stock = 2000})
	deed.print_haggle("stock", 25, "G. Lattich", [], 5, 200000, 30000, "Cabbages offered are not returned.")
	assert_str(_record(deed, "Owner")).is_equal("Owner: G. Lattich")
	assert_str(_record(deed, "Price")).is_equal("$200,000 + 2,000 cabbages")
	assert_str(_record(deed, "Opening")).is_equal("Drag cabbages from the crate onto your offer, then send it. Too few raise the price. Enough lower it.")
	assert_str(_record(deed, "Note")).is_equal("Cabbages offered are not returned.")
	assert_str(_record(deed, "Pile/Head")).is_equal("OFFER 1 OF 5")
	assert_str(_record(deed, "Pile/Total")).is_equal("0 cabbages")
	assert_str(_record(deed, "Send/Word")).is_equal("SEND OFFER")
	assert_str(_record(deed, "Stock")).is_equal("IN STOCK 30,000")
	assert_int(deed.get_node("Haggle/Page/Form/Slips").get_child_count()).is_equal(0)  # The first offer is blind.
	assert_bool(_shown(deed, "Page/Form/Asked")).is_false()
	deed.print_price({coins = 192000, stock = 1920})
	deed.print_haggle("stock", 25, "G. Lattich", [{offered = 100, mood = "UNIMPRESSED", line = "Closer. Not close."}, {offered = 150, mood = "INTRIGUED", line = "Acceptable. The price comes down."}], 3, 200000, 29750)
	assert_str(_record(deed, "Price")).is_equal("$192,000 + 1,920 cabbages")
	assert_str(_record(deed, "Pile/Head")).is_equal("OFFER 3 OF 5")
	var slips := deed.get_node("Haggle/Page/Form/Slips")
	assert_int(slips.get_child_count()).is_equal(2)
	assert_str((slips.get_child(0).get_node("Line") as Label).text).is_equal("Closer. Not close.")
	assert_str((slips.get_child(0).get_node("Imprint/Word") as Label).text).is_equal("UNIMPRESSED")
	assert_str((slips.get_child(0).get_node("About") as Label).text).is_equal("re: 100 cabbages")
	assert_str((slips.get_child(1).get_node("Imprint/Word") as Label).text).is_equal("INTRIGUED")  # The newest, under it.
	assert_float((slips.get_child(1) as Control).position.y).is_greater((slips.get_child(0) as Control).position.y)
	assert_bool(_shown(deed, "Haggle/Page/Form/Note")).is_false()  # The slips take its place.
	assert_bool(_shown(deed, "Haggle/Page/Form/Opening")).is_false()
	assert_bool(_shown(deed, "Page/Form/Asked")).is_true()
	assert_str(_text(deed, "SmallPrint")).is_equal("The seller confirms that the transfer is voluntary.")  # The deed's own.
	var five := []
	for i in 5:
		five.append({offered = 1, mood = "INSULTED", line = "Is this a joke? Double it."})
	deed.print_haggle("stock", 25, "G. Lattich", five, 0, 200000, 29750)
	assert_bool(_shown(deed, "Haggle/Page/Form/Pile/Closed")).is_true()
	assert_str(_record(deed, "Pile/Closed")).is_equal("NO FURTHER OFFERS")
	assert_str(_record(deed, "Pile/Head")).is_equal("YOUR OFFER")
	for part: String in ["Haggle/Page/Form/Send", "Haggle/Page/Form/Crate", "Haggle/Crate", "Haggle/Page/Form/Pile/Total"]:
		assert_bool(_shown(deed, part)).override_failure_message(part).is_false()
	deed.print_haggle("stock", 25, "G. Lattich", [], 5, 200000, 29750)  # Another owner's letter: no slips of the last.
	assert_int(slips.get_child_count()).is_equal(0)


func test_a_bribe_reads_in_coins_with_its_own_five_moods() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 5000000, stock = 9000})
	deed.print_haggle("coins", 100000, "M. Kappes", [{offered = 100000, mood = "UNSEEN", line = "What envelope? I see no envelope."}], 4, 5000000, 6000000)
	assert_str(_record(deed, "Opening")).is_equal("Put coins from the purse in the envelope, then pass it. Too little raises the price. Enough lowers it.")
	assert_str(_record(deed, "Send/Word")).is_equal("PASS THE ENVELOPE")
	assert_str(_record(deed, "Stock")).is_equal("IN THE PURSE $6M")
	assert_str(_record(deed, "Pile/Total")).is_equal("$0")
	var slip := deed.get_node("Haggle/Page/Form/Slips").get_child(0)
	assert_str((slip.get_node("About") as Label).text).is_equal("re: $100,000")
	for words: Array in FarmDeed.MOODS.values():
		assert_int(words.size()).is_equal(FarmRegister.Mood.size())
	assert_array(FarmDeed.MOODS["stock"]).is_equal(["INSULTED", "UNIMPRESSED", "LISTENING", "INTRIGUED", "DELIGHTED"])
	for bundle: Node in deed.get_node("Haggle/Crate/Bundles").get_children():  # The purse holds coin stacks.
		assert_bool((bundle as OfferBundle).coins).is_true()


func test_everything_the_negotiation_prints_fits_in_english_and_german_and_says_cabbages() -> void:
	var deed := _deed()
	deed.print_haggle("stock", 25, "R. Rübsam", [{offered = 1, mood = "INSULTED", line = "x"}], 4, 200000, 30000)
	var slip := deed.get_node("Haggle/Page/Form/Slips").get_child(0)
	var word := slip.get_node("Imprint/Word") as Label
	var about := slip.get_node("About") as Label
	var fits := func(label: Label, text: String, room: float) -> void:
		var width := label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
		assert_float(width).override_failure_message("%s (%d px of %d)" % [text, width, room]).is_less(room)
	var lines_fit := func(label: Label, text: String) -> void:
		var height := label.get_theme_font(&"font").get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, label.get_theme_font_size(&"font_size")).y
		assert_float(height).override_failure_message("%s (%d px of %d)" % [text, height, label.size.y]).is_less_equal(label.size.y)
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for paid_in: String in FarmDeed.MOODS:
			for mood: String in FarmDeed.MOODS[paid_in]:
				if locale == "de":
					assert_str(tr(mood)).override_failure_message(mood).is_not_equal(mood)
				fits.call(word, tr(mood), word.size.x - 12.0)  # Inside the stamp's frame.
			fits.call(about, tr("re: %s") % NegotiationLetter.amount_text(paid_in, 1500000 if paid_in == "coins" else 1125), about.size.x)
		for line: Array in [["Haggle/Page/Form/Pile/Head", "OFFER %d OF %d"], ["Haggle/Page/Form/Pile/Head", "YOUR OFFER"],
				["Haggle/Page/Form/Send/Word", "SEND OFFER"], ["Haggle/Page/Form/Send/Word", "PASS THE ENVELOPE"],
				["Haggle/Page/Form/Stock", "IN STOCK %s"], ["Haggle/Page/Form/Stock", "IN THE PURSE %s"],
				["Haggle/Page/Form/FormLine", "FORM 3-N  NEGOTIATION"], ["Haggle/Page/Form/PriceHead", "PRICE NOW"],
				["Haggle/Page/Form/Owner", "Owner: %s"], ["Page/Form/Asked", "ASKED %s"],
				["Page/Form/Start/Word", "START HAGGLING"], ["Page/Form/Start/Word", "RESUME HAGGLING"], ["Page/Form/Start/Word", "NEGOTIATION RECORD"]]:
			var label := deed.get_node(line[0]) as Label
			if locale == "de":
				assert_str(tr(line[1])).override_failure_message(line[1]).is_not_equal(line[1])
			var text: String = tr(line[1]).replace("%d", "5").replace("%s", {"Owner: %s": "W. Kohlhaas", "IN STOCK %s": "30,000", "IN THE PURSE %s": "$10M"}.get(line[1], "$9,000,000"))
			fits.call(label, text, label.size.x)
		var price := deed.get_node("Haggle/Page/Form/Price") as Label  # The price beside its head.
		fits.call(price, "$7,000,000 + " + tr("%s cabbages") % "12,600", price.size.x)
		var total := deed.get_node("Haggle/Page/Form/Pile/Total") as Label
		fits.call(total, tr("%s cabbages") % "1,125", total.size.x)
		for line: Array in [["Haggle/Page/Form/Return/Word", "BACK TO THE DEED"],
				["Haggle/Page/Form/Opening", "Drag cabbages from the crate onto your offer, then send it. Too few raise the price. Enough lower it."],
				["Haggle/Page/Form/Opening", "Put coins from the purse in the envelope, then pass it. Too little raises the price. Enough lowers it."],
				["Haggle/Page/Form/Note", "Cabbages offered are not returned."], ["Haggle/Page/Form/Note", "Envelopes are not returned."],
				["Haggle/Page/Form/Note", "Half of a refused offer is returned."], ["Haggle/Page/Form/Pile/Closed", "NO FURTHER OFFERS"]]:
			if locale == "de":
				assert_str(tr(line[1])).override_failure_message(line[1]).is_not_equal(line[1])
			lines_fit.call(deed.get_node(line[0]) as Label, tr(line[1]))
			assert_bool(tr(line[1]).to_lower().contains("einheit") or tr(line[1]).to_lower().contains("unit")).is_false()


func test_every_reply_line_fits_its_slip_in_full_in_english_and_german() -> void:
	var deed := _deed()
	deed.print_haggle("stock", 25, "R. Rübsam", [{offered = 1, mood = "INSULTED", line = "x"}], 4, 200000, 30000)
	var said := deed.get_node("Haggle/Page/Form/Slips").get_child(0).get_node("Line") as Label
	var font := said.get_theme_font(&"font")
	var size := said.get_theme_font_size(&"font_size")
	var tallest := 0.0
	var longest := ""
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for paid_in: String in FarmRegister.REPLIES:
			for lines: Array in FarmRegister.REPLIES[paid_in]:
				for line: String in lines:
					var height := font.get_multiline_string_size(tr(line), HORIZONTAL_ALIGNMENT_LEFT, said.size.x, size).y
					assert_float(height).override_failure_message("%s (%d px of %d)" % [tr(line), height, said.size.y]).is_less_equal(said.size.y)
					if tr(line).length() > longest.length():
						longest = tr(line)
					tallest = maxf(tallest, height)
	# The longest line of all (German) still shows in full on two lines.
	assert_float(font.get_multiline_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, said.size.x, size).y).is_less_equal(said.size.y)
	assert_float(tallest).is_less_equal(said.size.y)


func test_the_stamp_comes_down_on_the_newest_reply_slip_and_a_mood_sounds_its_own_thump() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 200000, stock = 2000})
	deed.print_haggle("stock", 25, "G. Lattich", [{offered = 100, mood = "UNIMPRESSED", line = "Closer. Not close."}, {offered = 150, mood = "INTRIGUED", line = "Acceptable. The price comes down."}], 3, 200000, 30000)
	deed.strike_mood(0.1)
	var stamp := deed.get_node("Stamp") as Node3D
	var mood := FarmDeed.HAGGLE_PAGE * (NegotiationLetter.SLIP_AT + Vector2(0.0, NegotiationLetter.SLIP_STEP) + NegotiationLetter.SLIP_STAMP)
	assert_float(stamp.position.x).is_equal_approx(mood.x / FarmDeed.PIXELS_PER_METRE - FarmDeed.SIZE.x / 2.0, 0.001)
	assert_float(stamp.position.z).is_equal_approx(mood.y / FarmDeed.PIXELS_PER_METRE, 0.001)
	(deed._stamping as Tween).custom_step(1.0)
	assert_float(stamp.position.y).is_greater(FarmDeed.HAGGLE_LIFT - 0.0001)  # On the letter, not through it.
	deed.stamp_mood(true)
	assert_bool((deed.get_node("MoodStamp") as SoundCue).playing).is_true()
	assert_bool((deed.get_node("Agreed") as SoundCue).playing).is_true()
	assert_bool((deed.get_node("Strike") as SoundCue).playing).is_false()  # The ACQUIRED thunk stays the purchase's.
	assert_bool(deed.stamped).is_false()
	assert_bool((deed.get_node("Ring") as Node3D).visible).is_true()


func test_the_stamp_prints_acquired_in_place_of_the_box() -> void:
	var deed := _deed()
	deed.fill("Kaletten Farm", &"K-8", {coins = 60000, stock = 800})
	deed.strike(0.1)
	assert_bool((deed.get_node("Stamp") as Node3D).visible).is_true()
	assert_bool(deed.stamped).is_false()
	deed.imprint()
	assert_bool(deed.stamped).is_true()
	assert_bool((deed.get_node("Page/Form/Imprint") as Control).visible).is_true()
	assert_str(_text(deed, "Imprint/Word")).is_equal("ACQUIRED")
	assert_bool((deed.get_node("Page/Form/Box") as Control).visible).is_false()
	assert_bool((deed.get_node("Ring") as Node3D).visible).is_true()
	deed.fill("Kaletten Farm", &"K-7", {coins = 60000, stock = 800})  # The next deed is a fresh form.
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
