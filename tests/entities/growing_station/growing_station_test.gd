extends GdUnitTestSuite


func _stamped() -> SaveGame:
	var save := SaveGame.new()
	save.stamped.append("mini_station")
	return save


func test_the_growing_station_turns_about_one_mini_in_twenty_into_a_full_cabbage() -> void:
	var save := _stamped()
	var grown := 0
	for i in 1000:
		if GrowingStation.grows(save, (i + 0.5) / 1000.0):
			grown += 1
	assert_int(grown).is_equal(50)


func test_no_mini_grows_without_the_growing_station_card() -> void:
	assert_bool(GrowingStation.grows(SaveGame.new(), 0.0)).is_false()


func test_a_higher_grow_chance_grows_more_minis() -> void:
	var save := _stamped()
	assert_bool(GrowingStation.grows(save, 0.1)).is_false()
	save.mini_grow_chance = 0.15
	assert_bool(GrowingStation.grows(save, 0.1)).is_true()


func test_a_grown_mini_lights_the_collar_cold_blue_and_it_fades_back_to_dark() -> void:
	var station: GrowingStation = auto_free(preload("res://entities/growing_station/growing_station.tscn").instantiate())
	add_child(station)
	var glow := (station.get_node("Model/Glow") as MeshInstance3D).material_override as StandardMaterial3D
	assert_float(glow.emission_energy_multiplier).is_equal(0.0)
	assert_float(glow.emission.b).is_greater(glow.emission.r)
	station.pulse()
	await get_tree().create_timer(GrowingStation.GLOW_RISE).timeout
	assert_float(glow.emission_energy_multiplier).is_greater(0.5)
	await get_tree().create_timer(GrowingStation.GLOW_FADE + 0.2).timeout
	assert_float(glow.emission_energy_multiplier).is_equal_approx(0.0, 0.001)
