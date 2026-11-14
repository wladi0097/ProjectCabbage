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
## - Paid for: the price in coins and cabbages from stock is taken at once (UpgradeDesk.pay, as the
##   desk's cards) and the site joins save.farms_owned; then, in order (the constants below): the
##   stamp comes down on the deed and stays for a hit pause; the token takes its owned look and jumps
##   with a flash, its tag flips to ACQUIRED and the cabbage pattern spreads over its parcel; the
##   Field Line lights the farm's lamp (lamp_held keeps it dark until then); the deed rolls itself up and drops off the map. No click is
##   taken until it is gone, and the boss's paper waits PAPER_AFTER longer.
## - Not paid for: nothing is taken, the stamp stays up, the token shakes its head and what is short
##   flashes on the deed (it is marked there all along).
## The first farm is sold freely. The next four print NOT FOR SALE until their card is stamped
## (GATES: NEGOTIATION for the 2nd to 4th, BRIBERY for the 5th); then each can be haggled over on
## its deed before it is stamped (the negotiation, below). Any site can be the next one bought: the
## price goes by how many farms are owned (PRICES).
## WAR takes what nobody sells, one farm at a time: at home the last three, abroad every farm
## (nothing is bought or haggled over abroad). Until the card WAR_CARD is stamped such a farm prints
## NOT FOR SALE and its paper wears that strip. With it (war_ready) the paper is a WAR ORDER
## (FarmDeed.FORMS): it prints what the war is expected to cost (WorldRegister.war_price) and its
## stamp starts the war: nothing is paid, the sheet asks the table for the war sheet of that farm
## (`sheet_wanted`), where the war is won or left (WarSheet). A farm that cannot be attacked yet
## (WorldRegister.reach: no neighbouring country is wholly ours, or the sea is not open) gets the
## order with a strip saying why and no stamp box. Back from a war won, the table has the sheet
## play the farm's moment (expect, celebrate): the token's swap, the tag, the pattern, the lamp.
## The land (`Page/Sheet/Layers/Parcels`, assets/shaders/farm_parcels.gdshader): the art prints the
## whole country in the cabbage pattern; the layer greys what is not the company's. A farm's parcel
## is the land nearer to it than to any other site, out to PARCEL_RADIUS; the head office keeps its
## own patch (head_office, at home). Once every farm of the country is ours the whole country shows
## the pattern (as its overlay on the world sheet does). Owned parcels show from the save.
## Owned sites show as owned from the save, without the moment (also farms from the debug key).
##
## The negotiation (decided with the user 2026-11-14; its numbers are provisional, paced in
## tools/pace.py: `python tools/pace.py haggle`). The deed of a farm behind a card shows the owner's
## asking price (PRICES) and takes up to ROUNDS offers before it
## is stamped; it may be stamped at any time at the price it then shows. An offer is cabbages from
## stock put on the dial (ladder) and submitted; for the farm behind BRIBERY it is coins in an
## envelope (tender). The owner has a number in mind (wanted: drawn per farm between HAGGLES' `low`
## and `high`, dearer farms higher and wider; never shown, and fixed by the save's `created`, so a
## reload cannot change it). What is offered is gone either way (offer). At least his number: the
## price drops; less: it goes up (MOOD_STEP, in percent of the asking price, between PRICE_FLOOR
## and PRICE_CEILING; its coins and its cabbages move together, by the same percentage: price; the ceiling may be more than the purse holds, the next TREASURY step holds it). His mood is stamped on
## the deed after each offer and is the only clue (Mood, MOOD_FROM: the offer as a share of his
## number). After every offer that landed he wants GREED times as much. With the card RECOVER
## (RECOVER REJECTED GOODS) RECOVERED of an offer that missed comes back. The offers made and the
## price they left are in the save (haggle_offers, haggle_price) until the farm is bought.
## On the sheet: the dial's `<` and `>` (LESS, MORE) turn it a notch, SUBMIT OFFER (OFFER) takes the
## offer at once, the stamp comes down on the mood (as the purchase's, no click meanwhile) and the
## price reprints as it lands.
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

## What the 1st .. 5th farm costs, in coins and in cabbages from stock (paced in tools/pace.py:
## `python tools/pace.py ch3`). The cabbages are a harvest drive of 2-3 min at the TV each, quicker
## with every farm square and FARM OUTPUT step, and from the second farm on more than the store
## before it holds: 2,000 needs SALT MINE (3,000), 3,500 the 4,000 step, 5,500 the 6,000, 9,000
## the 9,999 (Projector's storage chain behind BIG MINDS HAVE BIG IDEAS). The last two farms are
## walled by their cabbages, not their coins (pace.py wanted $1.5M and $5M for them).
const PRICES: Array[Dictionary] = [
	{coins = 60000, stock = 800},
	{coins = 200000, stock = 2000},
	{coins = 450000, stock = 3500},
	{coins = 1500000, stock = 5500},
	{coins = 5000000, stock = 9000},
]
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
## offer lies between `low` and `high` (cabbages; coins for the bribe), and the dial starts at `least`.
## PROVISIONAL (tools/pace.py haggle): a share of what one step off the price is worth at the deed's
## own rate (its coins per cabbage), wider with every farm.
const HAGGLES: Array[Dictionary] = [
	{},
	{low = 35, high = 85, least = 30},
	{low = 40, high = 160, least = 30},
	{low = 50, high = 260, least = 40},
	{low = 40000, high = 250000, least = 30000},
]
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
## The dial's notches: these in every decade, LADDER of them from the farm's `least` up.
const RUNGS: Array[int] = [10, 15, 20, 30, 40, 50, 75]
const LADDER := 12
## The spots of the laid-out deed's dial and its SUBMIT OFFER box (FarmDeed.BOXES).
const LESS := &"deed_less"
const MORE := &"deed_more"
const OFFER := &"deed_offer"
## A site's click target on the art, around its centre (px): its disc and the two tags below it.
const HIT := Rect2(-115, -90, 230, 285)
## What the hint slip covers of the art (px): MapTable.SPOT_HINT_WIDTH and six lines at the map
## camera, at about 1.75 art pixels a screen pixel (hint_pixel).
const HINT_ROOM := Vector2(740, 400)
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
## spreads over the parcel for PARCEL_TIME; LAMP_AFTER later the Field Line may light its lamp;
## DEED_LEAVE_AFTER later the deed rolls up (DEED_ROLL_TIME) and drops off the map (DEED_DROP_TIME).
const STAMP_DROP_TIME := 0.14
const HIT_PAUSE := 0.09
const STAMP_LIFT_TIME := 0.3
const PARCEL_TIME := 0.8
const LAMP_AFTER := 0.75
const DEED_LEAVE_AFTER := 0.45
const DEED_ROLL_TIME := 0.34
const DEED_DROP_TIME := 0.28
## A farm's parcel reaches this far from its site (px), where no other site is nearer.
const PARCEL_RADIUS := 300.0
## A parcel of a country that is wholly ours reaches this far (px): all of the sheet.
const FULL := 5000.0
## The land layer takes this many places (farm_parcels.gdshader `sites`): the sites and the head
## office; the rest lie far off the sheet.
const PLACES := 9
const NOWHERE := Vector3(-1e6, -1e6, 0.0)
## The whole country turns in this many seconds when its last farm is taken.
const COUNTRY_TIME := 1.4
## Refused, it shakes this far to either side (m, on the sheet).
const SHAKE := 0.012
const SHAKE_TIME := 0.28

## The head office on the art (px) and how far its own patch reaches (px): company land from the
## start. Zero on a sheet without one (every country but the home country).
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
## The site whose deed lies on the sheet (&"": none), the deed's top left corner on the art (px)
## and what it marks as short.
var _deed_site := &""
var _deed_corner := Vector2.ZERO
var _deed_lacks := {}
## The purchase playing out (null: none): no click is taken until its deed is gone.
var _dealing: Tween
## The site just paid for whose token still waits for the stamp to land, and the one whose parcel
## is spreading right now.
var _pending := &""
var _spreading := &""
var _spread_tween: Tween
## How much of each site's parcel shows the pattern (0..1), and how far a whole parcel reaches (px).
var _parcels: Dictionary[StringName, float] = {}
var _parcel_reach := PARCEL_RADIUS
## The box of the deed under the mouse (FarmDeed.BOXES; &"": none), and the notch its dial stands on.
var _hot_box := &""
var _dial := 0
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
	elif _dealing == null and lacks(SaveManager.save, _deed_bill(), _out()) != _deed_lacks:
		_print_deed()  # What is short changed while it lies there.


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()  # The tags' wording changed.


## What the next home farm's owner asks of `save`, {currency: amount} as UpgradeDesk.costs; nothing
## while nobody sells: its card (GATES) is not stamped, or five are owned (the rest is war).
static func asking(save: SaveGame) -> Dictionary:
	var owned := save.farms_owned.size()
	if owned >= mini(Events.HOME_SELLERS, PRICES.size()) or (gate(save) != "" and not save.stamped.has(gate(save))):
		return {}
	return PRICES[owned]


## What the next home farm costs `save` now: the asking price as the offers made have left it. The
## save keeps the coins (save.haggle_price); the cabbages move by the same share of what was asked.
static func price(save: SaveGame) -> Dictionary:
	var bill := asking(save)
	if bill.is_empty() or save.haggle_price <= 0:
		return bill
	return {coins = save.haggle_price, stock = roundi(bill.stock * float(save.haggle_price) / bill.coins)}


## The card the next farm waits for (GATES), stamped or not; "" when it needs none.
static func gate(save: SaveGame) -> String:
	var owned := save.farms_owned.size()
	return GATES[owned] if owned < GATES.size() else ""


## What the next farm's owner is offered: "stock" (cabbages) behind NEGOTIATION, "coins" (a bribe)
## behind BRIBERY; "" where nobody haggles (the first farm, a farm not for sale).
static func tender(save: SaveGame) -> String:
	if asking(save).is_empty() or gate(save) == "":
		return ""
	return "coins" if gate(save) == BRIBE else "stock"


## What the next farm's owner has in mind after `wins` offers that landed: at least this much lands.
## Drawn once per save and farm (save.created, the farms owned), so a reload never changes it.
## Never shown to the player.
static func wanted(save: SaveGame, wins: int) -> int:
	var haggle := HAGGLES[save.farms_owned.size()]
	var draw := RandomNumberGenerator.new()
	draw.seed = hash([save.created, save.farms_owned.size()])
	return roundi(lerpf(haggle.low, haggle.high, draw.randf()) * pow(GREED, wins))


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


## The owner's mood after each offer made for the next farm so far (save.haggle_offers), in order.
static func moods(save: SaveGame) -> Array[int]:
	var out: Array[int] = []
	var wins := 0
	for offered in save.haggle_offers:
		out.append(mood_of(offered, wanted(save, wins)))
		wins += int(landed(out[-1]))
	return out


## The lowest the next farm's coin price goes (PRICE_FLOOR).
static func floor_price(save: SaveGame) -> int:
	return roundi(asking(save).coins * (100 + PRICE_FLOOR) / 100.0)


## How many more offers the next farm's owner hears: ROUNDS in all; none where nobody haggles, and
## none once the price is at its floor (an offer could only be lost).
static func offers_left(save: SaveGame) -> int:
	if tender(save) == "" or price(save).coins <= floor_price(save):
		return 0
	return maxi(ROUNDS - save.haggle_offers.size(), 0)


## The next farm's coin price after an offer that left the owner in `mood`: MOOD_STEP percent of the
## asking price on or off it, between the floor and the ceiling. The ceiling is not held to the coin
## limit (a miss must cost something at the limit a player has): the next TREASURY step holds it and
## costs less than the limit (the suite walks that).
static func price_after(save: SaveGame, mood: int) -> int:
	var asked: int = asking(save).coins
	return clampi(price(save).coins + roundi(asked * MOOD_STEP[mood] / 100.0), floor_price(save), roundi(asked * (100 + PRICE_CEILING) / 100.0))


## Puts `amount` (cabbages from the store, or coins: tender) to the next farm's owner: it is gone
## whether it lands or not (RECOVERED of a miss comes back once RECOVER is stamped), the price moves
## (price_after) and the offer is on file. The mood it leaves him in (Mood), or -1 when no offer is
## taken and nothing changes: nobody haggles, no offer left, or `save` does not hold `amount` (`out`:
## UpgradeDesk.units_out).
static func offer(save: SaveGame, amount: int, out := Vector2i.ZERO) -> int:
	var paid_in := tender(save)
	if offers_left(save) <= 0 or amount <= 0 or UpgradeDesk.spendable(save, paid_in, out) < amount:
		return -1
	var mood := mood_of(amount, wanted(save, moods(save).reduce(func(wins: int, was: int) -> int: return wins + int(landed(was)), 0)))
	UpgradeDesk.pay(save, paid_in, amount, out)
	if not landed(mood) and save.stamped.has(RECOVER):
		save.set(paid_in, save.get(paid_in) + int(amount * RECOVERED))
	save.haggle_price = price_after(save, mood)
	save.haggle_offers.append(amount)
	return mood


## The negotiation for the next farm starts over: no offer on file, the asking price again.
static func close_haggle(save: SaveGame) -> void:
	save.haggle_offers = PackedInt32Array()
	save.haggle_price = 0


## The amounts the dial clicks through for a farm whose HAGGLES entry starts it at `least`.
static func ladder(least: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var decade := 1
	while out.size() < LADDER:
		for rung in RUNGS:
			if rung * decade >= least and out.size() < LADDER:
				out.append(rung * decade)
		decade *= 10
	return out


## The small print of a deed that is haggled over, until the first offer (a translation key).
static func haggle_note(save: SaveGame) -> String:
	if save.stamped.has(RECOVER):
		return "Half of a refused offer is returned."
	return "Envelopes are not returned." if tender(save) == "coins" else "Cabbages offered are not returned."


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


## What the war on `site` is expected to cost `save` (the stand-in victory, WorldRegister.war_price);
## nothing where there is no war to start: not war_ready, or out of reach (WorldRegister.reach).
static func war_bill(save: SaveGame, site: StringName) -> Dictionary:
	var country := World.country_of(site)
	return World.war_price(save, country) if war_ready(save, site) and World.reach(save, country) == "" else {}


## Where the deed for the site at art pixel `at` lies: its top left corner on the art (px). Beside
## the site (deed_side), level with it, inside the sheet: never on the site.
static func deed_corner(at: Vector2) -> Vector2:
	var size := FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE
	var x := at.x + DEED_GAP if deed_side(at) > 0.0 else at.x - DEED_GAP - size.x
	var room := SIZE * PIXELS_PER_METRE - size - Vector2.ONE * DEED_MARGIN
	return Vector2(x, clampf(at.y - size.y / 2.0, DEED_MARGIN, room.y))


## The side of the site at art pixel `at` its deed lies on, and comes from: -1 map-left, 1
## map-right. The side away from the sheet's middle, so the map stays in view; where the paper has
## no room there (a site near the sheet's edge), the side towards the middle.
static func deed_side(at: Vector2) -> float:
	var width := SIZE.x * PIXELS_PER_METRE
	var out := -1.0 if at.x < width / 2.0 else 1.0
	var need := DEED_GAP + FarmDeed.SIZE.x * FarmDeed.PIXELS_PER_METRE + DEED_MARGIN
	return out if (at.x if out < 0.0 else width - at.x) >= need else -out


## Seconds from the click on the stamp box until the deed has left the map.
static func deed_gone_after() -> float:
	return STAMP_DROP_TIME + HIT_PAUSE + LAMP_AFTER + DEED_LEAVE_AFTER + DEED_ROLL_TIME + DEED_DROP_TIME


## Whether `site` can still be bought: a home farm, not ours yet, and somebody still sells.
static func for_sale(save: SaveGame, site: StringName) -> bool:
	return World.country_of(site) == World.HOME and not save.farms_owned.has(site) and not price(save).is_empty()


## What `save` lacks of the next farm's price, {currency: amount}; empty when it can pay (`out`:
## UpgradeDesk.units_out, cabbages out of the store can't pay).
static func short(save: SaveGame, out := Vector2i.ZERO) -> Dictionary:
	return lacks(save, price(save), out)


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
	var bill := price(save)
	if not for_sale(save, site) or not UpgradeDesk.affords(save, bill, out):
		return false
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
	save.farms_owned.append(site)
	close_haggle(save)  # The next owner starts from his own asking price.
	return true


## What `site`'s price tag prints: the next farm's price ("$60K + 800": coins + cabbages; the tag
## is small, so coins from 10,000 are set in whole thousands and from a million in millions,
## "$1.5M"; the hint slip has them in full),
## ACQUIRED once ours; for a farm taken by war what the war is expected to cost, or why it cannot be
## attacked (WorldRegister.reach); NOT FOR SALE while nobody sells and there is no war card.
static func tag_text(save: SaveGame, site: StringName) -> String:
	if save.farms_owned.has(site):
		return TranslationServer.translate("ACQUIRED")
	var bill := price(save) if for_sale(save, site) else war_bill(save, site)
	if bill.is_empty():
		return TranslationServer.translate(World.reach(save, World.country_of(site)) if war_ready(save, site) else "NOT FOR SALE")
	return "$%s + %s" % [short_coins(bill.coins), FarmScreen._thousands(bill.stock)]


## `coins` as a price tag sets them: "9,500", "900K", "1.5M".
static func short_coins(coins: int) -> String:
	if coins >= 999500:  # Would round to 1000K.
		return String.num(coins / 1000000.0, 1).trim_suffix(".0") + "M"
	if coins >= 10000:
		return str(roundi(coins / 1000.0)) + "K"
	return FarmScreen._thousands(coins)


## `bill` in words: "$30,000, 300 cabbages".
static func words(bill: Dictionary) -> String:
	var parts := PackedStringArray()
	if bill.has("coins"):
		parts.append("$" + FarmScreen._thousands(bill.coins))
	if bill.has("stock"):
		parts.append(TranslationServer.translate("%s cabbages") % FarmScreen._thousands(bill.stock))
	return ", ".join(parts)


## The hint slip for `site` called this name: its price (and what is short of it), that it is ours,
## or why it cannot be bought.
static func hint_text(save: SaveGame, site: StringName, called: String, out := Vector2i.ZERO) -> String:
	if save.farms_owned.has(site):
		return TranslationServer.translate("%s. Company property.") % called
	if war_ready(save, site):
		var country := World.country_of(site)
		if World.reach(save, country) != "":
			return TranslationServer.translate("%s. Not for sale.") % called + " " + World.reason(save, country)
		return TranslationServer.translate("%s. Not for sale. Expected cost of war: %s. Click for the war order.") % [called, words(war_bill(save, site))]
	if not for_sale(save, site):
		return TranslationServer.translate("%s. Not for sale.") % called + " " + reason(save, site)
	var missing := short(save, out)
	if missing.is_empty():
		return TranslationServer.translate("%s. Price: %s. Click for the deed.") % [called, words(price(save))]
	return TranslationServer.translate("%s. Price: %s. Short: %s.") % [called, words(price(save)), words(missing)]


static func _state(save: SaveGame) -> Vector3i:
	return Vector3i(save.farms_owned.size(), save.stamped.size(), save.haggle_price)


## Shows every site as the save has it (owned look, tag), without any moment, and prints the page.
func refresh() -> void:
	var save := SaveManager.save
	if _shown.x >= 0 and save.farms_owned.size() != _shown.x:
		close_haggle(save)  # A farm came some other way (the debug key): the offers were for another owner.
	_shown = _state(save)
	_parcel_reach = FULL if World.owns_all(save, id) and _pending == &"" and _spreading == &"" else PARCEL_RADIUS
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
		var on := pixel - _deed_corner
		if Rect2(Vector2.ZERO, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE).has_point(on):
			# The deed covers what lies under it; only its boxes are spots: the stamp box of a farm
			# for sale, the dial and SUBMIT OFFER while its owner hears offers.
			var box := FarmDeed.box_at(on)
			var live := not _deed.bill.is_empty() if box == STAMP else offers_left(SaveManager.save) > 0
			return box if _dealing == null and live else &""
	for site in _sites:
		if HIT.has_point(pixel - _pixel(site)):
			return site
	return &""


## Nothing while a deed lies on the sheet: it says all of it, and the slip would lie on it.
func hint(spot: StringName) -> String:
	return hint_text(SaveManager.save, spot, _sites[spot].title, _out()) if _sites.has(spot) and _deed_site == &"" else ""


func hover(spot: StringName) -> void:
	var box := spot if FarmDeed.BOXES.has(spot) else &""
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


## A click on `spot` (&"": on nothing): the stamp box buys the deed's farm, the dial's boxes turn it
## a notch, SUBMIT OFFER makes the offer, a farm not ours lays out its deed, anything else puts the
## deed away. Nothing while a purchase or an offer plays out.
func press(spot: StringName) -> void:
	if _dealing != null:
		return
	if spot == STAMP and _deed_site != &"":
		_stamp_deed()
	elif spot in [LESS, MORE] and _deed_site != &"":
		_turn_dial(1 if spot == MORE else -1)
	elif spot == OFFER and _deed_site != &"":
		_submit_offer()
	elif _sites.has(spot) and spot != _deed_site and not SaveManager.save.farms_owned.has(spot) and spot != _pending:
		_lay_out(spot)
	else:
		_put_away()


## A purchase or an offer plays out: the table does not roll the sheet up under it (MapTable.show_sheet).
func busy() -> bool:
	return _dealing != null


## The site whose deed lies on the sheet, or &"".
func deed_site() -> StringName:
	return _deed_site


## Lays `spot`'s deed beside it: it slides in from beyond the sheet's edge on its side.
func _lay_out(spot: StringName) -> void:
	_deed_site = spot
	_deed_corner = deed_corner(_pixel(spot))
	_dial = 0
	var offers := SaveManager.save.haggle_offers
	if not offers.is_empty():  # The dial stands where the last offer left it.
		_dial = maxi(_ladder().find(offers[-1]), 0)
	_print_deed()
	_uncover(0.0)
	var paper := Rect2(_deed_corner, FarmDeed.SIZE * FarmDeed.PIXELS_PER_METRE).grow(COVER)
	for site in _sites:
		if site != spot and paper.has_point(_pixel(site)):
			_tucked.append(site)
			_move(site).tween_method(raise_thing.bind(_index(site)), 1.0, 0.0, TUCK_TIME)
	var to := _deed_at()
	_deed.slide(to + Vector3.RIGHT * deed_side(_pixel(spot)) * DEED_FROM / PIXELS_PER_METRE, to, DEED_SLIDE_TIME)


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
	if tender(save) != "" and for_sale(save, _deed_site):
		_deed.print_haggle(tender(save), _ladder()[_dial], save.haggle_offers, moods(save), offers_left(save), asking(save).coins, haggle_note(save))
	_deed.hot(_hot_box)  # The mouse may still be on its box.


## What the laid-out paper prints as its price: the purchase price of a farm for sale, what the war
## on one that is taken is expected to cost, nothing where neither is to be had.
func _deed_bill() -> Dictionary:
	var save := SaveManager.save
	return price(save) if for_sale(save, _deed_site) else war_bill(save, _deed_site)


## The amounts the laid-out deed's dial clicks through (ladder); one notch where nobody haggles.
func _ladder() -> PackedInt32Array:
	var save := SaveManager.save
	return ladder(HAGGLES[save.farms_owned.size()].least) if tender(save) != "" else PackedInt32Array([0])


## The dial turns `by` notches, as far as the ladder goes.
func _turn_dial(by: int) -> void:
	var to := clampi(_dial + by, 0, _ladder().size() - 1)
	if to == _dial:
		return
	_dial = to
	_deed.tick()
	_print_deed()


## A click on SUBMIT OFFER: what is on the dial goes to the owner (offer) and the stamp comes down
## on his mood; the deed prints it, and the new price, as it lands. Not held: refused, nothing changes.
func _submit_offer() -> void:
	var bribe := tender(SaveManager.save) == "coins"
	var mood := offer(SaveManager.save, _ladder()[_dial], _out())
	if mood < 0:
		_deed.blink()
		return
	if bribe:
		_deed.envelope()
	var save := SaveManager.save
	SaveManager.log_event("offer", str(save.farms_owned.size() + 1), save.haggle_offers[-1], tender(save))
	SaveManager.autosave()  # At once: quitting must not take a lost offer back and keep what the mood told.
	_deed.strike(STAMP_DROP_TIME, FarmDeed.MOOD_AT)
	_dealing = create_tween()
	_dealing.tween_interval(STAMP_DROP_TIME)
	_dealing.tween_callback(_mood_landed.bind(landed(mood)))
	_dealing.tween_interval(HIT_PAUSE)
	_dealing.tween_callback(_deed.lift_stamp.bind(STAMP_LIFT_TIME))
	_dealing.tween_interval(STAMP_LIFT_TIME)
	_dealing.tween_callback(_offer_done)


func _mood_landed(won: bool) -> void:
	_print_deed()
	_deed.stamp_mood(won)


func _offer_done() -> void:
	_dealing = null


## The deed slides off the sheet the way it came, unstamped.
func _put_away() -> void:
	if _deed_site == &"":
		return
	var from := _deed_at()
	_deed.slide(from, from + Vector3.RIGHT * deed_side(_pixel(_deed_site)) * DEED_FROM / PIXELS_PER_METRE, DEED_SLIDE_TIME, true)
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
	return Vector3((_deed_corner.x + FarmDeed.SIZE.x * FarmDeed.PIXELS_PER_METRE / 2.0) / PIXELS_PER_METRE - SIZE.x / 2.0,
			DEED_LIFT, _deed_corner.y / PIXELS_PER_METRE)


## A click on the stamp box. On a war order it starts the war: the stamp comes down, and the sheet
## asks for the war sheet of that farm (nothing is paid here). On a deed it is the purchase if it is
## paid for (the rest plays out from here, see the constants), else the refusal and nothing bought.
func _stamp_deed() -> void:
	var spot := _deed_site
	if war_ready(SaveManager.save, spot):
		_deed.strike(STAMP_DROP_TIME)
		_dealing = create_tween()
		_dealing.tween_interval(STAMP_DROP_TIME)
		_dealing.tween_callback(_deed.imprint)
		_dealing.tween_interval(HIT_PAUSE)
		_dealing.tween_callback(_deed.lift_stamp.bind(STAMP_LIFT_TIME))
		_dealing.tween_interval(WAR_AFTER)
		_dealing.tween_callback(_go_to_war.bind(spot))
		return
	var bill := price(SaveManager.save)
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
	var off := _deed_at() + Vector3.RIGHT * deed_side(_pixel(spot)) * DEED_FROM / PIXELS_PER_METRE
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


## The hint slip lies in the first corner of the sheet (top left, top right, bottom left, bottom
## right) where its HINT_ROOM covers no site's disc or tags; every country's sites lie elsewhere.
func hint_pixel() -> Vector2:
	var paper := SIZE * PIXELS_PER_METRE
	var far := paper - HINT_ROOM - HINT_PIXEL
	for corner: Vector2 in [HINT_PIXEL, Vector2(far.x, HINT_PIXEL.y), Vector2(HINT_PIXEL.x, far.y), far]:
		var slip := Rect2(corner, HINT_ROOM)
		if _sites.keys().all(func(site: StringName) -> bool: return not slip.intersects(Rect2(HIT.position + _pixel(site), HIT.size))):
			return corner
	return HINT_PIXEL


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
	_spread_tween.tween_method(_spread.bind(spot), 0.0, 1.0, PARCEL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var whole := World.owns_all(SaveManager.save, id)  # The country's last farm: all of its land turns.
	if whole:
		_spread_tween.tween_method(_spread_country, PARCEL_RADIUS, span(), COUNTRY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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


## Every parcel reaches `reach` px: the whole country turning, once its last farm is ours.
func _spread_country(reach: float) -> void:
	_parcel_reach = reach
	_print_parcels()


func _spread_done() -> void:
	_spreading = &""
	refresh()


## How far the sheet's land can lie from a site (px): its diagonal.
func span() -> float:
	return (SIZE * PIXELS_PER_METRE).length()


## Hands every parcel's reach to the land layer and prints the page.
func _print_parcels() -> void:
	var reach := PackedVector3Array()
	for site in _sites:
		reach.append(Vector3(_pixel(site).x, _pixel(site).y, _parcel_reach * _parcels.get(site, 0.0)))
	if head_office != Vector3.ZERO:  # Its own patch; with the whole country ours it reaches as far as the parcels.
		reach.append(Vector3(head_office.x, head_office.y, maxf(head_office.z, _parcel_reach if _parcel_reach > PARCEL_RADIUS else 0.0)))
	while reach.size() < PLACES:
		reach.append(NOWHERE)
	_parcel_ink.set_shader_parameter(&"sites", reach)
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
