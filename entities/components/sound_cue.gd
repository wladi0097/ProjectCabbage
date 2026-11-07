class_name SoundCue
extends AudioStreamPlayer3D
## A 3D sound slot for an event that can fire very often (coins, bumps, drum ticks). Variation
## and pitch jitter come from an AudioStreamRandomizer as the stream. This node caps how often
## it restarts and scales volume by impact strength, so a shower of events reads as one rattle
## instead of a machine gun of identical hits. Set max_polyphony on the node to cap overlaps.
## Every cabbage and coin carries its own cues, so the same sound is also capped game-wide (the
## "max instances" / "playback limit" of FMOD and Wwise): at most max_instances plays of one stream
## at once across all nodes; a cue over the cap is dropped. The SFX bus compressor and the Master
## limiter (default_bus_layout.tres) catch what still piles up.

## Shortest gap between two plays, in seconds. Cues inside it are dropped.
@export var min_interval := 0.0
## Strength at or below this is silent; at full_strength and above it plays at full volume.
@export var silent_strength := 0.0
@export var full_strength := 1.0
## At most this many plays of this stream at once, game-wide.
@export var max_instances := 4

## Plays running now per stream, over every SoundCue.
static var _playing := {}
var _base_db := 0.0
var _last_msec := -100000
## This node is counted in _playing.
var _counted := false


func _ready() -> void:
	_base_db = volume_db
	finished.connect(_uncount)
	tree_exiting.connect(_uncount)


func cue(at: Vector3, strength := 1.0) -> void:
	var level := level_for(strength, silent_strength, full_strength)
	var now := Time.get_ticks_msec()
	if stream == null or level <= 0.0 or now - _last_msec < min_interval * 1000.0:
		return
	if not _counted and not has_room(_playing.get(stream, 0), max_instances):
		return
	_last_msec = now
	if not _counted:
		_counted = true
		_playing[stream] = _playing.get(stream, 0) + 1
	global_position = at
	volume_db = _base_db + linear_to_db(level)
	play()


static func level_for(strength: float, silent: float, full: float) -> float:
	return clampf(inverse_lerp(silent, full, strength), 0.0, 1.0)


## Another play fits under the game-wide cap: `running` of this stream run now, at most `cap`.
static func has_room(running: int, cap: int) -> bool:
	return running < cap


func _uncount() -> void:
	if _counted:
		_counted = false
		_playing[stream] = maxi(0, _playing.get(stream, 1) - 1)
