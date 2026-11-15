extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/silo.tscn")


func test_the_silo_and_its_burst_wreck_stay_inside_their_two_by_two_cells() -> void:
	var silo: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Rubble"]:
		var box: AABB = (silo.get_node(part) as MeshInstance3D).mesh.get_aabb()
		assert_bool(box.position.x >= -WarMap.CELL and box.end.x <= WarMap.CELL and box.position.z >= -WarMap.CELL and box.end.z <= WarMap.CELL) \
				.override_failure_message(part).is_true()


func test_the_burst_comes_from_inside_the_silo_drum() -> void:
	var silo: Node3D = auto_free(SCENE.instantiate())
	var burst: Node3D = silo.get_node("Burst")
	var base: AABB = (silo.get_node("Base") as MeshInstance3D).mesh.get_aabb()
	assert_bool(base.has_point(burst.position)).is_true()
	assert_float(burst.position.y).is_between(base.size.y * 0.25, base.size.y * 0.75)
	assert_float(Vector2(burst.position.x, burst.position.z).length()).is_less(0.01)


func test_the_silo_bursts_down_to_a_low_wreck() -> void:
	var silo: Node3D = auto_free(SCENE.instantiate())
	var standing: float = (silo.get_node("Base") as MeshInstance3D).mesh.get_aabb().end.y
	assert_float((silo.get_node("Rubble") as MeshInstance3D).mesh.get_aabb().end.y).is_less(standing * 0.5)


func test_the_muzzle_sits_at_the_barrel_end_on_the_roof_facing_north() -> void:
	var silo: Node3D = auto_free(SCENE.instantiate())
	var muzzle: Node3D = silo.get_node("Turret/Muzzle")
	var gun: AABB = (silo.get_node("Turret/Mesh") as MeshInstance3D).mesh.get_aabb()
	var roof: float = (silo.get_node("Base") as MeshInstance3D).mesh.get_aabb().end.y
	assert_float(muzzle.position.z).is_equal_approx(gun.position.z, 0.008)
	assert_float((silo.get_node("Turret") as Node3D).position.y).is_equal_approx(roof, 0.002)


func test_the_silo_is_built_from_the_maquette_palette() -> void:
	var silo: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var mesh: Mesh = (silo.get_node(part) as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			assert_str(mesh.surface_get_material(k).resource_path).starts_with("res://assets/materials/maquette/maquette_")
