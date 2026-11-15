extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/mortar.tscn")


func test_the_mortar_ring_and_its_wreck_stay_inside_their_two_by_two_cells() -> void:
	var mortar: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Rubble"]:
		var box: AABB = (mortar.get_node(part) as MeshInstance3D).mesh.get_aabb()
		assert_bool(box.position.x >= -WarMap.CELL and box.end.x <= WarMap.CELL and box.position.z >= -WarMap.CELL and box.end.z <= WarMap.CELL) \
				.override_failure_message(part).is_true()


func test_the_mortar_squats_low_unlike_the_cannon_tower() -> void:
	var mortar: Node3D = auto_free(SCENE.instantiate())
	var cannon: Node3D = auto_free(preload("res://entities/war/buildings/cannon.tscn").instantiate())
	assert_float((mortar.get_node("Turret/Muzzle") as Node3D).position.y + (mortar.get_node("Turret") as Node3D).position.y) \
			.is_less((cannon.get_node("Turret") as Node3D).position.y)


func test_the_mortar_is_built_from_the_maquette_palette() -> void:
	var mortar: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var mesh: Mesh = (mortar.get_node(part) as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			assert_str(mesh.surface_get_material(k).resource_path).starts_with("res://assets/materials/maquette/maquette_")
