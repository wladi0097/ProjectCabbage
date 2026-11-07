extends GdUnitTestSuite

const Lamp := preload("res://entities/golden_lamp/golden_lamp.gd")
const SCENE := preload("res://entities/golden_lamp/golden_lamp.tscn")

var _save: SaveGame


func before_test() -> void:
	_save = SaveManager.save
	SaveManager.save = SaveGame.new()


func after_test() -> void:
	SaveManager.save = _save


func spawn() -> GoldenLamp:
	var lamp := SCENE.instantiate() as GoldenLamp
	add_child(auto_free(lamp))
	return lamp


func stamp() -> void:
	SaveManager.save.stamped.append(Lamp.CARD)


func test_the_lamp_glows_again_after_0_6_to_1_4_of_its_mean_wait() -> void:
	assert_float(Lamp.next_wait(100.0, 0.0)).is_equal_approx(60.0, 0.0001)
	assert_float(Lamp.next_wait(100.0, 0.5)).is_equal_approx(100.0, 0.0001)
	assert_float(Lamp.next_wait(100.0, 1.0)).is_equal_approx(140.0, 0.0001)


func test_the_lamp_glows_full_until_its_last_seconds() -> void:
	assert_float(Lamp.glow_at(10.0, 1.0)).is_equal(1.0)
	assert_float(Lamp.glow_at(Lamp.FADE_LEFT, 1.0)).is_equal(1.0)


func test_the_lamp_flickers_but_never_goes_dark_in_its_last_seconds() -> void:
	var dimmed := false
	for i in 100:
		var glow := Lamp.glow_at(Lamp.FADE_LEFT * 0.5, i * 0.013)
		assert_float(glow).is_between(0.1 - 0.0001, 1.0 + 0.0001)
		dimmed = dimmed or glow < 1.0
	assert_bool(dimmed).is_true()


func test_no_lamp_stands_on_the_desk_before_its_card_is_stamped() -> void:
	var lamp := spawn()
	lamp._process(100.0)

	assert_bool(lamp.visible).is_false()
	assert_bool(lamp.glowing).is_false()


func test_a_lamp_already_stamped_is_there_from_the_start() -> void:
	stamp()

	assert_bool(spawn().visible).is_true()


func test_a_newly_stamped_lamp_drops_in_and_first_glows_after_first_wait() -> void:
	var lamp := spawn()
	stamp()
	lamp._process(0.0)

	assert_bool(lamp.visible).is_true()

	lamp._process(Lamp.FIRST_WAIT - 0.1)

	assert_bool(lamp.glowing).is_false()

	lamp._process(0.2)

	assert_bool(lamp.glowing).is_true()


func test_a_glow_lasts_lamp_time_then_the_next_comes_within_the_wait_spread() -> void:
	stamp()
	var save: SaveGame = SaveManager.save
	var lamp := spawn()
	lamp._process(Lamp.FIRST_WAIT + 0.01)
	lamp._process(save.lamp_time - 0.1)

	assert_bool(lamp.glowing).is_true()

	lamp._process(0.2)

	assert_bool(lamp.glowing).is_false()

	lamp._process(save.lamp_every * 0.6 - 0.1)

	assert_bool(lamp.glowing).is_false()

	lamp._process(save.lamp_every * 0.8 + 0.2)

	assert_bool(lamp.glowing).is_true()
