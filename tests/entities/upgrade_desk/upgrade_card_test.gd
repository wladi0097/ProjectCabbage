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
	for id: String in ["family_farm", "consolidation", "stars"]:  # Only what changes the chapter: the farm, and each chapter's last card.
		var card := UpgradeDesk.card_data(id)
		assert_object(UpgradeCard.paper_tint(card)).override_failure_message(id).is_equal(UpgradeCard.PRIORITY_TINT)
		assert_str(UpgradeCard.form_of(card)).override_failure_message(id).is_equal("FORM 0-P  PRIORITY ACQUISITION")
	for card: Dictionary in UpgradeDesk.CARDS:
		if card.id not in ["family_farm", "consolidation", "stars"]:
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
	var width := UpgradeCard.also_width(also.text, also.font_size)
	assert_float(width).is_less_equal(UpgradeCard.ALSO_WIDTH)
	assert_float(also.position.x - width).override_failure_message("on the card").is_greater(-UpgradeCard.SIZE.x * 0.5)


func test_a_card_in_one_currency_prints_nothing_beside_its_price_box() -> void:
	for each: Dictionary in UpgradeDesk.CARDS:
		if UpgradeDesk.costs(each).size() == 1:
			assert_str(UpgradeCard.also_text(UpgradeDesk.costs(each), each.get("currency", "coins"))).override_failure_message(each.id).is_empty()
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("projector")))
	assert_bool((card.get_node("Look/Also") as Label3D).visible).is_false()


func test_farms_a_card_needs_are_printed_left_of_its_price_box_as_their_count_and_the_farm_icon_in_any_language() -> void:
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		assert_str(UpgradeCard.price_text(24, "farms")).is_equal("24")
		assert_str(UpgradeCard.price_text(1, "farms")).is_equal("1")
		assert_str(UpgradeCard.price_text(8, "home_farms")).is_equal("8")  # Home farms print as farms.
		var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("stars")))
		var also := card.get_node("Look/Also") as Label3D
		var count := card.get_node("Look/Farms") as Label3D
		var icon := card.get_node("Look/FarmIcon") as Sprite3D
		assert_bool(count.visible).is_true()
		assert_bool(icon.visible).is_true()
		assert_str(count.text).is_equal("24")
		assert_object(icon.texture).is_same(UpgradeCard.FARM_ICON)
		assert_str(also.text).is_equal("+")  # "24 [farm] +" and the price in its box: no word for farms.
		assert_str((card.get_node("Look/Price") as Label3D).text).is_equal("$%d" % UpgradeDesk.card_data("stars").price)
		# Left to right: the count, the icon, the plus, the price box.
		assert_float(count.position.x).is_less(icon.position.x)
		assert_float(icon.position.x).is_less(also.position.x)
		assert_float(also.position.x).is_less(UpgradeCard.PRICE_AT.x - UpgradeCard.PRICE_WIDTH * 0.5)


func test_the_farm_icon_is_a_little_taller_than_the_print_beside_it_and_lit_and_inked_like_it() -> void:
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("condense")))
	var also := card.get_node("Look/Also") as Label3D
	var count := card.get_node("Look/Farms") as Label3D
	var icon := card.get_node("Look/FarmIcon") as Sprite3D
	assert_str(count.text).is_equal("1")
	assert_int(count.font_size).is_equal(also.font_size)
	assert_float(icon.pixel_size * icon.texture.get_height()).is_equal_approx(also.font_size * UpgradeCard.PIXEL * UpgradeCard.FARM_EM, 0.0001)
	assert_float(UpgradeCard.FARM_EM).is_greater(UpgradeCard.ICON_EM)
	# Still on its line: under the heading's box, above the paper's edge.
	assert_float(icon.position.z - icon.pixel_size * icon.texture.get_height() * 0.5).is_greater_equal(UpgradeCard.HEADING_BOX.y * 0.5 - 0.01)
	assert_float(icon.position.z + icon.pixel_size * icon.texture.get_height() * 0.5).is_less(UpgradeCard.SIZE.y * 0.5)
	assert_bool(icon.shaded).is_true()
	assert_bool(count.shaded).is_true()
	assert_object(icon.modulate).is_equal(UpgradeCard.INK)
	assert_object(count.modulate).is_equal(UpgradeCard.INK)


func test_a_card_that_needs_no_farm_shows_no_farm_icon() -> void:
	for id: String in ["projector", "consolidation", "offsite_storage"]:
		var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data(id)))
		assert_bool((card.get_node("Look/FarmIcon") as Sprite3D).visible).override_failure_message(id).is_false()
		assert_bool((card.get_node("Look/Farms") as Label3D).visible).override_failure_message(id).is_false()


func test_every_card_that_needs_farms_prints_them_and_its_other_prices_on_the_card_left_of_the_box() -> void:
	var with_farms := 0
	for each: Dictionary in UpgradeDesk.CARDS:
		var bill := UpgradeDesk.costs(each)
		var farms := UpgradeCard.farms_of(bill)
		assert_int(farms).override_failure_message(each.id).is_equal(int(each.get("farms", each.get("home_farms", 0))))
		if farms == 0:
			continue
		with_farms += 1
		var shown := UpgradeCard.also_text(bill, each.get("currency", "coins"))
		assert_bool(shown.begins_with("+")).override_failure_message(each.id).is_true()
		var size := UpgradeCard.also_size(shown, farms)
		assert_int(size).override_failure_message(each.id).is_greater(UpgradeCard.MIN_SIZE)
		assert_float(UpgradeCard.also_width(shown, size, farms)).override_failure_message(each.id).is_less_equal(UpgradeCard.ALSO_WIDTH)
		# The count's left edge is still on the paper.
		var left := UpgradeCard.PRICE_AT.x - UpgradeCard.PRICE_WIDTH * 0.5 - UpgradeCard.ALSO_GAP - UpgradeCard.also_width(shown, size, farms)
		assert_float(left).override_failure_message(each.id).is_greater(-UpgradeCard.SIZE.x * 0.5)
	assert_int(with_farms).is_greater(5)
	# The farms and a second price share the line: sea lanes prints "13 [farm] + $12000000 +".
	assert_str(UpgradeCard.also_text(UpgradeDesk.costs(UpgradeDesk.card_data("sea_lanes")), "findings")).is_equal("+ $12000000 +")


func test_on_paper_a_farm_count_is_drawn_with_the_farm_icon_after_it_and_cabbages_with_theirs_before() -> void:
	assert_object(UpgradeCard.icon_of("farms")).is_same(UpgradeCard.FARM_ICON)
	assert_object(UpgradeCard.icon_of("home_farms")).is_same(UpgradeCard.FARM_ICON)
	assert_object(UpgradeCard.icon_of("stock")).is_same(UpgradeCard.ICON)
	assert_object(UpgradeCard.icon_of("coins")).is_null()
	assert_object(UpgradeCard.icon_of("findings")).is_null()
	assert_bool(UpgradeCard.icon_follows("farms")).is_true()
	assert_bool(UpgradeCard.icon_follows("stock")).is_false()
	# The icon takes room in a row of prices (the note's bill, the press's card).
	assert_float(UpgradeCard.price_width("5", "farms", 100)).is_greater(UpgradeCard.price_width("5", "coins", 100))
	assert_float(UpgradeCard.bill_row_width({farms = 5, stock = 13000}, 34)).is_greater(UpgradeCard.bill_row_width({stock = 13000}, 34))
