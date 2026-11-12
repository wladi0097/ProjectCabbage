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
	save.stamped = PackedStringArray(["family_farm", "consolidation"])
	return save


func test_the_alpha_thanks_the_player_once_the_chapter_two_capstone_is_stamped_and_not_before() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["family_farm", "standing_seed_order"])
	assert_bool(AlphaEnd.due(save)).is_false()
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


func test_for_the_alpha_the_chapter_three_paper_is_held_back_but_its_event_still_starts() -> void:
	var save := _capstone_stamped()
	save.reports = PackedStringArray(["welcome"])
	assert_bool(Report.Events.chapter_3(save)).is_true()
	assert_array(Report.due(save)).not_contains(["invest_in_growth"])
