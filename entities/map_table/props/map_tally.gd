extends Node3D
## The map table's tally (chapter 3, once its desk card is stamped: MapTable.TALLY_CARD): a long steel
## counter lying left of the sheet, below the TO DESK button, one
## split-flap window for everything the company holds, top to bottom: coins ($), cabbages in stock
## (the cabbage sign, green), Findings (¶, cold cyan) and farms owned of all there are. A black plate
## left of each window carries its sign; no words. Farms are bought at the map, where the desk's own
## counters are out of sight.
## Its housing runs on up into a console deck (`Console`) carrying TO DESK and TO FARM (desk_button
## instances, plinths sunk into the deck); MapTable shows and clicks them once the tally has landed.
## The windows print the save as the map's price tags and the Field Line do (readout): they follow
## it every frame. While the camera is at the map (`live`, set by MapTable) a window whose number
## changes flicks its flaps over (FLICK_TIME, the new flap coming up out of the dark) with one `Tick`,
## at most once in REST seconds a window; away from the
## map, and on a loaded save, the numbers change silently.
## A window whose number is at its limit (coins and Findings: SaveGame.room is 0, nothing more comes
## in) prints it in FULL_INK, the desk counters' FULL red, and flicks over as it turns; under the
## limit again it flicks back to its own colour.

const Events := preload("res://globalScripts/game_events.gd")

## A changed window's flaps come over from FLICK_FROM of their height in FLICK_TIME s, the number
## coming up from DIM times its ink in LIGHT_TIME s (it keeps its colour: green stays green).
const FLICK_FROM := 0.3
const FLICK_TIME := 0.22
const DIM := 0.35
const LIGHT_TIME := 0.3
## A window flicks at most once in this many seconds: a number that ticks all the time (cabbages
## while the hands sell) changes quietly in between and stays readable.
const REST := 2.0
## The ink of a number at its limit (the desk counters' FULL plate).
const FULL_INK := Color(0.9, 0.12, 0.08)

## Whether changes are shown off (the camera is at the map).
var live := false

var _inks: Array[Color] = []
var _flicks: Array[Tween] = [null, null, null, null]
## When each window last flicked (s, the engine's clock).
var _flicked_at: Array[float] = [-REST, -REST, -REST, -REST]
## Which windows print in FULL_INK right now.
var _full: Array[bool] = [false, false, false, false]

@onready var _windows: Array[Label3D] = [$Windows/Coins, $Windows/Cabbages, $Windows/Findings, $Windows/Farms]
@onready var _tick: SoundCue = $Tick


func _ready() -> void:
	for window in _windows:
		_inks.append(window.modulate)
	show_save(SaveManager.save, false)


func _process(_delta: float) -> void:
	show_save(SaveManager.save, live)


## What the four windows print for `save`: coins and Findings as a price tag sets them
## (FarmRegister.short_coins: "9,500", "900K", "1.5M"), the cabbages in stock in full, the farms as
## the Field Line's count window ("7/24").
static func readout(save: SaveGame) -> PackedStringArray:
	return PackedStringArray([
		FarmRegister.short_coins(save.coins),
		FarmScreen._thousands(save.stock),
		FarmRegister.short_coins(save.findings),
		FieldLine.count_text(save.farms_owned.size(), Events.FARMS),
	])


## Which of the four windows hold all `save` may hold: coins and Findings at their limits.
static func at_limit(save: SaveGame) -> Array[bool]:
	return [save.room(&"coins") <= 0, false, save.room(&"findings") <= 0, false]


## Prints `save` in the windows; with `animate`, every window whose number changed flicks over, and
## one that reached or left its limit always does (it changes colour).
func show_save(save: SaveGame, animate := true) -> void:
	var texts := readout(save)
	var full := at_limit(save)
	for i in _windows.size():
		var turned := full[i] != _full[i]
		_full[i] = full[i]
		if turned:
			_windows[i].modulate = _ink(i)
		if _windows[i].text != texts[i] or turned:
			_windows[i].text = texts[i]
			if animate and (turned or rested(_now() - _flicked_at[i])):
				_flick(i)


## Whether a window that last flicked `since` seconds ago may flick again.
static func rested(since: float) -> bool:
	return since >= REST


## Whether window `i` (0 coins .. 3 farms) is flicking over right now.
func flicking(i: int) -> bool:
	return _flicks[i] != null and _flicks[i].is_running()


## Window `i`'s ink right now: its own, or FULL_INK at its limit.
func _ink(i: int) -> Color:
	return FULL_INK if _full[i] else _inks[i]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _flick(i: int) -> void:
	_flicked_at[i] = _now()
	if _flicks[i] != null:
		_flicks[i].kill()
	_tick.cue(_windows[i].global_position)
	_flicks[i] = create_tween().set_parallel()
	_flicks[i].tween_property(_windows[i], "scale:y", 1.0, FLICK_TIME).from(FLICK_FROM) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flicks[i].tween_property(_windows[i], "modulate", _ink(i), LIGHT_TIME).from(_ink(i).darkened(1.0 - DIM))
