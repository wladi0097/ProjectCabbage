class_name EndCard
extends CanvasLayer
## The game's last screen (chapter 5): a cut to black, one soft cabbage thud, the logo fades in and
## holds HOLD s to sink in, then it scrolls slowly up and the credits (credits.txt, as in the credits
## menu) follow it, white on black, until the closing line sits in the middle of the screen. It holds
## there END_HOLD s, then `finished`. Holding any key or mouse button rolls the credits FAST × faster.
## A soft swell comes with the logo; one of the radio's songs, picked at random, plays under the
## credits (Music bus) and fades out over the closing hold. While the credits roll fast, the song (and
## the `pitched` players: the ending's hum) speed up with them, eased over RATE_EASE s.

signal finished
## The logo's hold is over and the credits start to roll.
signal scroll_started

const Credits := preload("res://ui/sub/credits_ui.gd")
## Sections whose names (QA's people, the music's titles) lie in rows of up to COLUMNS.
const COLUMN_SECTIONS: PackedStringArray = ["QA", "Music"]
const COLUMNS := 3
const COLUMN_GAP := 48
## Seconds the audio takes to follow the scroll speed up or back down (no click).
const RATE_EASE := 0.15
## The song's level under the credits, and what it fades to over the closing hold (dB).
const SONG_DB := -6.0
const SONG_OUT_DB := -60.0
## Seconds: black before the thud, the thud to the logo, the logo's fade-in, its hold, the closing
## line's hold; the scroll's speed (px/s) and how much faster it rolls while something is held.
const BLACK := 0.8
const THUD_TO_LOGO := 0.9
const FADE := 1.5
const HOLD := 7.5
const END_HOLD := 4.0
const SPEED := 32.0
const FAST := 8.0

## Whether the credits are rolling now (not during the logo's hold, nor once the closing line is centred).
var scrolling := false
## Other players whose pitch follows the scroll speed (the ending hands in its hum).
var pitched: Array[AudioStreamPlayer] = []
## The audio's speed now: 1, up to FAST while the credits roll fast.
var rate := 1.0
var _bases := {}

@onready var _song: AudioStreamPlayer = $Song

@onready var _roll: Control = $Roll
@onready var _logo: TextureRect = $Roll/Logo
@onready var _credits: VBoxContainer = $Roll/Credits
@onready var _closing_gap: Control = $Roll/Credits/ClosingGap
@onready var _closing: Label = $Roll/Credits/Closing


func _ready() -> void:
	var credits := Credits.parse(FileAccess.get_file_as_string(Credits.CREDITS_PATH))
	for section: Dictionary in credits.sections:
		var heading := Label.new()
		heading.theme_type_variation = &"CreditHeading"
		heading.text = section.name.to_upper()
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_credits.add_child(heading)
		for entry: PackedStringArray in section.entries:
			var grid: GridContainer = null
			for line in entry:
				var label := Label.new()
				label.text = line
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				if Credits.is_fine_print(line):
					label.theme_type_variation = &"CreditFine"
				if not in_columns(section.name, line):
					grid = null
					_credits.add_child(label)
					continue
				if grid == null:
					grid = GridContainer.new()
					grid.columns = COLUMNS
					grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					grid.add_theme_constant_override(&"h_separation", COLUMN_GAP)
					_credits.add_child(grid)
				grid.add_child(label)
		_credits.add_child(Control.new())  # A gap between sections (the VBox spacing doubles).
	_credits.move_child(_closing_gap, -1)
	_credits.move_child(_closing, -1)


func _process(delta: float) -> void:
	rate = rate_toward(rate, scrolling and Input.is_anything_pressed(), delta)
	for player: AudioStreamPlayer in [_song] + pitched:
		if is_instance_valid(player):
			if not _bases.has(player):
				_bases[player] = player.pitch_scale
			player.pitch_scale = _bases[player] * rate
	if not scrolling:
		return
	var stop := closing_stop()
	_roll.position.y = maxf(_roll.position.y - speed() * delta, stop)
	if _roll.position.y <= stop:
		scrolling = false


## Whether credit `line` of section `section` lies in the rows of columns: QA's names, the music's
## quoted titles; never a licence line or an attribution.
static func in_columns(section: String, line: String) -> bool:
	if not COLUMN_SECTIONS.has(section) or Credits.is_fine_print(line):
		return false
	return section == "QA" or (line.begins_with("\"") and line.ends_with("\""))


## The audio's speed `delta` s on from `rate`, heading for FAST while `fast`, else 1, over RATE_EASE s.
static func rate_toward(from: float, fast: bool, delta: float) -> float:
	return move_toward(from, FAST if fast else 1.0, (FAST - 1.0) / RATE_EASE * delta)


## The radio's songs (Radio.MUSIC_DIR), and the one a `roll` (0..1) picks for the credits ("" with none).
static func songs() -> PackedStringArray:
	var out := PackedStringArray()
	for file in Radio.track_paths(ResourceLoader.list_directory(Radio.MUSIC_DIR)):
		out.append(Radio.MUSIC_DIR + file)
	return out


static func pick_song(list: PackedStringArray, roll: float) -> String:
	return "" if list.is_empty() else list[mini(floori(roll * list.size()), list.size() - 1)]


## When each beat starts, in seconds from play(): the thud, the logo's fade-in, the logo at full,
## and the scroll.
static func timeline() -> Dictionary:
	var logo_in := BLACK + THUD_TO_LOGO
	return {thud = BLACK, logo_in = logo_in, logo_full = logo_in + FADE, scroll = logo_in + FADE + HOLD}


## How fast the credits roll now (px/s): 0 when they are not rolling, FAST × while any key or
## mouse button is held.
func speed() -> float:
	if not scrolling:
		return 0.0
	return SPEED * (FAST if Input.is_anything_pressed() else 1.0)


## The roll's y at which the closing line's middle is on the screen's middle.
func closing_stop() -> float:
	var closing_mid := _credits.position.y + _closing.position.y + _closing.size.y * 0.5
	return get_viewport().get_visible_rect().size.y * 0.5 - closing_mid


## Runs the whole end card; returns (and emits `finished`) once the closing line has held.
func play() -> void:
	visible = true
	var view := get_viewport().get_visible_rect().size
	_roll.size.x = view.x
	_logo.modulate.a = 0.0
	# The logo centred on screen to start with.
	_roll.position = Vector2(0, (view.y - _logo.custom_minimum_size.y) * 0.5)
	var at := timeline()
	await get_tree().create_timer(at.thud).timeout
	$Thud.play()
	await get_tree().create_timer(at.logo_in - at.thud).timeout
	create_tween().tween_property(_logo, "modulate:a", 1.0, FADE)
	$LogoSwell.play()
	await get_tree().create_timer(at.scroll - at.logo_in).timeout
	scrolling = true
	scroll_started.emit()
	var song := pick_song(songs(), randf())
	if not song.is_empty():
		_song.stream = load(song)
		_song.volume_db = SONG_DB
		_song.play()
	while scrolling:
		await get_tree().process_frame
	create_tween().tween_property(_song, "volume_db", SONG_OUT_DB, END_HOLD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(END_HOLD).timeout
	finished.emit()
