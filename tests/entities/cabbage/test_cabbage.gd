extends Node
## Run: Godot --headless --path . res://tests/entities/cabbage/test_cabbage.tscn

const CabbageScript := preload("res://entities/cabbage/cabbage.gd")


func _ready() -> void:
	var failed := false
	if not is_equal_approx(CabbageScript.squish_at(0.0), CabbageScript.SQUISH):
		failed = true
		push_error("squish does not start fully pressed")
	if CabbageScript.squish_at(CabbageScript.SQUISH_TIME) != 0.0 or absf(CabbageScript.squish_at(0.5)) > 0.02:
		failed = true
		push_error("squish does not settle")
	var s := CabbageScript.squish_scale(0.18)
	if not is_equal_approx(s.y, 0.82) or not is_equal_approx(s.x * s.y * s.z, 1.0):
		failed = true
		push_error("squish_scale %s does not keep the volume" % s)
	print("cabbage tests failed" if failed else "cabbage tests passed")
	get_tree().quit(1 if failed else 0)
