class_name Interactable
extends Node
## Makes its parent CollisionObject3D hoverable and grabbable by the Hand autoload.
## The parent reacts to the signals; the Hand only picks, grabs and swaps the cursor.

signal hovered
signal unhovered
signal grabbed
signal released

@export var enabled := true
## A button to press rather than a thing to pick up: the hand points at it, tapping its finger,
## and presses in while held.
@export var pressable := false
## While true, the hand also grabs it by sweeping into it with the button already held (catching
## something in the air), not only by pressing over it.
var catchable := false


func _ready() -> void:
	get_parent().set_meta(&"interactable", self)


static func of(object: Object) -> Interactable:
	if object == null or not object.has_meta(&"interactable"):
		return null
	var found := object.get_meta(&"interactable") as Interactable
	return found if found != null and found.enabled else null
