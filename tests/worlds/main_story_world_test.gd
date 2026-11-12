extends GdUnitTestSuite
## The lighting rules of the one fixed scene: the room and the desk are marked Static for the LightmapGI
## (no baked data is kept), everything that moves, is skinned, is spawned or shows up
## later stays out of the bake, and every light stays real-time so moving things cast real shadows.

const WORLD := "res://worlds/MainStoryWorld.tscn"
## Scenes are instantiated but never added to the tree: no _ready runs, only the saved properties count.
const SCENE_DIRS: Array[String] = ["res://entities", "res://worlds"]
const BAKED: Array[String] = [
	"Room/room_wall", "Room/facade", "Room/street", "Room/window", "Room/blinds", "Room/crates",
	"Table/Table", "Table/cabbage_mat", "MiniDrop/TubeDesk/table_tube", "MiniDrop/TubeDesk/cabbage_mat_tube",
]
const WORLD_LIGHTS: Array[String] = ["DeskLamp", "WindowLight", "StreetLight"]


static func has_lightmap_uv(mesh: Mesh) -> bool:
	if mesh is PrimitiveMesh:
		return (mesh as PrimitiveMesh).add_uv2
	if not mesh is ArrayMesh or mesh.get_surface_count() == 0:
		return false
	for surface in mesh.get_surface_count():
		if ((mesh as ArrayMesh).surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV2) == 0:
			return false
	return true


static func scenes_in(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with("/"):
			found.append_array(scenes_in(dir.path_join(file.trim_suffix("/"))))
		elif file.ends_with(".tscn"):
			found.append(dir.path_join(file))
	return found


func _world() -> Node:
	return auto_free((load(WORLD) as PackedScene).instantiate())


func test_the_room_and_the_desk_are_marked_static_for_the_lightmap() -> void:
	var world := _world()
	for path in BAKED:
		var mesh := world.get_node(path) as MeshInstance3D
		assert_int(mesh.gi_mode).override_failure_message(path + " is not Static").is_equal(GeometryInstance3D.GI_MODE_STATIC)


func test_every_mesh_baked_into_a_lightmap_has_a_lightmap_uv() -> void:
	var scenes: Array[String] = []
	for dir in SCENE_DIRS:
		scenes.append_array(scenes_in(dir))
	assert_array(scenes).contains([WORLD, "res://entities/cabbage/cabbage.tscn"])
	for path in scenes:
		var scene: Node = auto_free((load(path) as PackedScene).instantiate())
		for node in scene.find_children("*", "MeshInstance3D", true, false) + [scene]:
			var mesh := node as MeshInstance3D
			if mesh == null or mesh.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
				continue
			assert_bool(has_lightmap_uv(mesh.mesh)).override_failure_message(
					"%s: %s is gi_mode Static without a lightmap UV2 (moving things: gi_mode Disabled)" % [path, scene.get_path_to(mesh)]).is_true()


func test_everything_that_moves_or_is_spawned_stays_out_of_the_bake() -> void:
	var world := _world()
	for path: String in ["Coins", "Associate", "TallyMachine", "CabbageFeeder/Model", "QaBay", "GoldenLamp", "ChuteLever"]:
		var node := world.get_node(path)
		for mesh: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false) + ([node] if node is GeometryInstance3D else []):
			if mesh is MeshInstance3D or mesh is MultiMeshInstance3D:
				assert_int(mesh.gi_mode).override_failure_message(str(world.get_path_to(mesh)) + " is baked").is_equal(GeometryInstance3D.GI_MODE_DISABLED)
	for path: String in ["res://entities/cabbage/cabbage.tscn", "res://entities/hand/hand_model.tscn"]:
		var scene: Node = auto_free((load(path) as PackedScene).instantiate())
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			assert_int(mesh.gi_mode).override_failure_message(path + " is baked").is_equal(GeometryInstance3D.GI_MODE_DISABLED)


func test_the_desk_lamp_stays_real_time_so_moving_things_cast_shadows() -> void:
	var world := _world()
	var lamp := world.get_node("DeskLamp") as Light3D
	assert_int(lamp.light_bake_mode).is_equal(Light3D.BAKE_DYNAMIC)
	assert_bool(lamp.shadow_enabled).is_true()


func test_only_the_three_room_lights_feed_the_bake() -> void:
	var world := _world()
	for light: Light3D in world.find_children("*", "Light3D", true, false):
		var path := str(world.get_path_to(light))
		var expected := Light3D.BAKE_DYNAMIC if WORLD_LIGHTS.has(path) else Light3D.BAKE_DISABLED
		assert_int(light.light_bake_mode).override_failure_message(path + " has the wrong bake mode").is_equal(expected)
