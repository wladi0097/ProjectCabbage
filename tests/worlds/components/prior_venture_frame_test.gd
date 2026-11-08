extends GdUnitTestSuite

const FRAME := preload("res://worlds/components/prior_venture_frame.tscn")


func test_a_frame_shows_its_own_cover_and_plate() -> void:
	var frame: Node3D = FRAME.instantiate()
	var cover := StandardMaterial3D.new()
	frame.cover = cover
	frame.plate = "PRIOR VENTURE No. 2"
	add_child(auto_free(frame))
	assert_object((frame.get_node("Model/Cover") as MeshInstance3D).material_override).is_same(cover)
	assert_str((frame.get_node("Plate") as Label3D).text).is_equal("PRIOR VENTURE No. 2")
