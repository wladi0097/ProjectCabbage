class_name SettingsResource
extends Resource

signal map_specific_settings_changed

enum ScreenMode { EXCLUSIVE_FULLSCREEN, WINDOWED, BORDERLESS }
enum ShadowQuality { LOW, MEDIUM, HIGH }

@export var version := ""

# -- Video --
@export var ui_scale := 1.0:
	set(new_scale):
		ui_scale = new_scale
		Engine.get_main_loop().root.content_scale_factor = new_scale

@export var monitor_used := 0:
	set(monitor):
		monitor_used = monitor
		if !window_ready():
			return
		if monitor == 0 || monitor > DisplayServer.get_screen_count():
			monitor_used = 0
			DisplayServer.window_set_current_screen(DisplayServer.get_primary_screen())
		else:
			monitor_used = monitor
			DisplayServer.window_set_current_screen(monitor - 1)

@export var screen_mode := 0:
	set(mode):
		screen_mode = mode
		if !window_ready():
			return
		match mode:
			ScreenMode.EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			ScreenMode.WINDOWED:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			ScreenMode.BORDERLESS:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		display_size = display_size

@export var display_size := "1920 x 1080":
	set(size):
		display_size = size
		if !window_ready():
			return
		var sizes = size.split(" x ")
		var res = Vector2i(int(sizes[0]), int(sizes[1]))
		DisplayServer.window_set_size(res)
		if screen_mode == ScreenMode.WINDOWED:
			Engine.get_main_loop().root.move_to_center()

@export var fidelity_fx := 0:
	set(new_f):
		fidelity_fx = new_f
		map_specific_settings_changed.emit()

@export var use_fidelity_fx := true:
	set(use):
		use_fidelity_fx = use
		map_specific_settings_changed.emit()

@export var max_fps := "60":
	set(new_fps):
		max_fps = new_fps
		Engine.max_fps = engine_max_fps(new_fps)

@export var vsync := true:
	set(is_vsync):
		vsync = is_vsync
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if is_vsync else DisplayServer.VSYNC_DISABLED
		)

@export var shadow_quality := ShadowQuality.HIGH:
	set(new_quality):
		shadow_quality = new_quality
		map_specific_settings_changed.emit()

@export var brightness := 1.0:
	set(new_b):
		brightness = new_b
		map_specific_settings_changed.emit()

@export var allow_camera_shake := true

# -- Audio --
@export var master_volume := 1.0:
	set(volume):
		master_volume = volume
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Master'), linear_to_db(volume))

@export var master_muted := false:
	set(is_muted):
		master_muted = is_muted
		AudioServer.set_bus_mute(AudioServer.get_bus_index('Master'), is_muted)

@export var mute_on_focus_exit := false

@export var music_volume := 1.0:
	set(volume):
		music_volume = volume
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(volume))

@export var music_muted := false:
	set(is_muted):
		music_muted = is_muted
		AudioServer.set_bus_mute(AudioServer.get_bus_index('Music'), is_muted)

@export var sfx_volume := 1.0:
	set(volume):
		sfx_volume = volume
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'), linear_to_db(volume))

@export var sfx_muted := false:
	set(is_muted):
		sfx_muted = is_muted
		AudioServer.set_bus_mute(AudioServer.get_bus_index('SFX'), is_muted)

# -- Gameplay --
@export var language := "":
	get:
		return language if language != "" else OS.get_locale_language()
	set(lang):
		language = lang
		if lang != "":
			TranslationServer.set_locale(lang)


static func toggled_screen_mode(mode: int) -> int:
	return ScreenMode.EXCLUSIVE_FULLSCREEN if mode == ScreenMode.WINDOWED else ScreenMode.WINDOWED


static func engine_max_fps(text: String) -> int:
	if text == "∞":
		return 0
	return int(text) + 2


static func window_ready() -> bool:
	return Engine.get_main_loop().root.is_inside_tree()
