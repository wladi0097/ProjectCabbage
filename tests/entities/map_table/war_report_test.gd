extends GdUnitTestSuite

const FA := "field_associate"
const SA := "senior_asset"

var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale)


## A small fight: one cannon, the farmhouse, one zone; two field associates and a senior asset placed, started.
func _fight() -> WarFight:
	var layout := [{kind = "cannon", cell = Vector2i(6, 1)}, {kind = "farmhouse", cell = Vector2i(10, 1), size = Vector2i(2, 2)},
			{kind = "zone", cell = Vector2i(0, 0), size = Vector2i(3, 3)}]
	var fight := WarFight.new(layout, Vector2i(20, 11), 90.0)
	var save := SaveGame.new()
	for unit: String in [FA, FA, SA]:
		fight.place(unit, WarRules.unit_stats(save, unit), 0)
	fight.start()
	return fight


func test_a_lost_or_retreated_war_is_regrettable_however_it_went() -> void:
	assert_str(WarReport.grade_for(false, 0.0, 0.1)).is_equal(WarReport.REGRETTABLE)
	assert_str(WarReport.grade_for(false, 1.0, 1.0)).is_equal(WarReport.REGRETTABLE)


func test_a_win_losing_at_most_a_tenth_of_the_staff_in_a_third_of_the_time_is_exemplary() -> void:
	assert_str(WarReport.grade_for(true, 0.0, 0.15)).is_equal(WarReport.EXEMPLARY)
	assert_str(WarReport.grade_for(true, 0.1, 1.0 / 3.0)).is_equal(WarReport.EXEMPLARY)


func test_any_other_win_is_acceptable() -> void:
	assert_str(WarReport.grade_for(true, 1.0 / 3.0, 0.2)).is_equal(WarReport.ACCEPTABLE)  # The typical win: one of three lost.
	assert_str(WarReport.grade_for(true, 0.0, 0.5)).is_equal(WarReport.ACCEPTABLE)  # Clean, but slow.


func test_the_report_lists_the_staff_lost_per_type_and_the_cabbages_they_cost() -> void:
	var fight := _fight()
	fight.retreat(0.5)  # One of the two associates comes home; the senior asset does not.
	var report := WarReport.summary(fight)
	assert_dict(report.deployed).is_equal({field_associate = 2, senior_asset = 1})
	assert_dict(report.lost).is_equal({field_associate = 1, senior_asset = 1})
	assert_int(report.cabbages).is_equal(WarRules.unit_cabbage_price(FA) + WarRules.unit_cabbage_price(SA))
	assert_that(report.defences).is_equal(Vector2i(0, 1))
	assert_bool(report.retreat).is_true()
	assert_str(report.grade).is_equal(WarReport.REGRETTABLE)

	var form: WarReport = auto_free(load("res://entities/map_table/war_report.tscn").instantiate())
	add_child(form)
	form.fill(&"K-8", "Test Holding", 3000000, report)
	var rows := form.get_node("Page/Form/Staff").get_children().filter(func(n: Node) -> bool: return n.name != "Row")
	assert_array(rows.map(func(n: Node) -> String: return n.get_node("Name").text)).is_equal(["FIELD ASSOCIATE", "SENIOR ASSET"])
	assert_array(rows.map(func(n: Node) -> String: return n.get_node("Lost").text)).is_equal(["1", "1"])
	assert_str(form.get_node("Page/Form/Cabbages").text).is_equal(FarmScreen._thousands(report.cabbages))
	assert_str(form.get_node("Page/Form/Coins").text).is_equal("$3,000,000")
	assert_str(form.get_node("Page/Form/Outcome").text).is_equal("WITHDRAWN")
	assert_str(form.get_node("Page/Form/Defences").text).is_equal("0 of 1")
	assert_array(WarReport.REMARKS["WITHDRAWN"]).contains([form.get_node("Page/Form/Remark").text])


func test_a_won_war_reports_its_time_on_site_of_the_limit_and_comes_home_whole() -> void:
	var fight := _fight()
	fight.tick(90.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)
	var report := WarReport.summary(fight)
	assert_bool(report.won).is_true()
	assert_that(report.defences).is_equal(Vector2i(1, 1))
	var lost := 0
	for unit: String in report.lost:
		lost += int(report.lost[unit])
	assert_int(lost).is_equal(3 - int(fight.survivors().values().reduce(func(a: int, b: int) -> int: return a + b, 0)))
	assert_str(WarReport.clock(65.4)).is_equal("1:05")
	assert_str(WarReport.clock(90.0)).is_equal("1:30")


func test_the_same_war_always_gets_the_same_remark() -> void:
	var report := {grade = WarReport.ACCEPTABLE, retreat = false}
	assert_str(WarReport.remark(report, &"K-6")).is_equal(WarReport.remark(report, &"K-6"))
	assert_array(WarReport.REMARKS[WarReport.ACCEPTABLE]).contains([WarReport.remark(report, &"K-6")])


func test_the_report_is_german_in_german() -> void:
	TranslationServer.set_locale("de")
	var keys: Array = ["FORM 9-R  AFTER-ACTION REPORT", "OUTCOME", "TIME ON SITE", "STAFF", "DEPLOYED", "LOST",
			"CABBAGES WRITTEN OFF", "DEFENCES DECOMMISSIONED", "GRADE AND REMARKS", "FILE REPORT", "%s of %s", "%d of %d",
			WarReport.EXEMPLARY, WarReport.ACCEPTABLE, WarReport.REGRETTABLE]
	for lines: Array in WarReport.REMARKS.values():
		keys.append_array(lines)
	for key: String in keys:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
