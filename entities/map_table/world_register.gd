extends MapSheet
## The world sheet: the nine countries, taken here. Each country has one holding point, a MapBuilding
## under `Things` (its `site` is the country's id, its `title` the name), a click outline
## `Page/Sheet/Outlines/<id>` (a Line2D, shown while a country that can be taken is hovered), its
## cabbage-pattern overlay `Page/Sheet/Layers/<id>` (its art is loaded when the country is ours: each
## is a 3200 x 1800 texture) and a count tag `Page/Sheet/Count_<id>` ("0/2": farms owned of its
## farms). tools/make_map_sheets.py writes all of them from reports/maps/labels.json; COUNTRIES
## below is the same data as the rules need it (a test holds the two together).
## The rules: the home country (HOME) is the company's from the start, however many of its farms are
## bought (those are the country sheet's business, FarmRegister). A country can be taken when it
## borders one that is ours: by land, or across a drawn sea lane once the card SEA_CARD is stamped
## (reach). The final island (LAST) is taken last of all. Taking one costs coins and cabbages from
## stock (COUNTRIES: nearer is cheaper) and brings all its farms (farm_ids) into save.farms_owned.
## At the map: a country is hovered (the hint slip names it, its farms and its price or why it cannot
## be taken; one that can be taken shows its outline and its token lifts) and clicked: its
## ANNEXATION ORDER (`Deed`, the farm deed's paper lettered as FarmDeed.FORMS "annexation") slides in
## beside its holding point. One that cannot be taken wears a strip (NOT ADJACENT, NO SEA LANES, NOT
## YET), a line why and no stamp box. A click on the stamp box takes the country, in FarmRegister's
## order and timings (the stamp, the hit pause, the token's swap and jump with a flash, the tag, the
## Field Line's lamps held until then, the order rolling away); the pattern spreads from the holding
## point over the whole country in SPREAD_TIME. Not paid for: the stamp stays up, the token shakes
## and what is short flashes.
## THE FIGHT PLUGS IN AT take() (armies, the fighting maps, the boss fight on the island: not
## designed yet): today the stamp and the payment take the country at once.
## No class_name: whoever needs the rules preloads this script (as props/map_tally.gd), so nothing
## waits for the editor to register a new global class.
## ponytail: the order's choreography is FarmRegister's, written out again here (that sheet's script
## was being reworked for the negotiation); fold both into one helper when they have settled.

const Events := preload("res://globalScripts/game_events.gd")

## The head office's country: ours from the start. And the final island: taken last of all.
const HOME := &"kohlmark"
const LAST := &"endmark"
## The desk card (UpgradeDesk) that opens the drawn sea lanes.
const SEA_CARD := "sea_lanes"
## Every country: how many farms it holds, how far it is from home (`rank`, reports/maps/labels.json
## `distance_rank`), what taking it costs in coins and in cabbages from stock, the countries it
## borders by `land` and the ones across a drawn `sea` lane.
## PROVISIONAL prices (paced in tools/pace.py: `python tools/pace.py ch3`), until the user has seen
## them: a nearer country costs less than a farther one, in both currencies.
const COUNTRIES: Dictionary = {
	&"kohlmark": {farms = 8, rank = 0, coins = 0, stock = 0, land = [&"ostrevia", &"sulvania", &"veldmark"], sea = []},
	&"ostrevia": {farms = 2, rank = 1, coins = 9000000, stock = 12000, land = [&"kohlmark", &"veldmark"], sea = []},
	&"veldmark": {farms = 2, rank = 2, coins = 10000000, stock = 12500, land = [&"kohlmark", &"ostrevia", &"sulvania"], sea = []},
	&"sulvania": {farms = 3, rank = 3, coins = 12000000, stock = 13000, land = [&"kohlmark", &"veldmark"], sea = [&"grauland", &"lower_provinces"]},
	&"grauland": {farms = 2, rank = 4, coins = 13000000, stock = 13500, land = [&"morrow", &"nordhal"], sea = [&"sulvania"]},
	&"lower_provinces": {farms = 2, rank = 5, coins = 14000000, stock = 14000, land = [], sea = [&"morrow", &"sulvania"]},
	&"morrow": {farms = 2, rank = 6, coins = 15000000, stock = 14200, land = [&"grauland", &"nordhal"], sea = [&"lower_provinces"]},
	&"nordhal": {farms = 2, rank = 7, coins = 15500000, stock = 14400, land = [&"grauland", &"morrow"], sea = [&"endmark"]},
	&"endmark": {farms = 1, rank = 8, coins = 16000000, stock = 14500, land = [], sea = [&"nordhal"]},
}
## Why a country cannot be taken, as its order's strip prints it (translation keys).
const NOT_ADJACENT := "NOT ADJACENT"
const NO_SEA_LANES := "NO SEA LANES"
const NOT_YET := "NOT YET"
## And the line under it (translation keys).
const REASONS := {
	NOT_ADJACENT: "We do not border this country. Yet.",
	NO_SEA_LANES: "The sea is not ours to cross yet.",
	NOT_YET: "Head office has scheduled the island for last.",
}
## The hint slip's corner on the art (px): the sea bottom left, clear of every country (hint_pixel).
const SEA_HINT_PIXEL := Vector2(110.0, 1530.0)
## The overlay art of a country that is ours.
const OWNED_ART := "res://assets/sprites/maps/world_owned/%s.svg"
## The pattern spreads over a taken country in this many seconds; an owned country's overlay
## reaches FULL px from its holding point (all of the sheet).
const SPREAD_TIME := 1.4
const FULL := 5000.0

## The holding points by country id, and where each stands at rest (on the sheet).
var _sites: Dictionary[StringName, MapBuilding] = {}
var _rest: Dictionary[StringName, Vector3] = {}
var _moving: Dictionary[StringName, Tween] = {}
var _flash_tween: Tween
var _hot := &""
## What the sheet shows: the farms owned and the cards stamped (the sea lanes). When the save has it
## otherwise, it is printed again.
var _shown := Vector2i(-1, -1)
var _ink: Color
## The country whose order lies on the sheet (&"": none), the order's top left corner on the art
## (px) and what it marks as short.
var _deed_site := &""
var _deed_corner := Vector2.ZERO
var _deed_lacks := {}
## The taking playing out (null: none): no click is taken until its order is gone.
var _dealing: Tween
## The country just paid for whose token still waits for the stamp to land, and the one whose
## pattern is spreading right now.
var _pending := &""
var _spreading := &""
var _spread_tween: Tween
var _stamp_hot := false
var _tucked: Array[StringName] = []

@onready var _deed: FarmDeed = $Deed
@onready var _flash: GeometryInstance3D = $Flash
@onready var _acquire_sound: SoundCue = $Flash/Acquire
@onready var _refuse_sound: SoundCue = $Flash/Refuse


func _ready() -> void:
	super()
	for thing in $Things.get_children():
		var point := thing as MapBuilding
		if point != null and point.site != &"":
			_sites[point.site] = point
			_rest[point.site] = point.position
	_ink = _tag(HOME).get_theme_color(&"font_color")
	refresh()


func _process(_delta: float) -> void:
	if _state(SaveManager.save) != _shown:
		refresh()
	if _deed_site == &"":
		return
	if open < 1.0:
		_drop_deed()  # The sheet is being rolled up: its order goes with it, at once.
	elif _dealing == null and short(SaveManager.save, _deed_site, _out()) != _deed_lacks:
		_print_deed()  # What is short changed while it lies there.


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()  # The order's wording changed.


func _exit_tree() -> void:
	if _dealing != null:
		FarmRegister.lamp_held = false  # A taking cut off (the scene left) holds no lamp.


## The ids of `country`'s farms in save.farms_owned: the home country's are the country sheet's
## sites ("K-1".."K-8"), any other's "<country>-1" and on.
static func farm_ids(country: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in COUNTRIES[country].farms:
		out.append("%s%d" % [Events.HOME_PREFIX if country == HOME else String(country) + "-", n + 1])
	return out


## Whether `country` is the company's: the home country always, any other once it was taken.
static func owns(save: SaveGame, country: StringName) -> bool:
	return country == HOME or save.farms_owned.has(farm_ids(country)[0])


## How many of `country`'s farms `save` owns (the home country's are bought one by one).
static func farms_of(save: SaveGame, country: StringName) -> int:
	var count := 0
	for farm in farm_ids(country):
		count += int(save.farms_owned.has(farm))
	return count


## Why `country` cannot be taken by `save` right now, as its order's strip prints it; "" when it can
## (or is ours already). NOT_ADJACENT: no country of ours borders it, by land or across a lane.
## NO_SEA_LANES: one does, but only across the sea, and SEA_CARD is not stamped. NOT_YET: the final
## island while any other country is not ours.
static func reach(save: SaveGame, country: StringName) -> String:
	if owns(save, country):
		return ""
	var ours := func(other: StringName) -> bool: return owns(save, other)
	var entry: Dictionary = COUNTRIES[country]
	if not entry.land.any(ours):
		if not entry.sea.any(ours):
			return NOT_ADJACENT
		if not save.stamped.has(SEA_CARD):
			return NO_SEA_LANES
	if country == LAST and COUNTRIES.keys().any(func(other: StringName) -> bool: return other != LAST and not owns(save, other)):
		return NOT_YET
	return ""


## The line under an order's strip (REASONS), translated.
static func reason(save: SaveGame, country: StringName) -> String:
	return TranslationServer.translate(REASONS.get(reach(save, country), ""))


## Whether `save` may take `country` now: not ours, and within reach.
static func takeable(save: SaveGame, country: StringName) -> bool:
	return not owns(save, country) and reach(save, country) == ""


## What taking `country` costs, {currency: amount} as UpgradeDesk.costs.
static func price(country: StringName) -> Dictionary:
	return {coins = COUNTRIES[country].coins, stock = COUNTRIES[country].stock}


## What `save` lacks of `country`'s price, {currency: amount}; empty when it can pay, or when the
## country cannot be taken anyway (`out`: UpgradeDesk.units_out).
static func short(save: SaveGame, country: StringName, out := Vector2i.ZERO) -> Dictionary:
	var lacks := {}
	var bill := price(country) if takeable(save, country) else {}
	for paid_in: String in bill:
		if UpgradeDesk.spendable(save, paid_in, out) < bill[paid_in]:
			lacks[paid_in] = bill[paid_in] - UpgradeDesk.spendable(save, paid_in, out)
	return lacks


## Takes `country` for `save` if it is within reach and paid for: the price is taken and all its
## farms join the farms owned. Whether it was taken; refused, nothing changes.
## THE FIGHT WILL REPLACE THE PAYMENT HERE (not designed yet).
static func take(save: SaveGame, country: StringName, out := Vector2i.ZERO) -> bool:
	var bill := price(country)
	if not takeable(save, country) or not UpgradeDesk.affords(save, bill, out):
		return false
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
	annex(save, country)
	return true


## All of `country`'s farms join the farms `save` owns, unpaid (take; the debug key).
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


## The hint slip for `country` called this name: that it is ours, its farms and its price (and what
## is short of it), or why it cannot be taken.
static func hint_text(save: SaveGame, country: StringName, called: String, out := Vector2i.ZERO) -> String:
	if owns(save, country):
		return TranslationServer.translate("%s. Company property.") % called
	var farms: int = COUNTRIES[country].farms
	if reach(save, country) != "":
		return TranslationServer.translate("%s. Farms: %d. %s") % [called, farms, reason(save, country)]
	var lacks := short(save, country, out)
	if lacks.is_empty():
		return TranslationServer.translate("%s. Farms: %d. Cost: %s. Click for the order.") % [called, farms, FarmRegister.words(price(country))]
	return TranslationServer.translate("%s. Farms: %d. Cost: %s. Short: %s.") % [called, farms, FarmRegister.words(price(country)), FarmRegister.words(lacks)]


static func _state(save: SaveGame) -> Vector2i:
	return Vector2i(save.farms_owned.size(), save.stamped.size())


## Shows every country as the save has it (owned look, tag, pattern), without any moment, and prints
## the page.
func refresh() -> void:
	var save := SaveManager.save
	_shown = _state(save)
	for country in _sites:
		var ours := owns(save, country) and country != _pending  # Paid for: ours when the stamp lands.
		_sites[country].owned = ours
		var tag := _tag(country)
		tag.text = tag_text(save, country) if country != _pending else tag.text
		tag.add_theme_color_override(&"font_color", FarmRegister.OXBLOOD if ours and country != HOME else _ink)
		var layer := _layer(country)
		layer.visible = ours
		if ours and layer.texture == null:
			layer.texture = load(OWNED_ART % country)
		if ours and country != _spreading and layer.material != null:
			(layer.material as ShaderMaterial).set_shader_parameter(&"reach", FULL)
		_outline(country).visible = country == _hot and takeable(save, country)
	reprint()
	if _deed_site != &"" and _dealing == null:
		_print_deed()  # Whether it can be taken, or what is short, may have changed.


func spot_at(pixel: Vector2) -> StringName:
	if _deed_site != &"":
		var on := pixel - _deed_corner
		if Rect2(Vector2.ZERO, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE).has_point(on):
			# The order covers what lies under it; only its stamp box is a spot.
			return FarmRegister.STAMP if _dealing == null and not _deed.bill.is_empty() and FarmDeed.in_stamp_box(on) else &""
	for country in _sites:
		if Geometry2D.is_point_in_polygon(pixel, _outline(country).points):
			return country
	return &""


func hint_pixel() -> Vector2:
	return SEA_HINT_PIXEL


## Nothing while an order lies on the sheet: it says all of it, and the slip would lie on it.
func hint(spot: StringName) -> String:
	if not _sites.has(spot) or _deed_site != &"":
		return ""
	return hint_text(SaveManager.save, spot, tr(_sites[spot].title), _out())


func hover(spot: StringName) -> void:
	if (spot == FarmRegister.STAMP) != _stamp_hot and _deed_site != &"":
		_stamp_hot = spot == FarmRegister.STAMP
		_deed.hot(FarmRegister.STAMP if _stamp_hot else &"")
	if not _sites.has(spot):
		spot = &""
	if spot == _hot:
		return
	var save := SaveManager.save
	for country: StringName in [_hot, spot]:
		if country == &"":
			continue
		var lifted := country == spot and takeable(save, country)
		_outline(country).visible = lifted
		if thing_up(_index(country)):
			_move(country).tween_method(raise_thing.bind(_index(country)), _raised(country),
					FarmRegister.HOVER_SCALE if lifted else 1.0, FarmRegister.HOVER_TIME)
	_hot = spot
	reprint()


## A click on `spot` (&"": on nothing): the stamp box takes the order's country, a country not ours
## lays out its order, anything else puts the order away. Nothing while a taking plays out.
func press(spot: StringName) -> void:
	if _dealing != null:
		return
	if spot == FarmRegister.STAMP and _deed_site != &"":
		_stamp_deed()
	elif _sites.has(spot) and spot != _deed_site and not owns(SaveManager.save, spot):
		_lay_out(spot)
	else:
		_put_away()


## A taking plays out: the table does not roll the sheet up under it (MapTable.show_sheet).
func busy() -> bool:
	return _dealing != null


## The country whose order lies on the sheet, or &"".
func deed_site() -> StringName:
	return _deed_site


## Lays `spot`'s order beside its holding point: it slides in from beyond the sheet's edge on its side.
func _lay_out(spot: StringName) -> void:
	_deed_site = spot
	_deed_corner = FarmRegister.deed_corner(_pixel(spot))
	_stamp_hot = false
	_print_deed()
	_uncover(0.0)
	var paper := Rect2(_deed_corner, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE).grow(FarmRegister.COVER)
	for country in _sites:
		if country != spot and paper.has_point(_pixel(country)):
			_tucked.append(country)
			_move(country).tween_method(raise_thing.bind(_index(country)), 1.0, 0.0, FarmRegister.TUCK_TIME)
	var to := _deed_at()
	_deed.slide(to + _off(spot), to, FarmRegister.DEED_SLIDE_TIME)


## Prints the laid-out order as the save has it: the country's price and what is short of it, or the
## strip and why it cannot be taken.
func _print_deed() -> void:
	var save := SaveManager.save
	var bar := reach(save, _deed_site)
	_deed_lacks = short(save, _deed_site, _out())
	_deed.fill(tr(_sites[_deed_site].title), _deed_site, price(_deed_site) if bar == "" else {}, _deed_lacks, reason(save, _deed_site))
	_deed.letter(&"annexation", bar, tr("FARMS x%d") % COUNTRIES[_deed_site].farms)
	_deed.hot(FarmRegister.STAMP if _stamp_hot else &"")


## The order slides off the sheet the way it came, unstamped.
func _put_away() -> void:
	if _deed_site == &"":
		return
	var from := _deed_at()
	_deed.slide(from, from + _off(_deed_site), FarmRegister.DEED_SLIDE_TIME, true)
	_deed_site = &""
	_uncover(FarmRegister.DEED_SLIDE_TIME * 0.5)


## The tokens tucked away under the order stand up again, `after` s from now.
func _uncover(after: float) -> void:
	for country in _tucked:
		var tween := _move(country)
		tween.tween_interval(after)
		tween.tween_method(raise_thing.bind(_index(country)), 0.0, 1.0, FarmRegister.TUCK_TIME)
	_tucked.clear()


## The order is gone at once, whatever was playing (the sheet is rolled up under it).
func _drop_deed() -> void:
	_deed.hide()
	_deed_site = &""
	_tucked.clear()  # The table tucks and stands everything on a rolled sheet itself.
	refresh()


## Where the laid-out order's origin (the middle of its top edge) lies on the sheet.
func _deed_at() -> Vector3:
	return Vector3((_deed_corner.x + FarmDeed.SIZE.x * FarmDeed.PIXELS_PER_METRE / 2.0) / PIXELS_PER_METRE - SIZE.x / 2.0,
			FarmRegister.DEED_LIFT, _deed_corner.y / PIXELS_PER_METRE)


## From its place to beyond the sheet's edge on `spot`'s side: where its order comes from and goes.
func _off(spot: StringName) -> Vector3:
	return Vector3.RIGHT * FarmRegister.deed_side(_pixel(spot)) * FarmRegister.DEED_FROM / PIXELS_PER_METRE


## A click on the stamp box: the country is taken if it is paid for (the rest plays out from here,
## FarmRegister's timings), else the refusal and nothing taken.
func _stamp_deed() -> void:
	var spot := _deed_site
	if not take(SaveManager.save, spot, _out()):
		_refuse(spot)
		_deed.blink()
		return
	for paid_in: String in price(spot):  # One log line per currency, as the desk's cards.
		SaveManager.log_event("annexation", spot, price(spot)[paid_in], paid_in)
	SaveManager.autosave()
	_pending = spot
	FarmRegister.lamp_held = true
	BossReport.hold = FarmRegister.deed_gone_after() + FarmRegister.PAPER_AFTER
	_deed.strike(FarmRegister.STAMP_DROP_TIME)
	_dealing = create_tween()
	_dealing.tween_interval(FarmRegister.STAMP_DROP_TIME)
	_dealing.tween_callback(_deed.imprint)
	_dealing.tween_interval(FarmRegister.HIT_PAUSE)
	_dealing.tween_callback(_acquire.bind(spot))
	_dealing.tween_interval(FarmRegister.LAMP_AFTER)
	_dealing.tween_callback(func() -> void: FarmRegister.lamp_held = false)
	_dealing.tween_interval(FarmRegister.DEED_LEAVE_AFTER)
	_dealing.tween_callback(_deed.roll_away.bind(_deed_at() + _off(spot), FarmRegister.DEED_ROLL_TIME, FarmRegister.DEED_DROP_TIME))
	_dealing.tween_interval(FarmRegister.DEED_ROLL_TIME + FarmRegister.DEED_DROP_TIME)
	_dealing.tween_callback(_deed_gone)


func _deed_gone() -> void:
	_dealing = null
	_deed_site = &""
	_uncover(0.0)


## The taking's moment on `spot`, paid for and stamped: the stamp lifts, the owned look and the tag
## at once, the token jumps, the flash spreads and fades, the pattern spreads over the country.
func _acquire(spot: StringName) -> void:
	_pending = &""
	_spreading = spot
	_deed.lift_stamp(FarmRegister.STAMP_LIFT_TIME)
	_spread(0.0, spot)
	refresh()
	if _spread_tween != null:
		_spread_tween.kill()
	_spread_tween = create_tween()
	_spread_tween.tween_method(_spread.bind(spot), 0.0, 1.0, SPREAD_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_acquire_sound.cue(_sites[spot].global_position)
	var tween := _move(spot)
	tween.tween_method(raise_thing.bind(_index(spot)), FarmRegister.JUMP_SCALE, 1.0, FarmRegister.JUMP_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.position = _rest[spot] + Vector3.UP * 0.002
	_flash.show()
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash, "scale", Vector3.ONE * FarmRegister.FLASH_TO, FarmRegister.FLASH_TIME) \
			.from(Vector3.ONE * FarmRegister.FLASH_FROM).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash, "transparency", 1.0, FarmRegister.FLASH_TIME).from(0.15)
	_flash_tween.chain().tween_callback(_flash.hide)


## `country`'s overlay shows the pattern `k` of the way out from its holding point (1: all of it).
func _spread(k: float, country: StringName) -> void:
	(_layer(country).material as ShaderMaterial).set_shader_parameter(&"reach", FULL if k >= 1.0 else k * span(country))
	if k >= 1.0 and _spreading == country:
		_spreading = &""
	reprint()


## How far `country`'s land reaches from its holding point (px): its outline's farthest corner, and
## a little more for the spreading edge's wobble.
func span(country: StringName) -> float:
	var far := 0.0
	for corner in _outline(country).points:
		far = maxf(far, corner.distance_to(_pixel(country)))
	return far * 1.15


## `country`'s holding point on the art (px).
func _pixel(country: StringName) -> Vector2:
	return Vector2(_rest[country].x + SIZE.x / 2.0, _rest[country].z) * PIXELS_PER_METRE


## The refusal's moment on `spot`: its token shakes from side to side, nothing else changes.
func _refuse(spot: StringName) -> void:
	_refuse_sound.cue(_sites[spot].global_position)
	var tween := _move(spot)
	for side: float in [1.0, -1.0, 0.6, -0.6, 0.0]:
		tween.tween_property(_sites[spot], "position", _rest[spot] + Vector3.RIGHT * FarmRegister.SHAKE * side, FarmRegister.SHAKE_TIME / 5.0)


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


## The stock cabbages out of the chute: they cannot pay (UpgradeDesk.units_out).
func _out() -> Vector2i:
	return UpgradeDesk.units_out(get_tree().get_nodes_in_group(&"cabbages"))
