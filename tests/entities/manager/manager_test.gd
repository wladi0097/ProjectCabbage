extends GdUnitTestSuite

const MANAGER := preload("res://entities/manager/manager.tscn")
const STEP := 0.1
const WarSheet := preload("res://entities/map_table/war_sheet.gd")
const FAKE_COINS := "extends CoinPile\nvar paid := 0\nfunc _ready() -> void:\n\tpass\nfunc _process(_delta: float) -> void:\n\tpass\nfunc throw_in_after(_delay: float, _origin: Vector3, amount: int) -> void:\n\tpaid += amount\n"
const FAKE_MEMO := "extends Node\nvar posted: Array[Dictionary] = []\nfunc post(m: Dictionary) -> void:\n\tposted.append(m)\n"

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()
	WarSheet.at_war = false  # No war left over from another suite.


func after_test() -> void:
	SaveManager.save = _real_save
	WarSheet.at_war = false


func _fake(source: String) -> Node:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return auto_free(script.new())


func _manager() -> Manager:
	var manager := MANAGER.instantiate() as Manager
	manager.coins = _fake(FAKE_COINS) as CoinPile
	manager.memo = _fake(FAKE_MEMO)
	add_child(auto_free(manager))
	manager.set_process(false)
	return manager


func _run(manager: Manager, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		manager._process(STEP)


## Stamps the card and waits until he is at the window asking for his quota.
func _asking(manager: Manager) -> void:
	SaveManager.save.stamped.append(Manager.CARD)
	_run(manager, Manager.CARD_VISIT + Manager.ARRIVE_TIME + 0.2)


func _rising_samples(count: int) -> PackedInt32Array:
	var samples := PackedInt32Array()
	for i in count:
		samples.append(i)
	return samples


func test_the_quota_is_the_five_minute_pace_over_the_time_given_raised_a_quarter() -> void:
	# 60 sold over 60 samples of 5 s: 0.2 a second, 45 s at x1.25 asks ceil(11.25).
	assert_int(Manager.quota_for(_rising_samples(60), 60, 45.0, 1.25)).is_equal(12)


func test_with_nothing_sold_yet_the_quota_is_the_minimum() -> void:
	assert_int(Manager.quota_for(PackedInt32Array([5]), 5, 45.0, 1.25)).is_equal(Manager.MIN_QUOTA)
	assert_int(Manager.quota_for(PackedInt32Array(), 0, 45.0, 1.25)).is_equal(Manager.MIN_QUOTA)


func test_more_time_or_a_bigger_raise_asks_for_more_units() -> void:
	var samples := _rising_samples(60)
	var base := Manager.quota_for(samples, 60, 45.0, 1.25)

	assert_int(Manager.quota_for(samples, 60, 60.0, 1.25)).is_greater(base)
	assert_int(Manager.quota_for(samples, 60, 45.0, 1.5)).is_greater(base)


func test_the_time_since_the_last_sample_counts_toward_the_pace() -> void:
	var samples := PackedInt32Array([0, 10, 10, 10, 10, 10, 10])

	# 20 sold over 30 s + 5 s since: ceil(25.7); over 30 s: 30.
	assert_int(Manager.quota_for(samples, 20, 45.0, 1.0, 5.0)).is_equal(26)
	assert_int(Manager.quota_for(samples, 20, 45.0, 1.0, 0.0)).is_equal(30)


func test_the_first_visit_right_after_the_card_reads_the_pace_over_at_least_thirty_seconds() -> void:
	# 3 sold in the 5 s since the stamp: read over 30 s, 45 s at x1.25 asks ceil(5.6), not 34.
	assert_int(Manager.quota_for(PackedInt32Array([0]), 3, 45.0, 1.25, 5.0)).is_equal(6)


## A save with plenty in stock: only the chute limits what can be delivered.
func _stocked(capacity: int) -> SaveGame:
	var save := SaveGame.new()
	save.stock = 1000
	save.storage_cap = 1000
	save.desk_capacity = capacity
	return save


func test_head_office_never_asks_for_more_cabbages_than_the_chute_can_drop_in_the_deadline() -> void:
	# One mat slot, 1 s chute: a cabbage every 2.87 s at best (restock 0.67 + roll 0.4 + flight 0.8 +
	# a 1 s flick), so 1 on the mat + 15 more in 45 s and the walk-in. A player already selling every
	# one (104 in 5 minutes) would be asked 20 by the pace alone.
	var save := _stocked(1)
	var samples := PackedInt32Array()
	for i in 61:
		samples.append(roundi(i * 104 / 60.0))
	var asked := Manager.quota_for(samples, 104, save.manager_time, save.manager_raise)
	var can := Manager.deliverable(save, 1)

	assert_int(can).is_equal(16)
	assert_int(asked).is_greater(can)
	assert_int(Manager.capped(asked, can)).is_equal(14)


func test_a_sell_off_burst_does_not_make_the_next_quota_impossible() -> void:
	# 120 sold in 30 s off a full ten-cabbage mat and hands asks 225; the 1 s chute drops 45 more.
	var save := _stocked(10)
	var asked := Manager.quota_for(PackedInt32Array([0, 20, 40, 60, 80, 100, 120]), 120, save.manager_time, save.manager_raise)
	var can := Manager.deliverable(save, 10)

	assert_int(asked).is_equal(225)
	assert_int(can).is_equal(55)
	assert_int(Manager.capped(asked, can)).is_equal(49)


func test_the_quota_still_asks_for_more_than_your_pace_when_the_chute_can_deliver_it() -> void:
	# 0.2 sold a second is 9 in 45 s; the pace quota of 12 fits under the chute's 55.
	var save := _stocked(10)
	var asked := Manager.quota_for(_rising_samples(60), 60, save.manager_time, save.manager_raise)

	assert_int(Manager.capped(asked, Manager.deliverable(save, 10))).is_equal(12)


func test_a_shut_chute_or_a_steep_price_does_not_lower_what_can_be_delivered() -> void:
	var save := _stocked(3)
	var can := Manager.deliverable(save, 2)
	save.chute_blocked = true
	save.sale_price = 500

	assert_int(Manager.deliverable(save, 2)).is_equal(can)


func test_a_faster_chute_or_a_bigger_mat_lets_head_office_ask_for_more() -> void:
	var save := _stocked(1)
	var one := Manager.deliverable(save, 0)
	save.desk_capacity = 3
	var three := Manager.deliverable(save, 0)
	save.dispense_interval = 0.5

	assert_int(three).is_greater(one)
	assert_int(Manager.deliverable(save, 0)).is_greater(three)


func test_rotten_cabbages_off_the_chute_do_not_count_toward_what_can_be_delivered() -> void:
	var save := _stocked(10)
	var fresh := Manager.deliverable(save, 0)
	save.rotten_unlocked = true

	assert_int(Manager.deliverable(save, 0)).is_less(fresh)


func test_with_little_stock_and_no_packs_to_buy_the_quota_is_what_is_left() -> void:
	var save := SaveGame.new()
	save.stock = 2

	assert_int(Manager.deliverable(save, 1)).is_equal(2)
	assert_int(Manager.capped(Manager.MIN_QUOTA, 2)).is_equal(2)
	assert_int(Manager.capped(Manager.MIN_QUOTA, 3)).is_equal(Manager.MIN_QUOTA)


func test_coins_for_a_pack_that_pays_for_itself_count_as_stock_to_come() -> void:
	var save := SaveGame.new()
	save.stock = 2
	save.buy_unlocked = true
	save.coins = 100

	assert_int(SupplyConsole.pack_cost(save)).is_less_equal(save.pack_size * save.sale_price)
	assert_int(Manager.deliverable(save, 1)).is_equal(16)


func test_in_the_squeeze_only_the_packs_the_tally_can_pay_for_count() -> void:
	var save := SaveGame.new()
	save.stock = 0
	save.buy_unlocked = true
	save.supply_shock = true
	save.stamped.append("family_farm")
	save.sale_price = 1
	var cost := SupplyConsole.pack_cost(save)
	save.coins = cost + 1

	assert_int(cost).is_greater(save.pack_size * save.sale_price)
	assert_int(Manager.deliverable(save, 0)).is_equal(save.pack_size)


func test_the_farm_counts_the_squares_ripe_in_time_and_replants_while_seeds_last() -> void:
	var save := SaveGame.new()
	save.stamped.append("family_farm")
	var ripe := FarmScreen.grow_time(save)
	var crop := FarmScreen.harvest_yield(save, true)
	# Ripe in 10 s, then again a grow time later (with a seed); an empty square once (with a seed).
	save.farm_growth = PackedFloat32Array([ripe - 10.0, FarmScreen.EMPTY])
	var time := 10.0 + ripe

	assert_int(Manager.harvests(save, time)).is_equal(crop)
	save.farm_seeds = 5
	assert_int(Manager.harvests(save, time)).is_equal(3 * crop)


func test_with_nothing_to_deliver_he_waits_and_comes_once_there_is() -> void:
	var manager := _manager()
	SaveManager.save.stock = 0

	_asking(manager)
	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)

	SaveManager.save.stock = 10
	_run(manager, Manager.SAMPLE_EVERY + STEP)
	assert_int(manager.phase).is_not_equal(Manager.Phase.AWAY)


func test_the_bonus_is_quota_times_price_times_reward_rounded_up() -> void:
	assert_int(Manager.bonus_for(12, 3, 1.0)).is_equal(36)
	assert_int(Manager.bonus_for(12, 3, 1.5)).is_equal(54)
	assert_int(Manager.bonus_for(3, 2, 1.1)).is_equal(7)


func test_a_met_quota_always_pays_at_least_a_coin() -> void:
	assert_int(Manager.bonus_for(0, 0, 1.0)).is_equal(1)


func test_the_manager_never_visits_before_his_card_is_stamped() -> void:
	var manager := _manager()

	_run(manager, 600.0)

	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)


func test_the_first_visit_comes_five_seconds_after_the_card() -> void:
	var manager := _manager()
	SaveManager.save.stamped.append(Manager.CARD)

	_run(manager, Manager.CARD_VISIT - 0.5)
	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)

	_run(manager, 1.0)
	assert_int(manager.phase).is_equal(Manager.Phase.ARRIVING)


func test_a_late_stamp_asks_the_pace_since_the_stamp_not_before_it() -> void:
	var manager := _manager()
	for i in 300:
		SaveManager.save.sold += 1
		manager._process(1.0)
	SaveManager.save.stamped.append(Manager.CARD)
	for i in roundi((Manager.CARD_VISIT + 0.2) / STEP):
		manager._process(STEP)

	# 300 units in the 300 s before the stamp would ask ~57; nothing sold since asks the least.
	assert_int(manager.phase).is_not_equal(Manager.Phase.AWAY)
	assert_int(manager.quota).is_equal(Manager.MIN_QUOTA)


func test_once_he_has_arrived_he_asks_his_quota_and_counts_down_the_time_given() -> void:
	var manager := _manager()

	_asking(manager)

	assert_int(manager.phase).is_equal(Manager.Phase.QUOTA)
	assert_int(manager.quota).is_equal(Manager.MIN_QUOTA)
	assert_float(manager.left).is_between(SaveManager.save.manager_time - 1.0, SaveManager.save.manager_time)


func test_only_units_moved_since_he_asked_count_toward_the_quota() -> void:
	var manager := _manager()
	SaveManager.save.sold = 50
	_asking(manager)

	SaveManager.save.sold += manager.quota - 1
	_run(manager, STEP)
	assert_int(manager.phase).is_equal(Manager.Phase.QUOTA)

	SaveManager.save.sold += 1
	_run(manager, STEP)
	assert_int(manager.phase).is_equal(Manager.Phase.VERDICT)
	assert_bool(manager.met).is_true()


func test_a_met_quota_throws_in_the_bonus_and_counts_as_met() -> void:
	var manager := _manager()
	SaveManager.save.sale_price = 4
	SaveManager.save.manager_reward = 1.5
	_asking(manager)

	SaveManager.save.sold += manager.quota
	_run(manager, STEP)

	var bonus := Manager.bonus_for(manager.quota, 4, 1.5)
	assert_int(manager.bonus).is_equal(bonus)
	assert_int(manager.coins.get("paid")).is_equal(bonus)
	assert_int(SaveManager.save.quotas_met).is_equal(1)
	assert_int(SaveManager.save.quotas_missed).is_equal(0)


func test_a_missed_quota_posts_a_performance_concern_and_pays_nothing() -> void:
	var manager := _manager()
	_asking(manager)

	_run(manager, SaveManager.save.manager_time + STEP)

	assert_int(manager.phase).is_equal(Manager.Phase.VERDICT)
	assert_bool(manager.met).is_false()
	assert_int(SaveManager.save.quotas_missed).is_equal(1)
	assert_int(SaveManager.save.quotas_met).is_equal(0)
	assert_int(manager.coins.get("paid")).is_equal(0)
	assert_int((manager.memo.get("posted") as Array).size()).is_equal(1)
	assert_str(manager.memo.get("posted")[0].re).is_equal("PERFORMANCE CONCERN")


func test_no_quota_starts_while_a_war_is_on() -> void:
	var manager := _manager()
	WarSheet.at_war = true

	_asking(manager)
	_run(manager, 60.0)

	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)
	assert_bool(manager.on_hold).is_true()


func test_a_running_quota_neither_meets_nor_misses_while_a_war_is_on() -> void:
	var manager := _manager()
	_asking(manager)
	WarSheet.at_war = true

	SaveManager.save.sold += manager.quota * 2  # Sold during the war: doesn't count.
	_run(manager, SaveManager.save.manager_time * 2.0)

	assert_int(manager.phase).is_equal(Manager.Phase.QUOTA)
	assert_int(SaveManager.save.quotas_met + SaveManager.save.quotas_missed).is_equal(0)
	WarSheet.at_war = false
	_run(manager, STEP)
	assert_int(manager.phase).is_equal(Manager.Phase.QUOTA)  # The war's sales still don't count after it.


func test_after_the_war_the_quota_resumes_with_the_same_time_left() -> void:
	var manager := _manager()
	_asking(manager)
	var left := manager.left
	WarSheet.at_war = true

	_run(manager, 30.0)
	assert_float(manager.left).is_equal(left)
	WarSheet.at_war = false
	_run(manager, STEP)

	assert_float(manager.left).is_equal_approx(left - STEP, 0.001)
	assert_bool(manager.on_hold).is_false()


func test_after_the_verdict_he_leaves_and_returns_two_and_a_half_to_four_minutes_later() -> void:
	var manager := _manager()
	_asking(manager)
	_run(manager, SaveManager.save.manager_time + STEP)

	_run(manager, Manager.VERDICT_TIME + Manager.LEAVE_TIME + 0.3)

	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)
	assert_float(manager._wait).is_between(Manager.VISIT_EVERY.x, Manager.VISIT_EVERY.y)


func test_the_manager_comes_five_seconds_after_his_card_and_a_minute_after_a_load() -> void:
	assert_float(Manager.first_wait(false)).is_equal(5.0)
	assert_float(Manager.first_wait(true)).is_equal(60.0)


func test_once_the_supply_console_is_gone_the_manager_counts_no_crates() -> void:
	var save := SaveGame.new()
	save.stock = 2
	save.buy_unlocked = true
	save.coins = 100
	assert_float(Manager.supply(save)).is_equal(INF)  # A pack pays for itself: all of them count.
	save.stamped.append("market_intelligence")
	assert_float(Manager.supply(save)).is_equal(2.0)
	assert_int(Manager.deliverable(save, 1)).is_equal(2)


func test_a_farm_square_counts_at_its_own_yield_in_what_the_farm_can_bring_in() -> void:
	var save := SaveGame.new()
	save.stamped.append("family_farm")
	var ripe := FarmScreen.grow_time(save)
	save.farm_plots = 2
	save.farm_growth = PackedFloat32Array([ripe, ripe])  # Both ripe now; no seeds to replant.
	var plain := FarmScreen.harvest_yield(save, true)
	assert_int(Manager.harvests(save, 10.0)).is_equal(2 * plain)
	save.farms_owned.append("K-1")
	save.farm_squares.append(1)
	assert_int(Manager.harvests(save, 10.0)).is_equal(plain + roundi(plain * save.farm_square_mult))
	# One seed for the replant: it goes to the farm square.
	save.farm_seeds = 1
	assert_int(Manager.harvests(save, ripe + 10.0)).is_equal(plain + 2 * roundi(plain * save.farm_square_mult))



func test_condensed_drops_let_head_office_ask_for_twice_as_many_cabbages() -> void:
	var save := _stocked(1)
	var single := Manager.deliverable(save, 0)
	UpgradeDesk.apply("condense", save)
	# Each drop now holds two; the rotten share is floored after doubling.
	assert_int(Manager.deliverable(save, 0)).is_between(single * 2, single * 2 + 1)


func test_after_two_quotas_missed_in_a_row_head_office_asks_a_fifth_less() -> void:
	assert_int(Manager.eased(20, 0)).is_equal(20)
	assert_int(Manager.eased(20, 1)).is_equal(20)
	assert_int(Manager.eased(20, 2)).is_equal(16)


func test_the_eased_target_does_not_compound_with_more_misses() -> void:
	assert_int(Manager.eased(20, 5)).is_equal(16)


func test_an_eased_quota_still_asks_for_at_least_one_cabbage_and_nothing_stays_nothing() -> void:
	assert_int(Manager.eased(1, 2)).is_equal(1)
	assert_int(Manager.eased(0, 2)).is_equal(0)


func test_misses_in_a_row_are_counted_and_a_met_quota_clears_them() -> void:
	var manager := _manager()
	_asking(manager)
	_run(manager, SaveManager.save.manager_time + STEP)
	assert_int(SaveManager.save.quota_misses_row).is_equal(1)

	SaveManager.save.quota_misses_row = 3
	manager._verdict(SaveManager.save, true)
	assert_int(SaveManager.save.quota_misses_row).is_equal(0)


func test_after_two_misses_in_a_row_the_visit_says_head_office_revised_the_target() -> void:
	var manager := _manager()
	SaveManager.save.quota_misses_row = 2
	SaveManager.save.stock = 100
	_asking(manager)

	assert_bool(manager.revised).is_true()


func test_a_visit_after_a_single_miss_is_not_revised() -> void:
	var manager := _manager()
	SaveManager.save.quota_misses_row = 1
	SaveManager.save.stock = 100
	_asking(manager)

	assert_bool(manager.revised).is_false()


func test_the_manager_never_comes_again_once_the_gun_is_bought() -> void:
	var save := SaveGame.new()
	save.stamped.append(Manager.CARD)
	assert_bool(Manager.visits(save)).is_true()
	save.stamped.append(Manager.Feeder.Events.GUN_CARD)
	assert_bool(Manager.visits(save)).is_false()


func test_a_manager_at_the_window_when_the_ending_starts_is_gone_at_once() -> void:
	var manager := _manager()
	_asking(manager)
	assert_int(manager.phase).is_equal(Manager.Phase.QUOTA)
	SaveManager.save.stamped.append(Manager.Feeder.Events.GUN_CARD)
	_run(manager, STEP)
	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)
	assert_bool(manager._shadow.visible).is_false()
	_run(manager, 600.0)
	assert_int(manager.phase).is_equal(Manager.Phase.AWAY)  # And he never comes back.
