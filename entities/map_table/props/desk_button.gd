extends Node3D
## The map table's TO DESK call button (MapTable): an oxblood push button on a sage plinth, its
## engraved plate (`Stencil`) beside it. press() pushes the button in and lets it spring back, with
## the supply console's bakelite button clack (`Press`).

## How far the button goes in (m), how long a press takes (s) and the part of it going down.
const TRAVEL := 0.006
const PRESS_TIME := 0.2
const DOWN := 0.25

@onready var _button: Node3D = $Button


## How deep the button sits (m) `k` of the way through a press: in fast, out slower.
static func depth(k: float) -> float:
	return TRAVEL * (k / DOWN if k < DOWN else (1.0 - k) / (1.0 - DOWN))


func press() -> void:
	($Press as SoundCue).cue(global_position)
	create_tween().tween_method(_sink, 0.0, 1.0, PRESS_TIME)


func _sink(k: float) -> void:
	_button.position.y = -depth(k)
