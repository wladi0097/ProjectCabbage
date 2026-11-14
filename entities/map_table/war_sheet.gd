extends MapSheet
## The war sheet (FORM 9-T THEATRE OF OPERATIONS): rolls out when war is declared on a farm nobody
## sells (FarmRegister), with that farm's country rolled up in the table's holder. The declaration
## pays for the war and hands over the figures taken (begin, research/war-contract.md); the fight
## is a WarFight on the map lying on the right (`Things/Map`, a WarMap: the test map for now).
## The fight: the way out goes away (TO DESK, TO FARM, the tally, the roll in the holder, Esc) and
## the figures taken stand in the tray on the left, one row per unit type with its count and stats.
## Pick one up (press) and drop it on a landing spot (release: the spots glow while one is held);
## anywhere else it goes back. START begins; after START placing is refused unless TACTICS
## (WarRules.can_place_mid_round). The clock counts the fight's time down; with the RETREAT card a
## RETREAT box calls it off (WarRules.retreat_share). FightView (`Field`) makes it seen.
## The end: WON (farmhouse down) the survivors go back into save.army, the farm is ours (win) and the
## sheet asks for its country's sheet again (`sheet_wanted`), where the farm's moment plays
## (FarmRegister.celebrate). LOST (time out, every figure down, retreat): a stamp, the retreat's share
## goes back into save.army, the placed figures are gone, the farm stays as it was. Figures never
## placed always go back. Everything hidden comes back as the sheet leaves.
## While the fight is on, the sheet takes the mouse itself (_input runs before the table's); else
## the table routes clicks as on any sheet (it has no spots then: the way back is the roll).
## Sounds: a figure picked up (PickUp) and set down (SetDown), START (Start), the clock's last
## seconds (Tick, TICK_FROM), RETREAT (Retreat), the end's stamp (Won, Lost), a refusal (Denied).
## Hand-built (tools/make_map_sheets.py no longer writes it). No class_name: whoever needs it
## preloads this script.

const World := preload("res://entities/map_table/world_register.gd")

## Unit ids -> their names on the tray (translated), and the target rules' words.
const NAMES := {field_associate = "FIELD ASSOCIATE", compliance_officer = "COMPLIANCE OFFICER",
		senior_asset = "SENIOR ASSET", pult_crew = "CABBAGE-PULT CREW"}
const TARGETS := {defence = "DEFENCES", tower = "TOWERS", wall = "WALLS"}
## The tray's rows (art px): the first's top-left corner, its size; its figures stand in staggered
## lines from FIGURE_AT (in the row), FIGURE_STEP apart, FIGURES_PER_LINE to a line, LINES lines
## (more figures than that stand in the last place).
const ROW_AT := Vector2(110.0, 440.0)
const ROW_SIZE := Vector2(900.0, 200.0)
const FIGURE_AT := Vector2(70.0, 70.0)
const FIGURE_STEP := Vector2(80.0, 45.0)
const FIGURES_PER_LINE := 4
const LINES := 3
## The START and RETREAT boxes (art px).
const START_BOX := Rect2(510.0, 1380.0, 470.0, 125.0)
const RETREAT_BOX := Rect2(510.0, 1525.0, 470.0, 125.0)
const START := &"start"
const RETREAT := &"retreat"
## A figure held is carried this high over the paper (m), swaying with the mouse like the glove's
## hold (HandModel's SWAY_GAIN / MAX_SWAY), and follows at this rate (1/s).
const CARRY := 0.06
const SWAY_GAIN := 0.004
const MAX_SWAY := 0.6
const FOLLOW := 22.0
## A landing spot glowing while a figure is held: its pulse (scale) and pace.
const PULSE := 0.1
const PULSE_PACE := 6.0
## From the end's stamp until the sheet asks for the country sheet again (s): a win, a loss.
const LEAVE_AFTER := 0.7
const LOST_AFTER := 1.8
## The table's nodes that go away while the fight is on (the way out and the currency column).
const EXITS: Array[String] = ["DeskButton", "FarmButton", "Tally", "Depot"]
const AWAY_TIME := 0.2
## The running clock ticks aloud from this many seconds left.
const TICK_FROM := 10

## The farm the war is for (&"": none yet).
var farm := &""
## The fight under way (null: none).
var fight: WarFight
## Unit id -> figures still in the tray (not placed).
var tray := {}
## The unit type of each tray row in use.
var rows: Array[String] = []
## The end playing out (null: none): from the stamp until the sheet leaves.
var _dealing: Tween
var _hot := &""
var _held: Node3D
var _held_unit := ""
var _mouse_pixel := Vector2.ZERO
var _sway := Vector2.ZERO
var _clock_shown := -1
## The table's nodes put away for the fight -> their scale; the roll in the holder lifted away and
## where it lay.
var _away := {}
var _roll: MapSheet
var _roll_at: Transform3D

@onready var _map: WarMap = $Things/Map
@onready var _view: FightView = $Field
@onready var _grid: Control = $Page/Sheet/Grid
@onready var _farm: Label = $Page/Sheet/Farm
@onready var _country: Label = $Page/Sheet/Country
@onready var _imprint: Label = $Page/Sheet/Imprint
@onready var _rows: Array[Control] = [$Page/Sheet/Row0, $Page/Sheet/Row1, $Page/Sheet/Row2, $Page/Sheet/Row3]
@onready var _clock: Label = $Page/Sheet/Clock
@onready var _start: Label = $Page/Sheet/Start
@onready var _start_hot: Panel = $Page/Sheet/StartHot
@onready var _retreat: Label = $Page/Sheet/Retreat
@onready var _retreat_note: Label = $Page/Sheet/RetreatNote
@onready var _retreat_hot: Panel = $Page/Sheet/RetreatHot
@onready var _won_sound: SoundCue = $Won
@onready var _lost_sound: SoundCue = $Lost
@onready var _pick_up_sound: SoundCue = $PickUp
@onready var _set_down_sound: SoundCue = $SetDown
@onready var _start_sound: SoundCue = $Start
@onready var _tick_sound: SoundCue = $Tick
@onready var _retreat_sound: SoundCue = $Retreat
@onready var _denied_sound: SoundCue = $Denied
@onready var _glow := preload("res://entities/war/fight/landing_glow.tres")
@onready var _glow_hot := preload("res://entities/war/fight/landing_hot.tres")


func _ready() -> void:
	super()
	_grid.position = pixel_of(_map.position)
	_grid.set(&"cells", _map.grid_size)
	_print()


func _process(delta: float) -> void:
	_view.visible = open > 0.999
	if fight == null:
		return
	_keep_away()
	if _held != null:
		_carry(delta)
	if fight.state == WarFight.State.RUNNING:
		fight.tick(delta)
	_view.follow(fight, delta)
	_glow_landings()
	if ceili(fight.time_left()) != _clock_shown:
		if fight.state == WarFight.State.RUNNING and ceili(fight.time_left()) in range(1, TICK_FROM + 1):
			_tick_sound.cue(global_position)
		_print()
	if _dealing == null and fight.state in [WarFight.State.WON, WarFight.State.LOST]:
		_end()


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
	_point(_pixel_under(mouse.position))
	var button := mouse as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or _dealing != null:
		return
	if button.pressed:
		_press_spot(_hot)
	elif _held != null:
		drop(int(String(_hot).trim_prefix("landing")) if String(_hot).begins_with("landing") else -1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_print()


## Takes the farm `save` wins a war on: it joins the farms owned. Whether it was won (once). The
## war is paid for at its declaration: nothing is taken here.
static func win(save: SaveGame, farm_id: StringName) -> bool:
	if save.farms_owned.has(farm_id):
		return false
	save.farms_owned.append(farm_id)
	return true


## The war on `farm_id` begins with `chosen` (unit id -> figures taken, already out of save.army;
## MapTable.show_sheet calls it as the sheet rolls out): the sheet is lettered for the farm and the
## fight is set up for planning. With no figures there is no fight: the roll in the holder leads back.
func begin(farm_id: StringName, chosen: Dictionary) -> void:
	farm = farm_id
	var table := _table()
	var register := table.sheet_of(World.country_of(farm)) as FarmRegister if table != null else null
	_letter(register.site_title(farm) if register != null else "", tr(register.title) if register != null else "")
	fight = null
	_view.setup(_map)
	_imprint.hide()
	tray = {}
	rows.clear()
	for unit: String in WarRules.UNITS:  # Depot order.
		if int(chosen.get(unit, 0)) > 0:
			tray[unit] = int(chosen[unit])
			rows.append(unit)
	if rows.is_empty():
		_print()
		return
	var save := SaveManager.save
	fight = WarFight.new(_map.layout(), _map.grid_size, WarRules.fight_seconds(save), WarRules.can_place_mid_round(save))
	if fight.mid_round:
		fight.reserve = left()
	for unit in rows:
		for k in tray[unit]:
			var holder := FightView.figure(unit)
			_view.tray.add_child(holder)
			holder.position = _local(tray_pixel(unit, k))
	_put_away()
	_print()


## Figures still in the tray, all types.
func left() -> int:
	var count := 0
	for unit: String in tray:
		count += int(tray[unit])
	return count


## Whether a figure may be placed now: planning, or running with TACTICS.
func can_place() -> bool:
	return fight != null and _dealing == null and (fight.state == WarFight.State.PLANNING \
			or (fight.state == WarFight.State.RUNNING and fight.mid_round))


## Whether RETREAT can be called: the fight runs and the RETREAT card is stamped.
func can_retreat() -> bool:
	return fight != null and _dealing == null and fight.state == WarFight.State.RUNNING \
			and WarRules.retreat_share(SaveManager.save) > 0.0


## Takes a figure of `unit` out of the tray into the hand; refused (the refusal sounds) if placing
## is closed or none is left.
func pick_up(unit: String) -> bool:
	if _held != null or not can_place() or int(tray.get(unit, 0)) <= 0:
		_denied_sound.cue(global_position)
		return false
	_held_unit = unit
	_held = _tray_figures(unit)[-1]
	_mouse_pixel = pixel_of(_held.position)
	_sway = Vector2.ZERO
	_pick_up_sound.cue(_held.global_position)
	return true


## Puts the figure held on landing spot `landing`; anywhere else (-1) or refused, it goes back to
## the tray. Whether it was placed.
func drop(landing: int) -> bool:
	if _held == null:
		return false
	var holder := _held
	var unit := _held_unit
	_held = null
	_held_unit = ""
	_set_down_sound.cue(holder.global_position)
	if landing < 0 or not can_place() or not fight.place(unit, WarRules.unit_stats(SaveManager.save, unit), landing):
		if landing >= 0:
			_denied_sound.cue(global_position)
		holder.rotation = Vector3.ZERO
		_print()  # The tray lays its figures out again.
		return false
	tray[unit] = int(tray[unit]) - 1
	_view.add_unit(holder)
	_print()
	return true


## Picks a figure of `unit` up and drops it on `landing`: what a drag does.
func place(unit: String, landing: int) -> bool:
	return pick_up(unit) and drop(landing)


## START: the fight runs. Refused with nothing placed, or once started.
func start_fight() -> bool:
	if fight == null or _dealing != null or not fight.start():
		_denied_sound.cue(global_position)
		return false
	_start_sound.cue(global_position)
	_print()
	return true


## RETREAT: the fight ends LOST; WarRules.retreat_share of the figures placed and alive come home.
func call_retreat() -> bool:
	if not can_retreat():
		return false
	fight.retreat(WarRules.retreat_share(SaveManager.save))
	_retreat_sound.cue(global_position)
	return true


## The war is on, or its end plays out: the table does not roll the sheet up under it.
func busy() -> bool:
	return fight != null


## Art pixel of tray figure `k` of `unit`.
func tray_pixel(unit: String, k: int) -> Vector2:
	var row := maxi(rows.find(unit), 0)
	var line := mini(int(k / float(FIGURES_PER_LINE)), 1)
	return ROW_AT + Vector2(0.0, ROW_SIZE.y * row) + FIGURE_AT \
			+ Vector2(FIGURE_STEP.x * (k % FIGURES_PER_LINE), FIGURE_STEP.y * line)


## Art pixel of a point in the sheet's own frame (MapSheet's layout: origin the middle of the top edge).
static func pixel_of(local: Vector3) -> Vector2:
	return Vector2(local.x + SIZE.x / 2.0, local.z) * PIXELS_PER_METRE


static func _local(pixel: Vector2) -> Vector3:
	return Vector3(pixel.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0, pixel.y / PIXELS_PER_METRE)


## Landing spot `i`'s square on the art (px).
func landing_rect(i: int) -> Rect2:
	var cell_px := WarMap.CELL * PIXELS_PER_METRE
	return Rect2(pixel_of(_map.position) + Vector2(fight.landings[i]) * cell_px, Vector2.ONE * cell_px)


## What the mouse at art pixel `pixel` is on: a tray row ("tray<n>"), START, RETREAT, or with a
## figure held a landing spot ("landing<i>").
func spot_under(pixel: Vector2) -> StringName:
	if fight == null:
		return &""
	if _held != null:
		for i in fight.landings.size():
			if landing_rect(i).grow(20.0).has_point(pixel):
				return StringName("landing%d" % i)
		return &""
	for r in rows.size():
		if Rect2(ROW_AT + Vector2(0.0, ROW_SIZE.y * r), ROW_SIZE).has_point(pixel) and int(tray[rows[r]]) > 0:
			return StringName("tray%d" % r)
	if START_BOX.has_point(pixel) and fight.state == WarFight.State.PLANNING:
		return START
	if RETREAT_BOX.has_point(pixel) and can_retreat():
		return RETREAT
	return &""


func _press_spot(spot: StringName) -> void:
	if spot == START:
		start_fight()
	elif spot == RETREAT:
		call_retreat()
	elif String(spot).begins_with("tray"):
		pick_up(rows[int(String(spot).trim_prefix("tray"))])


func _point(pixel: Vector2) -> void:
	_sway = (_sway + (pixel - _mouse_pixel) * SWAY_GAIN).limit_length(MAX_SWAY)
	_mouse_pixel = pixel
	var spot := spot_under(pixel)
	if spot != _hot:
		_hot = spot
		_start_hot.visible = _hot == START
		_retreat_hot.visible = _hot == RETREAT
		reprint()
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG if _held != null \
			else DisplayServer.CURSOR_POINTING_HAND if _hot != &"" else DisplayServer.CURSOR_ARROW)


## The figure held follows the mouse over the paper, tilted by its sway.
func _carry(delta: float) -> void:
	var to := _local(_mouse_pixel) + Vector3.UP * CARRY
	_held.position = _held.position.lerp(to, minf(FOLLOW * delta, 1.0))
	_sway = _sway.lerp(Vector2.ZERO, minf(8.0 * delta, 1.0))
	_held.rotation = Vector3(_sway.y, 0.0, -_sway.x)


func _glow_landings() -> void:
	var pulse := 1.0 + PULSE * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * PULSE_PACE))
	var landings := _map.landings()
	for i in landings.size():
		var mesh: MeshInstance3D = landings[i].get_node("Mesh")
		var hot := _hot == StringName("landing%d" % i)
		mesh.material_overlay = null if _held == null else _glow_hot if hot else _glow
		landings[i].scale = Vector3.ONE * (1.0 if _held == null else pulse * (1.15 if hot else 1.0))


## The fight is over: who comes home goes back into save.army, the stamp, and the sheet leaves.
func _end() -> void:
	if _held != null:
		drop(-1)
	var save := SaveManager.save
	var home: Dictionary = fight.kept.duplicate()
	for unit: String in tray:
		home[unit] = int(home.get(unit, 0)) + int(tray[unit])
	for unit: String in home:
		if int(home[unit]) > 0:
			save.army[unit] = int(save.army.get(unit, 0)) + int(home[unit])
	tray = {}
	for holder in _view.tray.get_children():
		holder.queue_free()  # Back to the depot.
	var won := fight.state == WarFight.State.WON
	if won:
		win(save, farm)
		SaveManager.log_event("war_won", farm)
		FarmRegister.lamp_held = true  # The Field Line's lamp waits for the farm's moment on its country's sheet.
		BossReport.hold = LEAVE_AFTER + MapTable.swap_time() + FarmRegister.LAMP_AFTER + FarmRegister.PAPER_AFTER
		_imprint.text = "VICTORY"
	else:
		SaveManager.log_event("war_lost", farm)
		_imprint.text = "WITHDRAWN" if fight.end == WarFight.End.RETREAT else "ACQUISITION UNSUCCESSFUL"
	SaveManager.autosave()
	(_won_sound if won else _lost_sound).cue(global_position)
	_imprint.show()
	_hot = &""
	_print()
	_dealing = create_tween()
	_dealing.tween_interval(LEAVE_AFTER if won else LOST_AFTER)
	_dealing.tween_callback(_leave)


func _exit_tree() -> void:
	if _dealing != null:
		FarmRegister.lamp_held = false  # An end cut off (the scene left) holds no lamp.


func _leave() -> void:
	_dealing = null
	fight = null
	_bring_back()
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	sheet_wanted.emit(World.country_of(farm), farm)


func _letter(called: String, country: String) -> void:
	_farm.text = ("%s  (%s)" % [called, FarmDeed.code(farm)]).strip_edges()
	_country.text = country
	reprint()


## Prints the tray, the clock and the boxes as the fight has them.
func _print() -> void:
	var save := SaveManager.save
	for r in _rows.size():
		_rows[r].visible = r < rows.size()
		if r < rows.size():
			var unit := rows[r]
			var stats := WarRules.unit_stats(save, unit)
			(_rows[r].get_node("Name") as Label).text = tr(NAMES.get(unit, unit))
			(_rows[r].get_node("Count") as Label).text = "x %d" % int(tray.get(unit, 0))
			(_rows[r].get_node("Stats") as Label).text = tr("HP %d  ·  DAMAGE %d  ·  SPEED %s") \
					% [roundi(stats.hp), roundi(stats.damage), "%.1f" % stats.speed] \
					+ "\n" + tr("TARGET: %s") % tr(TARGETS.get(stats.target, stats.target))
	for unit in rows:  # The figures left stand in their places again.
		var figures := _tray_figures(unit)
		for k in figures.size():
			if figures[k] != _held:
				figures[k].position = _local(tray_pixel(unit, k))
	var seconds := WarRules.fight_seconds(save) if fight == null else fight.time_left()
	_clock_shown = ceili(seconds)
	_clock.text = "%d:%02d" % [floori(_clock_shown / 60.0), _clock_shown % 60]
	var planning := fight != null and fight.state == WarFight.State.PLANNING
	_start.text = "START" if planning or fight == null else "ENGAGED"
	_start_hot.visible = _hot == START
	var share := WarRules.retreat_share(save)  # Without the RETREAT card the box is printed, not authorised.
	_retreat.modulate.a = 1.0 if share > 0.0 else 0.35
	_retreat_note.text = tr("%d%% of staff placed return") % roundi(share * 100.0) if share > 0.0 else tr("Not authorised.")
	_retreat_hot.visible = _hot == RETREAT
	reprint()


func _tray_figures(unit: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for holder: Node3D in _view.tray.get_children():
		if holder.get_meta(&"unit", "") == unit and not holder.is_queued_for_deletion():
			out.append(holder)
	return out


## Whether the mouse is the sheet's: the fight is on, this sheet lies open at the map, nothing over it.
func _taking() -> bool:
	var table := _table()
	if fight == null or table == null or table.shown != id or table.swapping or not table.is_away() or BossReport.up:
		return false
	return not get_tree().get_nodes_in_group(&"blocks_hand").any(func(n: Node) -> bool:
		return n is CanvasItem and (n as CanvasItem).is_visible_in_tree() and n.name != &"Cursor")


## The art pixel under screen point `at` (the mouse at the map).
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
			create_tween().tween_property(node, "scale", Vector3.ONE * 0.001, AWAY_TIME) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


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


func _bring_back() -> void:
	for node: Node3D in _away:
		if is_instance_valid(node):
			node.scale = _away[node][0]
			node.visible = _away[node][1]
	_away.clear()
	if _roll != null and is_instance_valid(_roll):
		_roll.global_transform = _roll_at
		_roll.show()
	_roll = null
