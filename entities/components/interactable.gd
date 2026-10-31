class_name Interactable
extends Node
## Makes its parent CollisionObject3D hoverable and grabbable by the Hand autoload.
## The parent reacts to the signals; the Hand only picks, grabs and swaps the cursor.

@warning_ignore("unused_signal")
signal hovered
@warning_ignore("unused_signal")
signal unhovered
@warning_ignore("unused_signal")
signal grabbed
@warning_ignore("unused_signal")
signal released

@export var enabled := true
## A button to press rather than a thing to pick up: the hand points at it, tapping its finger,
## and presses in while held.
@export var pressable := false
## Held, the palm rests this far above the parent's centre (a cabbage's radius by default).
@export var grip_height := 0.135
## A handle: hovered, the hand already goes onto it half-closed, ready to grab.
@export var reach := false
## While true, the hand also grabs it by sweeping into it with the button already held (catching
## something in the air), not only by pressing over it.
var catchable := false
## Carried from below like a sheet of paper: hovered or held, the hand turns palm up and sits
## carry_offset from the parent (the parent keeps it current, e.g. under a lifted card).
@export var carried := false
var carry_offset := Vector3.ZERO


func _ready() -> void:
	get_parent().set_meta(&"interactable", self)


static func of(object: Object) -> Interactable:
	if object == null or not object.has_meta(&"interactable"):
		return null
	var found := object.get_meta(&"interactable") as Interactable
	return found if found != null and found.enabled else null
