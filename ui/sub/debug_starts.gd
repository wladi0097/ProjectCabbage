extends Control
## Debug builds only: ^ (the key left of 1) opens a list of prepared start points. Picking one
## overwrites the real save with that prepared save and reloads the world; NEW GAME starts from
## scratch. SAVE CURRENT files the running game as a new start point in START_DIR (works when the
## game runs from the project folder, i.e. from the editor). The prepared saves are left out of
## every export (export_presets.cfg).

const START_DIR := "res://ressources/save/debug_starts/"

@onready var _list: VBoxContainer = %List
@onready var _name: LineEdit = %Name


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	hide()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_toggle(key):
		return
	if visible:
		hide()
	else:
		_fill()
		show()
	get_viewport().set_input_as_handled()


## Whether `key` is the ^ key: by position (left of 1, any layout) or by the character.
static func is_toggle(key: InputEventKey) -> bool:
	return key.physical_keycode == KEY_QUOTELEFT or key.keycode == KEY_ASCIICIRCUM


## The prepared saves in `dir`, sorted by file name (a number prefix sets the order).
static func entries(dir: String = START_DIR) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			out.append(dir.path_join(file))
	out.sort()
	return out


## "20_farm_just_bought.tres" → "20  Farm just bought".
static func label_of(path: String) -> String:
	var stem := path.get_file().get_basename()
	var cut := stem.find("_")
	if cut > 0 and stem.left(cut).is_valid_int():
		return "%s  %s" % [stem.left(cut), stem.substr(cut + 1).replace("_", " ").capitalize()]
	return stem.replace("_", " ").capitalize()


## A typed name as a file stem: lower case, spaces to _, nothing but letters, digits and _.
static func stem_for(text: String) -> String:
	var out := ""
	for c in text.strip_edges().to_lower().replace(" ", "_"):
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out += c
	return out


## A copy of `save` fit to be a start point: no playtest log (it only bloats the file).
static func prepared(save: SaveGame) -> SaveGame:
	var copy := save.duplicate(true) as SaveGame
	copy.playtest_log = []
	return copy


func _fill() -> void:
	for child in _list.get_children():
		child.queue_free()
	for path in entries():
		var button := Button.new()
		button.text = label_of(path)
		button.theme_type_variation = &"NavButton"
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_start.bind(path))
		_list.add_child(button)


func _start(path: String) -> void:
	var save := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	if save == null:
		push_error("debug start point %s did not load" % path)
		return
	SaveManager.replace_save(prepared(save))


func _on_new_game_pressed() -> void:
	SaveManager.reset_save()


func _on_save_current_pressed() -> void:
	var stem := stem_for(_name.text)
	if stem.is_empty():
		_name.placeholder_text = "type a name first"
		return
	var path := START_DIR.path_join(stem + ".tres")
	var err := ResourceSaver.save(prepared(SaveManager.save), path)
	print("debug: start point %s saved (%s)" % [path, error_string(err)])
	_name.text = ""
	_fill()


func _on_close_pressed() -> void:
	hide()
