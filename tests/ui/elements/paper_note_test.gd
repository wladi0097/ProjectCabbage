extends GdUnitTestSuite


func test_an_upgrade_body_opens_with_its_flavour_line_and_then_the_real_description() -> void:
	assert_array(PaperNote.flavour_split("Morale is a deliverable.\nA radio on the desk.")) \
			.is_equal(PackedStringArray(["Morale is a deliverable.", "A radio on the desk."]))
	assert_array(PaperNote.flavour_split("Seed packs cost half.")).is_equal(PackedStringArray(["", "Seed packs cost half."]))


func test_flavour_is_slanted_like_italics() -> void:
	var slanted := PaperNote.italic(PaperNote.BODY_FONT) as FontVariation
	assert_float(slanted.variation_transform.x.y).is_greater(0.0)
	assert_object(PaperNote.italic(PaperNote.BODY_FONT)).is_same(slanted)


func test_the_flavour_line_is_written_in_a_darker_ink_than_the_description() -> void:
	assert_object(PaperNote.line_ink(0, 20)).is_equal(PaperNote.FLAVOUR_INK)
	assert_object(PaperNote.line_ink(20, 20)).is_equal(PaperNote.INK)
	assert_float(PaperNote.FLAVOUR_INK.get_luminance()).is_less(PaperNote.INK.get_luminance())


func test_the_paper_of_a_card_in_several_currencies_prints_every_price_in_a_row() -> void:
	var bill := UpgradeDesk.costs(UpgradeDesk.card_data("consolidation"))
	var each := 0.0
	for paid_in: String in bill:
		each += UpgradeCard.price_width(UpgradeCard.price_text(bill[paid_in], paid_in), paid_in, 34, 1.0)
	assert_float(UpgradeCard.bill_row_width(bill, 34)).is_greater(each)  # All three, with gaps between.
	var paper: PaperNote = auto_free(preload("res://ui/elements/paper_note.tscn").instantiate())
	paper.set_card(UpgradeDesk.card_data("consolidation"))
	assert_dict(paper._bill).is_equal(bill)
	# The row fits the writing's width.
	assert_float(UpgradeCard.bill_row_width(bill, PaperNote.PRICE_SIZE)).is_less((PaperNote.TEXT_RIGHT - PaperNote.TEXT_LEFT) * PaperNote.SCALE)
