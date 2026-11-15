class_name TallyMachine
extends Node3D
## A drum counter for a saved number: the coin tally machine (nine drums, coins) and the Findings
## counter (six drums, findings). Its drums show the saved total. When the total moves,
## the shown value rolls toward it (faster the further behind it is) and carries like a real
## odometer: a drum only turns while every drum to its right rolls from 9 to 0.
## The number has a limit (SaveGame.LIMITS: coin_limit, findings_limit), lettered in cream on a black
## enamel plate in a steel rim on the machine's top ($LimitPlate, $Limit: "MAX $40K"), as the
## drums' own windows are. While the purse is full the plate reads FULL in red instead ($Full,
## "FULL $40K"), steady, as the supply console's ticker reads FULL for cabbages. Full means the save and what lies unbanked on the desk
## (SaveManager.pending_coins / pending_findings) reach the limit, or income was just lost to it
## (refuse: CoinPile.refused, QaBay._eject). The buzzer sounds once as it becomes full, never while
## it stays full, and at most once in QUIET seconds. The limits end under what the drums show
## (the ARCHIVE ladder at ¶900,000 for six drums; the suite holds them together).

## Once per frame in which the ones drum passed a whole number (the tick sound hooks in here).
signal ticked

## The SaveGame field shown, and how many drums show it.
@export var field := &"coins"
@export var drums := 9
## The drums' area (this node's space) and what hovering it explains.
@export var hover_area := AABB()
@export_multiline var tooltip := ""
## The currency sign on the limit plate.
@export var mark := "$"
## The buzzer keeps quiet this long after it sounded: a purse hovering at its limit (a little earned,
## a little spent) fills again and again.
const QUIET := 30.0
## What lies unbanked for each field: the SaveManager callable that counts it.
const PENDING := {&"coins": &"pending_coins", &"findings": &"pending_findings"}
## Units per second the drums roll at least, plus this much per unit still to go.
const MIN_RATE := 8.0
const CATCH_UP := 4.0

var _shown := 0.0
var _bones := PackedInt32Array()

@onready var _skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var _tick: SoundCue = $Tick
@onready var _limit: Label3D = $Limit
@onready var _full: Label3D = $Full
@onready var _buzzer: SoundCue = $Refuse
## FULL shows; seconds until the buzzer may sound again.
var _is_full := false
var _quiet := 0.0


func _ready() -> void:
	for k in drums:
		_bones.append(_skeleton.find_bone("Drum%d" % k))
	_shown = SaveManager.save.get(field)
	_pose()
	if tooltip != "":
		Interactable.hover_box(self, hover_area, tooltip)


func _process(delta: float) -> void:
	var save := SaveManager.save
	_quiet = maxf(_quiet - delta, 0.0)
	_set_full(save.room(field) <= unbanked())
	var limit := limit_text(mark, save.get(SaveGame.LIMITS[field]), _is_full)
	var lettering := _full if _is_full else _limit
	if lettering.text != limit:
		lettering.text = limit
	_limit.visible = not _is_full
	_full.visible = _is_full
	var target := float(save.get(field))
	if _shown == target:
		return
	var before := floori(_shown)
	_shown = move_toward(_shown, target, (MIN_RATE + absf(target - _shown) * CATCH_UP) * delta)
	if floori(_shown) != before:
		ticked.emit()
		_tick.cue(_tick.global_position)
	_pose()


## The lettering on the machine's top: the most it holds, as a price tag sets it ("MAX $40K"), and
## FULL in MAX's place while it holds that much.
static func limit_text(currency: String, limit: int, full := false) -> String:
	var word := str(TranslationServer.translate("FULL")) if full else "MAX"
	return "%s %s%s" % [word, currency, Num.text(limit)]


## Income was lost to the limit: the purse is full (the buzzer only if it was not already).
func refuse(_at := Vector3.ZERO) -> void:
	_set_full(true)


## What lies unbanked on the desk for this counter (coins on the mat, tokens in front of the lab).
func unbanked() -> int:
	var pending: Callable = SaveManager.get(PENDING[field]) if PENDING.has(field) else Callable()
	return pending.call() if pending.is_valid() else 0


## The buzzer sounds as the purse becomes full, unless it sounded within QUIET seconds.
func _set_full(full: bool) -> void:
	if full and not _is_full and _quiet <= 0.0:
		_quiet = QUIET
		_buzzer.cue(_buzzer.global_position)
	_is_full = full


func _pose() -> void:
	var positions := drum_positions(_shown, drums)
	for k in drums:
		_skeleton.set_bone_pose_rotation(_bones[k], Quaternion(Vector3.RIGHT, deg_to_rad(positions[k] * 36.0)))


## Digit each drum faces, fractional while rolling (Drum0 = ones). Drum k shows digit d at d * 36°.
static func drum_positions(value: float, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	value = fmod(maxf(value, 0.0), pow(10.0, count))
	for k in count:
		var place := pow(10.0, k)
		var below := fmod(value, place)
		out.append(fmod(floorf(value / place), 10.0) + maxf(below - (place - 1.0), 0.0))
	return out
