extends GdUnitTestSuite
## One rule per campaign map that pins its lesson (research/war-maps.md section 2). Each builder
## appends its own block.


# --- Sulvania and Grauland (sulvania-1..3, grauland-1..2) ---

## Whether `army` (unit id -> figures) takes map `id` from zones `use`; `full`: every research node.
func _sg_won(id: String, army: Dictionary, use: Array, full := false) -> bool:
	var map: WarMap = load(WarMap.MAPS + id + ".tscn").instantiate()
	var layout := map.layout()
	var grid := map.grid_size
	map.free()
	var options := {research = BattleSim.research_for("full")} if full else {}
	return BattleSim.trial(layout, grid, army, use, options).won


func test_the_reception_line_falls_from_the_unbuilt_end_and_holds_against_the_top_lane() -> void:
	assert_bool(_sg_won("sulvania-1", {field_associate = 7}, [2])).is_true()
	assert_bool(_sg_won("sulvania-1", {field_associate = 7}, [0])).is_false()


func test_a_senior_asset_in_front_takes_the_north_toll_bridge_cheaper_than_associates_alone() -> void:
	assert_bool(_sg_won("sulvania-2", {senior_asset = 1, field_associate = 4}, [0])).is_true()
	assert_bool(_sg_won("sulvania-2", {field_associate = 7}, [1])).is_false()
	assert_bool(_sg_won("sulvania-2", {field_associate = 8}, [1])).is_true()


func test_the_scenic_drive_is_a_trap_and_a_side_lane_takes_the_heights() -> void:
	assert_bool(_sg_won("sulvania-3", {field_associate = 9}, [2])).is_true()
	assert_bool(_sg_won("sulvania-3", {field_associate = 9}, [0])).is_false()


func test_a_senior_asset_leading_one_associate_takes_the_heights_for_less_than_five_associates() -> void:
	assert_bool(_sg_won("sulvania-3", {senior_asset = 1, field_associate = 1}, [1], true)).is_true()
	assert_bool(_sg_won("sulvania-3", {field_associate = 4}, [1], true)).is_false()
	assert_bool(_sg_won("sulvania-3", {field_associate = 4}, [2], true)).is_false()


func test_a_crowd_gets_past_the_front_desk_where_a_lone_senior_asset_is_shredded() -> void:
	assert_bool(_sg_won("grauland-1", {field_associate = 10}, [0])).is_true()
	assert_bool(_sg_won("grauland-1", {senior_asset = 1}, [0])).is_false()
	assert_bool(_sg_won("grauland-1", {senior_asset = 1, pult_crew = 1}, [0], true)).is_true()
	assert_bool(_sg_won("grauland-1", {field_associate = 5}, [0], true)).is_false()


func test_pults_take_the_corner_office_from_the_bottom_left_with_every_research() -> void:
	assert_bool(_sg_won("grauland-2", {pult_crew = 3}, [0], true)).is_true()
	assert_bool(_sg_won("grauland-2", {field_associate = 10}, [1])).is_true()
	assert_bool(_sg_won("grauland-2", {field_associate = 9}, [1])).is_false()


# --- Kohlmark, Veldmark and Ostrevia (K-8, veldmark-1..2, ostrevia-1..2) ---

## Whether `army` (unit id -> figures) takes map `id` from zones `use`, with depot nodes `research`.
func _vo_won(id: String, army: Dictionary, use: Array, research := PackedStringArray()) -> bool:
	var map: WarMap = load(WarMap.MAPS + id + ".tscn").instantiate()
	var layout := map.layout()
	var grid := map.grid_size
	map.free()
	return BattleSim.trial(layout, grid, army, use, {research = research}).won


func test_the_last_neighbour_takes_four_associates_and_three_with_body_armour() -> void:
	assert_bool(_vo_won("K-8", {field_associate = 4}, [0, 1])).is_true()
	assert_bool(_vo_won("K-8", {field_associate = 3}, [0, 1])).is_false()
	assert_bool(_vo_won("K-8", {field_associate = 3}, [0], PackedStringArray(["fa_hp_1"]))).is_true()


func test_the_gated_community_opens_at_the_garden_gate_or_with_a_charge_at_the_front() -> void:
	assert_bool(_vo_won("veldmark-1", {field_associate = 4}, [1])).is_true()
	assert_bool(_vo_won("veldmark-1", {field_associate = 4}, [0])).is_false()
	assert_bool(_vo_won("veldmark-1", {field_associate = 4}, [0], PackedStringArray(["fa_hp_1"]))).is_false()
	# With BODY ARMOUR, three at the front and a charge set apart from them (a mailing crate meant
	# for the crowd would take it on the way) open the masonry where the player wants it.
	var map: WarMap = auto_free(load(WarMap.MAPS + "veldmark-1.tscn").instantiate())
	var plan := [{unit = "field_associate", pos = Vector2(1.5, 4.75)}, {unit = "field_associate", pos = Vector2(1.5, 5.25)},
			{unit = "field_associate", pos = Vector2(1.5, 5.75)}, {unit = "restructuring_charge", pos = Vector2(0.5, 7.5)}]
	assert_bool(BattleSim.run(map.layout(), map.grid_size, plan, PackedStringArray(["fa_hp_1"])).won).is_true()


func test_visitor_management_falls_from_the_top_strip_and_watches_the_long_walk_to_death() -> void:
	assert_bool(_vo_won("veldmark-2", {field_associate = 5}, [1])).is_true()
	assert_bool(_vo_won("veldmark-2", {field_associate = 5}, [0])).is_false()


func test_the_mail_room_falls_to_a_line_of_associates_from_a_strip_beside_the_nest() -> void:
	assert_bool(_vo_won("ostrevia-1", {field_associate = 5}, [2])).is_true()
	assert_bool(_vo_won("ostrevia-1", {field_associate = 4}, [2])).is_false()


func test_the_retention_ponds_wash_out_one_crowd_but_not_two_halves() -> void:
	assert_bool(_vo_won("ostrevia-2", {field_associate = 7}, [0, 1])).is_true()
	assert_bool(_vo_won("ostrevia-2", {field_associate = 7}, [0])).is_false()
	assert_bool(_vo_won("ostrevia-2", {field_associate = 7}, [1])).is_false()


# --- Lower Provinces, Morrow, Nordhal and Endmark Isle (lower_provinces-1..2, morrow-1..2, nordhal-1..2, endmark-1) ---

## Whether `army` (unit id -> figures) takes map `id` from zones `use`; `full`: every research node;
## `seconds`: the fight's time limit.
func _late_won(id: String, army: Dictionary, use: Array, full := false, seconds := WarRules.BASE_FIGHT) -> bool:
	var map: WarMap = load(WarMap.MAPS + id + ".tscn").instantiate()
	var layout := map.layout()
	var grid := map.grid_size
	map.free()
	var research := BattleSim.research_for("full") if full else PackedStringArray()
	return BattleSim.trial(layout, grid, army, use, {research = research, seconds = seconds}).won


func test_the_strongroom_is_breached_right_of_centre_and_associates_hack_in_at_the_centre() -> void:
	var breach := {senior_asset = 1, field_associate = 1, restructuring_charge = 1}
	assert_bool(_late_won("lower_provinces-1", breach, [2], true)).is_true()
	assert_bool(_late_won("lower_provinces-1", breach, [1], true)).is_false()
	assert_bool(_late_won("lower_provinces-1", {field_associate = 11}, [1])).is_true()
	assert_bool(_late_won("lower_provinces-1", {field_associate = 11}, [0])).is_false()


func test_pults_empty_the_redundant_vaults_from_the_top_right_but_not_from_the_bottom_left() -> void:
	assert_bool(_late_won("lower_provinces-2", {pult_crew = 5}, [1])).is_true()
	assert_bool(_late_won("lower_provinces-2", {pult_crew = 5}, [0])).is_false()


func test_at_the_single_point_of_failure_slow_seniors_need_most_of_the_clock() -> void:
	assert_bool(_late_won("morrow-1", {senior_asset = 4}, [0])).is_true()
	assert_bool(_late_won("morrow-1", {senior_asset = 4}, [0], false, 75.0)).is_false()
	assert_bool(_late_won("morrow-1", {field_associate = 14}, [0], false, 60.0)).is_true()


func test_double_indemnity_is_taken_by_splitting_over_both_roads() -> void:
	var army := {senior_asset = 2, pult_crew = 1}
	assert_bool(_late_won("morrow-2", army, [0, 1], true)).is_true()
	assert_bool(_late_won("morrow-2", army, [0], true)).is_false()
	assert_bool(_late_won("morrow-2", army, [1], true)).is_false()
	assert_bool(_late_won("morrow-2", {field_associate = 15}, [0, 1])).is_true()
	assert_bool(_late_won("morrow-2", {field_associate = 15}, [1])).is_false()


func test_layered_security_is_opened_from_the_north_by_associates_and_the_south_by_a_mixed_army() -> void:
	assert_bool(_late_won("nordhal-1", {field_associate = 16}, [2])).is_true()
	assert_bool(_late_won("nordhal-1", {field_associate = 16}, [0])).is_false()
	assert_bool(_late_won("nordhal-1", {senior_asset = 1, pult_crew = 2}, [3], true)).is_true()
	assert_bool(_late_won("nordhal-1", {senior_asset = 1, pult_crew = 2}, [0], true)).is_false()


func test_pults_along_the_south_wall_clear_the_open_plan_office_without_entering() -> void:
	assert_bool(_late_won("nordhal-2", {pult_crew = 3}, [1], true)).is_true()
	assert_bool(_late_won("nordhal-2", {pult_crew = 3}, [0], true)).is_false()


func test_the_heart_takes_associates_from_both_quays_or_a_smaller_army_of_every_unit() -> void:
	assert_bool(_late_won("endmark-1", {field_associate = 10}, [0, 1], true)).is_true()
	assert_bool(_late_won("endmark-1", {field_associate = 9}, [0, 1], true)).is_false()
	assert_bool(_late_won("endmark-1", {field_associate = 11}, [0], true)).is_false()
	var every := {senior_asset = 1, field_associate = 3, pult_crew = 2, restructuring_charge = 2, courier = 1}
	assert_bool(_late_won("endmark-1", every, [0], true)).is_true()
	assert_int(BattleSim.army_cost(every).places).is_less(BattleSim.cap_for("full"))


func test_the_late_maps_carry_their_site_names_and_briefings() -> void:
	for id in ["lower_provinces-1", "lower_provinces-2", "morrow-1", "morrow-2", "nordhal-1", "nordhal-2", "endmark-1"]:
		var map: WarMap = load(WarMap.MAPS + id + ".tscn").instantiate()
		assert_str(map.site_name).override_failure_message(id).is_not_empty()
		assert_str(map.briefing).override_failure_message(id).is_not_empty()
		map.free()
