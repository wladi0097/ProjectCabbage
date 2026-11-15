extends MapSheet
## The world sheet: the nine countries, and the way into each one's own sheet. Each country has one
## holding point, a MapBuilding under `Things` (its `site` is the country's id, its `title` the
## name), a click outline `Page/Sheet/Outlines/<id>` (a Line2D, shown while the country is hovered),
## its cabbage-pattern overlay `Page/Sheet/Layers/<id>` (its art is loaded once a farm there is
## ours: each is a 3200 x 1800 texture) and a count tag `Page/Sheet/Count_<id>` ("0/2": farms owned
## of its farms). tools/make_map_sheets.py writes all of them from reports/maps/labels.json;
## COUNTRIES below is the same data as the rules need it (a test holds the two together).
## At the map: a country is hovered (its outline shows, its token lifts, the hint slip names it and
## its farms: no price, nothing is bought here) and clicked: its own sheet rolls out. A country not
## yet reachable (closed: none of it ours and its farms out of reach) shows a faded outline, the slip
## says why, and a click is refused (`Flash/Refuse`) (`sheet_wanted`,
## MapTable), where its farms are taken one at a time (FarmRegister). A country shows one of three
## looks (share): plain while none of its farms is ours, patches of the cabbage pattern once some
## are, wholly cabbage-pattern green only once ALL are.
## The rules of the world (static, read by FarmRegister, WarSheet, the debug key and the tests):
## which farms a country holds (farm_ids), which country a farm lies in (country_of), whether a
## country's farms can be attacked (reach) and what starting the war on the next one costs
## (war_price). No class_name: whoever needs the rules preloads this script (as props/map_tally.gd),
## so nothing waits for the editor to register a new global class.

const Events := preload("res://globalScripts/game_events.gd")

## The head office's country: its first farms are bought, its sheet is the first one.
const HOME := &"kohlmark"
## The desk card (UpgradeDesk) that opens the drawn sea lanes.
const SEA_CARD := "sea_lanes"
## Every country: how many farms it holds, how far it is from home (`rank`, reports/maps/labels.json
## `distance_rank`), the countries it borders by `land` and the ones across a drawn `sea` lane, and
## `wars`: what starting a war on each of its farms that cannot be bought costs, in coins only (the
## cabbages go into the soldiers, WarRules.UNIT_PRICE), in the order they are taken (at home the last
## three; abroad all). Cheap enough to repeat a lost war (round 2 point 24): about $200K for the first
## country's wars, about 13% more each war after, $1.65M for the last of Nordhal; the final island
## $3M. Paced in tools/pace.py (`python tools/pace.py ch3`: every war costs at most WAR_MINUTES of
## income when it is declared); the army and the fights set the war's pace, not its coins.
const COUNTRIES: Dictionary = {
	&"kohlmark": {farms = 8, rank = 0, land = [&"ostrevia", &"sulvania", &"veldmark"], sea = [],
		wars = [{coins = 200000}, {coins = 230000}, {coins = 260000}]},
	&"veldmark": {farms = 2, rank = 1, land = [&"kohlmark", &"ostrevia", &"sulvania"], sea = [],
		wars = [{coins = 300000}, {coins = 340000}]},
	&"ostrevia": {farms = 2, rank = 2, land = [&"kohlmark", &"veldmark"], sea = [],
		wars = [{coins = 390000}, {coins = 440000}]},
	&"sulvania": {farms = 3, rank = 3, land = [&"kohlmark", &"veldmark"], sea = [&"grauland", &"lower_provinces"],
		wars = [{coins = 500000}, {coins = 560000}, {coins = 630000}]},
	&"grauland": {farms = 2, rank = 4, land = [&"morrow", &"nordhal"], sea = [&"sulvania"],
		wars = [{coins = 710000}, {coins = 800000}]},
	&"lower_provinces": {farms = 2, rank = 5, land = [], sea = [&"morrow", &"sulvania"],
		wars = [{coins = 900000}, {coins = 1000000}]},
	&"morrow": {farms = 2, rank = 6, land = [&"grauland", &"nordhal"], sea = [&"lower_provinces"],
		wars = [{coins = 1150000}, {coins = 1300000}]},
	&"nordhal": {farms = 2, rank = 7, land = [&"grauland", &"morrow"], sea = [&"endmark"],
		wars = [{coins = 1450000}, {coins = 1650000}]},
	&"endmark": {farms = 1, rank = 8, land = [], sea = [&"nordhal"],
		wars = [{coins = 3000000}]},
}
## Why a country's farms cannot be attacked, as a war order's strip prints it (translation keys).
const NOT_ADJACENT := "NOT ADJACENT"
const NO_SEA_LANES := "NO SEA LANES"
## And the line under it (translation keys).
const REASONS := {
	NOT_ADJACENT: "No country next to this one is wholly ours. Yet.",
	NO_SEA_LANES: "The sea is not ours to cross yet.",
}
## Why a country's own sheet cannot be opened from the world sheet (closed), as the hint slip says it
## (translation keys): no neighbour wholly ours, the sea not ours to cross, the final island.
const CLOSED_LAND := "NOT YET REACHABLE. No border with a country wholly ours."
const CLOSED_SEA := "NOT YET REACHABLE. Requires sea lanes."
const CLOSED_FINAL := "NOT YET REACHABLE. Pending the full acquisition of Nordhal."
## The final island: reached only past all of Nordhal.
const FINAL := &"endmark"
## A country's outline while hovered and closed: the plain ink, faded.
const CLOSED_FADE := 0.55
## A country's token on the art, around its holding point (px).
const TOKEN := Rect2(-110, -110, 220, 220)
## The overlay art of a country that is ours.
const OWNED_ART := "res://assets/sprites/maps/world_owned/%s.svg"
## An owned country's overlay reaches FULL px from its holding point (all of the sheet).
const FULL := 5000.0

## The three looks of a country on the world sheet (share).
enum Share { NONE, SOME, ALL }

## The holding points by country id, and where each stands at rest (on the sheet).
var _sites: Dictionary[StringName, MapBuilding] = {}
var _rest: Dictionary[StringName, Vector3] = {}
var _moving: Dictionary[StringName, Tween] = {}
var _hot := &""
## What the sheet shows: the farms owned. When the save has it otherwise, it is printed again.
var _shown := -1
var _ink: Color
## The outline's own ink (the scene's), for a country that opens.
var _open_ink: Color

@onready var _refuse_sound: SoundCue = $Flash/Refuse


func _ready() -> void:
	super()
	for thing in $Things.get_children():
		var point := thing as MapBuilding
		if point != null and point.site != &"":
			_sites[point.site] = point
			_rest[point.site] = point.position
	_ink = _tag(HOME).get_theme_color(&"font_color")
	_open_ink = _outline(HOME).default_color
	refresh()


func _process(_delta: float) -> void:
	if SaveManager.save.farms_owned.size() != _shown:
		refresh()


## The ids of `country`'s farms in save.farms_owned: the home country's are "K-1".."K-8", any
## other's "<country>-1" and on (the sites of its own sheet).
static func farm_ids(country: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in COUNTRIES[country].farms:
		out.append("%s%d" % [Events.HOME_PREFIX if country == HOME else String(country) + "-", n + 1])
	return out


## The country farm `farm` lies in ("K-3": the home country; "ostrevia-1": ostrevia).
static func country_of(farm: String) -> StringName:
	return HOME if farm.begins_with(Events.HOME_PREFIX) else StringName(farm.left(farm.rfind("-")))


## How many of `country`'s farms `save` owns.
static func farms_of(save: SaveGame, country: StringName) -> int:
	var count := 0
	for farm in farm_ids(country):
		count += int(save.farms_owned.has(farm))
	return count


## Whether every farm of `country` is the company's.
static func owns_all(save: SaveGame, country: StringName) -> bool:
	return farms_of(save, country) == COUNTRIES[country].farms


## How much of `country` the world sheet paints ours: none of its farms (plain), some (patches of
## the cabbage pattern, the same however many) or all (wholly green). Never by percentage.
static func share(save: SaveGame, country: StringName) -> Share:
	var owned := farms_of(save, country)
	if owned == 0:
		return Share.NONE
	return Share.ALL if owned == COUNTRIES[country].farms else Share.SOME


## Why the farms of `country` cannot be attacked by `save` right now, as a war order's strip prints
## it; "" when they can. At home always. Abroad a country must border, by land, one in which every
## farm is ours; across a drawn sea lane only once SEA_CARD is stamped, with the same rule for the
## country at the lane's near end (NO_SEA_LANES: such a country is there, the card is not; the final
## island needs nothing but all of Nordhal and the lanes). NOT_ADJACENT: no neighbour is wholly ours.
static func reach(save: SaveGame, country: StringName) -> String:
	var ours := func(other: StringName) -> bool: return owns_all(save, other)
	var entry: Dictionary = COUNTRIES[country]
	if country == HOME or entry.land.any(ours):
		return ""
	if not entry.sea.any(ours):
		return NOT_ADJACENT
	return "" if save.stamped.has(SEA_CARD) else NO_SEA_LANES


## Why `country`'s own sheet cannot be opened from the world sheet for `save` (a CLOSED_ key), ""
## when it can: once any of its farms is ours, or its farms can be attacked (reach). The final
## island waits for Nordhal; a country the sea lanes would open, or that no land path from home
## reaches, waits for SEA_CARD; anything else for a neighbour wholly ours. Farm by farm the war
## order's strips (reach) still stand behind this.
static func closed(save: SaveGame, country: StringName) -> String:
	if farms_of(save, country) > 0 or reach(save, country) == "":
		return ""
	if country == FINAL and reach(save, country) != NO_SEA_LANES:  # Nordhal ours without the lanes: the sea is why.
		return CLOSED_FINAL
	if reach(save, country) == NO_SEA_LANES or not (save.stamped.has(SEA_CARD) or by_land(country)):
		return CLOSED_SEA
	return CLOSED_LAND


## Whether `country` can be walked to from home, border by border, without a sea lane.
static func by_land(country: StringName) -> bool:
	var seen: Array = [HOME]
	var i := 0
	while i < seen.size():
		for next: StringName in COUNTRIES[seen[i]].land:
			if not seen.has(next):
				seen.append(next)
		i += 1
	return seen.has(country)


## The line under a war order's strip (REASONS), translated.
static func reason(save: SaveGame, country: StringName) -> String:
	return TranslationServer.translate(REASONS.get(reach(save, country), ""))


## What starting the war on the next farm of `country` costs `save` (coins), {currency: amount} as
## UpgradeDesk.costs: its `wars` ladder, by how many of its farms are already ours (any of its
## farms can be the next). Empty while its farms are still bought (at home, the first
## GameEvents.HOME_SELLERS) or once all are ours.
static func war_price(save: SaveGame, country: StringName) -> Dictionary:
	var wars: Array = COUNTRIES[country].wars
	var fought: int = farms_of(save, country) - (COUNTRIES[country].farms - wars.size())
	return wars[fought] if fought >= 0 and fought < wars.size() else {}


## All of `country`'s farms join the farms `save` owns, unpaid (the tests, a debug start).
static func annex(save: SaveGame, country: StringName) -> void:
	for farm in farm_ids(country):
		if not save.farms_owned.has(farm):
			save.farms_owned.append(farm)


## The next farm `save` does not own, nearest country first (the home sites, then abroad), or "" when
## every farm is ours: what the debug key gives.
static func next_farm(save: SaveGame) -> String:
	var nearest := COUNTRIES.keys()
	nearest.sort_custom(func(a: StringName, b: StringName) -> bool: return COUNTRIES[a].rank < COUNTRIES[b].rank)
	for country: StringName in nearest:
		for farm in farm_ids(country):
			if not save.farms_owned.has(farm):
				return farm
	return ""


## What `country`'s count tag prints: its farms owned of its farms ("0/2", "5/8").
static func tag_text(save: SaveGame, country: StringName) -> String:
	return "%d/%d" % [farms_of(save, country), COUNTRIES[country].farms]


## The hint slip for `country` called this name: its farms, and that a click opens its sheet; while
## it is closed, only why. Never a price: nothing is bought on the world sheet.
static func hint_text(save: SaveGame, country: StringName, called: String) -> String:
	var why := closed(save, country)
	if why != "":
		return "%s. %s" % [called, TranslationServer.translate(why)]
	return TranslationServer.translate("%s. Farms: %d of %d. Click for its farm register.") % [called, farms_of(save, country), COUNTRIES[country].farms]


## Shows every country as the save has it (owned look, tag, pattern) and prints the page.
func refresh() -> void:
	var save: SaveGame = SaveManager.save
	_shown = save.farms_owned.size()
	for country in _sites:
		var ours := owns_all(save, country)
		_sites[country].owned = ours
		var tag := _tag(country)
		tag.text = tag_text(save, country)
		tag.add_theme_color_override(&"font_color", FarmRegister.OXBLOOD if ours else _ink)
		var layer := _layer(country)
		var shown := share(save, country)
		layer.visible = shown != Share.NONE
		if layer.visible and layer.texture == null:
			layer.texture = load(OWNED_ART % country)
		var ink := layer.material as ShaderMaterial
		ink.set_shader_parameter(&"reach", FULL)
		ink.set_shader_parameter(&"patchy", shown == Share.SOME)
		_outline(country).visible = country == _hot
	reprint()


func spot_at(pixel: Vector2) -> StringName:
	for country in _sites:
		if Geometry2D.is_point_in_polygon(pixel, _outline(country).points):
			return country
	return &""


## A country's token, its count tag and its name: the hint slip lies beside them, never over them.
func spot_box(spot: StringName) -> Rect2:
	if not _sites.has(spot):
		return Rect2()
	var box := Rect2(TOKEN.position + _pixel(spot), TOKEN.size).merge(lettering(_tag(spot)))
	for label in $Page/Sheet.get_children():
		if label is Label and label.text == _sites[spot].title:
			box = box.merge(lettering(label))
	return box


func hint(spot: StringName) -> String:
	return hint_text(SaveManager.save, spot, tr(_sites[spot].title)) if _sites.has(spot) else ""


func hover(spot: StringName) -> void:
	if not _sites.has(spot):
		spot = &""
	if spot == _hot:
		return
	for country: StringName in [_hot, spot]:
		if country == &"":
			continue
		_outline(country).visible = country == spot
		_outline(country).default_color = _open_ink if closed(SaveManager.save, country) == "" else Color(_ink, CLOSED_FADE)
		if thing_up(_index(country)):
			_move(country).tween_method(raise_thing.bind(_index(country)), _raised(country),
					FarmRegister.HOVER_SCALE if country == spot else 1.0, FarmRegister.HOVER_TIME)
	_hot = spot
	reprint()


## A click on a country opens its own sheet (MapTable hears `sheet_wanted`); on a closed one
## (closed) the refusal's clunk, and nothing opens.
func press(spot: StringName) -> void:
	if not _sites.has(spot):
		return
	if closed(SaveManager.save, spot) != "":
		_refuse_sound.cue(_sites[spot].global_position)
	else:
		sheet_wanted.emit(spot, &"")


## `country`'s holding point on the art (px).
func _pixel(country: StringName) -> Vector2:
	return Vector2(_rest[country].x + SIZE.x / 2.0, _rest[country].z) * PIXELS_PER_METRE


## A fresh tween for `country`'s token, in place of whatever moved it (back on its spot first).
func _move(country: StringName) -> Tween:
	if _moving.has(country):
		_moving[country].kill()
	_sites[country].position = _rest[country]
	_moving[country] = create_tween()
	return _moving[country]


func _index(country: StringName) -> int:
	return _standing.find(_sites[country])


## How far `country`'s token stands up right now (raise_thing's k).
func _raised(country: StringName) -> float:
	var i := _index(country)
	return _standing[i].scale.x / _stand_scale[i].x


func _tag(country: StringName) -> Label:
	return get_node("Page/Sheet/Count_%s" % country) as Label


func _layer(country: StringName) -> TextureRect:
	return get_node("Page/Sheet/Layers/%s" % country) as TextureRect


func _outline(country: StringName) -> Line2D:
	return get_node("Page/Sheet/Outlines/%s" % country) as Line2D
