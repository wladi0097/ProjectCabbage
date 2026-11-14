class_name FarmTv
extends Node3D
## Stage 2's way to the farm: a TV remote drops onto the desk once card `family_farm` is stamped.
## Clicked, the camera glides left to an old CRT standing at 45 degrees in the back-left corner of the
## L desk (table.blend's left arm, left of the desk view) and frames its glass; the set powers on. The glass shows `ScreenViewport`, a 2D
## SubViewport (`screen_scene`), and mouse input over the glass is
## passed into it. The BACK button on the set (right of the glass) or Esc pans back (a click
## elsewhere off the glass does nothing). The TV corner (`Corner`) is its own
## node so the farm section can be built onto it later. Sits at the world origin; the remote, the set,
## its lamps and materials are laid out in farm_tv.tscn.
## Channels: the CH 1 / CH 2 keys at the top of the right panel (built like BACK; Corner/Tv/Channel1, Channel2
## are their pilot windows, lit for the channel showing) switch the glass
## between `screen_scene` (the fields) and `tree_scene` (the farm tree, locked until its card) with
## STATIC_TIME of static; the channel is kept in save.farm_channel.
## Once the shortcut card is stamped (MapTable.shortcut) the BACK key is split in two (`Corner/Tv/Split`
## shows, the plain `Stencil` hides): its top half is TO DESK as before, its bottom half TO MAP
## (to_map: a dip to dark, `Dip`, and the camera is at the map table, `map`, the set off).
## go_to_tv() is the map's way here (its TO FARM button, in the same dip).

const CARD := "family_farm"
## The glass in the model: centre, normal +Z, half size (m), and the viewport it shows (px).
const SCREEN_CENTRE := Vector3(-0.025, 0.33, 0.262)
const SCREEN_HALF := Vector2(0.374063, 0.19)
const SCREEN_PIXELS := Vector2(1512, 768)
## Barrel warp of the glass; the same as WARP in crt_screen.gdshader.
const WARP := 0.06
## The BACK button at the foot of the set's narrow right panel (the CH 1 / CH 2 keys above it): front
## face centre and half size (m), as the glass; the click target takes in its chrome rim.
const BACK_CENTRE := Vector3(0.404063, 0.21, 0.263)
const BACK_HALF := Vector2(0.024, 0.045)
## The split BACK key's halves (MapTable.shortcut): TO DESK on top, TO MAP below, each this half size.
const SPLIT_BACK_CENTRE := Vector3(0.404063, 0.2325, 0.263)
const MAP_CENTRE := Vector3(0.404063, 0.1875, 0.263)
const SPLIT_HALF := Vector2(0.024, 0.0225)
## The TO MAP stencil hovered: the oxblood of the map table's buttons (pale ink would vanish on the key).
const MAP_HOVER_INK := Color(0.6, 0.1, 0.08)
## The CH 1 / CH 2 keys at the top of the panel, as BACK (the model's CZ), rim included.
const CHANNEL_CENTRES: Array[Vector3] = [Vector3(0.404063, 0.47, 0.263), Vector3(0.404063, 0.385, 0.263)]
const CHANNEL_HALF := Vector2(0.023, 0.039)
## The power lamp's glow at full power; dark (0) with the set off, i.e. while the camera is on the desk.
const LAMP_GLOW := 1.1
## The TV view: the set's case (CASE_HALF_W either side of the glass's centre + VIEW_SHIFT) fills
## WIDTH_FILL of the view's width, unless the glass would then fill more than FILL of its height
## (wide screens): the closer of the two never crops the set.
const WIDTH_FILL := 0.9
const FILL := 0.72
const CASE_HALF_W := 0.446
const DESK_FOV := 40.0
## The TV view sits this far right of the glass (m): on the middle of the case, BACK button included.
const VIEW_SHIFT := 0.03
## ...and looks down at it this much (degrees): nearly from the front, the desk under the set showing.
const VIEW_PITCH := 10.0
const PAN_TIME := 1.05
## The set switches on this far into the pan and takes POWER_TIME to open up; off takes OFF_TIME.
const POWER_AT := 0.45
const POWER_TIME := 0.55
const OFF_TIME := 0.25
const HUM_DB := -10.0
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
## Hovered, the arrow (and a CH key's pilot window) stands this far proud of its plate (m).
const ARROW_LIFT := 0.0015
## Hovered, the remote lifts off the desk and tips its nose up at the set (m, rad, s), like the ledger.
const REMOTE_LIFT := 0.03
const REMOTE_TILT := 0.14
const REMOTE_HOVER_TIME := 0.15
const STATIC_TIME := 0.12
## The shortcuts (TO FARM, TO MAP) do not fly the camera across the room (twice the desk glides' way and
## a half turn with a roll, in the same time: it made players sick). The screen dips to dark over
## DIP_OUT s, the camera cuts to SETTLE_FROM of the way along the destination's own glide from the
## desk, and the rest of that glide (its last, small stretch) plays as the dark lifts over DIP_IN s.
const DIP_OUT := 0.15
const DIP_IN := 0.25
const SETTLE_FROM := 0.85
## A channel key's pilot window glow (a pale phosphor green, the keys' material): off, the channel
## showing (times the set's power: dark with the set off), hovered.
const BUTTON_GLOW: Array[float] = [0.0, 1.4, 4.5]
## The OS cursor at the TV (the desk's 3D hand hides there): pixel glove images (tools/make_farm_sprites.py,
## the screen's pixel style) for the pointer, the open
## and the closed hand (FarmScreen.POINT / OPEN_HAND / GRAB), with their hotspots (px), game-wide.
const CURSORS := {
	Input.CURSOR_POINTING_HAND: [preload("res://assets/sprites/cursors/pointer.png"), Vector2(11, 1)],
	Input.CURSOR_CAN_DROP: [preload("res://assets/sprites/cursors/hand_open.png"), Vector2(15, 15)],
	Input.CURSOR_DRAG: [preload("res://assets/sprites/cursors/hand_grab.png"), Vector2(15, 17)],
}

## The camera is off the desk: on its way to the TV, there, or on its way back (away_at). The
## projector's PULL tab hides meanwhile and only comes back once the camera is home.
static var away := false

@export var screen_scene: PackedScene
@export var tree_scene: PackedScene
## The map table TO MAP hands the camera to (MainStoryWorld); without one the key is never split.
@export var map: MapTable

var _lamp_energy: Array[float] = []
var _back_hover := false
var _map_hover := false
## The shortcuts' dip to dark (dip), while it runs.
var _dip_tween: Tween
## The channel button under the mouse (1, 2; 0 none), the channels' screens, seconds of static left.
var _channel_hover := 0
var _channels: Array[CanvasItem] = []
var _static_left := 0.0
## 0 on the desk, 1 at the TV; the set's power 0..1.
var _view := 0.0
var _power := 0.0
var _at_tv := false
var _on_glass := false
var _tween: Tween
var _remote_tween: Tween
var _camera: Camera3D
var _desk_view: Transform3D

@onready var _screen: SubViewport = $ScreenViewport
@onready var _remote: StaticBody3D = $Remote
@onready var _model: Node3D = $Remote/Model
## Where the remote lies: on the desk's left, between the tally machine and the ledger.
@onready var _remote_rest := _remote.position
## The TV corner, its own node so the farm section can be built onto it later.
@onready var _corner: Node3D = $Corner
@onready var _glass: ShaderMaterial = $Corner/Tv/Screen.material_override
@onready var _led: StandardMaterial3D = $Corner/Tv/Led.material_override
@onready var _arrow: StandardMaterial3D = $Corner/Tv/BackArrow.material_override
@onready var _arrow_mesh: MeshInstance3D = $Corner/Tv/BackArrow
## The screen's own glow, with the power.
@onready var _glow: OmniLight3D = $Corner/Glow
## The TV corner's own lamps: they fade in with the pan so the desk view's light stays as it was.
@onready var _lamps: Array[OmniLight3D] = [$Corner/Lamp, $Corner/Fill, $Corner/Step, $Corner/Wash]
## Shown while the camera is off the desk: the hand hides and the OS cursor comes back.
@onready var _cursor: Control = $Cursor
## The shortcuts' dark (dip), over everything; clear (alpha 0) otherwise.
@onready var _dark: ColorRect = $Dip/Dark
## The hint slip that follows the mouse over the BACK button.
@onready var _hint: Label = $HintLayer/Hint
## The plain TO DESK stencil, and the split key's divider and two stencils (shown instead once split).
@onready var _stencil: Label3D = $Corner/Tv/Stencil
@onready var _split: Node3D = $Corner/Tv/Split
@onready var _map_stencil: Label3D = $Corner/Tv/Split/MapStencil
@onready var _map_ink := _map_stencil.modulate
## The TO MAP half's arrow (the BACK arrow's mesh), lit like it on hover.
@onready var _map_arrow: MeshInstance3D = $Corner/Tv/Split/MapArrow
## The burst of static over the glass on a channel switch, and the channel buttons.
@onready var _static: CanvasItem = $ScreenViewport/Static
@onready var _buttons: Array[MeshInstance3D] = [$Corner/Tv/Channel1, $Corner/Tv/Channel2]  # their pilot windows


func _ready() -> void:
	away = false  # Static: a scene reload (reset, debug start) must not keep the camera "at the TV".
	_camera = get_viewport().get_camera_3d()
	_desk_view = _camera.transform
	for light in _lamps:
		_lamp_energy.append(light.light_energy)
	var hit := $Remote/Interactable as Interactable
	hit.grabbed.connect(_toggle)
	hit.hovered.connect(_lift_remote.bind(1.0))
	hit.unhovered.connect(_lift_remote.bind(0.0))
	_glass.set_shader_parameter(&"screen_tex", _screen.get_texture())
	_screen.world_2d = World2D.new()  # Its own canvas: the desk's 2D overlays must not show on the glass.
	for shape: Input.CursorShape in CURSORS:
		Input.set_custom_mouse_cursor(CURSORS[shape][0], shape, CURSORS[shape][1])
	for scene: PackedScene in [screen_scene, tree_scene]:
		var channel: CanvasItem = scene.instantiate()
		_screen.add_child(channel)
		_channels.append(channel)
	_show_channel()
	var owned := bought(SaveManager.save)
	_remote.visible = owned
	_corner.visible = owned
	_set_power(0.0)
	_show_split()


func _process(delta: float) -> void:
	_show_split()
	if _at_tv:
		SaveManager.save.tv_seconds += delta
	_static_left = maxf(_static_left - delta, 0.0)
	_static.visible = _static_left > 0.0
	if not _remote.visible and bought(SaveManager.save):
		_drop()
	_cursor.visible = _view > 0.0
	for i in _lamps.size():
		_lamps[i].light_energy = _lamp_energy[i] * smoothstep(0.0, 0.5, _view)  # Up early: the corner reads mid-pan.
		_lamps[i].visible = _view > 0.0
	_hint.visible = hint_shown(_back_hover or _map_hover, BossReport.up)
	if _hint.visible:
		var key := map_frame() if _map_hover else back_frame()
		var below := _camera.unproject_position(key * Vector3(0.0, -back_half().y - 0.07, 0.0))
		_hint.position = below - Vector2(_hint.size.x / 2.0, 0.0)
	_screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _view > 0.0 else SubViewport.UPDATE_DISABLED
	var hum := _view * _power
	if hum > 0.001:
		$Hum.volume_db = HUM_DB + linear_to_db(hum)
		if not $Hum.playing:
			$Hum.play()
	elif $Hum.playing:
		$Hum.stop()


func _input(event: InputEvent) -> void:
	# _input, not _unhandled_input: the pause menu (later in the tree) would take Esc first.
	# A boss report is up: it takes the mouse (and Esc goes to the pause menu), not the TV.
	# The pause menu is open (Esc during a report's flight can open it): its buttons take the mouse.
	if dipping():
		get_viewport().set_input_as_handled()  # Esc or a click mid-shortcut must not catch the camera mid-cut.
		return
	if not takes_input(_at_tv, BossReport.up, _menu_open()):
		return
	if event.is_action_pressed("ui_cancel"):
		_pan(false)
		get_viewport().set_input_as_handled()
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	# Nothing behind the TV view takes the mouse: it goes into the screen or pans back.
	get_viewport().set_input_as_handled()
	var from := _camera.project_ray_origin(mouse.position)
	var dir := _camera.project_ray_normal(mouse.position)
	_hover_back(on_glass(rect_uv(back_frame(), back_half(), from, dir)))
	_hover_map(split() and on_glass(rect_uv(map_frame(), SPLIT_HALF, from, dir)))
	_hover_channel(_channel_at(from, dir))
	var uv := glass_uv(screen_frame(), from, dir)
	var was_on := _on_glass
	_on_glass = on_glass(uv)
	if _on_glass:
		if not was_on:  # Without it the screen only hears hover motion after a click.
			_screen.notification(NOTIFICATION_VP_MOUSE_ENTER)
		var inner := mouse.duplicate() as InputEventMouse
		inner.position = screen_pixel(uv)
		inner.global_position = inner.position
		_screen.push_input(inner, true)
		_set_cursor()
		return
	if was_on:
		_screen.notification(NOTIFICATION_VP_MOUSE_EXIT)
	_set_cursor()
	var button := mouse as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if _map_hover:
			$Click.cue(map_frame().origin)
			to_map()
			return
		if _channel_hover > 0:
			$Click.cue(channel_frame(_channel_hover).origin)
			_switch(_channel_hover)
			return
		if leaves_tv(_back_hover):
			$Click.cue(back_frame().origin)
			_pan(false)


## Whether a click off the glass takes the camera back to the desk: only on BACK (a click that
## misses the glass, e.g. while dragging a seed or a cabbage, must not leave).
static func leaves_tv(on_back: bool) -> bool:
	return on_back


## The channel showing for `save`: 2 (the farm tree) or else 1 (the fields).
static func shown_channel(save: SaveGame) -> int:
	return 2 if save.farm_channel == 2 else 1


## The power lamp's glow for the set's power `power` (0 off .. 1 on): dark when off, no blinking.
static func lamp_glow(power: float) -> float:
	return LAMP_GLOW * clampf(power, 0.0, 1.0)


## The cursor at the TV: a pointer on BACK or a CH key (`on_key`), on the glass what the screen
## asks for (`glass`: its hovered control's shape), the arrow elsewhere.
static func tv_cursor(on_key: bool, on_glass_now: bool, glass: Input.CursorShape) -> Input.CursorShape:
	if on_key:
		return Input.CURSOR_POINTING_HAND
	return glass if on_glass_now else Input.CURSOR_ARROW


## Whether the camera is off the desk (`away`): at or bound for the TV, or still panning back (view > 0).
static func away_at(at_tv: bool, view: float) -> bool:
	return at_tv or view > 0.0


## A CH key's pilot window glow for its state `glow` (0 off, 1 the channel showing, 2 hovered) on a set
## at power `power`: the channel showing is lit only while the set is on.
static func key_glow(glow: int, power: float) -> float:
	return BUTTON_GLOW[glow] * (clampf(power, 0.0, 1.0) if glow == 1 else 1.0)


## Channel `channel`'s (1, 2) key face in the world, as screen_frame.
func channel_frame(channel: int) -> Transform3D:
	return _corner.global_transform * Transform3D(Basis(), CHANNEL_CENTRES[channel - 1])


## The channel key a ray hits (1, 2), or 0.
func _channel_at(from: Vector3, dir: Vector3) -> int:
	for i in CHANNEL_CENTRES.size():
		if on_glass(rect_uv(channel_frame(i + 1), CHANNEL_HALF, from, dir)):
			return i + 1
	return 0


## Switches the set to channel `channel` with a burst of static, kept in the save.
func _switch(channel: int) -> void:
	if channel == shown_channel(SaveManager.save):
		return
	SaveManager.save.farm_channel = channel
	_static_left = STATIC_TIME
	if _on_glass:
		_on_glass = false
		_screen.notification(NOTIFICATION_VP_MOUSE_EXIT)
	_show_channel()


## Shows the saved channel's screen and lights its button.
func _show_channel() -> void:
	var channel := shown_channel(SaveManager.save)
	for i in _channels.size():
		_channels[i].visible = i + 1 == channel
	_light_buttons()


func _hover_channel(channel: int) -> void:
	if channel == _channel_hover:
		return
	_channel_hover = channel
	_light_buttons()
	_set_cursor()


func _light_buttons() -> void:
	var channel := shown_channel(SaveManager.save)
	for i in _buttons.size():
		var glow := 2 if _channel_hover == i + 1 else 1 if channel == i + 1 else 0
		(_buttons[i].material_override as StandardMaterial3D).emission_energy_multiplier = key_glow(glow, _power)
		_buttons[i].position.z = ARROW_LIFT if glow == 2 else 0.0


## Sets the OS cursor (tv_cursor). Set straight on the display: the desk's default shape stays the arrow.
func _set_cursor() -> void:
	var hovered := _screen.gui_get_hovered_control() if _on_glass else null
	var glass: int = Input.CURSOR_ARROW
	if hovered != null:
		glass = hovered.get_cursor_shape()
	var shape := tv_cursor(_back_hover or _map_hover or _channel_hover > 0, _on_glass, glass as Input.CursorShape)
	DisplayServer.cursor_set_shape(int(shape) as DisplayServer.CursorShape)


## The SubViewport shown on the glass; its content is `screen_scene`.
func screen_viewport() -> SubViewport:
	return _screen


## The glass's frame in the world: centre, +Z out of the glass, +Y up the screen.
func screen_frame() -> Transform3D:
	return _corner.global_transform * Transform3D(Basis(), SCREEN_CENTRE)


## The BACK button's face in the world (its top half once split), as screen_frame.
func back_frame() -> Transform3D:
	return _corner.global_transform * Transform3D(Basis(), SPLIT_BACK_CENTRE if split() else BACK_CENTRE)


## The BACK button's click target's half size: the whole key, or its top half once split.
func back_half() -> Vector2:
	return SPLIT_HALF if split() else BACK_HALF


## The TO MAP half's face in the world (the split key's bottom half), as screen_frame.
func map_frame() -> Transform3D:
	return _corner.global_transform * Transform3D(Basis(), MAP_CENTRE)


## Whether the BACK key is split into TO DESK and TO MAP: the shortcut card is stamped and there is a
## map table to go to.
func split() -> bool:
	return map != null and MapTable.shortcut(SaveManager.save)


## The map's TO FARM, in the dip's dark: the camera cuts to the last stretch of the desk's glide to
## the TV (SETTLE_FROM) and settles on the set from there.
func go_to_tv() -> void:
	if _at_tv:
		return
	_view = SETTLE_FROM
	_pan(true)
	_set_view(_view)  # Now, not on the tween's first step: no frame shows the desk.


## TO MAP: the screen dips to dark, the set is off and the camera at the map table (MapTable.arrive).
func to_map() -> void:
	if not _at_tv or not split() or dipping():
		return
	_at_tv = false  # Takes nothing meanwhile (the dip eats Esc and the mouse).
	dip(func() -> void:
		leave()
		map.arrive())


## The shortcuts' way across the room: the screen goes dark over DIP_OUT s, `cut` moves the camera,
## and the dark lifts over DIP_IN s. Input is eaten until it is done.
func dip(cut: Callable) -> void:
	_dip_tween = create_tween()
	_dip_tween.tween_property(_dark, "color:a", 1.0, DIP_OUT)
	_dip_tween.tween_callback(cut)
	_dip_tween.tween_property(_dark, "color:a", 0.0, DIP_IN)
	_dip_tween.finished.connect(func() -> void: _dip_tween = null)


## Whether a shortcut's dip is running.
func dipping() -> bool:
	return _dip_tween != null


## In a shortcut's dark: the set is off and the corner unlit at once, the camera handed on.
func leave() -> void:
	_pan(false)
	_tween.kill()
	_set_power(0.0)
	_set_view(0.0)


## Whether the TV takes Esc and the mouse: only at the TV with no boss report up and no menu open.
static func takes_input(at_tv: bool, report_up: bool, menu_open: bool) -> bool:
	return at_tv and not report_up and not menu_open


## Whether the "Back to the desk" slip shows: on the BACK plate, and not over a boss report (it is
## on a higher layer than the report and would float above it).
static func hint_shown(back_hover: bool, report_up: bool) -> bool:
	return back_hover and not report_up


static func bought(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## The camera on the glass (`screen`, as screen_frame) from VIEW_PITCH above, shifted VIEW_SHIFT
## to the right, as close as WIDTH_FILL and FILL allow on a view `aspect` (width / height) wide.
static func tv_view(screen: Transform3D, aspect := 16.0 / 9.0) -> Transform3D:
	var half_tan := tan(deg_to_rad(DESK_FOV) / 2.0)
	var distance := maxf(CASE_HALF_W / WIDTH_FILL / (half_tan * aspect), SCREEN_HALF.y / FILL / half_tan)
	var look := screen.basis * Basis(Vector3.RIGHT, -deg_to_rad(VIEW_PITCH))
	return Transform3D(look, screen.origin + look.z * distance + screen.basis.x * VIEW_SHIFT)


## The camera `t` of the way (0 desk, 1 TV) along the pan, eased in and out.
static func view_at(desk: Transform3D, tv: Transform3D, t: float) -> Transform3D:
	return desk.interpolate_with(tv, ease(clampf(t, 0.0, 1.0), -2.0))


## Where a ray hits the glass, as UV (0,0 top left .. 1,1 bottom right); (-1, -1) if it misses
## the glass's plane.
static func glass_uv(screen: Transform3D, from: Vector3, dir: Vector3) -> Vector2:
	return rect_uv(screen, SCREEN_HALF, from, dir)


## Where a ray hits a flat rectangle of half size `half` centred on `frame` (+Z out of it), as
## glass_uv.
static func rect_uv(frame: Transform3D, half: Vector2, from: Vector3, dir: Vector3) -> Vector2:
	var hit: Variant = Plane(frame.basis.z, frame.origin).intersects_ray(from, dir)
	if hit == null:
		return Vector2(-1, -1)
	var local: Vector3 = frame.affine_inverse() * (hit as Vector3)
	return Vector2(local.x / half.x, -local.y / half.y) * 0.5 + Vector2(0.5, 0.5)


static func on_glass(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0


## The viewport pixel seen at glass `uv`, through the CRT's barrel warp.
static func screen_pixel(uv: Vector2) -> Vector2:
	var c := uv * 2.0 - Vector2.ONE
	c += c * Vector2(c.y * c.y, c.x * c.x) * WARP
	return (c * 0.5 + Vector2(0.5, 0.5)) * SCREEN_PIXELS


func _menu_open() -> bool:
	return get_tree().get_nodes_in_group(&"blocks_hand").any(func(n: Node) -> bool:
		return n != _cursor and n is CanvasItem and (n as CanvasItem).is_visible_in_tree())


func _pan(to_tv: bool) -> void:
	_at_tv = to_tv
	away = away_at(to_tv, _view)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()
	var goal := 1.0 if to_tv else 0.0
	var time := PAN_TIME * absf(goal - _view)
	_tween.tween_method(_set_view, _view, goal, time)
	if to_tv:
		_tween.tween_callback(func() -> void: $TvOn.cue(screen_frame().origin)).set_delay(time * POWER_AT)
		_tween.tween_method(_set_power, 0.0, 1.0, POWER_TIME).set_delay(time * POWER_AT)
	elif _power > 0.0:
		$TvOff.cue(screen_frame().origin)
		_tween.tween_method(_set_power, _power, 0.0, OFF_TIME)
	if _on_glass:
		_on_glass = false
		_screen.notification(NOTIFICATION_VP_MOUSE_EXIT)
	if not to_tv:
		_hover_back(false)
		_hover_map(false)
		_hover_channel(0)
		_set_cursor()


func _set_view(t: float) -> void:
	_view = t
	away = away_at(_at_tv, t)
	var view := get_viewport().get_visible_rect().size
	_camera.transform = view_at(_desk_view, tv_view(screen_frame(), view.x / maxf(view.y, 1.0)), t)


func _set_power(p: float) -> void:
	_power = p
	_glass.set_shader_parameter(&"power", p)
	_led.emission_energy_multiplier = lamp_glow(p)
	_light_buttons()
	_glow.light_energy = 0.5 * p


## Lifts the remote's model `k` (0 resting .. 1 hovered) off the desk, nose up.
func _lift_remote(k: float) -> void:
	if _remote_tween != null:
		_remote_tween.kill()
	_remote_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_remote_tween.tween_property(_model, "position:y", REMOTE_LIFT * k, REMOTE_HOVER_TIME)
	_remote_tween.tween_property(_model, "rotation:x", -REMOTE_TILT * k, REMOTE_HOVER_TIME)


func _toggle() -> void:
	$Click.cue(_remote.global_position)
	_pan(not _at_tv)


func _drop() -> void:
	_remote.visible = true
	_corner.visible = true
	_remote.position = _remote_rest + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_remote, "position", _remote_rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Thud.cue(_remote.global_position))
	tween.tween_property(_model, "scale", Vector3(1.06, 0.8, 1.06), 0.06)
	tween.tween_property(_model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Lights the BACK arrow and turns the cursor into a pointing hand while the mouse is on it.
func _hover_back(on: bool) -> void:
	if on == _back_hover:
		return
	_back_hover = on
	_arrow.emission_energy_multiplier = 2.4 if on else 0.0
	_arrow_mesh.position.z = ARROW_LIFT if on else 0.0
	if on:
		_hint.text = "Back to the desk"
	_set_cursor()


## Lights the TO MAP stencil and turns the cursor into a pointing hand while the mouse is on it.
func _hover_map(on: bool) -> void:
	if on == _map_hover:
		return
	_map_hover = on
	_map_stencil.modulate = MAP_HOVER_INK if on else _map_ink
	(_map_arrow.material_override as StandardMaterial3D).emission_energy_multiplier = 2.4 if on else 0.0
	_map_arrow.position.z = ARROW_LIFT if on else 0.0
	if on:
		_hint.text = "Straight to the map"
	_set_cursor()


func _show_split() -> void:
	var on := split()
	_split.visible = on
	_stencil.visible = not on
