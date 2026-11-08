extends Node

const SETTINGS_PATH := "user://settings.tres"
const SAVE_PATH := "user://savegame.tres"
const LOG_PATH := "user://playtest_log.csv"
## Seconds between playtest snapshots; the save is written with each one.
const LOG_EVERY := 30.0

## The game is about to quit: last chance to put anything into the save before it is written.
signal closing

var settings: SettingsResource
var save: SaveGame
var seconds_away := 0
## Returns the coins not banked yet (CoinPile.pending_value): the autosave writes them into the file
## without adding them to save.coins, so a crash loses nothing and nothing is counted twice.
var pending_coins := Callable()

var _played_since_msec := 0
var _log_timer := 0.0


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
	if not writes_allowed():
		return
	_log_timer += delta
	if _log_timer >= LOG_EVERY:
		_log_timer = 0.0
		log_event("snapshot")
		save.playtest_log = SaveGame.thin_log(save.playtest_log, played_now())
		var unbanked: int = pending_coins.call() if pending_coins.is_valid() else 0
		save.coins += unbanked
		write_save()
		save.coins -= unbanked


## Adds a playtest log line (see SaveGame.log_entry): a "card" or "node" purchase, a "session" start
## (id = seconds away) or a "snapshot".
func log_event(kind: String, id := "", price := 0, currency := "") -> void:
	save.playtest_log.append(save.log_entry(played_now(), kind, id, price, currency))


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


func write_save() -> void:
	var played := played_seconds(save.play_seconds, _played_since_msec, Time.get_ticks_msec())
	_played_since_msec += (played - save.play_seconds) * 1000
	save.play_seconds = played
	save.last_played = int(Time.get_unix_time_from_system())
	if not writes_allowed():
		return
	ResourceSaver.save(save, SAVE_PATH)
	var log_file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log_file != null:
		log_file.store_string(save.playtest_csv())


func reset_save() -> void:
	save = _new_save()
	seconds_away = 0
	_played_since_msec = Time.get_ticks_msec()
	write_save()
	get_tree().reload_current_scene()


## Swaps in `replacement` as the save (the debug start points, ui/sub/debug_starts), writes it over
## the real save and reloads the world.
func replace_save(replacement: SaveGame) -> void:
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
