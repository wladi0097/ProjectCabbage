extends GdUnitTestSuite

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func _letter(what := "stock", have := 30000) -> NegotiationLetter:
	var letter: NegotiationLetter = auto_free(load("res://entities/map_table/negotiation_letter.tscn").instantiate())
	add_child(letter)
	letter.print_letter(what, 25 if what == "stock" else 100000, "A. Krautmann", {coins = 200000, stock = 2000}, [], 5, have, "Cabbages offered are not returned.")
	return letter


func _on_pile(letter: NegotiationLetter) -> Array[Node]:
	return letter.get_node("Bundles").get_children().filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())


func _settle(letter: NegotiationLetter) -> void:
	for bundle in letter.get_node("Bundles").get_children():
		for tween in (bundle as Node).get_tree().get_processed_tweens():
			tween.custom_step(10.0)


func test_a_bundle_let_go_on_the_offer_lies_there_and_one_let_go_elsewhere_goes_back() -> void:
	var letter := _letter()
	assert_bool(letter.grab(NegotiationLetter.CRATE_BOX.get_center())).is_true()
	letter.drag_to(NegotiationLetter.PILE_BOX.get_center())
	assert_bool(letter.drop(true)).is_true()
	assert_int(letter.count).is_equal(1)
	assert_int(letter.offered()).is_equal(25)
	assert_bool(letter.grab(NegotiationLetter.CRATE_BOX.get_center())).is_true()
	letter.drag_to(NegotiationLetter.RETURN_BOX.get_center())
	assert_bool(letter.drop(false)).is_false()
	assert_int(letter.count).is_equal(1)
	_settle(letter)
	assert_int(_on_pile(letter).size()).is_equal(1)  # The one let go elsewhere is back in the crate.


func test_a_click_on_the_crate_lays_a_bundle_on_the_offer() -> void:
	var letter := _letter()
	letter.grab(NegotiationLetter.CRATE_BOX.get_center())
	assert_bool(letter.drop(false)).is_true()  # It hardly moved: a click.
	assert_int(letter.count).is_equal(1)


func test_taking_a_cabbage_back_off_the_paper_lowers_the_offer() -> void:
	var letter := _letter()
	for i in 3:
		letter.grab(NegotiationLetter.CRATE_BOX.get_center())
		letter.drop(true)
	assert_str((letter.get_node("Page/Form/Pile/Total") as Label).text).is_equal("75 cabbages")
	letter.take_back(NegotiationLetter.pile_place(0))
	assert_int(letter.count).is_equal(2)
	assert_int(letter.offered()).is_equal(50)
	assert_str((letter.get_node("Page/Form/Pile/Total") as Label).text).is_equal("50 cabbages")
	_settle(letter)
	var places := _on_pile(letter).map(func(b: Node3D) -> Vector2: return Vector2(b.position.x, b.position.z) * NegotiationLetter.PIXELS_PER_METRE)
	assert_array(places).contains_exactly_in_any_order([NegotiationLetter.pile_place(0), NegotiationLetter.pile_place(1)])  # The rest close up.


func test_the_offer_takes_no_more_than_its_room() -> void:
	var letter := _letter()
	for i in NegotiationLetter.MOST:
		assert_bool(letter.grab(NegotiationLetter.CRATE_BOX.get_center())).is_true()
		letter.drop(true)
	assert_bool(letter.grab(NegotiationLetter.CRATE_BOX.get_center())).is_false()
	assert_int(letter.count).is_equal(NegotiationLetter.MOST)


func test_sending_carries_the_pile_off_the_paper() -> void:
	var letter := _letter()
	for i in 2:
		letter.grab(NegotiationLetter.CRATE_BOX.get_center())
		letter.drop(true)
	letter.send(0.6, 0.3)
	assert_int(letter.count).is_equal(0)
	assert_bool((letter.get_node("Slide") as SoundCue).playing).is_true()
	_settle(letter)
	assert_array(_on_pile(letter)).is_empty()


func test_the_crate_shows_what_stock_is_left_for() -> void:
	var letter := _letter("stock", 60)  # Two bundles' worth.
	var shown := letter.get_node("Crate/Bundles").get_children().filter(func(b: Node3D) -> bool: return b.visible)
	assert_int(shown.size()).is_equal(2)
	letter.grab(NegotiationLetter.CRATE_BOX.get_center())
	letter.drop(true)
	shown = letter.get_node("Crate/Bundles").get_children().filter(func(b: Node3D) -> bool: return b.visible)
	assert_int(shown.size()).is_equal(1)


func test_a_bribe_is_laid_out_in_coin_stacks() -> void:
	var letter := _letter("coins", 6000000)
	letter.grab(NegotiationLetter.CRATE_BOX.get_center())
	letter.drop(true)
	assert_bool((_on_pile(letter)[0] as OfferBundle).coins).is_true()
	assert_str((letter.get_node("Page/Form/Pile/Total") as Label).text).is_equal("$100K")
	assert_bool((letter.get_node("Clink") as SoundCue).playing).is_true()
