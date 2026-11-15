extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/cannon.tscn")


func _inside_cell(box: AABB) -> bool:
	var h := WarMap.CELL / 2.0
	return box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h


func test_the_watchtower_and_its_wreck_stay_inside_their_cell() -> void:
	var cannon: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Rubble"]:
		assert_bool(_inside_cell((cannon.get_node(part) as MeshInstance3D).mesh.get_aabb())).override_failure_message(part).is_true()


func test_the_cannon_turns_on_top_of_the_tower() -> void:
	var cannon: Node3D = auto_free(SCENE.instantiate())
	var tower_top: float = (cannon.get_node("Base") as MeshInstance3D).mesh.get_aabb().end.y
	var turret: Node3D = cannon.get_node("Turret")
	assert_float(turret.position.y).is_greater(WarMap.CELL * 0.7)  # a tower, not a gun on the paper
	assert_float(turret.position.y).is_less(tower_top)


func test_the_muzzle_sits_at_the_barrel_end_above_the_platform_facing_north() -> void:
	var cannon: Node3D = auto_free(SCENE.instantiate())
	var turret: Node3D = cannon.get_node("Turret")
	var muzzle: Node3D = cannon.get_node("Turret/Muzzle")
	var gun: AABB = (cannon.get_node("Turret/Mesh") as MeshInstance3D).mesh.get_aabb()
	assert_float(muzzle.position.z).is_equal_approx(gun.position.z, 0.004)  # the barrel's far end, -Z
	assert_float(turret.position.y + muzzle.position.y).is_greater(turret.position.y)


func test_the_cannon_is_built_from_the_maquette_palette() -> void:
	var cannon: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var mesh: Mesh = (cannon.get_node(part) as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			assert_str(mesh.surface_get_material(k).resource_path).starts_with("res://assets/materials/maquette/maquette_")
