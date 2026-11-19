class_name DigitalReadout
extends Node3D
## A green fourteen-segment readout behind dark smoked glass (segment_display.gdshader: ghosted unlit
## segments, a soft phosphor glow, scanlines) that covers a drum counter once the desk card PRINT
## LARGER NUMBERS (CARD) is stamped: the coin tally machine, the Findings counter and the chute's stock
## drums; the map tally's windows and the Field Line's count window turn to it too. It prints
## Num.text's short form (K/M/B/T/Q) after its sign (`mark`), so it never tops out as the drums did.
## Hidden until the card; stamped live, the window comes on at once (the drums are behind it) and its
## figures flicker on (FLICKER); a loaded save just shows it. The host calls show_value (or show_text)
## every frame. Its ink (INK) is pale and cold: the cabbage stays the only saturated green on screen.

## The desk card that turns the counters digital.
const CARD := "print_numbers"
## The readout's green, the farm TV's pilot green paled toward its PHOSPHOR (map tally, field line too).
const INK := Color(0.62, 0.86, 0.68)
## The figures' off/on spans as the window comes on (s, starting dark): about half a second.
const FLICKER: Array[float] = [0.05, 0.07, 0.04, 0.1, 0.06, 0.18]
## The segments each of CHARS lights (bits: segment_display.gdshader SEGS; the dot is DOT and
## lights on the character before it; anything else is blank). ¶ and B have shapes of their own
## (bits 15, 16): in segments they read as a 9 and an 8.
const DOT := 1 << 14
const CHARS := "0123456789KMBTQ$¶-/"
const SEGMENTS: Array[int] = [
	0x3F, 0x06, 0xDB, 0x8F, 0xE6, 0xED, 0xFD, 0x07, 0xFF, 0xEF,
	0x2470, 0x0536, 0x10000, 0x1201, 0x203F, 0x12ED, 0x8000, 0xC0, 0x0C00,
]

## The sign in front of the number ($, ¶; none for cabbages).
@export var mark := ""
## The fewest figure cells the window holds (the figures shrink to fit them); more fit if there is room.
@export var min_cells := 1

## What the readout prints now.
var text := ""
## The figures' colour (INK; the map tally's FULL red).
var ink := INK:
	set(value):
		ink = value
		if _material:
			_material.set_shader_parameter(&"ink", value)

@onready var _ink: MeshInstance3D = $Glass/Ink
@onready var _material: ShaderMaterial = _ink.get_surface_override_material(0)


## Whether the counters show digital for `save`: the card is stamped.
static func on(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## What the readout prints for `value`.
static func text_for(currency: String, value: int) -> String:
	return currency + Num.text(value)


## The segments character `c` lights (0: blank).
static func glyph(c: String) -> int:
	var at := CHARS.find(c)
	return SEGMENTS[at] if at >= 0 else 0


## The segment masks for `text`, rightmost character first (a dot joins the character before it).
static func masks_for(chars: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var dot := 0
	for k in range(chars.length() - 1, -1, -1):
		if chars[k] == ".":
			dot = DOT
			continue
		out.append(glyph(chars[k]) | dot)
		dot = 0
	if dot:
		out.append(dot)
	out.resize(16)
	return out


func _ready() -> void:
	visible = on(SaveManager.save)
	_material.set_shader_parameter(&"min_cells", min_cells)


## Prints `value` after the sign; see show_text.
func show_value(value: int) -> void:
	show_text(text_for(mark, value))


## Prints `chars`; comes on (with its flicker) the first time it is called after the card is stamped.
func show_text(chars: String) -> void:
	if not visible and on(SaveManager.save):
		visible = true
		_flicker()
	if text != chars:
		text = chars
		_material.set_shader_parameter(&"masks", masks_for(chars))


func _flicker() -> void:
	var tween := create_tween()
	for k in FLICKER.size():
		tween.tween_property(_ink, "visible", k % 2 == 1, 0.0)
		tween.tween_interval(FLICKER[k])
	tween.tween_property(_ink, "visible", true, 0.0)
