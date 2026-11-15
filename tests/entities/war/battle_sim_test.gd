extends GdUnitTestSuite


func test_a_text_layout_gives_each_kind_its_footprint_a_zone_its_size_and_walls_a_cell_each() -> void:
	var layout := BattleSim.parse_layout("farmhouse@14,4; silo@9,5; cctv@3,1; zone@0,3,3x5; wall_stone@7,0,1x3")
	assert_array(layout.slice(0, 4)).is_equal([
		{kind = "farmhouse", cell = Vector2i(14, 4), size = Vector2i(2, 2)},
		{kind = "silo", cell = Vector2i(9, 5), size = Vector2i(2, 2)},
		{kind = "cctv", cell = Vector2i(3, 1), size = Vector2i.ONE},
		{kind = "zone", cell = Vector2i(0, 3), size = Vector2i(3, 5)}])
	assert_array(layout.slice(4).map(func(e: Dictionary) -> Vector2i: return e.cell)).is_equal([Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 2)])


func test_a_text_layout_reads_terrain_rectangles_whole_and_hedges_and_bridges_a_cell_each() -> void:
	var layout := BattleSim.parse_layout("pond@1,2,3x2; river@7,0,1x11; road@0,9,6x1; field@12,1,4x3; bridge@7,5; hedge@5,0,1x3")
	assert_array(layout.slice(0, 5)).is_equal([
		{kind = "pond", cell = Vector2i(1, 2), size = Vector2i(3, 2)},
		{kind = "river", cell = Vector2i(7, 0), size = Vector2i(1, 11)},
		{kind = "road", cell = Vector2i(0, 9), size = Vector2i(6, 1)},
		{kind = "field", cell = Vector2i(12, 1), size = Vector2i(4, 3)},
		{kind = "bridge", cell = Vector2i(7, 5), size = Vector2i.ONE}])
	assert_array(layout.slice(5).map(func(e: Dictionary) -> String: return "%s %s %s" % [e.kind, e.cell, e.size])) 			.is_equal(["hedge (5, 0) (1, 1)", "hedge (5, 1) (1, 1)", "hedge (5, 2) (1, 1)"])


func test_a_text_army_knows_every_units_short_name_counts_places_and_drop_times() -> void:
	var plan := BattleSim.parse_plan("fa x2 @z0+1,-0.5; rc @3.5,5.5 t2; sa; pc; cr")
	assert_array(plan.map(func(e: Dictionary) -> String: return e.unit)).is_equal(WarRules.UNITS)
	assert_dict(plan[0]).is_equal({unit = "field_associate", zone = 0, count = 2, offset = Vector2(1.0, -0.5)})
	assert_dict(plan[1]).is_equal({unit = "restructuring_charge", pos = Vector2(3.5, 5.5), at = 2.0})


func test_a_text_scenario_plays_out_like_the_same_layout_built_by_hand() -> void:
	var by_hand := [{kind = "farmhouse", cell = Vector2i(8, 3), size = Vector2i(2, 2)}, {kind = "zone", cell = Vector2i(0, 3), size = Vector2i.ONE}]
	var r := BattleSim.run(BattleSim.parse_layout("farmhouse@8,3; zone@0,3"), Vector2i(12, 8), BattleSim.parse_plan("fa x2"))
	var same := BattleSim.run(by_hand, Vector2i(12, 8), [{unit = "field_associate", zone = 0, count = 2}])
	assert_bool(r.won).is_true()
	assert_float(r.seconds).is_equal(same.seconds)


# ---- The map difficulty calculator and the counters (research/war-balance.md). Counter rules are
# measured like the --matrix: on the war sheet's grid, the defences where tutorial 2 has its cannon (a
# pair: above and below it), the cheapest winning army by cabbages; at k 2 (where the unit cards
# arrive) unless the associates need k 1 to win at all (splash: soft counters, research/war-balance.md).

const SHEET := Vector2i(20, 11)
const BEFORE := "farmhouse@14,4; zone@0,3,3x5"
## A 1-cell masonry ring round the cannon at (9, 5).
const FENCED_TOWER := "cannon@9,5; wall_stone@8,4,3x1; wall_stone@8,6,3x1; wall_stone@8,5; wall_stone@10,5; " + BEFORE
const MAILING_IN_MASONRY := "mortar@9,5; wall_stone@8,4,4x1; wall_stone@8,7,4x1; wall_stone@8,5,1x2; wall_stone@11,5,1x2; " + BEFORE


## Text layout: a pair of `kind` before the farmhouse.
func _pair(kind: String) -> String:
	var two := WarMap.size_of(kind).y
	return "%s@9,%d; %s@9,%d; %s" % [kind, 4 - two, kind, 6 + two - 1, BEFORE]


## Cabbages of playstyle `style`'s cheapest winning army on `layout` (0: none wins).
func _cost(layout: String, style: String, options := {k = 2.0}) -> int:
	var e := BattleSim.cheapest(BattleSim.parse_layout(layout), SHEET, style, options)
	return e.get("cabbages", 0) if e.get("won", false) else 0


## Asserts `style` wins `layout` at no more than `share` of what associates alone cost (both win).
func _counters(layout: String, style: String, share := 0.75, options := {k = 2.0}) -> void:
	var associates := _cost(layout, "associates", options)
	var counter := _cost(layout, style, options)
	assert_int(associates).override_failure_message("associates never win").is_greater(0)
	assert_int(counter).override_failure_message("%s never wins" % style).is_greater(0)
	assert_float(float(counter)).override_failure_message("%s %d vs associates %d" % [style, counter, associates]) 			.is_less_equal(share * associates)


func _maps() -> Array[WarMap]:
	var out: Array[WarMap] = []
	for path: String in WarMap.map_paths():
		out.append(auto_free(load(path).instantiate()))
	return out


func test_assess_finds_a_cheapest_winning_army_for_every_existing_map() -> void:
	for map in _maps():
		var a := BattleSim.assess(map.layout(), map.grid_size)
		assert_bool(a.best.get("won", false)).override_failure_message(map.name).is_true()
		for e: Dictionary in a.styles:
			if e.won:
				assert_int(e.cabbages).is_greater_equal(a.best.cabbages)
				assert_bool(BattleSim.trial(map.layout(), map.grid_size, e.army, e.zones).won).is_true()


func test_every_existing_map_falls_to_associates_alone() -> void:
	for map in _maps():
		var a := BattleSim.assess(map.layout(), map.grid_size, {units = ["field_associate"], level = "full"})
		assert_bool(a.best.get("won", false)).override_failure_message(map.name).is_true()
		assert_bool(a.best.fits).override_failure_message(map.name).is_true()


func test_the_test_map_is_the_k_ladders_unit_strength() -> void:
	var map: WarMap = auto_free(load(WarMap.DEFAULT).instantiate())
	assert_float(BattleSim.assess(map.layout(), map.grid_size, {units = ["field_associate"]}).k_associates).is_equal_approx(1.0, 0.001)


func test_a_plan_puts_tanks_in_front_and_pults_behind_inside_the_zone() -> void:
	var layout := BattleSim.parse_layout("cannon@9,5; " + BEFORE)
	var plan := BattleSim.plan_for({senior_asset = 1, field_associate = 2, pult_crew = 1}, layout, [0])
	assert_array(plan.map(func(e: Dictionary) -> String: return e.unit)).is_equal(["senior_asset", "field_associate", "field_associate", "pult_crew"])
	assert_float(plan[0].pos.x).is_greater(plan[1].pos.x)
	assert_float(plan[1].pos.x).is_greater(plan[3].pos.x)
	for e: Dictionary in plan:
		assert_bool(Rect2(0, 3, 3, 5).has_point(e.pos)).is_true()


func test_pults_take_a_shredder_cheaper_than_associates() -> void:
	_counters(_pair("shredder"), "pults", 0.6)


func test_pults_take_a_sprinkler_cheaper_than_associates() -> void:
	_counters(_pair("sprinkler"), "pults", 0.6, {})


func test_pults_take_a_silo_cheaper_than_associates() -> void:
	_counters(_pair("silo"), "pults", 0.6, {})


func test_a_charge_behind_associates_opens_a_fenced_tower_cheaper_than_associates_alone() -> void:
	_counters(FENCED_TOWER, "charge")


func test_senior_assets_take_the_cctv_mast_cheaper_than_associates() -> void:
	_counters(_pair("cctv"), "tank")


func test_a_senior_asset_in_front_takes_a_tower_cheaper_than_associates() -> void:
	_counters("cannon@9,5; farmhouse@17,0; zone@0,3,3x5", "tank", 0.75, {k = 2.0, goal = "defences"})


func test_a_courier_rush_takes_the_mailing_unit_cheaper_than_associates() -> void:
	_counters(MAILING_IN_MASONRY, "couriers")


func test_senior_assets_pay_more_than_associates_at_the_shredder() -> void:
	assert_int(_cost(_pair("shredder"), "seniors")).is_greater(_cost(_pair("shredder"), "associates"))


func test_pults_pay_more_than_associates_at_a_tower() -> void:
	assert_int(_cost(_pair("cannon"), "pults")).is_greater(_cost(_pair("cannon"), "associates"))


func test_couriers_pay_more_than_associates_at_the_silo() -> void:
	assert_int(_cost(_pair("silo"), "couriers", {})).is_greater(_cost(_pair("silo"), "associates", {}))


func test_pults_take_a_silo_cheaper_than_senior_assets() -> void:
	var seniors := _cost(_pair("silo"), "seniors", {})  # The burst takes a share of a parked tank's health.
	assert_float(float(_cost(_pair("silo"), "pults", {}))).is_less_equal(0.75 * seniors)
	assert_float(float(_cost(_pair("silo"), "pults"))).is_less_equal(0.75 * _cost(_pair("silo"), "seniors"))


## Editing a map without `tools/battle_sim.gd -- --write-all` fails here.
func test_every_maps_stored_difficulty_matches_the_calculator() -> void:
	for map in _maps():
		var want := BattleSim.difficulty(map.layout(), map.grid_size)
		var stored: Dictionary = map.difficulty
		var stale := "%s: rerun --write-all" % map.name
		assert_array(stored.keys()).override_failure_message(stale).contains_exactly_in_any_order(want.keys())
		for key: String in want:
			if key == "k":  # Stored to 0.01; a scene round-trip may add float noise.
				assert_float(float(stored.k)).override_failure_message(stale).is_equal_approx(want.k, 0.001)
			else:
				assert_that(stored.get(key)).override_failure_message(stale).is_equal(want[key])


func test_the_declaration_reads_the_band_the_associates_and_the_best_style_without_a_fight() -> void:
	var save := SaveGame.new()
	save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3", "K-4", "K-5", "K-6"])  # The second war at home: K-7's map.
	var d := WarMap.difficulty_for(&"K-7", save)
	assert_int(d.band).is_equal(1)
	assert_str(d.band_name).is_equal("ROUTINE")
	assert_int(d.associates).is_equal(3)
	assert_str(d.style).is_equal("seniors")
	assert_int(WarMap.difficulty_for(&"K-7", save, 3).associates).is_equal(3)
	assert_int(WarMap.difficulty_for(&"K-7", save, 2).associates).is_equal(-1)  # More than the cap.


## tools/pace.py's DEFENCE: the 19 wars' target strengths.
func test_the_k_ladder_spreads_over_all_five_bands() -> void:
	var counts := [0, 0, 0, 0, 0]
	for k in [1.0, 1.0, 1.15, 1.26, 1.4, 1.54, 1.64, 1.78, 1.91, 2.03, 2.16, 2.28, 2.4, 2.52, 2.67, 2.78, 2.9, 3.01, 3.42]:
		counts[WarMap.band_of(k) - 1] += 1
	for c: int in counts:
		assert_int(c).is_between(2, 6)


## research/war-maps.md: the 19 maps in war order, each built to read its planned band (tutorials
## ROUTINE; K-8 to Ostrevia 1 MODERATE; Ostrevia 2 to Sulvania 3 SERIOUS; Grauland to Morrow 1 SEVERE;
## Morrow 2 to Endmark Isle CATASTROPHIC).
func test_every_campaign_map_reads_the_band_its_war_was_planned_for() -> void:
	var plan := {"K-6": 1, "K-7": 1, "K-8": 2, "veldmark-1": 2, "veldmark-2": 2, "ostrevia-1": 2, "ostrevia-2": 3,
			"sulvania-1": 3, "sulvania-2": 3, "sulvania-3": 3, "grauland-1": 4, "grauland-2": 4, "lower_provinces-1": 4,
			"lower_provinces-2": 4, "morrow-1": 4, "morrow-2": 5, "nordhal-1": 5, "nordhal-2": 5, "endmark-1": 5}
	for id: String in plan:
		var map: WarMap = auto_free(load(WarMap.MAPS + id + ".tscn").instantiate())
		assert_int(WarMap.band_of(map.difficulty.k)).override_failure_message(id).is_equal(plan[id])


func test_a_map_no_army_can_take_stores_k_99_and_no_associates() -> void:
	var d := BattleSim.difficulty(BattleSim.parse_layout("farmhouse@14,4"), Vector2i(18, 10))
	assert_float(d.k).is_equal(99.0)
	assert_int(d.associates).is_equal(-1)
	assert_str(d.style).is_empty()


func test_a_drop_due_after_the_time_limit_does_not_keep_a_wiped_army_in_the_fight() -> void:
	var r := BattleSim.run(BattleSim.parse_layout("farmhouse@14,4; cannon@4,3; zone@1,3"), Vector2i(18, 10),
			BattleSim.parse_plan("fa; fa t999"), PackedStringArray(), 50.0)
	assert_int(r.end).is_equal(WarFight.End.WIPED)
	assert_int(r.refused).is_equal(1)
