extends GdUnitTestSuite

const SCENE := preload("res://entities/chute_lever/chute_lever.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


func _lever(save: SaveGame) -> ChuteLever:
	SaveManager.save = save
	var lever: ChuteLever = auto_free(SCENE.instantiate())
	add_child(lever)
	return lever


func test_the_chute_lever_only_appears_once_its_card_is_stamped() -> void:
	var save := SaveGame.new()
	assert_bool(ChuteLever.bought(save)).is_false()
	assert_bool(_lever(save).visible).is_false()
	save.stamped.append("chute_control")
	assert_bool(ChuteLever.bought(save)).is_true()


func test_a_hidden_lever_cannot_be_grabbed() -> void:
	var lever := _lever(SaveGame.new())
	assert_bool((lever.get_node("Arm/Handle/Shape") as CollisionShape3D).disabled).is_true()


## The hand grabs an Interactable at its body's centre: that is the black rubber grip at the arm's
## end (chute_lever_geo.py: y 0.222, z -0.02..0.094), not the hub on the axle.
func test_the_hand_grabs_the_lever_by_its_rubber_grip_not_by_the_hub() -> void:
	var handle := _lever(SaveGame.new()).get_node("Arm/Handle") as Node3D
	assert_vector(handle.position).is_equal_approx(Vector3(0, 0.222, 0.037), Vector3.ONE * 0.01)


func test_pulling_the_lever_shuts_the_chute_and_pulling_again_opens_it() -> void:
	var save := SaveGame.new()
	save.stamped.append("chute_control")
	var lever := _lever(save)
	lever.pull()
	assert_bool(save.chute_blocked).is_true()
	lever.pull()
	assert_bool(save.chute_blocked).is_false()


func test_the_lever_is_down_and_the_flap_across_the_chute_while_blocked() -> void:
	assert_float(ChuteLever.lever_angle(true)).is_greater(ChuteLever.lever_angle(false))
	assert_float(ChuteLever.flap_angle(true)).is_equal(ChuteLever.FLAP_SHUT)
	assert_float(ChuteLever.flap_angle(false)).is_equal(ChuteLever.FLAP_OPEN)


func test_a_loaded_save_shows_the_lever_and_flap_where_they_were_left() -> void:
	var save := SaveGame.new()
	save.stamped.append("chute_control")
	save.chute_blocked = true
	var lever := _lever(save)
	assert_bool(lever.visible).is_true()
	assert_float((lever.get_node("Arm") as Node3D).rotation.z).is_equal_approx(ChuteLever.PULLED_ANGLE, 0.0001)
	assert_float((lever.get_node("Flap") as Node3D).rotation.z).is_equal_approx(ChuteLever.FLAP_SHUT, 0.0001)


## Open, the flap swings out to the screen's right (up the chute, away from the mat), lying about level.
func test_the_open_flap_swings_up_the_chute_to_the_right() -> void:
	assert_float(ChuteLever.FLAP_OPEN).is_greater(0.0)
	var flap_end := Vector3.DOWN.rotated(Vector3.BACK, ChuteLever.FLAP_OPEN)
	assert_float(flap_end.x).is_greater(0.9)



func test_pulling_down_plays_the_slam_and_pulling_up_cuts_it_for_the_ratchet() -> void:
	var save := SaveGame.new()
	save.stamped.append("chute_control")
	var lever := _lever(save)
	var shut := lever.get_node("Flap/Shut") as AudioStreamPlayer3D
	var lift := lever.get_node("Flap/Lift") as AudioStreamPlayer3D
	assert_object(shut.stream).is_not_null()
	assert_object(lift.stream).is_not_null()
	lever.pull()
	assert_bool(shut.playing).is_true()
	assert_bool(lift.playing).is_false()
	lever.pull()
	assert_bool(shut.playing).is_false()
	assert_bool(lift.playing).is_true()
