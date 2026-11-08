class_name FarmTv
extends Node3D
## Stage 2's way to the farm: a TV remote drops onto the desk once card `family_farm` is stamped.
## Clicked, the camera glides left to an old CRT standing at 45 degrees in the back-left corner of the
## L desk (table.blend's left arm, left of the desk view) and frames its glass; the set powers on. The glass shows `ScreenViewport`, a 2D
## SubViewport (`screen_scene`, or a NO SIGNAL placeholder), and mouse input over the glass is
## passed into it. The BACK button on the set (right of the glass), Esc or a click elsewhere off
## the glass pans back. The TV corner (`Corner`) is its own
## node so the farm section can be built onto it later. Sits at the world origin; the remote, the set,
## its lamps and materials are laid out in farm_tv.tscn.

const CARD := "family_farm"
## The glass in the model: centre, normal +Z, half size (m), and the viewport it shows (px).
const SCREEN_CENTRE := Vector3(-0.025, 0.33, 0.262)
const SCREEN_HALF := Vector2(0.320625, 0.19)
const SCREEN_PIXELS := Vector2(1296, 768)
## Barrel warp of the glass; the same as WARP in crt_screen.gdshader.
const WARP := 0.06
## The BACK button on the set's narrow right panel: front face centre and half size (m), as the
## glass; the click target takes in its chrome rim.
const BACK_CENTRE := Vector3(0.356625, 0.37, 0.282)
const BACK_HALF := Vector2(0.024, 0.045)
## The TV view: the glass fills this much of the desk camera's vertical field of view (degrees),
## leaving some room around the set.
const FILL := 0.66
const DESK_FOV := 40.0
## The TV view sits this far right of the glass (m): on the middle of the case, so the BACK
## button is in view too.
const VIEW_SHIFT := 0.025
## ...and looks down at it this much (degrees), so the desk corner under the set shows.
const VIEW_PITCH := 9.0
const PAN_TIME := 1.05
## The set switches on this far into the pan and takes POWER_TIME to open up; off takes OFF_TIME.
const POWER_AT := 0.45
const POWER_TIME := 0.55
const OFF_TIME := 0.25
const HUM_DB := -10.0
const DROP_HEIGHT := 1.6
const DROP_TIME := 0.45
## Hovered, the arrow stands this far proud of its plate (m).
const ARROW_LIFT := 0.004
const STATIC_SHADER := preload("res://assets/shaders/tv_static.gdshader")

## The camera is (on its way) at the TV: the projector's PULL tab hides meanwhile.
static var away := false

@export var screen_scene: PackedScene

var _lamp_energy: Array[float] = []
var _back_hover := false
## 0 on the desk, 1 at the TV; the set's power 0..1.
var _view := 0.0
var _power := 0.0
var _at_tv := false
var _on_glass := false
var _tween: Tween
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
## The hint slip that follows the mouse over the BACK button.
@onready var _hint: Label = $HintLayer/Hint


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	_desk_view = _camera.transform
	for light in _lamps:
		_lamp_energy.append(light.light_energy)
	($Remote/Interactable as Interactable).grabbed.connect(_toggle)
	_glass.set_shader_parameter(&"screen_tex", _screen.get_texture())
	_screen.world_2d = World2D.new()  # Its own canvas: the desk's 2D overlays must not show on the glass.
	_screen.add_child(screen_scene.instantiate() if screen_scene != null else _placeholder())
	var owned := bought(SaveManager.save)
	_remote.visible = owned
	_corner.visible = owned
	_set_power(0.0)


func _process(_delta: float) -> void:
	if not _remote.visible and bought(SaveManager.save):
		_drop()
	_cursor.visible = _view > 0.0
	for i in _lamps.size():
		_lamps[i].light_energy = _lamp_energy[i] * smoothstep(0.0, 0.5, _view)  # Up early: the corner reads mid-pan.
		_lamps[i].visible = _view > 0.0
	_hint.visible = hint_shown(_back_hover, BossReport.up)
	if _hint.visible:
		var below := _camera.unproject_position(back_frame() * Vector3(0.0, -BACK_HALF.y - 0.07, 0.0))
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
	_hover_back(on_glass(rect_uv(back_frame(), BACK_HALF, from, dir)))
	var uv := glass_uv(screen_frame(), from, dir)
	var was_on := _on_glass
	_on_glass = on_glass(uv)
	if _on_glass:
		var inner := mouse.duplicate() as InputEventMouse
		inner.position = screen_pixel(uv)
		inner.global_position = inner.position
		_screen.push_input(inner, true)
		return
	if was_on:
		_screen.notification(NOTIFICATION_VP_MOUSE_EXIT)
	var button := mouse as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if _back_hover:
			$Click.cue(back_frame().origin)
		_pan(false)


## The SubViewport shown on the glass; its content is `screen_scene` (or the placeholder).
func screen_viewport() -> SubViewport:
	return _screen


## The glass's frame in the world: centre, +Z out of the glass, +Y up the screen.
func screen_frame() -> Transform3D:
	return _corner.global_transform * Transform3D(Basis(), SCREEN_CENTRE)


## The BACK button's face in the world, as screen_frame.
func back_frame() -> Transform3D:
	return _corner.global_transform * Transform3D(Basis(), BACK_CENTRE)


## Whether the TV takes Esc and the mouse: only at the TV with no boss report up and no menu open.
static func takes_input(at_tv: bool, report_up: bool, menu_open: bool) -> bool:
	return at_tv and not report_up and not menu_open


## Whether the "Back to the desk" slip shows: on the BACK plate, and not over a boss report (it is
## on a higher layer than the report and would float above it).
static func hint_shown(back_hover: bool, report_up: bool) -> bool:
	return back_hover and not report_up


static func bought(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## The camera on the glass (`screen`, as screen_frame) from VIEW_PITCH above, so it fills about
## FILL of the view's height, shifted VIEW_SHIFT to the right.
static func tv_view(screen: Transform3D) -> Transform3D:
	var distance := SCREEN_HALF.y * 2.0 / FILL / (2.0 * tan(deg_to_rad(DESK_FOV) / 2.0))
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
	away = to_tv
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


func _set_view(t: float) -> void:
	_view = t
	_camera.transform = view_at(_desk_view, tv_view(screen_frame()), t)


func _set_power(p: float) -> void:
	_power = p
	_glass.set_shader_parameter(&"power", p)
	_led.emission_energy_multiplier = 0.2 + 2.0 * p
	_glow.light_energy = 0.5 * p


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


## NO SIGNAL static until the farm feed scene exists.
func _placeholder() -> Control:
	var root := Control.new()
	root.size = SCREEN_PIXELS
	var noise := ColorRect.new()
	noise.size = SCREEN_PIXELS
	noise.material = ShaderMaterial.new()
	(noise.material as ShaderMaterial).shader = STATIC_SHADER
	root.add_child(noise)
	var font := load("res://assets/fonts/Oswald.ttf")
	for spec in [["FARM FEED — CHANNEL 3", 44, 70.0], ["NO SIGNAL", 120, 300.0]]:
		var label := Label.new()
		label.text = spec[0]
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", spec[1])
		label.add_theme_color_override(&"font_color", Color(0.85, 0.9, 0.88))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, spec[2])
		label.size = Vector2(SCREEN_PIXELS.x, 160)
		root.add_child(label)
		if spec[0] == "NO SIGNAL":
			var blink := create_tween().set_loops()
			blink.tween_callback(func() -> void: label.visible = not label.visible).set_delay(0.7)
	return root


## Lights the BACK arrow and turns the cursor into a pointing hand while the mouse is on it.
func _hover_back(on: bool) -> void:
	if on == _back_hover:
		return
	_back_hover = on
	_arrow.emission_energy_multiplier = 2.4 if on else 0.0
	_arrow_mesh.position.z = ARROW_LIFT if on else 0.0
	_led.emission_energy_multiplier = (0.2 + 2.0 * _power) * (1.8 if on else 1.0)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
