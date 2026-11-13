extends GdUnitTestSuite

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func test_a_price_shows_its_currency_sign() -> void:
	assert_str(UpgradeCard.price_text(10, "findings")).is_equal("¶10")
	assert_str(UpgradeCard.price_text(130, "coins")).is_equal("$130")


func test_a_price_paid_in_cabbages_is_the_number_with_the_cabbage_icon_before_it() -> void:
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("offsite_storage")))
	var coins: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("projector")))
	var price := card.get_node("Look/Price") as Label3D
	var icon := card.get_node("Look/PriceIcon") as Sprite3D

	assert_str(price.text).is_equal("60")
	assert_bool(icon.visible).is_true()
	assert_float(icon.position.x).is_less(price.position.x)
	assert_bool((coins.get_node("Look/PriceIcon") as Sprite3D).visible).is_false()
	# The icon takes room: the cabbage price is wider than its bare number.
	assert_float(UpgradeCard.price_width("60", "stock", 100)).is_greater(UpgradeCard.price_width("60", "coins", 100))


func test_every_card_price_fits_its_box_and_short_ones_keep_the_full_size() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		var paid_in: String = card.get("currency", "coins")
		var shown := UpgradeCard.price_text(card.price, paid_in)
		var width := UpgradeCard.price_width(shown, paid_in, UpgradeCard.price_size(shown, paid_in))
		assert_float(width).override_failure_message(shown).is_less_equal(UpgradeCard.PRICE_WIDTH)
	assert_int(UpgradeCard.price_size("$6")).is_equal(UpgradeCard.PRICE_SIZE)
	assert_int(UpgradeCard.price_size("¶3000")).is_less(UpgradeCard.PRICE_SIZE)


func test_research_directives_print_their_own_form_line() -> void:
	assert_str(UpgradeCard.form_of(UpgradeDesk.card_data("research_inspection"))).is_equal("FORM 7-R  RESEARCH DIRECTIVE")
	assert_str(UpgradeCard.form_of(UpgradeDesk.card_data("projector"))).is_equal("FORM 7-B  REQUISITION")


func test_a_card_is_paid_from_the_currency_it_names_or_coins_by_default() -> void:
	var coins: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("projector")))
	var findings: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("street_posters")))

	assert_str(coins.currency).is_equal("coins")
	assert_int(coins.price).is_equal(75)
	assert_str(findings.currency).is_equal("findings")
	assert_str(findings.id).is_equal("street_posters")


func test_cabbages_pass_through_a_card_on_its_own_layer() -> void:
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("radio")))

	assert_int(card.collision_layer).is_equal(UpgradeCard.LAYER)
	assert_int(card.collision_mask).is_equal(0)



func test_every_card_title_and_form_line_fits_its_card_in_english_and_german() -> void:
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for card: Dictionary in UpgradeDesk.CARDS:
			var lines: Array[Array] = [[card.title, UpgradeCard.HEADING_SIZE, UpgradeCard.HEADING_BOX],
					[UpgradeCard.form_of(card), UpgradeCard.FORM_SIZE, UpgradeCard.FORM_BOX]]
			for line in lines:
				var shown := TranslationServer.translate(line[0])
				var size := UpgradeCard.fit_size(shown, line[1], line[2])
				assert_bool(UpgradeCard.fits(shown, size, line[2])).override_failure_message("%s: %s" % [locale, shown]).is_true()
				assert_int(size).override_failure_message("%s: %s" % [locale, shown]).is_greater(UpgradeCard.MIN_SIZE)


func test_a_short_title_keeps_the_full_size_and_a_long_word_prints_smaller() -> void:
	assert_int(UpgradeCard.fit_size("PRICE SLATE", UpgradeCard.HEADING_SIZE, UpgradeCard.HEADING_BOX)).is_equal(UpgradeCard.HEADING_SIZE)
	assert_int(UpgradeCard.fit_size("FORSCHUNG: VERBRAUCHERSTIMMUNG", UpgradeCard.HEADING_SIZE, UpgradeCard.HEADING_BOX)).is_less(UpgradeCard.HEADING_SIZE)
	assert_int(UpgradeCard.fit_size("X".repeat(200), UpgradeCard.HEADING_SIZE, UpgradeCard.HEADING_BOX)).is_equal(UpgradeCard.MIN_SIZE)


func test_a_stage_changing_card_is_an_oxblood_priority_form_and_the_rest_plain_stock() -> void:
	for id: String in ["family_farm", "consolidation"]:  # The farm, and chapter 2's last card.
		var card := UpgradeDesk.card_data(id)
		assert_object(UpgradeCard.paper_tint(card)).override_failure_message(id).is_equal(UpgradeCard.PRIORITY_TINT)
		assert_str(UpgradeCard.form_of(card)).override_failure_message(id).is_equal("FORM 0-P  PRIORITY ACQUISITION")
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in ["family_farm", "consolidation"]:
			assert_object(UpgradeCard.paper_tint(card)).override_failure_message(card.id).is_equal(Color.WHITE)


func test_the_card_print_is_lit_by_the_lamp_like_the_paper_it_is_on() -> void:
	var card := auto_free(preload("res://entities/upgrade_desk/upgrade_card.tscn").instantiate()) as Node
	for path in ["Look/Form", "Look/Heading", "Look/Price"]:
		assert_bool((card.get_node(path) as Label3D).shaded).override_failure_message(path).is_true()


func test_a_card_in_several_currencies_prints_its_units_in_the_box_and_the_other_prices_left_of_it() -> void:
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("consolidation")))
	var price := card.get_node("Look/Price") as Label3D
	var also := card.get_node("Look/Also") as Label3D

	assert_str(price.text).is_equal("1900")
	assert_bool((card.get_node("Look/PriceIcon") as Sprite3D).visible).is_true()
	assert_bool(also.visible).is_true()
	assert_str(also.text).is_equal("$20000 + ¶4000 +")
	assert_float(also.position.x).is_less(UpgradeCard.PRICE_AT.x - UpgradeCard.PRICE_WIDTH * 0.5)
	var width := UpgradeCard.TITLE_FONT.get_string_size(also.text, HORIZONTAL_ALIGNMENT_LEFT, -1, also.font_size).x * UpgradeCard.PIXEL
	assert_float(width).is_less_equal(UpgradeCard.ALSO_WIDTH)
	assert_float(also.position.x - width).override_failure_message("on the card").is_greater(-UpgradeCard.SIZE.x * 0.5)


func test_a_card_in_one_currency_prints_nothing_beside_its_price_box() -> void:
	for each: Dictionary in UpgradeDesk.CARDS:
		if UpgradeDesk.costs(each).size() == 1:
			assert_str(UpgradeCard.also_text(UpgradeDesk.costs(each), each.get("currency", "coins"))).override_failure_message(each.id).is_empty()
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("projector")))
	assert_bool((card.get_node("Look/Also") as Label3D).visible).is_false()
