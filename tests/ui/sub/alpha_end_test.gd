extends GdUnitTestSuite

const Report := preload("res://entities/boss_report/boss_report.gd")

var _real_save: SaveGame
var _demo: bool


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()
	_demo = ProjectSettings.get_setting("game/demo", false)
	ProjectSettings.set_setting("game/demo", false)


func after_test() -> void:
	SaveManager.save = _real_save
	ProjectSettings.set_setting("game/demo", _demo)
	BossReport.up = false


func _capstone_stamped() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm", "consolidation", "market_intelligence", "stars", AlphaEnd.CARD])
	return save


func test_the_alpha_end_comes_only_after_its_card_not_after_the_stars_card() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm", "consolidation", "market_intelligence"])
	assert_bool(Report.Events.chapter_3(save)).is_true()
	assert_bool(AlphaEnd.due(save)).is_false()
	save.stamped.append("stars")
	assert_bool(Report.Events.chapter_3_done(save)).is_true()
	assert_bool(AlphaEnd.due(save)).is_false()  # Chapter 4's nuclear hour comes first.
	assert_bool(AlphaEnd.due(_capstone_stamped())).is_true()


func test_closing_the_alpha_popup_files_it_for_good_and_the_game_runs_on() -> void:
	SaveManager.save = _capstone_stamped()
	var popup: AlphaEnd = auto_free(load("res://ui/sub/alpha_end.tscn").instantiate())
	add_child(popup)
	popup.open()
	assert_bool(popup.visible).is_true()
	assert_bool(get_tree().paused).is_false()
	popup.close()
	assert_bool(popup.visible).is_false()
	assert_bool(BossReport.up).is_false()
	assert_bool(SaveManager.save.alpha_end).is_true()
	assert_bool(AlphaEnd.due(SaveManager.save)).is_false()


func test_the_demo_never_shows_the_alpha_popup() -> void:
	ProjectSettings.set_setting("game/demo", true)
	assert_bool(AlphaEnd.due(_capstone_stamped())).is_false()


func test_the_stars_card_needs_every_farm_in_the_game() -> void:
	var card := UpgradeDesk.card_data("stars")
	assert_int(card.farms).is_equal(Report.Events.FARMS)
	assert_int(Report.Events.FARMS).is_equal(FieldLine.LAMPS)
	assert_bool(card.get("priority", false)).is_true()


## Chapter 4 has no end card for now (it goes on from the telescope): no desk card deals the popup.
func test_no_desk_card_deals_the_alpha_end_while_chapter_4_goes_on_from_the_telescope() -> void:
	assert_dict(UpgradeDesk.card_data(AlphaEnd.CARD)).is_empty()
