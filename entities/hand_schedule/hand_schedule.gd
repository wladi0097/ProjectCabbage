class_name HandSchedule
extends Node3D
## The HANDLING ASSIGNMENT SCHEDULE (desk card CARD, chapter 1): a light switch at the bottom of the
## desk, between the lab hands' and the hired hands' parking piles (Associate.park_spot), there once
## the card is stamped. Clicked, it opens the schedule (handling_sheet.tscn):
## a form split in two, lab hands left and hired hands right, a picture per cabbage kind (KINDS) under
## each. A struck kind is in that half's list in the save (hands_forbidden, lab_hands_forbidden) and
## no hand of that kind takes it (Associate.pick_target, given `forbidden`).
## A kind is on the paper once the player has met it (`seen`: its card SEEN stamped; never before, no
## spoilers) and can be struck once it is `listed`: plain cabbages and minis with their cards, blue
## ones with MEMO: LAB PRIORITY (LAB_CARD; its stamp strikes blue for hired hands), golden ones with
## their projector node (GOLD_NODE). Met but not listed: padlocked.
## The schedule only withholds: what a hand may not take anyway (a golden cabbage without its
## clearance, a rotten one under the spoilage memo) stays untouched whatever the paper says. Rotten
## cabbages are no kind here (kind_of ""): the memo and the waste protocol govern them.
## The switch's lamp is lit while anything is struck.

const CARD := "hand_schedule"
## The cabbage kinds on the paper, in its order. "regular": a plain cabbage, condensed and grown ones included.
const KINDS: Array[String] = ["regular", "research", "mini", "golden"]
## The card that brings each kind past the plain one: met (on the paper) once it is stamped.
const SEEN := {research = "research_cabbage", mini = "mini_cabbages", golden = "golden_cabbage"}
## MEMO: LAB PRIORITY: lists blue, and its stamp strikes blue for hired hands (UpgradeDesk.apply).
const LAB_CARD := "lab_priority"
## The projector node (under BULLION HANDLING CLEARANCE) that lists golden cabbages.
const GOLD_NODE := "schedule_golden"

## What the switch's toggle and lamp show (anything struck).
var _shown_on := false

@onready var _switch: CogSwitch = $Switch
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


## Whether the player has met `kind` (its card is stamped): only then is it on the paper at all.
static func seen(save: SaveGame, kind: String) -> bool:
	return kind == "regular" or save.stamped.has(SEEN.get(kind, ""))


## Whether the schedule lists `kind` (its picture can be struck): plain and mini cabbages once met,
## blue ones with LAB_CARD, golden ones with GOLD_NODE.
static func listed(save: SaveGame, kind: String) -> bool:
	if not save.stamped.has(CARD) or not seen(save, kind):
		return false
	match kind:
		"research":
			return save.stamped.has(LAB_CARD)
		"golden":
			return save.tree_bought.has(GOLD_NODE)
	return true


## The kinds struck for lab hands (`for_research`) or hired hands. Without the card only LAB_CARD's
## rule holds: hired hands leave blue alone.
static func forbidden(save: SaveGame, for_research: bool) -> PackedStringArray:
	if save.stamped.has(CARD):
		return save.lab_hands_forbidden if for_research else save.hands_forbidden
	if not for_research and save.stamped.has(LAB_CARD):
		return PackedStringArray(["research"])
	return PackedStringArray()


## LAB_CARD stamped (or an old save that had it, once): blue struck for hired hands.
static func strike_blue(save: SaveGame) -> void:
	if not save.hands_forbidden.has("research"):
		save.hands_forbidden.append("research")


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
