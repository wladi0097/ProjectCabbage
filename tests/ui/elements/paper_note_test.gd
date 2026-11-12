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
