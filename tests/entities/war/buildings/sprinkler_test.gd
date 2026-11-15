extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/sprinkler.tscn")


func _inside_cell(box: AABB) -> bool:
	var h := WarMap.CELL / 2.0
	return box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h


func test_the_sprinkler_and_its_wreck_stay_inside_their_cell_on_the_paper() -> void:
	var sprinkler: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var box: AABB = (sprinkler.get_node(part) as MeshInstance3D).mesh.get_aabb()
		assert_bool(_inside_cell(box)).override_failure_message(part).is_true()
		assert_float(box.position.y).override_failure_message(part).is_greater_equal(-0.0005)


func test_the_sprinkler_squats_lower_than_the_cannon_tower() -> void:
	var sprinkler: Node3D = auto_free(SCENE.instantiate())
	var cannon: Node3D = auto_free(preload("res://entities/war/buildings/cannon.tscn").instantiate())
	assert_float((sprinkler.get_node("Turret") as Node3D).position.y).is_less((cannon.get_node("Turret") as Node3D).position.y)


func test_the_muzzle_is_the_nozzle_at_the_tip_of_the_north_arm() -> void:
	var sprinkler: Node3D = auto_free(SCENE.instantiate())
	var muzzle: Node3D = sprinkler.get_node("Turret/Muzzle")
	var head: AABB = (sprinkler.get_node("Turret/Mesh") as MeshInstance3D).mesh.get_aabb()
	assert_float(muzzle.position.z).is_less(head.position.z * 0.85)  # out at the arm's end, -Z
	assert_float(absf(muzzle.position.x)).is_less(0.001)
	assert_bool(head.grow(0.002).has_point(muzzle.position)).is_true()


func test_the_sprinkler_is_built_from_the_maquette_palette() -> void:
	var sprinkler: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var mesh: Mesh = (sprinkler.get_node(part) as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			assert_str(mesh.surface_get_material(k).resource_path).starts_with("res://assets/materials/maquette/maquette_")


func test_a_wrecked_sprinkler_lies_flat_below_half_its_tank() -> void:
	var sprinkler: Node3D = auto_free(SCENE.instantiate())
	var tank: float = (sprinkler.get_node("Base") as MeshInstance3D).mesh.get_aabb().end.y
	assert_float((sprinkler.get_node("Rubble") as MeshInstance3D).mesh.get_aabb().end.y).is_less(tank * 0.5)
