extends GdUnitTestSuite

const GRID := Vector2i(12, 8)


func _fight(layout: Array, seconds := 90.0, mid_round := false) -> WarFight:
	return WarFight.new(layout, GRID, seconds, mid_round)


func _stats(unit: String, changes := {}) -> Dictionary:
	var stats := WarRules.unit_stats(SaveGame.new(), unit)
	stats.merge(changes, true)
	return stats


func _index(fight: WarFight, kind: String) -> int:
	for i in fight.buildings.size():
		if fight.buildings[i].kind == kind:
			return i
	return -1


func _walls(fight: WarFight) -> Array:
	return fight.buildings.filter(func(b: Dictionary) -> bool: return b.kind in WarFight.WALLS)


func test_units_ignore_the_farmhouse_while_a_cannon_stands() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(4, 1)},
			{kind = "farmhouse", cell = Vector2i(4, 3), size = Vector2i(2, 2)},
			{kind = "cannon", cell = Vector2i(11, 7)}])
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	fight.tick(3.0)
	assert_int(fight.units[0].target).is_equal(_index(fight, "cannon"))
	assert_float(fight.buildings[_index(fight, "farmhouse")].hp).is_equal(WarFight.BUILDINGS.farmhouse.hp)


func test_a_fight_is_won_when_the_farmhouse_falls_and_survivors_come_home() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)},
			{kind = "farmhouse", cell = Vector2i(4, 3), size = Vector2i(2, 2)}])
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	fight.tick(60.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)
	assert_int(fight.end).is_equal(WarFight.End.FARMHOUSE)
	assert_dict(fight.kept).is_equal({field_associate = 2})


func test_the_farmhouse_falls_after_the_last_defence() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)},
			{kind = "farmhouse", cell = Vector2i(3, 5), size = Vector2i(2, 2)},
			{kind = "cannon", cell = Vector2i(9, 1)}])
	for i in 3:
		fight.place("senior_asset", _stats("senior_asset"), 0)
	fight.start()
	while fight.state == WarFight.State.RUNNING and fight.buildings[_index(fight, "cannon")].alive:
		fight.tick(0.5)
	assert_float(fight.buildings[_index(fight, "farmhouse")].hp).is_equal(WarFight.BUILDINGS.farmhouse.hp)
	fight.tick(60.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)


func test_a_fight_is_lost_when_ninety_seconds_run_out() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)},
			{kind = "farmhouse", cell = Vector2i(4, 3), size = Vector2i(2, 2)}])
	fight.place("field_associate", _stats("field_associate", {damage = 0.1}), 0)
	fight.start()
	fight.tick(89.9)
	assert_int(fight.state).is_equal(WarFight.State.RUNNING)
	fight.tick(0.2)
	assert_int(fight.state).is_equal(WarFight.State.LOST)
	assert_int(fight.end).is_equal(WarFight.End.TIME)
	assert_dict(fight.kept).is_empty()


func test_a_fight_is_lost_when_every_placed_unit_is_down() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(2, 1)},
			{kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)},
			{kind = "cannon", cell = Vector2i(4, 1)}])
	fight.place("field_associate", _stats("field_associate", {hp = 1.0}), 0)
	fight.start()
	fight.tick(3.0)
	assert_int(fight.state).is_equal(WarFight.State.LOST)
	assert_int(fight.end).is_equal(WarFight.End.WIPED)


func test_with_tactics_and_figures_left_losing_the_placed_ones_is_not_the_end() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(2, 1)},
			{kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)},
			{kind = "cannon", cell = Vector2i(4, 1)}], 90.0, true)
	fight.reserve = 2
	fight.place("field_associate", _stats("field_associate", {hp = 1.0}), 0)
	fight.start()
	fight.tick(3.0)
	assert_int(fight.state).is_equal(WarFight.State.RUNNING)
	assert_bool(fight.place("field_associate", _stats("field_associate", {hp = 1.0}), 0)).is_true()
	assert_int(fight.reserve).is_equal(0)
	fight.tick(3.0)
	assert_int(fight.state).is_equal(WarFight.State.LOST)


func test_units_cannot_be_placed_after_start_without_tactics() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_true()
	fight.start()
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_false()
	assert_int(fight.units.size()).is_equal(1)


func test_units_can_be_placed_after_start_with_tactics() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}], 90.0, true)
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_true()


func test_units_land_only_on_landing_spots() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_bool(fight.place("field_associate", _stats("field_associate"), 1)).is_false()
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_true()
	assert_vector(fight.units[0].pos).is_equal(Vector2(1.5, 1.5))


func test_a_fight_cannot_start_with_no_unit_placed() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_bool(fight.start()).is_false()
	assert_int(fight.state).is_equal(WarFight.State.PLANNING)


func test_retreat_saves_thirty_percent_with_the_card() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	for i in 10:
		fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["war_mode", "retreat"])
	assert_dict(fight.retreat(WarRules.retreat_share(save))).is_equal({field_associate = 3})
	assert_int(fight.state).is_equal(WarFight.State.LOST)
	assert_int(fight.end).is_equal(WarFight.End.RETREAT)


func test_retreat_rounds_down_per_unit_type_and_counts_only_the_living() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	for i in 4:
		fight.place("field_associate", _stats("field_associate"), 0)
	for i in 2:
		fight.place("senior_asset", _stats("senior_asset"), 0)
	fight.start()
	fight.units[0].alive = false
	assert_dict(fight.retreat(0.5)).is_equal({field_associate = 1, senior_asset = 1})


func test_compliance_officers_go_for_walls_and_blow_up_on_them() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(1, 4)},
			{kind = "cannon", cell = Vector2i(3, 1)},
			{kind = "wall_stone", cell = Vector2i(6, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)}])
	fight.place("compliance_officer", _stats("compliance_officer"), 0)
	fight.start()
	fight.tick(0.1)
	var wall := _index(fight, "wall_stone")
	assert_int(fight.units[0].target).is_equal(wall)
	fight.tick(4.0)
	assert_bool(fight.buildings[wall].alive).is_false()
	assert_bool(fight.units[0].alive).is_false()
	assert_bool(fight.take_events().any(func(e: Dictionary) -> bool: return e.kind == "explode")).is_true()


func test_senior_assets_walk_past_walls_to_towers() -> void:
	var layout := [{kind = "landing", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(8, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}]
	for y in range(2, 6):
		layout.append({kind = "wall_wood", cell = Vector2i(4, y)})
	var fight := _fight(layout)
	fight.place("senior_asset", _stats("senior_asset"), 0)
	fight.start()
	fight.tick(0.1)
	assert_int(fight.units[0].target).is_equal(_index(fight, "cannon"))
	fight.tick(45.0)
	assert_bool(fight.buildings[_index(fight, "cannon")].alive).is_false()
	for wall: Dictionary in _walls(fight):
		assert_float(wall.hp).is_equal(wall.max_hp)


func test_units_break_a_wall_when_it_closes_every_way() -> void:
	var layout := [{kind = "landing", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(8, 4)},
			{kind = "farmhouse", cell = Vector2i(8, 2)}]
	for x in range(6, 11):
		layout.append({kind = "wall_wood", cell = Vector2i(x, 1)})
		layout.append({kind = "wall_wood", cell = Vector2i(x, 6)})
	for y in range(2, 6):
		layout.append({kind = "wall_wood", cell = Vector2i(6, y)})
		layout.append({kind = "wall_wood", cell = Vector2i(10, y)})
	var fight := _fight(layout)
	fight.place("senior_asset", _stats("senior_asset"), 0)
	fight.place("senior_asset", _stats("senior_asset"), 0)
	fight.start()
	fight.tick(25.0)
	assert_bool(_walls(fight).any(func(w: Dictionary) -> bool: return not w.alive)).is_true()
	fight.tick(60.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)


func test_a_cannon_shot_lands_after_its_travel_time() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(4, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0)}])
	fight.place("senior_asset", _stats("senior_asset", {speed = 0.0}), 0)
	fight.start()
	fight.tick(WarFight.STEP)
	var shots := fight.take_events().filter(func(e: Dictionary) -> bool: return e.by == "cannon")
	assert_int(shots.size()).is_equal(1)
	assert_float(shots[0].travel).is_equal_approx(4.0 / WarFight.BUILDINGS.cannon.shot_speed, 0.001)
	assert_float(fight.units[0].hp).is_equal(fight.units[0].max_hp)
	fight.tick(shots[0].travel + WarFight.STEP / 2.0)
	assert_float(fight.units[0].hp).is_equal(fight.units[0].max_hp - WarFight.BUILDINGS.cannon.damage)


func test_a_mortar_cannot_hit_a_unit_inside_its_minimum_range() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(3, 4)}, {kind = "mortar", cell = Vector2i(4, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0)}])
	fight.place("senior_asset", _stats("senior_asset", {damage = 0.0}), 0)
	fight.start()
	fight.tick(6.0)
	assert_bool(fight.take_events().any(func(e: Dictionary) -> bool: return e.by == "mortar")).is_false()
	assert_float(fight.units[0].hp).is_equal(fight.units[0].max_hp)


func test_a_mortar_shell_hurts_every_unit_near_where_it_lands() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(0, 4)}, {kind = "mortar", cell = Vector2i(4, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0)}])
	fight.place("senior_asset", _stats("senior_asset", {speed = 0.0}), 0)
	fight.place("senior_asset", _stats("senior_asset", {speed = 0.0}), 0)
	fight.start()
	fight.tick(2.0)
	for u in fight.units:
		assert_float(u.hp).is_equal(u.max_hp - WarFight.BUILDINGS.mortar.damage)


func test_pult_crews_throw_from_range() -> void:
	var fight := _fight([{kind = "landing", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(9, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0)}])
	fight.place("pult_crew", _stats("pult_crew", {hp = 10000.0}), 0)
	fight.start()
	while fight.units[0].attacking < 0 and fight.elapsed < 20.0:
		fight.tick(WarFight.STEP)
	var u := fight.units[0]
	assert_float(fight.reach(u.pos, u.attacking)).is_greater(WarFight.MELEE)
	fight.tick(2.0)
	assert_bool(fight.take_events().any(func(e: Dictionary) -> bool: return e.by == "pult_crew" and e.travel > 0.0)).is_true()
	assert_float(fight.buildings[_index(fight, "cannon")].hp).is_less(WarFight.BUILDINGS.cannon.hp)


func test_the_same_fight_plays_out_the_same_twice() -> void:
	var layout := [{kind = "landing", cell = Vector2i(0, 4)}, {kind = "landing", cell = Vector2i(0, 1)},
			{kind = "cannon", cell = Vector2i(6, 3)}, {kind = "mortar", cell = Vector2i(9, 5)},
			{kind = "wall_wood", cell = Vector2i(4, 3)}, {kind = "farmhouse", cell = Vector2i(10, 1), size = Vector2i(2, 2)}]
	var runs := []
	for run in 2:
		var fight := _fight(layout)
		fight.place("field_associate", _stats("field_associate"), 0)
		fight.place("pult_crew", _stats("pult_crew"), 1)
		fight.place("compliance_officer", _stats("compliance_officer"), 1)
		fight.start()
		fight.tick(25.0)
		runs.append([fight.units.map(func(u: Dictionary) -> Array: return [u.pos, u.hp]),
				fight.buildings.map(func(b: Dictionary) -> float: return b.hp), fight.state])
	assert_array(runs[0]).is_equal(runs[1])


func test_the_test_map_falls_to_a_full_starting_army() -> void:
	# The first map from the design: 12x8, 3 landing spots, a wooden wall ring, 2 cannons, 1 mortar.
	var layout := [{kind = "landing", cell = Vector2i(0, 0)}, {kind = "landing", cell = Vector2i(0, 7)},
			{kind = "landing", cell = Vector2i(11, 7)}, {kind = "cannon", cell = Vector2i(5, 3)},
			{kind = "cannon", cell = Vector2i(8, 4)}, {kind = "mortar", cell = Vector2i(6, 5)},
			{kind = "farmhouse", cell = Vector2i(6, 3), size = Vector2i(2, 2)}]
	for x in range(3, 11):
		layout.append({kind = "wall_wood", cell = Vector2i(x, 1)})
		layout.append({kind = "wall_wood", cell = Vector2i(x, 6)})
	for y in range(2, 6):
		layout.append({kind = "wall_wood", cell = Vector2i(3, y)})
		layout.append({kind = "wall_wood", cell = Vector2i(10, y)})
	var fight := _fight(layout)
	for i in 3:
		fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	fight.tick(90.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)
