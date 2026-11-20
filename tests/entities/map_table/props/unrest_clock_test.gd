extends GdUnitTestSuite

const Clock := preload("res://entities/map_table/props/unrest_clock.gd")

var _real_save: SaveGame
var _locale: String


func before_test() -> void:
	_real_save = SaveManager.save
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	SaveManager.save = _real_save
	TranslationServer.set_locale(_locale)


func _clock(save: SaveGame) -> Clock:
	SaveManager.save = save
	var clock: Clock = auto_free(load("res://entities/map_table/props/unrest_clock.tscn").instantiate())
	add_child(clock)
	clock._process(0.0)
	return clock


func _unrest() -> SaveGame:
	var save := SaveGame.new()
	save.stamped = PackedStringArray([BanditCamp.CARD])
	return save


func test_the_clock_is_not_on_the_table_before_the_camps_card() -> void:
	assert_bool(_clock(SaveGame.new()).visible).is_false()


func test_on_an_empty_map_the_clock_counts_down_to_the_next_camp() -> void:
	var save := _unrest()
	save.bandit_wait = 125.0
	var clock := _clock(save)
	assert_bool(clock.visible).is_true()
	assert_str((clock.get_node("Glass/Ink") as Label3D).text).is_equal("02:05")
	assert_str(Clock.hint_for(save)).is_equal("Next rebel camp in 02:05.")


func test_while_a_camp_stands_the_clock_shows_its_level_and_when_it_goes() -> void:
	var save := _unrest()
	BanditCamp.tick(save, 0.016)
	save.camps_recovered = 2
	var clock := _clock(save)
	assert_str(Clock.hint_for(save)).is_equal("Rebel camp, level 3. It leaves in 10:00. Click the camp to take back what is ours.")
	assert_str((clock.get_node("Glass/Ink") as Label3D).text).is_equal("10:00")


func test_the_clock_carries_only_its_numbers_and_explains_itself_in_the_hint_slip() -> void:
	var clock := _clock(_unrest())
	var words: Array[String] = []
	for label: Label3D in clock.find_children("*", "Label3D", true, false):
		if clock.get_node("Resurvey").is_ancestor_of(label) or label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
			continue  # RESURVEY's stencil, and the readout's digits.
		words.append(label.name)
	assert_array(words).is_empty()


func test_resurvey_stands_on_the_clock_only_once_its_depot_node_is_bought() -> void:
	var save := _unrest()
	var clock := _clock(save)
	assert_bool(clock.can_press()).is_false()
	save.tree_bought = PackedStringArray([BanditCamp.RESURVEY_NODE])
	clock._process(0.0)
	assert_bool(clock.can_press()).is_true()


func test_pressing_resurvey_puts_a_new_camp_of_the_same_level_on_the_map() -> void:
	var save := _unrest()
	save.tree_bought = PackedStringArray([BanditCamp.RESURVEY_NODE])
	BanditCamp.tick(save, 0.016)
	var was := save.bandit_camp
	var clock := _clock(save)
	assert_bool(clock.resurvey()).is_true()  # No income yet: it costs nothing.
	assert_int(save.bandit_camp).is_not_equal(was)


func test_the_clocks_hint_takes_the_mouse_over_its_whole_face() -> void:
	var clock := _clock(_unrest())
	var body := (clock.get_node("Body") as MeshInstance3D).mesh.get_aabb()
	assert_vector(Clock.FACE_HALF * 2.0).is_equal_approx(Vector2(body.size.x, body.size.z), Vector2(0.001, 0.001))
	var top := FarmTv.rect_uv(clock.face().global_transform, Clock.FACE_HALF, clock.global_position + Vector3(0.3, 1.0, 0.17), Vector3.DOWN)
	assert_bool(FarmTv.on_glass(top)).is_true()  # A corner of the plate, from above.
