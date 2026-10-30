extends Control

signal exited

const LANGUAGES := {
	"en": "English",
	"de": "Deutsch",
	"ru": "Русский",
	"zh": "简体中文",
	"es": "Español",
	"ja": "日本語",
	"pt": "Português",
	"pl": "Polski",
	"fr": "Français",
	"ko": "한국어",
	"tr": "Türkçe",
	"it": "Italiano",
	"cs": "Čeština",
	"uk": "Українська",
}

var _initializing := true
var _ui_scale_dragged := false

@onready var settings: SettingsResource = SaveManager.settings
@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var tab_bar: TabBar = %TabBar
@onready var pages: Control = %Pages


static func language_index(code: String) -> int:
	return maxi(LANGUAGES.keys().find(code), 0)


static func item_index(items: PackedStringArray, text: String) -> int:
	return maxi(items.find(text), 0)


func _ready() -> void:
	_connect_ui_sounds(pages)
	_list_monitors()
	for language_name in LANGUAGES.values():
		%Language.add_item(language_name)

	%Language.selected = language_index(settings.language)

	%MuteOnFocusExit.button_pressed = settings.mute_on_focus_exit
	%MuteMaster.button_pressed = settings.master_muted
	%MasterVolume.value = settings.master_volume
	%MuteMusic.button_pressed = settings.music_muted
	%MusicVolume.value = settings.music_volume
	%MuteSfx.button_pressed = settings.sfx_muted
	%SfxVolume.value = settings.sfx_volume

	%Monitor.selected = settings.monitor_used
	%Resolution.selected = item_index(_items(%Resolution), settings.display_size)
	%Vsync.button_pressed = settings.vsync
	%UiScale.value = settings.ui_scale
	%ScalingQuality.selected = settings.fidelity_fx
	%ShadowQuality.selected = settings.shadow_quality
	%MaxFps.selected = item_index(_items(%MaxFps), settings.max_fps)
	%UseFidelityFx.button_pressed = settings.use_fidelity_fx
	%AllowCameraShake.button_pressed = settings.allow_camera_shake
	%Brightness.value = settings.brightness

	_initializing = false


func _unhandled_input(event: InputEvent) -> void:
	if visible && event.is_action_pressed("ui_cancel"):
		go_back()
		accept_event()


func enable() -> void:
	%ScreenMode.selected = settings.screen_mode
	%ResolutionRow.visible = settings.screen_mode == SettingsResource.ScreenMode.WINDOWED
	_on_tab_bar_tab_changed(tab_bar.current_tab)
	show()


func disable() -> void:
	%ResetConfirm.hide()
	hide()
	exited.emit()


func go_back() -> void:
	if !visible:
		return
	disable()
	SaveManager.write_settings()


func _items(option: OptionButton) -> PackedStringArray:
	var items := PackedStringArray()
	for i in option.item_count:
		items.append(option.get_item_text(i))
	return items


func _connect_ui_sounds(node: Node) -> void:
	if node is BaseButton || node is Slider:
		node.mouse_entered.connect(_on_ui_hovered)
	if node is BaseButton:
		node.pressed.connect(_on_ui_clicked)
	for child in node.get_children():
		_connect_ui_sounds(child)


func _list_monitors() -> void:
	for i in DisplayServer.get_screen_count():
		%Monitor.add_item(tr("settings.screen") + " " + str(i), i + 1)


func _play_after_setup(player: AudioStreamPlayer) -> void:
	if !_initializing:
		player.play()


func _on_ui_hovered() -> void:
	_play_after_setup(hover_sound)


func _on_ui_clicked() -> void:
	_play_after_setup(click_sound)


func _on_tab_bar_tab_hovered(_tab: int) -> void:
	_on_ui_hovered()


func _on_tab_bar_tab_clicked(_tab: int) -> void:
	_on_ui_clicked()


func _on_tab_bar_tab_changed(tab: int) -> void:
	for page in pages.get_children():
		page.visible = page.get_index() == tab


func _on_back_button_clicked() -> void:
	go_back()


func _on_reset_confirmed() -> void:
	SaveManager.reset_save()


func _on_language_item_selected(index: int) -> void:
	settings.language = LANGUAGES.keys()[index]


func _on_mute_on_focus_exit_toggled(toggled_on: bool) -> void:
	settings.mute_on_focus_exit = toggled_on


func _on_mute_master_toggled(toggled_on: bool) -> void:
	settings.master_muted = toggled_on
	_play_after_setup(%MasterAudioTest)


func _on_master_volume_value_changed(value: float) -> void:
	settings.master_volume = value
	_play_after_setup(%MasterAudioTest)


func _on_mute_music_toggled(toggled_on: bool) -> void:
	settings.music_muted = toggled_on
	_play_after_setup(%MusicAudioTest)


func _on_music_volume_value_changed(value: float) -> void:
	settings.music_volume = value
	_play_after_setup(%MusicAudioTest)


func _on_mute_sfx_toggled(toggled_on: bool) -> void:
	settings.sfx_muted = toggled_on
	_play_after_setup(%SfxAudioTest)


func _on_sfx_volume_value_changed(value: float) -> void:
	settings.sfx_volume = value
	_play_after_setup(%SfxAudioTest)


func _on_monitor_item_selected(index: int) -> void:
	settings.monitor_used = index


func _on_screen_mode_item_selected(index: int) -> void:
	settings.screen_mode = index
	%ResolutionRow.visible = index == SettingsResource.ScreenMode.WINDOWED


func _on_resolution_item_selected(index: int) -> void:
	settings.display_size = %Resolution.get_item_text(index)


func _on_vsync_toggled(toggled_on: bool) -> void:
	settings.vsync = toggled_on


func _on_ui_scale_drag_started() -> void:
	_ui_scale_dragged = true


func _on_ui_scale_drag_ended(value_changed: bool) -> void:
	if value_changed && _ui_scale_dragged:
		_ui_scale_dragged = false
		settings.ui_scale = %UiScale.value


func _on_ui_scale_value_changed(value: float) -> void:
	if !_ui_scale_dragged:
		settings.ui_scale = value


func _on_scaling_quality_item_selected(index: int) -> void:
	settings.fidelity_fx = index


func _on_shadow_quality_item_selected(index: int) -> void:
	settings.shadow_quality = index as SettingsResource.ShadowQuality


func _on_max_fps_item_selected(index: int) -> void:
	settings.max_fps = %MaxFps.get_item_text(index)


func _on_use_fidelity_fx_toggled(toggled_on: bool) -> void:
	settings.use_fidelity_fx = toggled_on


func _on_allow_camera_shake_toggled(toggled_on: bool) -> void:
	settings.allow_camera_shake = toggled_on


func _on_brightness_value_changed(value: float) -> void:
	settings.brightness = value
