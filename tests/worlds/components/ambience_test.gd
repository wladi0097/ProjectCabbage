extends GdUnitTestSuite

const Ambience := preload("res://worlds/components/ambience.gd")


func test_ambience_plays_only_while_the_radio_is_off() -> void:
	var save := SaveGame.new()
	save.radio_on = true
	assert_bool(Ambience.plays(save)).is_true()  # on, but not bought yet: no music
	save.stamped.append("radio")
	assert_bool(Ambience.plays(save)).is_false()
	save.radio_on = false
	assert_bool(Ambience.plays(save)).is_true()
