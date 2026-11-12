extends GdUnitTestSuite
## Godot applies a node's properties in file order and drops a script variable written above the
## node's `script = ...` line (the script isn't attached yet), so it silently keeps its default.

const SOURCE_DIRS := ["res://entities", "res://ui", "res://worlds", "res://ressources"]


func test_no_scene_writes_a_script_value_above_the_nodes_script_line() -> void:
	var scenes: Array[String] = []
	for dir in SOURCE_DIRS:
		collect_scenes(dir, scenes)
	assert_array(scenes).is_not_empty()
	var bad: Array[String] = []
	for path in scenes:
		bad.append_array(misplaced_values(path))
	assert_array(bad).is_empty()


## "scene: node.property" for every script variable set before its node's script line.
func misplaced_values(path: String) -> Array[String]:
	var text := FileAccess.get_file_as_string(path)
	var scripts := {}
	var ext := RegEx.create_from_string(r'\[ext_resource type="Script"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"')
	for m in ext.search_all(text):
		scripts[m.get_string(2)] = m.get_string(1)
	var script_line := RegEx.create_from_string(r'^script = ExtResource\("([^"]+)"\)')
	var out: Array[String] = []
	for section in text.split("\n["):
		if not section.begins_with("node "):
			continue
		var lines := section.split("\n")
		var set_first: Array[String] = []
		for line in lines.slice(1):
			var m := script_line.search(line)
			if m == null:
				if " = " in line:
					set_first.append(line.get_slice(" = ", 0))
				continue
			if not scripts.has(m.get_string(1)):
				break
			var script := load(scripts[m.get_string(1)]) as Script
			var own := script.get_script_property_list().map(func(p: Dictionary) -> String: return p.name)
			for key in set_first:
				if key in own:
					out.append("%s: %s.%s" % [path, lines[0].get_slice('"', 1), key])
			break
	return out


func collect_scenes(dir: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			into.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		collect_scenes(dir.path_join(sub), into)
