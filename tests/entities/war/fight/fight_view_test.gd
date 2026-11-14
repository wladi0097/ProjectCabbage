extends GdUnitTestSuite

const SHEET := "res://entities/map_table/war_sheet.tscn"


func _view() -> FightView:
	var sheet: Node3D = auto_free(load(SHEET).instantiate())
	add_child(sheet)
	var view: FightView = sheet.get_node("Field")
	view.setup(sheet.get_node("Things/Map"))
	return view


func test_a_fallen_figure_tips_over_on_the_back_edge_of_its_base() -> void:
	var holder: Node3D = auto_free(FightView.figure("field_associate"))
	var soldier: Node3D = holder.get_node("Soldier")
	var edge := Vector3(0.0, 0.0, FightView.back_edge(soldier))
	var lying := FightView.pose(soldier, 1.0, 0.0, 0.0)
	assert_vector(lying * (edge / FightView.FIGURE_SCALE)).is_equal_approx(edge, Vector3.ONE * 0.0001)  # The edge stays put.
	var top := lying * Vector3(0.0, 0.1, 0.0)
	assert_float(top.y).is_equal_approx(-edge.z, 0.001)  # It lies down on its back,
	assert_float(top.z).is_less(edge.z)  # backwards.
	var standing := FightView.pose(soldier, 0.0, 0.0, 0.0)
	assert_vector(standing * Vector3(0.0, 0.1, 0.0)).is_equal_approx(Vector3(0.0, 0.1 * FightView.FIGURE_SCALE, 0.0), Vector3.ONE * 0.0001)


func test_figures_are_scaled_to_the_maps_cells() -> void:
	assert_float(FightView.FIGURE_SCALE).is_equal_approx(0.8, 0.0001)
	var holder: Node3D = auto_free(FightView.figure("field_associate"))
	assert_vector((holder.get_node("Soldier") as Node3D).scale).is_equal_approx(Vector3.ONE * 0.8, Vector3.ONE * 0.0001)


func test_every_shot_throws_a_cabbage_and_no_more_than_the_pool_lie_on_the_board() -> void:
	var view := _view()
	var map := view.map
	var fight := WarFight.new(map.layout(), map.grid_size, 90.0)
	for i in FightView.MAX_SHOTS + 10:
		view._event(fight, {kind = "shot", by = "cannon", from = fight.centre(0), to = Vector2(1, 1), splash = 0.0, travel = 0.3})
	assert_int(view.shots_thrown()).is_equal(FightView.MAX_SHOTS)
	assert_int(view.get_node("Shots").get_child_count()).is_equal(FightView.MAX_SHOTS)


func test_a_thrown_cabbage_lands_where_the_shot_lands_after_its_travel() -> void:
	var view := _view()
	view._throw(Vector3(0.0, 0.1, 0.5), Vector3(0.4, 0.016, 0.9), 0.5, 0.0)
	view._fly(0.25)
	var body: RigidBody3D = view._shots[0]
	assert_bool(body.freeze).is_true()  # Still in the air.
	assert_float(body.global_position.y).is_greater(0.1)
	view._fly(0.26)
	assert_bool(body.freeze).is_false()  # Down: it rolls and lies there.
	assert_vector(body.global_position).is_equal_approx(Vector3(0.4, 0.016, 0.9), Vector3.ONE * 0.0001)


func test_a_building_at_zero_hp_turns_to_rubble_and_its_wall_neighbours_drop_their_arms() -> void:
	var view := _view()
	var map := view.map
	var fight := WarFight.new(map.layout(), map.grid_size, 90.0)
	var wall := -1
	for i in fight.buildings.size():
		if fight.buildings[i].cell == Vector2i(4, 1):
			wall = i
	view.follow(fight, 0.0)
	fight.buildings[wall].hp = 0.0
	fight.buildings[wall].alive = false
	view.follow(fight, 0.016)
	var nodes := map.buildings()
	assert_bool((nodes[wall].get_node("Rubble") as Node3D).visible).is_true()
	for i in nodes.size():
		if WarMap.cell_of(nodes[i]) == Vector2i(3, 1):
			assert_bool((nodes[i].get_node("Arms/East") as Node3D).visible).is_false()
