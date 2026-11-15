extends MeshInstance3D
## A wreck turned a quarter turn and mirrored by its building's spot on the map, so a row of
## wrecked fence pieces does not repeat one stamp. Quarter turns keep it inside its cell.


func _ready() -> void:
	var spot := (get_parent() as Node3D).position
	var turn := look(Vector2(spot.x, spot.z))
	rotation.y = turn.x * PI / 2.0
	scale.x = turn.y


## The quarter turns (0..3) and the mirror (1 or -1) for a building standing at map point `at`.
static func look(at: Vector2) -> Vector2i:
	var h := hash(Vector2i((at / WarMap.CELL * 2.0).round()))
	return Vector2i(h % 4, 1 if (h >> 2) % 2 == 0 else -1)
