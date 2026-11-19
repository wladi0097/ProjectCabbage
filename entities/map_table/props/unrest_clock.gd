extends Node3D
## The unrest clock on the map table (MapTable `UnrestClock`), above the sheet's top edge in the
## middle: a gunmetal plate with a green segment readout behind smoked glass, like the desk's digital
## counters (DigitalReadout), counting down to the next bandit camp (BanditCamp.countdown). Its
## stencilled caption says what the count is for: NEXT CAMP IN on an empty map, CAMP STANDS, LEVEL n,
## GONE IN while one stands (it goes when the count runs out). Hidden until the camps' card. Its oxblood
## push button (`Resurvey`, the map table's desk button) stands beside it once the depot's REVISED SITE
## SURVEY is bought (BanditCamp.RESURVEY_NODE): MapTable picks its `Plate` (RESURVEY) and calls resurvey.

@onready var _ink: Label3D = $Glass/Ink
@onready var _caption: Label3D = $Caption
@onready var _button: Node3D = $Resurvey
@onready var _denied: SoundCue = $Denied


## Seconds as the readout prints them: "09:41"; "--:--" for none.
static func clock_text(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--"
	var whole := ceili(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


## The caption (a key) and its level for `save`: an empty map, or a camp standing.
static func caption_for(save: SaveGame) -> String:
	if BanditCamp.is_open(save):
		return TranslationServer.translate("CAMP STANDS, LEVEL %d. GONE IN") % BanditCamp.level(save)
	return TranslationServer.translate("NEXT CAMP IN")


func _process(_delta: float) -> void:
	var save := SaveManager.save
	visible = BanditCamp.active(save)
	if not visible:
		return
	_ink.text = clock_text(BanditCamp.countdown(save))
	_caption.text = caption_for(save)
	_button.visible = save.tree_bought.has(BanditCamp.RESURVEY_NODE)


## Whether RESURVEY stands on the clock now (MapTable picks it then).
func can_press() -> bool:
	return visible and _button.visible


## RESURVEY pressed: the button goes in; a new camp of the same level comes and the clock starts over
## (BanditCamp.resurvey), or the refusal's clunk when the coins are short. Whether it was done.
func resurvey() -> bool:
	_button.press()
	if BanditCamp.resurvey(SaveManager.save):
		SaveManager.autosave()
		return true
	_denied.cue(global_position)
	return false


## The button's click plate (MapTable picks it like TO DESK's).
func plate() -> Node3D:
	return $Resurvey/Plate
