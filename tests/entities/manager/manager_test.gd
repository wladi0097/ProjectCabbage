extends GdUnitTestSuite

const MANAGER := preload("res://entities/manager/manager.tscn")
const STEP := 0.1
const FAKE_COINS := "extends CoinPile\nvar paid := 0\nfunc _ready() -> void:\n\tpass\nfunc _process(_delta: float) -> void:\n\tpass\nfunc throw_in_after(_delay: float, _origin: Vector3, amount: int) -> void:\n\tpaid += amount\n"
const FAKE_MEMO := "extends Node\nvar posted: Array[Dictionary] = []\nfunc post(m: Dictionary) -> void:\n\tposted.append(m)\n"

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


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
