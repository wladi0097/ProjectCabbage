class_name MapTable
extends Node3D
## Chapter 3's map table, on the desk's right wing (out of the desk view): one paper map sheet
## (MapSheet) lies open under four drafting weights, the others wait rolled up in the chart rack at
## the wall, their cores' ends in its cheeks' saddles (props/: the weights, the rack, the button)
## (the sheets are the children of `Sheets`, each in the rack slot of its place there; the first lies
## open at the start: to add or replace a sheet, change the instance there).
## Along the table's right edge lies the tally (props/map_tally: `Tally`): the company's coins,
## cabbages, Findings and farms in four windows.
## Only the sheets the save has are on the table (SHEET_CARDS, on_table): the country sheet from the
## start, the world sheet once its desk card is stamped; the others are hidden, cannot be picked or
## shown, and their saddles in the rack are empty with a blank label holder. A sheet unlocked during
## play arrives the next time the camera is at the map: its roll drops into its saddle (ARRIVE_*,
## the `Arrive` cue as it lands) and its name pops into the holder; a loaded save has it there already.
## go_to_map() glides the camera over the sheet like the farm TV's pan (FarmTv.view_at) and
## back_to_desk() (the TO DESK button, Esc) glides it home; while it is away the hand hides and the OS
## cursor comes back (`Cursor`, FarmTv.away: the one "camera is off the desk" flag both share). At the
## map a click on a rolled sheet swaps it in; show_sheet(id) does the same from code. A click on a
## spot of the open sheet, or on nothing at all, is the sheet's business (the country sheet's farm
## sites and their deeds: FarmRegister). The corner has
## its own cold work light (`Lights`), faded in with the pan so the desk view keeps its look.
## Sounds (cues in the scene): ViewIn as the light comes up, ViewOut as it starts to dim on the way
## home, Swap for a whole swap (one file, its hits on the steps below), Hover on anything the mouse
## takes hold of; the TO DESK button and the farm sites sound for themselves.
## Everything is hidden and does nothing until chapter 3 opens (GameEvents.chapter_3). Sits at the
## world origin; the layout is in map_table.tscn.
##
## The swap, in seconds from the request (assets/audio/sources/map_swap/layers puts a hit on each
## step: change both together):
## WEIGHTS_OFF_AT the weights hop off the corners, the things on the sheet tuck away and the free
## edge curls up; ROLL_UP_AT the sheet rolls itself up towards the rack; FETCH_AT the new roll
## leaves its slot; STOW_AT the old roll hops to its slot; LAND_AT the new roll lands with a little
## bounce; UNROLL_AT it unrolls across the desk, its edge still curled; WEIGHTS_ON_AT the weights
## drop onto its corners and pin the edge; POP_AT what stands on it pops up in a wave.

const Events := preload("res://globalScripts/game_events.gd")
const Tally := preload("res://entities/map_table/props/map_tally.gd")

const PAN_TIME := 1.1
## The work light is fully up from this much of the pan on (and starts to dim there on the way home).
const LIGHT_FULL := 0.6

const WEIGHTS_OFF_AT := 0.0
const WEIGHT_HOP_TIME := 0.2
const WEIGHT_STAGGER := 0.03
const TUCK_TIME := 0.12
const TUCK_STAGGER := 0.01
const CURL_TIME := 0.14
const ROLL_UP_AT := 0.14
const ROLL_UP_TIME := 0.42
const FETCH_AT := 0.46
const STOW_AT := 0.54
const FLIGHT_TIME := 0.3
const LAND_AT := FETCH_AT + FLIGHT_TIME
const BOUNCE_TIME := 0.14
const UNROLL_AT := LAND_AT + 0.07
const UNROLL_TIME := 0.42
const WEIGHTS_ON_AT := UNROLL_AT + UNROLL_TIME - 0.06
const WEIGHT_DROP_TIME := 0.16
const WEIGHT_DROP_STAGGER := 0.04
const SETTLE_TIME := 0.3
const POP_AT := WEIGHTS_ON_AT + 0.14
const POP_TIME := 0.2
const POP_STAGGER := 0.022

## A weight hops this high (m) and lands this far beyond the sheet's end (m, along the sheet's width).
const WEIGHT_HOP := 0.22
const WEIGHT_ASIDE := 0.3
const WEIGHT_SQUASH := Vector3(1.18, 0.68, 1.18)
## How a roll's flight bulges (m): the old one up and over, the new one out towards the viewer.
const STOW_ARC := Vector3(0.0, 0.3, 0.0)
const FETCH_ARC := Vector3(-0.3, 0.12, 0.0)
const BOUNCE := 0.04
## Hovered, a roll in the rack lifts this far off its pegs (m, s).
const HOVER_LIFT := 0.035
const HOVER_TIME := 0.12
## Half sizes (m) of the click targets, on their frames (FarmTv.rect_uv): a roll in the rack (along
## it, across it) and the TO DESK plate.
const ROLL_HALF := Vector2(1.6, 0.066)
const BACK_HALF := Vector2(0.15, 0.065)
const BACK := &"back"
## The desk card (UpgradeDesk.CARDS) that puts a sheet's roll in the rack; "": there from the start.
## A sheet not listed never comes (the district sheet: a stand-in for the later fighting maps).
const SHEET_CARDS := {&"country": "", &"world": "world_map"}
## A sheet's arrival: its roll comes down from this far off its saddle (m: up, and from the wall's
## side), waits ARRIVE_AFTER s once the camera is there, falls for ARRIVE_TIME s and bounces
## ARRIVE_BOUNCE m; its name pops into the holder from NAME_POP times its size.
const ARRIVE_FROM := Vector3(0.25, 0.9, 0.0)
const ARRIVE_AFTER := 0.35
const ARRIVE_TIME := 0.38
const ARRIVE_BOUNCE := 0.05
const NAME_POP := 1.6
## Where the hint slip lies for a spot of the open sheet: its top left corner on this art pixel (the
## sea, top left: off the country, so it never covers a site's tags; a sheet may name another,
## MapSheet.hint_pixel: the world sheet's sea is free bottom left) and this wide (px), wrapping.
const SPOT_HINT_PIXEL := MapSheet.HINT_PIXEL
const SPOT_HINT_WIDTH := 400.0

## The sheet lying open (or on its way out during a swap), and whether a swap is running.
var shown := &""
var swapping := false

## The sheets on the table (lying open or rolled in the rack), and the arrival running, if any.
var _on_table: Array[StringName] = []
var _arrive_tween: Tween
## The sheet asked for during a swap (the last request wins): swapped in right after.
var _queued := &""
## What the mouse is on at the map: BACK, a rolled sheet's id, a spot on the open sheet, or nothing.
var _hovered := &""
## Where the mouse is at the map (px): the hint slip hangs below it.
var _mouse_at := Vector2.ZERO
## 0 on the desk, 1 at the map.
var _view := 0.0
var _at_map := false
var _pan_tween: Tween
var _swap_tween: Tween
var _hover_tween: Tween
var _camera: Camera3D
var _desk_view: Transform3D
var _lamp_energy: Array[float] = []
## Each weight's place on its corner (its transform in the scene).
var _weight_rest: Array[Vector3] = []

@onready var _map_view: Marker3D = $View
@onready var _lay: Marker3D = $Lay
@onready var _slots: Array[Marker3D] = [$Rack/Slot0, $Rack/Slot1, $Rack/Slot2]
@onready var _back: Marker3D = $Back
@onready var _button: Node3D = $DeskButton
@onready var _stencil: Label3D = $DeskButton/Stencil
@onready var _stencil_ink := _stencil.modulate
@onready var _lamps: Array[Light3D] = [$Lights/Key, $Lights/Fill]
@onready var _cursor: Control = $Cursor
@onready var _hint: Label = $HintLayer/Hint
@onready var _names: Node3D = $Rack/ChartRack/Names
@onready var _tally: Tally = $Tally
@onready var _swap_sound: SoundCue = $Swap
@onready var _arrive_sound: SoundCue = $Arrive
@onready var _view_in_sound: SoundCue = $ViewIn
@onready var _view_out_sound: SoundCue = $ViewOut
@onready var _hover_sound: SoundCue = $Hover


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	if _camera != null:
		_desk_view = _camera.transform
	for light in _lamps:
		_lamp_energy.append(light.light_energy)
	for weight: Node3D in $Weights.get_children():
		_weight_rest.append(weight.position)
	shown = sheets()[0].id  # The first sheet under `Sheets` lies open at the start.
	for sheet in sheets():
		var out := sheet.id == shown
		if sheet_unlocked(sheet.id, SaveManager.save):
			_on_table.append(sheet.id)
		sheet.visible = on_table(sheet.id)
		_names.get_child(sheet.get_index()).visible = on_table(sheet.id)
		sheet.global_transform = _lay.global_transform if out else _stowed(sheet)
		sheet.open = 1.0 if out else 0.0
		for i in sheet.thing_count():
			sheet.raise_thing(1.0 if out else 0.0, i)
	visible = unlocked(SaveManager.save)
	_set_view(0.0)


func _process(_delta: float) -> void:
	visible = unlocked(SaveManager.save)
	_cursor.visible = _view > 0.0
	if _view >= 1.0 and _arrive_tween == null and not swapping:
		for sheet in sheets():
			if not on_table(sheet.id) and sheet_unlocked(sheet.id, SaveManager.save):
				_arrive(sheet)
				break
	_hint.visible = FarmTv.hint_shown(_hovered != &"", BossReport.up)
	if _hint.visible:
		var spot := _on_spot()
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if spot else TextServer.AUTOWRAP_OFF
		_hint.size = Vector2(SPOT_HINT_WIDTH if spot else 0.0, 0.0)  # As small as its text lets it.
		_hint.position = _mouse_at + Vector2(18.0, 26.0)
		if spot:
			_hint.position = _camera.unproject_position(sheet_of(shown).point_at(sheet_of(shown).hint_pixel()))
			_hint.text = sheet_of(shown).hint(_hovered)  # Its price, and what is short, as they change.
			_hint.visible = _hint.text != ""  # A spot with nothing to say (a deed lies there).


func _input(event: InputEvent) -> void:
	# As the farm TV: _input so Esc is ours before the pause menu; a boss report or an open menu
	# takes the mouse instead.
	if not FarmTv.takes_input(_at_map, BossReport.up, _menu_open()):
		return
	if event.is_action_pressed("ui_cancel"):
		back_to_desk()
		get_viewport().set_input_as_handled()
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	get_viewport().set_input_as_handled()  # Nothing behind the map view takes the mouse.
	_mouse_at = mouse.position
	_hover(pick(_camera.project_ray_origin(mouse.position), _camera.project_ray_normal(mouse.position)))
	var button := mouse as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if _hovered == BACK:
			_button.press()
			back_to_desk()
		elif _hovered != &"" and on_table(_hovered):
			show_sheet(_hovered)
		else:
			# A spot on the open sheet (a farm site, its deed's stamp box), or a click on nothing,
			# which the sheet hears too (it puts a farm's deed away).
			sheet_of(shown).press(_hovered)


## Seconds into the pan home from `view` (1 at the map) until the work light starts to dim.
static func light_off_after(view: float) -> float:
	return PAN_TIME * maxf(view - LIGHT_FULL, 0.0)


## Whether the map table exists yet for `save`: from chapter 3 on.
static func unlocked(save: SaveGame) -> bool:
	return Events.chapter_3(save)


## Whether sheet `id` belongs on the table for `save`: its card (SHEET_CARDS) is stamped, or it needs none.
static func sheet_unlocked(id: StringName, save: SaveGame) -> bool:
	return SHEET_CARDS.has(id) and (SHEET_CARDS[id] == "" or save.stamped.has(SHEET_CARDS[id]))


## Whether sheet `id` is on the table: lying open or rolled in the rack (not locked, not still arriving).
func on_table(id: StringName) -> bool:
	return id in _on_table


## Glides the camera from the desk to the map table. Nothing before chapter 3, or while the camera
## is away elsewhere (the farm TV).
func go_to_map() -> void:
	if _at_map or not unlocked(SaveManager.save) or _camera == null or (FarmTv.away and _view <= 0.0):
		return
	_pan(true)


## Glides the camera home to the desk view.
func back_to_desk() -> void:
	if _at_map:
		_pan(false)


## Whether the camera is at the map table or on its way there or back (not at the desk).
func is_away() -> bool:
	return _at_map or _view > 0.0


## To the map from the desk, home from the map (the debug key; in the game the FieldLine's handset).
func toggle_view() -> void:
	if _at_map:
		back_to_desk()
	else:
		go_to_map()


## Swaps sheet `id` (a MapSheet.id under `Sheets`: "country", "world") in for the one lying open. The
## sheet already out changes nothing, nor does one that is not on the table (on_table); asked during a swap, it is remembered (the last request wins) and swapped in
## as soon as the running swap is done.
func show_sheet(id: StringName) -> void:
	if not on_table(id) or sheet_of(shown).busy():
		return  # Not there, or a purchase plays out on the open sheet: it is not rolled up under it.
	if swapping:
		_queued = id
	elif id != shown:
		_swap(sheet_of(shown), sheet_of(id))


func sheets() -> Array[MapSheet]:
	var out: Array[MapSheet] = []
	for child in $Sheets.get_children():
		out.append(child as MapSheet)
	return out


func sheet_of(id: StringName) -> MapSheet:
	for sheet in sheets():
		if sheet.id == id:
			return sheet
	return null


## What a ray from the map camera is on: BACK (the TO DESK plate), the id of a sheet rolled up in
## the rack (the upper rolls lie over the lower ones), a spot on the open sheet (MapSheet.spot_at:
## a farm site's id), or nothing.
func pick(from: Vector3, dir: Vector3) -> StringName:
	if FarmTv.on_glass(FarmTv.rect_uv(_back.global_transform, BACK_HALF, from, dir)):
		return BACK
	var all := sheets()
	for i in range(all.size() - 1, -1, -1):
		if all[i].id != shown and on_table(all[i].id) and FarmTv.on_glass(FarmTv.rect_uv(_slots[i].global_transform, ROLL_HALF, from, dir)):
			return all[i].id
	return sheet_of(shown).spot_at(sheet_pixel(from, dir))


## The art pixel of the open sheet (0..3200, 0..1800) that a ray (the mouse at the map) hits, or
## (-1, -1) off the paper or during a swap: how farm sites and countries are clicked.
func sheet_pixel(from: Vector3, dir: Vector3) -> Vector2:
	var hit: Variant = Plane(Vector3.UP, _lay.global_position.y).intersects_ray(from, dir)
	if hit == null or swapping:
		return Vector2(-1, -1)
	var pixel := sheet_of(shown).pixel_at(hit as Vector3)
	return pixel if MapSheet.on_paper(pixel) else Vector2(-1, -1)


## Where a rolled-up `sheet` rests in the rack: its roll's middle on its slot.
func _stowed(sheet: MapSheet) -> Transform3D:
	var slot := _slots[sheet.get_index()].global_position
	return Transform3D(_lay.global_basis, slot - Vector3.UP * MapSheet.roll_radius(0.0))


func _swap(old: MapSheet, new: MapSheet) -> void:
	shown = new.id
	swapping = true
	_hover(&"")
	_swap_sound.cue(_lay.global_position)
	var lay := _lay.global_transform
	var weights := $Weights.get_children()
	_swap_tween = create_tween().set_parallel()
	# The weights hop off, the things tuck away, the free edge curls up.
	for i in weights.size():
		_swap_tween.tween_method(_hop_weight.bind(i), 0.0, 1.0, WEIGHT_HOP_TIME) \
				.set_delay(WEIGHTS_OFF_AT + i * WEIGHT_STAGGER).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in old.thing_count():
		_swap_tween.tween_method(old.raise_thing.bind(i), 1.0, 0.0, TUCK_TIME) \
				.set_delay(WEIGHTS_OFF_AT + i * TUCK_STAGGER).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_swap_tween.tween_property(old, "lift", 1.0, CURL_TIME).set_delay(WEIGHTS_OFF_AT) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The old sheet rolls itself up and hops to its slot.
	_swap_tween.tween_property(old, "open", 0.0, ROLL_UP_TIME).set_delay(ROLL_UP_AT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_swap_tween.tween_method(_fly.bind(old, lay, _stowed(old), STOW_ARC), 0.0, 1.0, FLIGHT_TIME) \
			.set_delay(STOW_AT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swap_tween.tween_property(old, "lift", 0.0, 0.01).set_delay(STOW_AT)
	# The new roll flies out, lands with a little bounce and unrolls, its edge still curled.
	_swap_tween.tween_method(_fly.bind(new, _stowed(new), lay, FETCH_ARC), 0.0, 1.0, FLIGHT_TIME) \
			.set_delay(FETCH_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swap_tween.tween_method(_bounce.bind(new, lay.origin), 0.0, 1.0, BOUNCE_TIME).set_delay(LAND_AT)
	_swap_tween.tween_property(new, "lift", 1.0, 0.01).set_delay(LAND_AT)
	_swap_tween.tween_property(new, "open", 1.0, UNROLL_TIME).set_delay(UNROLL_AT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The weights drop onto the corners with a squash and pin the edge; the things pop up in a wave.
	for i in weights.size():
		var at := WEIGHTS_ON_AT + i * WEIGHT_DROP_STAGGER
		_swap_tween.tween_method(_hop_weight.bind(i), 1.0, 0.0, WEIGHT_DROP_TIME) \
				.set_delay(at).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_swap_tween.tween_property(weights[i], "scale", Vector3.ONE, SETTLE_TIME).from(WEIGHT_SQUASH) \
				.set_delay(at + WEIGHT_DROP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_swap_tween.tween_property(new, "lift", 0.0, SETTLE_TIME).set_delay(WEIGHTS_ON_AT + WEIGHT_DROP_TIME) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for i in new.thing_count():
		_swap_tween.tween_method(new.raise_thing.bind(i), 0.0, 1.0, POP_TIME) \
				.set_delay(POP_AT + i * POP_STAGGER).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swap_tween.finished.connect(_swap_done)


## `sheet`'s roll drops into its saddle in the rack; from the landing on it is on the table.
func _arrive(sheet: MapSheet) -> void:
	var rest := _stowed(sheet)
	var from := rest.translated(ARRIVE_FROM)
	sheet.global_transform = from
	_arrive_tween = create_tween()
	_arrive_tween.tween_interval(ARRIVE_AFTER)
	_arrive_tween.tween_callback(sheet.show)
	_arrive_tween.tween_method(_fly.bind(sheet, from, rest, Vector3.ZERO), 0.0, 1.0, ARRIVE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_arrive_tween.tween_callback(_landed.bind(sheet))
	_arrive_tween.tween_method(_bounce.bind(sheet, rest.origin, ARRIVE_BOUNCE), 0.0, 1.0, BOUNCE_TIME)
	_arrive_tween.finished.connect(func() -> void: _arrive_tween = null)


func _landed(sheet: MapSheet) -> void:
	_on_table.append(sheet.id)
	_arrive_sound.cue(sheet.global_position)
	var name_tag: Node3D = _names.get_child(sheet.get_index())
	name_tag.show()
	create_tween().tween_property(name_tag, "scale", Vector3.ONE, SETTLE_TIME).from(Vector3.ONE * NAME_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _swap_done() -> void:
	swapping = false
	var next := _queued
	_queued = &""
	if next != &"":
		show_sheet(next)


## Weight `i` `k` of the way (0 on its corner .. 1 beside the sheet) along its hop.
func _hop_weight(k: float, i: int) -> void:
	var weight: Node3D = $Weights.get_child(i)
	var rest := _weight_rest[i]
	var aside := rest + Vector3(0.0, 0.0, signf(rest.z - _lay.position.z) * WEIGHT_ASIDE)
	weight.position = rest.lerp(aside, k) + Vector3.UP * sin(k * PI) * WEIGHT_HOP


## A rolled `sheet` `k` of the way from `from` to `to`, its path bulging by `arc` in the middle.
func _fly(k: float, sheet: MapSheet, from: Transform3D, to: Transform3D, arc: Vector3) -> void:
	sheet.global_transform = from.interpolate_with(to, k)
	sheet.global_position += arc * sin(clampf(k, 0.0, 1.0) * PI)


func _bounce(k: float, sheet: MapSheet, at: Vector3, height := BOUNCE) -> void:
	sheet.global_position = at + Vector3.UP * sin(k * PI) * height


func _hover(what: StringName) -> void:
	if what == _hovered:
		return
	_hovered = what
	if what != &"":
		_hover_sound.cue(_lay.global_position)
	_stencil.modulate = Color(0.95, 0.97, 0.96) if what == BACK else _stencil_ink
	if what == BACK:
		_hint.text = "Back to the desk"
	elif on_table(what):
		_hint.text = sheet_of(what).title
	elif what != &"":
		_hint.text = sheet_of(shown).hint(what)
	for sheet in sheets():
		sheet.hover(what)  # A spot on the open sheet lifts; anything else lets it down.
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if what != &"" else DisplayServer.CURSOR_ARROW)
	if swapping:
		return  # The rolls are flying: none is lifted.
	if _hover_tween != null:
		_hover_tween.kill()
	var rolls := sheets().filter(func(sheet: MapSheet) -> bool: return sheet.id != shown and on_table(sheet.id))
	if rolls.is_empty():
		return  # The rack is empty.
	_hover_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for sheet: MapSheet in rolls:
		var lift := HOVER_LIFT if sheet.id == what else 0.0
		_hover_tween.tween_property(sheet, "global_position:y", _stowed(sheet).origin.y + lift, HOVER_TIME)


## Whether the mouse is on a spot of the open sheet (not the plate, not a roll).
func _on_spot() -> bool:
	return _hovered != &"" and _hovered != BACK and not on_table(_hovered)


func _menu_open() -> bool:
	return get_tree().get_nodes_in_group(&"blocks_hand").any(func(n: Node) -> bool:
		return n != _cursor and n is CanvasItem and (n as CanvasItem).is_visible_in_tree())


func _pan(to_map: bool) -> void:
	_at_map = to_map
	FarmTv.away = FarmTv.away_at(to_map, _view)
	if _pan_tween != null:
		_pan_tween.kill()
	var goal := 1.0 if to_map else 0.0
	_pan_tween = create_tween()
	_pan_tween.tween_method(_set_view, _view, goal, PAN_TIME * absf(goal - _view))
	if to_map:
		_view_in_sound.cue(_lay.global_position)
	else:
		# The light's switch clicks when the light starts to dim, not when the camera leaves.
		_pan_tween.parallel().tween_callback(_view_out_sound.cue.bind(_lay.global_position)) \
				.set_delay(light_off_after(_view))
		_hover(&"")


func _set_view(t: float) -> void:
	_view = t
	_tally.live = t > 0.0  # Its windows flick and tick only where they are seen.
	if _at_map or t > 0.0 or _pan_tween != null:
		FarmTv.away = FarmTv.away_at(_at_map, t)
	for i in _lamps.size():
		_lamps[i].light_energy = _lamp_energy[i] * smoothstep(0.0, LIGHT_FULL, t)
		_lamps[i].visible = t > 0.0
	if _camera != null and (t > 0.0 or _pan_tween != null):
		_camera.transform = FarmTv.view_at(_desk_view, _map_view.global_transform, t)
