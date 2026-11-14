extends Node

const SETTINGS_PATH := "user://settings.tres"
const SAVE_PATH := "user://savegame.tres"
## The playtest log (SaveGame.LOG_COLUMNS): appended one line per entry, never rewritten. A new game
## (reset, debug start) moves it to LOG_PREV_PATH and starts a fresh one.
const LOG_PATH := "user://playtest_log.csv"
const LOG_PREV_PATH := "user://playtest_log_prev.csv"
## Seconds between autosaves.
const SAVE_EVERY := 30.0
## Play seconds between the log's "minute" rows.
const LOG_MINUTE := 60.0
## What a playtest report zips from the user folder (file_report).
const REPORT_FILES := ["savegame.tres", "playtest_log.csv", "playtest_log_prev.csv"]
const Demo := preload("res://globalScripts/demo.gd")

## The game is about to quit: last chance to put anything into the save before it is written.
signal closing

var settings: SettingsResource
var save: SaveGame
var seconds_away := 0
## Returns the coins not banked yet (CoinPile.pending_value): the autosave writes them into the file
## without adding them to save.coins, so a crash loses nothing and nothing is counted twice.
var pending_coins := Callable()
## The same for the Findings not filed yet (QaBay.unfiled: benches, slips, those held back).
var pending_findings := Callable()

var _played_since_msec := 0
var _save_timer := 0.0
## LOG_PATH kept open for appending (opened on the first entry, closed before a new game moves it).
var _log_file: FileAccess
var _minute_timer := 0.0


func _init() -> void:
	if writes_allowed():
		adopt_old_files(OS.get_data_dir().path_join("Godot/app_userdata/ProjectCabbage"), OS.get_user_data_dir())
	load_settings()
	load_save()


func _ready() -> void:
	# The display setters need the window, which isn't up while _init loads the settings.
	apply_viewport_settings.call_deferred()
	log_event("session", str(seconds_away))


func _process(delta: float) -> void:
	_minute_timer += delta
	if _minute_timer >= LOG_MINUTE:
		_minute_timer -= LOG_MINUTE
		log_event("minute")
	if not writes_allowed():
		return
	_save_timer += delta
	if _save_timer >= SAVE_EVERY:
		_save_timer = 0.0
		autosave()


## Writes the save with the coins not banked and the Findings not filed yet in it (pending_coins,
## pending_findings: what fits under the limits), save.coins and save.findings left as they are.
func autosave() -> void:
	var unbanked := save.earn(&"coins", pending_coins.call() if pending_coins.is_valid() else 0)
	var unfiled := save.earn(&"findings", pending_findings.call() if pending_findings.is_valid() else 0)
	write_save()
	save.coins -= unbanked
	save.findings -= unfiled


## Adds a playtest log line (see SaveGame.LOG_COLUMNS): a "card" or "node" purchase, a "session" start
## (id = seconds away), a "minute"... Kept in memory (the ledger reads it) and appended to LOG_PATH.
func log_event(kind: String, id := "", price := 0, currency := "") -> void:
	var entry := save.log_entry(played_now(), kind, id, price, currency)
	save.playtest_log.append(entry)
	if not writes_allowed():
		return
	if _log_file == null:
		_log_file = SaveGame.open_log(LOG_PATH)
	if _log_file != null:
		_log_file.store_line(SaveGame.log_line(entry))
		_log_file.flush()


## The log of the save just loaded, from `path`: an old save's in-save log is written to the file
## once (old builds rewrote that file from it anyway), else the file is read back. True when the
## save held a log (write it again so it drops it).
static func adopt_log(loaded: SaveGame, path: String, writable: bool) -> bool:
	if not loaded.playtest_log.is_empty():
		if writable:
			SaveGame.write_log(path, loaded.playtest_log)
		return true
	var text := FileAccess.get_file_as_string(path)
	loaded.playtest_log = SaveGame.parse_log(text)
	if writable and SaveGame.needs_header(text):
		var file := FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
			file.store_line(SaveGame.log_header())
	return false


## A new game's log: the old one becomes `prev` (replacing the one before), the next entry starts `path`.
static func rotate_log(path: String, prev: String) -> void:
	if not FileAccess.file_exists(path):
		return
	if FileAccess.file_exists(prev):
		DirAccess.remove_absolute(prev)
	DirAccess.rename_absolute(path, prev)


## FILE A PLAYTEST REPORT (settings): the save is written now, then one zip goes to the desktop
## (the user folder if there is none) with it, the playtest logs (REPORT_FILES) and info.txt. No
## names or paths of the player's go in. Returns the zip's path, "" if it couldn't be written.
func file_report() -> String:
	autosave()
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		dir = OS.get_user_data_dir()
	var stamp := Time.get_datetime_string_from_system(false, true).replace(" ", "_").replace(":", "-")
	var zip := dir.path_join("ProjectCabbage_playtest_%s.zip" % stamp)
	var info := "\n".join(["game: Project Cabbage %s" % get_current_version(),
			"build: %s" % ("demo" if Demo.active() else "full"), "os: %s" % OS.get_name(),
			"play_seconds: %d" % played_now(), "language: %s" % TranslationServer.get_locale(),
			"filed: %s" % stamp]) + "\n"
	return zip if pack_report(zip, "user://", REPORT_FILES, info) == OK else ""


## Zips the files `names` found in `from_dir` (missing ones skipped) and `info` as info.txt into `zip_path`.
static func pack_report(zip_path: String, from_dir: String, names: Array, info: String) -> Error:
	var zip := ZIPPacker.new()
	var opened := zip.open(zip_path)
	if opened != OK:
		return opened
	for file: String in names:
		var path := from_dir.path_join(file)
		if FileAccess.file_exists(path):
			zip.start_file(file)
			zip.write_file(FileAccess.get_file_as_bytes(path))
			zip.close_file()
	zip.start_file("info.txt")
	zip.write_file(info.to_utf8_buffer())
	zip.close_file()
	return zip.close()


## Builds before the custom user folder kept the save and settings under Godot's own folder
## (`old_dir`): each one missing in `new_dir` is copied over once, so nobody loses their progress.
static func adopt_old_files(old_dir: String, new_dir: String) -> void:
	for file in ["savegame.tres", "settings.tres"]:
		if FileAccess.file_exists(old_dir.path_join(file)) and not FileAccess.file_exists(new_dir.path_join(file)):
			DirAccess.copy_absolute(old_dir.path_join(file), new_dir.path_join(file))


## Test scenes and -s probe scripts never write the player's save, on any path (autosave, quit, reset).
static func writes_allowed() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("-s") and not OS.get_cmdline_args().has("--script")


## Play time so far in seconds, this session included.
func played_now() -> int:
	return played_seconds(save.play_seconds, _played_since_msec, Time.get_ticks_msec())


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		settings = SafeResourceLoader.load(SETTINGS_PATH, "",
				ResourceLoader.CACHE_MODE_IGNORE) as SettingsResource
	if settings == null:
		settings = SettingsResource.new()
		settings.version = get_current_version()
		write_settings()


func write_settings() -> void:
	ResourceSaver.save(settings, SETTINGS_PATH)


func load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		save = SafeResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	seconds_away = away_seconds(save.last_played, int(Time.get_unix_time_from_system())) if save != null else 0
	_played_since_msec = Time.get_ticks_msec()
	if save == null:
		save = _new_save()
		write_save()
	elif adopt_log(save, LOG_PATH, writes_allowed()):
		write_save()


func write_save() -> void:
	var played := played_seconds(save.play_seconds, _played_since_msec, Time.get_ticks_msec())
	_played_since_msec += (played - save.play_seconds) * 1000
	save.play_seconds = played
	save.last_played = int(Time.get_unix_time_from_system())
	if not writes_allowed():
		return
	ResourceSaver.save(save, SAVE_PATH)


func reset_save() -> void:
	_log_file = null  # Closed, so it can be moved.
	if writes_allowed():
		rotate_log(LOG_PATH, LOG_PREV_PATH)
	save = _new_save()
	seconds_away = 0
	_played_since_msec = Time.get_ticks_msec()
	write_save()
	get_tree().reload_current_scene()


## Swaps in `replacement` as the save (the debug start points, ui/sub/debug_starts), writes it over
## the real save and reloads the world.
## The player's log is rotated (LOG_PREV_PATH) like on a reset.
func replace_save(replacement: SaveGame) -> void:
	_log_file = null  # Closed, so it can be moved.
	if writes_allowed():
		rotate_log(LOG_PATH, LOG_PREV_PATH)
	save = replacement
	seconds_away = 0
	_played_since_msec = Time.get_ticks_msec()
	write_save()
	get_tree().reload_current_scene()


func _new_save() -> SaveGame:
	var created := SaveGame.new()
	created.version = get_current_version()
	created.created = int(Time.get_unix_time_from_system())
	created.migration = SaveGame.MIGRATION
	return created


static func played_seconds(play_seconds: int, since_msec: int, now_msec: int) -> int:
	return play_seconds + floori((now_msec - since_msec) / 1000.0)


static func away_seconds(last_played: int, now: int) -> int:
	return maxi(now - last_played, 0) if last_played > 0 else 0


static func master_bus_muted(focused: bool, mute_on_focus_exit: bool,
		master_muted: bool) -> bool:
	return master_muted || (!focused && mute_on_focus_exit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		closing.emit()
		write_save()
		write_settings()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN || what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var focused := what == NOTIFICATION_APPLICATION_FOCUS_IN
		var muted := master_bus_muted(focused, settings.mute_on_focus_exit, settings.master_muted)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


static func get_current_version() -> String:
	return str(ProjectSettings.get_setting_with_override("application/config/version"))


func apply_viewport_settings() -> void:
	settings.ui_scale = settings.ui_scale
	settings.monitor_used = settings.monitor_used
	settings.screen_mode = settings.screen_mode
	settings.display_size = settings.display_size
	settings.vsync = settings.vsync
	settings.max_fps = settings.max_fps
