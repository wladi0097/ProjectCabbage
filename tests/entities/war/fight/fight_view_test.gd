extends GdUnitTestSuite

const SHEET := "res://entities/map_table/war_sheet.tscn"


func _view() -> FightView:
	var sheet: Node3D = auto_free(load(SHEET).instantiate())
	add_child(sheet)
	var view: FightView = sheet.get_node("Field")
	view.setup(sheet.get_node("Things/Board/Map"))
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


## A mortar's and a cannon's shot over the same way, from `view`'s fight on its map.
func _mortar_and_cannon(view: FightView) -> void:
	var fight := WarFight.new(view.map.layout(), view.map.grid_size, 90.0)
	for by in ["mortar", "cannon"]:
		view._event(fight, {kind = "shot", by = by, from = Vector2(1, 1), to = Vector2(6, 1), splash = WarFight.BUILDINGS[by].splash, travel = 1.0})


func test_the_mortar_lobs_a_dark_shell_higher_than_the_cannons_cabbage() -> void:
	var view := _view()
	_mortar_and_cannon(view)
	assert_int(view.shots_thrown()).is_equal(1)  # Only the cannon throws a cabbage;
	var shell: Node3D = view._flying[0].body
	assert_str(shell.scene_file_path).is_equal("res://entities/war/fight/mortar_shell.tscn")  # the mortar a shell.
	view._fly(0.5)
	assert_float(shell.global_position.y).is_greater((view._shots[0] as Node3D).global_position.y + 0.2)


func test_the_mortar_shells_shadow_grows_on_the_paper_where_it_comes_down() -> void:
	var view := _view()
	_mortar_and_cannon(view)
	var shell: Node3D = view._flying[0].body
	var shadow: Node3D = shell.get_node("Shadow")
	view._fly(0.2)
	var early := shadow.global_transform.basis.get_scale().x
	assert_vector(shadow.global_position * Vector3(1, 0, 1)).is_equal_approx(view.spot(Vector2(6, 1)) * Vector3(1, 0, 1), Vector3.ONE * 0.0001)
	var target: MeshInstance3D = shell.get_node("Target")
	var faint := target.transparency
	view._fly(0.6)
	assert_float(shadow.global_transform.basis.get_scale().x).is_greater(early * 1.5)
	assert_float(target.transparency).is_less(faint)  # The splash circle draws in as it falls,
	var splash: float = WarFight.BUILDINGS.mortar.splash
	var edge := view.spot(Vector2(6, 1)).distance_to(view.spot(Vector2(6 + splash, 1)))
	assert_float(target.global_transform.basis.get_scale().x * (target.mesh as TorusMesh).outer_radius).is_equal_approx(edge, 0.0001)  # exactly the splash wide.


func test_the_mortars_impact_spans_its_splash_radius_and_lands_after_its_travel() -> void:
	var view := _view()
	_mortar_and_cannon(view)
	var shell: Node3D = view._flying[0].body
	view._fly(0.99)
	assert_bool(shell.is_queued_for_deletion()).is_false()  # Still in the air,
	view._fly(0.02)
	assert_bool(shell.is_queued_for_deletion()).is_true()  # down on its travel, as the shot's sound has it.
	var impacts := view.get_node("Shots").get_children().filter(func(n: Node) -> bool: return n.scene_file_path == "res://entities/war/fight/mortar_impact.tscn")
	assert_int(impacts.size()).is_equal(1)
	var impact: Node3D = impacts[0]
	var splash: float = WarFight.BUILDINGS.mortar.splash
	var edge := view.spot(Vector2(6, 1)).distance_to(view.spot(Vector2(6 + splash, 1)))
	assert_float(impact.global_transform.basis.get_scale().x).is_equal_approx(edge, 0.0001)  # Scaled to the splash,
	assert_float((impact.get_node("Ring") as MeshInstance3D).mesh.get("outer_radius")).is_equal(1.0)  # its shock ring
	assert_float((impact.get_node("Edge") as MeshInstance3D).mesh.get("outer_radius")).is_equal(1.0)  # and pencil edge reach it,
	var dust: CPUParticles3D = impact.get_node("Dust")
	assert_float(dust.emission_ring_radius).is_between(0.85, 1.0)  # and dust covers it.
	assert_bool(dust.local_coords).is_true()


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


func test_a_placed_figure_first_stands_where_it_was_set_down_even_beside_others() -> void:
	var view := _view()
	var fight := WarFight.new(view.map.layout(), view.map.grid_size, 90.0)
	for i in 3:
		fight.place_at("field_associate", WarRules.unit_stats(SaveGame.new(), "field_associate"), Vector2(4.0 + i * 0.2, 1.5))
		var holder := FightView.figure("field_associate")
		view.figures.add_child(holder)  # Off the desk, as the war sheet hands it over.
		view.add_unit(holder)
	view.follow(fight, 0.0)
	for i in 3:
		assert_vector(view.units[i].position).is_equal_approx(WarMap.point(fight.units[i].pos), Vector3.ONE * 0.0001)


## A view on a map laid out from `text` (BattleSim.parse_layout), on the war sheet.
func _view_on(text: String) -> FightView:
	var sheet: Node3D = auto_free(load(SHEET).instantiate())
	add_child(sheet)
	var map := WarMap.new()
	sheet.get_node("Things/Board").add_child(map)
	for piece: Dictionary in BattleSim.parse_layout(text):
		var zone: bool = piece.kind == "zone"
		var node: Node3D = load("res://entities/war/%s/%s.tscn" % ["maps" if zone else "buildings", piece.kind]).instantiate()
		node.position = WarMap.point(Vector2(piece.cell) + Vector2(piece.size) / 2.0)
		if zone:
			node.scale = Vector3(piece.size.x, 1.0, piece.size.y)
		map.add_child(node)
	var view: FightView = sheet.get_node("Field")
	view.setup(map)
	return view


## Places a figure of `unit` at `pos` in `fight` and on `view`.
func _put(view: FightView, fight: WarFight, unit: String, pos: Vector2) -> void:
	assert_bool(fight.place_at(unit, WarRules.unit_stats(SaveGame.new(), unit), pos)).is_true()
	var holder := FightView.figure(unit)
	view.figures.add_child(holder)
	view.add_unit(holder)


## The effect scenes `path` under Shots not in `seen` (instance ids), added to it.
func _new_effects(view: FightView, path: String, seen: Dictionary) -> Array[CPUParticles3D]:
	var out: Array[CPUParticles3D] = []
	for child in view.get_node("Shots").get_children():
		if child.scene_file_path == path and not seen.has(child.get_instance_id()):
			seen[child.get_instance_id()] = true
			out.append(child)
	return out


func test_a_courier_jumps_over_the_fence_cell_during_its_hop() -> void:
	var view := _view_on("farmhouse@10,1; wall_steel@5,0,1x6; zone@1,1,3x3")
	var fight := WarFight.new(view.map.layout(), view.map.grid_size, 90.0)
	_put(view, fight, "courier", Vector2(2.5, 2.5))
	fight.start()
	var over := 0.0  # Its highest lift while it is seen over the fence's cells.
	for k in 240:
		fight.tick(1.0 / 60.0)
		view.follow(fight, 1.0 / 60.0)
		var seen_at := Vector2(view.units[0].position.x, view.units[0].position.z) / WarMap.CELL
		if seen_at.x >= 5.0 and seen_at.x <= 6.0:
			over = maxf(over, (view.units[0].get_node("Soldier") as Node3D).position.y)
	assert_float(fight.units[0].pos.x).is_greater(6.5)  # It is past the fence,
	assert_float(over).is_greater(0.076)  # cleared the security grade's post in the air,
	assert_bool(fight.buildings.all(func(b: Dictionary) -> bool: return b.kind not in WarFight.WALLS or b.hp == b.max_hp)).is_true()  # and left it standing.
	assert_float((view.units[0].get_node("Soldier") as Node3D).position.y).is_equal_approx(0.0, 0.0001)  # Down again.


func test_the_shredders_stream_of_strips_grows_with_its_streak() -> void:
	var view := _view_on("shredder@6,4; farmhouse@14,4; zone@3,3,2x3")
	var fight := WarFight.new(view.map.layout(), view.map.grid_size, 90.0)
	_put(view, fight, "senior_asset", Vector2(4.0, 4.5))
	fight.start()
	var seen := {}
	var strips: Array[int] = []
	for k in 600:
		fight.tick(1.0 / 60.0)
		view.follow(fight, 1.0 / 60.0)
		for stream in _new_effects(view, "res://entities/war/fight/strips.tscn", seen):
			strips.append(stream.amount)
	assert_int(strips.size()).is_greater(5)
	assert_int(strips[0]).is_equal(FightView.STRIPS_MIN)
	for k in range(1, strips.size()):
		assert_int(strips[k]).is_greater_equal(strips[k - 1])  # It only thickens while it holds its figure,
	assert_int(strips[-1]).is_greater(strips[0] * 3)  # and by a lot.
	assert_int(FightView.strip_count(1000)).is_equal(FightView.STRIPS_MAX)


func test_a_fallen_silo_bursts_and_rocks_the_figure_it_spares() -> void:
	var view := _view_on("silo@6,4; farmhouse@14,4; zone@4,4,2x2")
	var fight := WarFight.new(view.map.layout(), view.map.grid_size, 90.0)
	_put(view, fight, "senior_asset", Vector2(5.5, 5.0))
	_put(view, fight, "field_associate", Vector2(5.5, 4.4))
	fight.units[1].hp = WarFight.BUILDINGS.silo.burst / 2.0  # Hit on the way in: the burst finishes it.
	fight.start()
	view.follow(fight, 0.0)
	fight._hurt(0, 10000.0)  # The silo falls.
	var seen := {}
	view.follow(fight, 1.0 / 60.0)
	assert_bool((view.map.buildings()[0].get_node("Rubble") as Node3D).visible).is_true()
	assert_int(_new_effects(view, "res://entities/war/fight/debris.tscn", seen).size()).is_equal(1)  # Card bits,
	assert_int(_new_effects(view, "res://entities/war/fight/puff.tscn", seen).size()).is_greater(FightView.BURST_PUFFS)  # a ring of puffs.
	for k in 30:
		view.follow(fight, 1.0 / 60.0)
	assert_bool(fight.units[0].alive).is_true()
	var up := (view.units[0].get_node("Soldier") as Node3D).transform.basis.y.normalized()
	assert_float(up.y).is_less(0.9)  # The senior asset rocks over,
	assert_bool(fight.units[1].alive).is_false()
	for k in 60:
		view.follow(fight, 1.0 / 60.0)
	up = (view.units[0].get_node("Soldier") as Node3D).transform.basis.y.normalized()
	assert_float(up.y).is_greater(0.999)  # and stands again;
	up = (view.units[1].get_node("Soldier") as Node3D).transform.basis.y.normalized()
	assert_float(up.y).is_less(0.2)  # the associate lies where it fell.


func test_a_new_map_with_as_many_buildings_keeps_its_own_building_spots() -> void:
	var view := _view_on("farmhouse@10,1")
	var first := view.map
	var second := WarMap.new()
	first.get_parent().add_child(second)
	var house: Node3D = load("res://entities/war/buildings/farmhouse.tscn").instantiate()
	var spot := WarMap.point(Vector2(3.5, 4.5))
	house.position = spot
	second.add_child(house)
	view.setup(second)
	assert_vector(second.buildings()[0].position).is_equal(spot)
