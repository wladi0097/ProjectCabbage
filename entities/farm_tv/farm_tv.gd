class_name FarmTv
extends Node3D
## Stage 2's way to the farm: a TV remote drops onto the desk once card `family_farm` is stamped.
## Clicked, the camera glides a little left to an old CRT on the desk's 45 degree corner step (the
## L wing of table.blend, left of the desk view) and frames its glass; the set powers on. The glass shows `ScreenViewport`, a 2D
## SubViewport (`screen_scene`, or a NO SIGNAL placeholder), and mouse input over the glass is
## passed into it. The BACK button on the set (right of the glass), Esc or a click elsewhere off
## the glass pans back. The TV corner (`Corner`) is its own
## node so the farm section can be built onto it later. Sits at the world origin; all placements
## are the consts below.

const CARD := "family_farm"
const TV_MODEL := preload("res://assets/meshes/Props/farm_tv.blend")
const REMOTE_MODEL := preload("res://assets/meshes/Props/tv_remote.blend")
const CRT_SHADER := preload("res://assets/shaders/crt_screen.gdshader")
## On the desk's left, between the tally machine and the ledger: free wood, in view.
const REMOTE_AT := Vector3(-1.0, 0.76, -0.18)
const REMOTE_TURN := 1.3
## Shown larger than life, like the tally machine, so it reads from the desk camera.
const REMOTE_SCALE := 1.5
## The TV on the desk's corner step: 0.37 m behind the middle of the step's diagonal edge (from
## (-2.0, -0.1) to (-2.7, 0.6) in x, z), facing out of it at 45 degrees.
const CORNER_AT := Vector3(-2.612, 0.75, -0.012)
const CORNER_TURN := PI / 4.0
## The glass in the model: centre, normal +Z, half size (m), and the viewport it shows (px).
const SCREEN_CENTRE := Vector3(-0.0525, 0.33, 0.262)
const SCREEN_HALF := Vector2(0.25, 0.19)
const SCREEN_PIXELS := Vector2(1024, 768)
## Barrel warp of the glass; the same as WARP in crt_screen.gdshader.
const WARP := 0.06
## The BACK button on the set's narrow right panel: front face centre and half size (m), as the
## glass; the click target takes in its chrome rim.
const BACK_CENTRE := Vector3(0.3075, 0.36, 0.282)
const BACK_HALF := Vector2(0.041, 0.035)
## The TV view: the glass fills this much of the desk camera's vertical field of view (degrees),
## leaving some room around the set.
const FILL := 0.58
const DESK_FOV := 40.0
## The TV view sits this far right of the glass (m): on the middle of the case, so the BACK
## button is in view too.
const VIEW_SHIFT := 0.0525
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
const LED_ON := Color(0.42, 0.09, 0.06)
## The BACK button's stencilled arrow: dim, and lit while hovered. The hint slip under the plate
## is styled like the hand's tooltips.
const ARROW := Color(0.5, 0.53, 0.5)
const ARROW_LIT := Color(0.66, 0.74, 0.72)
## Hovered, the arrow stands this far proud of its plate (m).
const ARROW_LIFT := 0.004
const HINT_PAPER := Color(0.72, 0.73, 0.69)
const HINT_INK := Color(0.13, 0.15, 0.14)
const STATIC_SHADER := preload("res://assets/shaders/tv_static.gdshader")

## The camera is (on its way) at the TV: the projector's PULL tab hides meanwhile.
static var away := false

@export var screen_scene: PackedScene

var _remote := StaticBody3D.new()
var _model := Node3D.new()
var _corner := Node3D.new()
var _glass: ShaderMaterial
var _led: StandardMaterial3D
var _glow := OmniLight3D.new()
## The TV corner's own lamps: they fade in with the pan so the desk view's light stays as it was.
var _lamps: Array[OmniLight3D] = []
var _lamp_energy: Array[float] = []
## Shown while the camera is off the desk: the hand hides and the OS cursor comes back.
var _cursor := Control.new()
var _arrow: StandardMaterial3D
var _arrow_mesh: MeshInstance3D
var _hint := Label.new()
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


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	_desk_view = _camera.transform
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_cursor.add_to_group(&"blocks_hand")
	add_child(_cursor)
	_build_remote()
	_build_corner()
	_build_back()
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
	_hint.visible = _back_hover
	if _back_hover:
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
	if not _at_tv or BossReport.up:
		return
	if event.is_action_pressed("ui_cancel") and not _menu_open():
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
	_remote.position = REMOTE_AT + Vector3.UP * DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_remote, "position", REMOTE_AT, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: $Thud.cue(_remote.global_position))
	tween.tween_property(_model, "scale", Vector3(1.06, 0.8, 1.06), 0.06)
	tween.tween_property(_model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_remote() -> void:
	_remote.position = REMOTE_AT
	_remote.rotation.y = REMOTE_TURN
	add_child(_remote)
	_remote.add_child(_model)
	var remote := REMOTE_MODEL.instantiate() as Node3D
	remote.scale = Vector3.ONE * REMOTE_SCALE
	_model.add_child(remote)
	_remote.collision_layer = Interactable.HOVER_LAYER  # Found by the hand's ray, collides with nothing.
	_remote.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.11, 0.07, 0.27) * REMOTE_SCALE
	shape.shape = box
	shape.position = Vector3(0, 0.025, 0)
	_remote.add_child(shape)
	var interactable := Interactable.new()
	interactable.pressable = true
	interactable.grip_height = 0.04
	interactable.tooltip = "TV remote. Click: watch the farm feed on the set beside the desk. The arrow, Esc or a click beside the screen: back to the desk."
	_remote.add_child(interactable)
	interactable.grabbed.connect(_toggle)


## The TV corner: the set on its stand, a dim cold lamp above, the screen's own glow.
func _build_corner() -> void:
	_corner.name = "Corner"
	_corner.position = CORNER_AT
	_corner.rotation.y = CORNER_TURN
	add_child(_corner)
	var model := TV_MODEL.instantiate()
	_corner.add_child(model)
	_glass = ShaderMaterial.new()
	_glass.shader = CRT_SHADER
	_glass.set_shader_parameter(&"screen_tex", _screen.get_texture())
	(model.get_node("Screen") as MeshInstance3D).material_override = _glass
	_led = StandardMaterial3D.new()
	_led.albedo_color = LED_ON.darkened(0.5)
	_led.emission_enabled = true
	_led.emission = LED_ON
	(model.get_node("Led") as MeshInstance3D).material_override = _led
	_arrow = StandardMaterial3D.new()
	_arrow.albedo_color = ARROW
	_arrow.roughness = 0.7
	_arrow.emission_enabled = true
	_arrow.emission = ARROW_LIT
	_arrow.emission_energy_multiplier = 0.0
	_arrow_mesh = model.get_node("BackArrow")
	_arrow_mesh.material_override = _arrow
	var stencil := Label3D.new()  # "TO DESK" under the arrow, so it can't read as "next".
	stencil.text = "TO DESK"
	stencil.font = load("res://assets/fonts/Oswald.ttf")
	stencil.font_size = 64
	stencil.pixel_size = 0.00022
	stencil.outline_size = 0
	stencil.modulate = Color(0.1, 0.11, 0.1)  # Dark paint on the pale plate.
	stencil.shaded = true
	stencil.position = BACK_CENTRE + Vector3(0.0, -BACK_HALF.y + 0.014, 0.002)
	model.add_child(stencil)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.72, 0.8, 0.82)
	lamp.light_energy = 2.6
	lamp.omni_range = 3.0
	lamp.position = Vector3(0.6, 1.4, 1.2)
	_corner.add_child(lamp)
	_lamps.append(lamp)
	var fill := OmniLight3D.new()  # Cold bounce from the left, so the case keeps its sage.
	fill.light_color = Color(0.6, 0.68, 0.7)
	fill.light_energy = 0.8
	fill.omni_range = 2.5
	fill.position = Vector3(-1.2, 0.6, 1.0)
	_corner.add_child(fill)
	_lamps.append(fill)
	var step := OmniLight3D.new()  # Low and in front: the corner step's wood and edge band catch it.
	step.light_color = Color(0.62, 0.7, 0.72)
	step.light_energy = 1.4
	step.omni_range = 2.2
	step.position = Vector3(0.9, 0.35, 0.9)
	_corner.add_child(step)
	_lamps.append(step)
	var wash := OmniLight3D.new()  # Grazes the tile wall left of the set, so the view has no black hole.
	wash.light_color = Color(0.6, 0.68, 0.7)
	wash.light_energy = 2.4
	wash.omni_range = 2.2
	wash.position = Vector3(-0.95, 0.9, 0.1)
	_corner.add_child(wash)
	_lamps.append(wash)
	for light in _lamps:
		_lamp_energy.append(light.light_energy)
	_glow.light_color = Color(0.7, 0.76, 0.78)
	_glow.omni_range = 1.2
	_glow.position = SCREEN_CENTRE + Vector3(0, 0, 0.35)
	_corner.add_child(_glow)


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


## The hint slip that follows the mouse over the BACK button.
func _build_back() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var paper := StyleBoxFlat.new()
	paper.bg_color = HINT_PAPER
	paper.border_color = HINT_INK.lightened(0.3)
	paper.set_border_width_all(1)
	paper.set_content_margin_all(10)
	paper.shadow_color = Color(0, 0, 0, 0.35)
	paper.shadow_offset = Vector2(4, 4)
	_hint.add_theme_stylebox_override(&"normal", paper)
	_hint.add_theme_color_override(&"font_color", HINT_INK)
	_hint.add_theme_font_size_override(&"font_size", 22)
	_hint.text = "Back to the desk"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	layer.add_child(_hint)


## Lights the BACK arrow and turns the cursor into a pointing hand while the mouse is on it.
func _hover_back(on: bool) -> void:
	if on == _back_hover:
		return
	_back_hover = on
	_arrow.emission_energy_multiplier = 2.4 if on else 0.0
	_arrow_mesh.position.z = ARROW_LIFT if on else 0.0
	_led.emission_energy_multiplier = (0.2 + 2.0 * _power) * (1.8 if on else 1.0)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
