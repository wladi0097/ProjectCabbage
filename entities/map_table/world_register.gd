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

## CHAPTER 4'S BANDIT CAMPS (BanditCamp): the camp standing is a red marker (`Camp`, its UNREST LEVEL
## printed beside it) at a point inside its country's outline drawn from its seed (camp_pixel). The
## country is only where it stands: the hint, the paper and the fight never name it. A click on the
## marker lays the RECOVERY OPERATION (`Deed`, FarmDeed lettered as &"camp") beside it, as a country's
## sheet lays a declaration of war: its fee, its level, ASSESSED RESISTANCE, the staff rows ([-] n [+])
## and the stamp box; the stamp declares it (BanditCamp.declare) and asks for the war sheet
## (sheet_wanted WAR, BanditCamp.SITE) with the staff sent (`committed`). A click anywhere else puts
## the paper away; a camp gone (the clock ran out) takes its paper with it.
const CAMP := &"camp"
## The marker takes the mouse this close to its pin (px).
const CAMP_HIT := 90.0
const CAMP_LIFT := 1.25
## The staff the last operation stamped here sent (unit id -> count), for the war sheet (MapTable).
var committed := {}
var _take := {}
var _deed_army := {}
var _deed_lacks := {}
var _deed_corner := Vector2.ZERO
## The camp whose paper lies on the sheet (0: none), and the camp the marker shows.
var _deed_camp := 0
var _shown_camp := -1
var _hot_box := &""
var _dealing: Tween

@onready var _camp: Node3D = $Camp
@onready var _camp_level: Label3D = $Camp/Level
@onready var _deed: FarmDeed = $Deed


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
	var save := SaveManager.save
	if save.farms_owned.size() != _shown:
		refresh()
	if save.bandit_camp != _shown_camp:
		_show_camp()
	if _deed_camp != 0 and (open < 1.0 or _deed_camp != save.bandit_camp):
		_drop_deed()  # Rolled up, or the camp is gone: its paper goes at once.
	elif _deed_camp != 0 and _dealing == null and (FarmRegister.lacks(save, BanditCamp.bill(save), _out()) != _deed_lacks or save.army != _deed_army):
		_print_deed()


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
	if _deed_camp != 0:
		var on := (lifted(pixel, FarmRegister.DEED_LIFT) - _deed_corner) / FarmDeed.WAR_SCALE
		if FarmDeed.on_paper(on):  # The paper covers what lies under it; only its boxes are spots.
			if _dealing != null:
				return &""
			if FarmRegister.has_staff(SaveManager.save):
				var staff := FarmDeed.staff_box_at(on, Depot.units(SaveManager.save))
				if staff != &"":
					return staff
			return FarmRegister.STAMP if FarmDeed.in_stamp_box(on) else &""
	if _camp.visible and pixel.distance_to(camp_pixel(SaveManager.save.bandit_camp)) <= CAMP_HIT:
		return CAMP
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
	if spot == CAMP and _deed_camp == 0:
		return camp_hint(SaveManager.save)
	return hint_text(SaveManager.save, spot, tr(_sites[spot].title)) if _sites.has(spot) and _deed_camp == 0 else ""


## The hint slip on the camp's marker: its level, what it is, and what a click does. Never its country.
static func camp_hint(save: SaveGame) -> String:
	return "%s. %s. %s" % [TranslationServer.translate(BanditCamp.LEVEL_TEXT) % BanditCamp.level(save),
			TranslationServer.translate(BanditCamp.NAME).capitalize(), TranslationServer.translate("Click for the recovery operation.")]


func hover(spot: StringName) -> void:
	var box := spot if spot == FarmRegister.STAMP or _staff_spot(spot) else &""
	if box != _hot_box:
		_hot_box = box
		_deed.hot(box)
	var grow := CAMP_LIFT if spot == CAMP else 1.0
	if not is_equal_approx(_camp.scale.x, grow):
		create_tween().tween_property(_camp, "scale", Vector3.ONE * grow, FarmRegister.HOVER_TIME)
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
	if _dealing != null:
		return
	if spot == FarmRegister.STAMP and _deed_camp != 0:
		_stamp_deed()
		return
	if _staff_spot(spot) and _deed_camp != 0:
		_choose(spot)
		return
	if spot == CAMP:
		_lay_out()
		return
	if _deed_camp != 0:
		_put_away()  # A click anywhere else puts the paper away.
		return
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


## Where camp `camp` (its seed) stands on the art (px): a point inside its country's outline, drawn
## from the seed, so it stays put across reloads; its country's holding point if none is found.
func camp_pixel(camp: int) -> Vector2:
	var country := BanditCamp.country_of(camp)
	var ring := _outline(country).points
	var box := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		box = box.expand(p)
	var draw := RandomNumberGenerator.new()
	draw.seed = camp
	for i in 64:
		var p := box.position + Vector2(draw.randf(), draw.randf()) * box.size
		if Geometry2D.is_point_in_polygon(p, ring) and _near_border(p, ring) > CAMP_HIT:
			return p
	return _pixel(country)


## How far `p` lies from the nearest corner of `ring` (px): a camp's pin keeps off the coast.
static func _near_border(p: Vector2, ring: PackedVector2Array) -> float:
	var best := INF
	for q in ring:
		best = minf(best, p.distance_to(q))
	return best


## The marker as the save has it: shown on its camp's point with its level, or hidden.
func _show_camp() -> void:
	var save := SaveManager.save
	_shown_camp = save.bandit_camp
	_camp.visible = BanditCamp.is_open(save)
	if _camp.visible:
		var at := camp_pixel(save.bandit_camp)
		_camp.position = Vector3(at.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0, at.y / PIXELS_PER_METRE)
		_camp_level.text = tr(BanditCamp.LEVEL_TEXT) % BanditCamp.level(save)
	reprint()


## Sheet pixel `pixel` moved to the pixel the mouse is on of a paper lying `height` m over the sheet
## (FarmRegister.lifted: the camera looks down at an angle).
func lifted(pixel: Vector2, height: float) -> Vector2:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return pixel
	var screen := camera.unproject_position(point_at(pixel))
	var up := global_basis.y
	var hit: Variant = Plane(up.normalized(), point_at(pixel) + up * height).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return pixel_at(hit) if hit != null else pixel


## The operation's paper is out or being stamped: the table does not roll the sheet up under it.
func busy() -> bool:
	return _dealing != null


## Whether `spot` is one of the paper's [-] / [+] boxes.
static func _staff_spot(spot: StringName) -> bool:
	return String(spot).begins_with(FarmDeed.STAFF_LESS) or String(spot).begins_with(FarmDeed.STAFF_MORE)


## Lays the RECOVERY OPERATION beside the camp's marker: it slides in from beyond the sheet's edge.
func _lay_out() -> void:
	var save := SaveManager.save
	_deed_camp = save.bandit_camp
	_deed.scale = Vector3.ONE * FarmDeed.WAR_SCALE
	var at := camp_pixel(_deed_camp)
	_deed_corner = FarmRegister.deed_corner(at, FarmDeed.WAR_SCALE)
	_take = save.army.duplicate()  # Everybody ready goes, unless told otherwise.
	_print_deed()
	var to := _deed_at()
	_deed.slide(to + Vector3.RIGHT * FarmRegister.deed_side(at, FarmDeed.WAR_SCALE) * FarmRegister.DEED_FROM / PIXELS_PER_METRE, to, FarmRegister.DEED_SLIDE_TIME)


## Prints the paper as the save has it: the camp, its level and briefing with what it pays, the fee
## and what is short of it, the resistance, the staff rows.
func _print_deed() -> void:
	var save := SaveManager.save
	var bill := BanditCamp.bill(save)
	_deed_lacks = FarmRegister.lacks(save, bill, _out())
	_deed.fill(tr(BanditCamp.NAME), BanditCamp.SITE, bill, _deed_lacks)
	_deed.letter(&"camp")
	var paid := BanditCamp.reward(save)
	var briefing := tr(BanditCamp.BRIEFING) + " " + tr("On recovery: %s, %s Findings, %s cabbages.") % [
			"$" + Num.text(paid.coins), Num.text(paid.findings), Num.text(paid.stock)]
	_deed.print_site({site_name = tr(BanditCamp.LEVEL_TEXT) % BanditCamp.level(save), briefing = briefing})
	_deed_army = save.army.duplicate()
	var rows := []
	for unit in Depot.units(save):
		var have := int(save.army.get(unit, 0))
		_take[unit] = clampi(int(_take.get(unit, have)), 0, have)
		rows.append({unit = unit, name = tr(DepotSheet.NAMES[unit]), have = have, take = _take[unit]})
	_deed.print_staff(rows)
	_deed.print_resistance(BanditCamp.difficulty(save, WarRules.army_cap(save)))
	_deed.hot(_hot_box)


## A click on a [-] or [+]: one figure of that type fewer or more, as far as it goes.
func _choose(spot: StringName) -> void:
	var more := String(spot).begins_with(FarmDeed.STAFF_MORE)
	var unit := String(spot).trim_prefix(FarmDeed.STAFF_MORE if more else FarmDeed.STAFF_LESS)
	var to := clampi(int(_take.get(unit, 0)) + (1 if more else -1), 0, int(SaveManager.save.army.get(unit, 0)))
	if to == int(_take.get(unit, 0)):
		return
	_take[unit] = to
	_deed.count_tick()
	_print_deed()


## The stamp: the operation is declared (BanditCamp.declare: the fee paid, the staff sent) and the
## war sheet asked for; refused (the clunk, what is short blinks), nothing changes.
func _stamp_deed() -> void:
	var save := SaveManager.save
	var chosen := {}
	for unit in Depot.units(save):
		if int(_take.get(unit, 0)) > 0:
			chosen[unit] = int(_take[unit])
	var fee := save.bandit_fee
	if not BanditCamp.declare(save, chosen, _out()):
		_deed.blink(chosen.is_empty())
		return
	committed = chosen
	SaveManager.log_event("camp_declared", str(BanditCamp.level(save)), fee, "coins")
	SaveManager.autosave()
	_deed_army = save.army.duplicate()  # The rows keep what was sent until it leaves.
	_deed.strike(FarmRegister.STAMP_DROP_TIME)
	_dealing = create_tween()
	_dealing.tween_interval(FarmRegister.STAMP_DROP_TIME)
	_dealing.tween_callback(_deed.imprint)
	_dealing.tween_interval(FarmRegister.HIT_PAUSE)
	_dealing.tween_callback(_deed.lift_stamp.bind(FarmRegister.STAMP_LIFT_TIME))
	_dealing.tween_interval(FarmRegister.WAR_AFTER)
	_dealing.tween_callback(_go_to_war)


func _go_to_war() -> void:
	_dealing = null
	_deed_camp = 0
	_deed.hide()
	sheet_wanted.emit(&"war", BanditCamp.SITE)


## The paper slides off the sheet the way it came, unstamped.
func _put_away() -> void:
	var from := _deed_at()
	_deed.slide(from, from + Vector3.RIGHT * FarmRegister.deed_side(camp_pixel(_deed_camp), FarmDeed.WAR_SCALE) * FarmRegister.DEED_FROM / PIXELS_PER_METRE, FarmRegister.DEED_SLIDE_TIME, true)
	_deed_camp = 0


## The paper is gone at once (the sheet is rolled up under it, or the camp went).
func _drop_deed() -> void:
	if _dealing != null:
		_dealing.kill()
		_dealing = null
	_deed.hide()
	_deed_camp = 0


## Where the laid-out paper's origin (the middle of its top edge) lies on the sheet.
func _deed_at() -> Vector3:
	return Vector3((_deed_corner.x + FarmDeed.SIZE.x * FarmDeed.PIXELS_PER_METRE * FarmDeed.WAR_SCALE / 2.0) / PIXELS_PER_METRE - SIZE.x / 2.0,
			FarmRegister.DEED_LIFT, _deed_corner.y / PIXELS_PER_METRE)


## The stock cabbages out of the chute: they cannot pay (UpgradeDesk.units_out).
func _out() -> Vector2i:
	return UpgradeDesk.units_out(get_tree().get_nodes_in_group(&"cabbages")) if is_inside_tree() else Vector2i.ZERO
