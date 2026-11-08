extends GdUnitTestSuite
## GDMaim (the export obfuscator) renames identifiers but never strings. Every name the game also
## reads as a string must stay as written, or the release build breaks while the editor works:
## save fields and class names (`save.get(stat)`, the keys and script_class in the save file), dictionary keys (`node.mul`
## vs `.get("needs")`) and members named in strings (`tween_property(self, "_open")`).
## Those names live in GDMaim's ignore list; this suite keeps it complete.

const SOURCE_DIRS := ["res://entities", "res://globalScripts", "res://ui", "res://worlds",
		"res://ressources"]
const IGNORE_LIST := "res://addons/gdmaim/user/ignore_tokens.txt"
const GDMAIM_CONFIG := "res://.gdmaim/export.cfg"
## Members named in a string: tweens, method checks, string get/set/call.
const NAMED_IN_STRING := [
	"tween_property\\([^,]+,\\s*&?\"(\\w+)\"",
	"has_method\\(\\s*&?\"(\\w+)\"",
	"\\.(?:get|set|call|call_deferred|set_deferred)\\(\\s*&?\"(\\w+)\"",
]


func test_every_name_the_game_reads_as_a_string_is_kept_by_the_obfuscator() -> void:
	var locked := {}
	for line in FileAccess.get_file_as_string(IGNORE_LIST).split("\n"):
		if not line.strip_edges().is_empty() and not line.begins_with("#"):
			locked[line.strip_edges()] = true
	var missing: Array[String] = []
	for key in required_names():
		if not locked.has(key):
			missing.append(key)
	missing.sort()
	assert_array(missing).override_failure_message(
			"Add these to %s (one per line):\n%s" % [IGNORE_LIST, "\n".join(missing)]).is_empty()


## Each of these broke the release build once, while the editor and every test still worked.
func test_the_obfuscator_keeps_what_the_release_build_needs() -> void:
	var config := ConfigFile.new()
	assert_int(config.load(GDMAIM_CONFIG)).is_equal(OK)
	# Reads the ignore list above.
	assert_bool(config.get_value("exclude_files_category", "custom_tokens_enabled", false)).is_true()
	# Keeps @export: only exported fields are written, so without it the save file comes out empty.
	assert_bool(config.get_value("post_process", "strip_editor_annotations", true)).is_false()
	# Keeps static typing: stripping it writes code that no longer parses.
	assert_bool(config.get_value("post_process", "strip_static_typing", true)).is_false()
	# Text, not binary: binary scenes lose material overrides on nodes inside instanced models.
	assert_int(config.get_value("post_process", "export_mode", 2)).is_equal(0)


## Our patch in the addon: an editor started before a settings change must not export with the old ones.
func test_every_export_rereads_the_obfuscator_settings() -> void:
	var source := FileAccess.get_file_as_string("res://addons/gdmaim/export_plugin.gd")
	assert_str(source).contains("settings.initialize_settings(true)\n\tsettings.deserialize()")


func test_dictionary_keys_are_found_in_both_spellings_and_only_inside_braces() -> void:
	var keys := dictionary_keys('var x = 1\nconst A := {id = "a", "body": "x = 2", n = {flag = true}}\n'
			+ '# {commented = 1}\nfunc f(a, b = 2) -> void:\n\tpass\n')
	assert_array(keys).contains_exactly_in_any_order(["id", "body", "n", "flag"])


static func required_names() -> Array[String]:
	var names := {}
	for resource: Resource in [SaveGame.new(), SettingsResource.new()]:
		names[(resource.get_script() as Script).get_global_name()] = true  # The file header's script_class.
		for property in resource.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				names[property.name] = true
	var patterns: Array[RegEx] = []
	for pattern in NAMED_IN_STRING:
		patterns.append(RegEx.create_from_string(pattern))
	var scripts: Array[String] = []
	for dir in SOURCE_DIRS:
		collect_scripts(dir, scripts)
	for path in scripts:
		var source := FileAccess.get_file_as_string(path)
		for key in dictionary_keys(source):
			names[key] = true
		for regex in patterns:
			for found in regex.search_all(source):
				names[found.get_string(1)] = true
	var out: Array[String] = []
	out.assign(names.keys())
	return out


## Keys of dictionary literals, `{key = …}` and `{"key": …}`, skipping comments and strings.
static func dictionary_keys(source: String) -> Array[String]:
	var keys: Array[String] = []
	var depth := 0
	var i := 0
	while i < source.length():
		var c := source[i]
		if c == "#":
			i = source.find("\n", i)
			if i < 0:
				break
		elif c == "\"" or c == "'":
			var end := source.find(c, i + 1)
			while end > 0 and source[end - 1] == "\\":
				end = source.find(c, end + 1)
			var next := end + 1
			while next < source.length() and source[next] == " ":
				next += 1
			if depth > 0 and source[next] == ":" and source[next + 1] != "=":
				keys.append(source.substr(i + 1, end - i - 1))
			i = end
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
		elif depth > 0 and c == "=" and source[i + 1] != "=" and not source[i - 1] in ["=", ":", "<", ">", "!", "+", "-", "*", "/"]:
			var stop := i
			while source[stop - 1] == " ":
				stop -= 1
			var start := stop
			while start > 0 and (source[start - 1] == "_" or source[start - 1].is_valid_identifier() or source[start - 1].is_valid_int()):
				start -= 1
			if start < stop:
				keys.append(source.substr(start, stop - start))
		i += 1
	return keys


static func collect_scripts(dir: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			into.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		collect_scripts(dir.path_join(sub), into)
