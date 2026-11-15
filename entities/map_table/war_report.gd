class_name WarReport
extends Node3D
## The after-action report (FORM 9-R): after every war that started (won, lost or retreated; never
## after an ABORT before START) it slides in over the war sheet once the end's stamp is on it, and
## the sheet goes on (the farm's moment on a win, back to the country otherwise) only once it is
## filed (WarSheet.file_report: a click). Built like the deed (FarmDeed): `Page` is a 2D SubViewport
## with the form at 1 px = 1 mm, printed on `Paper`; its origin is the middle of its top edge, the
## paper runs along +Z. The form: the farm and its site, OUTCOME, TIME ON SITE, one row per staff type
## deployed with how many were lost (`Page/Form/Staff/Row` is the template), CABBAGES WRITTEN OFF (the
## cabbages the lost figures cost), the war's coins, DEFENCES DECOMMISSIONED, then the GRADE stamp
## (it lands with a thud once the paper is in) beside one deadpan remark.
## The grade (grade_for): a loss or a retreat is REGRETTABLE; a win is EXEMPLARY with at most
## EXEMPLARY_LOST of the staff deployed lost and at most EXEMPLARY_TIME of the time limit used, else
## ACCEPTABLE (a typical win, sent about the estimate, loses a third or more: ACCEPTABLE).
## Sounds: Slide (in and away), Strike (the grade stamp).

const SIZE := Vector2(0.86, 1.2)
const EXEMPLARY := "EXEMPLARY"
const ACCEPTABLE := "ACCEPTABLE"
const REGRETTABLE := "REGRETTABLE"
const EXEMPLARY_LOST := 0.1
const EXEMPLARY_TIME := 1.0 / 3.0
## The remarks (translation keys), by grade; a retreat has its own. One is picked by the farm's id.
const REMARKS := {
	EXEMPLARY: ["Losses within tolerance. The tolerance has been lowered.",
			"Head office has requested the method in writing.",
			"Commendation issued. Commendations carry no salary."],
	ACCEPTABLE: ["The site is ours. The staff costs have been noted.",
			"Objective met. Efficiency will be discussed at your review.",
			"A satisfactory result, for a given value of satisfactory."],
	REGRETTABLE: ["The farm remains in private hands. This is being looked into.",
			"Staff losses have been reclassified as a learning experience.",
			"Please do not discuss this engagement with the shareholders."],
	"WITHDRAWN": ["Staff were relocated rearward ahead of schedule.",
			"A withdrawal is not a defeat. It is merely filed as one.",
			"The remaining staff have been asked to stop looking back."],
}
## Sliding in from SLIDE_FROM m to the right, turned SLIDE_TURN, in SLIDE_TIME s; STAMP_AFTER s later
## the grade comes down from STAMP_SCALE times its size in STAMP_TIME s and the paper dips DIP m.
const SLIDE_FROM := 2.0
const SLIDE_TURN := 0.22
const SLIDE_TIME := 0.32
const STAMP_AFTER := 0.3
const STAMP_SCALE := 2.4
const STAMP_TIME := 0.12
const DIP := 0.012

## Filed by a click: the grade is on the paper and it has not been filed yet.
var waiting := false
var _moving: Tween

@onready var _page: SubViewport = $Page
@onready var _paper: ShaderMaterial = $Paper.material_override
@onready var _staff: Control = $Page/Form/Staff
@onready var _row: Control = $Page/Form/Staff/Row
@onready var _grade: Control = $Page/Form/Grade
@onready var _slide_sound: SoundCue = $Slide
@onready var _strike_sound: SoundCue = $Strike


func _ready() -> void:
	_paper.set_shader_parameter(&"sheet_tex", _page.get_texture())


## What the ended `fight` comes to: {deployed, lost (unit id -> figures, depot order), cabbages (what
## the lost figures cost), defences: Vector2i(down, all), won, retreat, grade, seconds, limit}. Lost
## is every figure placed that does not come home (WarFight.kept): the dead, and a retreat's rest.
static func summary(fight: WarFight) -> Dictionary:
	var deployed := {}
	for u in fight.units:
		deployed[u.unit] = int(deployed.get(u.unit, 0)) + 1
	var lost := {}
	var sent := 0
	var gone := 0
	var cabbages := 0
	for unit: String in WarRules.UNITS:
		if deployed.has(unit):
			lost[unit] = maxi(int(deployed[unit]) - int(fight.kept.get(unit, 0)), 0)
			sent += int(deployed[unit])
			gone += int(lost[unit])
			cabbages += int(lost[unit]) * WarRules.unit_cabbage_price(unit)
	var defences := Vector2i.ZERO
	for b in fight.buildings:
		if b.kind in WarFight.DEFENCES:
			defences += Vector2i(0 if b.alive else 1, 1)
	var won := fight.state == WarFight.State.WON
	return {deployed = deployed, lost = lost, cabbages = cabbages, defences = defences, won = won,
			retreat = fight.end == WarFight.End.RETREAT, seconds = fight.elapsed, limit = fight.time_limit,
			grade = grade_for(won, gone / maxf(sent, 1.0), fight.elapsed / maxf(fight.time_limit, 0.001))}


## The grade of a war: `won` or not, the share of the staff deployed lost, the share of the time
## limit used.
static func grade_for(won: bool, lost_share: float, time_share: float) -> String:
	if not won:
		return REGRETTABLE
	return EXEMPLARY if lost_share <= EXEMPLARY_LOST + 0.0001 and time_share <= EXEMPLARY_TIME else ACCEPTABLE


## The remark (a key) for `report` (summary) on `farm`: by its grade, a retreat's own; which of
## them by the farm, so the same war always reads the same.
static func remark(report: Dictionary, farm: StringName) -> String:
	var lines: Array = REMARKS["WITHDRAWN" if report.retreat else report.grade]
	return lines[hash(String(farm)) % lines.size()]


## Seconds as the clock reads them: "1:05".
static func clock(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


## Fills the form for the war on `farm` (called `called`; "": the site only) that cost `coins` and
## came to `report` (summary).
func fill(farm: StringName, called: String, coins: int, report: Dictionary) -> void:
	($Page/Form/Title as Label).text = called if called != "" else FarmDeed.code(farm)
	($Page/Form/Site as Label).text = tr("FARM SITE %s") % FarmDeed.code(farm)
	($Page/Form/Outcome as Label).text = tr("VICTORY" if report.won else ("WITHDRAWN" if report.retreat else "ACQUISITION UNSUCCESSFUL"))
	($Page/Form/Time as Label).text = tr("%s of %s") % [clock(report.seconds), clock(report.limit)]
	($Page/Form/Cabbages as Label).text = FarmScreen._thousands(report.cabbages)
	($Page/Form/Coins as Label).text = FarmDeed.amount_text("coins", coins)
	($Page/Form/Defences as Label).text = tr("%d of %d") % [report.defences.x, report.defences.y]
	($Page/Form/Remark as Label).text = tr(remark(report, farm))
	($Page/Form/Grade/Word as Label).text = tr(report.grade)
	for old in _staff.get_children():
		if old != _row:
			old.free()
	var k := 0
	for unit: String in report.lost:
		var line := _row.duplicate() as Control
		line.name = unit
		line.position = Vector2(0.0, k * _row.size.y)
		(line.get_node("Name") as Label).text = tr(DepotSheet.NAMES[unit])
		(line.get_node("Deployed") as Label).text = str(report.deployed[unit])
		(line.get_node("Lost") as Label).text = str(report.lost[unit])
		line.show()
		_staff.add_child(line)
		k += 1
	_grade.hide()


## Slides in onto `to` (the parent's space), then the grade stamp lands; filed by a click after that.
func lay(to: Vector3) -> void:
	waiting = false
	_page.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # The stamp moves on the page.
	show()
	_slide_sound.cue(global_position)
	_still()
	_moving = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_moving.tween_property(self, "position", to, SLIDE_TIME).from(to + Vector3.RIGHT * SLIDE_FROM)
	_moving.parallel().tween_property(self, "rotation:y", 0.0, SLIDE_TIME).from(-SLIDE_TURN)
	_moving.tween_interval(STAMP_AFTER)
	_moving.tween_callback(_grade.show)
	_moving.tween_property(_grade, "scale", Vector2.ONE, STAMP_TIME).from(Vector2.ONE * STAMP_SCALE) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_moving.parallel().tween_property(_grade, "modulate:a", 1.0, STAMP_TIME).from(0.0)
	_moving.tween_callback(_thud.bind(to))


## Filed: it slides off to the left and is gone. Whether it was waiting to be filed.
func file() -> bool:
	if not waiting:
		return false
	waiting = false
	_slide_sound.cue(global_position)
	_still()
	_moving = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_moving.tween_property(self, "position", position + Vector3.LEFT * SLIDE_FROM, SLIDE_TIME)
	_moving.parallel().tween_property(self, "rotation:y", SLIDE_TURN, SLIDE_TIME)
	_moving.tween_callback(put_away)
	return true


## Gone at once.
func put_away() -> void:
	_still()
	waiting = false
	hide()
	_page.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The grade has landed: the thud, the paper gives a little, and it may be filed.
func _thud(to: Vector3) -> void:
	_strike_sound.cue(global_position)
	waiting = true
	var dip := create_tween()
	dip.tween_property(self, "position:y", to.y - DIP, 0.05)
	dip.tween_property(self, "position:y", to.y, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _still() -> void:
	if _moving != null:
		_moving.kill()
