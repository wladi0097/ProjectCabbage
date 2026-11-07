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
	# Variants: a mini is about a quarter of the mass, a research unit glows.
	var scene := load("res://entities/cabbage/cabbage.tscn") as PackedScene
	var mini := scene.instantiate() as Cabbage
	mini.mini = true
	var research := scene.instantiate() as Cabbage
	research.research = true
	add_child(mini)
	add_child(research)
	# At most the biggest size spread (1 + SIZE_SPREAD) times the mini scale: mass cubed, radius once.
	var most := (1.0 + CabbageScript.SIZE_SPREAD) * CabbageScript.MINI_SCALE
	if mini.mass > 0.8 * pow(most, 3.0) + 0.0001 or (mini.get_node("Shape").shape as SphereShape3D).radius > 0.11 * most + 0.0001:
		failed = true
		push_error("mini mass %.2f too big" % mini.mass)
	if research.get_node("Mesh").material_override != CabbageScript.RESEARCH_MATERIAL:
		failed = true
		push_error("research unit has no research material")
	mini.free()
	research.free()
	print("cabbage tests failed" if failed else "cabbage tests passed")
	get_tree().quit(1 if failed else 0)
