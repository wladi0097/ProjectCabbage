@tool
extends EditorScenePostImport
## Import script for every model that moves, is skinned, is spawned or appears only later in the
## game (`import_script/path` in its `.import`): its meshes stay out of the LightmapGI bake
## (gi_mode Disabled) and are lit in real time only. Models that never move and are on the desk
## from the first second (room, table) go without it and get `meshes/light_baking=2` (a lightmap UV2).


func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return scene
