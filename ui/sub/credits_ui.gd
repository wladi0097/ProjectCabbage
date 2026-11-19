extends Control

signal exited

# credits.txt is the single source: "#" lines open a section, blank lines split
# entries, the line before the first section is the game title. A "[logo] <path>" line is an image
# (the studio's logo), shown by both credit screens.
const CREDITS_PATH := "res://credits.txt"
const COLUMN_WIDTH := 430.0
const LOGO_MARK := "[logo]"
## The logo on this page: its height (px) and its colour (the logo is white: in ink on the paper).
const LOGO_HEIGHT := 96.0
const LOGO_INK := Color(0.13, 0.15, 0.14)

@onready var sections_box: Container = %Sections


static func parse(text: String) -> Dictionary:
	var title := ""
	var sections: Array[Dictionary] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			sections.append({"name": line.lstrip("#- ").strip_edges(), "entries": []})
		elif sections.is_empty():
			if title.is_empty():
				title = line
		elif line.is_empty():
			sections[-1].entries.append(PackedStringArray())
		else:
			var entries: Array = sections[-1].entries
			if entries.is_empty():
				entries.append(PackedStringArray())
			entries[-1].append(line)
	for section in sections:
		section.entries = section.entries.filter(func(entry): return !entry.is_empty())
	return {"title": title, "sections": sections}


## The image a "[logo] <path>" line shows, or "" for a text line.
static func image_of(line: String) -> String:
	return line.trim_prefix(LOGO_MARK).strip_edges() if line.begins_with(LOGO_MARK) else ""


static func is_fine_print(line: String) -> bool:
	return line.begins_with("Licensed") || line.begins_with("http")


func _ready() -> void:
	var credits := parse(FileAccess.get_file_as_string(CREDITS_PATH))
	%GameTitle.text = credits.title
	for i in credits.sections.size():
		sections_box.add_child(_section(i + 1, credits.sections[i]))


func _unhandled_input(event: InputEvent) -> void:
	if visible && event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


func enable() -> void:
	show()


func go_back() -> void:
	if !visible:
		return
	hide()
	exited.emit()


func _section(number: int, section: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = COLUMN_WIDTH
	box.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.theme_type_variation = &"FormLabel"
	heading.text = "§%02d  %s" % [number, section.name.to_upper()]
	box.add_child(heading)
	for entry in section.entries:
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		for line in entry:
			lines.add_child(_line(line))
		box.add_child(lines)
	return box


func _line(text: String) -> Control:
	if not image_of(text).is_empty():
		var logo := TextureRect.new()
		logo.texture = load(image_of(text))
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.custom_minimum_size = Vector2(LOGO_HEIGHT, LOGO_HEIGHT)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		logo.self_modulate = LOGO_INK
		return logo
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_fine_print(text):
		label.theme_type_variation = &"NoteLabel"
	else:
		label.add_theme_font_size_override("font_size", 19)
	return label
