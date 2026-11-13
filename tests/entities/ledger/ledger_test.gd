extends GdUnitTestSuite


func _summary(save: SaveGame, seconds: int) -> Dictionary:
	var rows := {}
	for row: Array in Ledger.summary_rows(save, seconds):
		rows[row[0]] = row[1]
	return rows


func _buy(save: SaveGame, count: int) -> void:
	for i in count:
		save.playtest_log.append(save.log_entry(1000 + i, "node", "pack_1", 50, "coins"))


func test_the_ledger_waits_for_its_desk_card() -> void:
	var save := SaveGame.new()
	assert_bool(Ledger.unlocked(save)).is_false()
	save.stamped = PackedStringArray(["stats_ledger"])
	assert_bool(Ledger.unlocked(save)).is_true()


func test_play_time_reads_as_hours_minutes_and_seconds() -> void:
	assert_str(Ledger.clock(3723)).is_equal("1:02:03")
	assert_str(Ledger.clock(59)).is_equal("0:00:59")
	assert_str(Ledger.clock(0)).is_equal("0:00:00")
	assert_str(Ledger.clock(360000)).is_equal("100:00:00")


func test_findings_are_written_in_pilcrows_coins_in_dollars_and_cabbages_as_a_bare_number_beside_the_icon() -> void:
	assert_str(Ledger.money(10, "findings")).is_equal("¶10")
	assert_str(Ledger.money(12, "coins")).is_equal("$12")
	assert_str(Ledger.money(12, "")).is_equal("$12")
	assert_str(Ledger.money(60, "stock")).is_equal("60")
	assert_bool(UpgradeCard.shows_icon("stock")).is_true()
	assert_bool(UpgradeCard.shows_icon("coins")).is_false()
	assert_bool(UpgradeCard.shows_icon("findings")).is_false()


func test_the_summary_reports_the_save_as_written_figures() -> void:
	var save := SaveGame.new()
	save.sold = 40
	save.catches = 10
	save.coins = 120
	save.findings = 7
	save.sale_price = 5
	save.marketing = 1.5
	save.hands = 2
	var rows := _summary(save, 3723)
	assert_str(rows["CABBAGES MOVED"]).is_equal("40")
	assert_str(rows["CABBAGES INTERCEPTED MID-AIR"]).is_equal("10")
	assert_str(rows["INTERCEPTION RATE"]).is_equal("25%")
	assert_str(rows["CABBAGES IN INVENTORY"]).is_equal("%d / 20" % save.stock)
	assert_str(rows["COINS ON HAND"]).is_equal("$120")
	assert_str(rows["FINDINGS FILED"]).is_equal("¶7")
	assert_str(rows["PRICE PER CABBAGE"]).is_equal("$5")
	assert_str(rows["MARKETING MULTIPLIER"]).is_equal("x1.50")
	assert_str(rows["HANDS EMPLOYED"]).is_equal("2")
	assert_str(rows["TIME ON SHIFT"]).is_equal("1:02:03")


func test_the_interception_rate_is_rounded_and_zero_before_the_first_sale() -> void:
	var save := SaveGame.new()
	assert_str(_summary(save, 0)["INTERCEPTION RATE"]).is_equal("0%")
	save.sold = 3
	save.catches = 2
	assert_str(_summary(save, 0)["INTERCEPTION RATE"]).is_equal("67%")


func test_a_huge_fortune_is_written_out_in_full() -> void:
	var save := SaveGame.new()
	save.coins = 2000000000
	assert_str(_summary(save, 0)["COINS ON HAND"]).is_equal("$2000000000")


func test_requisitions_list_every_card_and_node_bought_newest_first_with_its_title_time_and_price() -> void:
	var save := SaveGame.new()
	save.playtest_log.append(save.log_entry(5, "session", "0"))
	save.playtest_log.append(save.log_entry(30, "snapshot"))
	save.playtest_log.append(save.log_entry(65, "card", "price_slate", 12, "coins"))
	save.playtest_log.append(save.log_entry(700, "node", "slogan_1", 70, "coins"))
	save.playtest_log.append(save.log_entry(900, "card", "street_posters", 10, "findings"))
	var reqs := Ledger.requisitions(save)
	assert_array(reqs).has_size(3)
	assert_array(reqs[0]).is_equal(["T+0:15:00", "STREET POSTER CAMPAIGN", "¶10", "findings"])
	assert_array(reqs[1]).is_equal(["T+0:11:40", "SLOGAN I", "$70", "coins"])
	assert_array(reqs[2]).is_equal(["T+0:01:05", "PRICE SLATE", "$12", "coins"])


func test_a_purchase_of_an_unknown_id_is_filed_under_its_id_in_capitals() -> void:
	var save := SaveGame.new()
	save.playtest_log.append(save.log_entry(1, "card", "retired_card", 3, "coins"))
	assert_array(Ledger.requisitions(save)[0]).is_equal(["T+0:00:01", "RETIRED_CARD", "$3", "coins"])


## A save earning `per_minute` coins steadily, logged on the minute, with purchases in between that
## spend most of what is held.
func _earning(per_minute: int, minutes: int) -> SaveGame:
	var save := SaveGame.new()
	for m in minutes + 1:
		save.coins_earned = m * per_minute
		save.coins = 10
		save.playtest_log.append(save.log_entry(m * 60, "minute"))
	return save


func _rates(points: PackedVector2Array) -> Array:
	return Array(points).map(func(p: Vector2) -> float: return p.y)


func test_the_income_line_plots_coins_earned_per_minute() -> void:
	var save := _earning(100, 3)
	var points := Ledger.rate_points(save.playtest_log, ["coins_earned"], 180, save.coins_earned, 60)
	assert_array(Array(points)).is_equal([Vector2(60, 100), Vector2(120, 100), Vector2(180, 100)])


func test_a_purchase_does_not_dent_the_income_line() -> void:
	var save := _earning(100, 3)
	# Mid-minute purchases (one card in two currencies: two rows, same second) spend the coins held.
	save.coins_earned = 150
	save.coins = 0
	save.playtest_log.insert(2, save.log_entry(90, "card", "consolidation", 140, "coins"))
	save.playtest_log.insert(3, save.log_entry(90, "card", "consolidation", 20, "findings"))
	save.coins_earned = 300
	var points := Ledger.rate_points(save.playtest_log, ["coins_earned"], 180, save.coins_earned, 60)
	assert_array(_rates(points)).is_equal([100.0, 100.0, 100.0])


func test_minute_rows_landing_a_second_late_do_not_spike_the_line() -> void:
	var entries := [{t = 0, coins_earned = 0}, {t = 61, coins_earned = 61}, {t = 122, coins_earned = 122},
			{t = 150, coins_earned = 150}]
	var points := Ledger.rate_points(entries, ["coins_earned"], 185, 185, 60)
	assert_array(Array(points).map(func(p: Vector2) -> float: return p.x)).is_equal([60.0, 120.0, 180.0])
	for rate: float in _rates(points):
		assert_float(rate).is_equal_approx(60.0, 0.01)


func test_the_unfinished_minute_is_not_plotted() -> void:
	var save := _earning(100, 2)
	var points := Ledger.rate_points(save.playtest_log, ["coins_earned"], 170, save.coins_earned + 10, 60)
	assert_array(Array(points).map(func(p: Vector2) -> float: return p.x)).is_equal([60.0, 120.0])


func test_a_long_shift_is_bucketed_into_wider_intervals_still_read_per_minute() -> void:
	assert_int(Ledger.chart_step(30 * 60)).is_equal(60)
	assert_int(Ledger.chart_step(61 * 60)).is_equal(120)
	assert_int(Ledger.chart_step(5 * 3600)).is_equal(300)
	for hours in [1, 3, 10, 40]:
		assert_float(hours * 3600.0 / Ledger.chart_step(hours * 3600)).is_less_equal(Ledger.CHART_POINTS)
	var save := _earning(100, 4)
	assert_array(_rates(Ledger.rate_points(save.playtest_log, ["coins_earned"], 240, save.coins_earned, 120))).is_equal([100.0, 100.0])


func test_the_findings_line_stays_hidden_until_findings_were_earned() -> void:
	var save := _earning(100, 3)
	var none := Ledger.rate_points(save.playtest_log, ["findings_earned"], 180, 0, 60)
	assert_bool(Ledger.shows_line(none)).is_false()
	save.playtest_log[2].findings_earned = 4
	save.playtest_log[3].findings_earned = 4
	var some := Ledger.rate_points(save.playtest_log, ["findings_earned"], 180, 4, 60)
	assert_bool(Ledger.shows_line(some)).is_true()
	assert_array(_rates(some)).is_equal([0.0, 4.0, 0.0])


func test_a_log_from_an_older_build_without_the_earned_columns_gives_no_line_instead_of_a_crash() -> void:
	var old := [{t = 10, kind = "session", coins = 0}, {t = 30, kind = "snapshot", coins = 40}, {t = 60, kind = "snapshot"}]
	assert_array(Array(Ledger.rate_points(old, ["coins_earned"], 200, 500, 60))).is_empty()
	assert_array(Array(Ledger.rate_points([], ["coins_earned"], 0, 0, 60))).is_empty()
	# Once the column turns up the line starts there, without a spike for what came before.
	old.append({t = 120, kind = "minute", coins_earned = 400})
	assert_array(_rates(Ledger.rate_points(old, ["coins_earned"], 240, 600, 60))).is_equal([100.0, 100.0])


func test_chart_scales_round_up_to_one_two_or_five_steps() -> void:
	for pair: Array in [[0.0, 1.0], [0.3, 0.5], [3.0, 5.0], [5.0, 5.0], [7.0, 10.0], [12.0, 20.0], [150.0, 200.0], [2001.0, 5000.0]]:
		assert_float(Ledger.nice_step(pair[0])).override_failure_message(str(pair)).is_equal_approx(pair[1], 0.0001)


func test_chart_ticks_carry_their_sign_and_thousands_separators() -> void:
	assert_str(Ledger.tick_text(1200.0, 200.0, "$")).is_equal("$1,200")
	assert_str(Ledger.tick_text(0.0, 200.0, "$")).is_equal("$0")
	assert_str(Ledger.tick_text(1.5, 0.5, "¶")).is_equal("¶1.5")
	assert_str(Ledger.tick_text(0.6000001, 0.2, "¶")).is_equal("¶0.6")


func test_a_fresh_ledger_has_summary_earnings_and_cabbage_charts_personnel_and_one_empty_requisitions_page() -> void:
	var pages := Ledger.pages(SaveGame.new(), 0)
	assert_array(pages.map(func(p: Dictionary) -> String: return p.kind)).is_equal(["rows", "chart", "chart", "rows", "list", "blank"])
	assert_array(pages.map(func(p: Dictionary) -> String: return p.form)).is_equal(["FORM QP-1", "FORM QP-2", "FORM QP-3", "FORM HR-4", "FORM RQ-9", ""])
	assert_array(pages[4].rows).is_empty()


func test_requisitions_spill_onto_a_new_page_every_twelve_lines() -> void:
	var save := SaveGame.new()
	_buy(save, 13)
	var pages := Ledger.pages(save, 2000)
	assert_array(pages[4].rows).has_size(Ledger.REQ_PER_PAGE)
	assert_array(pages[5].rows).has_size(1)


func test_the_ledger_always_has_an_even_page_count_padded_with_a_blank_page() -> void:
	for bought: Array in [[0, 6, true], [12, 6, true], [13, 6, false], [24, 6, false], [25, 8, true]]:
		var save := SaveGame.new()
		_buy(save, bought[0])
		var pages := Ledger.pages(save, 0)
		assert_int(pages.size()).override_failure_message("%d bought" % bought[0]).is_equal(bought[1])
		assert_bool(pages.back().kind == "blank").override_failure_message("%d bought" % bought[0]).is_equal(bought[2])


func test_personnel_counts_you_plus_every_hand_and_skips_associate_stats_without_hands() -> void:
	var rows := Ledger.personnel_rows(SaveGame.new())
	assert_array(rows).is_equal([["HEADCOUNT", "1"], ["YOU", "UNDER REVIEW"]])


func test_personnel_names_up_to_seven_associates_with_their_trip_interval_and_speed() -> void:
	var save := SaveGame.new()
	save.hands = 3
	save.associate_interval = 6.5
	save.associate_speed = 1.25
	var rows := Ledger.personnel_rows(save)
	assert_array(rows[0]).is_equal(["HEADCOUNT", "4"])
	assert_array(rows).has_size(2 + 3 + 2)
	assert_array(rows.slice(2, 5).map(func(r: Array) -> String: return r[1])).is_equal(["ACTIVE", "ACTIVE", "ACTIVE"])
	assert_array(rows[5]).is_equal(["TRIP INTERVAL", "6.5 s"])
	assert_array(rows[6]).is_equal(["WALKING SPEED", "x1.25"])


func test_personnel_lumps_associates_past_the_seventh_into_one_line() -> void:
	var save := SaveGame.new()
	save.hands = 7
	assert_array(Ledger.personnel_rows(save)).has_size(2 + 7 + 2)
	save.hands = 9
	var rows := Ledger.personnel_rows(save)
	assert_array(rows[0]).is_equal(["HEADCOUNT", "10"])
	assert_array(rows).has_size(2 + 7 + 1 + 2)
	assert_array(rows[9]).is_equal(["FURTHER ASSOCIATES", "2"])


func test_esc_closes_the_open_ledger_before_the_pause_menu_can_take_it() -> void:
	var layer: Node = auto_free(load("res://entities/ledger/ledger.tscn").instantiate())
	add_child(layer)
	var ledger: Ledger = layer.get_node("Book")
	ledger._out = 1.0
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	ledger._input(esc)  # _input runs before any _unhandled_input, so the menu never sees this Esc.
	assert_bool(get_viewport().is_input_handled()).is_true()
	await get_tree().create_timer(0.5).timeout
	assert_float(ledger._out).is_equal(0.0)


func test_a_card_paid_in_several_currencies_fills_a_row_each_but_counts_as_one_requisition() -> void:
	var save := SaveGame.new()
	save.playtest_log.append(save.log_entry(65, "card", "price_slate", 12, "coins"))
	for cost: Array in [[15000, "coins"], [2000, "findings"], [900, "stock"]]:
		save.playtest_log.append(save.log_entry(7900, "card", "consolidation", cost[0], cost[1]))
	var reqs := Ledger.requisitions(save)
	assert_array(reqs.map(func(row: Array) -> String: return row[2])).is_equal(["900", "¶2000", "$15000", "$12"])
	assert_int(Ledger.approved_total(reqs)).is_equal(2)


## A debug start (5812 s on the clock, no log) played on for 14 whole minutes at 100 coins a minute.
func _recent_only() -> SaveGame:
	var save := SaveGame.new()
	for m in 15:
		save.coins_earned = m * 100
		save.playtest_log.append(save.log_entry(5812 + m * 60, "session" if m == 0 else "minute"))
	return save


func test_the_charts_time_axis_spans_the_recorded_minutes_not_the_whole_shift() -> void:
	var save := _recent_only()
	var now := 5812 + 14 * 60
	var start := Ledger.series_start(save.playtest_log, ["coins_earned"], now)
	assert_int(start).is_equal(5812)
	var step := Ledger.history_step(start, now)
	var points := Ledger.rate_points(save.playtest_log, ["coins_earned"], now, save.coins_earned, step)
	var window := Ledger.chart_window(points, step)
	assert_float(window.x).is_greater_equal(5812.0 - 60.0)
	assert_float(window.y).is_equal(points[-1].x)
	for minute in Ledger.time_ticks(window):
		assert_float(minute * 60.0).is_between(window.x, window.y)


func test_a_short_recent_history_is_read_minute_by_minute_however_long_the_shift() -> void:
	assert_int(Ledger.history_step(5812, 5812 + 14 * 60)).is_equal(60)
	assert_int(Ledger.history_step(0, 108 * 60)).is_equal(120)
	assert_int(Ledger.history_step(100, 100)).is_equal(60)


func test_a_fresh_shift_gets_a_five_minute_axis_with_its_first_readings_at_the_left() -> void:
	var window := Ledger.chart_window(PackedVector2Array([Vector2(60, 5), Vector2(120, 8)]), 60)
	assert_that(window).is_equal(Vector2(0, Ledger.MIN_SPAN))
	assert_that(Ledger.chart_window(PackedVector2Array(), 60)).is_equal(Vector2(0, Ledger.MIN_SPAN))
	assert_array(Ledger.time_ticks(window)).is_equal([0, 1, 2, 3, 4, 5])


func test_minute_ticks_are_round_and_about_six_to_a_chart() -> void:
	assert_array(Ledger.time_ticks(Vector2(5760, 6660))).is_equal([100, 105, 110])
	assert_array(Ledger.time_ticks(Vector2(0, 108 * 60))).is_equal([0, 30, 60, 90])
	assert_array(Ledger.time_ticks(Vector2(0, 20 * 60))).is_equal([0, 5, 10, 15, 20])


func test_a_line_never_runs_backwards_in_time() -> void:
	# Rows out of order and doubled (a restored log, two rows in one second) never send the line back.
	var entries := [{t = 0, sold = 0}, {t = 60, sold = 10}, {t = 60, sold = 12}, {t = 30, sold = 50},
			{t = 120, sold = 20}, {t = 200, sold = 30}]
	var points := Ledger.rate_points(entries, ["sold"], 240, 40, 60)
	for i in range(1, points.size()):
		assert_float(points[i].x).is_greater(points[i - 1].x)
	var smoothed := Ledger.smooth(points)
	for i in points.size():
		assert_float(smoothed[i].x).is_equal(points[i].x)


func test_smoothing_calms_a_burst_of_banked_coins_and_leaves_a_steady_line_alone() -> void:
	var burst := Ledger.smooth(PackedVector2Array([Vector2(60, 0), Vector2(120, 300), Vector2(180, 0), Vector2(240, 0), Vector2(300, 0)]))
	assert_array(_rates(burst)).is_equal([150.0, 100.0, 100.0, 0.0, 0.0])
	# A fresh shift's first few readings are drawn as recorded, not averaged into a flat line.
	var few := PackedVector2Array([Vector2(60, 16), Vector2(120, 8)])
	assert_array(Array(Ledger.smooth(few))).is_equal(Array(few))
	var steady := Ledger.smooth(PackedVector2Array([Vector2(60, 50), Vector2(120, 50), Vector2(180, 50)]))
	assert_array(_rates(steady)).is_equal([50.0, 50.0, 50.0])
	assert_array(Array(Ledger.smooth(PackedVector2Array()))).is_empty()


func test_the_scale_tops_out_over_the_best_reading_as_recorded() -> void:
	var points := PackedVector2Array([Vector2(60, 40), Vector2(120, 650), Vector2(180, 30)])
	assert_float(Ledger.scale_top(points)).is_equal(800.0)
	assert_float(Ledger.scale_top(points)).is_greater_equal(Ledger.peak(points))


func test_large_ticks_are_counted_in_thousands() -> void:
	assert_str(Ledger.tick_text(15000.0, 5000.0, "$")).is_equal("$15K")
	assert_str(Ledger.tick_text(2500.0, 2500.0, "$")).is_equal("$2.5K")
	assert_str(Ledger.tick_text(0.0, 5000.0, "$")).is_equal("$0K")
	assert_str(Ledger.tick_text(800.0, 200.0, "")).is_equal("800")


func test_the_earnings_page_stacks_coins_over_findings_and_the_next_page_plots_cabbages() -> void:
	var save := SaveGame.new()
	save.coins_earned = 1234
	save.findings_earned = 56
	save.sold = 70
	save.minis_sold = 30
	var pages := Ledger.pages(save, 0)
	assert_array(pages[1].rows.map(func(c: Dictionary) -> Array: return c.columns)).is_equal([["coins_earned"], ["findings_earned"]])
	assert_array(pages[1].rows.map(func(c: Dictionary) -> int: return c.total)).is_equal([1234, 56])
	assert_str(pages[2].title).is_equal("CABBAGES SOLD PER MINUTE")
	assert_int(pages[2].rows[0].total).is_equal(100)


func test_the_cabbage_page_plots_cabbages_sold_per_minute_minis_included() -> void:
	var save := SaveGame.new()
	var entries := []
	for m in 4:
		save.sold = m * 8
		save.minis_sold = m * 2
		entries.append(save.log_entry(m * 60, "minute"))
	var columns: Array = Ledger.charts(save, "cabbages")[0].columns
	assert_array(_rates(Ledger.rate_points(entries, columns, 180, save.sold + save.minis_sold, 60))).is_equal([10.0, 10.0, 10.0])
	# A log from before minis were counted gives no line rather than a spike.
	assert_array(Array(Ledger.rate_points([{t = 0, sold = 0}, {t = 60, sold = 5}], columns, 120, 9, 60))).is_empty()


func test_the_summary_reports_coins_and_findings_earned_to_date_not_what_is_left_after_spending() -> void:
	var save := SaveGame.new()
	save.coins = 40
	save.coins_earned = 12500
	save.findings = 3
	save.findings_earned = 980
	var rows := _summary(save, 0)
	assert_str(rows["COINS EARNED TO DATE"]).is_equal("$12,500")
	assert_str(rows["FINDINGS EARNED TO DATE"]).is_equal("¶980")
	assert_str(rows["COINS ON HAND"]).is_equal("$40")