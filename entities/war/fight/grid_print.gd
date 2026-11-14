extends Control
## The fighting map's grid, printed on the war sheet's paper: `cells` cells of `cell_px` art pixels,
## from this control's top-left corner (the map's origin).

const INK := Color(0.11, 0.125, 0.118)

@export var cells := Vector2i(12, 8):
	set(value):
		cells = value
		queue_redraw()
@export var cell_px := 160.0


func _draw() -> void:
	var whole := Vector2(cells) * cell_px
	for x in range(1, cells.x):
		draw_line(Vector2(x * cell_px, 0.0), Vector2(x * cell_px, whole.y), Color(INK, 0.2), 2.0)
	for y in range(1, cells.y):
		draw_line(Vector2(0.0, y * cell_px), Vector2(whole.x, y * cell_px), Color(INK, 0.2), 2.0)
	draw_rect(Rect2(Vector2.ZERO, whole), Color(INK, 0.85), false, 5.0)
