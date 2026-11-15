class_name WarControl
extends Node3D
## The fight's control box on the map table beside the war sheet: a split-flap timer (m:ss), a lamp-lit START
## button and an oxblood ABORT button, each over an engraved plate. Meshes, lamps and labels live in the scene;
## this script only shows the state the host gives it and animates the buttons.
##
## Flow: the host turns a mouse ray into a part with part_at(from, dir), calls hover(part) while the mouse moves
## and press(part) on a click. press() plays the press and emits start_pressed / abort_pressed when the button
## is live (can_press), or plays the refused thud and returns false. The host then answers with set_state(),
## set_time() every frame of a fight, set_flee_allowed() (the paper upgrade: during a fight ABORT turns into
## a RETREAT button) and set_start_enabled() (false while the war can't start, e.g. a figure lies off-zone).

signal start_pressed
signal abort_pressed

enum State { READY, RUNNING, ENDED }

const START := &"start"
const ABORT := &"abort"
## The plates' words (keys in game.csv). ABORT reads RETREAT while it is the flee button.
const START_WORD := "BUTTON START"
const ABORT_WORD := "ABORT"
const FLEE_WORD := "RETREAT"
## The timer blinks red from this many seconds left; one blink cycle takes BLINK s.
const LAST := 10.0
const BLINK := 0.5
## How far a press pushes a cap in (m), how deep START stays latched once the fight runs, a hover's nudge,
## how long a press takes (s) and the share of it going down.
const TRAVEL := 0.009
const LATCH := 0.007
const NUDGE := 0.0015
const PRESS_TIME := 0.22
const DOWN := 0.25
## Lamp energies: lit, under the mouse, off. A refused START glows a dim ivory so it reads "not yet" (at 0.06
## it read as a broken brown lens). The oxblood ABORT lamp runs dull before the fight (a hot red read as candy);
## as the flee button it burns brighter (FLEE_LIT) and breathes deep once every PULSE s.
const LIT := 1.1
const HOT := 2.6
const EMBER := 0.22
const ABORT_LIT := 0.35
const FLEE_LIT := 0.9
const ABORT_HOT := 1.4
const PULSE := 1.6
## How fast lamps ease to their target (1/s).
const EASE := 12.0
const DIGIT_COLOUR := Color(0.84, 0.82, 0.72)
const LAST_COLOUR := Color(0.78, 0.27, 0.18)
const DEAD_COLOUR := Color(0.3, 0.3, 0.28)
## The button plates' text runs no wider than this (m), the time plate's no wider than TIME_TEXT, so a long
## word shrinks instead of spilling. Both button plates share one size.
const PLATE_TEXT := 0.064
const TIME_TEXT := 0.122

var state := State.READY
var flee_allowed := false
var start_enabled := true
var seconds_left := 90.0
var _hover := &""
## Press dip per part, 0..1 through a press (−1: no press running).
var _press := {START: -1.0, ABORT: -1.0}
var _clock := 0.0

@onready var _start_cap: MeshInstance3D = $Panel/StartCap
@onready var _abort_cap: MeshInstance3D = $Panel/AbortCap
@onready var _start_lens: StandardMaterial3D = _start_cap.get_surface_override_material(0)
@onready var _abort_lens: StandardMaterial3D = _abort_cap.get_surface_override_material(0)
@onready var _digits: Array[Label3D] = [$Panel/Digits/Min, $Panel/Digits/Colon, $Panel/Digits/Sec10, $Panel/Digits/Sec1]
@onready var _start_plate: Label3D = $Panel/StartPlate
@onready var _abort_plate: Label3D = $Panel/AbortPlate
@onready var _hits := {START: $Panel/Hits/Start as CollisionShape3D, ABORT: $Panel/Hits/Abort as CollisionShape3D}


## The timer's text: whole seconds rounded up, m:ss, 0:00 at the end, held at 9:59 (one flap for minutes).
static func time_text(seconds: float) -> String:
	var s := clampi(ceili(seconds), 0, 599)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


## Whether a part takes a press: START only before the fight and while the war may start; ABORT before the
## fight, and during it only as the flee button.
static func can_press(part: StringName, at: State, enabled: bool, flee: bool) -> bool:
	match part:
		START:
			return at == State.READY and enabled
		ABORT:
			return at == State.READY or (at == State.RUNNING and flee)
	return false


## The timer is in its last seconds (it blinks red) while a fight runs with LAST s or less left.
static func last_seconds(at: State, seconds: float) -> bool:
	return at == State.RUNNING and seconds <= LAST


## How deep a cap sits `k` of the way through a press: in fast, out slower.
static func dip(k: float) -> float:
	if k < 0.0:
		return 0.0
	return TRAVEL * (k / DOWN if k < DOWN else (1.0 - k) / (1.0 - DOWN))


func _ready() -> void:
	var time_plate: Label3D = $Panel/TimePlate
	time_plate.pixel_size = _fit_size(time_plate, TIME_TEXT)
	_refresh(true)


func set_time(seconds: float) -> void:
	seconds_left = seconds
	_refresh()


func set_state(to: State) -> void:
	state = to
	_refresh()


func set_flee_allowed(on: bool) -> void:
	flee_allowed = on
	_refresh()


func set_start_enabled(on: bool) -> void:
	start_enabled = on
	_refresh()


## The mouse is on `part` ("" for none): a live button sinks a hair and its lamp brightens.
func hover(part: StringName) -> void:
	_hover = part


## Click on `part`: a live button goes in with a clack and its signal fires; a dead one thuds. True if it took.
func press(part: StringName) -> bool:
	if part != START and part != ABORT:
		return false
	if not can_press(part, state, start_enabled, flee_allowed):
		($Denied as SoundCue).cue(global_position)
		return false
	($Press as SoundCue).cue(global_position)
	_press[part] = 0.0
	if part == START:
		start_pressed.emit()
	else:
		abort_pressed.emit()
	return true


## The button a ray (world space) hits first, "" for none. Tests the boxes in Panel/Hits without physics.
func part_at(from: Vector3, dir: Vector3) -> StringName:
	var best := &""
	var near := INF
	for part: StringName in _hits:
		var shape: CollisionShape3D = _hits[part]
		var inv := shape.global_transform.affine_inverse()
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var hit: Variant = AABB(-size / 2.0, size).intersects_ray(inv * from, inv.basis * dir)
		if hit != null:
			var d := from.distance_to(shape.global_transform * (hit as Vector3))
			if d < near:
				near = d
				best = part
	return best


## The middle of `part`'s cap top (world space), where a fingertip presses it; it sinks with the cap.
func part_position(part: StringName) -> Vector3:
	var cap := _start_cap if part == START else _abort_cap
	var box := cap.get_aabb()
	return cap.global_transform * Vector3(box.get_center().x, box.end.y, box.get_center().z)


func _process(delta: float) -> void:
	_clock += delta
	for part: StringName in _press:
		if _press[part] >= 0.0:
			_press[part] += delta / PRESS_TIME
			if _press[part] >= 1.0:
				_press[part] = -1.0
	_pose(delta)
	if last_seconds(state, seconds_left):
		var on := fmod(_clock, BLINK) < BLINK * 0.6
		for d in _digits:
			d.modulate = LAST_COLOUR if on else LAST_COLOUR.darkened(0.7)


func _pose(delta: float) -> void:
	var k := 1.0 if delta < 0.0 else 1.0 - exp(-EASE * delta)
	var start_live := can_press(START, state, start_enabled, flee_allowed)
	var abort_live := can_press(ABORT, state, start_enabled, flee_allowed)
	var start_rest := LATCH if state != State.READY else (NUDGE if start_live and _hover == START else 0.0)
	var abort_rest := NUDGE if abort_live and _hover == ABORT else 0.0
	_start_cap.position.y = 0.003 - maxf(start_rest, dip(_press[START]))
	_abort_cap.position.y = 0.003 - maxf(abort_rest, dip(_press[ABORT]))
	var start_glow := (HOT if _hover == START else LIT) if start_live else (EMBER if state == State.READY else 0.0)
	var abort_glow := 0.0
	if abort_live:
		abort_glow = ABORT_HOT if _hover == ABORT else (FLEE_LIT if state == State.RUNNING else ABORT_LIT)
	if abort_live and state == State.RUNNING and _hover != ABORT:
		abort_glow *= 0.55 + 0.45 * cos(_clock * TAU / PULSE)
	_start_lens.emission_energy_multiplier = lerpf(_start_lens.emission_energy_multiplier, start_glow, k)
	_abort_lens.emission_energy_multiplier = lerpf(_abort_lens.emission_energy_multiplier, abort_glow, k)


## Shows the state; `snap` jumps the lamps there (a loaded fight stays silent).
func _refresh(snap := false) -> void:
	if not is_node_ready():
		return
	var text := time_text(seconds_left)
	if text.length() == 4:
		for i in 4:
			_digits[i].text = text[i]
	var colour := DEAD_COLOUR if state == State.ENDED else DIGIT_COLOUR
	for d in _digits:
		d.modulate = colour
	_abort_plate.text = FLEE_WORD if state == State.RUNNING and flee_allowed else ABORT_WORD
	var size := minf(_fit_size(_start_plate, PLATE_TEXT), _fit_size(_abort_plate, PLATE_TEXT))
	_start_plate.pixel_size = size
	_abort_plate.pixel_size = size
	_pose(-1.0 if snap else 0.0)


## The pixel size that keeps a plate's text within `width` m (a long German word shrinks), never above the design size.
static func _fit_size(label: Label3D, width: float) -> float:
	var w := label.font.get_string_size(label.tr(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	return minf(0.00036, width / maxf(w, 1.0))
