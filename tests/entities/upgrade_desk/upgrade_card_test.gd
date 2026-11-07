extends GdUnitTestSuite

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func test_a_price_shows_its_currency_sign() -> void:
	assert_str(UpgradeCard.price_text(10, "findings")).is_equal("¶10")
	assert_str(UpgradeCard.price_text(130, "coins")).is_equal("$130")


func test_every_card_price_fits_its_box_and_short_ones_keep_the_full_size() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		var shown := UpgradeCard.price_text(card.price, card.get("currency", "coins"))
		var width := UpgradeCard.TITLE_FONT.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, UpgradeCard.price_size(shown)).x
		assert_float(width * UpgradeCard.PIXEL).override_failure_message(shown).is_less_equal(UpgradeCard.PRICE_WIDTH)
	assert_int(UpgradeCard.price_size("$6")).is_equal(UpgradeCard.PRICE_SIZE)
	assert_int(UpgradeCard.price_size("¶3000")).is_less(UpgradeCard.PRICE_SIZE)


func test_research_directives_print_their_own_form_line() -> void:
	assert_str(UpgradeCard.form_of(UpgradeDesk.card_data("research_inspection"))).is_equal("FORM 7-R  RESEARCH DIRECTIVE")
	assert_str(UpgradeCard.form_of(UpgradeDesk.card_data("projector"))).is_equal("FORM 7-B  REQUISITION")


func test_a_card_is_paid_from_the_currency_it_names_or_coins_by_default() -> void:
	var coins: UpgradeCard = auto_free(UpgradeCard.new(UpgradeDesk.card_data("projector")))
	var findings: UpgradeCard = auto_free(UpgradeCard.new(UpgradeDesk.card_data("street_posters")))

	assert_str(coins.currency).is_equal("coins")
	assert_int(coins.price).is_equal(75)
	assert_str(findings.currency).is_equal("findings")
	assert_str(findings.id).is_equal("street_posters")


func test_cabbages_pass_through_a_card_on_its_own_layer() -> void:
	var card: UpgradeCard = auto_free(UpgradeCard.new(UpgradeDesk.card_data("radio")))

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
	var farm := UpgradeDesk.card_data("family_farm")
	assert_object(UpgradeCard.paper_tint(farm)).is_equal(UpgradeCard.PRIORITY_TINT)
	assert_str(UpgradeCard.form_of(farm)).is_equal("FORM 0-P  PRIORITY ACQUISITION")
	for card: Dictionary in UpgradeDesk.CARDS:
		if not card.has("event"):
			assert_object(UpgradeCard.paper_tint(card)).override_failure_message(card.id).is_equal(Color.WHITE)
