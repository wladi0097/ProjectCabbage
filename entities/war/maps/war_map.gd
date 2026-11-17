class_name WarMap
extends Node3D
## A fighting map (research/war-contract.md): building scenes from entities/war/buildings/ placed as
## children, each centred on its footprint, `CELL` m to a grid cell; the map's origin is the grid's
## top-left corner, map-right +X, map-down +Z (the map-sheet frame). Its kind is the scene's file
## name (cannon, mortar, farmhouse, wall_wood, ..., zone), its cell comes from its position. A
## deployment zone (zone.tscn, hatched) is scaled to its size in cells (scale x / z).
## layout() is WarFight's layout; buildings() and zones() are the nodes in WarFight's order.
## Every piece sits on whole cells (the paper's heavy lines, tools/make_war_paper.py; a test checks).
## Walls show their arms toward standing wall neighbours (show_walls); wreck() swaps a building
## to its Rubble. Terrain (WarFight.TERRAIN, scenes in entities/war/terrain/) is placed the same way:
## hedges and bridges are 1-cell pieces, ponds, rivers, roads and fields one node each with a `size`
## in cells (terrain_piece.gd); show_terrain() joins touching pieces of a kind.
## A war's map follows the order, not the farm clicked: the n-th war in a country is fought on
## entities/war/maps/<its n-th war farm's id>.tscn (map_id: "veldmark-1", at home K-6, K-7, K-8);
## a war without one fights on DEFAULT.

const World := preload("res://entities/map_table/world_register.gd")
const CELL := 0.16
## The maps: <map id>.tscn in MAPS (scene_for), DEFAULT for a war without one.
const MAPS := "res://entities/war/maps/"
const DEFAULT := "res://entities/war/maps/test_map.tscn"
## Where each kind's scene lies (piece_path).
const BUILDINGS_DIR := "res://entities/war/buildings/"
const TERRAIN_DIR := "res://entities/war/terrain/"
## Footprints that are not 1x1 (cells).
const SIZES := {mortar = Vector2i(2, 2), silo = Vector2i(2, 2), farmhouse = Vector2i(2, 2)}
const ARMS := {East = Vector2i(1, 0), North = Vector2i(0, -1), West = Vector2i(-1, 0), South = Vector2i(0, 1)}
## A wall with no wall neighbour runs north-south across its cell: across the attack, which comes from
## the zones on the left (or the bottom edge, where it still reads as a wall piece).
const LONE_ARMS: Array[String] = ["North", "South"]
## Terrain kinds whose touching pieces merge into one look (terrain_piece.gd).
const MERGED: Array[String] = ["pond", "river", "road", "field"]
const TerrainPiece := preload("res://entities/war/terrain/terrain_piece.gd")
## A map's difficulty band (1..5) on the k ladder: band i + 1 from k BAND_FROM[i] (research/war-balance.md;
## the 19 wars' targets 1.0 .. 3.42 spread over all five). BAND_NAMES are their text keys.
const BAND_FROM: Array[float] = [0.0, 1.15, 1.6, 2.1, 2.75]
const BAND_NAMES: Array[String] = ["ROUTINE", "MODERATE", "SERIOUS", "SEVERE", "CATASTROPHIC"]

@export var grid_size := Vector2i(20, 11)
## What the battle calculator found (BattleSim.difficulty, written by tools/battle_sim.gd --write-all;
## a test fails when it is stale): {k, associates, style, cabbages}. Read with difficulty_for().
@export var difficulty := {}
## The site's name as the declaration and the sheet's title block print it (a key, EN, its DE in
## game.csv): the part of research/war-maps.md's heading after the dot, "THE SUPERVISED PLOT".
## "": the declaration prints none and the title block the farm code only.
@export var site_name := ""
## The declaration's one deadpan line about the site (a key, EN; war-maps.md section 2, no quotes).
@export_multiline var briefing := ""


func _ready() -> void:
	show_walls()
	show_terrain()


## The map of the war on `farm` for `save`: the country's farm id in the place of the farms of it
## `save` already owns (`farm` itself left out), so the n-th war there is on its n-th map whichever
## farm is attacked (inside a country the player picks the order). At home the first five farms are
## bought: its wars are K-6, K-7, K-8.
static func map_id(farm: StringName, save: SaveGame) -> String:
	var country := World.country_of(farm)
	var ids := World.farm_ids(country)
	var taken := World.farms_of(save, country) - int(save.farms_owned.has(farm))
	return ids[clampi(taken, 0, ids.size() - 1)]


## The map scene the war on `farm` is fought on for `save`: MAPS/<map_id>.tscn, or DEFAULT if there is none.
static func scene_for(farm: StringName, save: SaveGame) -> String:
	var path := MAPS + map_id(farm, save) + ".tscn"
	return path if ResourceLoader.exists(path) else DEFAULT


## Every map scene in MAPS (the farms' and DEFAULT; zone.tscn is a piece, not a map).
static func map_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(MAPS):
		file = file.trim_suffix(".remap")
		if file.get_extension() == "tscn" and file != "zone.tscn":
			out.append(MAPS + file)
	return out


## The scene of map piece `kind` (a building, a terrain kind or "zone").
static func piece_path(kind: String) -> String:
	if kind == "zone":
		return MAPS + "zone.tscn"
	return (TERRAIN_DIR if kind in WarFight.TERRAIN else BUILDINGS_DIR) + kind + ".tscn"


## The difficulty of the war on `farm` for `save` (scene_for), from its map's stored `difficulty` (no fight is run): {band
## (1..5), band_name (BAND_NAMES), k (the map's strength), associates (the fewest field associates that
## take it, no research; -1 if that is more than `cap` (> 0) or they never do), style (the cheapest
## playstyle, a BattleSim.PLAYSTYLES id or "mixed"), cabbages (its army's price)}. {} if never assessed.
static func difficulty_for(farm: StringName, save: SaveGame, cap := 0) -> Dictionary:
	var map: WarMap = load(scene_for(farm, save)).instantiate()
	var stored: Dictionary = map.difficulty
	map.free()
	if stored.is_empty():
		return {}
	var band := band_of(stored.k)
	var associates: int = stored.associates
	return {band = band, band_name = BAND_NAMES[band - 1], k = stored.k, style = stored.style, cabbages = stored.cabbages,
			associates = associates if cap <= 0 or associates <= cap else -1}


## The difficulty band (1..5) of a map of strength `k`.
static func band_of(k: float) -> int:
	var band := 1
	for i in BAND_FROM.size():
		if k >= BAND_FROM[i]:
			band = i + 1
	return band


static func kind_of(node: Node) -> String:
	return node.scene_file_path.get_file().get_basename()


static func size_of(kind: String) -> Vector2i:
	return SIZES.get(kind, Vector2i.ONE)


## Node `node`'s footprint (cells): a zone's from its scale, a terrain rectangle's its `size`, a
## building's from its kind.
static func footprint(node: Node3D) -> Vector2i:
	if kind_of(node) == "zone":
		return Vector2i(roundi(node.scale.x), roundi(node.scale.z))
	if kind_of(node) in MERGED:
		return (node as TerrainPiece).size
	return size_of(kind_of(node))


static func cell_of(node: Node3D) -> Vector2i:
	var size := Vector2(footprint(node))
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
		out.append({kind = kind_of(child), cell = cell_of(child), size = footprint(child)})
	return out


## The building nodes in WarFight.buildings' order (the zones and the terrain left out).
func buildings() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in pieces():
		if kind_of(child) != "zone" and kind_of(child) not in WarFight.TERRAIN:
			out.append(child)
	return out


## The terrain nodes in WarFight.terrain's order.
func terrain() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in pieces():
		if kind_of(child) in WarFight.TERRAIN:
			out.append(child)
	return out


## The deployment zones' nodes in WarFight.zones' order.
func zones() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in pieces():
		if kind_of(child) == "zone":
			out.append(child)
	return out


## Where cell-space point `p` lies on the map (local).
static func point(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y) * CELL


## Each wall's arms toward its wall neighbours that stand (`alive`: per buildings() index; empty:
## all standing). A wall with none stands as a 1-cell segment across the attack (LONE_ARMS), so it
## reads as a piece of wall, not a lone post.
func show_walls(alive: Array = []) -> void:
	var nodes := buildings()
	var standing := {}
	for i in nodes.size():
		if kind_of(nodes[i]).begins_with("wall") and (alive.is_empty() or alive[i]):
			standing[cell_of(nodes[i])] = true
	for i in nodes.size():
		if kind_of(nodes[i]).begins_with("wall"):
			var shown := wall_arms(cell_of(nodes[i]), standing)
			for arm: String in ARMS:
				(nodes[i].get_node("Arms/" + arm) as Node3D).visible = arm in shown


## The arms a wall on `cell` shows among `standing` wall cells (cell -> true): toward each standing
## neighbour, or LONE_ARMS with none.
static func wall_arms(cell: Vector2i, standing: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for arm: String in ARMS:
		if standing.has(cell + ARMS[arm]):
			out.append(arm)
	return out if not out.is_empty() else LONE_ARMS


## Joins the terrain: each merged kind's pieces are built with every cell of that kind on the map (a
## pond's rim only round the whole pond), hedges show their arms toward hedge neighbours, and a bridge's
## deck turns to cross its river (it spans north-south unless the river runs that way).
func show_terrain() -> void:
	var cells := {}  # kind -> {cell: true}
	for node in terrain():
		var kind := kind_of(node)
		if not cells.has(kind):
			cells[kind] = {}
		var size := footprint(node)
		for y in size.y:
			for x in size.x:
				cells[kind][cell_of(node) + Vector2i(x, y)] = true
	var river: Dictionary = cells.get("river", {})
	var hedges: Dictionary = cells.get("hedge", {})
	for node in terrain():
		var kind := kind_of(node)
		var cell := cell_of(node)
		if kind in MERGED:
			(node as TerrainPiece).build(cells[kind], cell)
		elif kind == "hedge":
			for arm: String in ARMS:
				(node.get_node("Arms/" + arm) as Node3D).visible = hedges.has(cell + ARMS[arm])
		elif kind == "bridge":
			var along_y: bool = (river.has(cell + Vector2i.UP) or river.has(cell + Vector2i.DOWN)) 					and not (river.has(cell + Vector2i.LEFT) or river.has(cell + Vector2i.RIGHT))
			(node.get_node("Deck") as Node3D).rotation.y = PI / 2.0 if along_y else 0.0


## Building `node` as rubble (`down`) or standing.
static func wreck(node: Node3D, down: bool) -> void:
	for child in node.get_children():
		if child is Node3D and child.name != "Body":
			(child as Node3D).visible = (child.name == "Rubble") == down


## Every war's map id in the campaign's order: each country's last `wars` farms (at home K-6, K-7,
## K-8; abroad all), countries in WorldRegister.COUNTRIES order. The title block's "SHEET n OF 19".
static func campaign() -> PackedStringArray:
	var out := PackedStringArray()
	for country: StringName in World.COUNTRIES:
		var ids := World.farm_ids(country)
		out.append_array(ids.slice(ids.size() - World.COUNTRIES[country].wars.size()))
	return out


## Map `id`'s place in the campaign (1 .. campaign().size()); 0 if it is not one of its wars.
static func sheet_number(id: String) -> int:
	return campaign().find(id) + 1


## Whether map `id` is the campaign's last war (Endmark Isle): its sheet arrives staged.
static func is_final(id: String) -> bool:
	return campaign()[-1] == id


## The scene map `id` is fought on (scene_for's rule for a map id): MAPS/<id>.tscn, else DEFAULT.
static func path_of(id: String) -> String:
	var path := MAPS + id + ".tscn"
	return path if ResourceLoader.exists(path) else DEFAULT


## The piece kinds map scene `path` holds (kind -> true), read from the packed scene, nothing built.
static func kinds_in(path: String) -> Dictionary:
	var state := (load(path) as PackedScene).get_state()
	var out := {}
	for i in state.get_node_count():
		var piece := state.get_node_instance(i)
		if piece != null:
			out[piece.resource_path.get_file().get_basename()] = true
	return out


## Building kinds that get a NEW STRUCTURE ON SITE slip on their first map: the defences and the
## two stronger fences (picket and the farmhouse are on the first war).
const DEBUT_KINDS: Array[String] = ["cannon", "mortar", "cctv", "sprinkler", "shredder", "silo", "wall_stone", "wall_steel"]


## The DEBUT_KINDS map `id` is the first in the campaign to hold, in DEBUT_KINDS order.
static func debuts(id: String) -> Array[String]:
	var maps := campaign()
	var at := maps.find(id)
	if at < 0:
		return []
	var seen := {}
	for k in at:
		seen.merge(kinds_in(path_of(maps[k])))
	var here := kinds_in(path_of(id))
	return DEBUT_KINDS.filter(func(kind: String) -> bool: return here.has(kind) and not seen.has(kind))


## What the declaration of the war on `farm` for `save` prints about its map (scene_for): {site_name,
## briefing (keys; "" unfilled), final (the campaign's last war)}.
static func brief_for(farm: StringName, save: SaveGame) -> Dictionary:
	var map: WarMap = load(scene_for(farm, save)).instantiate()
	var out := {site_name = map.site_name, briefing = map.briefing, final = is_final(map_id(farm, save))}
	map.free()
	return out
