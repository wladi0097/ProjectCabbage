class_name DigitalReadout
extends Node3D
## A green fourteen-segment readout behind dark smoked glass (DSEG14, assets/fonts/readout_font.tres)
## that covers a drum counter once the desk card PRINT LARGER NUMBERS (CARD) is stamped: the coin
## tally machine, the Findings counter and the chute's stock drums (the other displays keep their own
## look). It prints Num.text's short form (K/M/B/T/Q) after its sign (`mark`), so it never tops out as
## the drums did. Behind the figures ($Figures/Ink) a dim layer lights every segment of every cell
## ($Figures/Ghost, ghost_for), as on a real display. DSEG has no ¶: its fallback font draws the sign.
## Hidden until the card; stamped live, the window comes on at once (the drums are behind it) and its
## figures flicker on (FLICKER); a loaded save just shows it. The host calls show_value every frame.
## Its ink (INK) is pale and cold: the cabbage stays the only saturated green on screen.

## The desk card that turns the counters digital.
const CARD := "print_numbers"
## The readout's green, the farm TV's pilot green paled toward its PHOSPHOR.
const INK := Color(0.62, 0.86, 0.68)
## The figures' off/on spans as the window comes on (s, starting dark): about half a second.
const FLICKER: Array[float] = [0.05, 0.07, 0.04, 0.1, 0.06, 0.18]
## DSEG's every-segment cell and its dot (the dot takes no width: it lights on the cell before it).
const ALL_SEGMENTS := "~."

## The sign in front of the number ($, ¶; none for cabbages).
@export var mark := ""
## How many figure cells fit in the window (inside its margin): the ghost layer fills them all.
@export var cells := 12

@onready var _ink: Label3D = $Figures/Ink
@onready var _ghost: Label3D = $Figures/Ghost


## Whether the counters show digital for `save`: the card is stamped.
static func on(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## What the readout prints for `value`.
static func text_for(currency: String, value: int) -> String:
	return currency + Num.text(value)


## The ghost layer behind `chars` in a window of `cells`: every segment of every cell, right-aligned
## with the figures (a ¶ keeps its own dim sign, being narrower than a cell).
static func ghost_for(chars: String, window_cells: int) -> String:
	var lit := chars.replace(".", "")
	var out := ALL_SEGMENTS.repeat(maxi(window_cells - lit.length(), 0))
	for c in lit:
		out += c if c == "¶" else ALL_SEGMENTS
	return out


func _ready() -> void:
	visible = on(SaveManager.save)


## Prints `value`; comes on (with its flicker) the first time it is called after the card is stamped.
func show_value(value: int) -> void:
	if not visible and on(SaveManager.save):
		visible = true
		_flicker()
	var text := text_for(mark, value)
	if _ink.text != text:
		_ink.text = text
		_ghost.text = ghost_for(text, cells)


func _flicker() -> void:
	var tween := create_tween()
	for k in FLICKER.size():
		tween.tween_property(_ink, "visible", k % 2 == 1, 0.0)
		tween.tween_interval(FLICKER[k])
	tween.tween_property(_ink, "visible", true, 0.0)
