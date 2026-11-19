extends GdUnitTestSuite

const DebugStarts := preload("res://ui/sub/debug_starts.gd")


func _key(physical: Key, keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = physical
	key.keycode = keycode
	key.pressed = true
	return key


func test_the_key_left_of_one_opens_the_start_points_on_any_layout() -> void:
	assert_bool(DebugStarts.is_toggle(_key(KEY_QUOTELEFT, KEY_NONE))).is_true()
	assert_bool(DebugStarts.is_toggle(_key(KEY_NONE, KEY_ASCIICIRCUM))).is_true()
	assert_bool(DebugStarts.is_toggle(_key(KEY_1, KEY_1))).is_false()


func test_start_points_are_listed_in_file_name_order() -> void:
	var list := DebugStarts.entries()
	assert_int(list.size()).is_greater(0)
	var sorted := list.duplicate()
	sorted.sort()
	assert_array(Array(list)).is_equal(Array(sorted))


func test_every_prepared_start_point_still_loads_as_a_save() -> void:
	for path in DebugStarts.entries():
		var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
		assert_object(save).override_failure_message("%s does not load" % path).is_not_null()


func test_a_start_points_label_keeps_its_number_and_reads_as_words() -> void:
	assert_str(DebugStarts.label_of("res://x/20_farm_just_bought.tres")).is_equal("20  Farm Just Bought")
	assert_str(DebugStarts.label_of("res://x/late_game.tres")).is_equal("Late Game")


func test_a_typed_name_becomes_a_safe_file_name() -> void:
	assert_str(DebugStarts.stem_for("  30 Farm CH2!/.. ")).is_equal("30_farm_ch2")


func test_a_saved_start_point_drops_the_playtest_log_but_keeps_the_rest() -> void:
	var save := SaveGame.new()
	save.coins = 1234
	save.playtest_log = [{kind = "snapshot"}]
	var copy := DebugStarts.prepared(save)
	assert_int(copy.coins).is_equal(1234)
	assert_array(copy.playtest_log).is_empty()
	assert_array(save.playtest_log).has_size(1)


func test_the_consolidated_growth_start_point_is_the_moment_chapter_3_opens() -> void:
	var path := DebugStarts.START_DIR.path_join("50_consolidated_growth_bought.tres")
	assert_array(Array(DebugStarts.entries())).contains([path])
	assert_str(DebugStarts.label_of(path)).is_equal("50  Consolidated Growth Bought")
	var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	var card := UpgradeDesk.card_data("consolidation")
	assert_bool(save.stamped.has("consolidation")).is_true()
	assert_bool(UpgradeDesk.Events.chapter_3(save)).is_true()
	assert_bool(MapTable.unlocked(save)).is_true()
	# Everything the card waits for is there: its cards, and storage for the cabbages it costs.
	for need: String in card.needs:
		assert_bool(save.stamped.has(need)).override_failure_message("%s is not stamped" % need).is_true()
	assert_int(save.storage_cap).is_greater_equal(int(card.price))
	assert_bool(save.tree_bought.has("stock_2000")).is_true()
	assert_bool(FarmTv.bought(save)).is_true()
	# Just paid: what is left of each currency is less than the card took, and fits the store.
	assert_int(save.stock).is_less_equal(save.storage_cap - int(card.price))
	assert_int(save.coins).is_less(int(card.also.coins))
	assert_int(save.findings).is_less(int(card.also.findings))


func test_the_consolidated_growth_start_point_opens_on_the_promotion_paper_alone_with_chapter_threes_first_card_in_the_tray() -> void:
	var path := DebugStarts.START_DIR.path_join("50_consolidated_growth_bought.tres")
	var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_array(BossReport.due(save)).is_equal(["invest_in_growth"])
	assert_str(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)[0]).is_equal("market_intelligence")
	# Chapter 3 is all ahead: the console still stands, no farm is owned, the alpha has not ended.
	assert_bool(SupplyConsole.retired(save)).is_false()
	assert_bool(save.farms_owned.is_empty()).is_true()
	assert_bool(save.alpha_end).is_false()
	assert_bool(AlphaEnd.due(save)).is_false()


func test_the_five_farms_start_point_has_the_war_card_in_the_tray_ready_to_stamp() -> void:
	var path := DebugStarts.START_DIR.path_join("60_five_farms_owned.tres")
	assert_array(Array(DebugStarts.entries())).contains([path])
	assert_str(DebugStarts.label_of(path)).is_equal("60  Five Farms Owned")
	var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_int(save.farms_owned.size()).is_equal(UpgradeDesk.Events.HOME_SELLERS)
	assert_array(Array(save.stamped)).contains(["negotiation", "bribery"])  # The cards its farms were bought behind.
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)).is_equal([FarmRegister.WAR_CARD])
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(UpgradeDesk.card_data(FarmRegister.WAR_CARD)))).is_true()
	assert_int(save.stock).is_less_equal(save.storage_cap)
	assert_array(BossReport.due(save)).is_empty()  # Every paper is signed: nothing in the way.
	# No war yet, and the world sheet is still locked: stamping the card is what this start is for.
	assert_bool(FarmRegister.war_ready(save, &"K-6")).is_false()
	assert_bool(MapTable.sheet_unlocked(&"world", save)).is_false()
	assert_str(MapTable.start_sheet(save)).is_equal(&"kohlmark")


func test_the_home_country_start_point_opens_in_the_world_phase_with_the_first_law_in_the_tray() -> void:
	var path := DebugStarts.START_DIR.path_join("70_home_country_owned.tres")
	assert_array(Array(DebugStarts.entries())).contains([path])
	assert_str(DebugStarts.label_of(path)).is_equal("70  Home Country Owned")
	var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	var world: GDScript = load("res://entities/map_table/world_register.gd")
	# Every home farm and nothing abroad; the world sheet is in the holder over the home sheet.
	assert_int(UpgradeDesk.Events.home_farms(save)).is_equal(UpgradeDesk.Events.HOME_SITES)
	assert_int(save.farms_owned.size()).is_equal(UpgradeDesk.Events.HOME_SITES)
	assert_int(save.farm_squares.size()).is_equal(save.farms_owned.size())  # Each farm has its square.
	assert_array(Array(save.stamped)).contains([FarmRegister.WAR_CARD, MapTable.WORLD_CARD])
	assert_bool(MapTable.sheet_unlocked(&"world", save)).is_true()
	assert_str(MapTable.start_sheet(save)).is_equal(&"kohlmark")
	assert_array(BossReport.due(save)).is_empty()  # Every paper is signed, THE COUNTRY IS OURS too.
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["no_taxes", "route_planning"])  # The war line beside it, its first card.
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(UpgradeDesk.card_data("no_taxes")))).is_true()
	# A neighbour's farm can be attacked at once; the sea is still closed.
	var war := FarmRegister.war_bill(save, &"ostrevia-1")
	assert_dict(war).is_not_empty()
	assert_bool(UpgradeDesk.affords(save, war)).is_true()
	assert_str(world.reach(save, &"grauland")).is_equal(world.NOT_ADJACENT)
	assert_bool(save.stamped.has(world.SEA_CARD)).is_false()


## The desk cards that wait for the stars card (chapter 4's), directly or through another.
func _chapter_4_cards() -> Array:
	var out := ["stars"]
	var found := true
	while found:
		found = false
		for card: Dictionary in UpgradeDesk.CARDS:
			if card.id not in out and card.get("needs", []).any(func(need: String) -> bool: return need in out):
				out.append(card.id)
				found = true
	out.erase("stars")
	return out


## Whether node `id` of tree `rules` (or one above it) needs one of `cards`.
func _waits_for(rules: Variant, id: String, cards: Array) -> bool:
	var node: Dictionary = rules.node_data(id)
	return node.get("needs", []).any(func(card: String) -> bool: return card in cards) \
			or (node.parent != "" and _waits_for(rules, node.parent, cards))


func test_the_chapter_4_card_start_point_sorts_just_before_the_gun_with_everything_bought_and_the_stars_card_ready_to_stamp() -> void:
	var path := DebugStarts.START_DIR.path_join("95_chapter_4_card.tres")
	assert_str(DebugStarts.entries()[-2]).is_equal(path)
	assert_str(DebugStarts.entries()[-1]).is_equal(DebugStarts.START_DIR.path_join("96_chapter_5_the_gun.tres"))
	assert_str(DebugStarts.label_of(path)).is_equal("95  Chapter 4 Card")
	var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	# Every farm in the world, each on its own square.
	assert_int(save.farms_owned.size()).is_equal(UpgradeDesk.Events.FARMS)
	assert_int(save.farm_squares.size()).is_equal(save.farms_owned.size())
	# Every chapter 3 card but the last is stamped (chapter 4's wait behind it); every node of every
	# tree is bought but chapter 4's.
	var ahead := _chapter_4_cards()
	for card: Dictionary in UpgradeDesk.CARDS:
		assert_bool(save.stamped.has(card.id)).override_failure_message("%s is not stamped" % card.id).is_equal(card.id != "stars" and card.id not in ahead)
	for node: Dictionary in Projector.NODES:
		if not Projector.is_dept(node.id) and not _waits_for(Projector, node.id, ahead):
			assert_bool(Projector.is_bought(node.id, save)).override_failure_message("projector %s" % node.id).is_true()
	for node: Dictionary in FarmTree.NODES:
		if not FarmTree.is_dept(node.id) and not _waits_for(FarmTree, node.id, ahead):
			assert_bool(FarmTree.is_bought(node.id, save)).override_failure_message("farm tree %s" % node.id).is_true()
	for node: Dictionary in DepotResearch.NODES:
		if not DepotResearch.is_dept(node.id):
			assert_bool(DepotResearch.is_bought(node.id, save)).override_failure_message("depot %s" % node.id).is_true()
	# The stars card alone in the tray, paid at once, nothing in the way; chapter 3 not over yet.
	assert_array(UpgradeDesk.next_cards(save.stamped, UpgradeDesk.OFFERED, save)).is_equal(["stars"])
	assert_bool(UpgradeDesk.affords(save, UpgradeDesk.costs(UpgradeDesk.card_data("stars")))).is_true()
	assert_array(BossReport.due(save)).is_empty()
	assert_bool(UpgradeDesk.Events.chapter_3_done(save)).is_false()
	assert_bool(save.alpha_end).is_false()


func test_no_start_point_holds_more_than_its_limits_and_each_has_the_limits_its_upgrades_give() -> void:
	for path in DebugStarts.entries():
		var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
		assert_int(save.coins).override_failure_message("%s: coins over the limit" % path).is_less_equal(save.coin_limit)
		assert_int(save.findings).override_failure_message("%s: findings over the limit" % path).is_less_equal(save.findings_limit)
		var fresh := SaveGame.new()  # The limits its cards and nodes add up to.
		for card: String in ["cash_holding", "archive_capacity"]:
			if save.stamped.has(card):
				UpgradeDesk.apply(card, fresh)
		for node: Dictionary in Projector.NODES:
			# An ARCHIVE step from before it moved to the projector is still in farm_bought (save.migration 8 moves it).
			var bought: bool = save.tree_bought.has(node.id) or (node.id.begins_with("archive_") and save.farm_bought.has(node.id))
			if (node.get("add", {}).has("coin_limit") or node.get("add", {}).has("findings_limit")) and bought:
				UpgradeTree.apply_effect(node, fresh)
		assert_int(save.coin_limit).override_failure_message(path).is_equal(fresh.coin_limit)
		assert_int(save.findings_limit).override_failure_message(path).is_equal(fresh.findings_limit)


func test_the_chapter_5_start_point_opens_the_ending_with_the_gun_card_stamped() -> void:
	var save := ResourceLoader.load(DebugStarts.START_DIR.path_join("96_chapter_5_the_gun.tres"), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_bool(Ending.due(save)).is_true()
	assert_bool(save.stamped.has("stars")).is_true()
	assert_bool(AlphaEnd.due(save)).is_false()  # No alpha popup over the ending.
