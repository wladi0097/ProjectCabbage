@tool
class_name TremorEffect
extends RichTextEffect
## [tremor amp=2 freq=9 hand=0]...[/tremor]: every glyph wanders on its own, `amp` px at `freq` Hz.
## hand=1 makes it look written by hand: each glyph gets its own fixed tilt, size and baseline,
## and the tremble on top is fast and small, like a pen held too tight.

var bbcode := "tremor"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var amp: float = char_fx.env.get("amp", 1.0)
	var freq: float = char_fx.env.get("freq", 8.0)
	var i := float(char_fx.relative_index)
	var t := char_fx.elapsed_time * freq
	char_fx.offset = Vector2(sin(t + i * 1.7) + sin(t * 2.3 + i * 0.9) * 0.5, cos(t * 1.3 + i * 2.1) + sin(t * 3.1 + i) * 0.4) * amp * 0.7
	if int(char_fx.env.get("hand", 0)) == 1:
		# Fixed per glyph (a hash of its index, not time): the slant of a hurried hand.
		var h := absi(hash(char_fx.relative_index))
		var tilt := ((h % 1000) / 1000.0 - 0.5) * 0.35 + 0.12
		var size := 0.88 + ((h >> 10) % 100) / 400.0
		char_fx.offset.y += (((h >> 17) % 100) / 100.0 - 0.5) * amp * 2.0
		char_fx.transform = char_fx.transform * Transform2D(tilt, Vector2(size, size), 0.0, Vector2.ZERO)
	return true
