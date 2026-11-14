extends MapSheet
## The war sheet: rolls out when a WAR ORDER is stamped on a farm nobody sells (FarmRegister), with
## that farm's country sheet rolled up in the table's holder. A PLACEHOLDER until the fighting is
## designed (armies, the fighting maps, the boss fight on the final island): a theatre-of-operations
## form that names the farm and its country (begin), an empty field lettered WAR, and a FIELD
## DISPATCH with ONE stand-in action: the DECLARE VICTORY box (the spot VICTORY). A click on it wins
## the war if the dispatch's cost is covered (win: coins and cabbages from stock, WorldRegister's
## `wars` ladder): the farm joins save.farms_owned, VICTORY is stamped on the box, and the sheet asks
## the table for the farm's country sheet again (`sheet_wanted`), where the farm's moment plays
## (FarmRegister.celebrate: the token's swap, the pattern, the Field Line's lamp, held until then).
## Not covered: nothing is taken, what is short flashes. Leaving by the roll in the holder without
## winning costs nothing and leaves nothing behind.
## THE REAL FIGHT REPLACES win(): everything else here (which farm, the way in and out, the farm
## joining the save) stays.
## tools/make_map_sheets.py writes war_sheet.tscn; the lettering this script prints is named there
## (WAR_NAMES). No class_name: whoever needs it preloads this script.

const World := preload("res://entities/map_table/world_register.gd")

## The spot of the open sheet that is the DECLARE VICTORY box.
const VICTORY := &"war_victory"
## From the victory's stamp until the sheet asks for the country sheet again (s).
const LEAVE_AFTER := 0.7
const DENIED_RED := Color(0.9, 0.12, 0.08)
const BLINK_TIME := 0.12

## The DECLARE VICTORY box on the art (px).
@export var victory_box := Rect2()

## The farm the war is for (&"": none yet).
var farm := &""
## The victory playing out (null: none): no click is taken until the sheet has left.
var _dealing: Tween
var _blinking: Tween
var _lacks := {}
var _hot := false

@onready var _farm: Label = $Page/Sheet/Farm
@onready var _country: Label = $Page/Sheet/Country
@onready var _coins: Label = $Page/Sheet/Coins
@onready var _coins_short: Label = $Page/Sheet/CoinsShort
@onready var _cabbages: Label = $Page/Sheet/Cabbages
@onready var _cabbages_short: Label = $Page/Sheet/CabbagesShort
@onready var _imprint: Label = $Page/Sheet/Imprint
@onready var _victory: Label = $Page/Sheet/Victory
@onready var _victory_note: Label = $Page/Sheet/VictoryNote
@onready var _hot_frame: Panel = $Page/Sheet/VictoryHot
@onready var _ink := _coins_short.get_theme_color(&"font_color")
@onready var _strike_sound: SoundCue = $Strike
@onready var _denied_sound: SoundCue = $Denied


func _process(_delta: float) -> void:
	if farm != &"" and _dealing == null and short(SaveManager.save, farm, _out()) != _lacks:
		_print()  # What is short changed while the sheet lies there.


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and farm != &"":
		_print()


## What winning the war on `farm_id` costs `save`, {currency: amount} as UpgradeDesk.costs (the
## stand-in victory: WorldRegister.war_price for its country).
static func price(save: SaveGame, farm_id: StringName) -> Dictionary:
	return {} if save.farms_owned.has(farm_id) else World.war_price(save, World.country_of(farm_id))


## What `save` lacks of that cost, {currency: amount}; empty when it can pay (`out`: UpgradeDesk.units_out).
static func short(save: SaveGame, farm_id: StringName, out := Vector2i.ZERO) -> Dictionary:
	return FarmRegister.lacks(save, price(save, farm_id), out)


## Wins the war on `farm_id` for `save`: the farm joins the farms owned. Whether it was won; refused,
## nothing changes.
## THE REAL FIGHT PLUGS IN HERE (not designed yet): today the stand-in victory is paid for in coins
## and cabbages from stock, and that is the whole war.
static func win(save: SaveGame, farm_id: StringName, out := Vector2i.ZERO) -> bool:
	var bill := price(save, farm_id)
	if bill.is_empty() or not UpgradeDesk.affords(save, bill, out):
		return false
	for paid_in: String in bill:
		UpgradeDesk.pay(save, paid_in, bill[paid_in], out)
	save.farms_owned.append(farm_id)
	return true


## The war on `farm_id` (called `called`, in the country called `country`) starts: the sheet is
## lettered for it, before it rolls out.
func begin(farm_id: StringName, called: String, country: String) -> void:
	farm = farm_id
	_farm.text = "%s  (%s)" % [called, FarmDeed.code(farm_id)]
	_country.text = country
	_imprint.hide()
	_victory.show()
	_victory_note.show()
	_print()


func spot_at(pixel: Vector2) -> StringName:
	return VICTORY if victory_box.has_point(pixel) and _dealing == null and farm != &"" and not _imprint.visible else &""


func hint(spot: StringName) -> String:
	if spot != VICTORY:
		return ""
	var bill := price(SaveManager.save, farm)
	if _lacks.is_empty():
		return tr("Declare victory. Cost: %s.") % FarmRegister.words(bill)
	return tr("Declare victory. Cost: %s. Short: %s.") % [FarmRegister.words(bill), FarmRegister.words(_lacks)]


## The hint slip lies over the empty field, clear of the dispatch.
func hint_pixel() -> Vector2:
	return Vector2(victory_box.end.x + 60.0, victory_box.position.y - 320.0)


func hover(spot: StringName) -> void:
	if (spot == VICTORY) != _hot:
		_hot = spot == VICTORY
		_hot_frame.visible = _hot
		reprint()


## A click on the DECLARE VICTORY box: the war is won if its cost is covered, else the refusal.
func press(spot: StringName) -> void:
	if spot != VICTORY or _dealing != null:
		return
	var bill := price(SaveManager.save, farm)
	if not win(SaveManager.save, farm, _out()):
		_denied_sound.cue(global_position)
		_blink()
		return
	for paid_in: String in bill:  # One log line per currency, as the desk's cards.
		SaveManager.log_event("war_won", farm, bill[paid_in], paid_in)
	SaveManager.autosave()
	FarmRegister.lamp_held = true  # The Field Line's lamp waits for the farm's moment on its country's sheet.
	BossReport.hold = LEAVE_AFTER + MapTable.swap_time() + FarmRegister.LAMP_AFTER + FarmRegister.PAPER_AFTER
	_strike_sound.cue(global_position)
	_imprint.show()
	_victory.hide()
	_victory_note.hide()
	_hot_frame.hide()
	_print()
	_dealing = create_tween()
	_dealing.tween_interval(LEAVE_AFTER)
	_dealing.tween_callback(_leave)


## A victory plays out: the table does not roll the sheet up under it (MapTable.show_sheet).
func busy() -> bool:
	return _dealing != null


func _exit_tree() -> void:
	if _dealing != null:
		FarmRegister.lamp_held = false  # A victory cut off (the scene left) holds no lamp.


func _leave() -> void:
	_dealing = null
	sheet_wanted.emit(World.country_of(farm), farm)


## Prints the dispatch as the save has it: the cost and what is short of it.
func _print() -> void:
	var save := SaveManager.save
	var bill := price(save, farm)
	_lacks = short(save, farm, _out())
	_coins.text = "$" + FarmScreen._thousands(bill.coins) if bill.has("coins") else ""
	_cabbages.text = tr("%s cabbages") % FarmScreen._thousands(bill.stock) if bill.has("stock") else ""
	_coins_short.text = tr("SHORT %s") % ("$" + FarmScreen._thousands(_lacks.coins)) if _lacks.has("coins") else ""
	_cabbages_short.text = tr("SHORT %s") % FarmScreen._thousands(_lacks.stock) if _lacks.has("stock") else ""
	reprint()


## What is short flashes red twice.
func _blink() -> void:
	if _blinking != null:
		_blinking.kill()
	_blinking = create_tween()
	for colour: Color in [_ink, DENIED_RED, _ink, DENIED_RED, _ink]:
		_blinking.tween_callback(_ink_short.bind(colour))
		_blinking.tween_interval(BLINK_TIME)


func _ink_short(colour: Color) -> void:
	for label: Label in [_coins_short, _cabbages_short]:
		label.add_theme_color_override(&"font_color", colour)
	reprint()


## The stock cabbages out of the chute: they cannot pay (UpgradeDesk.units_out).
func _out() -> Vector2i:
	return UpgradeDesk.units_out(get_tree().get_nodes_in_group(&"cabbages"))
