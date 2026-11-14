class_name MapTable
extends Node3D
## Chapter 3's map table, on the desk's right wing (out of the desk view): one paper map sheet
## (MapSheet) lies open under four drafting weights (props/: the weights, the holder, the button).
## THE SHEETS ARE NESTED: WORLD > a COUNTRY > the WAR on one of its farms.
## - Every country has its own sheet (FarmRegister, entities/map_table/countries/<id>.tscn). The home
##   country's is the first and at the start the only one. A country's sheet is loaded when it is
##   opened and freed when it is left (one alive at a time: each is a 3200 x 1800 texture and page).
## - The world sheet (`Sheets/World`, WorldRegister) comes with its desk card (WORLD_CARD): a click
##   on a country there rolls that country's sheet out.
## - The war sheet (`Sheets/War`, WarSheet: a placeholder) rolls out when a war order is stamped on a
##   farm of the open country sheet, and rolls away when the war is won or left.
## A sheet asks for another one with MapSheet.sheet_wanted; show_sheet(id) does the same from code.
## THE HOLDER across the top (`Holder`, props/chart_holder: one saddle) carries the rolled-up PARENT
## of the open sheet (parent_id), labelled by the tag on its roll: WORLD while a country lies open
## (once the world card is stamped), the country while a war sheet does. A click on that roll goes
## back up one level: the open sheet rolls up and leaves, the parent unrolls. At the top level (the
## home country before the world card, the world sheet after it) the holder is empty. Whenever the
## holder lacks the open sheet's parent (the world card just stamped, back from a war), its roll
## drops into the saddle the next time the camera is at the map (ARRIVE_*, the `Arrive` cue as it
## lands); a loaded save has it there already. The sheet that lay open last lies open again when
## the camera comes back, and after a reload (save.map_sheet; a war is not kept: its country).
## Left of the sheet, below the TO DESK button, lies the tally (props/map_tally: `Tally`): the
## company's coins, cabbages, Findings and farms in four windows. It is a desk card's doing
## (TALLY_CARD): not on the table until that is stamped, then it drops into its place the next time
## the camera is at the map (as a sheet's roll does, with the `TallyArrive` cue); a loaded save has it.
## go_to_map() glides the camera over the sheet like the farm TV's pan (FarmTv.view_at) and
## back_to_desk() (the TO DESK button, Esc) glides it home; while it is away the hand hides and the OS
## cursor comes back (`Cursor`, FarmTv.away: the one "camera is off the desk" flag both share). A click on a
## spot of the open sheet, or on nothing at all, is the sheet's business (a country sheet's farm
## sites and their deeds, the world sheet's countries, the war sheet's victory box). The corner has
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
## edge curls up (a roll in the holder that is not the new sheet leaves now); ROLL_UP_AT the sheet
## rolls itself up towards the holder; FETCH_AT the new roll leaves the holder (or comes in from
## above); STOW_AT the old roll hops into the holder (or leaves); LAND_AT the new roll lands with a little
## bounce; UNROLL_AT it unrolls across the desk, its edge still curled; WEIGHTS_ON_AT the weights
## drop onto its corners and pin the edge; POP_AT what stands on it pops up in a wave.

const Events := preload("res://globalScripts/game_events.gd")
const Tally := preload("res://entities/map_table/props/map_tally.gd")
const World := preload("res://entities/map_table/world_register.gd")
const War := preload("res://entities/map_table/war_sheet.gd")

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
const WEIGHT_ASIDE := 0.15
const WEIGHT_SQUASH := Vector3(1.18, 0.68, 1.18)
## How a roll's flight bulges (m): the old one up and over, the new one out towards the viewer.
const STOW_ARC := Vector3(0.0, 0.3, 0.0)
const FETCH_ARC := Vector3(-0.3, 0.12, 0.0)
const BOUNCE := 0.04
## Hovered, the roll in the holder lifts this far off its saddle (m, s).
const HOVER_LIFT := 0.07
const HOVER_TIME := 0.12
## Half sizes (m) of the click targets, on their frames (FarmTv.rect_uv): the roll in the holder
## (along it, across it) and the TO DESK plate.
const ROLL_HALF := Vector2(1.6, 0.066)
const BACK_HALF := Vector2(0.15, 0.065)
const BACK := &"back"
## What the mouse is on when it is on the roll in the holder (pick).
const HOLDER := &"holder"
## The world sheet's and the war sheet's ids (MapSheet.id); a country's sheet has its country's id.
const WORLD := &"world"
const WAR := &"war"
## The desk card (UpgradeDesk.CARDS) that brings the world sheet.
const WORLD_CARD := "world_map"
## A country's sheet: loaded when it is opened.
const COUNTRY_SCENE := "res://entities/map_table/countries/%s.tscn"
## A roll's arrival in the holder: it comes down from this far off the saddle (m: up, and from the
## wall's side; where a sheet that is not in the holder comes from and goes to in a swap as well),
## waits ARRIVE_AFTER s once the camera is there, falls for ARRIVE_TIME s and bounces ARRIVE_BOUNCE m.
const ARRIVE_FROM := Vector3(0.25, 0.9, 0.0)
const ARRIVE_AFTER := 0.35
const ARRIVE_TIME := 0.38
const ARRIVE_BOUNCE := 0.05
## The desk card (UpgradeDesk.CARDS) that puts the tally on the table, and how far over its place it
## drops from (m).
const TALLY_CARD := "map_readout"
const TALLY_FROM := 0.5
## The hint slip for a spot of the open sheet lies with its top left corner on the sheet's
## MapSheet.hint_pixel (off the land, so it never covers a site's tags) and is this wide (px), wrapping.
const SPOT_HINT_WIDTH := 400.0

## The sheet lying open (or on its way out during a swap), and whether a swap is running.
var shown := &""
var swapping := false

## The sheet rolled up in the holder (null: none), and the arrival running, if any.
var _held: MapSheet
var _arrive_tween: Tween
## The sheet asked for during a swap (the last request wins), and the farm with it: swapped in right after.
var _queued := &""
var _queued_farm := &""
## The farm just won in a war: its moment plays on its country's sheet once that lies open again.
var _won := &""
## What the mouse is on at the map: BACK, HOLDER, a spot on the open sheet, or nothing.
var _hovered := &""
## Whether the tally stands on the table (its card stamped, and landed or on its way down).
var _tally_here := false
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
@onready var _slot: Marker3D = $Holder/Slot
@onready var _world: MapSheet = $Sheets/World
@onready var _war: War = $Sheets/War
@onready var _back: Marker3D = $Back
@onready var _button: Node3D = $DeskButton
@onready var _stencil: Label3D = $DeskButton/Stencil
@onready var _stencil_ink := _stencil.modulate
@onready var _lamps: Array[Light3D] = [$Lights/Key, $Lights/Fill]
@onready var _cursor: Control = $Cursor
@onready var _hint: Label = $HintLayer/Hint
@onready var _tally: Tally = $Tally
@onready var _swap_sound: SoundCue = $Swap
@onready var _arrive_sound: SoundCue = $Arrive
@onready var _tally_arrive_sound: SoundCue = $TallyArrive
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
	for sheet in sheets():  # The world and the war sheet: rolled up and put away until asked for.
		sheet.sheet_wanted.connect(_on_wants)
		sheet.hide()
	shown = start_sheet(SaveManager.save)  # The sheet that lay open last lies open again.
	var open := _sheet_for(shown)
	open.global_transform = _lay.global_transform
	open.open = 1.0
	open.show()
	for i in open.thing_count():
		open.raise_thing(1.0, i)
	if parent_id(shown) != &"":  # Its parent is in the holder already, without the moment.
		_held = _sheet_for(parent_id(shown))
		_held.global_transform = _stowed()
		_held.show()
	_tally_here = tally_unlocked(SaveManager.save)
	_tally.visible = _tally_here
	visible = unlocked(SaveManager.save)
	_set_view(0.0)


func _process(_delta: float) -> void:
	visible = unlocked(SaveManager.save)
	_cursor.visible = _view > 0.0
	if _view >= 1.0 and _arrive_tween == null and not swapping:
		if _held == null and parent_id(shown) != &"":
			_arrive(_sheet_for(parent_id(shown)))  # The holder lacks the open sheet's parent: its roll drops in.
		elif not _tally_here and tally_unlocked(SaveManager.save):
			_arrive_tally()
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
		elif _hovered == HOLDER:
			show_sheet(_held.id)  # Back up one level.
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


## Whether sheet `id` can lie on the table for `save`: the home country's always, the world sheet and
## every other country's once the world card (WORLD_CARD) is stamped. (The war sheet: show_sheet.)
static func sheet_unlocked(id: StringName, save: SaveGame) -> bool:
	return id == World.HOME or ((id == WORLD or World.COUNTRIES.has(id)) and save.stamped.has(WORLD_CARD))


## The sheet that lies open when the table is set up for `save`: the one that lay open last
## (save.map_sheet) if it still can, else the home country's.
static func start_sheet(save: SaveGame) -> StringName:
	var last := StringName(save.map_sheet)
	return last if sheet_unlocked(last, save) else World.HOME


## Seconds a whole swap takes, from the request until the new sheet's things stand.
static func swap_time() -> float:
	return POP_AT + POP_TIME


## Whether the tally belongs on the table for `save`: its card (TALLY_CARD) is stamped.
static func tally_unlocked(save: SaveGame) -> bool:
	return save.stamped.has(TALLY_CARD)


## Whether sheet `id` is on the table: lying open or rolled in the holder (not still arriving).
func on_table(id: StringName) -> bool:
	return id == shown or (_held != null and _held.id == id)


## The sheet one level up from sheet `id`, the one the holder carries while `id` lies open: the
## war's country for the war sheet, the world sheet for a country once it is unlocked, none (&"")
## at the top level.
func parent_id(id: StringName) -> StringName:
	if id == WAR:
		return World.country_of(_war.farm)
	return WORLD if id != WORLD and sheet_unlocked(WORLD, SaveManager.save) else &""


## The id of the sheet in the holder, or &"".
func held() -> StringName:
	return _held.id if _held != null else &""


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


## Rolls out sheet `id` (a MapSheet.id: "world", a country's, "war") in place of the one lying open;
## the war sheet is for `farm`. The sheet already out changes nothing, nor does one that is locked
## (sheet_unlocked) or a war without a farm; asked during a swap, it is remembered (the last request
## wins) and swapped in as soon as the running swap is done.
func show_sheet(id: StringName, farm: StringName = &"") -> void:
	if not (sheet_unlocked(id, SaveManager.save) or (id == WAR and farm != &"")) or sheet_of(shown).busy():
		return  # Not there, or a purchase plays out on the open sheet: it is not rolled up under it.
	if swapping:
		_queued = id
		_queued_farm = farm
	elif id != shown:
		if id == WAR:
			var country := _sheet_for(World.country_of(farm)) as FarmRegister
			_war.begin(farm, country.site_title(farm), tr(country.title))
		_swap(sheet_of(shown), _sheet_for(id))


## The sheets alive: the world sheet, the war sheet and the country sheet loaded, if any.
func sheets() -> Array[MapSheet]:
	var out: Array[MapSheet] = []
	for child in $Sheets.get_children():
		if not child.is_queued_for_deletion():
			out.append(child as MapSheet)
	return out


## The sheet with this id if it is alive, else null (a country's sheet that is not loaded).
func sheet_of(id: StringName) -> MapSheet:
	for sheet in sheets():
		if sheet.id == id:
			return sheet
	return null


## Starts loading country `id`'s sheet in the background (the mouse is on it on the world sheet),
## so opening it does not stall.
func warm(id: StringName) -> void:
	if sheet_of(id) == null and ResourceLoader.load_threaded_get_status(COUNTRY_SCENE % id) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(COUNTRY_SCENE % id)


## The sheet with this id: a country's is loaded now if it is not alive (rolled up, out of sight).
func _sheet_for(id: StringName) -> MapSheet:
	var sheet := sheet_of(id)
	if sheet == null:
		sheet = (load(COUNTRY_SCENE % id) as PackedScene).instantiate()
		$Sheets.add_child(sheet)
		sheet.sheet_wanted.connect(_on_wants)
		sheet.global_transform = _off()
		sheet.hide()
	return sheet


## A sheet asks for another one (MapSheet.sheet_wanted). From the war sheet with the farm now ours: the war
## is won, and the farm's moment plays on its country's sheet once that lies open again.
func _on_wants(id: StringName, farm: StringName) -> void:
	if shown == WAR and SaveManager.save.farms_owned.has(farm):
		_won = farm
		(_sheet_for(id) as FarmRegister).expect(farm)
	show_sheet(id, farm)


## A sheet that left the table: out of sight, and a country's sheet is freed.
func _retire(sheet: MapSheet) -> void:
	sheet.hide()
	if sheet != _world and sheet != _war:
		sheet.queue_free()


## What a ray from the map camera is on: BACK (the TO DESK plate), HOLDER (the roll in the holder),
## a spot on the open sheet (MapSheet.spot_at: a farm site's id, a country's), or nothing.
func pick(from: Vector3, dir: Vector3) -> StringName:
	if FarmTv.on_glass(FarmTv.rect_uv(_back.global_transform, BACK_HALF, from, dir)):
		return BACK
	if _held != null and not swapping and FarmTv.on_glass(FarmTv.rect_uv(_slot.global_transform, ROLL_HALF, from, dir)):
		return HOLDER
	return sheet_of(shown).spot_at(sheet_pixel(from, dir))


## The art pixel of the open sheet (0..3200, 0..1800) that a ray (the mouse at the map) hits, or
## (-1, -1) off the paper or during a swap: how farm sites and countries are clicked.
func sheet_pixel(from: Vector3, dir: Vector3) -> Vector2:
	var hit: Variant = Plane(Vector3.UP, _lay.global_position.y).intersects_ray(from, dir)
	if hit == null or swapping:
		return Vector2(-1, -1)
	var pixel := sheet_of(shown).pixel_at(hit as Vector3)
	return pixel if MapSheet.on_paper(pixel) else Vector2(-1, -1)


## Where a rolled-up sheet rests in the holder: its roll's middle on the saddle.
func _stowed() -> Transform3D:
	return Transform3D(_lay.global_basis, _slot.global_position - Vector3.UP * MapSheet.roll_radius(0.0))


## Where a rolled-up sheet that is not in the holder comes from and goes to: above the holder, out of sight.
func _off() -> Transform3D:
	return _stowed().translated(ARRIVE_FROM)


## `old` rolls up and `new` rolls out. `new` comes out of the holder if it lay there (a step up),
## else in from above; `old` goes into the holder if it is `new`'s parent (a step down), else away;
## a roll in the holder that is neither leaves first.
func _swap(old: MapSheet, new: MapSheet) -> void:
	_hover(&"")
	shown = new.id
	SaveManager.save.map_sheet = String(parent_id(WAR) if new.id == WAR else new.id)
	swapping = true
	var up := new == _held
	var stow := parent_id(new.id) == old.id
	var leaving: MapSheet = null if up else _held
	_held = null
	var new_from := _stowed() if up else _off()
	var old_to := _stowed() if stow else _off()
	new.global_transform = new_from
	new.open = 0.0
	new.show()
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
	_swap_tween.tween_method(_fly.bind(old, lay, old_to, STOW_ARC), 0.0, 1.0, FLIGHT_TIME) \
			.set_delay(STOW_AT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swap_tween.tween_callback(_stowed_or_gone.bind(old, stow)).set_delay(STOW_AT + FLIGHT_TIME)
	if leaving != null:  # The roll in the holder makes room.
		_swap_tween.tween_method(_fly.bind(leaving, _stowed(), _off(), Vector3.ZERO), 0.0, 1.0, FLIGHT_TIME) \
				.set_delay(WEIGHTS_OFF_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_swap_tween.tween_callback(_retire.bind(leaving)).set_delay(WEIGHTS_OFF_AT + FLIGHT_TIME)
	_swap_tween.tween_property(old, "lift", 0.0, 0.01).set_delay(STOW_AT)
	# The new roll flies out, lands with a little bounce and unrolls, its edge still curled.
	_swap_tween.tween_method(_fly.bind(new, new_from, lay, FETCH_ARC if up else Vector3.ZERO), 0.0, 1.0, FLIGHT_TIME) \
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


## The old sheet has reached the holder (`stow`: it is the new one's parent) or left the table.
func _stowed_or_gone(old: MapSheet, stow: bool) -> void:
	if stow:
		_held = old
	else:
		_retire(old)


## `sheet`'s roll drops into the holder's saddle; from the landing on it is on the table.
func _arrive(sheet: MapSheet) -> void:
	var rest := _stowed()
	var from := _off()
	sheet.global_transform = from
	sheet.open = 0.0
	_arrive_tween = create_tween()
	_arrive_tween.tween_interval(ARRIVE_AFTER)
	_arrive_tween.tween_callback(sheet.show)
	_arrive_tween.tween_method(_fly.bind(sheet, from, rest, Vector3.ZERO), 0.0, 1.0, ARRIVE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_arrive_tween.tween_callback(_landed.bind(sheet))
	_arrive_tween.tween_method(_bounce.bind(sheet, rest.origin, ARRIVE_BOUNCE), 0.0, 1.0, BOUNCE_TIME)
	_arrive_tween.finished.connect(func() -> void: _arrive_tween = null)


## The tally drops into its place left of the sheet, as a roll does into its saddle.
func _arrive_tally() -> void:
	_tally_here = true
	var rest := _tally.position
	_arrive_tween = create_tween()
	_arrive_tween.tween_interval(ARRIVE_AFTER)
	_arrive_tween.tween_callback(_tally.show)
	_arrive_tween.tween_property(_tally, "position", rest, ARRIVE_TIME).from(rest + Vector3.UP * TALLY_FROM) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_arrive_tween.tween_callback(_tally_arrive_sound.cue.bind(_tally.global_position))
	_arrive_tween.tween_property(_tally, "scale", Vector3.ONE, SETTLE_TIME).from(WEIGHT_SQUASH) 			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_arrive_tween.finished.connect(func() -> void: _arrive_tween = null)


func _landed(sheet: MapSheet) -> void:
	_held = sheet
	_arrive_sound.cue(sheet.global_position)


func _swap_done() -> void:
	swapping = false
	if _won != &"":  # Back from a war won: the farm's moment.
		var farm := _won
		_won = &""
		(sheet_of(shown) as FarmRegister).celebrate(farm)
	var next := _queued
	_queued = &""
	if next != &"":
		show_sheet(next, _queued_farm)


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
	elif what == HOLDER:
		_hint.text = _held.hint_title()
	elif what != &"":
		_hint.text = sheet_of(shown).hint(what)
		if shown == WORLD:
			warm(what)  # The mouse is on a country: its sheet may be asked for next.
	sheet_of(shown).hover(what)  # A spot on the open sheet lifts; anything else lets it down.
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if what != &"" else DisplayServer.CURSOR_ARROW)
	if swapping or _held == null or _arrive_tween != null:
		return  # The rolls are flying, or the holder is empty: nothing is lifted.
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_held, "global_position:y", _stowed().origin.y + (HOVER_LIFT if what == HOLDER else 0.0), HOVER_TIME)


## Whether the mouse is on a spot of the open sheet (not the plate, not the roll in the holder).
func _on_spot() -> bool:
	return _hovered != &"" and _hovered != BACK and _hovered != HOLDER


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
