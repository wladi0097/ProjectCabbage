class_name Radio
extends Node3D
## The desk radio: a Bakelite set left of the inbox tray. It drops onto the desk once desk card
## `radio` is stamped and plays every song in MUSIC_DIR in name order, round and round, through the
## Radio bus (old-set filter, switchable in the settings). The top key plays or stops it (fading,
## save.radio_on), the bottom key skips to the next song (save.songs_skipped). A song crossfades
## into the next one at its end and on a skip. The amber window shows the track number, dim while
## stopped. Bought and stopped, the silence is counted (save.radio_silent). While a war is on it fades
## out and pauses (the fight has its own songs) and picks the song up again afterwards, only if it was on.

const War := preload("res://entities/map_table/war_sheet.gd")

const MUSIC_DIR := "res://assets/audio/music/radio/"
const EXTENSIONS: PackedStringArray = ["ogg", "mp3", "wav"]
## Seconds for one song to hand over to the next, and for play/stop to fade in or out.
const CROSSFADE := 1.8
const FADE := 0.8
## Below this linear gain a player counts as silent.
const QUIET := 0.0001
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
## How far a key sinks when pressed (bone space, -Y is down).
const KEY_DEPTH := 0.024
const AMBER := Color(1, 0.62, 0.18, 1)
const AMBER_OFF := Color(0.5, 0.3, 0.09, 1)

var _tracks: Array[AudioStream] = []
## The player the current song is on; the other one fades out the song before.
var _cur := 0
## Crossfade progress, 0 (just started) to 1 (the old song is gone).
var _mix := 1.0
## Play/stop fade, 0 silent to 1 full.
var _level := 0.0

@onready var _players: Array[AudioStreamPlayer] = [$SongA, $SongB]
@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _window: Label3D = $Track
@onready var _rest := position


func _ready() -> void:
	for path in track_paths(ResourceLoader.list_directory(MUSIC_DIR)):
		_tracks.append(load(MUSIC_DIR + path))
	$PlayKey/Interactable.grabbed.connect(_toggle)
	$SkipKey/Interactable.grabbed.connect(_skip)
	for key in ["PlayKey", "SkipKey"]:
		get_node(key + "/Interactable").grabbed.connect(_push.bind(key, true))
		get_node(key + "/Interactable").released.connect(_push.bind(key, false))
	var save := SaveManager.save
	if _tracks.size() > 0:
		save.radio_track = posmod(save.radio_track, _tracks.size())
	_show_track()
	if bought(save):
		_start()
	else:
		visible = false
		_enable_keys(false)
		position = _rest + Vector3.UP * 10.0


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not visible:
		if bought(save):
			_drop()
		return
	save.radio_silent = silent_after(save.radio_silent, delta, bought(save), save.radio_on)
	var on := playing(save.radio_on, War.at_war)
	_level = move_toward(_level, 1.0 if on else 0.0, delta / FADE)
	_mix = move_toward(_mix, 1.0, delta / CROSSFADE)
	# Faded out: pause, so play picks the song up where it stopped.
	for player in _players:
		player.stream_paused = _level <= 0.0
	var song := _players[_cur]
	var old := _players[1 - _cur]
	if _mix >= 1.0 and old.playing:
		old.stop()
	if on and song.stream != null and _mix >= 1.0 \
			and (not song.playing or song.get_playback_position() >= song.stream.get_length() - CROSSFADE):
		_change(next_track(save.radio_track, _tracks.size()))
	song.volume_db = linear_to_db(maxf(fade_gain(_mix) * _level, QUIET))
	old.volume_db = linear_to_db(maxf(fade_gain(1.0 - _mix) * _level, QUIET))


## Whether the radio is heard: switched on and no war on (a war only pauses it, never switches it on).
static func playing(on: bool, at_war: bool) -> bool:
	return on and not at_war


static func bought(save: SaveGame) -> bool:
	return save.stamped.has("radio")


## The playable audio files in a directory listing, in name order.
static func track_paths(files: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for file in files:
		if EXTENSIONS.has(file.get_extension().to_lower()):
			out.append(file)
	out.sort()
	return out


## The track after `index` of `count`, back to the first after the last (0 with none).
static func next_track(index: int, count: int) -> int:
	return 0 if count <= 0 else (index + 1) % count


## Equal-power crossfade: the incoming song's gain at progress `t` (0..1); the outgoing one
## plays at fade_gain(1 - t), so the sum of powers stays 1 and the handover has no dip.
static func fade_gain(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI / 2.0)


## save.radio_silent after `delta` seconds: it only counts while the radio is bought and stopped.
static func silent_after(silent: float, delta: float, is_bought: bool, on: bool) -> float:
	return silent + delta if is_bought and not on else silent


## The song on the current player (at the start), with no handover.
func _start() -> void:
	var song := _players[_cur]
	if _tracks.is_empty():
		return
	song.stream = _tracks[SaveManager.save.radio_track]
	song.play()


## Song `index` starts on the free player and the current one fades out under it.
func _change(index: int) -> void:
	SaveManager.save.radio_track = index
	_show_track()
	if _tracks.is_empty():
		return
	_cur = 1 - _cur
	_mix = 0.0
	var song := _players[_cur]
	song.stream = _tracks[index]
	song.volume_db = linear_to_db(QUIET)
	song.play()


func _toggle() -> void:
	var save := SaveManager.save
	save.radio_on = not save.radio_on
	$Click.cue($PlayKey.global_position)
	_show_track()


func _skip() -> void:
	SaveManager.save.songs_skipped += 1
	$Click.cue($SkipKey.global_position)
	_change(next_track(SaveManager.save.radio_track, _tracks.size()))


## The key's cap sinks while held and springs back on release.
func _push(key: String, down: bool) -> void:
	var bone := _skeleton.find_bone(key)
	var rest := _skeleton.get_bone_rest(bone).origin
	create_tween().tween_method(func(at: Vector3) -> void: _skeleton.set_bone_pose_position(bone, at),
			_skeleton.get_bone_pose_position(bone), rest + (Vector3.DOWN * KEY_DEPTH if down else Vector3.ZERO), 0.05)


func _show_track() -> void:
	_window.text = "%02d" % (SaveManager.save.radio_track + 1)
	_window.modulate = AMBER if SaveManager.save.radio_on else AMBER_OFF


func _enable_keys(on: bool) -> void:
	$PlayKey/Interactable.enabled = on
	$SkipKey/Interactable.enabled = on


func _drop() -> void:
	visible = true
	position = _rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(self, "position", _rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_enable_keys(true)
		$Dust.restart()
		$Thud.cue(global_position)
		_start())
	tween.tween_property($Model, "scale", Vector3(1.06, 0.8, 1.06), 0.06)
	tween.tween_property($Model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
