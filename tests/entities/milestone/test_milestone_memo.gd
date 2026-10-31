extends Node
## Run: Godot --headless --path . res://tests/entities/milestone/test_milestone_memo.tscn

const Memo := preload("res://entities/milestone/milestone_memo.gd")


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	if not Memo.due(24, save.milestones).is_empty() or Memo.due(25, save.milestones).id != "units_25":
		failed = true
		push_error("the first memo should come at 25 units")
	# Two thresholds passed at once come one after the other, each applied once.
	Memo.apply(save, Memo.due(120, save.milestones))
	if Memo.due(120, save.milestones).id != "units_100":
		failed = true
		push_error("100 should be due once 25 is reached")
	Memo.apply(save, Memo.due(120, save.milestones))
	if not Memo.due(120, save.milestones).is_empty():
		failed = true
		push_error("nothing should be due after both are reached")
	if not is_equal_approx(save.marketing, 1.25) or save.findings_per_cabbage != 2:
		failed = true
		push_error("bonuses: marketing %s, findings %s" % [save.marketing, save.findings_per_cabbage])
	if save.milestones != PackedStringArray(["units_25", "units_100"]):
		failed = true
		push_error("reached ids: %s" % save.milestones)
	var last := 0
	for m: Dictionary in Memo.MILESTONES:
		if m.at <= last or not (m.mul >= 1.25) or not m.key in save:
			failed = true
			push_error("milestone %s: rising thresholds, felt (>= x1.25) bonus on a save number" % m.id)
		last = m.at
	if not is_zero_approx(Memo.slide_at(0.0, Memo.HOLD)) or not is_equal_approx(Memo.slide_at(Memo.IN_TIME, Memo.HOLD), 1.0) \
			or not is_zero_approx(Memo.slide_at(Memo.HOLD + Memo.OUT_TIME, Memo.HOLD)):
		failed = true
		push_error("memo should slide up, hold, and slide away")
	print("milestone memo tests failed" if failed else "milestone memo tests passed")
	get_tree().quit(1 if failed else 0)
