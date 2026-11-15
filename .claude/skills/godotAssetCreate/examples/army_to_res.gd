extends SceneTree
# Args after --: <glb path> <res dir> <prefix>. Saves every mesh as <res dir>/<prefix>_<node>.res
# with the shared materials (by Blender material name) baked into its surfaces.
const MATS := {
	"army_plastic": "res://assets/meshes/Army/army_plastic.tres",
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(args[0], state) != OK:
		push_error("cannot read " + args[0]); quit(1); return
	var scene := doc.generate_scene(state)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var src: ArrayMesh = mi.mesh
		var mesh := ArrayMesh.new()
		for k in src.get_surface_count():
			var mat_name := src.surface_get_material(k).resource_name
			mesh.add_surface_from_arrays(src.surface_get_primitive_type(k), src.surface_get_arrays(k))
			mesh.surface_set_material(k, load(MATS[mat_name]))
		var path := "%s/%s_%s.res" % [args[1], args[2], mi.name.to_snake_case()]
		print(path, " surfaces ", mesh.get_surface_count(), " at ", mi.position, " aabb ", mesh.get_aabb())
		ResourceSaver.save(mesh, path)
	scene.free()
	quit()
