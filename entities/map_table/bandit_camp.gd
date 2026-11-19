class_name BanditCamp
extends RefCounted
## Chapter 4's bandit camps (research/gameplan.md "Chapter 4: bandit camps"): once the optional card
## CARD is stamped, camps of former staff squat on company land, one at a time, each a red marker on
## a country of the world sheet (WorldRegister) with its UNREST LEVEL. The first comes at once; the
## clock (UnrestClock, on the map table) then runs EVERY s, and when it runs out the camp standing,
## taken or not, is gone and the next one comes: never a backlog. Clicking a camp lays a RECOVERY
## OPERATION on the world sheet (the war's declaration, no country named); its stamp sends the staff
## chosen to a fight on the war sheet like any war (WarSheet, the same write-off rule). Lost, the camp
## stays until the clock runs out, to be tried again (its fee paid again). Won, it pays REWARD_MINUTES
## of what the company made a minute over the last WINDOW samples (rates): coins, Findings and
## cabbages, each only as far as its limit holds (pay); the map stays empty until the clock runs out.
## THE LADDER: the level is 1 + the camps recovered, at most MAX_LEVEL; a camp lost or gone does not
## raise it. A camp's seed picks its map from SOURCES (chapter 3's hardest) and whether it is mirrored
## top to bottom; its level sets how many times as strong its defences are (buff: hp, and the damage
## they deal, BattleSim's k): from each map's LOW (hard but fair with chapter 3's research and cap)
## to its TOP (barely winnable with every unit and war upgrade, the best army), evenly on a log scale
## (tools/_camp_ladder.gd found both with BattleSim.assess). Only camp fights are buffed: a chapter 3
## war plays as it was tested.
## RESURVEY: once the depot's GENERAL node RESURVEY_NODE is bought, the clock's button replaces the
## camp standing with a new one of the same level (a new seed) and starts the clock over, for
## RESURVEY_MINUTES of coins: a skip, never a farm (the level only rises on wins).
## Pure static rules on the save; the scenes read them. tick() runs every frame (MapTable._process).

const World := preload("res://entities/map_table/world_register.gd")
const War := preload("res://entities/map_table/war_sheet.gd")

## The desk card that starts the camps (UpgradeDesk.CARDS).
const CARD := "civil_unrest"
## The war sheet's farm id for a camp fight (no farm, no country).
const SITE := &"camp"
## Seconds of play each camp stands, and between one camp and the next.
const EVERY := 600.0
## The company's output is sampled every SAMPLE_EVERY s; the rates span the last WINDOW samples.
const SAMPLE_EVERY := 60.0
const WINDOW := 5
## A recovered camp pays this many minutes of the rates; its operation costs FEE_MINUTES of coins.
const REWARD_MINUTES := 5.0
const FEE_MINUTES := 0.25
## The depot GENERAL node that puts RESURVEY on the clock, and what one costs (minutes of coins).
const RESURVEY_NODE := "war_resurvey"
const RESURVEY_MINUTES := 1.0
## The maps camps are cut from (chapter 3's last wars), each with its buff at level 1 (LOW) and at
## MAX_LEVEL (TOP).
const SOURCES: Array[String] = ["lower_provinces-1", "lower_provinces-2", "morrow-1", "morrow-2",
		"nordhal-1", "nordhal-2", "endmark-1", "grauland-1", "grauland-2"]
## LOW is 0.85 times the strongest buff an army under chapter 3's cap (11) wins with chapter 3's research
## (BattleSim level "full"), TOP 0.95 times the strongest one under the top cap (15) wins with every
## unit and war upgrade (level "nuclear"); tools/_camp_ladder.gd, 2026-11-19. lower_provinces-1 and
## grauland-1 still fell at the probe's ceiling (9), so their TOP is a little easier than the rest.
## MAX_LEVEL: TOP is 2.3 to 4 times LOW (2.8 on average), about 10% a level over 12 levels.
const LOW: Dictionary[String, float] = {"lower_provinces-1": 3.35, "lower_provinces-2": 3.51, "morrow-1": 2.6, "morrow-2": 2.31,
		"nordhal-1": 2.5, "nordhal-2": 2.66, "endmark-1": 2.05, "grauland-1": 2.15, "grauland-2": 2.9}
const TOP: Dictionary[String, float] = {"lower_provinces-1": 8.52, "lower_provinces-2": 8.13, "morrow-1": 6.5, "morrow-2": 6.53,
		"nordhal-1": 6.77, "nordhal-2": 8.13, "endmark-1": 5.67, "grauland-1": 8.52, "grauland-2": 6.62}
const MAX_LEVEL := 12
## What the declaration and the war sheet print (keys).
const NAME := "BANDIT CAMP"
const BRIEFING := "Former staff are camping on company land. Both remain company property."
const LEVEL_TEXT := "UNREST LEVEL %d"

## Per SOURCES map, once built: [its k, whether it can be mirrored] (plan).
static var _maps: Dictionary = {}


## Whether the camps run for `save`: the card is stamped.
static func active(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## Whether a camp stands on the map now.
static func is_open(save: SaveGame) -> bool:
	return save.bandit_camp != 0


## The level of the camp standing, or of the next one: 1 + the camps recovered, at most MAX_LEVEL.
static func level(save: SaveGame) -> int:
	return mini(1 + save.camps_recovered, MAX_LEVEL)


## `delta` s of play: the output is sampled, and with the card stamped the clock runs down; at zero
## the camp standing is gone and the next one comes (spawn), unless a camp fight is on (`fighting`)
## or staff are on their way to one (war_pending: stamped, the war sheet not yet up): then it waits.
static func tick(save: SaveGame, delta: float, fighting := false) -> void:
	sample(save, delta)
	if not active(save):
		return
	save.bandit_wait -= delta
	if save.bandit_wait <= 0.0 and not fighting and save.war_pending.is_empty():
		spawn(save)


## Every SAMPLE_EVERY s the totals (coins_earned, findings_earned, cabbages harvested) go into
## save.output_samples, the oldest dropping out past WINDOW.
static func sample(save: SaveGame, delta: float) -> void:
	save.output_clock += delta
	if save.output_samples.is_empty():
		save.output_samples.append(totals(save))
		save.output_clock = 0.0
	while save.output_clock >= SAMPLE_EVERY:
		save.output_clock -= SAMPLE_EVERY
		save.output_samples.append(totals(save))
		while save.output_samples.size() > WINDOW:
			save.output_samples.pop_front()


## The running totals a sample keeps: coins banked, Findings yielded, cabbages harvested.
static func totals(save: SaveGame) -> Array:
	return [save.coins_earned, save.findings_earned, save.hand_harvested + save.tractor_harvested]


## What the company made a minute over the samples (the oldest one to now): {coins, findings, stock}.
static func rates(save: SaveGame) -> Dictionary:
	var out := {coins = 0.0, findings = 0.0, stock = 0.0}
	if save.output_samples.is_empty():
		return out
	var minutes := maxf((save.output_samples.size() - 1) + save.output_clock / SAMPLE_EVERY, 1.0)  # Under a minute in: per minute so far, never blown up.
	var oldest: Array = save.output_samples[0]
	var now := totals(save)
	var i := 0
	for key: String in out:
		out[key] = maxf(float(now[i]) - float(oldest[i]), 0.0) / minutes
		i += 1
	return out


## What recovering a camp now pays: REWARD_MINUTES of rates ({coins, findings, stock}).
static func reward(save: SaveGame) -> Dictionary:
	var r := rates(save)
	return {coins = roundi(r.coins * REWARD_MINUTES), findings = roundi(r.findings * REWARD_MINUTES), stock = roundi(r.stock * REWARD_MINUTES)}


## A new camp in place of any standing: its seed (never 0, a new one each time), its fee (FEE_MINUTES
## of coins now), and the clock starts over.
static func spawn(save: SaveGame) -> void:
	save.camps_spawned += 1
	save.bandit_camp = (hash([save.created, save.camps_spawned]) & 0x7fffffff) | 1
	save.bandit_fee = roundi(rates(save).coins * FEE_MINUTES)
	save.bandit_wait = EVERY


## The country the camp `camp` (its seed) squats in (its marker lies inside its outline).
static func country_of(camp: int) -> StringName:
	var keys := World.COUNTRIES.keys()
	return keys[posmod(camp, keys.size())]


## Map `source`'s buff at `at` (1 .. MAX_LEVEL): LOW to TOP evenly on a log scale; 1 for a map not listed.
static func buff_at(source: String, at: int) -> float:
	var low: float = LOW.get(source, 1.0)
	var top: float = TOP.get(source, low)
	var t := clampf(float(at - 1) / maxf(MAX_LEVEL - 1, 1), 0.0, 1.0)
	return low * pow(top / low, t)


## Camp `camp` (its seed) at level `at`: {source (a SOURCES map id), mirror (flipped top to bottom),
## buff (its defences' multiplier), k (its strength on the k ladder: buff times its map's)}.
static func plan(camp: int, at: int) -> Dictionary:
	var draw := RandomNumberGenerator.new()
	draw.seed = camp
	var source := SOURCES[draw.randi() % SOURCES.size()]
	var mirror := draw.randf() < 0.5
	var known: Array = _maps.get(source, [])
	if known.is_empty():  # Built once per map: its k and whether it flips (the deed reprints often).
		var map: WarMap = load(WarMap.path_of(source)).instantiate()
		known = [float(map.difficulty.get("k", 1.0)), can_mirror(map)]
		map.free()
		_maps[source] = known
	mirror = mirror and bool(known[1])
	var times := buff_at(source, at)
	return {source = source, mirror = mirror, buff = times, k = times * float(known[0])}


## Whether `map` can be flipped top to bottom: nothing would land on the title block's cells.
static func can_mirror(map: WarMap) -> bool:
	for piece: Dictionary in map.layout():
		var flipped := Rect2i(Vector2i(piece.cell.x, map.grid_size.y - piece.cell.y - piece.size.y), piece.size)
		if flipped.intersects(War.TITLE_CELLS):
			return false
	return true


## The standing camp's plan (plan) at its level.
static func current(save: SaveGame) -> Dictionary:
	return plan(save.bandit_camp, level(save))


## The standing camp's map, built (not in the tree yet): its source map, mirrored as planned, named.
static func map_for(save: SaveGame) -> WarMap:
	var p := current(save)
	var map: WarMap = load(WarMap.path_of(p.source)).instantiate()
	if p.mirror:
		for piece in map.pieces():
			piece.position.z = map.grid_size.y * WarMap.CELL - piece.position.z
	map.site_name = NAME
	map.briefing = BRIEFING
	return map


## The standing camp's buff (1: none).
static func buff(save: SaveGame) -> float:
	return float(current(save).buff) if is_open(save) else 1.0


## What the declaration prints as ASSESSED RESISTANCE (FarmDeed.print_resistance): the band of its
## k, and the field associates the strength model says it takes with `save`'s associate research
## (-1: more than `cap`).
static func difficulty(save: SaveGame, cap := 0) -> Dictionary:
	var k: float = current(save).k
	var stats := WarRules.unit_stats(save, "field_associate")
	var base: Dictionary = WarRules.BASE_STATS.field_associate
	var r := float(stats.hp) / float(base.hp) * float(stats.damage) / float(base.damage)
	var associates := ceili(3.0 * pow(k / pow(r, 0.7), 1.55))
	var band := WarMap.band_of(k)
	return {band = band, band_name = WarMap.BAND_NAMES[band - 1], k = k, associates = associates if cap <= 0 or associates <= cap else -1}


## What the operation costs (coins): the camp's fee; nothing with none standing.
static func bill(save: SaveGame) -> Dictionary:
	return {coins = save.bandit_fee} if is_open(save) else {}


## Declares the operation on the standing camp: as FarmRegister.declare, with the camp's bill.
static func declare(save: SaveGame, chosen: Dictionary, out := Vector2i.ZERO) -> bool:
	return is_open(save) and FarmRegister.send(save, bill(save), chosen, out)


## The operation called off before START: its fee comes back. The coins given back.
static func refund(save: SaveGame) -> int:
	save.coins += save.bandit_fee
	return save.bandit_fee


## The camp recovered: its reward is paid (pay), the level goes up, and the map stays empty until the
## clock runs out. What was paid ({coins, findings, stock}).
static func win(save: SaveGame) -> Dictionary:
	var paid := pay(save, reward(save))
	save.camps_recovered += 1
	save.bandit_camp = 0
	save.bandit_fee = 0
	return paid


## The operation lost: the camp stands on, the same, to be tried again.
static func lose(save: SaveGame) -> void:
	save.camps_lost += 1


## Pays `amount` ({coins, findings, stock}) as far as each limit holds: coins and Findings through
## earn, cabbages up to storage_cap. What was paid. Not counted in coins_earned / findings_earned:
## those feed rates, and a reward counted there would raise the next one (RESURVEY, win, repeat).
static func pay(save: SaveGame, amount: Dictionary) -> Dictionary:
	var coins := save.earn(&"coins", int(amount.get("coins", 0)))
	var findings := save.earn(&"findings", int(amount.get("findings", 0)))
	var stock := clampi(int(amount.get("stock", 0)), 0, maxi(save.storage_cap - save.stock, 0))
	save.stock += stock
	return {coins = coins, findings = findings, stock = stock}


## What a RESURVEY costs now (coins).
static func resurvey_price(save: SaveGame) -> int:
	return roundi(rates(save).coins * RESURVEY_MINUTES)


## Whether the clock's RESURVEY can be pressed: the camps run, its node is bought, the coins are there,
## and no operation is under way (staff sent or a fight on: the camp they go for must stay).
## `fighting`: a camp fight is on (UnrestClock passes the war sheet's at_war).
static func can_resurvey(save: SaveGame, fighting := false) -> bool:
	return active(save) and save.tree_bought.has(RESURVEY_NODE) and save.coins >= resurvey_price(save) \
			and save.war_pending.is_empty() and not fighting


## RESURVEY: its coins are paid and a new camp of the same level replaces the one standing (or comes
## to an empty map), the clock starting over. Whether it was done.
static func resurvey(save: SaveGame, fighting := false) -> bool:
	if not can_resurvey(save, fighting):
		return false
	save.coins -= resurvey_price(save)
	spawn(save)
	return true


## The countdown clock's reading: seconds until the camp standing goes and the next one comes; -1
## before the card.
static func countdown(save: SaveGame) -> float:
	return maxf(save.bandit_wait, 0.0) if active(save) else -1.0
