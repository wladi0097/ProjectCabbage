class_name WarSlip
extends Node3D
## A small paper the war sheet lays out while a war is being planned (war_slip.tscn: a page printed
## on map paper like the report). Two uses, one scene: NEW STRUCTURE ON SITE (debut) on the desk the
## first time a building type is on a map, only its name on the paper (like a form in the tray; the
## war sheet shows its card, card(), on hover: its one line and what it does in plain words),
## taken away at START; and FINAL ACQUISITION (final) over the last war's sheet, in an oxblood border,
## filed with a click before planning starts. Its origin is the middle of its top edge.
## Sounds: Slide (it slides in or away).

## Its paper's size (m) comes from the scene: the big form (war_slip.tscn, 0.6 x 0.42) or the small
## debut card (war_debut_slip.tscn, only the form line, the name and the foot). See size().
## Slides in from (and away to) this far along -x (m, the parent's frame), turned SLIDE_TURN.
const SLIDE_FROM := 1.2
const SLIDE_TURN := 0.2
const SLIDE_TIME := 0.32
## Per building kind (WarMap.DEBUT_KINDS): its name, its line, what it does in plain words (keys).
const STRUCTURES := {
	cannon = ["SUPERVISOR'S TOWER", "Someone is always watching. Occasionally, someone throws something.",
		"Shoots the nearest figure within 6 squares and stays on it until it falls or walks away."],
	mortar = ["MASS MAILING UNIT", "Sent to all. Read by none. Lands on everyone.",
		"Lobs a crate that hurts every figure where it lands. Reaches 7 squares, but nobody within 2."],
	cctv = ["CCTV MAST", "For your safety, this attack is being recorded.",
		"Reaches 8 squares with a stream of small, weak shots. It starts early and does not stop."],
	sprinkler = ["FIRE SAFETY SPRINKLER", "Regulations require coverage. Of everyone nearby.",
		"Reaches only 2.5 squares, but its spray hits the figure and everyone beside it. Spread out."],
	shredder = ["DOCUMENT SHREDDER", "Every application is reviewed. Briefly.",
		"Chews on one figure within 3 squares. It starts weak and bites harder every half second, up to 18 times as hard. When it switches to another figure it starts weak again: send a tough figure in first, or several at once."],
	silo = ["LIABILITY SILO", "It was always going to blow. Nobody budgeted for it.",
		"Lobs cabbages 4 squares. When it falls it bursts and hurts every figure beside it."],
	wall_stone = ["MASONRY FENCING", "Access is restricted. Restrictions are flexible.",
		"Over three times as tough as picket. Staff walk round it if the way round is short."],
	wall_steel = ["SECURITY-GRADE FENCING", "Access is restricted. Restrictions are flexible.",
		"Six times as tough as picket. Find the way round, or bring a charge."],
}

## The final slip waits for a click (file); the debut slip never does.
var waiting := false

var _moving: Tween

@onready var _page: SubViewport = $Page
@onready var _paper: ShaderMaterial = $Paper.material_override
@onready var _slide_sound: SoundCue = $Slide


func _ready() -> void:
	_paper.set_shader_parameter(&"sheet_tex", _page.get_texture())


## Prints the NEW STRUCTURE ON SITE slip for building kind `kind` (STRUCTURES): its name only.
func debut(kind: String) -> void:
	_print("NEW STRUCTURE ON SITE", STRUCTURES[kind][0], "", "", "Removed at START.", false)


## The card the war sheet shows (PaperNote, like a form's in the tray) while the debut slip for
## building kind `kind` is hovered: its name, its line (the flavour) and what it does, translated.
static func card(kind: String) -> Dictionary:
	var said: Array = STRUCTURES[kind]
	return {form = "NEW STRUCTURE ON SITE", title = said[0],
			body = TranslationServer.translate(said[1]) + "\n" + TranslationServer.translate(said[2])}


## Prints FINAL ACQUISITION for the site called `site_name` with its `briefing` (keys).
func final(site_name: String, briefing: String) -> void:
	_print("FORM 9-F  FINAL ACQUISITION", site_name, briefing,
			"The last farm that is not ours. After this there is nothing left to acquire. The Board will be watching the clock.",
			"Click to proceed.", true)


## How big the paper lies (m, the parent's frame: its scale included), from its mesh.
func size() -> Vector2:
	return ($Paper.mesh as PlaneMesh).size * Vector2(scale.x, scale.z)


## The printed words, top to bottom (keys or names): the form line, the title, the line, the body.
func words() -> PackedStringArray:
	var out := PackedStringArray()
	for label: String in ["Form/FormLine", "Form/Title", "Form/Line", "Form/Body", "Form/Foot"]:
		out.append((get_node("Page/" + label) as Label).text)
	return out


## Slides in to `to` (the parent's frame); `wait` holds it there until file().
func lay(to: Vector3, wait := false) -> void:
	waiting = wait
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE
	show()
	_slide_sound.cue(global_position)
	_still()
	_moving = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_moving.tween_property(self, "position", to, SLIDE_TIME).from(to + Vector3.LEFT * SLIDE_FROM)
	_moving.parallel().tween_property(self, "rotation:y", 0.0, SLIDE_TIME).from(SLIDE_TURN)


## Slides off to the left and is gone. Whether it was showing.
func file() -> bool:
	if not visible:
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


func _print(form: String, title: String, line: String, body: String, foot: String, red: bool) -> void:
	($Page/Form/FormLine as Label).text = form
	($Page/Form/Title as Label).text = title
	($Page/Form/Line as Label).text = line
	($Page/Form/Body as Label).text = body
	($Page/Form/Rule as Control).visible = body != ""
	($Page/Form/Foot as Label).text = foot
	($Page/Form/Frame as Control).visible = not red
	($Page/Form/RedFrame as Control).visible = red
	_page.render_target_update_mode = SubViewport.UPDATE_ONCE


func _still() -> void:
	if _moving != null:
		_moving.kill()
