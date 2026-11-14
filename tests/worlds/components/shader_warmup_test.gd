extends GdUnitTestSuite

const SCENE := preload("res://worlds/components/shader_warmup.tscn")
const CABBAGE := preload("res://assets/materials/cabbage.tres")


func _drawn(warmup: Node) -> Array:
	var pairs := []
	for mesh: MeshInstance3D in warmup.find_children("*", "MeshInstance3D", true, false):
		pairs.append([mesh.mesh, mesh.material_override])
	return pairs


func test_the_warm_up_shows_every_cabbage_look_on_every_cabbage_mesh() -> void:
	var warmup: Node3D = auto_free(SCENE.instantiate())
	var drawn := _drawn(warmup)
	for look: Material in [CABBAGE, Cabbage.ROTTEN_MATERIAL, Cabbage.GOLD_MATERIAL, Cabbage.RESEARCH_MATERIAL]:
		for mesh: Mesh in Cabbage.MESHES:
			assert_bool(drawn.has([mesh, look])).is_true()


func test_the_research_look_is_drawn_under_the_research_cabbages_cyan_glow() -> void:
	var warmup: Node3D = auto_free(SCENE.instantiate())
	var glows := warmup.find_children("*", "OmniLight3D", true, false)
	assert_int(glows.size()).is_equal(1)
	var glow: OmniLight3D = glows[0]
	assert_that(glow.light_color).is_equal(Cabbage.RESEARCH_LIGHT)
	assert_float(glow.light_energy).is_equal_approx(0.5, 0.0001)
	assert_float(glow.omni_range).is_equal_approx(0.35, 0.0001)
	for mesh: MeshInstance3D in warmup.find_children("*", "MeshInstance3D", true, false):
		assert_float(mesh.position.distance_to(glow.position)).is_less(glow.omni_range)


func test_the_warm_up_draws_every_shared_material_and_the_coin_multimesh() -> void:
	var warmup: Node3D = auto_free(SCENE.instantiate())
	var used := []
	for pair: Array in _drawn(warmup):
		used.append(pair[1])
	var coins: MultiMeshInstance3D = warmup.get_node("Coin")
	assert_bool(coins.multimesh.use_custom_data and coins.multimesh.use_colors).is_true()
	used.append(coins.multimesh.mesh.surface_get_material(0))
	for file in DirAccess.get_files_at("res://assets/materials"):
		if file.ends_with(".tres"):
			assert_bool(used.has(load("res://assets/materials/" + file))).override_failure_message(file).is_true()


func test_the_warm_up_has_no_bodies_and_nothing_hidden() -> void:
	var warmup: Node3D = auto_free(SCENE.instantiate())
	assert_array(warmup.find_children("*", "CollisionObject3D", true, false)).is_empty()
	for node: Node in warmup.find_children("*", "", true, false):
		if node is Node3D or node is CanvasItem:
			assert_bool(node.visible).is_true()


func test_the_warm_up_removes_itself_after_its_frames() -> void:
	var warmup: Node3D = SCENE.instantiate()
	add_child(warmup)
	for i in ShaderWarmup.FRAMES + 1:
		await await_idle_frame()
	assert_bool(is_instance_valid(warmup)).is_false()


func test_the_sleeves_hand_keeps_the_associates_skin_when_the_editor_saves_the_warm_up_again() -> void:
	var skin := preload("res://worlds/components/shader_warmup.tscn").instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var resaved := PackedScene.new()
	assert_int(resaved.pack(skin)).is_equal(OK)  # What the editor writes on a save.
	skin.free()
	var warmup: Node3D = auto_free(resaved.instantiate())
	var hand: MeshInstance3D = warmup.get_node("Sleeve/Armature/Skeleton3D/Hand")
	assert_object(hand.material_override).is_not_null()
	assert_str(hand.material_override.resource_path).ends_with("associate_hand.tres")


func test_the_warm_up_draws_the_field_lines_lamps_and_the_map_sheets_shader() -> void:
	var warmup: Node3D = auto_free(SCENE.instantiate())
	var used := []
	var shaders := []
	for pair: Array in _drawn(warmup):
		used.append(pair[1])
		if pair[1] is ShaderMaterial:
			shaders.append((pair[1] as ShaderMaterial).shader)
	assert_bool(used.has(load("res://entities/field_line/field_line_lamps.tres"))).is_true()
	assert_bool(shaders.has(load("res://assets/shaders/map_sheet.gdshader"))).is_true()
