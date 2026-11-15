extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/wall_wood.tscn")
const RubbleTurn := preload("res://entities/war/buildings/rubble_turn.gd")


func test_a_fence_arm_reaches_exactly_the_cell_edge_so_neighbouring_pieces_join() -> void:
	var wall: Node3D = auto_free(SCENE.instantiate())
	var arm: MeshInstance3D = wall.get_node("Arms/East")
	assert_float(arm.mesh.get_aabb().end.x).is_equal_approx(WarMap.CELL / 2.0, 0.0005)


func test_the_fence_and_its_splinters_stay_inside_their_cell() -> void:
	var wall: Node3D = auto_free(SCENE.instantiate())
	for part in ["Post", "Rubble"]:
		var box: AABB = (wall.get_node(part) as MeshInstance3D).mesh.get_aabb()
		assert_bool(box.position.x >= -WarMap.CELL / 2.0 and box.end.x <= WarMap.CELL / 2.0).override_failure_message(part).is_true()
		assert_bool(box.position.z >= -WarMap.CELL / 2.0 and box.end.z <= WarMap.CELL / 2.0).override_failure_message(part).is_true()


func test_the_fence_is_built_from_the_shared_balsa() -> void:
	var wall: Node3D = auto_free(SCENE.instantiate())
	for part in ["Post", "Arms/East", "Rubble"]:
		var mesh: Mesh = (wall.get_node(part) as MeshInstance3D).mesh
		assert_str(mesh.surface_get_material(0).resource_path).is_equal("res://assets/materials/maquette/maquette_balsa.tres")


func test_a_row_of_fence_wrecks_is_turned_and_mirrored_so_it_does_not_repeat_one_stamp() -> void:
	var looks := {}
	for x in 8:
		var spot := WarMap.point(Vector2(x, 2) + Vector2(0.5, 0.5))
		looks[RubbleTurn.look(Vector2(spot.x, spot.z))] = true
	assert_int(looks.size()).is_greater(2)


func test_a_wrecked_fence_piece_is_turned_by_its_spot_and_stays_inside_its_cell() -> void:
	var wall: Node3D = auto_free(SCENE.instantiate())
	wall.position = WarMap.point(Vector2(3.5, 6.5))
	add_child(wall)
	var rubble: MeshInstance3D = wall.get_node("Rubble")
	var turn := RubbleTurn.look(Vector2(wall.position.x, wall.position.z))
	assert_float(rubble.rotation.y).is_equal_approx(turn.x * PI / 2.0, 0.0001)
	var box := rubble.transform * rubble.mesh.get_aabb()
	var h := WarMap.CELL / 2.0
	assert_bool(box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h).is_true()
