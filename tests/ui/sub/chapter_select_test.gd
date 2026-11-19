extends GdUnitTestSuite

const SCENE := preload("res://ui/sub/settings_ui.tscn")
const DebugStarts := preload("res://ui/sub/debug_starts.gd")


func before_test() -> void:
	Profile.clear()


func after_test() -> void:
	Profile.clear()


func _start(index: int) -> SaveGame:
	return ResourceLoader.load(ChapterSelect.STARTS[index], "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame


func _shown_settings() -> Control:
	var menu: Control = auto_free(SCENE.instantiate())
	add_child(menu)
	menu.enable()
	return menu


func test_the_chapter_select_stays_hidden_until_the_game_is_finished() -> void:
	assert_bool(ChapterSelect.is_unlocked()).is_false()
	assert_bool(_shown_settings().get_node("%ChapterSelectRow").visible).is_false()


func test_finishing_the_game_shows_the_chapter_select_in_the_settings() -> void:
	ChapterSelect.unlock()
	assert_bool(_shown_settings().get_node("%ChapterSelectRow").visible).is_true()


func test_the_unlock_survives_loading_a_chapter() -> void:
	ChapterSelect.unlock()
	var kept := SaveManager.save
	SaveManager.save = DebugStarts.prepared(_start(1))  # What a chapter load swaps in.
	assert_bool(ChapterSelect.is_unlocked()).is_true()
	SaveManager.save = SaveGame.new()  # Or a new game.
	assert_bool(ChapterSelect.is_unlocked()).is_true()
	SaveManager.save = kept


func test_the_unlock_survives_a_restart() -> void:
	ChapterSelect.unlock()
	Profile._config = null  # Read back from disk.
	assert_bool(ChapterSelect.is_unlocked()).is_true()


func test_choosing_a_chapter_asks_first_and_cancelling_keeps_the_save() -> void:
	ChapterSelect.unlock()
	var menu := _shown_settings()
	var kept := SaveManager.save
	menu.get_node("%ChapterSelectRow/Chapters/Chapter3").clicked.emit()
	assert_bool(menu.get_node("%ChapterConfirm").visible).is_true()
	assert_int(menu._chapter).is_equal(2)
	menu.get_node("%ChapterConfirm/Panel").cancelled.emit()
	assert_bool(menu.get_node("%ChapterConfirm").visible).is_false()
	assert_object(SaveManager.save).is_same(kept)


func test_there_is_one_start_per_chapter_and_chapter_one_is_a_new_game() -> void:
	assert_int(ChapterSelect.STARTS.size()).is_equal(4)
	assert_str(ChapterSelect.STARTS[0]).is_empty()
	for i in range(1, ChapterSelect.STARTS.size()):
		assert_object(_start(i)).override_failure_message(ChapterSelect.STARTS[i]).is_not_null()


func test_chapter_two_starts_with_the_family_farm_card_on_offer() -> void:
	var save := _start(1)
	assert_bool(save.supply_warning).is_true()
	assert_bool(save.stamped.has("family_farm")).is_false()
	assert_bool(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save).has("family_farm")).is_true()


func test_chapter_three_starts_on_the_promotion_paper() -> void:
	var save := _start(2)
	assert_bool(UpgradeDesk.Events.chapter_3(save)).is_true()
	assert_array(BossReport.due(save)).is_equal(["invest_in_growth"])
	assert_int(save.farms_owned.size()).is_equal(0)


func test_chapter_four_starts_with_the_stars_card_ready_to_stamp() -> void:
	var save := _start(3)
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["stars"])
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(UpgradeDesk.card_data("stars")))).is_true()
	assert_bool(UpgradeDesk.Events.chapter_3_done(save)).is_false()


func test_no_chapter_start_carries_a_playtest_log() -> void:
	for i in range(1, ChapterSelect.STARTS.size()):
		assert_array(_start(i).playtest_log).override_failure_message(ChapterSelect.STARTS[i]).is_empty()


func test_the_chapter_starts_ship_in_the_export_and_the_debug_starts_do_not() -> void:
	var presets := ConfigFile.new()
	assert_int(presets.load("res://export_presets.cfg")).is_equal(OK)
	var include: String = presets.get_value("preset.0", "include_filter")
	var exclude: String = presets.get_value("preset.0", "exclude_filter")
	assert_str(include).contains("ressources/save/chapter_starts/*")
	assert_str(exclude).not_contains("chapter_starts")
	assert_str(exclude).contains("ressources/save/debug_starts/*")
	for path: String in ChapterSelect.STARTS:
		assert_bool(path.contains("debug_starts")).is_false()

