extends GdUnitTestSuite

const SOURCE_DIRS := ["res://entities", "res://globalScripts", "res://ui", "res://worlds",
		"res://ressources"]


func test_every_script_compiles_so_a_type_error_in_an_untested_file_still_fails() -> void:
	var scripts: Array[String] = []
	for dir in SOURCE_DIRS:
		collect_scripts(dir, scripts)
	assert_array(scripts).is_not_empty()
	for path in scripts:
		var script := load(path) as GDScript
		assert_bool(script != null && script.can_instantiate()) \
				.override_failure_message("%s does not compile" % path).is_true()


func collect_scripts(dir: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			into.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		collect_scripts(dir.path_join(sub), into)
