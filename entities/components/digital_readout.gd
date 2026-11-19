class_name DigitalReadout
extends Node3D
## A dim green digital readout in a dark glass window, the farm TV's phosphor look (FarmTv GLASS,
## terminal_font), that covers a drum counter once the desk card PRINT LARGER NUMBERS (CARD) is
## stamped: the coin tally machine, the Findings counter and the chute's stock drums. It prints
## Num.text's short form (K/M/B/T/Q) after its sign (`mark`), so it never tops out as the drums did.
## Hidden until the card; stamped live, the window comes on at once (the drums are behind it) and its
## figures flicker on (FLICKER); a loaded save just shows it. The host calls show_value every frame.
## Its ink (INK) is pale and cold: the cabbage stays the only saturated green on screen.

## The desk card that turns the counters digital.
const CARD := "print_numbers"
## The readout's green, the farm TV's pilot green paled toward its PHOSPHOR (map tally, field line too).
const INK := Color(0.62, 0.86, 0.68)
## The figures' off/on spans as the window comes on (s, starting dark): about half a second.
const FLICKER: Array[float] = [0.05, 0.07, 0.04, 0.1, 0.06, 0.18]

## The sign in front of the number ($, ¶; none for cabbages).
@export var mark := ""

@onready var _ink: Label3D = $Ink


## Whether the counters show digital for `save`: the card is stamped.
static func on(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


## What the readout prints for `value`.
static func text_for(currency: String, value: int) -> String:
	return currency + Num.text(value)


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


func _flicker() -> void:
	var tween := create_tween()
	for k in FLICKER.size():
		tween.tween_property(_ink, "visible", k % 2 == 1, 0.0)
		tween.tween_interval(FLICKER[k])
	tween.tween_property(_ink, "visible", true, 0.0)
