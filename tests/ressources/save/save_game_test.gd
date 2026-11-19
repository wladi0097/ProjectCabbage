extends GdUnitTestSuite

const WorldRegister := preload("res://entities/map_table/world_register.gd")
const WarSheet := preload("res://entities/map_table/war_sheet.gd")
const ROUND_TRIP_PATH := "user://save_game_test_round_trip.tres"
const LOG_PATH := "user://save_game_test_log.csv"


func after_test() -> void:
	for path in [ROUND_TRIP_PATH, LOG_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_a_new_game_starts_with_ten_units_to_sell_two_dollars_chalked_and_nothing_unlocked() -> void:
	var save := SaveGame.new()
	assert_int(save.stock).is_equal(10)
	assert_int(save.coins).is_equal(0)
	assert_int(save.sold).is_equal(0)
	assert_int(save.sale_price).is_equal(2)
	assert_int(save.desk_capacity).is_equal(1)
	assert_int(save.pack_size).is_equal(10)
	assert_int(save.hands).is_equal(0)
	assert_float(save.marketing).is_equal(1.0)
	assert_float(save.demand_mood).is_equal(1.0)
	assert_bool(save.buy_unlocked or save.slate_unlocked or save.tray_unlocked or save.supply_shock).is_false()
	assert_array(save.stamped).is_empty()
	assert_array(save.tree_bought).is_empty()
	assert_array(save.playtest_log).is_empty()


func test_a_save_from_before_migrations_existed_loads_at_migration_zero_so_every_fix_up_runs() -> void:
	assert_int(SaveGame.new().migration).is_equal(0)
	assert_int(SaveGame.MIGRATION).is_greater(0)


func test_every_saved_field_survives_a_write_and_a_read_back() -> void:
	var save := SaveGame.new()
	var changed := {}
	for property: Dictionary in save.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = _another_value(save, property.name)
		save.set(property.name, value)
		changed[property.name] = value
	assert_dict(changed).is_not_empty()
	assert_int(ResourceSaver.save(save, ROUND_TRIP_PATH)).is_equal(OK)

	var loaded := SafeResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_object(loaded).is_not_null()
	for field: String in changed:
		if changed[field] is float:
			assert_float(loaded.get(field)).override_failure_message(field).is_equal_approx(changed[field], 0.0001)
		else:
			assert_that(loaded.get(field)).override_failure_message(field).is_equal(changed[field])


func test_a_save_from_the_old_squeeze_cycle_still_loads_and_its_squeeze_is_on_for_good() -> void:
	var text := '[gd_resource type="Resource" script_class="SaveGame" format=3]

' 			+ '[ext_resource type="Script" path="res://ressources/save/save_game.gd" id="1"]

' 			+ '[resource]
script = ExtResource("1")
coins = 30
supply_shock = true
squeeze_left = 20.0
' 			+ 'stamped = PackedStringArray("family_farm")
'
	FileAccess.open(ROUND_TRIP_PATH, FileAccess.WRITE).store_string(text)
	var loaded := SafeResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_object(loaded).is_not_null()
	assert_int(loaded.coins).is_equal(30)
	# It was in the old 1 min lull; now there is none.
	assert_float(SupplyConsole.crate_share(loaded.supply_shock, SupplyConsole.squeezing(loaded))).is_equal(SupplyConsole.SQUEEZE_SHARE)


func test_a_log_line_records_what_happened_and_the_state_right_after_it() -> void:
	var save := SaveGame.new()
	save.coins = 42
	save.marketing = 1.23456
	var entry := save.log_entry(95, "card", "price_slate", 12, "coins")
	assert_int(entry.t).is_equal(95)
	assert_str(entry.kind).is_equal("card")
	assert_str(entry.id).is_equal("price_slate")
	assert_int(entry.price).is_equal(12)
	assert_str(entry.currency).is_equal("coins")
	assert_int(entry.coins).is_equal(42)
	assert_float(entry.marketing).is_equal_approx(1.235, 0.00001)


func test_every_log_column_is_in_every_log_entry() -> void:
	var entry := SaveGame.new().log_entry(95, "minute")
	for column: String in SaveGame.LOG_COLUMNS:
		assert_bool(entry.has(column)).override_failure_message(column).is_true()


func test_a_log_entry_snapshots_the_playtest_counters_with_clock_seconds_rounded() -> void:
	var save := SaveGame.new()
	save.hand_sold = 3
	save.tv_seconds = 12.6
	save.coins_earned = 400
	var entry := save.log_entry(95, "minute")
	assert_int(entry.hand_sold).is_equal(3)
	assert_int(entry.tv_seconds).is_equal(13)
	assert_int(entry.coins_earned).is_equal(400)


func test_a_log_line_has_one_cell_per_column_and_blanks_for_what_an_entry_lacks() -> void:
	var save := SaveGame.new()
	save.coins = 42
	assert_str(SaveGame.log_line(save.log_entry(95, "card", "price_slate", 12, "coins"))).starts_with("95,card,price_slate,12,coins,42,")
	assert_str(SaveGame.log_line({t = 100, kind = "session"})).is_equal("100,session" + ",".repeat(SaveGame.LOG_COLUMNS.size() - 2))


func test_the_log_file_is_appended_under_one_header_and_reads_back_as_numbers() -> void:
	var save := SaveGame.new()
	save.coins = 42
	save.marketing = 1.23456
	SaveGame.append_log(LOG_PATH, save.log_entry(95, "card", "price_slate", 12, "coins"))
	SaveGame.append_log(LOG_PATH, save.log_entry(100, "session", "0"))
	var text := FileAccess.get_file_as_string(LOG_PATH)
	assert_int(text.split("
", false).size()).is_equal(3)
	assert_str(text).starts_with(SaveGame.log_header() + "
")
	var entries := SaveGame.parse_log(text)
	assert_int(entries.size()).is_equal(2)
	assert_int(entries[0].t).is_equal(95)
	assert_int(entries[0].coins).is_equal(42)
	assert_float(entries[0].marketing).is_equal_approx(1.235, 0.00001)
	assert_str(entries[0].id).is_equal("price_slate")
	assert_str(entries[1].id).is_equal("0")


func test_a_log_from_a_build_with_other_columns_gets_a_new_header_and_both_parts_read() -> void:
	var old := "t,kind,id,price,currency,coins
95,card,radio,6,coins,30
"
	assert_bool(SaveGame.needs_header(old)).is_true()
	assert_bool(SaveGame.needs_header("")).is_false()
	var both := old + SaveGame.log_header() + "
" + SaveGame.log_line(SaveGame.new().log_entry(120, "minute")) + "
"
	assert_bool(SaveGame.needs_header(both)).is_false()
	var entries := SaveGame.parse_log(both)
	assert_int(entries.size()).is_equal(2)
	assert_int(entries[0].coins).is_equal(30)
	assert_bool(entries[0].has("hand_sold")).is_false()
	assert_str(entries[1].kind).is_equal("minute")


func test_the_save_file_never_holds_the_playtest_log() -> void:
	var save := SaveGame.new()
	for t in 600:
		save.playtest_log.append(save.log_entry(t * 60, "minute"))
	assert_int(ResourceSaver.save(save, ROUND_TRIP_PATH)).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(ROUND_TRIP_PATH)).not_contains("playtest_log")


func _another_value(save: SaveGame, field: String) -> Variant:
	var value: Variant = save.get(field)
	match typeof(value):
		TYPE_BOOL:
			return not value
		TYPE_INT:
			return value + 7
		TYPE_FLOAT:
			return value + 0.5
		TYPE_STRING:
			return "round trip"
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(["price_slate", "radio"])
		TYPE_PACKED_FLOAT32_ARRAY:
			return PackedFloat32Array([1.5, -1.0])
		TYPE_PACKED_INT32_ARRAY:
			return PackedInt32Array([3, 7])
		TYPE_DICTIONARY:
			return {field_associate = 3, senior_asset = 1}
		TYPE_ARRAY:
			if field == "army_training":
				return [{unit = "field_associate", left = 12.5}]
			if field == "farm_seed_clocks":
				var clocks: Array[PackedFloat32Array] = [PackedFloat32Array([12.5, 3.0]), PackedFloat32Array()]
				return clocks
			if field == "farm_seed_golden":
				var golden: Array[PackedByteArray] = [PackedByteArray([0, 1]), PackedByteArray()]
				return golden
			var log_lines: Array[Dictionary] = [save.log_entry(95, "card", "price_slate", 12, "coins")]
			return log_lines
	fail("no round-trip value for %s (type %d)" % [field, typeof(value)])
	return value

# ---- The coin and Findings limits (SaveGame.earn), their two desk cards and their ladders ----

func test_a_new_game_may_hold_40000_coins_and_8000_findings() -> void:
	var save := SaveGame.new()
	assert_int(save.coin_limit).is_equal(40000)
	assert_int(save.findings_limit).is_equal(8000)


func test_coins_stop_at_the_cash_limit() -> void:
	var save := SaveGame.new()
	save.coins = save.coin_limit - 10
	assert_int(save.earn(&"coins", 25)).is_equal(10)
	assert_int(save.coins).is_equal(save.coin_limit)
	assert_int(save.earn(&"coins", 25)).is_equal(0)
	assert_int(save.coins).is_equal(save.coin_limit)


func test_findings_stop_at_the_research_limit() -> void:
	var save := SaveGame.new()
	assert_int(save.earn(&"findings", 7990)).is_equal(7990)
	assert_int(save.earn(&"findings", 500)).is_equal(10)
	assert_int(save.findings).is_equal(8000)
	assert_int(save.room(&"findings")).is_equal(0)


func test_an_old_save_above_the_limit_keeps_its_coins_and_earns_nothing_until_it_is_under_again() -> void:
	var save := SaveGame.new()
	save.coins = 2500000
	save.findings = 60000
	assert_int(save.earn(&"coins", 100)).is_equal(0)
	assert_int(save.earn(&"findings", 100)).is_equal(0)
	assert_int(save.coins).is_equal(2500000)  # Never clawed back.
	assert_int(save.findings).is_equal(60000)
	save.coins = 39000  # Spent down under the limit: it earns again, up to the limit.
	assert_int(save.earn(&"coins", 5000)).is_equal(1000)


func test_a_raised_limit_lets_a_full_purse_earn_again() -> void:
	var save := SaveGame.new()
	save.coins = save.coin_limit
	assert_int(save.earn(&"coins", 100)).is_equal(0)
	UpgradeDesk.apply("cash_holding", save)
	assert_int(save.earn(&"coins", 100)).is_equal(100)


func test_the_cash_limit_card_multiplies_the_limit_by_five_and_the_archive_card_the_findings_limit() -> void:
	var save := SaveGame.new()
	UpgradeDesk.apply("cash_holding", save)
	assert_int(save.coin_limit).is_equal(200000)
	assert_int(save.findings_limit).is_equal(8000)
	UpgradeDesk.apply("archive_capacity", save)
	assert_int(save.findings_limit).is_equal(40000)


## Every step that raises `limit` ("coin_limit", "findings_limit"), in the order it is bought: the desk
## card, then the tree's chain, chapter 4's (CAPITAL after the card print_numbers, DECAY ARCHIVE) last.
## Each as [id, price, the node or card].
func _limit_steps(limit: String) -> Array:
	var coins := limit == "coin_limit"
	var card := UpgradeDesk.card_data("cash_holding" if coins else "archive_capacity")
	var out := [[card.id, card.price, card]]
	for node: Dictionary in Projector.NODES:
		if node.get("add", {}).has(limit):
			if node.id == "capital_1":
				var numbers := UpgradeDesk.card_data("print_numbers")
				out.append([numbers.id, numbers.price, numbers])
			out.append([node.id, node.price, node])
	return out


## Whether limit step `id` is chapter 4's (print_numbers, CAPITAL, DECAY ARCHIVE).
func _nuclear_step(id: String) -> bool:
	return id == "print_numbers" or id.begins_with("capital_") or id.begins_with("decay_archive_")


## Buys every step of `limit` on a new save, calling `each` (step, limit before, limit after); returns the save.
func _climb(limit: String, each := Callable()) -> SaveGame:
	var save := SaveGame.new()
	for step: Array in _limit_steps(limit):
		var was: int = save.get(limit)
		if step[2].has("parent"):
			UpgradeTree.apply_effect(step[2], save)
		else:
			UpgradeDesk.apply(step[0], save)
		if each.is_valid():
			each.call(step, was, save.get(limit))
	return save


func test_every_limit_step_costs_no_more_than_the_limit_before_it_and_at_least_doubles_it_but_the_archives_last_two() -> void:
	# The Findings counter has six drums: the ARCHIVE ladder ends under ¶1,000,000, its last two steps half as much again.
	for limit: String in ["coin_limit", "findings_limit"]:
		var currency := "coins" if limit == "coin_limit" else "findings"
		var steps := _limit_steps(limit)
		assert_int(steps.filter(func(step: Array) -> bool: return not _nuclear_step(step[0])).size()).override_failure_message(limit).is_equal(6)  # The card, then five steps.
		_climb(limit, func(step: Array, was: int, now: int) -> void:
			assert_int(step[1]).override_failure_message("%s costs more than the limit before it" % step[0]).is_less_equal(was)
			# Chapter 4's DECAY ARCHIVE climbs from ¶900K to ¶10M in five steps: half as much again or more.
			var least := 1.5 if step[0] in ["archive_4", "archive_5"] or step[0].begins_with("decay_archive_") else 2.0
			assert_float(float(now)).override_failure_message("%s does not raise the limit %s times" % [step[0], least]).is_greater_equal(was * least))
		# Paid in the currency it raises, each tree step hanging under the one before.
		assert_array(UpgradeDesk.costs(steps[0][2]).keys()).is_equal([currency])
		for i in range(1, steps.size()):
			assert_str(UpgradeTree.currency_of(steps[i][2])).override_failure_message(steps[i][0]).is_equal(currency)
			if i > 1 and steps[i][2].has("parent") and steps[i - 1][2].has("parent"):
				assert_str(steps[i][2].parent).override_failure_message(steps[i][0]).is_equal(steps[i - 1][0])


func test_the_ladders_reach_ten_million_coins_and_past_a_hundred_thousand_findings() -> void:
	assert_int(_climb("coin_limit").coin_limit).is_greater_equal(10000000)
	assert_int(_climb("findings_limit").findings_limit).is_greater(100000)


func test_nothing_in_the_game_costs_more_than_the_highest_limit_of_its_currency() -> void:
	var top := {coins = _climb("coin_limit").coin_limit, findings = _climb("findings_limit").findings_limit}
	var bills := {}  # What everything on sale costs, by id.
	for card: Dictionary in UpgradeDesk.CARDS:
		bills[card.id] = UpgradeDesk.costs(card)
	for node: Dictionary in Projector.NODES + FarmTree.NODES:
		bills[node.id] = {UpgradeTree.currency_of(node): node.price}
	var farms := SaveGame.new()
	farms.stamped = PackedStringArray(["negotiation", "bribery"])
	for nth in FarmRegister.PRICES.size():
		farms.farms_owned.resize(nth)
		for site: StringName in FarmRegister.WORTH:
			bills["farm %d at %s" % [nth + 1, site]] = FarmRegister.asking(farms, site)
	for country: StringName in WorldRegister.COUNTRIES:
		for nth in WorldRegister.COUNTRIES[country].wars.size():
			bills["war %d in %s" % [nth + 1, country]] = WorldRegister.COUNTRIES[country].wars[nth]
	bills["the last farm square"] = {coins = FarmScreen.plot_price_of(FarmScreen.MAX_PLOTS - 1)}
	for id: String in bills:
		for currency: String in top:
			assert_int(bills[id].get(currency, 0)).override_failure_message("%s costs more %s than can ever be held" % [id, currency]) \
					.is_less_equal(top[currency])


func test_everything_needed_before_chapter_3_is_affordable_under_the_starting_limits() -> void:
	var save := SaveGame.new()
	# Every desk card up to chapter 2's last one, then the card that opens chapter 3 and the cash card.
	var ids: Array = UpgradeDesk.CARDS.map(func(card: Dictionary) -> String: return card.id)
	assert_int(ids.find("cash_holding")).is_equal(ids.find("consolidation") + 2)
	for card: Dictionary in UpgradeDesk.CARDS.slice(0, ids.find("big_ideas") + 1):
		var bill := UpgradeDesk.costs(card)
		assert_int(bill.get("coins", 0)).override_failure_message(card.id).is_less_equal(save.coin_limit)
		assert_int(bill.get("findings", 0)).override_failure_message(card.id).is_less_equal(save.findings_limit)
	# The storage chain to ANNEXED PROVINCE (the last card is paid in more cabbages than the depot
	# holds; the steps past it are chapter 3's, behind the cash card), and every projector node a card waits for.
	var needed: Array = UpgradeDesk.CARDS.filter(func(card: Dictionary) -> bool: return card.has("tree")).map(func(card: Dictionary) -> String: return card.tree)
	assert_array(needed).is_not_empty()
	for node: Dictionary in Projector.NODES:
		if (node.get("add", {}).has("storage_cap") and Projector.cap_at(node.id) <= 15000) or node.id in needed:
			assert_int(node.price).override_failure_message(node.id).is_less_equal(save.coin_limit)


func test_chapter_3_never_asks_for_more_than_the_limit_its_cards_so_far_allow() -> void:
	# The cash card comes right after the card that opens chapter 3, with the wide sheet's card and
	# the archive card (each fits the starting limits, so they are stamped in any order), before the
	# first farm ($60,000); CONDENSE, STRUCTURED FARM and all that follows wait for both limit cards.
	var ids: Array = UpgradeDesk.CARDS.map(func(card: Dictionary) -> String: return card.id)
	assert_int(ids.find("cash_holding")).is_equal(ids.find("market_intelligence") + 1)
	for id: String in ["cash_holding", "big_ideas", "archive_capacity"]:
		assert_array(UpgradeDesk.card_data(id).needs).override_failure_message(id).is_equal(["market_intelligence"])
	for id: String in ["condense", "structured_farm"]:
		assert_array(UpgradeDesk.card_data(id).needs).override_failure_message(id).contains(["cash_holding", "big_ideas", "archive_capacity"])
	var start := SaveGame.new()
	for site: StringName in FarmRegister.WORTH:  # The cheapest site and the dearest.
		assert_int(FarmRegister.asking(start, site).coins).override_failure_message(site).is_greater(start.coin_limit)
		assert_int(FarmRegister.asking(start, site).coins).override_failure_message(site).is_less_equal(start.coin_limit * UpgradeDesk.LIMIT_RAISE)
	# The projector's steps wait for the wide sheet, the archive's for its card too.
	assert_array(Projector.node_data("coin_limit_1").needs).contains(["big_ideas", "cash_holding"])
	assert_array(Projector.node_data("archive_1").needs).contains(["archive_capacity", "big_ideas"])
	# The four cards that can lie in the tray before either limit is raised fit the starting limits.
	var start_ids := ["market_intelligence", "cash_holding", "big_ideas", "archive_capacity", "map_readout"]
	for id: String in start_ids:
		var first := UpgradeDesk.costs(UpgradeDesk.card_data(id))
		assert_int(first.get("coins", 0)).override_failure_message(id).is_less_equal(start.coin_limit)
		assert_int(first.get("findings", 0)).override_failure_message(id).is_less_equal(start.findings_limit)
	# Every card of the chapter is covered by the limit the chain has reached when it is dealt: the
	# cards' own x5, then (from the wide sheet on) every projector and CH2 step, each affordable in turn.
	var save := SaveGame.new()
	for card: Dictionary in UpgradeDesk.CARDS.slice(ids.find("market_intelligence")):
		if card.id == "condense":  # The wide sheet and CH2's archive branch are open: the ladders can be climbed.
			save.coin_limit = _climb("coin_limit").coin_limit
			save.findings_limit = _climb("findings_limit").findings_limit
		var bill := UpgradeDesk.costs(card)
		assert_int(bill.get("coins", 0)).override_failure_message(card.id).is_less_equal(save.coin_limit)
		assert_int(bill.get("findings", 0)).override_failure_message(card.id).is_less_equal(save.findings_limit)
		UpgradeDesk.apply(card.id, save)


func test_every_farm_of_the_world_can_be_owned_and_the_last_card_is_reachable_under_the_limits() -> void:
	# From the world map card on, under the top limits and the biggest store: whatever can be paid
	# with a full purse, a full archive and a full store (less a full mat of condensed cabbages) is
	# taken, a war at a time, until nothing more can be. The whole chain has to come out of that.
	var save := _climb("coin_limit")
	save.findings_limit = _climb("findings_limit").findings_limit
	save.storage_cap = SaveGame.new().storage_cap
	var condensed := 2
	for node: Dictionary in Projector.NODES:
		save.storage_cap += int(node.get("add", {}).get("storage_cap", 0))
		condensed += int(node.get("add", {}).get("condense", 0))
	var out := Vector2i(Projector.MAT_MAX * condensed, 0)
	var ids: Array = UpgradeDesk.CARDS.map(func(card: Dictionary) -> String: return card.id)
	save.stamped = PackedStringArray(ids.slice(0, ids.find("world_map") + 1))
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5"])
	var by_rank := WorldRegister.COUNTRIES.keys()
	by_rank.sort_custom(func(a: StringName, b: StringName) -> bool: return WorldRegister.COUNTRIES[a].rank < WorldRegister.COUNTRIES[b].rank)
	var order := []  # What happened, in order.
	var moved := true
	while moved:
		moved = false
		save.coins = save.coin_limit
		save.findings = save.findings_limit
		save.stock = save.storage_cap
		for id: String in UpgradeDesk.next_cards(save.stamped, 1, save):
			var bill := UpgradeDesk.costs(UpgradeDesk.card_data(id))
			if not moved and UpgradeDesk.affords(save, bill, out):
				for paid_in: String in bill:
					UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
				save.stamped.append(id)
				UpgradeDesk.apply(id, save)
				order.append(id)
				moved = true
		for country: StringName in by_rank:
			for farm in WorldRegister.farm_ids(country):
				var bill := FarmRegister.war_bill(save, StringName(farm))
				if not moved and not bill.is_empty() and UpgradeDesk.affords(save, bill, out):
					for paid_in: String in bill:  # The declaration pays; the war is won.
						UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
					WarSheet.win(save, StringName(farm))
					order.append(farm)
					moved = true
	assert_int(save.farms_owned.size()).is_equal(UpgradeDesk.Events.FARMS)
	assert_bool(UpgradeDesk.Events.chapter_3_done(save)).is_true()
	assert_array(order.slice(0, 4)).is_equal(["K-6", "K-7", "K-8", "no_taxes"])  # The country, then its first law.
	# An optional card queued behind the chain (GameEvents.DRY_LEFT) may still be bought after it.
	var chain := order.filter(func(id: Variant) -> bool: return not str(id) in UpgradeDesk.Events.DRY_LEFT)
	assert_str(chain[-1]).is_equal("star_programme")  # Chapter 4's nuclear hour follows stars under the same limits.
	chain = chain.slice(0, chain.find("stars") + 1)
	assert_str(chain[-1]).is_equal("stars")
	assert_str(chain[-2]).is_equal("endmark-1")  # The final island falls last.
	# Nothing across the water before the sea lanes.
	for country: StringName in [&"grauland", &"lower_provinces", &"morrow", &"nordhal", &"endmark"]:
		for farm in WorldRegister.farm_ids(country):
			assert_int(order.find(farm)).override_failure_message(farm).is_greater(order.find("sea_lanes"))
	for country: StringName in [&"ostrevia", &"veldmark", &"sulvania"]:
		for farm in WorldRegister.farm_ids(country):
			assert_int(order.find(farm)).override_failure_message(farm).is_between(0, order.find("grauland-1"))
