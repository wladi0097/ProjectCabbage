extends Node
## Run: Godot --headless --path . res://tests/entities/mini_drop/test_mini_drop.tscn

var _failed := false


func _ready() -> void:
	# SPLIT alternates exactly: sales, research, sales, research...; SALES never, RESEARCH always.
	for split: float in [0.0, 0.5, 1.0]:
		var owed := 0.0
		var routes := ""
		for i in 6:
			var research := MiniDrop.goes_to_research(owed, split)
			owed = MiniDrop.owed_after(owed, split, research)
			routes += "R" if research else "S"
		var want: String = {0.0: "SSSSSS", 0.5: "SRSRSR", 1.0: "RRRRRR"}[split]
		_check(routes == want, "split %s routes %s" % [split, routes])
	# Lever: each split has its notch, a turn snaps to the nearest one, a click steps round.
	for split: float in [0.0, 0.5, 1.0]:
		_check(MiniDrop.split_at(MiniDrop.lever_angle(split)) == split, "notch round trip %s" % split)
	_check(MiniDrop.lever_angle(0.0) > 0.0 and MiniDrop.lever_angle(1.0) < 0.0, "SALES right, RESEARCH left")
	_check(MiniDrop.split_at(MiniDrop.SWING * 0.6) == 0.0 and MiniDrop.split_at(MiniDrop.SWING * 0.4) == 0.5, "snaps to nearest")
	_check(MiniDrop.split_at(-5.0) == 1.0 and MiniDrop.split_at(5.0) == 0.0, "clamped past the ends")
	_check(MiniDrop.next_split(0.0) == 0.5 and MiniDrop.next_split(0.5) == 1.0 and MiniDrop.next_split(1.0) == 0.0, "click cycles")
	# The zip through the glass pipe starts and ends on the pipe floor, bouncing between.
	_check(MiniDrop.zip_at(0.0).is_equal_approx(MiniDrop.GLASS_FROM) and MiniDrop.zip_at(1.0).is_equal_approx(MiniDrop.GLASS_TO), "zip ends")
	_check(MiniDrop.zip_at(0.25).y > MiniDrop.GLASS_FROM.y, "zip bounces")
	# The cap counts unsold minis only.
	var units: Array = []
	for flags: Array in [[true, false], [true, true], [false, false], [true, false]]:
		var cabbage := Cabbage.new()
		cabbage.mini = flags[0]
		cabbage.sold = flags[1]
		units.append(cabbage)
	_check(MiniDrop.minis_out(units) == 2, "minis out")
	for cabbage: Cabbage in units:
		cabbage.free()
	print("mini drop tests failed" if _failed else "mini drop tests passed")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
