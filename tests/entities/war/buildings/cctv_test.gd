extends GdUnitTestSuite

const SCENE := preload("res://entities/war/buildings/cctv.tscn")
const OTHERS := ["cannon", "mortar", "farmhouse", "sprinkler", "shredder", "silo"]


func _inside_cell(box: AABB) -> bool:
	var h := WarMap.CELL / 2.0
	return box.position.x >= -h and box.end.x <= h and box.position.z >= -h and box.end.z <= h


## The highest point of a standing building (its turret on top, if it has one).
func _top(building: Node3D) -> float:
	var top := 0.0
	for mi: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "Rubble":
			var lift: float = (mi.get_parent() as Node3D).position.y if mi.get_parent() != building else 0.0
			top = maxf(top, lift + mi.mesh.get_aabb().end.y)
	return top


func test_the_mast_and_its_wreck_stay_inside_their_cell() -> void:
	var cctv: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		assert_bool(_inside_cell((cctv.get_node(part) as MeshInstance3D).mesh.get_aabb())).override_failure_message(part).is_true()


func test_the_cctv_mast_is_the_tallest_piece_on_the_map() -> void:
	var cctv: Node3D = auto_free(SCENE.instantiate())
	for kind: String in OTHERS:
		var other: Node3D = auto_free((load("res://entities/war/buildings/%s.tscn" % kind) as PackedScene).instantiate())
		assert_float(_top(cctv)).override_failure_message(kind).is_greater(_top(other) * 1.3)


func test_the_muzzle_is_the_lens_at_the_front_of_the_camera_head() -> void:
	var cctv: Node3D = auto_free(SCENE.instantiate())
	var muzzle: Node3D = cctv.get_node("Turret/Muzzle")
	var head: AABB = (cctv.get_node("Turret/Mesh") as MeshInstance3D).mesh.get_aabb()
	assert_bool(head.grow(0.001).has_point(muzzle.position)).is_true()
	assert_float(muzzle.position.z).is_less(head.get_center().z - 0.02)  # the front, facing -Z
	assert_float(absf(muzzle.position.x)).is_less(0.001)


func test_the_cctv_mast_is_built_from_the_maquette_palette() -> void:
	var cctv: Node3D = auto_free(SCENE.instantiate())
	for part in ["Base", "Turret/Mesh", "Rubble"]:
		var mesh: Mesh = (cctv.get_node(part) as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			assert_str(mesh.surface_get_material(k).resource_path).starts_with("res://assets/materials/maquette/maquette_")
