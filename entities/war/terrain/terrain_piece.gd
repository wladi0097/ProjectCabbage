@tool
extends Node3D
## A rectangle of terrain on a war map (pond, river, road, field: research/war-contract.md), `size`
## cells, centred on its footprint like every map piece. Its look is put together from tile meshes:
## `base` on every cell (as it is), `edge` on each side whose neighbour is not the same terrain and
## `corner` in each inner corner (both sides joined, the cell between them not), each made for the
## north side (north-east corner) and turned for the others. WarMap.show_terrain() builds it with every
## cell of its kind on the map, so touching pieces merge into one pond or one river; on its own (the
## editor) it shows just itself. One generated mesh, one surface per material.

## The sides in quarter turns about +Y from north: north, west, south, east.
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]

@export var size := Vector2i.ONE:
	set(value):
		size = value.max(Vector2i.ONE)
		if is_node_ready():
			build()
@export var base: Mesh
@export var edge: Mesh
@export var corner: Mesh

var _mesh: MeshInstance3D


func _ready() -> void:
	build()


## Builds the look. `joined`: every cell of this kind on the map -> true (empty: only this piece's,
## its top-left at `at`).
func build(joined := {}, at := Vector2i.ZERO) -> void:
	var meshes := {base = base, edge = edge, corner = corner}
	var tools := {}  # Material -> SurfaceTool
	for t: Array in tiles(size, joined, at):
		var centre := Vector3(t[1].x + 0.5 - size.x / 2.0, 0.0, t[1].y + 0.5 - size.y / 2.0) * WarMap.CELL
		_add(tools, meshes[t[0]], centre, t[2])
	var mesh := ArrayMesh.new()
	for material: Material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_mesh, false, INTERNAL_MODE_FRONT)  # Generated: never saved with the map.
	_mesh.mesh = mesh


## The tiles of a piece of `cells` whose top-left cell is `at`, among `joined` cells of its kind (empty:
## only its own): each [tile ("base", "edge", "corner"), cell inside the piece, quarter turns].
static func tiles(cells: Vector2i, joined: Dictionary, at := Vector2i.ZERO) -> Array:
	if joined.is_empty():
		for y in cells.y:
			for x in cells.x:
				joined[at + Vector2i(x, y)] = true
	var out := []
	for y in cells.y:
		for x in cells.x:
			var inside := Vector2i(x, y)
			var cell := at + inside
			out.append(["base", inside, 0])
			for i in SIDES.size():
				var side := SIDES[i]
				var next := SIDES[(i + 3) % 4]
				if not joined.has(cell + side):
					out.append(["edge", inside, i])
				elif joined.has(cell + next) and not joined.has(cell + side + next):
					out.append(["corner", inside, i])
	return out


static func _add(tools: Dictionary, tile: Mesh, centre: Vector3, turn: int) -> void:
	if tile == null:
		return
	var place := Transform3D(Basis(Vector3.UP, PI / 2.0 * turn), centre)
	for s in tile.get_surface_count():
		var material := tile.surface_get_material(s)
		if not tools.has(material):
			tools[material] = SurfaceTool.new()
		(tools[material] as SurfaceTool).append_from(tile, s, place)
