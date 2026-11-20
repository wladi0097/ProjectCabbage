extends Node3D
## The unrest clock on the world sheet (WorldSheet `UnrestClock`), lying over its survey pole at the
## top middle, so it goes with the sheet and shows only while the sheet lies open: a gunmetal plate with a green segment readout behind smoked glass, like the desk's digital
## counters (DigitalReadout), counting down to the next bandit camp (BanditCamp.countdown). Only the
## numbers are on it: what the count is for is the table's hint slip on its face (hint_for: the next
## camp on an empty map, or when the one standing goes). Hidden until the camps' card. Its oxblood
## push button (`Resurvey`, the map table's desk button) stands beside it once the depot's REVISED SITE
## SURVEY is bought (BanditCamp.RESURVEY_NODE): MapTable picks its `Plate` (RESURVEY) and calls resurvey.

const War := preload("res://entities/map_table/war_sheet.gd")
## Half the plate's size (m), for the table's pick on its face.
const FACE_HALF := Vector2(0.31, 0.18)

@onready var _ink: Label3D = $Glass/Ink
@onready var _button: Node3D = $Resurvey
@onready var _denied: SoundCue = $Denied


## Seconds as the readout prints them: "09:41"; "--:--" for none.
static func clock_text(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--"
	var whole := ceili(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


## The hint slip on the clock's face for `save`: when the next camp comes, or the camp standing,
## its level and when it goes.
static func hint_for(save: SaveGame) -> String:
	var left := clock_text(BanditCamp.countdown(save))
	if BanditCamp.is_open(save):
		return TranslationServer.translate("Rebel camp, level %d. It leaves in %s. Click the camp to take back what is ours.") % [BanditCamp.level(save), left]
	return TranslationServer.translate("Next rebel camp in %s.") % left


func _process(_delta: float) -> void:
	var save := SaveManager.save
	var sheet := get_parent() as MapSheet
	visible = BanditCamp.active(save) and (sheet == null or sheet.open >= 1.0)
	if not visible:
		return
	_ink.text = clock_text(BanditCamp.countdown(save))
	_button.visible = save.tree_bought.has(BanditCamp.RESURVEY_NODE)


## Whether RESURVEY stands on the clock now (MapTable picks it then).
func can_press() -> bool:
	return is_visible_in_tree() and _button.visible


## RESURVEY pressed: the button goes in; a new camp of the same level comes and the clock starts over
## (BanditCamp.resurvey), or the refusal's clunk when the coins are short. Whether it was done.
func resurvey() -> bool:
	_button.press()
	if BanditCamp.resurvey(SaveManager.save, War.at_war):
		SaveManager.autosave()
		return true
	_denied.cue(global_position)
	return false


## The button's click plate (MapTable picks it like TO DESK's).
func plate() -> Node3D:
	return $Resurvey/Plate


## The clock's face (MapTable picks it for the hint slip): FACE_HALF each way round it.
func face() -> Node3D:
	return $Face
