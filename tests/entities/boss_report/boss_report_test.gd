extends GdUnitTestSuite

const Report := preload("res://entities/boss_report/boss_report.gd")
const Events := preload("res://globalScripts/game_events.gd")

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func test_a_new_game_opens_with_the_welcome_report_alone() -> void:
	assert_array(Report.due(SaveGame.new())).is_equal(["welcome"])


func test_a_filed_report_never_comes_again() -> void:
	var save := SaveGame.new()
	save.reports.append("welcome")
	assert_array(Report.due(save)).is_empty()
	save.buy_unlocked = true
	save.reports.append("pack_pressure")
	assert_array(Report.due(save)).is_empty()


func test_a_report_comes_for_each_started_event_in_event_order_after_the_welcome() -> void:
	var save := SaveGame.new()
	save.supply_warning = true
	save.supply_shock = true
	save.stamped.append("family_farm")
	save.buy_unlocked = true
	save.slate_unlocked = true
	assert_array(Report.due(save)).is_equal(["welcome", "mood_drift", "pack_pressure", "supply_warning", "supply_shock", "supply_squeeze"])


func test_the_supply_shock_report_comes_with_the_shock_and_the_squeeze_report_with_the_farm() -> void:
	var save := SaveGame.new()
	save.reports.append("welcome")
	save.supply_warning = true
	assert_array(Report.due(save)).is_equal(["supply_warning"])
	save.reports.append("supply_warning")
	save.supply_shock = true
	assert_array(Report.due(save)).is_equal(["supply_shock"])
	save.reports.append("supply_shock")
	save.stamped.append("family_farm")
	assert_array(Report.due(save)).is_equal(["supply_squeeze"])


func test_every_event_has_a_report_with_a_headline_and_a_body() -> void:
	for id: String in Events.EVENTS:
		var report := Report.report(id)
		assert_str(report.re).is_not_empty()
		assert_str(report.body).is_not_empty()


func test_no_report_carries_a_stamp() -> void:
	for id: String in ["welcome", "demo_end"] + Events.EVENTS.keys():
		assert_bool(Report.report(id).has("stamp")).is_false()


func test_the_demo_end_report_has_buttons_instead_of_a_signature() -> void:
	assert_bool(Report.report("demo_end").get("buttons", false)).is_true()
	assert_bool(Report.report("welcome").get("buttons", false)).is_false()


func test_ink_is_the_length_of_the_stroke() -> void:
	assert_float(Report.ink_of(PackedVector2Array([Vector2(0, 0), Vector2(3, 4), Vector2(3, 10)]))).is_equal_approx(11.0, 0.0001)
	assert_float(Report.ink_of(PackedVector2Array([Vector2(5, 5)]))).is_equal(0.0)


func test_one_stroke_across_the_signature_field_is_enough_ink_to_sign() -> void:
	assert_float(Report.SIGN_BOX.grow(-4.0).size.x).is_greater(Report.SIGN_INK)


func test_the_ok_and_wishlist_buttons_lie_clear_of_the_signature_field_and_each_other() -> void:
	assert_bool(Report.OK_BOX.intersects(Report.SIGN_BOX)).is_false()
	assert_bool(Report.OK_BOX.intersects(Report.WISH_BOX)).is_false()
	assert_bool(Rect2(Vector2.ZERO, Report.SIZE).encloses(Report.OK_BOX)).is_true()
	assert_bool(Rect2(Vector2.ZERO, Report.SIZE).encloses(Report.SIGN_BOX)).is_true()


func test_every_report_text_fits_its_paper_in_english_and_german() -> void:
	var ids: Array = ["welcome", "demo_end"] + Events.EVENTS.keys()
	for lang in ["en", "de"]:
		TranslationServer.set_locale(lang)
		for id: String in ids:
			var fit := Report.layout(Report.report(id))
			assert_bool(fit.fits).override_failure_message("%s report '%s' overflows: %s" % [lang, id, fit]).is_true()
			assert_int(fit.body).is_greater_equal(Report.BODY_MIN)


func test_a_farm_bought_before_the_shock_gets_the_squeeze_report_only_with_the_shock() -> void:
	var save := SaveGame.new()
	save.reports = PackedStringArray(["welcome", "supply_warning"])
	save.supply_warning = true
	save.stamped.append("family_farm")
	assert_array(Report.due(save)).is_empty()
	save.supply_shock = true
	assert_array(Report.due(save)).is_equal(["supply_shock", "supply_squeeze"])
