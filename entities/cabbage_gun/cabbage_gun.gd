class_name CabbageGun
extends Node3D
## The chapter 5 ending's cabbage gun, held in the player's glove at the bottom right of the view.
## Sits under the camera. Hidden until raise(); then it aims after the mouse and, while `armed`,
## a left click fires: a kick, a muzzle flash, a short bright trail from the muzzle to where the
## shot lands (no projectile), a shake of the camera, and a ray on the
## ending_target layer (Convertible.LAYER) that converts what it hits. turn_to_player() swings it
## slowly round, the muzzle passing the screen's right, until the barrel looks at the camera; after
## that it no longer aims, and the hand keeps a small nervous tremble.
## The canister's liquid is a shader cut off at a plane (liquid_wobble.gdshader) that stays level to
## the view, not to the room: the camera looks steeply down at the desk, and a truly level liquid
## pooled in the canister's front corner. A damped spring here tips the plane after the canister's
## motion, so aiming and every shot slosh it.
## The gauge on the rear cap reads the canister's pressure: every shot drops its needle toward the
## red tick, and a damped spring brings it wobbling back.
## The whole gun is built at a quarter size (Rig) a quarter as far away: it looks the same, but the
## camera comes close to the TV and the map, and a gun at full size went behind the TV's front.

signal fired(hit: Convertible)

## How long the ray reaches (m).
const RANGE := 30.0
## Raised from this far below its rest (m) and this far tipped down (rad).
const LOWERED := Vector3(0.05, -0.4, 0.12)
const LOWERED_TIP := -0.9
const RAISE_TIME := 0.9
## How fast it swings after the mouse (1/s) and where it aims when the mouse ray meets nothing.
const AIM_SPEED := 14.0
const AIM_DEPTH := 4.0
## The kick of a shot: back (m) and muzzle up (rad), out fast, back over KICK_BACK s.
const KICK := Vector2(0.07, 0.32)
const KICK_OUT := 0.04
const KICK_BACK := 0.28
const FLASH_TIME := 0.06
## How long a shot's trail takes to fade (s).
const TRAIL_TIME := 0.16
## Turned to the player: where it ends up (camera space), which way round it swings (-1: the muzzle
## passes the screen's right), the most it shakes on the way and the tremble it keeps once there (rad).
const FACING := Vector3(0.02, -0.085, -0.72)
const TURN_WAY := -1.0
const TREMBLE := 0.035
const HELD_TREMBLE := 0.011
## Nothing of the gun is farther from the camera than this (m): every station's scenery is farther.
const MAX_DEPTH := 0.35
## The canister's liquid: how hard it springs back level (1/s^2), how fast it calms (1/s), how hard
## the canister's speed shoves it (slope/s^2 per m/s, speed capped at SLOSH_SPEED m/s) and the
## steepest its surface tips (slope).
const SLOSH_SPRING := 120.0
const SLOSH_DAMPING := 3.0
const SLOSH_PUSH := 160.0
const SLOSH_SPEED := 1.5
const SLOSH_MAX := 0.7
## The point whose speed shoves the liquid, well above the canister (Liquid's space) so turning
## the gun counts as much as moving it; and how far the cabbage drifts in the liquid (m per slope).
const SLOSH_POINT := Vector3(0.0, 0.6, -0.035)
const BOB := 0.012
## The gauge's needle (rad, about the gauge's normal; more is toward the red tick on the left):
## where it rests, how far a shot drops it, the most that quick shots stack up to, how hard it
## springs back (1/s^2) and how fast it calms (1/s): back at rest in about 0.7 s.
const NEEDLE_REST := -0.436
const NEEDLE_KICK := 1.0
const NEEDLE_MAX := 1.66
const NEEDLE_SPRING := 180.0
const NEEDLE_DAMPING := 11.0
## How far the needle shivers while the gun turns on the player (rad).
const NEEDLE_SHIVER := 0.05
const CROSSHAIR := preload("res://entities/cabbage_gun/crosshair.res")
const CROSSHAIR_HOTSPOT := Vector2(24, 24)

## Clicks fire only while this is on.
var armed := false
## How hard a shot shakes the camera (m of offset); the director may raise it step by step.
@export var shake_strength := 0.012
## Shake left now (m), easing off.
var _shake := 0.0
var _aiming := false
var _turned := false
## The turn to the player: where it began, how far it is (0..1) and the tremble's clock (s).
var _turn_from := Transform3D.IDENTITY
var _turn := 0.0
var _tremble_time := 0.0
var _crosshair := false
## The liquid's surface: its slope along the view's x and z (x, y) and how fast that changes (z, w).
var _slosh := Vector4.ZERO
var _slosh_point := Vector3.ZERO
## The needle: how far it is off its rest (x, rad) and how fast that changes (y).
var _needle_dip := Vector2.ZERO
## Where the last ray met its target, or ended (RANGE away) on a miss.
var _last_point := Vector3.ZERO
var _trail_fade: Tween
@onready var _rest := ($Rig/Pivot as Node3D).transform
@onready var _pivot: Node3D = $Rig/Pivot
@onready var _kick: Node3D = $Rig/Pivot/Kick
@onready var _flash: Node3D = $Rig/Pivot/Kick/Muzzle/Flash
@onready var _flash_light: OmniLight3D = $Rig/Pivot/Kick/Muzzle/FlashLight
@onready var _muzzle: Node3D = $Rig/Pivot/Kick/Muzzle
@onready var _trail: Node3D = $Trail
@onready var _beam: MeshInstance3D = $Trail/Beam
@onready var _hand: HandModel = $Rig/Pivot/Kick/Hand
@onready var _needle: Node3D = $Rig/Pivot/Kick/Needle
@onready var _liquid: MeshInstance3D = $Rig/Pivot/Kick/Liquid
@onready var _cabbage: Node3D = $Rig/Pivot/Kick/Cabbage
@onready var _cabbage_rest := ($Rig/Pivot/Kick/Cabbage as Node3D).position
@onready var _blocker: Control = $Crosshair/Blocker
@onready var _shot: AudioStreamPlayer = $Shot


func _ready() -> void:
	visible = false
	_flash.visible = false
	_flash_light.visible = false
	# The glove closes on the grip at once (one long step lands the pose), then keeps its authored place.
	var place := _hand.transform
	_hand.pose = HandModel.Pose.GRAB
	_hand.move_to(_hand.global_position, HandModel.SETTLE_TIME + 1.0)
	_hand.transform = place


func _exit_tree() -> void:
	if _crosshair:
		Input.set_custom_mouse_cursor(null)
	var camera := _camera()
	if camera != null:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Brings it up into the hand's place from below the screen; returns once it is up.
func raise() -> void:
	visible = true
	_pivot.transform = Transform3D(Basis(Vector3.RIGHT, LOWERED_TIP), LOWERED) * _rest
	_slosh_point = _liquid.to_global(SLOSH_POINT)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_pivot, ^"transform", _rest, RAISE_TIME)
	await tween.finished
	_aiming = not _turned


## Swings slowly round, trembling more and more, until the barrel looks at the camera; returns then.
func turn_to_player(seconds: float) -> void:
	_aiming = false
	_turned = true
	_turn_from = _pivot.transform
	_turn = 0.0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _turn = t, 0.0, 1.0, seconds)
	await tween.finished
	_pivot.transform = turn_pose(_turn_from, 1.0, _tremble_time)


## The pose `t` (0..1) of the way from `from` to facing the camera at clock `time` (s): half a turn
## about the camera's up, TURN_WAY round, while the aim it began with levels out. The hand shakes
## most mid-way and keeps HELD_TREMBLE once it faces the player.
static func turn_pose(from: Transform3D, t: float, time := 0.0) -> Transform3D:
	var eased := ease(t, -2.2)
	var swung := Basis(Vector3.UP, TURN_WAY * PI * eased) * from.basis.orthonormalized().slerp(Basis.IDENTITY, eased)
	return Transform3D(swung * tremble(time, TREMBLE * sin(t * PI) + HELD_TREMBLE * t), from.origin.lerp(FACING, eased))


## A hand-held shake at clock `time` (s), at most about `strength` (rad) on any axis: a slow sway
## with a faster, smaller quiver on top, each axis at its own pace so it never loops visibly.
static func tremble(time: float, strength: float) -> Basis:
	var sway := Vector3(sin(time * 5.3), sin(time * 4.1 + 1.3), sin(time * 6.7 + 2.1))
	var quiver := Vector3(sin(time * 27.0 + 0.4), sin(time * 33.0), sin(time * 21.0 + 1.9))
	return Basis.from_euler((sway * 0.65 + quiver * 0.35) * strength)


func set_crosshair(on: bool) -> void:
	_crosshair = on
	_blocker.visible = on
	Input.set_custom_mouse_cursor(CROSSHAIR if on else null, Input.CURSOR_ARROW, CROSSHAIR_HOTSPOT)


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and armed and visible:
		fire(click.position)
		get_viewport().set_input_as_handled()


## One shot toward `screen` (viewport pixels): converts the first Convertible on the ray.
## Turned to the player (turn_to_player), the shot is only the signal: no sound, kick, flash or shake,
## since the director cuts to black on that very frame.
func fire(screen: Vector2) -> void:
	if _turned:
		fired.emit(null)
		return
	_shot.play()
	_shake = shake_strength
	_kick_back()
	_needle_dip = needle_kick(_needle_dip)
	var hit := _target(screen)
	if _camera() != null:
		_show_trail(_last_point)
	if hit != null:
		hit.convert_at(_last_point)
	fired.emit(hit)


func _target(screen: Vector2) -> Convertible:
	var camera := _camera()
	if camera == null or _turned:
		return null
	var from := camera.project_ray_origin(screen)
	_last_point = from + camera.project_ray_normal(screen) * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, _last_point, Convertible.LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	_last_point = result.position
	var target: Variant = (result.collider as Object).get_meta(&"convertible", null)
	return target as Convertible if is_instance_valid(target) else null


## Where the trail's node goes for a shot from `from` to `to`: at the muzzle, its -Z along the
## shot and stretched to its length (the beam is one unit long). `up` only steadies the roll.
static func trail_pose(from: Vector3, to: Vector3, up: Vector3) -> Transform3D:
	var along := to - from
	if along.cross(up).is_zero_approx():
		up = Vector3.RIGHT if absf(along.normalized().x) < 0.9 else Vector3.UP
	return Transform3D(Basis.looking_at(along, up) * Basis.from_scale(Vector3(1.0, 1.0, along.length())), from)


## The shot's trail, muzzle to `to` in world space (the gun itself is a quarter size and close to
## the camera, the trail is not): there at once, faded out within TRAIL_TIME.
func _show_trail(to: Vector3) -> void:
	_trail.global_transform = trail_pose(_muzzle.global_position, to, global_basis.y)
	_beam.transparency = 0.0
	_trail.visible = true
	if _trail_fade != null:
		_trail_fade.kill()
	_trail_fade = create_tween()
	_trail_fade.tween_property(_beam, ^"transparency", 1.0, TRAIL_TIME)
	_trail_fade.tween_callback(_trail.hide)


func _kick_back() -> void:
	var tween := create_tween()
	tween.tween_property(_kick, ^"transform", Transform3D(Basis(Vector3.RIGHT, KICK.y), Vector3(0.0, 0.0, KICK.x)), KICK_OUT)
	tween.tween_property(_kick, ^"transform", Transform3D.IDENTITY, KICK_BACK) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_flash.visible = true
	_flash_light.visible = true
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	get_tree().create_timer(FLASH_TIME).timeout.connect(func() -> void:
		_flash.visible = false
		_flash_light.visible = false)


## The needle right after a shot: dropped by NEEDLE_KICK from where it was (the pressure let go at
## once, so it starts from a standstill), never past NEEDLE_MAX however fast the shots come.
static func needle_kick(state: Vector2) -> Vector2:
	return Vector2(minf(maxf(state.x, 0.0) + NEEDLE_KICK, NEEDLE_MAX), 0.0)


## The needle `delta` seconds on: `state` is how far it is off its rest (x) and how fast that
## changes (y); a damped spring swings it back, a little past rest and back again.
static func needle_step(state: Vector2, delta: float) -> Vector2:
	var step := minf(delta, 0.05)
	var speed := state.y - (state.x * NEEDLE_SPRING + state.y * NEEDLE_DAMPING) * step
	return Vector2(minf(state.x + speed * step, NEEDLE_MAX), speed)


## The liquid `delta` seconds on: `state` is its surface's slope along the view's x and z (x, y) and the
## slope's speed (z, w); `push` shoves it (slope/s^2). A damped spring pulls it back level.
static func slosh_step(state: Vector4, push: Vector2, delta: float) -> Vector4:
	var step := minf(delta, 0.05)
	var tilt := Vector2(state.x, state.y)
	var speed := Vector2(state.z, state.w)
	speed += (push - tilt * SLOSH_SPRING - speed * SLOSH_DAMPING) * step
	tilt = (tilt + speed * step).limit_length(SLOSH_MAX)
	return Vector4(tilt.x, tilt.y, speed.x, speed.y)


## Shoves the liquid by how the canister moved this frame, and lets the cabbage drift with it.
func _slosh_liquid(delta: float) -> void:
	var point := _liquid.to_global(SLOSH_POINT)
	var view := global_basis.orthonormalized()
	var moved := view.inverse() * ((point - _slosh_point) / delta).limit_length(SLOSH_SPEED)
	_slosh_point = point
	_slosh = slosh_step(_slosh, Vector2(moved.x, moved.z) * SLOSH_PUSH, delta)
	var tilt := Vector3(_slosh.x, 0.0, _slosh.y)
	(_liquid.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"level", view * (Vector3.UP + tilt))
	_cabbage.position = _cabbage_rest - _kick.global_basis.orthonormalized().inverse() * (view * tilt) * BOB


func _process(delta: float) -> void:
	if _turned:
		_tremble_time += delta
		_pivot.transform = turn_pose(_turn_from, _turn, _tremble_time)
	if visible and delta > 0.0:
		_slosh_liquid(delta)
		_needle_dip = needle_step(_needle_dip, delta)
		var shiver := sin(_tremble_time * 31.0) * NEEDLE_SHIVER * _turn if _turned else 0.0
		_needle.rotation.z = NEEDLE_REST + _needle_dip.x + shiver
	var camera := _camera()
	if camera == null:
		return
	if _aiming and visible:
		var mouse := get_viewport().get_mouse_position()
		var aim := _aim_point(camera, mouse)
		var look := Basis.looking_at(_pivot.global_position.direction_to(aim), camera.global_basis.y)
		var local := (global_basis.inverse() * look).orthonormalized()
		_pivot.basis = _pivot.basis.orthonormalized().slerp(local, 1.0 - exp(-AIM_SPEED * delta))
	if _shake > 0.0:
		_shake = _shake * exp(-14.0 * delta) if _shake > 0.0005 else 0.0
		camera.h_offset = randf_range(-1.0, 1.0) * _shake
		camera.v_offset = randf_range(-1.0, 1.0) * _shake


func _aim_point(camera: Camera3D, screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var to := from + camera.project_ray_normal(screen) * RANGE
	var result := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return result.position if not result.is_empty() else from + camera.project_ray_normal(screen) * AIM_DEPTH


func _camera() -> Camera3D:
	var parent := get_parent()
	if parent is Camera3D:
		return parent as Camera3D
	return get_viewport().get_camera_3d() if is_inside_tree() else null
