extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/shredder.tscn")


func _inside_cell(box: AABB) -> bool:
	var h := WarMap.CELL / 2.0
	return box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h


func test_the_shredder_its_strips_and_its_wreck_stay_inside_their_cell() -> void:
	var shredder: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble", "Base/Strips", "Rubble/Strips"]:
		var node: GeometryInstance3D = shredder.get_node(part)
		assert_bool(_inside_cell(node.get_aabb())).override_failure_message(part).is_true()


func test_the_muzzle_is_the_feed_slot_at_the_front_of_the_head() -> void:
	var shredder: Node3D = auto_free(SCENE.instantiate())
	var muzzle: Node3D = shredder.get_node("Turret/Muzzle")
	var head: AABB = (shredder.get_node("Turret/Mesh") as MeshInstance3D).mesh.get_aabb()
	assert_float(muzzle.position.z).is_less(head.get_center().z - 0.01)  # the front half, facing -Z
	assert_float(absf(muzzle.position.x)).is_less(0.001)
	assert_bool(head.grow(0.002).has_point(muzzle.position)).is_true()


func test_the_bin_holds_cabbage_green_strips_that_scatter_on_the_wreck() -> void:
	var shredder: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base/Strips", "Rubble/Strips"]:
		var strips: MultiMeshInstance3D = shredder.get_node(part)
		assert_str(strips.material_override.resource_path).is_equal("res://assets/materials/cabbage.tres")
		assert_int(strips.multimesh.instance_count).is_greater(0)


func test_the_shredder_is_built_from_the_maquette_palette() -> void:
	var shredder: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var mesh: Mesh = (shredder.get_node(part) as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			assert_str(mesh.surface_get_material(k).resource_path).starts_with("res://assets/materials/maquette/maquette_")


func test_a_wrecked_shredder_is_crushed_to_a_third_of_its_height() -> void:
	var shredder: Node3D = auto_free(SCENE.instantiate())
	var standing: float = (shredder.get_node("Turret") as Node3D).position.y + (shredder.get_node("Turret/Mesh") as MeshInstance3D).mesh.get_aabb().end.y
	assert_float((shredder.get_node("Rubble") as MeshInstance3D).mesh.get_aabb().end.y).is_less(standing / 3.0)
