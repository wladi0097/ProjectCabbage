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
	var fight := _fight([{kind = "zone", cell = Vector2i(4, 1)},
			{kind = "farmhouse", cell = Vector2i(4, 3), size = Vector2i(2, 2)},
			{kind = "cannon", cell = Vector2i(11, 7)}])
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	fight.tick(3.0)
	assert_int(fight.units[0].target).is_equal(_index(fight, "cannon"))
	assert_float(fight.buildings[_index(fight, "farmhouse")].hp).is_equal(WarFight.BUILDINGS.farmhouse.hp)


func test_a_fight_is_won_when_the_farmhouse_falls_and_survivors_come_home() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)},
			{kind = "farmhouse", cell = Vector2i(4, 3), size = Vector2i(2, 2)}])
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	fight.tick(60.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)
	assert_int(fight.end).is_equal(WarFight.End.FARMHOUSE)
	assert_dict(fight.kept).is_equal({field_associate = 2})


func test_the_farmhouse_falls_after_the_last_defence() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)},
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


func test_splash_never_touches_the_farmhouse_while_a_defence_stands() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(6, 4)},
			{kind = "farmhouse", cell = Vector2i(7, 3), size = Vector2i(2, 2)}, {kind = "cannon", cell = Vector2i(11, 0)}])
	fight.place("pult_crew", _stats("pult_crew", {hp = 100000.0}), 0)
	fight.start()
	var near := fight.buildings[0]
	while near.alive and fight.elapsed < 60.0:
		fight.tick(0.5)
	assert_bool(near.alive).is_false()  # Thrown down, the farmhouse inside every splash.
	assert_float(fight.buildings[_index(fight, "farmhouse")].hp).is_equal(WarFight.BUILDINGS.farmhouse.hp)
	assert_int(fight.state).is_equal(WarFight.State.RUNNING)


func test_a_fight_is_lost_when_ninety_seconds_run_out() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)},
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
	var fight := _fight([{kind = "zone", cell = Vector2i(2, 1)},
			{kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)},
			{kind = "cannon", cell = Vector2i(4, 1)}])
	fight.place("field_associate", _stats("field_associate", {hp = 1.0}), 0)
	fight.start()
	fight.tick(3.0)
	assert_int(fight.state).is_equal(WarFight.State.LOST)
	assert_int(fight.end).is_equal(WarFight.End.WIPED)


func test_with_tactics_and_figures_left_losing_the_placed_ones_is_not_the_end() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(2, 1)},
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
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_true()
	fight.start()
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_false()
	assert_int(fight.units.size()).is_equal(1)


func test_units_can_be_placed_after_start_with_tactics() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}], 90.0, true)
	fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_true()


func test_units_are_placed_only_inside_a_deployment_zone() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1), size = Vector2i(2, 3)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_bool(fight.place_at("field_associate", _stats("field_associate"), Vector2(5.0, 2.0))).is_false()
	assert_bool(fight.place_at("field_associate", _stats("field_associate"), Vector2(3.2, 2.0))).is_false()
	assert_bool(fight.place_at("field_associate", _stats("field_associate"), Vector2(2.7, 3.9))).is_true()
	assert_vector(fight.units[0].pos).is_equal(Vector2(2.7, 3.9))  # Where it was set down.
	assert_bool(fight.place("field_associate", _stats("field_associate"), 1)).is_false()  # No second zone.
	assert_bool(fight.place("field_associate", _stats("field_associate"), 0)).is_true()
	assert_vector(fight.units[1].pos).is_equal(Vector2(2.0, 2.5))  # Its middle.


func test_a_figure_dropped_near_a_zone_slides_into_it_and_one_far_off_does_not() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 2), size = Vector2i(3, 4)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_vector(fight.snap(Vector2(1.2, 3.3))).is_equal(Vector2(1.2, 3.3))  # Inside: it stays.
	var near := fight.snap(Vector2(3.6, 4.0))  # 0.6 cells right of the zone.
	assert_bool(fight.in_zone(near)).is_true()
	assert_float(near.y).is_equal(4.0)
	assert_float(near.x).is_equal_approx(3.0 - WarFight.INSET, 0.0001)
	assert_vector(fight.snap(Vector2(4.5, 4.0))).is_equal(Vector2.INF)  # 1.5 cells off: no zone.


func test_a_fight_cannot_start_with_no_unit_placed() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	assert_bool(fight.start()).is_false()
	assert_int(fight.state).is_equal(WarFight.State.PLANNING)


func test_retreat_saves_thirty_percent_with_the_card() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	for i in 10:
		fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["war_mode", "retreat"])
	assert_dict(fight.retreat(WarRules.retreat_share(save))).is_equal({field_associate = 3})
	assert_int(fight.state).is_equal(WarFight.State.LOST)
	assert_int(fight.end).is_equal(WarFight.End.RETREAT)


func test_retreat_rounds_down_per_unit_type_and_counts_only_the_living() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(1, 1)}, {kind = "farmhouse", cell = Vector2i(8, 4)}])
	for i in 4:
		fight.place("field_associate", _stats("field_associate"), 0)
	for i in 2:
		fight.place("senior_asset", _stats("senior_asset"), 0)
	fight.start()
	fight.units[0].alive = false
	assert_dict(fight.retreat(0.5)).is_equal({field_associate = 1, senior_asset = 1})


func test_a_charge_goes_for_the_first_fence_on_its_straight_path_not_the_nearest_one() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)},
			{kind = "wall_wood", cell = Vector2i(1, 6)},  # Nearest, but off the way.
			{kind = "wall_stone", cell = Vector2i(6, 4)},
			{kind = "cannon", cell = Vector2i(9, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)}])
	fight.place("restructuring_charge", _stats("restructuring_charge", {hp = 1000.0}), 0)  # Outlives the cannon.
	fight.start()
	fight.tick(0.1)
	var wall := _index(fight, "wall_stone")
	assert_int(fight.units[0].target).is_equal(wall)
	fight.tick(6.0)
	assert_bool(fight.buildings[wall].alive).is_false()
	assert_bool(fight.units[0].alive).is_false()
	assert_float(fight.buildings[_index(fight, "wall_wood")].hp).is_equal(WarFight.BUILDINGS.wall_wood.hp)
	assert_bool(fight.take_events().any(func(e: Dictionary) -> bool: return e.kind == "explode" and e.by == "restructuring_charge")).is_true()


func test_a_charge_with_no_fence_on_its_way_blows_up_at_the_defence_for_its_small_damage() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)}, {kind = "wall_wood", cell = Vector2i(1, 6)},
			{kind = "cannon", cell = Vector2i(5, 4)}, {kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)}])
	var charge := _stats("restructuring_charge", {hp = 1000.0})
	fight.place("restructuring_charge", charge, 0)
	fight.start()
	fight.tick(6.0)
	assert_bool(fight.units[0].alive).is_false()
	var cannon: Dictionary = fight.buildings[_index(fight, "cannon")]
	assert_float(cannon.hp).is_equal(cannon.max_hp - charge.damage)
	assert_float(fight.buildings[_index(fight, "wall_wood")].hp).is_equal(WarFight.BUILDINGS.wall_wood.hp)


func test_a_courier_hops_a_fence_in_half_a_second_and_leaves_it_standing() -> void:
	var layout := [{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(9, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}]
	for y in GRID.y:
		layout.append({kind = "wall_steel", cell = Vector2i(4, y)})  # No way round.
	var runs := []
	for hops: bool in [true, false]:
		var fight := _fight(layout)
		fight.place("courier", _stats("courier", {hp = 5000.0, hops = hops}), 0)
		fight.start()
		var past := -1.0
		while fight.state == WarFight.State.RUNNING and fight.elapsed < 20.0:
			fight.tick(WarFight.STEP)
			if past < 0.0 and fight.units[0].pos.x > 5.0:
				past = fight.elapsed
		runs.append([past, _walls(fight).all(func(w: Dictionary) -> bool: return w.hp == w.max_hp)])
	var on_foot := (5.0 - 0.5) / float(WarRules.BASE_STATS.courier.speed)  # The zone's middle to past the fence.
	assert_float(runs[0][0]).is_equal_approx(on_foot + WarFight.HOP, 0.15)
	assert_bool(runs[0][1]).is_true()
	assert_bool(runs[1][1]).is_false()  # Without the hop it has to break through.


func test_the_shredder_ramps_on_the_figure_it_holds_and_starts_over_on_a_new_one() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4), size = Vector2i(9, 1)}, {kind = "shredder", cell = Vector2i(8, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}])
	fight.place_at("senior_asset", _stats("senior_asset", {speed = 0.0, damage = 0.0, hp = 100.0}), Vector2(6.5, 4.5))
	fight.place_at("senior_asset", _stats("senior_asset", {speed = 0.0, damage = 0.0, hp = 10000.0}), Vector2(5.6, 4.5))
	fight.start()
	var spec: Dictionary = WarFight.BUILDINGS.shredder
	var hits := []
	while fight.elapsed < 12.0:
		fight.tick(WarFight.STEP)
		for e in fight.take_events():
			hits.append([e.damage, fight.buildings[_index(fight, "shredder")].target])
	assert_float(hits[0][0]).is_equal(spec.damage)
	assert_float(hits[1][0]).is_equal(spec.damage + spec.step)
	var switch := hits.map(func(h: Array) -> int: return h[1]).find(1)  # The first one fell: a new figure.
	assert_int(switch).is_greater(1)
	assert_float(hits[switch][0]).is_equal(spec.damage)
	assert_float(hits[-1][0]).is_equal(spec.top)  # Held long enough, it tops out.


func test_the_silo_bursts_on_everyone_beside_it_when_it_falls() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 3), size = Vector2i(9, 2)}, {kind = "silo", cell = Vector2i(5, 1), size = Vector2i(2, 2)},
			{kind = "farmhouse", cell = Vector2i(10, 6), size = Vector2i(2, 2)}])
	fight.place_at("senior_asset", _stats("senior_asset", {speed = 0.0, hp = 10000.0}), Vector2(6.0, 3.5))  # Beside it.
	fight.place_at("senior_asset", _stats("senior_asset", {speed = 0.0, damage = 0.0, hp = 10000.0}), Vector2(1.0, 4.5))  # Out of the burst.
	fight.start()
	var silo := _index(fight, "silo")
	var before_hp := []
	while fight.buildings[silo].alive and fight.elapsed < 60.0:
		before_hp = fight.units.map(func(u: Dictionary) -> float: return u.hp)
		fight.tick(WarFight.STEP)
	assert_bool(fight.buildings[silo].alive).is_false()
	assert_float(before_hp[0] - fight.units[0].hp).is_greater_equal(WarFight.BUILDINGS.silo.burst)
	assert_float(fight.units[1].hp).is_equal(before_hp[1])
	assert_bool(fight.take_events().any(func(e: Dictionary) -> bool: return e.kind == "explode" and e.by == "silo")).is_true()


func test_the_sprinkler_soaks_everyone_round_its_target_at_once() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4), size = Vector2i(9, 1)}, {kind = "sprinkler", cell = Vector2i(8, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}])
	var still := _stats("senior_asset", {speed = 0.0, damage = 0.0})
	fight.place_at("senior_asset", still, Vector2(6.6, 4.5))
	fight.place_at("senior_asset", still, Vector2(6.0, 4.5))
	fight.place_at("senior_asset", still, Vector2(4.5, 4.5))  # Out of its reach.
	fight.start()
	fight.tick(WarFight.STEP)
	var spray := fight.take_events().filter(func(e: Dictionary) -> bool: return e.by == "sprinkler")
	assert_int(spray.size()).is_equal(1)
	assert_float(spray[0].travel).is_equal(0.0)
	assert_float(fight.units[0].hp).is_equal(still.hp - WarFight.BUILDINGS.sprinkler.damage)
	assert_float(fight.units[1].hp).is_equal(still.hp - WarFight.BUILDINGS.sprinkler.damage)
	assert_float(fight.units[2].hp).is_equal(still.hp)


func test_the_cctv_mast_reaches_further_than_any_other_defence_with_quick_small_shots() -> void:
	var cctv: Dictionary = WarFight.BUILDINGS.cctv
	for kind: String in WarFight.DEFENCES:
		if kind != "cctv":
			assert_float(cctv.range).override_failure_message(kind).is_greater(WarFight.BUILDINGS[kind].range)
			assert_float(cctv.interval).override_failure_message(kind).is_less(WarFight.BUILDINGS[kind].interval)
			assert_float(cctv.damage).override_failure_message(kind).is_less(WarFight.BUILDINGS[kind].get("top", WarFight.BUILDINGS[kind].damage))
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cctv", cell = Vector2i(8, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}])
	fight.place("senior_asset", _stats("senior_asset", {speed = 0.0}), 0)  # 8 cells off: in its reach.
	fight.start()
	fight.tick(2.0)
	assert_float(fight.units[0].hp).is_less(fight.units[0].max_hp)


func test_senior_assets_walk_past_walls_to_towers() -> void:
	var layout := [{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(8, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}]
	for y in range(2, 6):
		layout.append({kind = "wall_wood", cell = Vector2i(4, y)})
	var fight := _fight(layout)
	fight.place("senior_asset", _stats("senior_asset", {hp = 5000.0}), 0)  # Outlives the cannon.
	fight.start()
	fight.tick(0.1)
	assert_int(fight.units[0].target).is_equal(_index(fight, "cannon"))
	fight.tick(45.0)
	assert_bool(fight.buildings[_index(fight, "cannon")].alive).is_false()
	for wall: Dictionary in _walls(fight):
		assert_float(wall.hp).is_equal(wall.max_hp)


func test_units_break_a_wall_when_it_closes_every_way() -> void:
	var layout := [{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(8, 4)},
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
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(4, 4)},
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


func test_a_tower_shoots_the_nearest_staff_member() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4), size = Vector2i(9, 1)}, {kind = "cannon", cell = Vector2i(9, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}])
	var still := _stats("senior_asset", {speed = 0.0, damage = 0.0})
	fight.place_at("senior_asset", still, Vector2(6.5, 4.5))  # Placed first, but further off.
	fight.place_at("senior_asset", still, Vector2(8.5, 4.5))
	fight.start()
	fight.tick(3.0)
	assert_float(fight.units[0].hp).is_equal(fight.units[0].max_hp)
	assert_float(fight.units[1].hp).is_less(fight.units[1].max_hp)


func test_a_tower_keeps_shooting_its_target_until_it_falls_though_another_comes_nearer() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4), size = Vector2i(9, 1)}, {kind = "cannon", cell = Vector2i(9, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}])
	fight.place_at("senior_asset", _stats("senior_asset", {speed = 0.0, damage = 0.0, hp = 100000.0}), Vector2(6.5, 4.5))
	fight.place_at("field_associate", _stats("field_associate", {damage = 0.0, hp = 100000.0}), Vector2(0.5, 4.5))
	fight.start()
	fight.tick(10.0)
	var walker := fight.units[1]
	assert_float(fight.centre(_index(fight, "cannon")).distance_to(walker.pos)).is_less(2.0)  # Nearer now.
	assert_float(walker.hp).is_equal(walker.max_hp)
	assert_float(fight.units[0].hp).is_less(fight.units[0].max_hp)


func test_a_mortar_cannot_hit_a_unit_inside_its_minimum_range() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(3, 4)}, {kind = "mortar", cell = Vector2i(4, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0)}])
	fight.place("senior_asset", _stats("senior_asset", {damage = 0.0}), 0)
	fight.start()
	fight.tick(6.0)
	assert_bool(fight.take_events().any(func(e: Dictionary) -> bool: return e.by == "mortar")).is_false()
	assert_float(fight.units[0].hp).is_equal(fight.units[0].max_hp)


func test_a_mortar_shell_hurts_every_unit_near_where_it_lands() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)}, {kind = "mortar", cell = Vector2i(4, 4)},
			{kind = "farmhouse", cell = Vector2i(10, 0)}])
	fight.place("senior_asset", _stats("senior_asset", {speed = 0.0}), 0)
	fight.place("senior_asset", _stats("senior_asset", {speed = 0.0}), 0)
	fight.start()
	fight.tick(2.0)
	for u in fight.units:
		assert_float(u.hp).is_equal(u.max_hp - WarFight.BUILDINGS.mortar.damage)


func test_pult_crews_throw_from_range() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 4)}, {kind = "cannon", cell = Vector2i(9, 4)},
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
	var layout := [{kind = "zone", cell = Vector2i(0, 4)}, {kind = "zone", cell = Vector2i(0, 1)},
			{kind = "cannon", cell = Vector2i(6, 3)}, {kind = "mortar", cell = Vector2i(9, 5)},
			{kind = "wall_wood", cell = Vector2i(4, 3)}, {kind = "farmhouse", cell = Vector2i(10, 1), size = Vector2i(2, 2)}]
	var runs := []
	for run in 2:
		var fight := _fight(layout)
		fight.place("field_associate", _stats("field_associate"), 0)
		fight.place("pult_crew", _stats("pult_crew"), 1)
		fight.place("restructuring_charge", _stats("restructuring_charge"), 1)
		fight.start()
		fight.tick(25.0)
		runs.append([fight.units.map(func(u: Dictionary) -> Array: return [u.pos, u.hp]),
				fight.buildings.map(func(b: Dictionary) -> float: return b.hp), fight.state])
	assert_array(runs[0]).is_equal(runs[1])


func test_the_design_layout_falls_to_an_army_of_five() -> void:
	# The first map from the design: 12x8, 3 one-cell zones, a wooden wall ring, a cannon, a mortar.
	# One-cell zones clump the army, and the mailing unit (40 a shell since the balance pass) punishes
	# that: 3 lose here, 5 (the cap with BIGGER ARMIES) win. The test map spreads its zones: 3 win.
	var layout := [{kind = "zone", cell = Vector2i(0, 0)}, {kind = "zone", cell = Vector2i(0, 7)},
			{kind = "zone", cell = Vector2i(11, 7)}, {kind = "cannon", cell = Vector2i(5, 3)},
			{kind = "mortar", cell = Vector2i(6, 5)},
			{kind = "farmhouse", cell = Vector2i(6, 3), size = Vector2i(2, 2)}]
	for x in range(3, 11):
		layout.append({kind = "wall_wood", cell = Vector2i(x, 1)})
		layout.append({kind = "wall_wood", cell = Vector2i(x, 6)})
	for y in range(2, 6):
		layout.append({kind = "wall_wood", cell = Vector2i(3, y)})
		layout.append({kind = "wall_wood", cell = Vector2i(10, y)})
	var fight := _fight(layout)
	for i in WarRules.BASE_CAP + WarRules.CARD_CAP:
		fight.place("field_associate", _stats("field_associate"), 0)
	fight.start()
	fight.tick(90.0)
	assert_int(fight.state).is_equal(WarFight.State.WON)


# ---- The roster's matchups (research/war-units.md section 7), played on BattleSim with text layouts.

const FENCE_LINE := "wall_stone@6,0,1x8; cannon@8,3; farmhouse@10,6; zone@0,2,4x3"
const OPEN := "farmhouse@10,6; zone@0,2,4x3"


## `layout` and `army` as the calculator's text (BattleSim.parse_layout / parse_plan), on GRID.
func _sim(layout: String, army: String) -> Dictionary:
	return BattleSim.run(BattleSim.parse_layout(layout), GRID, BattleSim.parse_plan(army))


func _deaths(r: Dictionary, unit: String) -> Array:
	return r.events.filter(func(e: Dictionary) -> bool: return e.what == "died" and e.kind == unit)


func _standing(r: Dictionary, kind: String) -> bool:
	return r.buildings.any(func(b: Dictionary) -> bool: return b.kind == kind and b.alive)


func _untouched(r: Dictionary, kind: String) -> bool:
	return r.buildings.all(func(b: Dictionary) -> bool: return b.kind != kind or b.dealt == 0.0)


func test_associates_in_front_draw_the_tower_so_the_charge_reaches_the_fence() -> void:
	var r := _sim(FENCE_LINE, "fa x2 @3.5,3.5; rc @2.5,3.5")
	var blast: Dictionary = _deaths(r, "restructuring_charge")[0]
	assert_str(blast.by).is_equal("wall_stone")
	assert_float(blast.hp).is_equal(WarRules.BASE_STATS.restructuring_charge.hp)
	assert_bool(r.buildings.any(func(b: Dictionary) -> bool: return b.kind == "wall_stone" and not b.alive)).is_true()


func test_a_charge_sent_first_dies_before_the_fence() -> void:
	var r := _sim(FENCE_LINE, "rc @2.5,3.5")
	assert_str(_deaths(r, "restructuring_charge")[0].by).is_equal("")  # Shot down walking.
	assert_bool(_untouched(r, "wall_stone")).is_true()


func test_security_grade_fencing_needs_two_charges() -> void:
	var steel := "wall_steel@6,0,1x8; farmhouse@9,3; zone@0,2,4x3"
	var one := _sim(steel, "rc @2.5,3.5")
	assert_bool(one.buildings.all(func(b: Dictionary) -> bool: return b.kind != "wall_steel" or b.alive)).is_true()
	assert_bool(one.buildings.any(func(b: Dictionary) -> bool: return b.kind == "wall_steel" and b.dealt > 0.0)).is_true()
	var two := _sim(steel, "rc x2 @2.5,3.5")
	assert_bool(two.buildings.any(func(b: Dictionary) -> bool: return b.kind == "wall_steel" and not b.alive)).is_true()


func test_a_crowd_of_associates_outlasts_one_supervisors_tower() -> void:
	var r := _sim("cannon@8,3; " + OPEN, "fa x4")
	assert_bool(_standing(r, "cannon")).is_false()
	assert_int(_deaths(r, "field_associate").size()).is_equal(1)


func test_a_cctv_mast_cannot_stop_a_senior_asset() -> void:
	var r := _sim("cctv@8,3; " + OPEN, "sa")
	assert_bool(_standing(r, "cctv")).is_false()
	assert_float(r.units[0].hp).is_greater(r.units[0].max_hp / 2.0)


func test_a_senior_asset_soaks_the_tower_while_associates_take_it() -> void:
	var r := _sim("cannon@8,3; farmhouse@10,6; zone@0,1,4x5", "sa @3.5,3.5; fa x2 @1.5,3.5")
	assert_bool(_standing(r, "cannon")).is_false()
	assert_array(_deaths(r, "field_associate")).is_empty()


func test_a_mailing_unit_shell_hurts_a_whole_clump() -> void:
	var fight := _fight([{kind = "zone", cell = Vector2i(0, 3), size = Vector2i(2, 2)}, {kind = "mortar", cell = Vector2i(6, 3), size = Vector2i(2, 2)},
			{kind = "farmhouse", cell = Vector2i(10, 0), size = Vector2i(2, 2)}])
	var still := _stats("field_associate", {speed = 0.0})
	for i in 3:
		fight.place("field_associate", still, 0)  # Set together.
	fight.start()
	fight.tick(10.0)  # Shells at 0, 4 and 8 s, the last landing at 9.5 s.
	var shells := fight.take_events().filter(func(e: Dictionary) -> bool: return e.by == "mortar").size()
	assert_int(shells).is_greater(1)
	for u in fight.units:
		assert_float(u.hp).is_equal(float(still.hp) - shells * float(WarFight.BUILDINGS.mortar.damage))


func test_a_courier_takes_the_mailing_unit_in_its_dead_zone() -> void:
	var ring := "mortar@5,3; wall_stone@4,2,4x1; wall_stone@4,5,4x1; wall_stone@4,3,1x2; wall_stone@7,3,1x2"
	var r := _sim(ring + "; farmhouse@10,6; zone@0,2,2x3", "cr")
	assert_bool(_standing(r, "mortar")).is_false()
	assert_bool(_untouched(r, "wall_stone")).is_true()
	assert_float(r.units[0].hp).is_equal(r.units[0].max_hp)  # Never hit: inside its minimum range.


func test_a_sprinkler_washes_out_clumped_associates() -> void:
	var r := _sim("sprinkler@7,3; " + OPEN, "fa x3")
	assert_int(_deaths(r, "field_associate").size()).is_equal(3)
	assert_bool(_standing(r, "sprinkler")).is_true()


func test_pult_crews_outrange_the_sprinkler() -> void:
	var r := _sim("sprinkler@7,3; " + OPEN, "pc x2")
	assert_bool(_standing(r, "sprinkler")).is_false()
	for u: Dictionary in r.units:
		assert_float(u.hp).is_equal(u.max_hp)


func test_a_lone_senior_asset_loses_to_the_shredder() -> void:
	var r := _sim("shredder@7,3; " + OPEN, "sa")
	assert_int(_deaths(r, "senior_asset").size()).is_equal(1)
	assert_bool(_standing(r, "shredder")).is_true()


func test_associates_reset_the_shredder_so_it_never_ramps() -> void:
	var r := _sim("shredder@7,3; " + OPEN, "fa x5")
	assert_bool(_standing(r, "shredder")).is_false()
	assert_float(r.top.shredder).is_less(WarFight.BUILDINGS.shredder.top)


func test_pult_crews_outrange_the_shredder() -> void:
	var r := _sim("shredder@7,3; " + OPEN, "pc x2")
	assert_bool(_standing(r, "shredder")).is_false()
	assert_bool(r.top.has("shredder")).is_false()  # It never fired.


## A soft counter (balance pass): the burst takes most of an associate, not all of an unhurt one.
func test_the_silo_burst_takes_most_of_every_attacker_beside_it() -> void:
	var r := _sim("silo@7,3; " + OPEN, "fa x3")
	assert_bool(_standing(r, "silo")).is_false()
	for u: Dictionary in r.units:
		assert_float(u.max_hp - u.hp).is_greater_equal(WarFight.BUILDINGS.silo.burst)


func test_pult_crews_take_the_silo_from_outside_the_burst() -> void:
	var r := _sim("silo@7,3; " + OPEN, "pc x2")
	assert_bool(_standing(r, "silo")).is_false()
	assert_array(_deaths(r, "pult_crew")).is_empty()


func test_a_courier_that_takes_the_silo_dies_in_its_burst() -> void:
	var r := _sim("silo@7,3; " + OPEN, "cr")
	assert_bool(_standing(r, "silo")).is_false()
	assert_int(_deaths(r, "courier").size()).is_equal(1)


## The senior asset in front soaks the tower and hacks the one fence cell before it (18 a hit); the
## pults' splash lands round the tower without touching any of the ring.
func test_pult_crews_hit_a_fenced_tower_without_touching_the_fence() -> void:
	var ring := "cannon@6,3; wall_steel@5,2,3x1; wall_steel@5,4,3x1; wall_steel@5,3; wall_steel@7,3"
	var r := _sim(ring + "; farmhouse@10,6; zone@0,1,4x5", "sa @3.5,3.5; pc x2 @1.5,3.5")
	assert_bool(_standing(r, "cannon")).is_false()
	var hit: Array = r.buildings.filter(func(b: Dictionary) -> bool: return b.kind == "wall_steel" and b.dealt > 0.0)
	assert_int(hit.size()).is_less_equal(1)
	for b: Dictionary in hit:
		assert_that(b.cell).is_equal(Vector2i(5, 3))  # The senior asset's side.
		assert_float(fmod(b.dealt, float(WarRules.BASE_STATS.senior_asset.damage))).is_equal_approx(0.0, 0.001)
	assert_array(_deaths(r, "pult_crew")).is_empty()


func test_every_map_falls_to_field_associates_alone() -> void:
	var research := PackedStringArray()
	for node: Dictionary in WarRules.RESEARCH:
		if node.unit == "field_associate":
			research.append(node.id)
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["war_mode", "bigger_armies"])
	save.tree_bought = PackedStringArray(["war_cap_1", "war_cap_2", "war_cap_3"])
	var cap := WarRules.army_cap(save)
	for path: String in WarMap.map_paths():
		var map: WarMap = auto_free(load(path).instantiate())
		var zones := map.zones().size()
		var plan := []
		for i in cap:
			plan.append({unit = "field_associate", zone = i % zones})
		assert_bool(BattleSim.run(map.layout(), map.grid_size, plan, research).won).override_failure_message(path).is_true()


# ---- Terrain: ponds, hedges and rivers block every unit; bridges, roads and fields are walked.

## Plays `units` (one each, set down in zone 0) on text layout `text` (the 12x8 grid) until it ends,
## failing if a figure ever stands on a blocked cell.
func _terrain_fight(text: String, units: Array, seconds := 90.0) -> WarFight:
	var fight := _fight(BattleSim.parse_layout(text), seconds)
	for unit: String in units:
		fight.place(unit, _stats(unit), 0)
	fight.start()
	while fight.state == WarFight.State.RUNNING:
		fight.tick(0.25)
		for u in fight.units:
			assert_bool(fight.blocked(Vector2i(u.pos.floor()))) \
					.override_failure_message("%s at %s on %s" % [u.unit, u.pos, text]).is_false()
	return fight


func test_ponds_hedges_and_rivers_stop_every_unit_couriers_and_charges_too() -> void:
	for line: String in ["pond@6,0,2x8", "hedge@6,0,1x8", "river@6,0,1x8"]:
		for unit: String in WarRules.UNITS:
			var fight := _terrain_fight(line + "; farmhouse@10,3; zone@0,3,3x2", [unit])
			assert_bool(fight.units[0].pos.x < 6.0).override_failure_message("%s crossed %s" % [unit, line]).is_true()


func test_a_courier_runs_round_a_hedge_it_cannot_hop() -> void:
	var fight := _terrain_fight("hedge@6,0,1x6; farmhouse@9,3; zone@0,3,3x2", ["courier"])
	assert_int(fight.state).is_equal(WarFight.State.WON)


func test_a_bridge_carries_units_over_the_river() -> void:
	var fight := _terrain_fight("river@6,0,1x8; bridge@6,7; farmhouse@9,3; zone@0,3,3x2", ["field_associate"])
	assert_int(fight.state).is_equal(WarFight.State.WON)


func test_roads_and_fields_are_walked_like_open_paper() -> void:
	var army := ["field_associate", "field_associate", "senior_asset", "courier"]
	var open := _terrain_fight("cannon@6,5; farmhouse@9,2; zone@0,3,3x2", army)
	var printed := _terrain_fight("road@0,0,12x4; field@0,4,12x4; cannon@6,5; farmhouse@9,2; zone@0,3,3x2", army)
	assert_int(printed.state).is_equal(open.state)
	assert_float(printed.elapsed).is_equal(open.elapsed)
	assert_array(printed.units.map(func(u: Dictionary) -> Vector2: return u.pos)).is_equal(open.units.map(func(u: Dictionary) -> Vector2: return u.pos))


func test_towers_shoot_over_terrain_and_a_charge_never_takes_terrain_for_a_fence() -> void:
	var fight := _terrain_fight("hedge@3,0,1x8; river@4,0,1x8; cannon@6,3; farmhouse@10,6; zone@0,3,3x2",
			["restructuring_charge", "field_associate"], 10.0)
	assert_int(fight.units[0].target).is_equal(_index(fight, "cannon"))
	assert_bool(fight.units.any(func(u: Dictionary) -> bool: return u.hp < u.max_hp)).is_true()
	assert_int(fight.buildings.size()).is_equal(2)  # Terrain is no building: nothing to aim at.


func test_a_zone_or_building_on_blocking_terrain_is_refused_and_a_bridge_must_lie_on_a_river() -> void:
	var problems := func(text: String) -> Array: return Array(WarFight.problems(BattleSim.parse_layout(text)))
	assert_array(problems.call("pond@2,2,2x2; zone@3,3,2x2; road@0,0,4x1; zone@0,0,2x1; farmhouse@8,4")) \
			.is_equal(["zone@3,3 stands on blocking terrain"])
	assert_array(problems.call("hedge@5,0,1x3; cannon@5,2; zone@0,0")).is_equal(["cannon@5,2 stands on blocking terrain"])
	assert_array(problems.call("river@5,0,1x8; bridge@5,3; bridge@7,3; zone@5,3")).is_equal(["bridge@7,3 is not on a river"])


func test_no_figure_is_set_down_on_a_pond_even_inside_a_zone() -> void:
	var fight := _fight(BattleSim.parse_layout("zone@0,0,4x4; pond@1,1"))
	assert_bool(fight.place_at("field_associate", _stats("field_associate"), Vector2(1.5, 1.5))).is_false()
	assert_bool(fight.place_at("field_associate", _stats("field_associate"), Vector2(0.5, 0.5))).is_true()
