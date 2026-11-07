extends Node
## Run: Godot --headless --path . res://tests/entities/qa_bay/test_qa_bay.tscn


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	save.findings_per_cabbage = 2
	save.research_mult = 3.0
	save.mini_value = 0.25
	var unit := Cabbage.new()
	var research := Cabbage.new()
	research.research = true
	var mini := Cabbage.new()
	mini.mini = true
	# A plain unit, a research unit (× research_mult), a mini (a share, at least 1).
	if QaBay.findings_for(unit, save) != 2 or QaBay.findings_for(research, save) != 6 or QaBay.findings_for(mini, save) != 1:
		failed = true
		push_error("findings_for wrong")
	save.findings_per_cabbage = 10
	if QaBay.findings_for(mini, save) != 3:
		failed = true
		push_error("findings_for a mini should round its share")
	for cabbage in [unit, research, mini]:
		cabbage.free()
	print("qa bay tests failed" if failed else "qa bay tests passed")
	get_tree().quit(1 if failed else 0)
