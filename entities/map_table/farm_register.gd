class_name FarmRegister
extends MapSheet
## A country's own sheet (the national farm register): its farm sites, taken here one at a time.
## Every country has one (entities/map_table/countries/<id>.tscn, `id` is the country's,
## tools/make_map_sheets.py writes them); the home country's (WorldRegister.HOME) is the first and
## at the start the only one. Each site is a MapBuilding under `Things` (its `site` id and name) and
## a price tag `Page/Sheet/Price_<id>` printed on the paper. At the map a site is hovered (it lifts,
## the hint slip names it and its price) and clicked (MapTable: spot_at, hover, press, hint). A
## click takes nothing: it lays the farm's paper (`Deed`, FarmDeed) on the sheet beside it
## (deed_corner: never on the farm itself), with its name, its price and a stamp box. A click
## anywhere else, or on the same farm again, slides it away.
## AT HOME the first GameEvents.HOME_SELLERS farms are bought. The paper is a deed of transfer and
## a click on its stamp box (the spot STAMP) is the purchase:
## - Paid for: the price in coins is taken at once (UpgradeDesk.pay, as the desk's cards) and the site joins save.farms_owned; then, in order (the constants below): the
##   stamp comes down on the deed and stays for a hit pause; the token takes its owned look and jumps
##   with a flash, its tag flips to ACQUIRED and the cabbage pattern spreads over its parcel; the
##   Field Line lights the farm's lamp (lamp_held keeps it dark until then); the deed rolls itself up and drops off the map. No click is
##   taken until it is gone, and the boss's paper waits PAPER_AFTER longer.
## - Not paid for: nothing is taken, the stamp stays up, the token shakes its head and what is short
##   flashes on the deed (it is marked there all along).
## The first farm is sold freely. The next four print NOT FOR SALE until their card is stamped
## (GATES: NEGOTIATION for the 2nd to 4th, BRIBERY for the 5th); then each can be haggled over on
## its deed before it is stamped (the negotiation, below). Any site can be the next one bought: the
## price goes by how many farms are owned (PRICES), times the site's own worth (WORTH: land by the
## head office or a big parcel dearer, far out cheaper).
## WAR takes what nobody sells, one farm at a time: at home the last three, abroad every farm
## (nothing is bought or haggled over abroad). Until the card WAR_CARD is stamped such a farm prints
## NOT FOR SALE and its paper wears that strip. With it (war_ready) the paper is a DECLARATION OF
## WAR (FarmDeed.FORMS): the war's price in coins only (war_bill: WorldRegister.war_price), the
## scouting view of the farm's fighting map (WarMap.scene_for) and one row per unit type the depot deals in with the
## figures ready (save.army) and how many go ([-] n [+]: the spots FarmDeed.STAFF_LESS/MORE; all of
## them at first). Its stamp declares the war (declare): the coins are paid, the chosen figures leave
## save.army (`committed` keeps them for the war sheet) and the sheet asks the table for the war
## sheet of that farm (`sheet_wanted`; MapTable hands them on: WarSheet.begin), where the war is won
## or lost. Refused (the clunk, what is short blinks) short of coins or with nobody chosen; with
## nobody trained at all (has_staff) the paper prints the NO STAFF notice in place of the rows. It
## lies FarmDeed.WAR_SCALE times a deed's size (`_deed_scale`). A farm
## that cannot be attacked yet
## (WorldRegister.reach: no neighbouring country is wholly ours, or the sea is not open) gets the
## order with a strip saying why and no stamp box. Back from a war won, the table has the sheet
## play the farm's moment (expect, celebrate): the token's swap, the tag, the pattern, the lamp.
## The land (`Page/Sheet/Layers/Parcels`, assets/shaders/farm_parcels.gdshader): the art prints the
## whole country in the cabbage pattern; the layer greys what is not the company's. The country's
## land is split among its sites (and the head office, at home: company land from the start), each
## parcel the land its site reaches first walking over land (tools/bake_parcels.gd bakes it once into
## the material's `parcels` texture, with how far each pixel lies from its site). A farm taken spreads
## the pattern from its token over its parcel (`progress`); with every farm ours the whole country
## shows it (as its overlay on the world sheet does). Owned parcels show from the save.
## Owned sites show as owned from the save, without the moment (also farms from the debug key).
##
## The negotiation (decided with the user 2026-11-14; its numbers are provisional, paced in
## tools/pace.py: `python tools/pace.py haggle`). The deed of a farm behind a card shows the owner's
## asking price (asking: PRICES times WORTH) and takes up to ROUNDS offers before it
## is stamped; it may be stamped at any time at the price it then shows. An offer is cabbages from
## stock, in bundles of `bundle` (HAGGLES), laid on the letter and sent; for the farm behind BRIBERY
## it is coins in an envelope (tender). The owner (OWNERS names him) has a number in mind (wanted:
## drawn per site between HAGGLES' `low` and `high`, dearer farms higher and wider, times the site's
## WORTH: a dear site is harder to talk down; never shown, and fixed by the save's `created`, so a
## reload cannot change it). Every owner keeps his own negotiation (haggle: the price his offers
## left, the offers made), so all of them can be haggled with at once and a bad offer stays with
## his farm. What is offered is gone either way (offer). At least his number: the
## price drops; less: it goes up (MOOD_STEP, in percent of the asking price, between PRICE_FLOOR
## and PRICE_CEILING; the ceiling may be more than the purse holds, the next TREASURY step holds it).
## Each reply slip prints that step (step_text, replayed from the moods: steps). His mood is stamped on
## the deed after each offer and is the only clue (Mood, MOOD_FROM: the offer as a share of his
## number). After every offer that landed he wants GREED times as much. With the card RECOVER
## (RECOVER REJECTED GOODS) RECOVERED of an offer that missed comes back. Each owner's offers and
## price are in the save (save.haggles, by site) until a farm is bought; then every owner starts
## over from his new asking price. He answers each offer with a typed line (reply: REPLIES, by mood).
## On the sheet: START HAGGLING on the deed (HAGGLE) slides the negotiation letter over it
## (NegotiationLetter in FarmDeed). A press on the crate (CRATE) takes a bundle into the hand, it
## follows the mouse (drag) and is let go (release) on the offer (PILE) or back; a click on the
## offer takes the nearest bundle back; SEND OFFER (SEND) sends what lies there: the pile goes, his
## reply slip arrives and the stamp comes down on his mood (as the purchase's, no click
## meanwhile), the price reprints as it lands; BACK TO THE DEED (RETURN) slides the letter away.
##
## The moments, each its own: hover (HOVER_TIME; MapTable's hover sound), the deed sliding in and
## away (FarmDeed Slide), the stamp (FarmDeed Strike), the token's swap (the jump JUMP_TIME, the
## flash FLASH_TIME, the tag's reprint, the parcel PARCEL_TIME: `Flash/Acquire`, a deed seal and an
## adding machine), the lamp (the Field Line's own Relay, heard from the map), the deed rolling away
## (FarmDeed Roll), the refusal
## (SHAKE_TIME: `Flash/Refuse`, the token's wobble, and FarmDeed Denied). The token's swap itself is
## `Flash/Swap`, the pattern sweeping over a parcel `Flash/SpreadShort`, over the whole country (its
## last farm) `Flash/SpreadLong`.

const Events := preload("res://globalScripts/game_events.gd")
const World := preload("res://entities/map_table/world_register.gd")

## What the 1st .. 5th farm costs, in coins only (round 2 point 10: a farm is bought with money,
## haggled over with cabbages). Paced in tools/pace.py (`python tools/pace.py ch3`) against the
## farms-first player of the 2026-11-15 playtest (~$50K a minute at farm 4, ~$150K once the street
## pays double): the fourth and fifth fit the WALL SAFE limit ($1.5M), the fifth comes about 10 min
## after BRIBERY at the playtest's income.
const PRICES: Array[Dictionary] = [
	{coins = 60000},
	{coins = 200000},
	{coins = 450000},
	{coins = 1200000},
	{coins = 1600000},
]
## Each home site's price, times PRICES: by the head office or on a big parcel
## dearer, far out cheaper. A player who buys the cheapest site first pays 0.7 to 1.0 for
## the five that are sold, so the chapter keeps its pace (tools/pace.py ch3 mirrors it); the dearest
## three are the ones left to war. Any site not listed: 1.0.
const WORTH: Dictionary[StringName, float] = {
	&"K-1": 1.4,  # Beside the head office.
	&"K-2": 1.0,
	&"K-3": 1.15,  # Near the head office, a small parcel.
	&"K-4": 0.85,  # A small parcel.
	&"K-5": 1.25,  # A big parcel.
	&"K-6": 0.8,  # Far out, a small parcel.
	&"K-7": 0.95,  # The biggest parcel, the furthest west.
	&"K-8": 0.7,  # The furthest from the head office.
}
## The desk card (UpgradeDesk) that allows war on a farm nobody sells.
const WAR_CARD := "war_mode"
## From the stamp on a war order until the sheet asks for the war sheet (s): the stamp lifts first.
const WAR_AFTER := 0.5
## The card (UpgradeDesk) that must be stamped before the 1st .. 5th farm is sold; "" for none.
## Farms a save already owns stay owned whatever is stamped.
const GATES: Array[String] = ["", "negotiation", "negotiation", "negotiation", "bribery"]
## The gate whose farm is haggled over in coins (a bribe), not in cabbages.
const BRIBE := "bribery"
## The negotiation for the 1st .. 5th farm (none for the first): the owner's number for the first
## offer lies between `low` and `high` (cabbages; coins for the bribe), and an offer is made of
## bundles of `bundle` (a cabbage on the letter showing that count; a stack of coins), at most
## NegotiationLetter.MOST of them: a typical offer is 3 to 10 bundles.
## Paced in tools/pace.py haggle: a share of what one step off the coin price is worth in cabbages
## at the slate's price then, wider with every farm; a middling player ends about a fifth under the
## asking price (the bribe: a third, for about $320K of envelopes).
const HAGGLES: Array[Dictionary] = [
	{},
	{low = 70, high = 120, bundle = 25},
	{low = 130, high = 230, bundle = 50},
	{low = 260, high = 500, bundle = 75},
	{low = 30000, high = 70000, bundle = 15000},
]
## Who owns each home site and answers the letters: one name per site, the same every time.
const OWNERS: Dictionary[StringName, String] = {
	&"K-1": "H. Wirsing",
	&"K-2": "A. Krautmann",
	&"K-3": "E. Strunk",
	&"K-4": "O. Blattner",
	&"K-5": "M. Kappes",
	&"K-6": "W. Kohlhaas",
	&"K-7": "R. Rübsam",
	&"K-8": "G. Lattich",
}
## What an owner types back, by what was offered and his mood after it (Mood, worst first; keys):
## each reply picks one of its mood's lines (reply). The line hints the way, never the number.
const REPLIES := {
	"stock": [
		["Is this a joke? Double it.", "My grandfather planted these rows. I want more than this.", "I have framed better offers. Not many."],
		["Closer. Not close.", "My accountant laughed. Briefly.", "More. Considerably more."],
		["Almost. My accountant is listening.", "Nearly. Do not stop now.", "A little more and I stop pretending."],
		["Acceptable. The price comes down.", "Fine. I will come down. Do not get used to it.", "My wife says yes. I say a smaller yes."],
		["Fine. Sign before I change my mind.", "Generous. Suspiciously generous.", "You overpaid. I will not mention it again."],
	],
	"coins": [
		["What envelope? I see no envelope.", "This must have fallen out of a very small pocket.", "I do not count anything this thin."],
		["It is light. Paper weighs more.", "Weighed. Found wanting.", "The envelope is warm. The contents are not."],
		["Considered. A heavier envelope is easier to consider.", "Nearly persuasive.", "Thicker envelopes close faster."],
		["Understood. The price was a clerical error.", "I see we understand each other.", "The committee is satisfied. I am the committee."],
		["Gratitude noted. The paperwork will be quick.", "Very generous. The file has been misplaced.", "My nephew will remember your name."],
	],
}
## Offers the owner hears per farm.
const ROUNDS := 5
## After an offer that landed he wants this many times as much.
const GREED := 1.25
## His mood after an offer, worst first: the first three missed, the last two landed.
enum Mood { INSULTED, UNIMPRESSED, LISTENING, INTRIGUED, DELIGHTED }
## From which share of his number an offer leaves him in each mood, and what that mood does to the
## coin price, in percent of the asking price.
const MOOD_FROM: Array[float] = [0.0, 0.4, 0.75, 1.0, 1.6]
const MOOD_STEP: Array[int] = [10, 8, 4, -12, -12]
## The coin price stays between these, in percent off and on the asking price.
const PRICE_FLOOR := -40
const PRICE_CEILING := 40
## The card that brings RECOVERED of a missed offer back.
const RECOVER := "rejected_goods"
const RECOVERED := 0.5
## The spots of the negotiation letter (NegotiationLetter.BOXES): the crate a bundle is taken from,
## the offer it is laid on, SEND OFFER.
const CRATE := &"deed_crate"
const PILE := &"deed_pile"
const SEND := &"deed_send"
## The deed's START HAGGLING box and the letter's BACK TO THE DEED.
const HAGGLE := &"deed_haggle"
const RETURN := &"deed_return"
## The pile carried off the paper on SEND (s, and m along the deed's way out); the reply slip comes
## after it.
const SEND_TIME := 0.3
const SEND_AWAY := 0.6
## A site's click target on the art, around its centre (px): its disc and the two tags below it.
const HIT := Rect2(-115, -90, 230, 285)
## The company's ink: the tag of an owned site.
const OXBLOOD := Color(0.416, 0.169, 0.157)
## Hovered, a building stands this much bigger.
const HOVER_SCALE := 1.14
const HOVER_TIME := 0.1
## Acquired, it jumps to this size and settles.
const JUMP_SCALE := 1.6
const JUMP_TIME := 0.45
## The flash spreads from FLASH_FROM to FLASH_TO times its size while it fades.
const FLASH_FROM := 0.5
const FLASH_TO := 2.2
const FLASH_TIME := 0.5
## The boss's paper about a farm bought (BossReport) waits this long (s) after the deed has left
## the map (deed_gone_after): the acquisition plays out and is seen first.
const PAPER_AFTER := 1.4
## The spot of the open sheet that is the laid-out deed's stamp box (spot_at, press).
const STAMP := &"deed_stamp"
## The sheet a stamped war order asks the table for (MapSheet.sheet_wanted).
const WAR := &"war"
## Not a sheet: once the first farm's deed has left the map, the register asks the table for the
## farm TV (MapTable.to_farm, the TO FARM press, card or not).
const TV := &"farm_tv"
## The deed lies this far (px) beside its site's centre, at least DEED_MARGIN px inside the sheet's
## edges and DEED_LIFT m over the paper (clear of the tokens it covers); it slides in from DEED_FROM
## px further out in DEED_SLIDE_TIME s.
const DEED_GAP := 130.0
const DEED_MARGIN := 100.0
const DEED_LIFT := 0.075
const DEED_FROM := 1500.0
const DEED_SLIDE_TIME := 0.32
## A token whose centre is under the deed, or within COVER px of it, tucks away (TUCK_TIME s) while
## the deed lies there: it would stand through the paper.
const COVER := 110.0
const TUCK_TIME := 0.1
## The purchase, in order from the click on the stamp box (s): the stamp falls for STAMP_DROP_TIME
## and stays down HIT_PAUSE; then the token swaps, the stamp lifts (STAMP_LIFT_TIME) and the pattern
## spreads over the parcel for PARCEL_TIME (the country's last farm COUNTRY_TIME longer); LAMP_AFTER later the Field Line may light its lamp;
## DEED_LEAVE_AFTER later the deed rolls up (DEED_ROLL_TIME) and drops off the map (DEED_DROP_TIME).
const STAMP_DROP_TIME := 0.14
const HIT_PAUSE := 0.09
const STAMP_LIFT_TIME := 0.3
const PARCEL_TIME := 0.8
const LAMP_AFTER := 0.75
const DEED_LEAVE_AFTER := 0.45
const DEED_ROLL_TIME := 0.34
const DEED_DROP_TIME := 0.28
## The land layer takes this many places (farm_parcels.gdshader `progress`): the sites, then the
## head office.
const PLACES := 9
## The country's last farm spreads this much longer (s): its whole land turns.
const COUNTRY_TIME := 1.4
## Refused, it shakes this far to either side (m, on the sheet).
const SHAKE := 0.012
const SHAKE_TIME := 0.28

## The head office on the art (x, y px; z unused): its share of the land is the company's from the
## start (tools/bake_parcels.gd). Zero on a sheet without one (every country but the home country).
@export var head_office := Vector3.ZERO

## The buildings by site id, and where each stands at rest (on the sheet).
var _sites: Dictionary[StringName, MapBuilding] = {}
var _rest: Dictionary[StringName, Vector3] = {}
## What moves each site right now.
var _moving: Dictionary[StringName, Tween] = {}
var _flash_tween: Tween
var _hot := &""
## What the sheet shows: how many farms are owned, the cards stamped, the haggled price. When the
## save has it otherwise (a farm bought, a card stamped), it is printed again.
var _shown := Vector3i(-1, 0, 0)
var _ink: Color
## A farm is paid for and its moment on the map still plays: the Field Line (worlds/components/
## field_exchange.gd) keeps the new farm's lamp dark until this is false again.
static var lamp_held := false
## The figures the last declaration stamped here took to war (unit id -> count), for the war sheet.
var committed := {}
## How many of each unit type the declaration lying here sends (unit id -> count), and the army
## it was printed for.
var _take := {}
var _deed_army := {}
## The site whose deed lies on the sheet (&"": none), the deed's top left corner on the art (px)
## and what it marks as short.
var _deed_site := &""
var _deed_corner := Vector2.ZERO
## The laid-out paper's size as a deed's (FarmDeed.WAR_SCALE for a declaration of war).
var _deed_scale := 1.0
var _deed_lacks := {}
## The purchase playing out (null: none): no click is taken until its deed is gone.
var _dealing: Tween
## The site just paid for whose token still waits for the stamp to land, and the one whose parcel
## is spreading right now.
var _pending := &""
var _spreading := &""
var _spread_tween: Tween
## How much of each site's parcel shows the pattern (0..1).
var _parcels: Dictionary[StringName, float] = {}
## The box of the deed under the mouse (FarmDeed.BOXES; &"": none).
var _hot_box := &""
## Where the mouse was last on the negotiation letter's page (px; spot_at).
var _letter_at := Vector2.ZERO
## The sites whose tokens are tucked away under the deed.
var _tucked: Array[StringName] = []

@onready var _deed: FarmDeed = $Deed
@onready var _parcel_ink: ShaderMaterial = ($Page/Sheet/Layers/Parcels as CanvasItem).material
@onready var _flash: GeometryInstance3D = $Flash
@onready var _acquire_sound: SoundCue = $Flash/Acquire
@onready var _refuse_sound: SoundCue = $Flash/Refuse
@onready var _swap_sound: SoundCue = $Flash/Swap
@onready var _spread_short: SoundCue = $Flash/SpreadShort
@onready var _spread_long: SoundCue = $Flash/SpreadLong


func _ready() -> void:
	super()
	for thing in $Things.get_children():
		var building := thing as MapBuilding
		if building != null and building.site != &"":
			_sites[building.site] = building
			_rest[building.site] = building.position
	_ink = _tag(_sites.keys()[0]).get_theme_color(&"font_color")
	refresh()


func _process(_delta: float) -> void:
	if _state(SaveManager.save) != _shown:
		refresh()
	if _deed_site == &"":
		return
	if open < 1.0:
		_drop_deed()  # The sheet is being rolled up: its deed goes with it, at once.
	elif _dealing == null and (lacks(SaveManager.save, _deed_bill(), _out()) != _deed_lacks or SaveManager.save.army != _deed_army):
		_print_deed()  # What is short, or the staff ready, changed while it lies there.


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()  # The tags' wording changed.


## `site`'s worth (WORTH): what its price is times PRICES.
static func worth(site: StringName) -> float:
	return WORTH.get(site, 1.0)


## What `site`'s owner asks of `save` as the next home farm, {currency: amount} as UpgradeDesk.costs:
## PRICES by the farms owned times the site's WORTH (coins to the thousand);
## nothing while nobody sells: its card (GATES) is not stamped, or five are owned (the rest is war).
static func asking(save: SaveGame, site: StringName) -> Dictionary:
	var owned := save.farms_owned.size()
	if owned >= mini(Events.HOME_SELLERS, PRICES.size()) or (gate(save) != "" and not save.stamped.has(gate(save))):
		return {}
	var base: Dictionary = PRICES[owned]
	return {coins = roundi(base.coins * worth(site) / 1000.0) * 1000}


## What `site` costs `save` now: its asking price plus every step its owner's offers moved it
## (steps), replayed rather than read from the save, so it always matches the reply slips and a
## price saved before PRICES or HAGGLES changed never drifts past the ceiling.
static func price(save: SaveGame, site: StringName) -> Dictionary:
	var bill := asking(save, site)
	if bill.is_empty():
		return bill
	var coins: int = bill.coins
	for step in steps(save, site):
		coins += step
	return {coins = coins}


## `site`'s owner's negotiation as `save` has it: {price = the coin price his offers left (0: still
## asking), offers = every offer made to him, in order}; empty before the first. A save from when
## one owner at a time was haggled with (haggle_site, haggle_offers, haggle_price) has that
## negotiation moved to its owner first.
static func haggle(save: SaveGame, site: StringName) -> Dictionary:
	if save.haggle_site != "":
		save.haggles[save.haggle_site] = {price = save.haggle_price, offers = save.haggle_offers}
	if save.haggle_site != "" or not save.haggle_offers.is_empty() or save.haggle_price != 0:
		save.haggle_site = ""
		save.haggle_offers = PackedInt32Array()
		save.haggle_price = 0
	return save.haggles.get(String(site), {})


## The offers made to `site`'s owner so far, in order.
static func offers(save: SaveGame, site: StringName) -> PackedInt32Array:
	return haggle(save, site).get("offers", PackedInt32Array())


## How many cabbages (coins for the bribe) one bundle on the letter is for the next farm; 0 where
## nobody haggles.
static func bundle(save: SaveGame) -> int:
	return HAGGLES[save.farms_owned.size()].get("bundle", 0) if save.farms_owned.size() < HAGGLES.size() else 0


## Who owns `site` (OWNERS).
static func owner_of(site: StringName) -> String:
	return OWNERS.get(site, "")


## The line `site`'s owner typed back to offer `nth` (0: the first), which left him in `mood`, by
## what was offered (`paid_in`): a key of REPLIES, picked by the save and the site, the next one each
## time the same mood comes again (no line twice in a row), so reloading never changes what he said.
static func reply(save: SaveGame, site: StringName, nth: int, mood: int, paid_in: String) -> String:
	var lines: Array = REPLIES[paid_in][mood]
	var again := moods(save, site).slice(0, nth).count(mood)  # The same mood again: his next line for it.
	return lines[posmod(hash([save.created, String(site)]) + again, lines.size())]


## The card the next farm waits for (GATES), stamped or not; "" when it needs none.
static func gate(save: SaveGame) -> String:
	var owned := save.farms_owned.size()
	return GATES[owned] if owned < GATES.size() else ""


## What `site`'s owner is offered: "stock" (cabbages) behind NEGOTIATION, "coins" (a bribe) behind
## BRIBERY; "" where nobody haggles (the first farm, a farm not for sale).
static func tender(save: SaveGame, site: StringName) -> String:
	if asking(save, site).is_empty() or gate(save) == "":
		return ""
	return "coins" if gate(save) == BRIBE else "stock"


## What `site`'s owner has in mind after `wins` offers that landed: at least this much lands. Drawn
## once per save, farm and owner (save.created, the farms owned, the site: what one owner wants says
## nothing about the next), times the site's WORTH (a dear site is harder), so a reload never
## changes it. Never shown to the player.
static func wanted(save: SaveGame, wins: int, site: StringName) -> int:
	var range_of := HAGGLES[save.farms_owned.size()]
	var draw := RandomNumberGenerator.new()
	draw.seed = hash([save.created, save.farms_owned.size(), String(site)])
	return roundi(lerpf(range_of.low, range_of.high, draw.randf()) * worth(site) * pow(GREED, wins))


## The owner's mood after `offered` when he has `wants` in mind.
static func mood_of(offered: int, wants: int) -> Mood:
	var mood := Mood.INSULTED
	for i in MOOD_FROM.size():
		if offered >= MOOD_FROM[i] * wants:
			mood = i as Mood
	return mood


## Whether an offer that left him in `mood` landed (the price drops).
static func landed(mood: int) -> bool:
	return mood >= Mood.INTRIGUED


## `site`'s owner's mood after each offer made to him so far, in order.
static func moods(save: SaveGame, site: StringName) -> Array[int]:
	var out: Array[int] = []
	var wins := 0
	for offered in offers(save, site):
		out.append(mood_of(offered, wanted(save, wins, site)))
		wins += int(landed(out[-1]))
	return out


## The lowest `site`'s coin price goes (PRICE_FLOOR).
static func floor_price(save: SaveGame, site: StringName) -> int:
	return roundi(asking(save, site).coins * (100 + PRICE_FLOOR) / 100.0)


## How many more offers `site`'s owner hears: ROUNDS in all; none where nobody haggles, and none once
## the price is at its floor (an offer could only be lost).
static func offers_left(save: SaveGame, site: StringName) -> int:
	if tender(save, site) == "" or price(save, site).coins <= floor_price(save, site):
		return 0
	return maxi(ROUNDS - offers(save, site).size(), 0)


## `site`'s coin price after an offer that left its owner in `mood`: MOOD_STEP percent of the asking
## price on or off it, between the floor and the ceiling. The ceiling is not held to the coin
## limit (a miss must cost something at the limit a player has): the next TREASURY step holds it and
## costs less than the limit (the suite walks that).
static func price_after(save: SaveGame, site: StringName, mood: int) -> int:
	var asked: int = asking(save, site).coins
	return clampi(price(save, site).coins + roundi(asked * MOOD_STEP[mood] / 100.0), floor_price(save, site), roundi(asked * (100 + PRICE_CEILING) / 100.0))


## How much each offer made to `site`'s owner moved its coin price, in order (0: it stayed, at the
## floor or the ceiling): price_after replayed from the asking price over his moods, so the save
## needs nothing more than the offers.
static func steps(save: SaveGame, site: StringName) -> Array[int]:
	var asked: int = asking(save, site).get("coins", 0)
	var top := roundi(asked * (100 + PRICE_CEILING) / 100.0)
	var now := asked
	var out: Array[int] = []
	for mood in moods(save, site):
		var next := clampi(now + roundi(asked * MOOD_STEP[mood] / 100.0), floor_price(save, site), top)
		out.append(next - now)
		now = next
	return out


## A step (steps) as a reply slip prints it: "+$24K", "-$24.500", or "price unchanged".
static func step_text(step: int) -> String:
	if step == 0:
		return TranslationServer.translate("price unchanged")
	return ("+" if step > 0 else "-") + "$" + Num.text(absi(step))


## Puts `amount` (cabbages from the store, or coins: tender) to `site`'s owner: it is gone whether it
## lands or not (RECOVERED of a miss comes back once RECOVER is stamped), the price moves
## (price_after) and the offer is on file with his negotiation (haggle; no other owner's changes).
## The mood it leaves him in (Mood), or -1 when no offer is taken and nothing changes: nobody
## haggles, no offer left, or `save` does not hold `amount` (`out`: UpgradeDesk.units_out).
static func offer(save: SaveGame, site: StringName, amount: int, out := Vector2i.ZERO) -> int:
	var paid_in := tender(save, site)
	if offers_left(save, site) <= 0 or amount <= 0 or UpgradeDesk.spendable(save, paid_in, out) < amount:
		return -1
	var mood := mood_of(amount, wanted(save, moods(save, site).filter(landed).size(), site))
	UpgradeDesk.pay(save, paid_in, amount, out)
	save.owners_insulted += int(mood == Mood.INSULTED)
	if not landed(mood) and save.stamped.has(RECOVER):
		save.set(paid_in, save.get(paid_in) + int(amount * RECOVERED))
	var made := offers(save, site)
	made.append(amount)
	var haggles := save.haggles.duplicate()
	haggles[String(site)] = {price = price_after(save, site, mood), offers = made}
	save.haggles = haggles
	return mood


## Every negotiation starts over: no offer on file with anyone, every asking price again.
static func close_haggle(save: SaveGame) -> void:
	haggle(save, &"")  # An old save's one negotiation goes too.
	save.haggles = {}


## The small print of a deed that is haggled over, until the first offer (a translation key).
static func haggle_note(save: SaveGame, site: StringName) -> String:
	if save.stamped.has(RECOVER):
		return "Half of a refused offer is returned."
	return "Envelopes are not returned." if tender(save, site) == "coins" else "Cabbages offered are not returned."


## Why `site` is not for sale to `save`, as its paper says it: at home the owners need persuading
## while the next farm's card (GATES) is not stamped; any other farm's owner is unavailable (until
## the war card).
static func reason(save: SaveGame, site: StringName = &"K-") -> String:
	var waits := World.country_of(site) == World.HOME and save.farms_owned.size() < mini(Events.HOME_SELLERS, PRICES.size()) and gate(save) != ""
	return TranslationServer.translate("The owners will need persuading." if waits else "The owner is unavailable.")


## Whether `site` is taken by war for `save`: the war card is stamped, it is not ours, and nobody
## sells it (abroad never; at home once GameEvents.HOME_SELLERS farms are owned).
static func war_ready(save: SaveGame, site: StringName) -> bool:
	if not save.stamped.has(WAR_CARD) or save.farms_owned.has(site):
		return false
	return World.country_of(site) != World.HOME or Events.home_farms(save) >= Events.HOME_SELLERS


## What the war on `site` is expected to cost `save` (WorldRegister.war_price);
## nothing where there is no war to start: not war_ready, or out of reach (WorldRegister.reach).
## Coins only: the cabbages of a war go into its soldiers (WarRules).
static func war_bill(save: SaveGame, site: StringName) -> Dictionary:
	var country := World.country_of(site)
	if not war_ready(save, site) or World.reach(save, country) != "":
		return {}
	return {coins = World.war_price(save, country).get("coins", 0)}


## Whether `save` has anybody trained to send to war (save.army; trainees do not count).
static func has_staff(save: SaveGame) -> bool:
	return save.army.values().any(func(count: Variant) -> bool: return int(count) > 0)


## Whether `save` can declare war on `site` sending `chosen` (unit id -> count): a war can be
## started there (war_bill), its coins are in the purse, there is trained staff (has_staff), at
## least one figure goes and none more than save.army has ready (`out`: UpgradeDesk.units_out).
static func can_declare(save: SaveGame, site: StringName, chosen: Dictionary, out := Vector2i.ZERO) -> bool:
	var bill := war_bill(save, site)
	if bill.is_empty() or not UpgradeDesk.affords(save, bill, out) or not has_staff(save):
		return false
	var sent := 0
	for unit: String in chosen:
		var count := int(chosen[unit])
		if count < 0 or count > int(save.army.get(unit, 0)):
			return false
		sent += count
	return sent > 0


## Declares war on `site` for `save`: pays war_bill's coins and takes the `chosen` figures out of
## save.army into save.war_pending (a game closed before they are committed gives them back).
## Whether it was declared; refused (can_declare), nothing changes.
static func declare(save: SaveGame, site: StringName, chosen: Dictionary, out := Vector2i.ZERO) -> bool:
	return can_declare(save, site, chosen, out) and send(save, war_bill(save, site), chosen, out)


## Pays `bill` and sends `chosen` (unit id -> count) off to war, as declare does once allowed (a
## bandit camp's operation too, BanditCamp.declare): refused (nothing changes) short of the coins,
## with nobody trained, nobody chosen or more chosen than are ready.
static func send(save: SaveGame, bill: Dictionary, chosen: Dictionary, out := Vector2i.ZERO) -> bool:
	if not UpgradeDesk.affords(save, bill, out) or not has_staff(save):
		return false
	var sent := 0
	for unit: String in chosen:
		if int(chosen[unit]) < 0 or int(chosen[unit]) > int(save.army.get(unit, 0)):
			return false
		sent += int(chosen[unit])
	if sent <= 0:
		return false
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
	save.war_fee = int(bill.get("coins", 0))  # Given back if the game closes before START.
	save.war_pending = {}
	for unit: String in chosen:
		var left := int(save.army.get(unit, 0)) - int(chosen[unit])
		if left > 0:
			save.army[unit] = left
		else:
			save.army.erase(unit)
		if int(chosen[unit]) > 0:
			save.war_pending[unit] = int(chosen[unit])
	return true


## The war on `site` is called off before START (WarSheet.abort): nothing happened, so its coins
## (war_bill, the same as paid: the price only moves with farms won) come back. The figures are the
## war sheet's to return. The coins it gave back.
static func refund(save: SaveGame, site: StringName) -> int:
	var coins := int(war_bill(save, site).get("coins", 0))
	save.coins += coins  # Not earn(): what was paid comes back whole, over the purse's limit or not.
	return coins


## Where the deed for the site at art pixel `at` lies: its top left corner on the art (px). Beside
## the site (deed_side), level with it, inside the sheet: never on the site. `times`: the paper is
## that many times a deed's size (FarmDeed.WAR_SCALE for a declaration).
static func deed_corner(at: Vector2, times := 1.0) -> Vector2:
	var size := FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE * times
	var x := at.x + DEED_GAP if deed_side(at, times) > 0.0 else at.x - DEED_GAP - size.x
	var room := SIZE * PIXELS_PER_METRE - size - Vector2.ONE * DEED_MARGIN
	return Vector2(x, clampf(at.y - size.y / 2.0, DEED_MARGIN, room.y))


## The side of the site at art pixel `at` its deed lies on, and comes from: -1 map-left, 1
## map-right. The side away from the sheet's middle, so the map stays in view; where the paper has
## no room there (a site near the sheet's edge), the side towards the middle.
static func deed_side(at: Vector2, times := 1.0) -> float:
	var width := SIZE.x * PIXELS_PER_METRE
	var out := -1.0 if at.x < width / 2.0 else 1.0
	var need := DEED_GAP + FarmDeed.SIZE.x * FarmDeed.PIXELS_PER_METRE * times + DEED_MARGIN
	return out if (at.x if out < 0.0 else width - at.x) >= need else -out


## Seconds from the click on the stamp box until the deed has left the map.
static func deed_gone_after() -> float:
	return STAMP_DROP_TIME + HIT_PAUSE + LAMP_AFTER + DEED_LEAVE_AFTER + DEED_ROLL_TIME + DEED_DROP_TIME


## Whether `site` can still be bought: a home farm, not ours yet, and somebody still sells.
static func for_sale(save: SaveGame, site: StringName) -> bool:
	return World.country_of(site) == World.HOME and not save.farms_owned.has(site) and not price(save, site).is_empty()


## What `save` lacks of `site`'s price, {currency: amount}; empty when it can pay (`out`:
## UpgradeDesk.units_out, cabbages out of the store can't pay).
static func short(save: SaveGame, site: StringName, out := Vector2i.ZERO) -> Dictionary:
	return lacks(save, price(save, site), out)


## What `save` lacks of `bill` ({currency: amount}), the same way.
static func lacks(save: SaveGame, bill: Dictionary, out := Vector2i.ZERO) -> Dictionary:
	var missing := {}
	for paid_in: String in bill:
		if UpgradeDesk.spendable(save, paid_in, out) < bill[paid_in]:
			missing[paid_in] = bill[paid_in] - UpgradeDesk.spendable(save, paid_in, out)
	return missing


## Buys `site` for `save` if it is for sale and paid for: takes the price, adds the site to the
## farms owned. Whether it was bought; refused, nothing changes.
static func buy(save: SaveGame, site: StringName, out := Vector2i.ZERO) -> bool:
	var bill := price(save, site)
	if not for_sale(save, site) or not UpgradeDesk.affords(save, bill, out):
		return false
	save.floor_buys += int(tender(save, site) != "" and bill.get("coins", 0) <= floor_price(save, site))
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
	save.farms_owned.append(site)
	close_haggle(save)  # The next owner starts from his own asking price.
	return true


## What `site`'s price tag prints: its price as the next farm (Num.text: "$60K", "$62.400", "$1.5M"),
## ACQUIRED once ours; for a farm taken by war what the war is expected to cost, or why it cannot be
## attacked (WorldRegister.reach); NOT FOR SALE while nobody sells and there is no war card.
static func tag_text(save: SaveGame, site: StringName) -> String:
	if save.farms_owned.has(site):
		return TranslationServer.translate("ACQUIRED")
	var bill := price(save, site) if for_sale(save, site) else war_bill(save, site)
	if bill.is_empty():
		return TranslationServer.translate(World.reach(save, World.country_of(site)) if war_ready(save, site) else "NOT FOR SALE")
	return "$" + Num.text(bill.coins)


## `bill` (coins: a deed's or a war's) in words: "$30K".
static func words(bill: Dictionary) -> String:
	return "$" + Num.text(bill.get("coins", 0))


## The hint slip for `site` called this name: its price (never what is short: the deed shows that),
## that it is ours, or why it cannot be bought.
static func hint_text(save: SaveGame, site: StringName, called: String) -> String:
	if save.farms_owned.has(site):
		return TranslationServer.translate("%s. Company property.") % called
	if war_ready(save, site):
		var country := World.country_of(site)
		if World.reach(save, country) != "":
			return TranslationServer.translate("%s. Not for sale.") % called + " " + World.reason(save, country)
		return TranslationServer.translate("%s. Not for sale. Cost of war: %s. Click to declare war.") % [called, words(war_bill(save, site))]
	if not for_sale(save, site):
		return TranslationServer.translate("%s. Not for sale.") % called + " " + reason(save, site)
	return TranslationServer.translate("%s. Price: %s. Click for the deed.") % [called, words(price(save, site))]


static func _state(save: SaveGame) -> Vector3i:
	return Vector3i(save.farms_owned.size(), save.stamped.size(), save.haggles.hash() & 0x7fffffff)


## Shows every site as the save has it (owned look, tag), without any moment, and prints the page.
func refresh() -> void:
	var save := SaveManager.save
	if _shown.x >= 0 and save.farms_owned.size() != _shown.x:
		close_haggle(save)  # A farm came some other way (the debug key): the offers were for another owner.
	_shown = _state(save)
	for site in _sites:
		var ours := save.farms_owned.has(site) and site != _pending  # Paid for: ours when the stamp lands.
		_sites[site].owned = ours
		var tag := _tag(site)
		if _pending == &"":
			tag.text = tag_text(save, site)
		tag.add_theme_color_override(&"font_color", OXBLOOD if ours else _ink)
		if site != _spreading:
			_parcels[site] = 1.0 if ours else 0.0
	_print_parcels()
	if _deed_site != &"" and _dealing == null:
		_print_deed()  # Its price, or whether it is for sale at all, may have changed.


func spot_at(pixel: Vector2) -> StringName:
	if _deed_site != &"":
		# The deed lies DEED_LIFT over the sheet (the record a little more): the mouse is on the
		# pixel of the paper it shows there, not on the sheet's pixel under it.
		var on := (lifted(pixel, DEED_LIFT + (FarmDeed.HAGGLE_LIFT if _deed.haggling else 0.0)) - _deed_corner) / _deed_scale
		if FarmDeed.covers(on, _deed.haggling):
			# The papers cover what lies under them; only their boxes are spots: the stamp box of a
			# farm for sale, START HAGGLING where its owner haggles, the letter's crate, offer and
			# SEND OFFER while he hears offers, and BACK TO THE DEED.
			_letter_at = FarmDeed.page(on)
			if _declaring() and has_staff(SaveManager.save):  # Nobody trained: no rows to count.
				var staff := FarmDeed.staff_box_at(on, Depot.units(SaveManager.save))
				if staff != &"":
					return staff if _dealing == null else &""
			var box := FarmDeed.box_at(on, _deed.haggling)
			var live := true
			if box == STAMP:
				live = not _deed.bill.is_empty()
			elif box == HAGGLE:
				live = tender(SaveManager.save, _deed_site) != "" and for_sale(SaveManager.save, _deed_site)
			elif box != RETURN:
				live = offers_left(SaveManager.save, _deed_site) > 0
			return box if _dealing == null and live else &""
	for site in _sites:
		# A farm of ours is no spot: no lift, no sound, no hint slip, no deed (MapTable follows spot_at).
		if HIT.has_point(pixel - _pixel(site)) and not SaveManager.save.farms_owned.has(site):
			return site
	return &""


## Sheet pixel `pixel` (where the mouse's ray meets the sheet: MapTable.sheet_pixel) moved to the
## pixel the mouse is on of a paper lying `height` m over the sheet: the camera looks down at an
## angle, so what lies higher is seen nearer to it. As it is without a camera.
func lifted(pixel: Vector2, height: float) -> Vector2:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return pixel
	var screen := camera.unproject_position(point_at(pixel))
	var up := global_basis.y
	var hit: Variant = Plane(up.normalized(), point_at(pixel) + up * height).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return pixel_at(hit) if hit != null else pixel


## Nothing while a deed lies on the sheet: it says all of it, and the slip would lie on it.
func hint(spot: StringName) -> String:
	return hint_text(SaveManager.save, spot, _sites[spot].title) if _sites.has(spot) and _deed_site == &"" else ""


func hover(spot: StringName) -> void:
	var box := spot if FarmDeed.DEED_BOXES.has(spot) or FarmDeed.HAGGLE_BOXES.has(spot) or _staff_spot(spot) else &""
	if box != _hot_box:
		_hot_box = box
		_deed.hot(box)
	if not _sites.has(spot):
		spot = &""
	if spot == _hot:
		return
	for site: StringName in [_hot, spot]:
		if site != &"" and thing_up(_index(site)):
			_move(site).tween_method(raise_thing.bind(_index(site)), _raised(site), HOVER_SCALE if site == spot else 1.0, HOVER_TIME)
	_hot = spot


## A click on `spot` (&"": on nothing): the stamp box buys the deed's farm, START HAGGLING and BACK
## TO THE DEED lay the negotiation letter over the deed and take it away, the crate puts a bundle in
## the hand, the offer gives the nearest bundle back, SEND OFFER makes the offer, a farm not ours
## lays out its deed, anything else puts the deed away. Nothing while a purchase or an offer plays out.
func press(spot: StringName) -> void:
	if _dealing != null:
		return
	if spot == STAMP and _deed_site != &"":
		_stamp_deed()
	elif spot in [HAGGLE, RETURN] and _deed_site != &"":
		_deed.lay_haggle(spot == HAGGLE, deed_side(_pixel(_deed_site), _deed_scale) * DEED_FROM / PIXELS_PER_METRE, DEED_SLIDE_TIME)
	elif spot == CRATE and _deed_site != &"":
		_grab()
	elif spot == PILE and _deed_site != &"":
		_deed.negotiation.take_back(_letter_at)
	elif spot == SEND and _deed_site != &"":
		_submit_offer()
	elif _staff_spot(spot) and _deed_site != &"":
		_choose(spot)
	elif _sites.has(spot) and spot != _deed_site and not SaveManager.save.farms_owned.has(spot) and spot != _pending:
		_lay_out(spot)
	else:
		_put_away()


## The mouse moved to sheet pixel `pixel` (MapTable): a bundle in the hand follows it, held over the
## letter.
func drag(pixel: Vector2) -> void:
	if _deed_site != &"" and _deed.negotiation.holding():
		var over := DEED_LIFT + FarmDeed.HAGGLE_LIFT + NegotiationLetter.HOLD_LIFT
		_deed.negotiation.drag_to(FarmDeed.page(lifted(pixel, over) - _deed_corner))


## While the negotiation letter lies open, its four corners (world, where it comes to rest) and
## its tray: the table glides the camera in on it so its slips read (MapTable._follow_focus).
func focus() -> PackedVector3Array:
	if _deed_site == &"" or not _deed.haggling or not _deed.visible:
		return PackedVector3Array()
	var letter := global_transform * Transform3D(Basis.from_scale(Vector3.ONE * _deed_scale), _deed_at()) * _deed.letter_rest()
	var size := NegotiationLetter.SIZE
	return PackedVector3Array([letter * Vector3.ZERO, letter * Vector3(size.x, 0.0, 0.0), letter * Vector3(0.0, 0.0, size.y), letter * Vector3(size.x, 0.0, size.y)])


## The mouse button came up over `spot`: a bundle in the hand lies down on the offer (PILE, or a
## click on the crate) or goes back.
func release(spot: StringName) -> void:
	if _deed_site != &"" and _deed.negotiation.holding():
		_deed.negotiation.drop(spot == PILE)


## A purchase or an offer plays out: the table does not roll the sheet up under it (MapTable.show_sheet).
func busy() -> bool:
	return _dealing != null


## The site whose deed lies on the sheet, or &"".
func deed_site() -> StringName:
	return _deed_site


## Lays `spot`'s deed beside it: it slides in from beyond the sheet's edge on its side.
func _lay_out(spot: StringName) -> void:
	_deed_site = spot
	_deed_scale = FarmDeed.WAR_SCALE if war_ready(SaveManager.save, spot) else 1.0
	_deed.scale = Vector3.ONE * _deed_scale
	_deed_corner = deed_corner(_pixel(spot), _deed_scale)
	_take = SaveManager.save.army.duplicate()  # Everybody ready goes, unless told otherwise.
	_print_deed()
	_uncover(0.0)
	var paper := Rect2(_deed_corner, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE * _deed_scale).grow(COVER)
	for site in _sites:
		if site != spot and paper.has_point(_pixel(site)):
			_tucked.append(site)
			_move(site).tween_method(raise_thing.bind(_index(site)), 1.0, 0.0, TUCK_TIME)
	var to := _deed_at()
	_deed.slide(to + Vector3.RIGHT * deed_side(_pixel(spot), _deed_scale) * DEED_FROM / PIXELS_PER_METRE, to, DEED_SLIDE_TIME)


## Prints the laid-out paper as the save has it: a deed with the next farm's price and what is short
## of it; a war order with what the war is expected to cost, or the strip why it cannot be started;
## or that nobody sells and why.
func _print_deed() -> void:
	var save := SaveManager.save
	var war := war_ready(save, _deed_site)
	var bill := _deed_bill()
	_deed_lacks = lacks(save, bill, _out())
	_deed.fill(_sites[_deed_site].title, _deed_site, bill, _deed_lacks,
			World.reason(save, id) if war else reason(save, _deed_site))
	_deed.letter(&"war" if war else &"deed", World.reach(save, id) if war else "")  # Before the band: its note is the haggle's.
	var what := tender(save, _deed_site)
	if what != "" and for_sale(save, _deed_site):
		var made := offers(save, _deed_site)
		var said := moods(save, _deed_site)
		var moved := steps(save, _deed_site)
		var replies := []
		for i in made.size():
			replies.append({offered = made[i], mood = tr(FarmDeed.MOODS[what][said[i]]), line = tr(reply(save, _deed_site, i, said[i], what)),
					step = step_text(moved[i]), up = moved[i] > 0})
		_deed.print_haggle(what, bundle(save), owner_of(_deed_site), replies, offers_left(save, _deed_site),
				asking(save, _deed_site).coins, UpgradeDesk.spendable(save, what, _out()), haggle_note(save, _deed_site))
	elif _deed.haggling:
		_deed.shut_haggle()  # Nobody haggles over it any more (a farm came some other way).
	_deed_army = save.army.duplicate()
	if _declaring():
		var rows := []
		for unit in Depot.units(save):
			var have := int(save.army.get(unit, 0))
			_take[unit] = clampi(int(_take.get(unit, have)), 0, have)
			rows.append({unit = unit, name = tr(DepotSheet.NAMES[unit]), have = have, take = _take[unit]})
		_deed.print_staff(rows)
		_deed.print_resistance(WarMap.difficulty_for(_deed_site, save, WarRules.army_cap(save)))
		_deed.print_site(WarMap.brief_for(_deed_site, save))
	_deed.hot(_hot_box)  # The mouse may still be on its box.


## What the laid-out paper prints as its price: the purchase price of a farm for sale, what the war
## on one that is taken is expected to cost, nothing where neither is to be had.
func _deed_bill() -> Dictionary:
	var save := SaveManager.save
	return price(save, _deed_site) if for_sale(save, _deed_site) else war_bill(save, _deed_site)


## A press on the crate: a bundle comes into the hand if stock (the purse) holds one more than lies
## on the offer, and the offer has room; else the refusal.
func _grab() -> void:
	var save := SaveManager.save
	var letter := _deed.negotiation
	if UpgradeDesk.spendable(save, tender(save, _deed_site), _out()) < (letter.count + 1) * bundle(save) or not letter.grab(_letter_at):
		_deed.blink()


## A click on SEND OFFER: what lies on the offer goes to the owner (offer) and is carried off the
## paper; his reply slip arrives and the stamp comes down on his mood; the price reprints with it.
## Nothing on the offer, or not held: refused, nothing changes.
func _submit_offer() -> void:
	var save := SaveManager.save
	var letter := _deed.negotiation
	var bribe := tender(save, _deed_site) == "coins"
	var mood := offer(save, _deed_site, letter.offered(), _out()) if letter.count > 0 else -1
	if mood < 0:
		_deed.blink()
		return
	SaveManager.log_event("offer", str(save.farms_owned.size() + 1), offers(save, _deed_site)[-1], tender(save, _deed_site))
	SaveManager.autosave()  # At once: quitting must not take a lost offer back and keep what the mood told.
	letter.send(deed_side(_pixel(_deed_site), _deed_scale) * SEND_AWAY, SEND_TIME)
	if bribe:
		_deed.envelope()
	_dealing = create_tween()
	_dealing.tween_interval(SEND_TIME)
	_dealing.tween_callback(_reply_arrives)
	_dealing.tween_interval(STAMP_DROP_TIME)
	_dealing.tween_callback(_mood_landed.bind(landed(mood)))
	_dealing.tween_interval(HIT_PAUSE)
	_dealing.tween_callback(_deed.lift_stamp.bind(STAMP_LIFT_TIME))
	_dealing.tween_interval(STAMP_LIFT_TIME)
	_dealing.tween_callback(_offer_done)


## The owner's reply slip lands on the letter (with the price as it now stands) and the stamp
## starts down onto it.
func _reply_arrives() -> void:
	_print_deed()
	_deed.negotiation.slip_arrives()
	_deed.strike_mood(STAMP_DROP_TIME)


func _mood_landed(won: bool) -> void:
	_deed.stamp_mood(won)


func _offer_done() -> void:
	_dealing = null


## The deed slides off the sheet the way it came, unstamped.
func _put_away() -> void:
	if _deed_site == &"":
		return
	var from := _deed_at()
	_deed.slide(from, from + Vector3.RIGHT * deed_side(_pixel(_deed_site), _deed_scale) * DEED_FROM / PIXELS_PER_METRE, DEED_SLIDE_TIME, true)
	_deed_site = &""
	_uncover(DEED_SLIDE_TIME * 0.5)


## The tokens tucked away under the deed stand up again, `after` s from now.
func _uncover(after: float) -> void:
	for site in _tucked:
		var tween := _move(site)
		tween.tween_interval(after)
		tween.tween_method(raise_thing.bind(_index(site)), 0.0, 1.0, TUCK_TIME)
	_tucked.clear()


## The deed is gone at once, whatever was playing (the sheet is rolled up under it).
func _drop_deed() -> void:
	_deed.hide()
	_deed_site = &""
	_tucked.clear()  # The table tucks and stands everything on a rolled sheet itself.
	refresh()


## Where the laid-out deed's origin (the middle of its top edge) lies on the sheet.
func _deed_at() -> Vector3:
	return Vector3((_deed_corner.x + FarmDeed.SIZE.x * FarmDeed.PIXELS_PER_METRE * _deed_scale / 2.0) / PIXELS_PER_METRE - SIZE.x / 2.0,
			DEED_LIFT, _deed_corner.y / PIXELS_PER_METRE)


## A click on the stamp box. On a war order it starts the war: the stamp comes down, and the sheet
## asks for the war sheet of that farm (nothing is paid here). On a deed it is the purchase if it is
## paid for (the rest plays out from here, see the constants), else the refusal and nothing bought.
func _stamp_deed() -> void:
	var spot := _deed_site
	if war_ready(SaveManager.save, spot):
		var chosen := _chosen()
		var war_cost := war_bill(SaveManager.save, spot)
		if not declare(SaveManager.save, spot, chosen, _out()):
			_refuse(spot)
			_deed.blink(chosen.is_empty())
			return
		committed = chosen
		for paid_in: String in war_cost:
			SaveManager.log_event("war_declared", spot, war_cost[paid_in], paid_in)
		SaveManager.autosave()
		_deed_army = SaveManager.save.army.duplicate()  # The rows keep what was sent until it leaves.
		_deed.strike(STAMP_DROP_TIME)
		_dealing = create_tween()
		_dealing.tween_interval(STAMP_DROP_TIME)
		_dealing.tween_callback(_deed.imprint)
		_dealing.tween_interval(HIT_PAUSE)
		_dealing.tween_callback(_deed.lift_stamp.bind(STAMP_LIFT_TIME))
		_dealing.tween_interval(WAR_AFTER)
		_dealing.tween_callback(_go_to_war.bind(spot))
		return
	var bill := price(SaveManager.save, spot)
	if not buy(SaveManager.save, spot, _out()):
		_refuse(spot)
		_deed.blink()
		return
	for paid_in: String in bill:  # One log line per currency, as the desk's cards.
		SaveManager.log_event("farm_bought", spot, bill[paid_in], paid_in)
	SaveManager.autosave()
	_pending = spot
	lamp_held = true
	BossReport.hold = deed_gone_after() + PAPER_AFTER
	_deed.strike(STAMP_DROP_TIME)
	var off := _deed_at() + Vector3.RIGHT * deed_side(_pixel(spot), _deed_scale) * DEED_FROM / PIXELS_PER_METRE
	_dealing = create_tween()
	_dealing.tween_interval(STAMP_DROP_TIME)
	_dealing.tween_callback(_deed.imprint)
	# ponytail: the hit pause holds the stamp only (nothing else moves at the map); Engine.time_scale if the whole game should freeze.
	_dealing.tween_interval(HIT_PAUSE)
	_dealing.tween_callback(_acquire.bind(spot))
	_dealing.tween_interval(LAMP_AFTER)
	_dealing.tween_callback(_release_lamp)
	_dealing.tween_interval(DEED_LEAVE_AFTER)
	_dealing.tween_callback(_deed.roll_away.bind(off, DEED_ROLL_TIME, DEED_DROP_TIME))
	_dealing.tween_interval(DEED_ROLL_TIME + DEED_DROP_TIME)
	_dealing.tween_callback(_deed_gone)
	if SaveManager.save.farms_owned.size() == 1:  # The company's first farm: the camera goes to see it.
		_dealing.tween_callback(sheet_wanted.emit.bind(TV, spot))


## Whether the paper lying here is a declaration that can be stamped (a war that can be started).
func _declaring() -> bool:
	return _deed_site != &"" and war_ready(SaveManager.save, _deed_site) and not war_bill(SaveManager.save, _deed_site).is_empty()


## Whether `spot` is one of a declaration's [-] / [+] boxes.
static func _staff_spot(spot: StringName) -> bool:
	return String(spot).begins_with(FarmDeed.STAFF_LESS) or String(spot).begins_with(FarmDeed.STAFF_MORE)


## A click on a declaration's [-] or [+]: one figure of that type fewer or more, as far as it goes.
func _choose(spot: StringName) -> void:
	var more := String(spot).begins_with(FarmDeed.STAFF_MORE)
	var unit := String(spot).trim_prefix(FarmDeed.STAFF_MORE if more else FarmDeed.STAFF_LESS)
	var to := clampi(int(_take.get(unit, 0)) + (1 if more else -1), 0, int(SaveManager.save.army.get(unit, 0)))
	if to == int(_take.get(unit, 0)):
		return
	_take[unit] = to
	_deed.count_tick()
	_print_deed()


## What the declaration lying here sends: the figures chosen, types with none left out.
func _chosen() -> Dictionary:
	var out := {}
	for unit in Depot.units(SaveManager.save):
		if int(_take.get(unit, 0)) > 0:
			out[unit] = int(_take[unit])
	return out


## The war order is stamped: the table rolls this sheet up and the war sheet for `spot` out.
func _go_to_war(spot: StringName) -> void:
	_dealing = null
	SaveManager.log_event("war", spot)
	sheet_wanted.emit(WAR, spot)


## `spot` was won in a war while this sheet lay rolled up: it stays as it was (not ours) until the
## sheet lies open again and celebrate plays its moment.
func expect(spot: StringName) -> void:
	_pending = spot
	refresh()


## The sheet lies open again after the war on `spot` was won: the acquisition's moment (the token's
## swap, the tag, the pattern, the Field Line's lamp LAMP_AFTER later).
func celebrate(spot: StringName) -> void:
	_acquire(spot)
	_dealing = create_tween()
	_dealing.tween_interval(LAMP_AFTER)
	_dealing.tween_callback(_release_lamp)
	_dealing.tween_callback(_offer_done)


## The name of farm site `spot` on this sheet.
func site_title(spot: StringName) -> String:
	return _sites[spot].title


func hint_title() -> String:
	return tr("%s farm register") % tr(title)


## A site's disc and its two tags (its name, then its price, as wide as their lettering runs), so the
## hint slip lies beside them and never over them.
func spot_box(spot: StringName) -> Rect2:
	if not _sites.has(spot):
		return Rect2()
	var box := Rect2(HIT.position + _pixel(spot), HIT.size)
	var price_tag := _tag(spot)
	for tag: Label in [price_tag.get_parent().get_child(price_tag.get_index() - 1) as Label, price_tag]:
		box = box.merge(lettering(tag))
	return box


func _release_lamp() -> void:
	lamp_held = false


func _exit_tree() -> void:
	lamp_held = false  # A purchase cut off (the scene left) holds no lamp.


func _deed_gone() -> void:
	_dealing = null
	_deed_site = &""
	_uncover(0.0)


## The acquisition's moment on `spot`, paid for and stamped: the stamp lifts, the owned look and the
## tags at once, the building jumps, the flash spreads and fades, the pattern spreads over its parcel.
func _acquire(spot: StringName) -> void:
	_pending = &""
	_spreading = spot
	_parcels[spot] = 0.0
	if _deed.visible:
		_deed.lift_stamp(STAMP_LIFT_TIME)
	refresh()
	if _spread_tween != null:
		_spread_tween.kill()
	_spread_tween = create_tween()
	var whole := World.owns_all(SaveManager.save, id)  # The country's last farm: all of its land turns.
	_spread_tween.tween_method(_spread.bind(spot), 0.0, 1.0, PARCEL_TIME + (COUNTRY_TIME if whole else 0.0)) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spread_tween.tween_callback(_spread_done)
	_acquire_sound.cue(_sites[spot].global_position)
	_swap_sound.cue(_sites[spot].global_position)
	(_spread_long if whole else _spread_short).cue(_sites[spot].global_position)
	var tween := _move(spot)
	tween.tween_method(raise_thing.bind(_index(spot)), JUMP_SCALE, HOVER_SCALE if spot == _hot else 1.0, JUMP_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.position = _rest[spot] + Vector3.UP * 0.002
	_flash.show()
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash, "scale", Vector3.ONE * FLASH_TO, FLASH_TIME).from(Vector3.ONE * FLASH_FROM) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash, "transparency", 1.0, FLASH_TIME).from(0.15)
	_flash_tween.chain().tween_callback(_flash.hide)


## `site`'s parcel shows the pattern `k` of the way out from its token (1: all of it).
func _spread(k: float, site: StringName) -> void:
	_parcels[site] = k
	_print_parcels()


func _spread_done() -> void:
	_spreading = &""
	refresh()


## Hands how far each parcel shows to the land layer (the baked texture's order: the sites as
## `Things` has them, then the head office) and prints the page.
func _print_parcels() -> void:
	var progress := PackedFloat32Array()
	progress.resize(PLACES)
	for i in _sites.size():
		progress[i] = _parcels.get(_sites.keys()[i], 0.0)
	if head_office != Vector3.ZERO:
		progress[_sites.size()] = 1.0
	_parcel_ink.set_shader_parameter(&"progress", progress)
	reprint()


## `site`'s centre on the art (px).
func _pixel(site: StringName) -> Vector2:
	return Vector2(_rest[site].x + SIZE.x / 2.0, _rest[site].z) * PIXELS_PER_METRE


## The refusal's moment on `spot`: the building shakes from side to side, nothing else changes.
func _refuse(spot: StringName) -> void:
	_refuse_sound.cue(_sites[spot].global_position)
	var tween := _move(spot)
	var rest := _rest[spot]
	for side: float in [1.0, -1.0, 0.6, -0.6, 0.0]:
		tween.tween_property(_sites[spot], "position", rest + Vector3.RIGHT * SHAKE * side, SHAKE_TIME / 5.0)


## A fresh tween for `site`'s building, in place of whatever moved it (back on its spot first).
func _move(site: StringName) -> Tween:
	if _moving.has(site):
		_moving[site].kill()
	_sites[site].position = _rest[site]
	_moving[site] = create_tween()
	return _moving[site]


func _index(site: StringName) -> int:
	return _standing.find(_sites[site])


## How far `site`'s building stands up right now (raise_thing's k).
func _raised(site: StringName) -> float:
	var i := _index(site)
	return _standing[i].scale.x / _stand_scale[i].x


func _tag(site: StringName) -> Label:
	return get_node("Page/Sheet/Price_%s" % site) as Label


## The stock cabbages out of the chute: they cannot pay (UpgradeDesk.units_out).
func _out() -> Vector2i:
	return UpgradeDesk.units_out(get_tree().get_nodes_in_group(&"cabbages"))
