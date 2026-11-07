extends Node
## Run: Godot --headless --path . res://tests/entities/radio/test_radio.tscn

var _failed := false


func _ready() -> void:
	var save := SaveGame.new()
	_check(not Radio.bought(save), "no radio before the card")
	save.stamped.append("radio")
	_check(Radio.bought(save), "the card brings the radio")
	# Tracks: audio files only, in name order.
	var files: PackedStringArray = ["b.ogg", "a.OGG", "notes.txt", "c.mp3", "d.wav"]
	_check(Radio.track_paths(files) == PackedStringArray(["a.OGG", "b.ogg", "c.mp3", "d.wav"]), "track list")
	_check(Radio.next_track(0, 3) == 1 and Radio.next_track(2, 3) == 0, "next track wraps")
	_check(Radio.next_track(4, 0) == 0, "no tracks")
	# Equal-power crossfade: silent to full, no dip in the middle.
	_check(is_zero_approx(Radio.fade_gain(0.0)) and is_equal_approx(Radio.fade_gain(1.0), 1.0), "fade ends")
	for t in [0.1, 0.5, 0.8]:
		var power := pow(Radio.fade_gain(t), 2) + pow(Radio.fade_gain(1.0 - t), 2)
		_check(is_equal_approx(power, 1.0), "constant power at %s" % t)
	_check(is_equal_approx(Radio.fade_gain(2.0), 1.0), "fade clamps")
	# Silence counts only while bought and stopped.
	_check(is_equal_approx(Radio.silent_after(1.0, 0.5, true, false), 1.5), "stopped counts")
	_check(Radio.silent_after(1.0, 0.5, true, true) == 1.0, "playing does not")
	_check(Radio.silent_after(1.0, 0.5, false, false) == 1.0, "not bought does not")
	print("radio tests failed" if _failed else "radio tests passed")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
