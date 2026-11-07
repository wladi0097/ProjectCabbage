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
	var ids := Memo.files_order(save).map(func(m: Dictionary) -> String: return m.id)

	assert_int(ids.size()).is_equal(Memo.MEMOS.size())
	assert_array(ids.slice(0, 4)).is_equal(["units_100", "units_25", "units_10", "units_250"])


func test_a_retired_memo_id_in_an_old_save_is_left_out_of_the_files() -> void:
	var save := SaveGame.new()
	save.milestones = PackedStringArray(["retired_memo", "units_10"])

	assert_dict(Memo.memo("retired_memo")).is_empty()
	assert_int(Memo.files_order(save).size()).is_equal(Memo.MEMOS.size())
	assert_str(Memo.files_order(save)[0].id).is_equal("units_10")


func test_every_memo_has_its_own_id_one_condition_on_the_save_a_felt_bonus_and_all_its_texts() -> void:
	var save := SaveGame.new()
	var ids := Memo.MEMOS.map(func(m: Dictionary) -> String: return m.id)
	for m: Dictionary in Memo.MEMOS:
		var why := "memo %s" % m.id
		assert_int(ids.count(m.id)).override_failure_message(why).is_equal(1)
		assert_int(int(m.has("stat")) + int(m.has("card")) + int(m.has("node"))).override_failure_message(why).is_equal(1)
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


func test_a_memo_unlocks_the_steam_achievement_named_after_its_id_upper_cased() -> void:
	assert_str(preload("res://globalScripts/steam_achievements.gd").api_name("units_25")).is_equal("UNITS_25")


func test_filing_a_memo_without_steam_running_is_safe() -> void:
	assert_bool(Engine.has_singleton("Steam")).is_false()
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
