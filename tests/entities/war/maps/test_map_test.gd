extends GdUnitTestSuite

const SCENE := "res://entities/war/maps/test_map.tscn"


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


func test_the_test_map_has_three_landing_spots_a_wooden_ring_two_cannons_a_mortar_and_the_farmhouse() -> void:
	var map := _map()
	assert_that(map.grid_size).is_equal(Vector2i(12, 8))
	assert_int(_count(map, "landing")).is_equal(3)
	assert_int(_count(map, "cannon")).is_equal(2)
	assert_int(_count(map, "mortar")).is_equal(1)
	assert_int(_count(map, "farmhouse")).is_equal(1)
	assert_int(_count(map, "wall_wood")).is_greater(0)
	assert_int(map.landings().size()).is_equal(3)
	assert_int(map.buildings().size()).is_equal(map.layout().size() - 3)


func test_every_piece_of_the_test_map_lies_on_its_grid_without_overlapping() -> void:
	var taken := {}
	for entry: Dictionary in _map().layout():
		for y in entry.size.y:
			for x in entry.size.x:
				var cell: Vector2i = entry.cell + Vector2i(x, y)
				assert_bool(Rect2i(Vector2i.ZERO, Vector2i(12, 8)).has_point(cell)).override_failure_message(str(entry)).is_true()
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
	var corner := _node_at(map, Vector2i(3, 1))  # The ring's top-left corner: neighbours east and south.
	assert_bool(WarMap.kind_of(corner) == "wall_wood").is_true()
	var arms := func(wall: Node3D) -> Array:
		return ["East", "North", "West", "South"].filter(func(a: String) -> bool: return (wall.get_node("Arms/" + a) as Node3D).visible)
	assert_array(arms.call(corner)).is_equal(["East", "South"])
	var alive := []
	for node in map.buildings():
		alive.append(WarMap.cell_of(node) != Vector2i(4, 1))  # Its east neighbour is down.
	map.show_walls(alive)
	assert_array(arms.call(corner)).is_equal(["South"])


func test_a_building_down_shows_its_rubble_and_nothing_else() -> void:
	var cannon := _node_at(_map(), Vector2i(4, 2))
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
