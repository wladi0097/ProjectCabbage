extends GdUnitTestSuite

const Memo := preload("res://entities/milestone/milestone_memo.gd")
const ORIGINAL_BONUS_IDS := ["units_25", "units_100", "units_250", "units_1000", "units_2500", "units_10000"]


func _file_all(save: SaveGame) -> PackedStringArray:
	var order := PackedStringArray()
	while not Memo.due(save).is_empty():
		var m := Memo.due(save)
		order.append(m.id)
		Memo.apply(save, m)
	return order


func test_a_fresh_save_has_no_memo_due() -> void:
	assert_dict(Memo.due(SaveGame.new())).is_empty()


func test_the_first_memo_comes_at_exactly_10_units_sold() -> void:
	var save := SaveGame.new()
	save.sold = 9
	assert_dict(Memo.due(save)).is_empty()

	save.sold = 10
	assert_str(Memo.due(save).id).is_equal("units_10")


func test_thresholds_passed_at_once_are_filed_one_after_the_other_in_order() -> void:
	var save := SaveGame.new()
	save.sold = 120
	assert_array(Array(_file_all(save))).is_equal(["units_10", "units_25", "units_100"])


func test_a_filed_memo_is_never_due_again_and_its_bonus_applies_once() -> void:
	var save := SaveGame.new()
	save.sold = 120
	_file_all(save)
	_file_all(save)

	assert_float(save.marketing).is_equal_approx(1.25, 0.0001)
	assert_int(save.findings_per_cabbage).is_equal(2)
	assert_int(save.milestones.size()).is_equal(3)


func test_a_memo_bonus_multiplies_so_it_stacks_with_upgrades() -> void:
	var save := SaveGame.new()
	save.marketing = 1.2
	Memo.apply(save, Memo.memo("units_25"))
	assert_float(save.marketing).is_equal_approx(1.5, 0.0001)


func test_a_bonus_on_a_whole_number_keeps_it_whole() -> void:
	var save := SaveGame.new()
	Memo.apply(save, Memo.memo("units_100"))
	assert_int(typeof(save.findings_per_cabbage)).is_equal(TYPE_INT)
	assert_int(save.findings_per_cabbage).is_equal(2)


func test_a_memo_without_a_bonus_only_files_itself() -> void:
	var save := SaveGame.new()
	var fresh := SaveGame.new()
	Memo.apply(save, Memo.memo("units_10"))

	assert_array(Array(save.milestones)).is_equal(["units_10"])
	assert_float(save.marketing).is_equal(fresh.marketing)
	assert_int(save.findings_per_cabbage).is_equal(fresh.findings_per_cabbage)


func test_coin_memos_count_coins_on_hand() -> void:
	var save := SaveGame.new()
	save.coins = 999
	assert_bool(Memo.met(save, Memo.memo("coins_1000"))).is_false()

	save.coins = 1000
	assert_bool(Memo.met(save, Memo.memo("coins_1000"))).is_true()


func test_memos_can_wait_on_a_stat_a_stamped_card_or_a_bought_projector_node() -> void:
	var save := SaveGame.new()
	for id in ["lever_split", "research_directive", "double_findings"]:
		assert_bool(Memo.met(save, Memo.memo(id))).is_false()

	save.tube_split = 0.5
	save.stamped.append("research_inspection")
	save.tree_bought.append("double_findings")
	for id in ["lever_split", "research_directive", "double_findings"]:
		assert_bool(Memo.met(save, Memo.memo(id))).override_failure_message("%s should be met" % id).is_true()


func test_inbox_zero_needs_every_desk_card_stamped() -> void:
	var save := SaveGame.new()
	for card: Dictionary in UpgradeDesk.CARDS.slice(0, -1):
		save.stamped.append(card.id)
	assert_bool(Memo.met(save, Memo.memo("every_card"))).is_false()

	save.stamped.append(UpgradeDesk.CARDS[-1].id)
	assert_bool(Memo.met(save, Memo.memo("every_card"))).is_true()


func test_the_files_list_the_filed_memos_newest_first_then_the_rest_in_order() -> void:
	var save := SaveGame.new()
	save.sold = 120
	_file_all(save)
	var ids := Memo.files_order(save.milestones).map(func(m: Dictionary) -> String: return m.id)

	assert_int(ids.size()).is_equal(Memo.MEMOS.size())
	assert_array(ids.slice(0, 4)).is_equal(["units_100", "units_25", "units_10", "units_250"])


func test_a_retired_memo_id_in_an_old_save_is_left_out_of_the_files() -> void:
	var save := SaveGame.new()
	save.milestones = PackedStringArray(["retired_memo", "units_10"])

	assert_dict(Memo.memo("retired_memo")).is_empty()
	assert_int(Memo.files_order(save.milestones).size()).is_equal(Memo.MEMOS.size())
	assert_str(Memo.files_order(save.milestones)[0].id).is_equal("units_10")


func test_every_memo_has_its_own_id_one_condition_on_the_save_a_felt_bonus_and_all_its_texts() -> void:
	var save := SaveGame.new()
	var ids := Memo.MEMOS.map(func(m: Dictionary) -> String: return m.id)
	for m: Dictionary in Memo.MEMOS:
		var why := "memo %s" % m.id
		assert_int(ids.count(m.id)).override_failure_message(why).is_equal(1)
		assert_int(int(m.has("stat")) + int(m.has("card")) + int(m.has("node")) + int(m.has("hook"))).override_failure_message(why).is_equal(1)
		if m.has("stat"):
			assert_bool(m.stat in save).override_failure_message(why).is_true()
		if m.has("key"):
			assert_bool(m.key in save and m.has("bonus")).override_failure_message(why).is_true()
			assert_float(float(m.mul)).override_failure_message(why).is_greater_equal(1.25)
		for text in ["re", "how", "note", "icon"]:
			assert_bool(m.has(text)).override_failure_message("%s lacks %s" % [why, text]).is_true()


func test_the_six_original_memos_keep_their_bonus_so_old_saves_never_get_it_twice() -> void:
	for id: String in ORIGINAL_BONUS_IDS:
		assert_bool(Memo.memo(id).has("key")).override_failure_message(id).is_true()


func test_the_street_pays_double_from_8500_cabbages_sold_under_its_old_id() -> void:
	var save := SaveGame.new()
	save.milestones = PackedStringArray(["units_10", "units_25", "units_100", "units_250", "units_1000", "units_2500"])
	save.sold = 8499
	assert_dict(Memo.due(save)).is_empty()
	save.sold = 8500
	assert_str(Memo.due(save).id).is_equal("units_10000")
	var street := save.marketing
	Memo.apply(save, Memo.due(save))
	assert_float(save.marketing).is_equal_approx(street * 2.0, 0.0001)


func test_a_memo_unlocks_the_steam_achievement_named_after_its_id_upper_cased() -> void:
	assert_str(preload("res://globalScripts/steam_achievements.gd").api_name("units_25")).is_equal("UNITS_25")


func test_filing_a_memo_without_steam_running_is_safe() -> void:
	assert_object(SteamAchievements.steam).is_null()
	SteamAchievements.unlock("units_25")


func test_the_memo_slides_up_over_its_in_time() -> void:
	assert_float(Memo.slide_at(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(Memo.slide_at(Memo.IN_TIME)).is_equal_approx(1.0, 0.0001)


func test_the_memo_flies_from_rest_bowing_upward_into_the_folder() -> void:
	var from := Vector2(960, 900)
	var to := Vector2(1850, 1030)
	var mid := Memo.fly_at(0.5, from, to)

	assert_vector(Memo.fly_at(0.0, from, to)).is_equal_approx(from, Vector2.ONE * 0.001)
	assert_vector(Memo.fly_at(1.0, from, to)).is_equal_approx(to, Vector2.ONE * 0.001)
	assert_float(mid.y).is_less(from.y)
	assert_float(mid.x).is_between(from.x, to.x)


func test_the_folder_glow_pulses_while_it_lasts_fades_in_its_last_second_and_is_off_after() -> void:
	assert_float(Memo.glow_at(0.0, 3.0)).is_equal(0.0)
	assert_float(Memo.glow_at(-1.0, 3.0)).is_equal(0.0)
	assert_float(Memo.glow_at(Memo.GLOW_TIME, 3.0)).is_between(0.2, 1.0)
	assert_float(Memo.glow_at(0.5, 0.0)).is_less(Memo.glow_at(5.0, 0.0))


func test_esc_closes_the_open_files_before_the_pause_menu_can_take_it() -> void:
	var memo: CanvasLayer = auto_free(load("res://entities/milestone/milestone_memo.tscn").instantiate())
	add_child(memo)
	memo._files.visible = true
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	memo._input(esc)  # _input runs before any _unhandled_input, so the menu never sees this Esc.
	assert_bool(memo._files.visible).is_false()
	assert_bool(get_viewport().is_input_handled()).is_true()


func test_the_files_show_the_signed_boss_reports_newest_first() -> void:
	var save := SaveGame.new()
	save.reports = PackedStringArray(["welcome", "retired_report", "mood_drift"])
	assert_array(Memo.reports_order(save)).is_equal(["mood_drift", "welcome"])


func test_the_files_open_on_the_memos_and_the_boss_notes_tab_shows_only_the_boss_notes() -> void:
	var memo: CanvasLayer = auto_free(load("res://entities/milestone/milestone_memo.tscn").instantiate())
	add_child(memo)
	memo._open_files()
	assert_bool(memo._grid.visible).is_true()
	assert_bool(memo._reports.visible).is_false()
	memo._boss_tab.button_pressed = true
	assert_bool(memo._reports.visible).is_true()
	assert_bool(memo._grid.visible).is_false()


func test_filed_memos_stay_filed_after_a_new_game() -> void:
	Profile.clear()
	var save := SaveGame.new()
	save.sold = 30
	while not Memo.due(save).is_empty():
		var m := Memo.due(save)
		Memo.apply(save, m)
		Profile.file(PackedStringArray([m.id]))
	var fresh := SaveGame.new()  # A new game, or a chapter loaded.
	assert_array(Array(fresh.milestones)).is_empty()
	assert_array(Array(Profile.filed())).is_equal(["units_10", "units_25"])
	assert_str(Memo.files_order(Profile.filed())[0].id).is_equal("units_25")
	# Read back from disk, as on the next start.
	Profile._config = null
	assert_array(Array(Profile.filed())).is_equal(["units_10", "units_25"])
	Profile.clear()


func test_a_new_game_with_filed_memos_starts_with_the_folder_on_the_desk() -> void:
	Profile.clear()
	var kept := SaveManager.save
	SaveManager.save = SaveGame.new()
	Profile.file(PackedStringArray(["units_10"]))
	var memo: CanvasLayer = auto_free(load("res://entities/milestone/milestone_memo.tscn").instantiate())
	add_child(memo)
	await await_idle_frame()
	assert_bool(memo._folder.visible).is_true()
	# The folder's introduction, the first memo's paper, never comes again: nothing is queued.
	assert_array(memo._queue).is_empty()
	SaveManager.save = kept
	Profile.clear()


func test_a_new_game_with_no_memo_ever_filed_has_no_folder_yet() -> void:
	Profile.clear()
	var kept := SaveManager.save
	SaveManager.save = SaveGame.new()
	var memo: CanvasLayer = auto_free(load("res://entities/milestone/milestone_memo.tscn").instantiate())
	add_child(memo)
	await await_idle_frame()
	assert_bool(memo._folder.visible).is_false()
	SaveManager.save = kept
	Profile.clear()


func test_a_memo_bonus_still_waits_for_the_new_run_to_earn_it() -> void:
	Profile.clear()
	Profile.file(PackedStringArray(["units_10", "units_25"]))
	var save := SaveGame.new()
	save.sold = 24
	assert_dict(Memo.due(save)).is_not_empty()  # units_10: filed already, earned again quietly.
	Memo.apply(save, Memo.due(save))
	assert_dict(Memo.due(save)).is_empty()
	assert_float(save.marketing).is_equal_approx(1.0, 0.0001)
	save.sold = 25
	Memo.apply(save, Memo.due(save))
	assert_float(save.marketing).is_equal_approx(1.25, 0.0001)
	Profile.clear()


func test_a_replayed_memo_comes_quietly_and_only_a_bonus_gets_a_short_paper() -> void:
	Profile.clear()
	Profile.file(PackedStringArray(["units_10", "units_25"]))
	Profile.write("files", "migrated", true)
	var kept := SaveManager.save
	SaveManager.save = SaveGame.new()
	var memo: CanvasLayer = auto_free(load("res://entities/milestone/milestone_memo.tscn").instantiate())
	add_child(memo)
	SaveManager.save.sold = 25
	memo._file_due(true)
	assert_int(memo._queue.size()).is_equal(1)
	assert_str(memo._queue[0].id).is_equal("units_25")
	assert_float(memo._queue[0].hold).is_equal(Memo.SHORT_HOLD)
	assert_float(SaveManager.save.marketing).is_equal_approx(1.25, 0.0001)
	SaveManager.save = kept
	Profile.clear()


func test_an_old_saves_filed_memos_move_into_the_profile_once() -> void:
	Profile.clear()
	Profile.migrate(PackedStringArray(["units_10", "catches_1"]))
	assert_array(Array(Profile.filed())).is_equal(["units_10", "catches_1"])
	# Later saves (a chapter loaded) bring their own list: it is the run's, not the record's.
	Profile.migrate(PackedStringArray(["units_100"]))
	assert_array(Array(Profile.filed())).is_equal(["units_10", "catches_1"])
	Profile.clear()


func test_an_already_unlocked_memo_still_gives_its_bonus_in_a_new_run() -> void:
	Profile.clear()
	Profile.file(PackedStringArray(["units_10", "units_25", "units_100"]))  # All unlocked before.
	var save := SaveGame.new()  # The new run.
	save.sold = 100
	_file_all(save)
	assert_float(save.marketing).is_equal_approx(1.25, 0.0001)
	assert_int(save.findings_per_cabbage).is_equal(2)
	assert_array(Array(Profile.filed())).is_equal(["units_10", "units_25", "units_100"])
	Profile.clear()


func test_the_memos_tab_counts_the_achievements_filed_of_all_of_them() -> void:
	var filed := PackedStringArray(["units_10", "retired_memo", "closing", "units_25"])
	assert_int(Memo.filed_count(filed)).is_equal(2)  # Retired ids and posted papers never count.
	assert_str(Memo.memos_tab_text("AKTENNOTIZEN", filed)).is_equal("AKTENNOTIZEN  2 / %d" % Memo.MEMOS.size())


func test_opening_the_files_shows_the_profiles_count_on_the_memos_tab() -> void:
	Profile.clear()
	Profile.file(PackedStringArray(["units_10", "catches_1", "coins_1000"]))
	var memo: CanvasLayer = auto_free(load("res://entities/milestone/milestone_memo.tscn").instantiate())
	add_child(memo)
	memo._open_files()
	assert_str(memo._memos_tab.text).ends_with("  3 / %d" % Memo.MEMOS.size())
	Profile.clear()


func test_a_chapter_3_memo_shows_as_a_question_mark_until_chapter_3_is_reached() -> void:
	var m := {id = "some_chapter_3_memo", chapter = 3}
	assert_bool(Memo.hidden(m, PackedStringArray(), 2)).is_true()
	assert_bool(Memo.hidden(m, PackedStringArray(), 3)).is_false()
	assert_bool(Memo.hidden(m, PackedStringArray(["some_chapter_3_memo"]), 1)).is_false()  # Filed: never hidden.
	assert_bool(Memo.hidden({id = "plain"}, PackedStringArray(), 1)).is_false()  # No chapter: chapter 1.


func test_every_chapter_2_farm_memo_is_hidden_at_the_start() -> void:
	for id in ["harvest_1", "golden_1", "promotion", "chapter_2"]:
		assert_bool(Memo.hidden(Memo.memo(id), PackedStringArray(), 1)).override_failure_message(id).is_true()


func test_the_chapter_is_reached_at_the_farm_the_consolidation_the_stars_and_the_gun() -> void:
	var save := SaveGame.new()
	assert_int(Memo.chapter_of(save)).is_equal(1)
	for step: Array in [["family_farm", 2], ["consolidation", 3], ["stars", 4], [Memo.Events.GUN_CARD, 5]]:
		save.stamped.append(step[0])
		assert_int(Memo.chapter_of(save)).override_failure_message(step[0]).is_equal(step[1])


func test_reaching_a_chapter_is_kept_across_a_new_game() -> void:
	Profile.clear()
	assert_int(Profile.reached()).is_equal(1)
	Profile.reach(3)
	Profile.reach(2)  # Never back down: a new game starts in chapter 1 again.
	SaveGame.new()
	Profile._config = null  # Read back from disk, as on the next start.
	assert_int(Profile.reached()).is_equal(3)
	Profile.clear()


func test_a_profile_with_the_chapter_select_unlocked_has_seen_every_chapter() -> void:
	Profile.clear()
	Profile.write("chapter_select", "unlocked", true)
	assert_int(Profile.reached()).is_equal(5)
	Profile.clear()


func test_each_chapter_entered_files_its_memo() -> void:
	var save := SaveGame.new()
	for step: Array in [["family_farm", "chapter_2"], ["consolidation", "chapter_3"], ["stars", "chapter_4"], [Memo.Events.GUN_CARD, "chapter_5"]]:
		assert_bool(Memo.met(save, Memo.memo(step[1]))).override_failure_message(step[1]).is_false()
		save.stamped.append(step[0])
		assert_bool(Memo.met(save, Memo.memo(step[1]))).override_failure_message(step[1]).is_true()


func test_a_hook_memo_is_never_due_from_the_save() -> void:
	var save := SaveGame.new()
	save.stamped.append(Memo.Events.GUN_CARD)
	for m: Dictionary in Memo.MEMOS:
		if m.has("hook"):
			assert_bool(Memo.met(save, m)).override_failure_message(m.id).is_false()


func test_finishing_the_game_files_its_memo() -> void:
	Profile.clear()
	Memo.file_ending(3, 5.0)
	assert_array(Array(Profile.filed())).is_equal(["game_end"])
	Profile.clear()


func test_the_ending_files_its_misses_its_clean_run_and_a_long_wait() -> void:
	assert_array(Array(Memo.ending_memos(Memo.END_MISSES, 1.0))).is_equal(["game_end", "end_misses"])
	assert_array(Array(Memo.ending_memos(0, Memo.END_HOLD))).is_equal(["game_end", "end_marksman", "end_hold"])
	assert_array(Array(Memo.ending_memos(1, Memo.END_HOLD - 1.0))).is_equal(["game_end"])


func test_notifying_a_memo_twice_files_it_once() -> void:
	Profile.clear()
	Memo.notify("end_radio_first")
	Memo.notify("end_radio_first")
	assert_array(Array(Profile.filed())).is_equal(["end_radio_first"])
	Profile.clear()


## The memos of chapter 3 (the map table, the farms, the war), in MEMOS order.
const CHAPTER_3 := ["farms_1", "farms_12", "floor_price", "insults_5", "no_taxes", "wars_won_1", "wars_won_10",
		"wars_lost_1", "war_exemplary", "annexed_1", "annexed_4", "war_skeleton_crew", "war_associates_only",
		"war_quick_retreat", "war_lost_untouched", "condense_32", "merge_10k"]


func test_the_first_and_the_twelfth_farm_owned_each_file_a_memo() -> void:
	var save := SaveGame.new()
	save.farms_owned = PackedStringArray(["K-1"])
	assert_bool(Memo.met(save, Memo.memo("farms_1"))).is_true()
	assert_bool(Memo.met(save, Memo.memo("farms_12"))).is_false()
	for n in 11:
		save.farms_owned.append("x-%d" % n)
	assert_bool(Memo.met(save, Memo.memo("farms_12"))).is_true()


func test_winning_a_war_with_a_single_figure_files_its_memo() -> void:
	var save := SaveGame.new()
	save.solo_wins = 1
	save.wars_won = 1
	assert_array(Array(_file_all(save))).contains(["wars_won_1", "war_skeleton_crew"])


func test_every_chapter_3_memo_is_hidden_until_chapter_3_and_gives_no_bonus() -> void:
	for id: String in CHAPTER_3:
		var m := Memo.memo(id)
		assert_int(int(m.get("chapter", 0))).override_failure_message(id).is_equal(3)
		assert_bool(m.has("key")).override_failure_message(id).is_false()



func test_every_memo_can_be_checked_on_a_fresh_save_whatever_its_condition() -> void:
	var save := SaveGame.new()
	for m: Dictionary in Memo.MEMOS:  # A hook memo or any new condition kind must not read a missing key.
		assert_bool(Memo.met(save, m)).override_failure_message(m.id).is_false()
	assert_dict(Memo.due(save)).is_empty()
	for m: Dictionary in Memo.MEMOS:
		assert_bool(Memo.hidden(m, PackedStringArray(), 1)).override_failure_message(m.id).is_equal(m.get("chapter", 1) > 1)
