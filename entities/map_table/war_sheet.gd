extends MapSheet
## The war sheet: rolls out when war is declared on a farm nobody sells (FarmRegister), with that
## farm's country rolled up in the table's holder. The whole sheet is the battlefield: millimetre
## paper (assets/sprites/maps/war_map.svg, tools/make_war_paper.py) whose heavy lines are the fight's
## cells, no lettering but a small title block (`Page/Sheet/TitleBlock`) in the bottom-right corner
## cells no map uses: the site's code and name, SHEET n OF 19 (WarMap.sheet_number), scale and
## signatures. The farm's map (WarMap.scene_for) lies on it in `Things/Board`,
## its origin on the paper's grid origin (GRID_AT); its deployment zones are hatched on it.
## The declaration pays for the war and hands over the figures taken (begin, research/war-contract.md).
## The fight: the way out goes away (TO DESK, TO FARM, the tally, the depot, the roll in the holder,
## Esc) and the figures taken stand on the desk left of the sheet, no names, no plates. Like a
## cabbage they are picked up (press), carried swaying in the desk's glove and set down (release) anywhere: on the desk
## they stand there; in a zone they stand where they were set down; within WarFight.SNAP of a zone
## they slide into it; anywhere else on the paper they just stand there, and START is refused while
## one does (the hint says why). Before START every figure can be picked up again. START (the
## control box beside the sheet, WarControl: `Control`) puts every figure standing in a zone into the
## WarFight and runs it; after START placing (straight into the fight, zones only) needs TACTICS
## (WarRules.can_place_mid_round). ABORT before START calls the war off: every figure goes back to
## the army and its coins come back (FarmRegister.refund). During the fight ABORT is the RETREAT
## card's flee (WarRules.retreat_share), dead without it. The box shows the fight's clock.
## Figures not committed are kept in save.war_pending (set at the declaration; the ones set down at
## START or placed after it are taken off it), so a game closed mid-war gives them back (_ready).
## The end: WON (farmhouse down) the survivors go back into save.army, the farm is ours (win) and the
## sheet asks for its country's sheet again (`sheet_wanted`), where the farm's moment plays
## (FarmRegister.celebrate); no stamp on the paper (the report says it). LOST (time out, every figure
## down, retreat): no stamp on the paper but WITHDRAWN after a retreat (the report says the rest), the retreat's share
## goes back into save.army, the placed figures are gone, the farm stays as it was. Figures never
## placed always go back. After the end's stamp (won or lost, never after an ABORT before START) the
## after-action report (`Report`, WarReport) slides in over the sheet with its grade (kept in
## save.war_grades); the sheet leaves only once it is filed (file_report: a click). Everything hidden
## comes back as the sheet leaves.
## Planning aids, printed on the paper by `Page/Sheet/Ink` (WarInk): the defence under the mouse
## shows its range ring (the mailing unit also its dead zone), and, once ROUTE_CARD is stamped, a
## figure held over a zone shows the pencil line of the way it would walk to its first target
## (path_line: a planning copy of the fight, at most every PATH_EVERY s), drawn over the pieces. The first map to hold a building type (WarMap.debuts) gets the
## NEW STRUCTURE ON SITE slip on the desk (`Slip`, WarSlip) until START: only the building's name on it;
## hovered, its card fades in mid-screen (`Note`, PaperNote: the tray's form popup, WarSlip.card). The campaign's last war
## (WarMap.is_final, Endmark Isle) arrives staged: FINAL ACQUISITION in an oxblood border (`Final`)
## lies over the sheet first and holds the planning (staging) until a click files it; then the
## farmhouse drops onto the paper with a stamp's beat (`Beat`).
## While the fight is on, the sheet takes the mouse itself (_input runs before the table's) and
## hands the box's parts to the table's hint slip (MapTable.hover_spot, hint).
## Sounds: a figure picked up (PickUp) and set down (SetDown), START (Start), the clock's last
## seconds (Tick, TICK_FROM), RETREAT (Retreat), the end's stamp (Won, Lost), a refusal (Denied); the report has its own.
## Every war sound plays on the War bus; while a war is on (fight set) every other sound sits in the
## background (duck: Music and SFX go down and muffled), eased in over DUCK_IN s and out over DUCK_OUT s.
## The desk's glove (`Glove`) is the cursor while the sheet takes the mouse: open over the
## paper, closed on a figure held, the pointing finger tapping on START and ABORT. Once the
## after-action report is in, the map table's own cursor is back (the pointing hand on FILE REPORT).
## No boss paper comes while a war is on (BossReport.hold): it waits until the sheet has left.
## No class_name: whoever needs it preloads this script.

const World := preload("res://entities/map_table/world_register.gd")
const DeskHand := preload("res://globalScripts/hand.gd")

## The fight grid's top-left corner on the art (px): the paper's printed grid starts here too.
const GRID_AT := Vector2(0.0, 20.0)
## The cells the title block is printed on: no map puts a piece there (a test checks); the corner
## cell under the drafting weight is left free.
const TITLE_CELLS := Rect2i(19, 8, 1, 3)
## The box's parts (WarControl.part_at) as spots for the hint slip.
const START := &"start"
const ABORT := &"abort"
## A retreat called within this many seconds of START counts as quick (save.quick_retreats, a memo).
const QUICK_RETREAT := 3.0
## Where the figures taken stand on the desk left of the sheet (art px, off the paper), above the
## control box: FIGURE_AT the first, then FIGURES_PER_ROW to a row, FIGURE_STEP apart (11, the
## largest army, fill four rows). A figure set down off the paper stays inside DESK.
const FIGURE_AT := Vector2(-110.0, 200.0)
const FIGURE_STEP := Vector2(-115.0, 150.0)
const FIGURES_PER_ROW := 3
const DESK := Rect2(-400.0, 100.0, 370.0, 820.0)
## The desk lies this much lower than the paper (m, sheet frame).
const DESK_Y := -0.018
## A figure is picked up with the mouse this close to it (px).
const PICK_RADIUS := 70.0
## A figure held is carried this high (m), swaying with the mouse like the glove's hold (HandModel's
## SWAY_GAIN / MAX_SWAY), and follows at this rate (1/s); set down, it settles in SETTLE_TIME.
const CARRY := 0.06
const SWAY_GAIN := 0.004
const MAX_SWAY := 0.6
const FOLLOW := 22.0
const SETTLE_TIME := 0.12
## The desk's glove (`Glove`, HandModel) carries the figure held: its knuckles sit this high over
## the figure's base (m, the figure's frame), and once it is set down it opens there for LET_GO s.
const GRIP := 0.2
const LET_GO := 0.15
## A zone's glow (zone.gdshader's `glow`) while a figure is held, and the one it would land in.
const GLOW := 0.45
const GLOW_HOT := 1.0
## From the end's stamp until the after-action report slides in (s): a win, a loss.
const LEAVE_AFTER := 0.7
const LOST_AFTER := 1.8
## Seconds the fight's song takes to fade out once the fight ends.
const MUSIC_FADE := 1.5
## The table's nodes that go away while the fight is on (the way out and the currency column).
const EXITS: Array[String] = ["DeskButton", "FarmButton", "Tally", "Depot"]
const AWAY_TIME := 0.2
## The running clock ticks aloud from this many seconds left.
const TICK_FROM := 10
## The held figure's path line is worked out again at most this often (s). It is pencilled only once
## this card is stamped, on its own overlay (`PencilPage` shown by `PencilOverlay`, no depth test) so
## no piece on the board hides it.
const PATH_EVERY := 0.2
const ROUTE_CARD := "route_planning"
## The farmhouse of the last war drops from this high (m) in BEAT_TIME s, with a stamp's beat.
const BEAT_FROM := 0.3
const BEAT_TIME := 0.24
## The duck at its full depth: Music and SFX this much quieter (dB), and above DUCK_HZ muffled
## MUFFLE_DB more, through each bus's Duck (AudioEffectAmplify) and HighShelfFilter in
## default_bus_layout.tres. Both are switched off at rest. A shelf, not a low-pass: the low-pass at
## 800 Hz took a coin's clink 41 dB down (gone); the shelf takes it about 20 dB (damped, still heard).
const DUCK_DB := -12.0
const DUCK_HZ := 800.0
const MUFFLE_DB := -8.0
const DUCKED: Array[StringName] = [&"Music", &"SFX"]
const DUCK_IN := 0.6
const DUCK_OUT := 1.0
## The empty glove floats this high over the paper (m, under the mouse on screen); pointing, its
## fingertip touches a button this far toward the player from the cap's middle (m), like the desk's.
const HOVER := 0.16
const TIP_BACK := 0.02
## The debut slip's card fades in and out this fast (s), like a form's in the tray (UpgradeDesk.NOTE_FADE).
const NOTE_FADE := 0.15

## The farm the war is for (&"": none yet).
var farm := &""
## The fight under way (null: none). Created at begin, PLANNING until START.
var fight: WarFight:
	set(value):
		fight = value
		at_war = value != null
## A war is on: from the fight set up at begin until the sheet has left (or the scene goes). The one
## check for "war is running" (the manager pauses on it).
static var at_war := false
## The end playing out (null: none): from the stamp until the sheet leaves.
var _dealing: Tween
var _hot := &""
## Whether the sheet took the mouse last frame (_taking).
var _took := false
var _held: Node3D
## Where the figure held was picked up (sheet frame): a refused drop puts it back there.
var _held_from := Vector3.ZERO
var _mouse_pixel := Vector2.ZERO
var _sway := Vector2.ZERO
## The figure the glove is on (held, or just let go; null: the glove is hidden) and its time left there.
var _gripped: Node3D
var _let_go := 0.0
var _clock_shown := -1
## The table's nodes put away for the fight -> their scale; the roll in the holder lifted away and
## where it lay.
var _away := {}
## The tweens putting them away (killed when they come back).
var _away_tweens: Array[Tween] = []
var _roll: MapSheet
## The building type the NEW STRUCTURE ON SITE slip is for ("": none on this map).
var debut := ""
## The last war's FINAL ACQUISITION lies over the sheet: no planning until it is filed (proceed).
var staging := false
## The defence ringed (-1: none), where the path line was last worked out for and when next.
var _ringed := -1
var _path_spot := Vector2.INF
var _path_wait := 0.0
var _laying: Tween
var _roll_at: Transform3D
var _music_fade: Tween
## How far the duck is in (0..1).
var _ducked := 0.0
## The debut slip's card is up, and its fade; the mouse is on the report's FILE REPORT.
var _noting := false
var _note_fade: Tween
var _on_file := false
## A bandit camp fight (farm BanditCamp.SITE): its defences' buff (hp, and the damage they deal: unit
## hp is divided by it as each figure is committed). 1 for a war on a farm.
var _buff := 1.0

@onready var _board: Node3D = $Things/Board
@onready var _map: WarMap = $Things/Board/Map
@onready var _view: FightView = $Field
@onready var _control: WarControl = $Control
@onready var _imprint: Label = $Page/Sheet/Imprint
@onready var _won_sound: SoundCue = $Won
@onready var _lost_sound: SoundCue = $Lost
@onready var _pick_up_sound: SoundCue = $PickUp
@onready var _set_down_sound: SoundCue = $SetDown
@onready var _start_sound: SoundCue = $Start
## The fight's song: one of three (never the same twice in a row) from START until the fight ends.
@onready var _music: AudioStreamPlayer = $Music
@onready var _tick_sound: SoundCue = $Tick
@onready var _retreat_sound: SoundCue = $Retreat
@onready var _denied_sound: SoundCue = $Denied
## The after-action report and where it lies on the sheet (its place in the scene).
@onready var _report: WarReport = $Report
@onready var _report_rest := _report.position
@onready var _ink: WarInk = $Page/Sheet/Ink
@onready var _slip: WarSlip = $Slip
@onready var _slip_rest := _slip.position
@onready var _final: WarSlip = $Final
@onready var _final_rest := _final.position
@onready var _beat_sound: SoundCue = $Beat
@onready var _glove: HandModel = $Glove
@onready var _pencil: WarInk = $PencilPage/Sheet/Pencil
@onready var _pencil_page: SubViewport = $PencilPage
@onready var _pencil_overlay: MeshInstance3D = $PencilOverlay
@onready var _note: Control = $Note/Center
@onready var _note_paper: PaperNote = $Note/Center/Paper


func _ready() -> void:
	super()
	SaveManager.save.return_war_pending()  # A war cut off by closing the game: its figures come home.
	_control.hide()
	_report.put_away()


func _process(delta: float) -> void:
	_view.visible = open > 0.999
	var ducked := move_toward(_ducked, 1.0 if fight != null else 0.0, delta / (DUCK_IN if fight != null else DUCK_OUT))
	if ducked != _ducked:
		_ducked = ducked
		duck(ducked)
	if fight == null:
		return
	_keep_away()
	var taking := _taking()
	if _took and not taking:
		_unhover()  # An overlay, the boss's paper or a swap took the mouse: nothing stays lit or held.
		if _held != null:
			drop(pixel_of(_held_from))
	_took = taking
	if _held != null:
		_carry(delta)
	_hold_glove(delta, taking and not _report.visible)  # The report in: the table's cursor is back.
	if fight.state == WarFight.State.RUNNING:
		fight.tick(delta)
	_view.follow(fight, delta)
	_glow_zones()
	_planning_ink(delta)
	_show_note(taking and _held == null and on_slip(_mouse_pixel))
	if ceili(fight.time_left()) != _clock_shown and fight.state == WarFight.State.RUNNING \
			and ceili(fight.time_left()) in range(1, TICK_FROM + 1):
		_tick_sound.cue(global_position)
	_clock_shown = ceili(fight.time_left())
	_show_control()
	if _dealing == null and fight.state in [WarFight.State.WON, WarFight.State.LOST]:
		_end()
	BossReport.hold = maxf(BossReport.hold, 0.5)  # No boss paper while a war is on: it waits until the sheet has left.


func _input(event: InputEvent) -> void:
	if not _taking():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # No way out mid-war.
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	get_viewport().set_input_as_handled()  # The table behind takes nothing while the fight is on.
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(mouse.position)
	var dir := camera.project_ray_normal(mouse.position)
	if _dealing == null:  # Once the end plays out, nothing on the box lights again.
		_point(_pixel_under(mouse.position), _control.part_at(from, dir))
	_file_hover(_report.visible and _report.on_file(from, dir))
	var button := mouse as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed and _report.waiting:
		file_report()
		return
	if button.pressed and staging:
		proceed()
		return
	if _dealing != null:
		return
	if button.pressed:
		_press_spot(_hot)
	elif _held != null:
		drop(_mouse_pixel)


## Takes the farm `save` wins a war on: it joins the farms owned. Whether it was won (once). The
## war is paid for at its declaration: nothing is taken here.
static func win(save: SaveGame, farm_id: StringName) -> bool:
	if save.farms_owned.has(farm_id):
		return false
	save.farms_owned.append(farm_id)
	return true


## Counts the war on `site` that ended as `report` (WarReport.summary; a win's farm already ours)
## in `save`'s memo counters (wars_won...).
static func tally(save: SaveGame, site: StringName, report: Dictionary) -> void:
	if report.won:
		save.wars_won += 1
		var country := World.country_of(site)
		save.countries_annexed += int(country != World.HOME and World.owns_all(save, country))
		save.wars_exemplary += int(report.grade == WarReport.EXEMPLARY)
		var sent: Dictionary = report.deployed
		save.solo_wins += int(sent.values().reduce(func(a: int, b: int) -> int: return a + b, 0) == 1)
		save.associate_wins += int(sent.size() == 1 and sent.has("field_associate") and save.stamped.has(WarRules.UNIT_CARD.pult_crew))
		return
	save.wars_lost += 1
	if report.retreat:
		save.quick_retreats += int(report.seconds <= QUICK_RETREAT)
	else:
		save.untouched_losses += int(report.defences.x == 0)


## The war on `farm_id` begins with `chosen` (unit id -> figures taken, already out of save.army;
## MapTable.show_sheet calls it as the sheet rolls out): its map lies on the sheet, the figures stand
## on the desk and the fight is set up for planning. With no figures there is no fight: the roll in
## the holder leads back.
func begin(farm_id: StringName, chosen: Dictionary) -> void:
	farm = farm_id
	fight = null
	var camp := farm == BanditCamp.SITE
	if camp:
		_lay_camp(BanditCamp.map_for(SaveManager.save))
	else:
		_lay_map(WarMap.scene_for(farm, SaveManager.save))
	_buff = BanditCamp.buff(SaveManager.save) if camp else 1.0
	_view.setup(_map)
	_imprint.hide()
	_report.put_away()
	_held = null
	_unhover()
	_took = false
	_put_papers_away()
	var map_id := "" if camp else WarMap.map_id(farm, SaveManager.save)
	_print_title(map_id)
	var units: Array[String] = []
	for unit: String in WarRules.UNITS:  # Depot order.
		for k in int(chosen.get(unit, 0)):
			units.append(unit)
	if units.is_empty():
		reprint()
		return
	var save := SaveManager.save
	fight = WarFight.new(_map.layout(), _map.grid_size, WarRules.fight_seconds(save), WarRules.can_place_mid_round(save))
	for b in fight.buildings:  # A camp's defences: stronger by its buff (1 on a farm).
		b.hp *= _buff
		b.max_hp *= _buff
	for k in units.size():
		var holder := FightView.figure(units[k])
		_view.figures.add_child(holder)
		holder.position = _local(desk_pixel(k))
	_put_away()
	_control.scale = Vector3.ONE * 0.001
	_control.show()
	create_tween().tween_property(_control, "scale", Vector3.ONE, AWAY_TIME * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_control()
	var new: Array[String] = []
	if not camp:
		new = WarMap.debuts(map_id)
	debut = new[0] if not new.is_empty() else ""  # ponytail: one slip a map; the plan has one debut per map.
	staging = not camp and WarMap.is_final(map_id)
	_laying = create_tween()
	_laying.tween_interval(MapTable.swap_time())  # Once the sheet lies open.
	if staging:
		_final.final(_map.site_name if _map.site_name != "" else "ENDMARK ISLE", _map.briefing)
		_laying.tween_callback(_final.lay.bind(_final_rest, true))
	elif debut != "":
		_slip.debut(debut)
		_laying.tween_callback(_slip.lay.bind(_slip_rest))
	reprint()


## The title block: the site's code and name and its place in the campaign (map `map_id`).
func _print_title(map_id: String) -> void:
	var box := "Page/Sheet/TitleBlock/Box/"
	var camp := farm == BanditCamp.SITE  # No farm, no country: the camp and its level.
	(get_node(box + "Code") as Label).text = tr(BanditCamp.LEVEL_TEXT) % BanditCamp.level(SaveManager.save) if camp else tr("SITE %s") % FarmDeed.code(map_id)
	(get_node(box + "Site") as Label).text = tr(_map.site_name)
	(get_node(box + "Site") as Label).visible = _map.site_name != ""
	(get_node(box + "Sheet") as Label).text = tr("UNSCHEDULED") if camp else tr("SHEET %d OF %d") % [WarMap.sheet_number(map_id), WarMap.campaign().size()]


## FINAL ACQUISITION filed: it slides away, the farmhouse drops onto the paper with a beat and
## planning opens. Whether it was staging.
func proceed() -> bool:
	if not staging:
		return false
	staging = false
	if _laying != null:
		_laying.kill()
	_final.file()
	for node in _map.buildings():
		if WarMap.kind_of(node) == "farmhouse":
			var rest := node.position
			var fall := create_tween()
			fall.tween_property(node, "position:y", rest.y, BEAT_TIME).from(rest.y + BEAT_FROM) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.tween_callback(_beat_sound.cue.bind(node.global_position))
			fall.tween_property(node, "scale", Vector3.ONE, 0.3).from(Vector3(1.12, 0.8, 1.12)) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


## The defence (a building index) standing on cell-space point `p`, or -1.
func defence_at(p: Vector2) -> int:
	if fight == null:
		return -1
	for i in fight.buildings.size():
		var b := fight.buildings[i]
		if b.alive and b.kind in WarFight.DEFENCES and Rect2(Vector2(b.cell), Vector2(b.size)).has_point(p):
			return i
	return -1


## Rings defence `index`'s reach on the paper (its dead zone too, if it has one); -1 rubs it out.
func show_ring(index: int) -> void:
	if index < 0:
		_ink.ring(Vector2.ZERO, 0.0)
	else:
		var spec: Dictionary = WarFight.BUILDINGS[fight.buildings[index].kind]
		var cell := WarMap.CELL * PIXELS_PER_METRE
		_ink.ring(pixel_of_cell(fight.centre(index)), spec.range * cell, spec.min_range * cell)
	reprint()


## The way a figure of `unit` set down at cell-space point `spot` would walk to its first target (art
## px, from `spot`), as the fight would have it: a planning copy of this map's fight takes one sliver
## of a step. Empty if it could not stand there.
func path_line(unit: String, spot: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var probe := WarFight.new(_map.layout(), _map.grid_size, INF)
	if not probe.place_at(unit, WarRules.unit_stats(SaveManager.save, unit), spot) or not probe.start():
		return out
	probe.tick(0.001)
	out.append(pixel_of_cell(spot))
	for p: Vector2 in probe.units[0].path:
		out.append(pixel_of_cell(p))
	return out


## While planning: the ring of the defence under the mouse, the held figure's path line.
func _planning_ink(delta: float) -> void:
	var planning := fight.state == WarFight.State.PLANNING and _dealing == null and not staging
	var ring := defence_at(cell_at(_mouse_pixel)) if planning else -1
	if ring != _ringed:
		_ringed = ring
		show_ring(ring)
	_path_wait -= delta
	var routes := SaveManager.save.stamped.has(ROUTE_CARD)
	var spot := fight.snap(cell_at(_mouse_pixel)) if planning and routes and _held != null and on_paper(_mouse_pixel) else Vector2.INF
	if spot != _path_spot and (_path_wait <= 0.0 or spot == Vector2.INF):
		_path_spot = spot
		_path_wait = PATH_EVERY
		_pencil_line(path_line(_held.get_meta(&"unit"), spot) if spot != Vector2.INF else PackedVector2Array())


## Pencils `points` (art px) on the overlay over the board; empty rubs it out.
func _pencil_line(points: PackedVector2Array) -> void:
	_pencil.line(points)
	_pencil_page.render_target_update_mode = SubViewport.UPDATE_ONCE
	_pencil_overlay.visible = not points.is_empty()


## Whether art pixel `pixel` lies on the NEW STRUCTURE ON SITE slip while it is out (planning).
func on_slip(pixel: Vector2) -> bool:
	if debut == "" or not _slip.visible or fight == null or fight.state != WarFight.State.PLANNING:
		return false
	var corner := pixel_of(_slip.position - Vector3(_slip.size().x / 2.0, 0.0, 0.0))
	return Rect2(corner, _slip.size() * PIXELS_PER_METRE).has_point(pixel)


## The debut slip's card fades in (`on`) or out, like a hovered form's in the tray.
func _show_note(on: bool) -> void:
	if on == _noting:
		return
	_noting = on
	if on:
		_note_paper.set_card(WarSlip.card(debut))
	if _note_fade != null:
		_note_fade.kill()
	_note_fade = create_tween()
	_note_fade.tween_property(_note, "modulate:a", 1.0 if on else 0.0, NOTE_FADE)


## The mouse is on the after-action report's FILE REPORT (`on`): the box lights and the table's
## cursor points, as on any button at the map table.
func _file_hover(on: bool) -> void:
	if on == _on_file:
		return
	_on_file = on
	_report.hover(on)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if on else DisplayServer.CURSOR_ARROW)


## The slips gone and the paper's ink rubbed out.
func _put_papers_away() -> void:
	if _laying != null:
		_laying.kill()
	if _note_fade != null:
		_note_fade.kill()
	_noting = false
	_note.modulate.a = 0.0
	_on_file = false
	staging = false
	debut = ""
	_slip.put_away()
	_final.put_away()
	_ringed = -1
	_path_spot = Vector2.INF
	_ink.clear()
	_pencil_line(PackedVector2Array())


## Art pixel of desk place `k` (left of the sheet).
static func desk_pixel(k: int) -> Vector2:
	return FIGURE_AT + Vector2(FIGURE_STEP.x * (k % FIGURES_PER_ROW), FIGURE_STEP.y * floori(k / float(FIGURES_PER_ROW)))


## The figures not in the fight (on the desk, on the paper, or held), in the order taken.
func figures() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for holder: Node3D in _view.figures.get_children():
		if not holder.is_queued_for_deletion():
			out.append(holder)
	return out


## Figures not in the fight, all types.
func left() -> int:
	return figures().size()


## Cell-space point under art pixel `pixel`.
static func cell_at(pixel: Vector2) -> Vector2:
	return (pixel - GRID_AT) / (WarMap.CELL * PIXELS_PER_METRE)


## Art pixel of cell-space point `p`.
static func pixel_of_cell(p: Vector2) -> Vector2:
	return GRID_AT + p * WarMap.CELL * PIXELS_PER_METRE


## Whether figure `holder` stands off the paper (on the desk).
func on_desk(holder: Node3D) -> bool:
	return not on_paper(pixel_of(holder.position))


## Whether figure `holder` stands inside a deployment zone.
func in_zone(holder: Node3D) -> bool:
	return fight != null and not on_desk(holder) and fight.in_zone(cell_at(pixel_of(holder.position)))


## Figures standing on the battlefield outside every zone (they keep START shut).
func strays() -> int:
	return figures().filter(func(h: Node3D) -> bool: return h != _held and not on_desk(h) and not in_zone(h)).size()


## Whether a figure may be picked up now: planning, or running with TACTICS.
func can_place() -> bool:
	return fight != null and _dealing == null and not staging and (fight.state == WarFight.State.PLANNING \
			or (fight.state == WarFight.State.RUNNING and fight.mid_round))


## Whether START can be pressed: planning, nothing held, a figure in a zone and none astray.
func can_start() -> bool:
	return fight != null and _dealing == null and _held == null and fight.state == WarFight.State.PLANNING \
			and strays() == 0 and figures().any(in_zone)


## Whether ABORT does anything: before START it calls the war off; running, it is the RETREAT
## card's flee.
func can_abort() -> bool:
	if fight == null or _dealing != null:
		return false
	return fight.state == WarFight.State.PLANNING or can_retreat()


## Whether RETREAT can be called: the fight runs and the RETREAT card is stamped.
func can_retreat() -> bool:
	return fight != null and _dealing == null and fight.state == WarFight.State.RUNNING \
			and WarRules.retreat_share(SaveManager.save) > 0.0


## The figure nearest art pixel `pixel` within PICK_RADIUS, or null.
func figure_at(pixel: Vector2) -> Node3D:
	var best: Node3D = null
	var best_d := PICK_RADIUS
	for holder in figures():
		var d := pixel_of(holder.position).distance_to(pixel)
		if d < best_d:
			best = holder
			best_d = d
	return best


## Picks figure `holder` up into the hand; refused (the refusal sounds) if placing is closed.
func pick_up(holder: Node3D) -> bool:
	if _held != null or holder == null or not can_place() or not holder in figures():
		_denied_sound.cue(global_position)
		return false
	_held = holder
	_held_from = holder.position
	_mouse_pixel = pixel_of(holder.position)
	_sway = Vector2.ZERO
	_gripped = holder
	_glove.pose = HandModel.Pose.GRAB
	_pick_up_sound.cue(_held.global_position)
	return true


## Sets the figure held down at art pixel `pixel`: in a zone it stands there, near one it slides
## in, elsewhere on the paper it stands there (before START), off the paper it stands on the desk.
## Once the fight runs (TACTICS) only a zone takes it, straight into the fight; anywhere else it
## goes back where it was picked up. Whether it stands in a zone now.
func drop(pixel: Vector2) -> bool:
	if _held == null:
		return false
	var holder := _held
	_held = null
	holder.rotation = Vector3.ZERO
	_glove.pose = HandModel.Pose.OPEN
	_let_go = LET_GO
	var spot := fight.snap(cell_at(pixel)) if on_paper(pixel) else Vector2.INF
	var to := _held_from
	if spot != Vector2.INF:
		to = _local(pixel_of_cell(spot))
	elif fight.state == WarFight.State.PLANNING:
		to = _local(pixel if on_paper(pixel) else pixel.clamp(DESK.position, DESK.end))
	if fight.state == WarFight.State.RUNNING:
		if spot != Vector2.INF and _commit(holder, spot):
			SaveManager.autosave()  # Committed: a game closed now does not give it back.
		elif spot != Vector2.INF:
			_denied_sound.cue(global_position)
			to = _held_from
	_set_down_sound.cue(holder.global_position)
	if holder.get_parent() == _view.figures:
		_settle(holder, to)
	return holder.get_parent() != _view.figures or (spot != Vector2.INF and fight.state == WarFight.State.PLANNING)


## Picks figure `holder` up and sets it down at art pixel `pixel`: what a drag does.
func move(holder: Node3D, pixel: Vector2) -> bool:
	return pick_up(holder) and drop(pixel)


## Moves a figure of `unit` not in a zone yet into the middle of zone `zone` (the tests, the probes).
func place(unit: String, zone: int) -> bool:
	var holder: Node3D = null
	for h in figures():
		if h.get_meta(&"unit") == unit and not in_zone(h):
			holder = h
	if holder == null or fight == null or zone < 0 or zone >= fight.zones.size():
		return false
	return move(holder, pixel_of_cell(Rect2(fight.zones[zone]).get_center()))


## START: every figure standing in a zone goes into the fight (committed), and it runs. Refused
## (can_start) with nothing in a zone, a figure astray on the paper, or once started.
func start_fight() -> bool:
	if not can_start():
		return false  # The box thuds (WarControl.press).
	for holder in figures():
		if in_zone(holder):
			_commit(holder, cell_at(pixel_of(holder.position)))
	fight.start()
	SaveManager.save.war_fee = 0  # Started: the coins are spent for good.
	if fight.mid_round:
		fight.reserve = left()
	SaveManager.autosave()  # The placed ones are committed: a game closed now does not give them back.
	_start_sound.cue(global_position)
	if _music_fade != null:
		_music_fade.kill()
	_music.volume_db = 0.0
	_music.play()
	_slip.file()  # The debut slip goes; the paper's ink is rubbed out.
	_ringed = -1
	_path_spot = Vector2.INF
	_ink.clear()
	_pencil_line(PackedVector2Array())
	reprint()
	return true


## ABORT: before START the war is called off (nothing happened): every figure goes back to the army,
## the war's coins come back, and the sheet leaves for the country. Running, it is the flee
## (call_retreat). Whether it did anything.
func abort() -> bool:
	if not can_abort():
		return false  # The box thuds (WarControl.press).
	if fight.state == WarFight.State.RUNNING:
		return call_retreat()
	var save := SaveManager.save
	_held = null
	for holder in figures():
		var unit: String = holder.get_meta(&"unit")
		save.army[unit] = int(save.army.get(unit, 0)) + 1
		holder.queue_free()
	save.war_pending = {}
	save.war_fee = 0
	SaveManager.log_event("war_aborted", farm, BanditCamp.refund(save) if farm == BanditCamp.SITE else FarmRegister.refund(save, farm), "coins")
	SaveManager.autosave()
	_retreat_sound.cue(global_position)
	_leave()
	return true


## RETREAT: the fight ends LOST; WarRules.retreat_share of the figures placed and alive come home.
func call_retreat() -> bool:
	if not can_retreat():
		return false
	fight.retreat(WarRules.retreat_share(SaveManager.save))
	_retreat_sound.cue(global_position)
	return true


## Files the after-action report once its grade is on it: it slides away and the sheet leaves (the
## farm's moment on a win, back to the country otherwise). Whether it was waiting to be filed.
func file_report() -> bool:
	if fight == null or not _report.file():
		return false
	if fight.state == WarFight.State.WON:
		BossReport.hold = WarReport.SLIDE_TIME + MapTable.swap_time() + FarmRegister.LAMP_AFTER + FarmRegister.PAPER_AFTER
	_dealing = create_tween()
	_dealing.tween_interval(WarReport.SLIDE_TIME)
	_dealing.tween_callback(_leave)
	return true


## The war is on, or its end plays out: the table does not roll the sheet up under it.
func busy() -> bool:
	return fight != null


## Art pixel of a point in the sheet's own frame (MapSheet's layout: origin the middle of the top edge).
static func pixel_of(local: Vector3) -> Vector2:
	return Vector2(local.x + SIZE.x / 2.0, local.z) * PIXELS_PER_METRE


## A point in the sheet's frame on art pixel `pixel`: on the paper, or on the desk (DESK_Y) off it.
static func _local(pixel: Vector2) -> Vector3:
	return Vector3(pixel.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0 if on_paper(pixel) else DESK_Y, pixel.y / PIXELS_PER_METRE)


## The hint slip's words for a part of the control box.
func hint(spot: StringName) -> String:
	if fight == null:
		return ""
	if spot == START and fight.state == WarFight.State.PLANNING:
		if strays() > 0:
			return tr("Staff are standing outside the hatched zones. Move them in, or back onto the desk.")
		if not figures().any(in_zone):
			return tr("Set staff down in a hatched zone first.")
		return tr("Commence the engagement. Staff placed are committed.")
	if spot == ABORT:
		if fight.state == WarFight.State.PLANNING:
			return tr("Call it off. Staff and the war's fee are refunded.")
		var share := WarRules.retreat_share(SaveManager.save)
		return tr("%d%% of staff placed return") % roundi(share * 100.0) if share > 0.0 else tr("Not authorised.")
	return ""


## The hint slip lies beside the control box, over the paper's left edge.
func hint_pixel() -> Vector2:
	return pixel_of(_control.position) + Vector2(320.0, -120.0)


func _press_spot(spot: StringName) -> void:
	if spot == START:
		_control.press(spot)  # Its clack, or its thud while START is shut.
		start_fight()
	elif spot == ABORT:
		_control.press(spot)
		abort()
	elif _hot == &"figure":
		pick_up(figure_at(_mouse_pixel))


func _point(pixel: Vector2, part: StringName) -> void:
	_sway = (_sway + (pixel - _mouse_pixel) * SWAY_GAIN).limit_length(MAX_SWAY)
	_mouse_pixel = pixel
	var spot := &""
	if _held == null and part != &"":
		spot = part
	elif _held == null and can_place() and figure_at(pixel) != null:
		spot = &"figure"
	if spot != _hot:
		_hot = spot
		_control.hover(part if spot in [START, ABORT] else &"")
		var table := _table()
		if table != null:
			table.hover_spot(_hot if _hot in [START, ABORT] else &"")


## Nothing is hovered: the control box's glow and the table's hint slip go out.
func _unhover() -> void:
	_hot = &""
	_control.hover(&"")
	var table := _table()
	if table != null:
		table.hover_spot(&"")


## Puts figure `holder` into the fight at cell-space point `at` (it leaves save.war_pending: committed).
func _commit(holder: Node3D, at: Vector2) -> bool:
	var unit: String = holder.get_meta(&"unit")
	var stats := WarRules.unit_stats(SaveManager.save, unit)
	stats.hp = float(stats.hp) / _buff  # A camp's defences hit _buff times as hard.
	if not fight.place_at(unit, stats, at):
		return false
	var pending := SaveManager.save.war_pending
	if int(pending.get(unit, 0)) > 1:
		pending[unit] = int(pending[unit]) - 1
	else:
		pending.erase(unit)
	_view.add_unit(holder)
	return true


## Figure `holder` stands on `to` (sheet frame) at once and comes down onto it from where it is held.
func _settle(holder: Node3D, to: Vector3) -> void:
	holder.position = Vector3(to.x, maxf(holder.position.y, to.y), to.z)
	holder.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) 			.tween_property(holder, "position:y", to.y, SETTLE_TIME)


## The figure held follows the mouse over the paper and the desk, tilted by its sway.
func _carry(delta: float) -> void:
	var to := _local(_mouse_pixel) + Vector3.UP * CARRY
	_held.position = _held.position.lerp(to, minf(FOLLOW * delta, 1.0))
	_sway = _sway.lerp(Vector2.ZERO, minf(8.0 * delta, 1.0))
	_held.rotation = Vector3(_sway.y, 0.0, -_sway.x)


## The glove is the cursor while the sheet takes the mouse (`taking`) or holds a figure: it holds the
## figure carried by its head, swaying like the desk's hand, and opens over one just set down until
## LET_GO is over; over START or ABORT its fingertip taps the button (the desk's Hand.tap_lift);
## anywhere else it floats open under the mouse. Otherwise it is hidden and the cursor comes back.
func _hold_glove(delta: float, taking: bool) -> void:
	_let_go -= delta
	if _held == null and (_let_go <= 0.0 or not is_instance_valid(_gripped)):
		_gripped = null
	_glove.visible = _held != null or taking
	Hand.stand_in = _glove.visible
	if not _glove.visible:
		return
	var up := global_basis.y.normalized()
	if _gripped != null:
		_glove.pose = HandModel.Pose.GRAB if _held != null else HandModel.Pose.OPEN
		_glove_to(_gripped.global_transform * (Vector3.UP * GRIP), delta)
	elif _hot in [START, ABORT]:
		_glove.pose = HandModel.Pose.POINT
		var tap := DeskHand.tap_lift(Time.get_ticks_msec() / 1000.0, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		_glove_to(_control.part_position(_hot) + up * tap + global_basis.z.normalized() * TIP_BACK, delta)
	else:
		_glove.pose = HandModel.Pose.OPEN
		_glove_to(_hover_point(up), delta)


## Puts the glove's anchor for its pose on `target` (global).
func _glove_to(target: Vector3, delta: float) -> void:
	# HandModel offsets its anchor in its parent's space: undo the sheet's turn on it.
	var anchor := HandModel.ANCHORS[_glove.pose] as Vector3
	_glove.move_to(target + _glove.basis * anchor - _glove.global_basis * anchor, delta)


## Where the empty glove floats: HOVER over the paper, under the mouse on screen.
func _hover_point(up: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var hit: Variant = null
	if camera != null:
		var mouse := get_viewport().get_mouse_position()
		hit = Plane(up, global_position + up * HOVER).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return hit if hit != null else global_transform * _local(_mouse_pixel) + up * HOVER


## Music and SFX `k` of the way into the background (0: as they are, 1: DUCK_DB down, MUFFLE_DB more
## above DUCK_HZ). Never touches a bus's volume: the sliders own those.
static func duck(k: float) -> void:
	for bus_name in DUCKED:
		var bus := AudioServer.get_bus_index(bus_name)
		for i in AudioServer.get_bus_effect_count(bus) if bus >= 0 else 0:
			var effect := AudioServer.get_bus_effect(bus, i)
			if effect is AudioEffectAmplify:
				(effect as AudioEffectAmplify).volume_db = DUCK_DB * k
			elif effect is AudioEffectHighShelfFilter:
				var shelf := effect as AudioEffectHighShelfFilter
				shelf.cutoff_hz = DUCK_HZ
				shelf.gain = db_to_linear(MUFFLE_DB * k / 2.0)  # The shelf's gain counts twice in dB (measured).
			else:
				continue
			AudioServer.set_bus_effect_enabled(bus, i, k > 0.0)


## While a figure is held every zone glows, the one it would land in the most.
func _glow_zones() -> void:
	var spot := fight.snap(cell_at(_mouse_pixel)) if _held != null and on_paper(_mouse_pixel) else Vector2.INF
	var nodes := _map.zones()
	for i in nodes.size():
		var glow := 0.0
		if _held != null:
			glow = GLOW_HOT if spot != Vector2.INF and Rect2(fight.zones[i]).has_point(spot) else GLOW
		(nodes[i].get_node("Mesh") as GeometryInstance3D).set_instance_shader_parameter(&"glow", glow)


## The control box as the fight has it: its clock, START, ABORT.
func _show_control() -> void:
	var save := SaveManager.save
	_control.set_time(WarRules.fight_seconds(save) if fight == null else fight.time_left())
	var state := WarControl.State.READY
	if fight != null and fight.state == WarFight.State.RUNNING:
		state = WarControl.State.RUNNING
	elif fight != null and fight.state != WarFight.State.PLANNING:
		state = WarControl.State.ENDED
	_control.set_state(state)
	_control.set_start_enabled(can_start())
	_control.set_flee_allowed(can_abort())


## The map `path` lies on the board (the one there already stays).
func _lay_map(path: String) -> void:
	if _map != null and _map.scene_file_path == path:
		return
	if _map != null:
		_view.clear()  # The last war's placed figures stand on the old map: let go of them first.
		_map.free()
	_map = (load(path) as PackedScene).instantiate()
	_map.name = &"Map"
	_board.add_child(_map)


## The camp's map `map` (BanditCamp.map_for) lies on the board, in place of whatever lay there.
func _lay_camp(map: WarMap) -> void:
	if _map != null:
		_view.clear()
		_map.free()
	_map = map
	_map.name = &"Map"
	_board.add_child(_map)


## The fight is over: who comes home goes back into save.army, the stamp, and the sheet leaves.
func _end() -> void:
	if _held != null:
		drop(pixel_of(_held_from))
	var save := SaveManager.save
	var camp := farm == BanditCamp.SITE
	var coins := save.bandit_fee if camp else int(FarmRegister.war_bill(save, farm).get("coins", 0))  # What it cost (before the farm is ours).
	var report := WarReport.summary(fight)
	if not camp:
		save.war_grades[farm] = report.grade
	var home: Dictionary = fight.kept.duplicate()
	for holder in figures():
		var unit: String = holder.get_meta(&"unit")
		home[unit] = int(home.get(unit, 0)) + 1
		holder.queue_free()  # Back to the depot.
	for unit: String in home:
		if int(home[unit]) > 0:
			save.army[unit] = int(save.army.get(unit, 0)) + int(home[unit])
	save.war_pending = {}
	save.war_fee = 0
	var won := fight.state == WarFight.State.WON
	var paid := {}
	if camp:
		if won:
			paid = BanditCamp.win(save)
		else:
			BanditCamp.lose(save)
		SaveManager.log_event("camp_won" if won else "camp_lost", str(BanditCamp.level(save)), int(paid.get("coins", 0)), "coins")
	elif won:
		win(save, farm)
		SaveManager.log_event("war_won", farm)
		FarmRegister.lamp_held = true  # The Field Line's lamp waits for the farm's moment on its country's sheet.
	else:
		SaveManager.log_event("war_lost", farm)
	if not camp:
		tally(save, farm, report)
	SaveManager.autosave()
	(_won_sound if won else _lost_sound).cue(global_position)
	_fade_music()
	_imprint.visible = fight.end == WarFight.End.RETREAT  # A win or a loss is stamped on the report alone.
	_unhover()
	_show_control()
	reprint()
	if camp:
		_report.fill(farm, tr(BanditCamp.NAME), coins, report, camp_lines(paid, won))
	else:
		_report.fill(farm, _site_title(), coins, report)
	_dealing = create_tween()
	_dealing.tween_interval(LEAVE_AFTER if won else LOST_AFTER)
	_dealing.tween_callback(_report.lay.bind(_report_rest))


## What a camp's after-action report prints in place of a farm's site, outcome and remark: {site,
## outcome (a key), remark (text)}, the reward `paid` ({coins, findings, stock}) on a win.
static func camp_lines(paid: Dictionary, won: bool) -> Dictionary:
	var remark := TranslationServer.translate("The camp remains. Its occupants have been asked to leave in writing.")
	if won:
		remark = TranslationServer.translate("Recovered: %s, %s Findings and %s cabbages.") % ["$" + Num.text(int(paid.get("coins", 0))),
				Num.text(int(paid.get("findings", 0))), Num.text(int(paid.get("stock", 0)))]
	return {site = TranslationServer.translate("RECOVERY OPERATION"), outcome = "PROPERTY RECOVERED" if won else "RECOVERY UNSUCCESSFUL", remark = remark}


## The farm's name, from its country's sheet on the table ("": no table).
func _site_title() -> String:
	var table := _table()
	var country := table.sheet_of(World.country_of(farm)) as FarmRegister if table != null else null
	return country.site_title(farm) if country != null else ""


func _exit_tree() -> void:
	Hand.stand_in = false
	if fight != null:
		at_war = false
	if _ducked > 0.0:
		_ducked = 0.0
		duck(0.0)  # The scene left: the other sounds come back at once.
	if _dealing != null:
		FarmRegister.lamp_held = false  # An end cut off (the scene left) holds no lamp.


## The song fades out over MUSIC_FADE s under the win or loss stamp.
func _fade_music() -> void:
	if _music.playing:
		_music_fade = create_tween()
		_music_fade.tween_property(_music, "volume_db", -60.0, MUSIC_FADE)
		_music_fade.tween_callback(_music.stop)


func _leave() -> void:
	_music.stop()
	_dealing = null
	fight = null
	_held = null
	_gripped = null
	_glove.hide()
	Hand.stand_in = false
	_control.hide()
	_report.put_away()
	_put_papers_away()
	_unhover()
	_took = false
	_bring_back()
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	sheet_wanted.emit(&"world" if farm == BanditCamp.SITE else World.country_of(farm), farm)


## Whether the mouse is the sheet's: the fight is on, this sheet lies open at the map, nothing over it.
func _taking() -> bool:
	var table := _table()
	if fight == null or table == null or table.shown != id or table.swapping or not table.is_away() or BossReport.up:
		return false
	return not get_tree().get_nodes_in_group(&"blocks_hand").any(func(n: Node) -> bool:
		return n is CanvasItem and (n as CanvasItem).is_visible_in_tree() and n.name != &"Cursor")


## The art pixel under screen point `at` (the mouse at the map): on the paper's plane, also off it.
func _pixel_under(at: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var hit: Variant = Plane(global_basis.y.normalized(), global_position).intersects_ray(
			camera.project_ray_origin(at), camera.project_ray_normal(at))
	return pixel_at(hit as Vector3) if hit != null else Vector2(-1, -1)


func _table() -> MapTable:
	return get_parent().get_parent() as MapTable if get_parent() != null else null


## The way out and the currency column go away for the fight.
func _put_away() -> void:
	var table := _table()
	if table == null:
		return
	for path in EXITS:
		var node: Node3D = table.get_node_or_null(path)
		if node != null and not _away.has(node):
			_away[node] = [node.scale, node.visible]
			var tween := create_tween()
			tween.tween_property(node, "scale", Vector3.ONE * 0.001, AWAY_TIME) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			_away_tweens.append(tween)


## Keeps them away; the roll in the holder lifts off once it lies there.
func _keep_away() -> void:
	var table := _table()
	if table == null or _dealing != null:
		return
	for node: Node3D in _away:  # The table shows some of them again every frame (TO FARM, the depot).
		if node.scale.x < 0.01:
			node.hide()
	if _roll == null and not table.swapping and table.held() != &"":
		_roll = table.sheet_of(table.held())
		_roll_at = _roll.global_transform
		var tween := create_tween()
		tween.tween_property(_roll, "global_position", _roll_at.origin + MapTable.ARRIVE_FROM, AWAY_TIME * 2.0) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_roll.hide)
		_away_tweens.append(tween)


func _bring_back() -> void:
	for tween in _away_tweens:  # One still under way would put it away again.
		tween.kill()
	_away_tweens.clear()
	for node: Node3D in _away:
		if is_instance_valid(node):
			node.scale = _away[node][0]
			node.visible = _away[node][1]
	_away.clear()
	if _roll != null and is_instance_valid(_roll):
		_roll.global_transform = _roll_at
		_roll.show()
	_roll = null
