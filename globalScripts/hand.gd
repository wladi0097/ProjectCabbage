extends Node
## The player's hand: finds the Interactable under the mouse, grabs it on press, lets go on
## release, and drives the 3D hand that replaces the OS cursor (pointing, open over
## something, closed on what it holds). Over UI, while a menu in the "blocks_hand" group is
## open, or while the window is unfocused, the OS cursor comes back and the hand lets go of the mouse.

const MODEL := preload("res://entities/hand/hand_model.tscn")
const RAY_LENGTH := 20.0
const PLAY_AREA_LAYER := 2
## The empty hand floats here, above the cabbages on the mat.
const HOVER_HEIGHT := 1.05
## The empty hand's fingertip stops here, just short of the window wall's inner face (z -0.80).
const WALL_Z := -0.76
## How far the hidden mouse may run ahead of a held object: a little slack plus the lag it has
## at its speed (about 1 / Cabbage.follow), so a free drag feels heavy but a held object
## pinned against a wall keeps the mouse with it.
const LEAD_SLACK := 0.08
const LEAD_PER_SPEED := 0.07
## Fingertip height over a hovered button (m, low..high) and the tapping speed (rad/s);
## pressed, the tip sinks this far into it.
const TAP_LIFT := Vector2(0.005, 0.03)
const TAP_SPEED := 9.0
const PRESS_LIFT := -0.006
## The fingertip touches a button this far toward the player from the hovered spot, so the
## glove trails off below it on screen instead of covering it.
const TIP_BACK := 0.04
## On hovered paper the hand eases to the corner it pinches at this rate (per second); held paper
## moves with the hand, so there it sits exactly.
const CARRY_FOLLOW := 14.0

var hovered: Interactable
var held: Interactable

var _model: HandModel
## Where the mouse ray last hit the hovered thing; frozen while it is held.
var _point := Vector3.ZERO
## Where the hand was put last frame.
var _placed := Vector3.ZERO


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)


func _physics_process(_delta: float) -> void:
	if held != null and (not is_instance_valid(held) or not held.enabled
			or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_release()
	if held == null:
		# Over a GUI control (the projector overlay) nothing behind it is hovered or caught.
		_set_hovered(null if get_viewport().gui_get_hovered_control() != null else _pick())
		if hovered != null and hovered.catchable and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			held = hovered
			held.grabbed.emit()


func _process(delta: float) -> void:
	var in_game := get_window().has_focus() and get_viewport().get_camera_3d() != null \
			and get_viewport().gui_get_hovered_control() == null and not get_tree().get_nodes_in_group(&"blocks_hand").any(func(n: Node) -> bool:
				return n is CanvasItem and (n as CanvasItem).is_visible_in_tree())
	_model.visible = in_game
	var mode := Input.MOUSE_MODE_HIDDEN if in_game else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	if not in_game:
		return
	var touching := held if is_instance_valid(held) else hovered
	var pressing := is_instance_valid(touching) and touching.pressable
	var carrying := is_instance_valid(touching) and touching.carried
	var reaching := is_instance_valid(touching) and touching.reach
	_model.pose = HandModel.pose_for(held != null, hovered != null, pressing, carrying, reaching)
	if pressing:
		# Only the fingertip goes onto a button, tapping while it hovers, so the hand doesn't cover it.
		var lift := tap_lift(Time.get_ticks_msec() / 1000.0, held != null)
		_place(_point + Vector3(0.0, lift, TIP_BACK), delta)
	elif held != null or reaching or carrying:
		# On what it holds, on a hovered handle (half closed), or easing onto hovered paper's corner.
		# A held physics body lags the mouse, so the mouse is reined in to it; elsewhere it stays put.
		var thing := touching.get_parent() as Node3D
		if thing is RigidBody3D:
			var mouse := point_on_height(thing.global_position.y)
			var lead := LEAD_SLACK + (thing as RigidBody3D).linear_velocity.length() * LEAD_PER_SPEED
			_warp_to(mouse, rein(thing.global_position, mouse, lead))
		var offset := touching.carry_offset if carrying else Vector3.UP * touching.grip_height
		_place(thing.global_position + offset, delta, carrying and held == null)
	else:
		var mouse := point_on_height(HOVER_HEIGHT)
		var stopped := Vector3(mouse.x, mouse.y, maxf(mouse.z, WALL_Z))
		_warp_to(mouse, stopped)
		_place(stopped, delta)


## Puts the hand at `target`; `soft` (onto hovered paper) eases it there instead of snapping.
func _place(target: Vector3, delta: float, soft := false) -> void:
	if soft:
		target = _placed.lerp(target, 1.0 - exp(-CARRY_FOLLOW * delta))
	_placed = target
	_model.move_to(target, delta)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	if hovered != null and held == null:
		held = hovered
		held.grabbed.emit()
		get_viewport().set_input_as_handled()


## Where the mouse ray crosses the horizontal plane at `height`.
func point_on_height(height: float) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(
			camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return hit if hit != null else Vector3(0.0, height, 0.0)


## How high the fingertip floats over a button: tapping between TAP_LIFT.x and .y while
## hovering, pressed in (below the surface) while held.
static func tap_lift(time: float, pressed: bool) -> float:
	return PRESS_LIFT if pressed else lerpf(TAP_LIFT.x, TAP_LIFT.y, 0.5 + 0.5 * cos(time * TAP_SPEED))


## `point` pulled back to within `limit` of `anchor` on the horizontal plane.
static func rein(anchor: Vector3, point: Vector3, limit: float) -> Vector3:
	var lead := Vector3(point.x - anchor.x, 0.0, point.z - anchor.z)
	return point if lead.length() <= limit else Vector3(anchor.x, point.y, anchor.z) + lead.normalized() * limit


## The OS cursor is hidden, so when the hand cannot follow, the mouse is moved back to the hand
## instead of running on: no dead travel when coming back from a wall.
func _warp_to(mouse: Vector3, allowed: Vector3) -> void:
	if not mouse.is_equal_approx(allowed):
		get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(allowed))


func _release() -> void:
	var letting_go := held
	held = null
	if is_instance_valid(letting_go):
		letting_go.released.emit()


func _pick() -> Interactable:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(from,
			from + camera.project_ray_normal(mouse) * RAY_LENGTH, ~PLAY_AREA_LAYER)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	_point = hit.get("position", _point)
	return Interactable.of(hit.get("collider"))


func _set_hovered(next: Interactable) -> void:
	if next == hovered:
		return
	if is_instance_valid(hovered):
		hovered.unhovered.emit()
	hovered = next
	if next != null:
		next.hovered.emit()
