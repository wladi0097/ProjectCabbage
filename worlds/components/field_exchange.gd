extends Node
## Chapter 3's swap on the supply console's plinth: once the market intelligence card is stamped
## (SupplyConsole.retired) the console is lifted away (its own doing, SupplyConsole.LIFT_TIME) and
## the FieldLine drops in on its spot; a loaded save that has the card finds it standing there.
## The machine shows how many of the game's farms the company owns (save.farms_owned) and follows
## the count; a farm being bought at the map gets its lamp when its moment there has played
## (FarmRegister.lamp_held), the relay heard from the map. Lifting its handset takes the camera to the map table; once the camera is home again,
## however the player came back (the TO DESK plate, Esc, the debug key), or if it never left (the
## farm TV has it), the handset is hung up.
## The moments, each on its own for the sound pass: the console lifted away (SupplyConsole), the
## machine landing (FieldLine Land), the handset (Lift, LineOpen, HangUp), a lamp relay per farm (Relay).
## Until the line is first answered (save.field_line_answered) the handset rings (FieldLine.ringing).

const Events := preload("res://globalScripts/game_events.gd")

@export var line: FieldLine
@export var map: MapTable

## The machine is on the desk, or on its way down.
var _installed := false
## The handset is up for a call to the maps: hung up once the camera is not away at them.
var _calling := false
var _shown := -1


func _ready() -> void:
	line.line_opened.connect(_on_line_opened)
	line.ringing = not SaveManager.save.field_line_answered
	_installed = SupplyConsole.retired(SaveManager.save)
	line.visible = _installed
	if _installed:
		_show(false)
	else:
		line.position += Vector3.UP * 10.0  # Out of the hand's reach until it drops in (FieldLine keeps its rest).


func _process(_delta: float) -> void:
	var save := SaveManager.save
	if line.digital != DigitalReadout.on(save):
		line.digital = DigitalReadout.on(save)
	if not _installed and SupplyConsole.retired(save):
		_installed = true
		get_tree().create_timer(SupplyConsole.LIFT_TIME).timeout.connect(_install)
	if line.visible and save.farms_owned.size() != _shown and not FarmRegister.lamp_held:
		_show(true)
	if _calling and not map.is_away():
		_calling = false
		line.hang_up()


## The console is gone: the machine falls onto its spot.
func _install() -> void:
	line.visible = true
	line.drop_in()
	_show(false)


func _show(animate: bool) -> void:
	_shown = SaveManager.save.farms_owned.size()
	line.show_farms(_shown, Events.FARMS, animate)


func _on_line_opened() -> void:
	SaveManager.save.field_line_answered = true
	map.go_to_map()
	_calling = true
