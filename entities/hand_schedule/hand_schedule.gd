class_name HandSchedule
extends Node3D
## The HANDLING ASSIGNMENT SCHEDULE (desk card CARD, chapter 3): a light switch at the bottom of the
## desk, between the lab hands' and the hired hands' parking piles (Associate.park_spot), there once
## the card is stamped. Clicked, it opens the schedule (handling_sheet.tscn):
## a form split in two, lab hands left and hired hands right, a picture per cabbage kind (KINDS) under
## each. A struck kind is in that half's list in the save (hands_forbidden, lab_hands_forbidden) and
## no hand of that kind takes it (Associate.pick_target, given `forbidden`).
## The card lists plain cabbages; each other kind is listed once its projector node (NODES) is bought.
## The schedule only withholds: what a hand may not take anyway (a golden cabbage without its
## clearance, a rotten one under the spoilage memo) stays untouched whatever the paper says. Rotten
## cabbages are no kind here (kind_of ""): the memo and the waste protocol govern them.
## The switch's lamp is lit while anything is struck.

const CARD := "hand_schedule"
## The cabbage kinds on the paper, in its order. "regular": a plain cabbage, condensed and grown ones included.
const KINDS: Array[String] = ["regular", "research", "mini", "golden"]
## The projector node that lists each kind past the plain one.
const NODES := {research = "schedule_research", mini = "schedule_mini", golden = "schedule_golden"}

## What the switch's toggle and lamp show (anything struck).
var _shown_on := false

@onready var _switch: LightSwitch = $Switch
@onready var _sheet: HandlingSheet = $Schedule/Sheet


func _ready() -> void:
	_switch.flicked.connect(_flick)
	_show_switch(false)


func _process(_delta: float) -> void:
	var save := SaveManager.save
	if _switch.visible != save.stamped.has(CARD):
		_show_switch(false)
	elif _shown_on != any_struck(save):
		_show_switch()


## The schedule's kind of `cabbage`: golden, research, mini or regular; "" for a rotten one (not on it).
static func kind_of(cabbage: Cabbage) -> String:
	if cabbage.rotten:
		return ""
	if cabbage.golden:
		return "golden"
	if cabbage.research:
		return "research"
	return "mini" if cabbage.mini else "regular"


## Whether the schedule lists `kind` (its picture can be struck): the card for plain cabbages, and
## the kind's projector node for the others.
static func listed(save: SaveGame, kind: String) -> bool:
	return save.stamped.has(CARD) and (kind == "regular" or save.tree_bought.has(NODES.get(kind, "")))


## The kinds struck for lab hands (`for_research`) or hired hands: none without the card.
static func forbidden(save: SaveGame, for_research: bool) -> PackedStringArray:
	if not save.stamped.has(CARD):
		return PackedStringArray()
	return save.lab_hands_forbidden if for_research else save.hands_forbidden


## A click on `kind`'s picture in the lab hands' (`for_research`) or hired hands' half: struck, or
## cleared again. False (nothing changes) for a kind the schedule does not list.
static func toggle(save: SaveGame, for_research: bool, kind: String) -> bool:
	if not listed(save, kind):
		return false
	var struck := save.lab_hands_forbidden if for_research else save.hands_forbidden
	var at := struck.find(kind)
	if at < 0:
		struck.append(kind)
	else:
		struck.remove_at(at)
	if for_research:
		save.lab_hands_forbidden = struck
	else:
		save.hands_forbidden = struck
	return true


## Whether anything is struck for either kind of hand (the switch's lamp).
static func any_struck(save: SaveGame) -> bool:
	return not forbidden(save, false).is_empty() or not forbidden(save, true).is_empty()


func _flick() -> void:
	$Click.play()
	_sheet.open()


## The switch shows once the card is stamped, up and lit while anything is struck.
func _show_switch(animate := true) -> void:
	var save := SaveManager.save
	_switch.visible = save.stamped.has(CARD)
	_switch.set_enabled(_switch.visible)
	_shown_on = any_struck(save)
	_switch.show_on(_shown_on, animate)
