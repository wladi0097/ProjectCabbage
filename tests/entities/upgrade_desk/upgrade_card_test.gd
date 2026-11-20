extends GdUnitTestSuite

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func test_a_price_shows_its_currency_sign() -> void:
	assert_str(UpgradeCard.price_text(10, "findings")).is_equal("¶10")
	assert_str(UpgradeCard.price_text(130, "coins")).is_equal("$130")


func test_card_prices_print_their_numbers_like_every_other_number() -> void:
	assert_str(UpgradeCard.price_text(1000000, "coins")).is_equal("$1M")
	assert_str(UpgradeCard.price_text(13000, "stock")).is_equal("13K")
	assert_str(UpgradeCard.price_text(4000, "findings")).is_equal("¶4K")
	assert_str(UpgradeCard.price_text(999, "coins")).is_equal("$999")
	assert_str(UpgradeCard.price_text(13500, "stock")).is_equal("13.500")


func test_no_card_body_writes_a_thousand_with_a_comma_since_the_price_uses_dots() -> void:
	var comma := RegEx.create_from_string("\\d,\\d{3}")
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_object(comma.search(card.body)).override_failure_message(card.id).is_null()


func test_no_card_body_states_the_farms_it_needs_since_its_price_line_shows_them() -> void:
	var needs := RegEx.create_from_string("(?i)(needs|braucht|erfordert) (\\d+|every|all|jeden|alle) .*(farm|hof|höfe)")
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for card: Dictionary in UpgradeDesk.CARDS:
			var body := TranslationServer.translate(card.body)
			assert_object(needs.search(body)).override_failure_message("%s: %s" % [locale, card.id]).is_null()
			var farms := UpgradeCard.farms_of(UpgradeDesk.costs(card))
			if farms > 0:
				var count := RegEx.create_from_string("\\b%d (farm|Hof|Höfe)" % farms)
				assert_object(count.search(body)).override_failure_message("%s: %s" % [locale, card.id]).is_null()


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


func test_a_card_that_only_counts_farms_prints_their_count_and_the_farm_icon_in_the_box_and_nothing_else() -> void:
	var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("home_review")))
	var price := card.get_node("Look/Price") as Label3D
	var icon := card.get_node("Look/PriceIcon") as Sprite3D

	assert_str(price.text).is_equal(str(UpgradeDesk.Events.HOME_SELLERS))
	assert_bool(icon.visible).is_true()
	assert_object(icon.texture).is_same(UpgradeCard.FARM_ICON)
	assert_float(icon.position.x).is_greater(price.position.x)  # "5 [farm]": the barn after the count.
	for path in ["Look/Also", "Look/Farms", "Look/FarmIcon"]:  # No "$0", no second count.
		assert_bool((card.get_node(path) as Node3D).visible).override_failure_message(path).is_false()


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

	assert_str(price.text).is_equal("1.900")
	assert_bool((card.get_node("Look/PriceIcon") as Sprite3D).visible).is_true()
	assert_bool(also.visible).is_true()
	assert_str(also.text).is_equal("$20K + ¶4K +")
	assert_float(also.position.x).is_less(price.position.x)
	var width := UpgradeCard.also_width(also.text, also.font_size)
	assert_float(also.position.x - width).override_failure_message("in the box").is_greater_equal(UpgradeCard.WIDE_LEFT)


func test_units_stand_in_the_box_with_their_icon_even_on_a_card_priced_in_coins() -> void:
	var bill := UpgradeDesk.costs(UpgradeDesk.card_data("rejected_goods"))
	assert_str(UpgradeCard.boxed_in(bill, "coins")).is_equal("stock")
	assert_str(UpgradeCard.also_text(bill, "stock")).is_equal("+ $120K +")
	assert_str(UpgradeCard.boxed_in({coins = 75}, "coins")).is_equal("coins")
	assert_str(UpgradeCard.boxed_in({farms = 1, coins = 30000}, "coins")).is_equal("coins")


func test_a_card_with_more_than_two_price_items_is_printed_on_the_wide_paper() -> void:
	assert_bool(UpgradeCard.wide({coins = 75})).is_false()
	assert_bool(UpgradeCard.wide({farms = 1, coins = 30000})).is_false()  # Farms count as one item.
	assert_bool(UpgradeCard.wide({farms = 2, coins = 120000, stock = 2500})).is_true()
	for id: String in ["projector", "condense", "rejected_goods", "structured_farm"]:
		var data := UpgradeDesk.card_data(id)
		var card: UpgradeCard = auto_free(UpgradeCard.create(data))
		var paper := (card.get_node("Look/Paper") as MeshInstance3D).material_override as StandardMaterial3D
		var is_wide := UpgradeDesk.costs(data).size() > 2
		assert_object(paper.albedo_texture).override_failure_message(id).is_same(
				(UpgradeCard.WIDE_MATERIAL if is_wide else UpgradeCard.MATERIAL).albedo_texture)


func test_a_priority_form_on_wide_paper_is_the_wide_paper_dyed_oxblood() -> void:
	var data := UpgradeDesk.card_data("consolidation")
	assert_bool(UpgradeCard.wide(UpgradeDesk.costs(data))).is_true()
	var paper := UpgradeCard.paper_of(data)
	assert_object(paper.albedo_texture).is_same(UpgradeCard.WIDE_MATERIAL.albedo_texture)
	assert_object(paper.albedo_color).is_equal(UpgradeCard.PRIORITY_TINT)
	assert_object(UpgradeCard.paper_of(UpgradeDesk.card_data("projector"))).is_same(UpgradeCard.MATERIAL)


func test_on_wide_paper_every_price_stands_in_the_box_right_to_left_with_its_sign() -> void:
	var wide_cards := 0
	for each: Dictionary in UpgradeDesk.CARDS:
		var bill := UpgradeDesk.costs(each)
		if not UpgradeCard.wide(bill):
			continue
		wide_cards += 1
		var size := UpgradeCard.wide_size(bill)
		assert_int(size).override_failure_message(each.id).is_greater(UpgradeCard.MIN_SIZE)
		assert_float(UpgradeCard.wide_width(bill, size)).override_failure_message(each.id).is_less_equal(
				UpgradeCard.WIDE_RIGHT - UpgradeCard.WIDE_LEFT - UpgradeCard.WIDE_PAD * 2.0)
		var card: UpgradeCard = auto_free(UpgradeCard.create(each))
		var also := card.get_node("Look/Also") as Label3D
		var price := card.get_node("Look/Price") as Label3D
		# Every currency signed: $ and ¶ in print, units and farms by their icons.
		var line := also.text + " " + price.text
		if bill.has("coins"):
			assert_bool(line.contains("$")).override_failure_message(each.id).is_true()
		if bill.has("findings"):
			assert_bool(line.contains("¶")).override_failure_message(each.id).is_true()
		assert_bool((card.get_node("Look/PriceIcon") as Sprite3D).visible).override_failure_message(each.id).is_equal(bill.has("stock"))
		assert_bool((card.get_node("Look/FarmIcon") as Sprite3D).visible).override_failure_message(each.id).is_equal(UpgradeCard.farms_of(bill) > 0)
		# Right to left from the box's right edge, the leftmost print still in the box.
		var text := UpgradeCard.TITLE_FONT.get_string_size(price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * UpgradeCard.PIXEL
		assert_float(price.position.x + text * 0.5).override_failure_message(each.id).is_equal_approx(UpgradeCard.WIDE_RIGHT - UpgradeCard.WIDE_PAD, 0.0005)
		assert_float(also.position.x).override_failure_message(each.id).is_less(price.position.x)
		var leftmost := also.position.x - UpgradeCard.also_width(also.text, size, UpgradeCard.farms_of(bill))
		assert_float(leftmost).override_failure_message(each.id).is_greater_equal(UpgradeCard.WIDE_LEFT + UpgradeCard.WIDE_PAD - 0.0005)
	assert_int(wide_cards).is_greater(3)


func test_on_wide_paper_the_heading_fits_above_the_box_in_english_and_german() -> void:
	var box_top := 0.047  # The wide box's top edge on the texture.
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for each: Dictionary in UpgradeDesk.CARDS:
			if not UpgradeCard.wide(UpgradeDesk.costs(each)):
				continue
			var shown := TranslationServer.translate(each.title)
			var size := UpgradeCard.fit_size(shown, UpgradeCard.HEADING_SIZE, UpgradeCard.WIDE_HEADING_BOX)
			assert_int(size).override_failure_message("%s: %s" % [locale, shown]).is_greater(UpgradeCard.MIN_SIZE)
			var card: UpgradeCard = auto_free(UpgradeCard.create(each))
			var heading := card.get_node("Look/Heading") as Label3D
			assert_float(heading.position.z + UpgradeCard.WIDE_HEADING_BOX.y * 0.5).override_failure_message(each.id).is_less(box_top)


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
		var card: UpgradeCard = auto_free(UpgradeCard.create(UpgradeDesk.card_data("negotiation")))
		var also := card.get_node("Look/Also") as Label3D
		var count := card.get_node("Look/Farms") as Label3D
		var icon := card.get_node("Look/FarmIcon") as Sprite3D
		assert_bool(count.visible).is_true()
		assert_bool(icon.visible).is_true()
		assert_str(count.text).is_equal("1")
		assert_object(icon.texture).is_same(UpgradeCard.FARM_ICON)
		assert_str(also.text).is_equal("+")  # "1 [farm] +" and the price in its box: no word for farms.
		assert_str((card.get_node("Look/Price") as Label3D).text).is_equal(UpgradeCard.price_text(UpgradeDesk.card_data("negotiation").price, "coins"))
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
		if farms == 0 or bill.size() == 1:
			continue  # Farms alone stand in the price box: test_a_card_that_only_counts_farms_prints_their_count_and_the_farm_icon_in_the_box_and_nothing_else.
		with_farms += 1
		var shown := UpgradeCard.also_text(bill, UpgradeCard.boxed_in(bill, each.get("currency", "coins")))
		assert_bool(shown.begins_with("+")).override_failure_message(each.id).is_true()
		if UpgradeCard.wide(bill):
			continue  # The wide box's row: test_on_wide_paper_every_price_stands_in_the_box_right_to_left_with_its_sign.
		var size := UpgradeCard.also_size(shown, farms)
		assert_int(size).override_failure_message(each.id).is_greater(UpgradeCard.MIN_SIZE)
		assert_float(UpgradeCard.also_width(shown, size, farms)).override_failure_message(each.id).is_less_equal(UpgradeCard.ALSO_WIDTH)
		# The count's left edge is still on the paper.
		var left := UpgradeCard.PRICE_AT.x - UpgradeCard.PRICE_WIDTH * 0.5 - UpgradeCard.ALSO_GAP - UpgradeCard.also_width(shown, size, farms)
		assert_float(left).override_failure_message(each.id).is_greater(-UpgradeCard.SIZE.x * 0.5)
	assert_int(with_farms).is_greater(5)
	# The farms and a second price share the line: sea lanes prints "13 [farm] + $4.000.000 + ¶200.000".
	assert_str(UpgradeCard.also_text(UpgradeDesk.costs(UpgradeDesk.card_data("sea_lanes")), "findings")).is_equal("+ $4M +")


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


func test_the_war_line_from_hostile_acquisitions_on_is_war_cards_and_everything_before_is_not() -> void:
	for id: String in ["war_mode", "world_map", "no_taxes", "sea_lanes", "route_planning", "unit_charge",
			"bigger_armies", "tactics", "unit_senior", "unit_pult", "retreat", "unit_courier", "stars"]:
		assert_bool(UpgradeCard.war_card(UpgradeDesk.card_data(id))).override_failure_message(id).is_true()
	for id: String in ["price_slate", "family_farm", "consolidation", "condense", "bribery", "home_review", "coin_merge"]:
		assert_bool(UpgradeCard.war_card(UpgradeDesk.card_data(id))).override_failure_message(id).is_false()
	assert_bool(UpgradeCard.war_card(UpgradeDesk.NOTICE)).is_false()


func test_war_cards_carry_the_orange_header_and_other_cards_the_green_one() -> void:
	for card: Dictionary in UpgradeDesk.CARDS:
		var paper := UpgradeCard.paper_of(card)
		var is_wide := UpgradeCard.wide(UpgradeDesk.costs(card))
		if card.get("priority", false):
			continue  # The oxblood form, below.
		var expected: StandardMaterial3D
		if UpgradeCard.war_card(card):
			expected = UpgradeCard.WAR_WIDE_MATERIAL if is_wide else UpgradeCard.WAR_MATERIAL
		else:
			expected = UpgradeCard.WIDE_MATERIAL if is_wide else UpgradeCard.MATERIAL
		assert_object(paper).override_failure_message(card.id).is_same(expected)
	# The war's last card is a chapter change: it stays the oxblood form on plain stock.
	var stars := UpgradeCard.paper_of(UpgradeDesk.card_data("stars"))
	assert_object(stars.albedo_color).is_equal(UpgradeCard.PRIORITY_TINT)
	assert_object(stars.albedo_texture).is_not_same(UpgradeCard.WAR_MATERIAL.albedo_texture)
	assert_object(stars.albedo_texture).is_not_same(UpgradeCard.WAR_WIDE_MATERIAL.albedo_texture)


func test_the_orange_header_is_as_muted_as_the_green_one_and_the_dark_body_is_unchanged() -> void:
	var green := UpgradeCard.MATERIAL.albedo_texture.get_image()
	var orange := UpgradeCard.WAR_MATERIAL.albedo_texture.get_image()
	green.decompress()
	orange.decompress()
	var head_green := green.get_pixel(600, 50)
	var head_orange := orange.get_pixel(600, 50)
	assert_float(head_orange.h).is_between(0.04, 0.11)  # Orange, not red or yellow.
	assert_float(head_orange.s).is_less(0.5)  # Muted, never a bright safety orange.
	assert_float(absf(head_orange.v - head_green.v)).is_less(0.15)
	for at: Vector2i in [Vector2i(600, 300), Vector2i(1000, 600)]:
		# Same source pixels; the VRAM compression may round a step apart (editor vs headless import).
		var a := orange.get_pixelv(at)
		var b := green.get_pixelv(at)
		assert_float(Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()).override_failure_message(str(at)).is_less(0.03)
