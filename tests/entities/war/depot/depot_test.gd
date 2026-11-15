extends GdUnitTestSuite

const SCENE := preload("res://entities/war/depot/depot.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _real_save


func test_the_depot_stays_away_until_hostile_acquisitions_are_authorised() -> void:
	var save := SaveGame.new()
	assert_bool(Depot.unlocked(save)).is_false()
	assert_bool(Depot.drops(save)).is_false()
	save.stamped.append(Depot.WAR_CARD)
	assert_bool(Depot.unlocked(save)).is_true()
	assert_bool(Depot.drops(save)).is_true()
	assert_bool(Depot.standing(save)).is_false()  # Not before it has dropped in.


func test_the_depot_drops_in_only_once() -> void:
	SaveManager.save.stamped.append(Depot.WAR_CARD)
	var depot: Depot = auto_free(SCENE.instantiate())
	add_child(depot)
	depot.drop()
	assert_bool(SaveManager.save.depot_dropped).is_true()
	assert_bool(Depot.drops(SaveManager.save)).is_false()
	assert_bool(Depot.standing(SaveManager.save)).is_true()
	depot._drop_tween.custom_step(10.0)
	assert_bool(depot.visible).is_true()
	assert_bool((depot.get_node("Dust") as CPUParticles3D).emitting).is_true()
	assert_bool((depot.get_node("Drop") as SoundCue).playing).is_true()
	assert_vector(depot.position).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)  # On its place.


func test_only_hired_unit_types_the_depot_deals_in_are_on_offer() -> void:
	var save := SaveGame.new()
	assert_array(Depot.units(save)).is_empty()
	save.stamped.append(Depot.WAR_CARD)
	assert_array(Depot.units(save)).is_equal(["field_associate"])
	save.stamped.append("unit_pult")  # Hired types join in depot order, whatever order they came in.
	save.stamped.append("unit_charge")
	assert_array(Depot.units(save)).is_equal(["field_associate", "restructuring_charge", "pult_crew"])


func test_a_ray_at_the_depot_finds_it_and_one_beside_it_does_not() -> void:
	SaveManager.save.stamped.append(Depot.WAR_CARD)
	var depot: Depot = auto_free(SCENE.instantiate())
	add_child(depot)
	depot.show()
	assert_bool(depot.hit(Vector3(0, 2, 0), Vector3.DOWN)).is_true()
	assert_bool(depot.hit(Vector3(0.5, 2, 0), Vector3.DOWN)).is_false()
	depot.hide()
	assert_bool(depot.hit(Vector3(0, 2, 0), Vector3.DOWN)).is_false()


func test_hovering_lifts_the_depot_and_raises_its_shutter() -> void:
	var depot: Depot = auto_free(SCENE.instantiate())
	add_child(depot)
	depot.show()
	var shutter := (depot.get_node("Shutter") as Node3D).position.y
	depot.hover(true)
	depot._hover_tween.custom_step(10.0)
	assert_float(depot.position.y).is_equal_approx(Depot.HOVER_LIFT, 0.0001)
	assert_float((depot.get_node("Shutter") as Node3D).position.y).is_equal_approx(shutter + Depot.SHUTTER_UP, 0.0001)
	assert_bool((depot.get_node("Rattle") as SoundCue).playing).is_true()  # It rattles up aloud.
	depot.hover(false)
	depot._hover_tween.custom_step(10.0)
	assert_float(depot.position.y).is_equal_approx(0.0, 0.0001)
	assert_float((depot.get_node("Shutter") as Node3D).position.y).is_equal_approx(shutter, 0.0001)


func test_the_depot_carries_its_name_stencilled_on_the_roof_in_english_and_german() -> void:
	var depot: Depot = auto_free(SCENE.instantiate())
	add_child(depot)
	var stencil := depot.get_node("Stencil") as Label3D
	assert_vector(stencil.global_basis.z).is_equal_approx(depot.global_basis.y, Vector3.ONE * 0.001)  # Facing up.
	assert_float(stencil.position.y).is_greater(depot._box.end.y)  # On the roof, not inside it.
	var locale := TranslationServer.get_locale()
	for pair: Array in [["en", "PERSONNEL"], ["de", "PERSONAL"]]:
		TranslationServer.set_locale(pair[0])
		assert_str(stencil.tr(stencil.text)).starts_with(pair[1])
	TranslationServer.set_locale(locale)
