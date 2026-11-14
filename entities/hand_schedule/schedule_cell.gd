class_name ScheduleCell
extends Button
## One picture on the handling schedule: a cabbage kind (`kind`, HandSchedule.KINDS) in the lab
## hands' (`research`) or hired hands' half. Clicked, the sheet strikes or clears it. Struck: the
## picture pales under a red rubber stamp, NOT TO BE HANDLED. A kind the schedule does not list yet is
## faint, with a padlock, and takes no click. Instance schedule_cell.tscn and set kind, research,
## caption, ink and picture_scale.

## The printed cabbage's ink when the kind is not listed yet, and how much of it shows under the stamp.
const FAINT := Color(0.13, 0.14, 0.14, 0.2)
const STRUCK := 0.4

@export var kind := "regular"
@export var research := false
## The kind's name under the picture.
@export var caption := "PLAIN"
## The picture's ink (the kind's colour) and its size (a mini is printed smaller).
@export var ink := Color(0.33, 0.6, 0.18)
@export var picture_scale := 1.0

@onready var _picture: TextureRect = $Picture
@onready var _name: Label = $Name


func _ready() -> void:
	_name.text = caption
	_picture.scale = Vector2.ONE * picture_scale


## Shows the cell for a kind that is `listed` (else faint and padlocked) and `struck` or not.
func show_state(listed: bool, struck: bool) -> void:
	disabled = not listed
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if listed else Control.CURSOR_ARROW
	_picture.modulate = Color(ink, STRUCK if struck else 1.0) if listed else FAINT
	_name.modulate.a = 1.0 if listed else 0.4
	$Lock.visible = not listed
	$Stamp.visible = listed and struck
