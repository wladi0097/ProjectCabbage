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

## Layer of hover_box bodies (the cards' one: the hand's ray finds it, nothing collides with it).
const HOVER_LAYER := 8

@export var enabled := true
## What it does, shown next to it while hovered (Hand: at once the first time, after a second later).
@export_multiline var tooltip := ""
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
## Carried from below like a sheet of paper: held, the hand turns palm up and sits
## carry_offset from the parent (the parent keeps it current, e.g. under a lifted card).
@export var carried := false
var carry_offset := Vector3.ZERO


func _ready() -> void:
	get_parent().set_meta(&"interactable", self)


static func of(object: Object) -> Interactable:
	if object == null or not object.has_meta(&"interactable"):
		return null
	if object is Node3D and not (object as Node3D).is_visible_in_tree():
		return null  # Hidden (not on the desk yet): nothing to hover.
	var found := object.get_meta(&"interactable") as Interactable
	return found if found != null and found.enabled else null


## Makes `box` (in `target`'s space) of a display hoverable for its `text` only (a counter, a gauge):
## a body on the cards' layer, found by the hand's ray, colliding with nothing.
static func hover_box(target: Node3D, box: AABB, text: String) -> Interactable:
	var body := StaticBody3D.new()
	body.collision_layer = HOVER_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size
	shape.shape = cube
	shape.position = box.get_center()
	body.add_child(shape)
	var hover := Interactable.new()
	hover.tooltip = text
	body.add_child(hover)
	target.add_child(body)
	return hover
