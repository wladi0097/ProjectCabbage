class_name BossCard
extends CanvasLayer
## The chapter 5 ending's boss notices and its HUD (research/chapter5-ending.md). show_card drops a
## notice from the Office of the Director into the middle of the screen and the voice line plays;
## it goes again on a click or when its time is up. `level` 0..4 is how far gone the Director is
## (style()): the text wiggles harder, the whole sheet shakes, the paper tears, the type grows, and
## the last one is written by hand.
## Around it: the click prompt, the universe ticker, the "non-cabbage items" counter, a hum and a
## heartbeat. Voice slots 1..5 are `voices` (placeholders until the recordings, tools/voice_fx.sh).

## Per level (0..4): text wiggle (px) and its speed (Hz), sheet shake (px), body type size, how torn
## the paper is (0 = whole), the sheet's own tilt (degrees). The last card is handwritten.
const WIGGLE := [0.6, 1.5, 3.0, 5.0, 6.0]
const WIGGLE_HZ := [3.0, 5.0, 8.0, 12.0, 24.0]
const SHAKE := [0.0, 0.8, 2.5, 6.0, 8.0]
const FONT_SIZE := [30, 40, 54, 72, 80]
const TEAR := [0, 0, 1, 2, 3]
const SHEET_TILT := [-1.0, 1.5, -3.0, 4.5, -7.0]
const HAND_FROM := 4

const PAPER := Color(0.72, 0.73, 0.69)
const PAPER_EDGE := Color(0.86, 0.86, 0.82)
const INK := Color(0.13, 0.15, 0.14)
## The pen of the handwritten card: blue-black, as on the boss report's signature.
const PEN := Color(0.1, 0.12, 0.2)
const SIZE := Vector2(760, 500)
## The signature line's height on the paper (px).
const SIGN_Y := 438.0
const IN_TIME := 0.45
const OUT_TIME := 0.35
## A card stays at least MIN_HOLD s, and AFTER_VOICE s after its line ends; a click sends it away,
## but not in its first DISMISS_AFTER s (the click that fired the gun must not skip it).
const MIN_HOLD := 3.5
const AFTER_VOICE := 1.2
const DISMISS_AFTER := 1.0
## The hum's volume at a whisper (level → 0) and at full (1), and its pitch climb.
const HUM_DB := Vector2(-32.0, -4.0)
const HUM_PITCH := Vector2(0.9, 1.15)

## Voice lines 1..5 (index 0 = line 1).
@export var voices: Array[AudioStream] = []
@export var print_font: Font
@export var hand_font: Font

## Whether a card is up, and its level.
var up := false
var level := 0
## The hum's level, 0..1 (0 = silent).
var hum_level := 0.0
var _t := 0.0
var _hold := 0.0
var _slide := 0.0
var _dismissed := false
var _outline := PackedVector2Array()

@onready var _blocker: Control = $Blocker
@onready var _paper: Control = $Paper
@onready var _body: RichTextLabel = $Paper/Body
@onready var _prompt: Label = $Prompt
@onready var _ticker: Control = $Ticker
@onready var _ticker_value: Label = $Ticker/Box/Value
@onready var _remaining: Label = $Remaining
@onready var _voice: AudioStreamPlayer = $Voice
@onready var _hum: AudioStreamPlayer = $Hum
@onready var _heartbeat: AudioStreamPlayer = $Heartbeat


func _ready() -> void:
	_paper.pivot_offset = SIZE / 2.0
	_paper.draw.connect(_draw_paper)
	_blocker.gui_input.connect(_on_blocker_input)


func _process(delta: float) -> void:
	_prompt.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	if not up:
		return
	_t += delta
	var view := get_viewport().get_visible_rect().size
	var shake: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * style(level).shake
	_paper.position = view * 0.5 - SIZE * 0.5 + Vector2(0, -view.y * (1.0 - _slide)) + shake


## How deranged the card at `lvl` (clamped to 0..4) looks.
static func style(lvl: int) -> Dictionary:
	var i := clampi(lvl, 0, 4)
	return {wiggle = WIGGLE[i], wiggle_hz = WIGGLE_HZ[i], shake = SHAKE[i], font_size = FONT_SIZE[i],
		tear = TEAR[i], tilt = SHEET_TILT[i], hand = i >= HAND_FROM}


## The body as bbcode: `text` (its brackets escaped) inside the tremor of level `lvl`.
static func bbcode(text: String, lvl: int) -> String:
	var s := style(lvl)
	return "[tremor amp=%.1f freq=%.1f hand=%d]%s[/tremor]" % [s.wiggle, s.wiggle_hz, 1 if s.hand else 0, text.replace("[", "[lb]")]


## The sheet's outline at tear `tear` (0 = a clean rectangle): jagged torn edges, a corner bitten off,
## a rip into the bottom edge; 3 is a scrap torn on every side. Seeded, so a card tears the same way each time.
static func outline(tear: int, size: Vector2 = SIZE) -> PackedVector2Array:
	if tear <= 0:
		return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5 + tear
	# Per edge (top, right, bottom, left): how deep the torn fibres bite (px).
	var jag: Array = [[0.0, 0.0, 7.0, 0.0], [4.0, 10.0, 12.0, 0.0], [12.0, 14.0, 16.0, 12.0]][tear - 1]
	var bite: float = [70.0, 150.0, 120.0][tear - 1]
	var rip: float = [0.0, 130.0, 190.0][tear - 1]
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	var inward := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
	var out := PackedVector2Array()
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var steps := int(a.distance_to(b) / 16.0)
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			p += inward[e] * rng.randf() * jag[e]
			if e == 2 and rip > 0.0:
				# The rip: a V torn up into the bottom edge at 62 % of the width.
				var near := 1.0 - absf(p.x - size.x * 0.62) / 34.0
				if near > 0.0:
					p.y -= rip * near + rng.randf() * 8.0
			# The top-right corner bitten off along a ragged diagonal.
			var over := bite - ((size.x - p.x) + p.y)
			if over > 0.0:
				p += Vector2(-over, over) * 0.5 + Vector2(rng.randf(), rng.randf()) * 6.0
			out.append(p)
	return out


## Drops a card with `text`, as deranged as `lvl`, and plays voice line `voice` (1..5, 0 = none).
## Returns once it is gone again (clicked away, or its time is up).
func show_card(text: String, lvl: int, voice: int) -> void:
	level = clampi(lvl, 0, 4)
	var s := style(level)
	_outline = outline(s.tear)
	_body.add_theme_font_override("normal_font", hand_font if s.hand else print_font)
	_body.add_theme_font_size_override("normal_font_size", s.font_size)
	_body.add_theme_color_override("default_color", PEN if s.hand else INK)
	_body.text = bbcode(tr(text), level)
	_paper.rotation_degrees = s.tilt
	_paper.queue_redraw()
	_t = 0.0
	_slide = 0.0
	_dismissed = false
	_hold = MIN_HOLD
	_voice.stop()
	if voice >= 1 and voice <= voices.size() and voices[voice - 1] != null:
		_voice.stream = voices[voice - 1]
		_voice.play()
		_hold = maxf(MIN_HOLD, voices[voice - 1].get_length() + AFTER_VOICE)
	up = true
	_paper.visible = true
	_blocker.visible = true
	$Land.play()
	create_tween().tween_property(self, "_slide", 1.0, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	while _t < _hold and not _dismissed and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return  # Taken off the screen with the world (a reload) while it was up.
	$Rustle.play()
	var out := create_tween()
	out.tween_property(self, "_slide", 0.0, OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await out.finished
	up = false
	_paper.visible = false
	_blocker.visible = false


## Sends the card up away now (as a click does once DISMISS_AFTER has passed).
func dismiss() -> void:
	_dismissed = true


## The click prompt at the bottom of the screen.
func show_prompt(on: bool) -> void:
	_prompt.visible = on


## The universe ticker's readout (e.g. "99.999999%*"); empty hides it.
func set_ticker(percent_text: String) -> void:
	_ticker_value.text = percent_text
	_ticker.visible = not percent_text.is_empty()


## "NON-CABBAGE ITEMS REMAINING: n"; -1 hides it.
func set_remaining(n: int) -> void:
	_remaining.visible = n >= 0
	_remaining.text = tr("NON-CABBAGE ITEMS REMAINING: %d") % maxi(n, 0)


## The low hum, 0..1: louder and a touch higher as it rises; 0 cuts it dead.
func set_hum(lvl: float) -> void:
	hum_level = clampf(lvl, 0.0, 1.0)
	if hum_level <= 0.0:
		_hum.stop()
		return
	_hum.volume_db = lerpf(HUM_DB.x, HUM_DB.y, hum_level)
	_hum.pitch_scale = lerpf(HUM_PITCH.x, HUM_PITCH.y, hum_level)
	if not _hum.playing:
		_hum.play()


## The hum's player: the end card speeds it up with the credits (EndCard.pitched).
func hum_player() -> AudioStreamPlayer:
	return _hum


## The heartbeat loop on or off.
func heartbeat(on: bool) -> void:
	if on and not _heartbeat.playing:
		_heartbeat.play()
	elif not on:
		_heartbeat.stop()


func _on_blocker_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and _t >= DISMISS_AFTER:
		dismiss()
	_blocker.accept_event()


func _draw_paper() -> void:
	if _outline.is_empty():
		return
	var shadow := PackedVector2Array()
	for p in _outline:
		shadow.append(p + Vector2(14, 14))
	_paper.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	_paper.draw_colored_polygon(_outline, PAPER)
	# The letterhead's double rule and the signature line, cut where the paper is torn away.
	for rule: Array in [[64.0, 3.0, SIZE.x - 36.0], [71.0, 1.0, SIZE.x - 36.0], [SIGN_Y, 1.5, 420.0]]:
		for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(36, rule[0]), Vector2(rule[2], rule[0])]), _outline):
			_paper.draw_polyline(piece, Color(INK, 0.85), rule[1])
	if _outline.size() > 4:
		# Torn fibres: the pale inside of the paper shows along the edge.
		var ring := _outline.duplicate()
		ring.append(_outline[0])
		_paper.draw_polyline(ring, PAPER_EDGE, 2.5, true)
