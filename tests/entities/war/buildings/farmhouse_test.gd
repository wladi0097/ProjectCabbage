extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/farmhouse.tscn")
const HALF := WarMap.CELL  # 2x2 cells, centred on the footprint


func test_the_farmhouse_and_its_wreck_stay_inside_their_two_by_two_cells() -> void:
	var house: Node3D = auto_free(SCENE.instantiate())
	for part in ["Mesh", "Rubble"]:
		var box: AABB = (house.get_node(part) as MeshInstance3D).mesh.get_aabb()
		assert_bool(box.position.x >= -HALF and box.end.x <= HALF and box.position.z >= -HALF and box.end.z <= HALF) \
				.override_failure_message(part).is_true()


func test_the_farmhouse_collider_covers_its_two_by_two_footprint_centred_on_it() -> void:
	var house: Node3D = auto_free(SCENE.instantiate())
	var shape: CollisionShape3D = house.get_node("Body/Shape")
	var size: Vector3 = (shape.shape as BoxShape3D).size
	assert_float(size.x).is_between(HALF * 1.8, HALF * 2.0)
	assert_float(size.z).is_between(HALF * 1.8, HALF * 2.0)
	assert_float(shape.position.x).is_equal(0.0)
	assert_float(shape.position.z).is_equal(0.0)


func test_the_farmhouse_is_card_on_a_grey_board_site_plate() -> void:
	var house: Node3D = auto_free(SCENE.instantiate())
	var used := []
	var mesh: Mesh = (house.get_node("Mesh") as MeshInstance3D).mesh
	for k in mesh.get_surface_count():
		used.append(mesh.surface_get_material(k).resource_path.get_file())
	assert_array(used).contains(["maquette_card.tres", "maquette_core.tres", "maquette_grey_board.tres"])


func test_the_farmhouse_crates_hold_green_cabbages_that_go_down_with_the_house() -> void:
	var house: Node3D = auto_free(SCENE.instantiate())
	var cabbages: MultiMeshInstance3D = house.get_node("Mesh/Cabbages")
	assert_int(cabbages.multimesh.instance_count).is_greater(0)
	assert_str(cabbages.material_override.resource_path).is_equal("res://assets/materials/cabbage.tres")
	assert_object(cabbages.get_parent()).is_same(house.get_node("Mesh"))  # wreck() hides Mesh, crates and all
	WarMap.wreck(house, true)
	assert_bool((house.get_node("Mesh") as Node3D).visible).is_false()
