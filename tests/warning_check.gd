extends SceneTree

const SKIPPED: Array[String] = ["res://addons", "res://.godot", "res://.git", "res://reports",
		"res://dist", "res://full", "res://tools", "res://research", "res://.claude"]


static func project_scripts(dir: String, found: PackedStringArray) -> PackedStringArray:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		var path := dir.path_join(sub)
		if !SKIPPED.has(path):
			project_scripts(path, found)
	return found


func _initialize() -> void:
	var scripts := project_scripts("res://", PackedStringArray())
	for path in scripts:
		if ResourceLoader.has_cached(path):
			continue
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		script.resource_path = path
		script.reload()
	print("Warning check reloaded %d scripts" % scripts.size())
	quit()
