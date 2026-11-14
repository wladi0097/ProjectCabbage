class_name WarMap
extends Node3D
## A fighting map (research/war-contract.md): building scenes from entities/war/buildings/ placed as
## children, each centred on its footprint, `CELL` m to a grid cell; the map's origin is the grid's
## top-left corner, map-right +X, map-down +Z (the map-sheet frame). Its kind is the scene's file
## name (cannon, mortar, farmhouse, wall_wood, ..., landing), its cell comes from its position.
## layout() is WarFight's layout; buildings() and landings() are the nodes in WarFight's order.
## Walls show their arms toward standing wall neighbours (show_walls); wreck() swaps a building
## to its Rubble.

const CELL := 0.16
## Footprints that are not 1x1 (cells).
const SIZES := {mortar = Vector2i(2, 2), farmhouse = Vector2i(3, 3)}
const ARMS := {East = Vector2i(1, 0), North = Vector2i(0, -1), West = Vector2i(-1, 0), South = Vector2i(0, 1)}

@export var grid_size := Vector2i(12, 8)


func _ready() -> void:
	show_walls()


static func kind_of(node: Node) -> String:
	return node.scene_file_path.get_file().get_basename()


static func size_of(kind: String) -> Vector2i:
	return SIZES.get(kind, Vector2i.ONE)


static func cell_of(node: Node3D) -> Vector2i:
	var size := Vector2(size_of(kind_of(node)))
	return Vector2i((Vector2(node.position.x, node.position.z) / CELL - size / 2.0).round())


## The building scenes on the map, in child order (figures placed on it are not).
func pieces() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child: Node3D in get_children():
		if kind_of(child) != "":
			out.append(child)
	return out


## WarFight's layout: {kind, cell, size} per piece, in child order.
func layout() -> Array:
	var out := []
	for child in pieces():
		out.append({kind = kind_of(child), cell = cell_of(child), size = size_of(kind_of(child))})
	return out


## The building nodes in WarFight.buildings' order (the landing spots left out).
func buildings() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in pieces():
		if kind_of(child) != "landing":
			out.append(child)
	return out


## The landing spots' nodes in WarFight.landings' order.
func landings() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in pieces():
		if kind_of(child) == "landing":
			out.append(child)
	return out


## Where cell-space point `p` lies on the map (local).
static func point(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y) * CELL


## Each wall's arms toward its wall neighbours that stand (`alive`: per buildings() index; empty:
## all standing).
func show_walls(alive: Array = []) -> void:
	var nodes := buildings()
	var standing := {}
	for i in nodes.size():
		if kind_of(nodes[i]).begins_with("wall") and (alive.is_empty() or alive[i]):
			standing[cell_of(nodes[i])] = true
	for i in nodes.size():
		if kind_of(nodes[i]).begins_with("wall"):
			for arm: String in ARMS:
				(nodes[i].get_node("Arms/" + arm) as Node3D).visible = standing.has(cell_of(nodes[i]) + ARMS[arm])


## Building `node` as rubble (`down`) or standing.
static func wreck(node: Node3D, down: bool) -> void:
	for child in node.get_children():
		if child is Node3D and child.name != "Body":
			(child as Node3D).visible = (child.name == "Rubble") == down
