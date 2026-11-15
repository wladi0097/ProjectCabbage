class_name WarInk
extends Control
## What the planning hand draws on the war sheet's paper (Page/Sheet/Ink, in art px; the sheet
## reprints after a change): the range ring of the defence under the mouse in thin oxblood ink, the
## mailing unit's dead zone as a second, dashed ring inside it (ring), and the pencil line of the way
## a held figure would walk to its first target (path). Nothing is drawn while neither is set.

@export var ink := Color(0.416, 0.169, 0.157, 0.85)
@export var pencil := Color(0.22, 0.23, 0.23, 0.75)
@export var ring_width := 4.0
@export var pencil_width := 5.0
@export var dash := 18.0

## The ring: its centre and radius (px); dead > 0 is the dead zone's radius inside it.
var ring_at := Vector2.ZERO
var ring_radius := 0.0
var dead_radius := 0.0
## The pencil line's points (px), from the figure to its target; empty: none.
var path := PackedVector2Array()


## Rings the reach `radius` round `at` (px), the dead zone `dead` inside it (0: none); radius 0 rubs it out.
func ring(at: Vector2, radius: float, dead := 0.0) -> void:
	ring_at = at
	ring_radius = radius
	dead_radius = dead
	queue_redraw()


## Pencils `points` (px); empty rubs it out.
func line(points: PackedVector2Array) -> void:
	path = points
	queue_redraw()


func clear() -> void:
	ring(Vector2.ZERO, 0.0)
	line(PackedVector2Array())


func _draw() -> void:
	if ring_radius > 0.0:
		draw_arc(ring_at, ring_radius, 0.0, TAU, 128, ink, ring_width, true)
	if dead_radius > 0.0:
		var steps := 24
		for k in steps:
			draw_arc(ring_at, dead_radius, TAU * k / steps, TAU * (k + 0.5) / steps, 6, ink, ring_width * 0.75, true)
	for k in range(1, path.size()):
		draw_dashed_line(path[k - 1], path[k], pencil, pencil_width, dash, true, true)
