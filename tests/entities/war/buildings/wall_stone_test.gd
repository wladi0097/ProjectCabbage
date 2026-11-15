extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/wall_stone.tscn")
const WOOD := preload("res://entities/war/buildings/wall_wood.tscn")
const RubbleTurn := preload("res://entities/war/buildings/rubble_turn.gd")


func _box(scene: PackedScene, part: String) -> AABB:
	var wall: Node3D = auto_free(scene.instantiate())
	return (wall.get_node(part) as MeshInstance3D).mesh.get_aabb()


func test_a_masonry_arm_reaches_exactly_the_cell_edge_so_neighbouring_pieces_join() -> void:
	assert_float(_box(SCENE, "Arms/East").end.x).is_equal_approx(WarMap.CELL / 2.0, 0.0005)


func test_the_masonry_and_its_broken_blocks_stay_inside_their_cell() -> void:
	for part in ["Post", "Arms/East", "Rubble"]:
		var box := _box(SCENE, part)
		var h := WarMap.CELL / 2.0
		assert_bool(box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h).override_failure_message(part).is_true()


func test_the_masonry_is_lower_and_wider_than_the_wooden_picket() -> void:
	assert_float(_box(SCENE, "Post").end.y).is_less(_box(WOOD, "Post").end.y)
	assert_float(_box(SCENE, "Arms/East").size.z).is_greater(_box(WOOD, "Arms/East").size.z)


func test_the_masonry_is_built_from_grey_board_with_white_cut_edges() -> void:
	var wall: Node3D = auto_free(SCENE.instantiate())
	for part in ["Post", "Arms/East", "Rubble"]:
		var mesh: Mesh = (wall.get_node(part) as MeshInstance3D).mesh
		assert_str(mesh.surface_get_material(0).resource_path).is_equal("res://assets/materials/maquette/maquette_grey_board.tres")
		assert_str(mesh.surface_get_material(1).resource_path).is_equal("res://assets/materials/maquette/maquette_core.tres")


func test_a_wrecked_masonry_piece_is_turned_by_its_spot_and_stays_inside_its_cell() -> void:
	var wall: Node3D = auto_free(SCENE.instantiate())
	wall.position = WarMap.point(Vector2(5.5, 2.5))
	add_child(wall)
	var rubble: MeshInstance3D = wall.get_node("Rubble")
	var turn := RubbleTurn.look(Vector2(wall.position.x, wall.position.z))
	assert_float(rubble.rotation.y).is_equal_approx(turn.x * PI / 2.0, 0.0001)
	var box := rubble.transform * rubble.mesh.get_aabb()
	var h := WarMap.CELL / 2.0
	assert_bool(box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h).is_true()
