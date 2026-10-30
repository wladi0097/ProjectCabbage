class_name SoundCue
extends AudioStreamPlayer3D
## A 3D sound slot for an event that can fire very often (coins, bumps, drum ticks). Variation
## and pitch jitter come from an AudioStreamRandomizer as the stream. This node caps how often
## it restarts and scales volume by impact strength, so a shower of events reads as one rattle
## instead of a machine gun of identical hits. Set max_polyphony on the node to cap overlaps.

## Shortest gap between two plays, in seconds. Cues inside it are dropped.
@export var min_interval := 0.0
## Strength at or below this is silent; at full_strength and above it plays at full volume.
@export var silent_strength := 0.0
@export var full_strength := 1.0

var _base_db := 0.0
var _last_msec := -100000


func _ready() -> void:
	_base_db = volume_db


func cue(at: Vector3, strength := 1.0) -> void:
	var level := level_for(strength, silent_strength, full_strength)
	var now := Time.get_ticks_msec()
	if stream == null or level <= 0.0 or now - _last_msec < min_interval * 1000.0:
		return
	_last_msec = now
	global_position = at
	volume_db = _base_db + linear_to_db(level)
	play()


static func level_for(strength: float, silent: float, full: float) -> float:
	return clampf(inverse_lerp(silent, full, strength), 0.0, 1.0)
