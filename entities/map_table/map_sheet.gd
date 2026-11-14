class_name MapSheet
extends Node3D
## One paper map sheet of the map table (MapTable): a 3.2 x 1.8 m sheet that lies flat or rolls itself
## up (assets/shaders/map_sheet.gdshader). Its origin is the middle of its top edge, where the roll
## ends up; the paper runs from there along +Z, map-right is +X. The print is `Page`, a 2D SubViewport
## with the sheet's art and its lettering (Labels, translated like any other text) at the art's
## viewBox pixels (1 px = 1 mm on the desk), drawn once and again when the language changes.
## `Page/Sheet/Layers` takes more art over the base and under the lettering (a TextureRect each, e.g.
## the "owned" overlay of a country): show or hide one, then call reprint(). pixel_at() turns a point
## on the desk into the art's pixels, for clicks on the open sheet. `Things`
## holds what stands on the sheet (buildings, markers): they tuck away before it rolls up and pop back
## up once it lies flat. `Core` is the steel tube the paper is wound on (props/roll_core.tscn): it
## stays at the top edge, inside the roll while rolled (its label `Band` round the roll shows then)
## and lying there like a scroll rod on its end caps while the sheet is open; rolled, the roll also
## wears its name tag (`Core/Tag`: tag_name, "WORLD", a country's name), which is how the roll in the
## table's holder is labelled. The sheets (world_sheet.tscn, war_sheet.tscn, countries/<id>.tscn)
## are written by tools/make_map_sheets.py from reports/maps/labels.json.
## The sheets are nested (WORLD > a country > the WAR on one of its farms): a sheet asks the table
## for another one with `sheet_wanted`.

## Asks the table (MapTable) to roll out sheet `sheet` (a MapSheet.id): a country's from the world
## sheet, "war" for the war on `farm` from a country's sheet, the country's again from a war won
## (`farm`: the farm just taken).
@warning_ignore("unused_signal")
signal sheet_wanted(sheet: StringName, farm: StringName)

## The paper (m): map-right along X, top to bottom along Z.
const SIZE := Vector2(3.2, 1.8)
## The roll: its core's radius and how far apart its turns lie (m), as in the shader.
## The art's viewBox is 3200 x 1800 px: 1 px is 1 mm of paper.
const PIXELS_PER_METRE := 1000.0
const CORE := 0.03
const PITCH := 0.008
## The core's end caps' radius (m): open, the core rests on them. And how far open the roll is
## still whole enough to wear its label band.
const CAP := 0.055
const BAND_UNTIL := 0.02
## Where the hint slip for a spot of the open sheet lies when the sheet has no spot_box (hint_pixel):
## top left, in the sea.
const HINT_PIXEL := Vector2(110.0, 300.0)
## The name tag's lettering is set this big (Label3D font size), and smaller for a name longer than
## TAG_CHARS, so it stays on the card.
const TAG_FONT := 140
const TAG_CHARS := 16

## Which sheet this is (MapTable.show_sheet), its name on the hint slip over its roll, and the name
## on its roll's tag (roll_name; "": the title; tag_name).
@export var id: StringName
@export var title := ""
@export var roll_name := ""

## 1 lies flat, 0 is all rolled up at the top edge.
var open := 0.0:
	set(value):
		open = value
		_paper.set_shader_parameter(&"open", value)
		_core.position.y = core_height(value)
		_band.visible = value < BAND_UNTIL
		_roll_tag.visible = value < BAND_UNTIL
## How far the free edge stands up (0..1): paper memory, until the weights pin it down.
var lift := 0.0:
	set(value):
		lift = value
		_paper.set_shader_parameter(&"lift", value)

## What stands on the sheet, from map-left to map-right (the order of the pop-up wave), and each
## one's size when standing.
var _standing: Array[Node3D] = []
var _stand_scale: Array[Vector3] = []

@onready var _page: SubViewport = $Page
@onready var _paper: ShaderMaterial = $Paper.material_override
@onready var _core: Node3D = $Core
@onready var _band: Node3D = $Core/Band
@onready var _roll_tag: Node3D = $Core/Tag
@onready var _roll_tag_text: Label3D = $Core/Tag/Name


func _ready() -> void:
	_paper.set_shader_parameter(&"sheet_tex", _page.get_texture())
	open = open  # The paper, the core and the roll's tag as `open` has them (rolled up), before anyone sets it.
	lift = lift
	for child in $Things.get_children():
		_standing.append(child as Node3D)
	_standing.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)
	for thing in _standing:
		_stand_scale.append(thing.scale)
		thing.hide()
	_print_tag()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		reprint()  # The lettering changed.
		_print_tag()


## Prints the page onto the paper again: after a layer or a label changed.
func reprint() -> void:
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE


## The art's pixel (0..3200, 0..1800: its viewBox) under world point `point` on the lying sheet;
## outside that range the point is off the paper (on_paper).
func pixel_at(point: Vector3) -> Vector2:
	var local := global_transform.affine_inverse() * point
	return Vector2(local.x + SIZE.x / 2.0, local.z) * PIXELS_PER_METRE


## Where art pixel `pixel` lies in the world, on the lying sheet: pixel_at the other way round.
func point_at(pixel: Vector2) -> Vector3:
	return global_transform * Vector3(pixel.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0, pixel.y / PIXELS_PER_METRE)


static func on_paper(pixel: Vector2) -> bool:
	return Rect2(Vector2.ZERO, SIZE * PIXELS_PER_METRE).has_point(pixel)


## The sheet's name on the hint slip over its roll.
func hint_title() -> String:
	return tr(title)


## The name on its roll's tag, in capitals: `roll_name`, or its title.
func tag_name() -> String:
	return tr(roll_name if roll_name != "" else title).to_upper()


func _print_tag() -> void:
	_roll_tag_text.text = tag_name()
	var letters := maxi(_roll_tag_text.text.length(), 1)
	_roll_tag_text.font_size = roundi(TAG_FONT * minf(TAG_CHARS, letters) / letters)


## What can be pointed at on the open sheet at art pixel `pixel` (a farm site's id), or nothing.
## A sheet with such spots (FarmRegister) says here what they are, hint() what the hint slip reads
## for one, hover() lifts one (or none) and press() is a click on one.
func spot_at(_pixel: Vector2) -> StringName:
	return &""


func hint(_spot: StringName) -> String:
	return ""


## Where the hint slip for a spot lies when the sheet has no spot_box for it: its top left corner on
## this art pixel, on a part of the sheet where it covers no spot (HINT_PIXEL unless the sheet knows better).
func hint_pixel() -> Vector2:
	return HINT_PIXEL


## What spot `spot` covers of the art (px): its token and its tags. The hint slip lies right beside
## it (MapTable.beside). An empty Rect2: the slip lies at hint_pixel instead.
func spot_box(_spot: StringName) -> Rect2:
	return Rect2()


## What `tag` (a Label on the page, its lettering centred in it) covers with its lettering (px).
static func lettering(tag: Label) -> Rect2:
	var text := tag.get_minimum_size()
	return Rect2(tag.position + (tag.size - text) / 2.0, text)


func hover(_spot: StringName) -> void:
	pass


func press(_spot: StringName) -> void:
	pass


## The mouse moved over the open sheet, to art pixel `pixel` ((-1, -1): off it): what is dragged
## follows (FarmRegister: a bundle onto the negotiation letter).
func drag(_pixel: Vector2) -> void:
	pass


## The corners (world) of a paper on the sheet the camera should glide in on to be read (MapTable:
## the negotiation letter); empty for none.
func focus() -> PackedVector3Array:
	return PackedVector3Array()


## The left button came up with the mouse on `spot` (&"": on nothing): what is dragged is let go.
func release(_spot: StringName) -> void:
	pass


## Whether something plays out on the sheet that must not be rolled up under (a purchase, an offer).
func busy() -> bool:
	return false


func thing_count() -> int:
	return _standing.size()


## Stands thing `i` up by `k`: 0 tucked away (hidden) .. 1 standing; beyond 1 it overshoots.
func raise_thing(k: float, i: int) -> void:
	_standing[i].visible = k > 0.001
	_standing[i].scale = _stand_scale[i] * maxf(k, 0.001)


## Whether thing `i` stands on the sheet (not tucked away).
func thing_up(i: int) -> bool:
	return _standing[i].visible


## How high the core's axis lies over the sheet's top edge (m) with `open_now` of the sheet lying
## flat: in the roll's middle, and never lower than its end caps let it.
static func core_height(open_now: float) -> float:
	return maxf(roll_radius(open_now), CAP)


## The roll's outer radius (m) with `open_now` (0..1) of the sheet lying flat: it grows as it takes
## up paper, from the bare core to roll_radius(0.0).
static func roll_radius(open_now: float) -> float:
	return sqrt(CORE * CORE + PITCH / PI * SIZE.y * (1.0 - clampf(open_now, 0.0, 1.0)))
