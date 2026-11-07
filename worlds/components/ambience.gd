extends AudioStreamPlayer
## The office room tone: loops PATH on the SFX bus, but only while no music runs. It fades out
## (FADE seconds) when the radio plays and back in when it stops. PATH is a 60 s cut of the
## fluorescent-hum take in assets/audio/sources/office_roomtone, 3 s crossfade at the seam.

const PATH := "res://assets/audio/ambience/office_roomtone.ogg"
const FADE := 1.0
const QUIET := 0.0001

## Full level, under the radio and the effects.
@export var level_db := -8.0

var _level := 0.0


func _ready() -> void:
	if not ResourceLoader.exists(PATH):
		return
	stream = load(PATH)
	stream.set("loop", true)
	_level = 1.0 if plays(SaveManager.save) else 0.0
	volume_db = linear_to_db(maxf(_level, QUIET)) + level_db
	play()


func _process(delta: float) -> void:
	if stream == null:
		return
	_level = move_toward(_level, 1.0 if plays(SaveManager.save) else 0.0, delta / FADE)
	volume_db = linear_to_db(maxf(_level, QUIET)) + level_db
	stream_paused = _level <= 0.0


## The room tone only plays while the radio isn't playing music.
static func plays(save: SaveGame) -> bool:
	return not (Radio.bought(save) and save.radio_on)
