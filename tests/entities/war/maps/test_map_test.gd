extends GdUnitTestSuite

const SCENE := "res://entities/war/maps/test_map.tscn"
const TUTORIAL := "res://entities/war/maps/K-6.tscn"
const TUTORIAL_2 := "res://entities/war/maps/K-7.tscn"
## Every terrain kind with a few buildings: written from SHOWCASE_TEXT by tools/battle_sim.gd --save.
const SHOWCASE := "res://tests/entities/war/maps/terrain_showcase.tscn"
const SHOWCASE_TEXT := "zone@0,4,3x4; zone@14,9,3x2; road@0,3,6x1; road@7,3,4x1; river@6,0,1x7; river@7,6,5x1; " 		+ "river@11,7,1x4; bridge@6,3; bridge@9,6; pond@13,1,3x2; pond@16,2,2x2; hedge@3,8,4x1; hedge@8,1,3x1; " 		+ "hedge@11,1,1x2; field@13,6,4x3; field@1,0,3x2; farmhouse@17,4; cannon@13,4; mortar@9,8; wall_wood@12,3,1x3"


func _map() -> WarMap:
	var map: WarMap = auto_free(load(SCENE).instantiate())
	add_child(map)
	return map


func _count(map: WarMap, kind: String) -> int:
	return map.layout().filter(func(e: Dictionary) -> bool: return e.kind == kind).size()


func _node_at(map: WarMap, cell: Vector2i) -> Node3D:
	for node: Node3D in map.get_children():
		if WarMap.cell_of(node) == cell:
			return node
	return null


func test_the_test_map_has_three_zones_a_wooden_ring_a_cannon_a_mortar_and_the_farmhouse() -> void:
	var map := _map()
	assert_that(map.grid_size).is_equal(Vector2i(20, 11))
	assert_int(_count(map, "zone")).is_equal(3)
	assert_int(_count(map, "cannon")).is_equal(1)
	assert_int(_count(map, "mortar")).is_equal(1)
	assert_int(_count(map, "farmhouse")).is_equal(1)
	assert_int(_count(map, "wall_wood")).is_greater(0)
	assert_int(map.zones().size()).is_equal(3)
	assert_int(map.buildings().size()).is_equal(map.layout().size() - 3)


func test_every_piece_of_the_test_map_lies_on_its_grid_without_overlapping() -> void:
	var taken := {}
	for entry: Dictionary in _map().layout():
		for y in entry.size.y:
			for x in entry.size.x:
				var cell: Vector2i = entry.cell + Vector2i(x, y)
				assert_bool(Rect2i(Vector2i.ZERO, Vector2i(20, 11)).has_point(cell)).override_failure_message(str(entry)).is_true()
				assert_bool(taken.has(cell)).override_failure_message(str(cell)).is_false()
				taken[cell] = true


func test_the_test_map_falls_to_three_field_associates_within_the_time_limit() -> void:
	var map := _map()
	var fight := WarFight.new(map.layout(), map.grid_size, WarRules.BASE_FIGHT)
	for i in 3:
		fight.place("field_associate", WarRules.unit_stats(SaveGame.new(), "field_associate"), 0)
	fight.start()
	fight.tick(WarRules.BASE_FIGHT)
	assert_int(fight.state).is_equal(WarFight.State.WON)


func test_one_field_associate_alone_does_not_take_the_test_map() -> void:
	var map := _map()
	var fight := WarFight.new(map.layout(), map.grid_size, WarRules.BASE_FIGHT)
	fight.place("field_associate", WarRules.unit_stats(SaveGame.new(), "field_associate"), 0)
	fight.start()
	fight.tick(WarRules.BASE_FIGHT)
	assert_int(fight.state).is_equal(WarFight.State.LOST)


func test_walls_show_their_arms_only_toward_standing_wall_neighbours() -> void:
	var map := _map()
	var corner := _node_at(map, Vector2i(7, 2))  # The ring's top-left corner: neighbours east and south.
	assert_bool(WarMap.kind_of(corner) == "wall_wood").is_true()
	var arms := func(wall: Node3D) -> Array:
		return ["East", "North", "West", "South"].filter(func(a: String) -> bool: return (wall.get_node("Arms/" + a) as Node3D).visible)
	assert_array(arms.call(corner)).is_equal(["East", "South"])
	var alive := []
	for node in map.buildings():
		alive.append(WarMap.cell_of(node) != Vector2i(8, 2))  # Its east neighbour is down.
	map.show_walls(alive)
	assert_array(arms.call(corner)).is_equal(["South"])


func test_a_building_down_shows_its_rubble_and_nothing_else() -> void:
	var cannon := _node_at(_map(), Vector2i(8, 3))
	WarMap.wreck(cannon, true)
	assert_bool((cannon.get_node("Rubble") as Node3D).visible).is_true()
	assert_bool((cannon.get_node("Turret") as Node3D).visible).is_false()
	assert_bool((cannon.get_node("Base") as Node3D).visible).is_false()
	WarMap.wreck(cannon, false)
	assert_bool((cannon.get_node("Rubble") as Node3D).visible).is_false()
	assert_bool((cannon.get_node("Turret") as Node3D).visible).is_true()


func test_figures_standing_on_the_map_are_not_part_of_its_layout() -> void:
	var map := _map()
	var laid := map.layout()
	map.add_child(FightView.figure("field_associate"))
	assert_array(map.layout()).is_equal(laid)
	assert_int(map.buildings().size()).is_equal(laid.size() - 3)


func test_every_piece_of_every_map_sits_exactly_on_whole_cells_of_the_printed_grid() -> void:
	for path: String in Array(WarMap.map_paths()) + [SHOWCASE]:
		var map: WarMap = auto_free(load(path).instantiate())
		for node in map.pieces():
			var size := Vector2(WarMap.footprint(node))
			var cell := Vector2(WarMap.cell_of(node))
			var at := Vector2(node.position.x, node.position.z)
			assert_vector(at).override_failure_message("%s %s" % [path, node.name]) \
					.is_equal_approx((cell + size / 2.0) * WarMap.CELL, Vector2.ONE * 0.0001)
			assert_float(node.rotation.y).override_failure_message(node.name).is_equal(0.0)


func test_the_first_tutorial_has_the_farmhouse_in_the_middle_a_fence_one_cell_off_and_no_towers() -> void:
	var map: WarMap = auto_free(load(TUTORIAL).instantiate())
	var layout := map.layout()
	var house: Dictionary = layout.filter(func(e: Dictionary) -> bool: return e.kind == "farmhouse")[0]
	assert_that(house.cell).is_equal(Vector2i(9, 4))  # Cells 9-10 x 4-5: the sheet's middle.
	assert_int(layout.filter(func(e: Dictionary) -> bool: return e.kind in WarFight.DEFENCES).size()).is_equal(0)
	var fence := layout.filter(func(e: Dictionary) -> bool: return e.kind == "wall_wood")
	for wall: Dictionary in fence:  # A closed ring: x 7 or 12, y 2 or 7.
		assert_bool(wall.cell.x in [7, 12] or wall.cell.y in [2, 7]).is_true()
	assert_int(fence.size()).is_equal(20)
	var zones := map.zones()
	assert_int(zones.size()).is_equal(1)
	assert_int(WarMap.cell_of(zones[0]).x).is_equal(0)  # On the left, by the figures on the desk.


func test_a_single_field_associate_takes_the_first_tutorial_in_time() -> void:
	var map: WarMap = auto_free(load(TUTORIAL).instantiate())
	var fight := WarFight.new(map.layout(), map.grid_size, WarRules.BASE_FIGHT)
	fight.place("field_associate", WarRules.unit_stats(SaveGame.new(), "field_associate"), 0)
	fight.start()
	fight.tick(WarRules.BASE_FIGHT)
	assert_int(fight.state).is_equal(WarFight.State.WON)  # No towers: even one gets through the fence.


func test_a_zone_is_outlined_in_the_toy_soldiers_green_one_fine_grid_step_wide() -> void:
	var zone: MeshInstance3D = _map().zones()[0].get_node("Mesh")
	var hatch := (zone.mesh as PlaneMesh).material as ShaderMaterial
	var green: Vector3 = hatch.get_shader_parameter(&"ours")
	assert_float(green.y).is_greater(green.x * 2.0)  # Green, as the figures' plastic.
	assert_float(green.y).is_greater(green.z * 2.0)
	assert_float(hatch.get_shader_parameter(&"outline")).is_equal_approx(WarMap.CELL / 10.0, 0.0001)
	assert_float(hatch.get_shader_parameter(&"cell")).is_equal(WarMap.CELL)


## `count` field associates set down together in the second tutorial's zone (its middle, or `at`), played out.
func _second_tutorial(count: int, at := Vector2.INF) -> Dictionary:
	var map: WarMap = auto_free(load(TUTORIAL_2).instantiate())
	var plan: Array = [{unit = "field_associate", count = count, zone = 0}]
	if at != Vector2.INF:
		plan = [{unit = "field_associate", count = count, pos = at}]
	return BattleSim.run(map.layout(), map.grid_size, plan)


func test_the_second_tutorial_has_one_cannon_the_farmhouse_one_zone_and_no_fence() -> void:
	var map: WarMap = auto_free(load(TUTORIAL_2).instantiate())
	var kinds := map.layout().map(func(e: Dictionary) -> String: return e.kind)
	kinds.sort()
	assert_array(kinds).is_equal(["cannon", "farmhouse", "zone"])


func test_two_associates_lose_the_second_tutorial() -> void:
	assert_bool(_second_tutorial(2).won).is_false()


func test_three_associates_take_the_second_tutorial_losing_one_on_the_way_and_one_at_the_tower() -> void:
	var map: WarMap = auto_free(load(TUTORIAL_2).instantiate())
	var zone := Rect2(WarMap.cell_of(map.zones()[0]), WarMap.footprint(map.zones()[0])).grow(-0.5)
	for at: Vector2 in [zone.get_center(), zone.position, zone.end, Vector2(zone.end.x, zone.position.y), Vector2(zone.position.x, zone.end.y)]:
		var r := _second_tutorial(3, at)
		var deaths: Array = r.events.filter(func(e: Dictionary) -> bool: return e.what == "died")
		var downs: Array = r.events.filter(func(e: Dictionary) -> bool: return e.what == "down")
		assert_bool(r.won).override_failure_message(str(at)).is_true()
		assert_array(deaths.map(func(e: Dictionary) -> String: return e.by)).override_failure_message(str(at)).is_equal(["", "cannon"])
		assert_array(downs.map(func(e: Dictionary) -> String: return e.kind)).is_equal(["cannon", "farmhouse"])
		assert_float(downs[0].t).is_greater(deaths[1].t)  # The third one finishes the tower alone.


func test_four_associates_take_the_second_tutorial_comfortably() -> void:
	var r := _second_tutorial(4)
	assert_bool(r.won).is_true()
	assert_int(r.survivors.field_associate).is_greater_equal(3)


func _showcase() -> WarMap:
	var map: WarMap = auto_free(load(SHOWCASE).instantiate())
	add_child(map)
	return map


func _sorted(layout: Array) -> Array:
	var out := layout.map(func(e: Dictionary) -> String: return "%s %s %s" % [e.kind, e.cell, e.size])
	out.sort()
	return out


func test_a_map_scene_with_terrain_reads_as_the_same_layout_as_its_text() -> void:
	var map := _showcase()
	assert_array(_sorted(map.layout())).is_equal(_sorted(BattleSim.parse_layout(SHOWCASE_TEXT)))
	var kinds := map.buildings().map(func(n: Node) -> String: return WarMap.kind_of(n))
	kinds.sort()
	assert_array(kinds).is_equal(["cannon", "farmhouse", "mortar", "wall_wood", "wall_wood", "wall_wood"])
	assert_int(map.terrain().size()).is_equal(map.layout().size() - kinds.size() - map.zones().size())


func test_no_map_puts_a_zone_or_a_building_on_blocking_terrain() -> void:
	for path: String in Array(WarMap.map_paths()) + [SHOWCASE]:
		var map: WarMap = auto_free(load(path).instantiate())
		assert_array(Array(WarFight.problems(map.layout()))).override_failure_message(path).is_empty()


func _owning(farms: Array) -> SaveGame:
	var save := SaveGame.new()
	save.farms_owned = PackedStringArray(farms)
	return save


func test_the_nth_war_in_a_country_is_fought_on_its_nth_map_whichever_farm_is_attacked() -> void:
	var home := ["K-1", "K-2", "K-3", "K-4", "K-5"]
	for farm: StringName in [&"K-6", &"K-7", &"K-8"]:  # The first war at home is K-6's map, whichever farm.
		assert_str(WarMap.scene_for(farm, _owning(home))).is_equal(TUTORIAL)
	assert_str(WarMap.scene_for(&"K-6", _owning(home + ["K-8"]))).is_equal(TUTORIAL_2)  # K-8 taken first: K-6 is the second war.
	assert_str(WarMap.map_id(&"K-1", _owning(["K-2", "K-3", "K-5", "K-7", "K-8"]))).is_equal("K-6")  # Any five bought.
	assert_str(WarMap.map_id(&"veldmark-2", _owning(home))).is_equal("veldmark-1")
	assert_str(WarMap.map_id(&"veldmark-1", _owning(home + ["veldmark-2"]))).is_equal("veldmark-2")
	assert_str(WarMap.map_id(&"sulvania-3", _owning(["sulvania-1"]))).is_equal("sulvania-2")
	assert_str(WarMap.map_id(&"endmark-1", _owning(home))).is_equal("endmark-1")
	assert_str(WarMap.map_id(&"K-7", _owning(home + ["K-7"]))).is_equal("K-6")  # Once won, it keeps its map.


func test_a_war_without_its_map_fights_on_the_test_map() -> void:
	assert_str(WarMap.scene_for(&"K-1", SaveGame.new())).is_equal(WarMap.DEFAULT)  # Home farms one to five are bought, never fought.
	var paths := Array(WarMap.map_paths())
	assert_array(paths).contains([TUTORIAL, TUTORIAL_2, SCENE])
	assert_array(paths).not_contains([WarMap.MAPS + "zone.tscn"])


const TerrainPiece := preload("res://entities/war/terrain/terrain_piece.gd")


func test_touching_ponds_merge_their_rims_into_one_shore() -> void:
	var joined := {}
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]:  # Two 2x1 ponds, offset.
		joined[c] = true
	var alone := TerrainPiece.tiles(Vector2i(2, 1), {})
	var merged := TerrainPiece.tiles(Vector2i(2, 1), joined)
	assert_bool(alone.has(["edge", Vector2i(1, 0), 2])).is_true()  # On its own: a rim on the south side too.
	assert_bool(merged.has(["edge", Vector2i(1, 0), 2])).is_false()  # The other pond goes on there.
	assert_bool(merged.has(["corner", Vector2i(1, 0), 2])).is_true()  # And the shore turns the inner corner.
	assert_int(merged.filter(func(t: Array) -> bool: return t[0] == "base").size()).is_equal(2)


func test_hedges_join_toward_hedge_neighbours_and_a_bridge_deck_crosses_its_river() -> void:
	var map := _showcase()
	var arms := func(cell: Vector2i) -> Array:
		var hedge := _node_at(map, cell)
		return ["East", "North", "West", "South"].filter(func(a: String) -> bool: return (hedge.get_node("Arms/" + a) as Node3D).visible)
	assert_array(arms.call(Vector2i(10, 1))).is_equal(["East", "West"])
	assert_array(arms.call(Vector2i(11, 1))).is_equal(["West", "South"])
	assert_array(arms.call(Vector2i(3, 8))).is_equal(["East"])
	var deck := func(cell: Vector2i) -> float: return (_node_at(map, cell).get_node("Deck") as Node3D).rotation.y
	assert_float(deck.call(Vector2i(6, 3))).is_equal_approx(PI / 2.0, 0.001)  # The river runs north-south here.
	assert_float(deck.call(Vector2i(9, 6))).is_equal(0.0)


func test_a_wall_with_no_wall_neighbour_stands_as_a_segment_across_its_cell_not_a_lone_post() -> void:
	assert_array(WarMap.wall_arms(Vector2i(4, 4), {Vector2i(4, 4): true})).is_equal(["North", "South"])
	assert_array(WarMap.wall_arms(Vector2i(4, 4), {Vector2i(4, 4): true, Vector2i(5, 4): true})).is_equal(["East"])
	var map := _map()
	var corner := _node_at(map, Vector2i(7, 2))
	var alive := []
	for node in map.buildings():
		alive.append(WarMap.cell_of(node) not in [Vector2i(8, 2), Vector2i(7, 3)])  # Both its neighbours down.
	map.show_walls(alive)
	for arm: String in WarMap.ARMS:
		assert_bool((corner.get_node("Arms/" + arm) as Node3D).visible).override_failure_message(arm).is_equal(arm in WarMap.LONE_ARMS)
