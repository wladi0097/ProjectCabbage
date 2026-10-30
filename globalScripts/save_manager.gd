extends Node

const SETTINGS_PATH := "user://settings.tres"
const SAVE_PATH := "user://savegame.tres"

var settings: SettingsResource
var save: SaveGame
var seconds_away := 0

var _played_since_msec := 0


func _init() -> void:
	load_settings()
	load_save()


func _ready() -> void:
	# The display setters need the window, which isn't up while _init loads the settings.
	apply_viewport_settings.call_deferred()


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
	if save == null:
		save = _new_save()
	seconds_away = away_seconds(save.last_played, int(Time.get_unix_time_from_system()))
	_played_since_msec = Time.get_ticks_msec()
	write_save()


func write_save() -> void:
	var played := played_seconds(save.play_seconds, _played_since_msec, Time.get_ticks_msec())
	_played_since_msec += (played - save.play_seconds) * 1000
	save.play_seconds = played
	save.last_played = int(Time.get_unix_time_from_system())
	ResourceSaver.save(save, SAVE_PATH)


func reset_save() -> void:
	save = _new_save()
	seconds_away = 0
	_played_since_msec = Time.get_ticks_msec()
	write_save()
	get_tree().reload_current_scene()


func _new_save() -> SaveGame:
	var created := SaveGame.new()
	created.version = get_current_version()
	created.created = int(Time.get_unix_time_from_system())
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
