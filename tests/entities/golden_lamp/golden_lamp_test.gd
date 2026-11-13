extends GdUnitTestSuite

const Lamp := preload("res://entities/golden_lamp/golden_lamp.gd")
const SCENE := preload("res://entities/golden_lamp/golden_lamp.tscn")

var _save: SaveGame
var _locale: String


func before_test() -> void:
	_save = SaveManager.save
	SaveManager.save = SaveGame.new()
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	SaveManager.save = _save
	TranslationServer.set_locale(_locale)


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


func test_the_lamp_dims_softly_in_its_last_seconds_never_going_dark_or_flickering_fast() -> void:
	var dimmed := false
	var last := Lamp.glow_at(Lamp.FADE_LEFT * 0.5, 0.0)
	for i in 120:  # Two seconds at 60 fps: never dark, never a jump between frames (no strobe).
		var glow := Lamp.glow_at(Lamp.FADE_LEFT * 0.5 - i / 60.0, i / 60.0)
		assert_float(glow).is_between(0.2, 1.0 + 0.0001)
		assert_float(absf(glow - last)).is_less(0.05)
		dimmed = dimmed or glow < 0.9
		last = glow
	assert_bool(dimmed).is_true()
	assert_float(Lamp.PULSE_HZ).is_less(3.0)


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


func test_hovering_the_lamp_explains_it_with_the_current_upgraded_numbers() -> void:
	var save := SaveGame.new()
	save.lamp_every = 90.0
	save.lamp_time = 25.0
	save.lamp_mult = 7.5
	var text := Lamp.hint(save)
	assert_str(text).contains("90 s").contains("25 s").contains("7.5×")


func test_hovering_the_lamp_says_golden_cabbages_are_excluded_until_gold_standard() -> void:
	TranslationServer.set_locale("en")
	var save := SaveGame.new()
	assert_str(Lamp.hint(save)).contains("Golden cabbages excluded.")
	save.tree_bought.append(SaleWindow.GOLD_AGE)
	assert_str(Lamp.hint(save)).not_contains("Golden cabbages excluded.")


func test_the_lamp_has_a_hover_box_for_its_explanation() -> void:
	var lamp: Node = auto_free(load("res://entities/golden_lamp/golden_lamp.tscn").instantiate())
	assert_object(lamp.get_node("Hit/Interactable")).is_not_null()
	assert_int((lamp.get_node("Hit") as StaticBody3D).collision_layer).is_equal(Interactable.HOVER_LAYER)


func test_the_hidden_lamp_does_not_block_clicks_until_its_card_brings_it_in() -> void:
	var lamp := spawn()
	assert_bool((lamp.get_node("Hit/Shape") as CollisionShape3D).disabled).is_true()

	stamp()
	lamp._process(0.0)

	assert_bool((lamp.get_node("Hit/Shape") as CollisionShape3D).disabled).is_false()


func test_the_golden_lamp_sounds_when_the_golden_age_begins() -> void:
	stamp()
	var lamp := spawn()
	var on := lamp.get_node("On") as AudioStreamPlayer3D
	assert_object(on.stream).is_not_null()
	lamp._process(Lamp.FIRST_WAIT - 0.1)

	assert_bool(on.playing).is_false()

	lamp._process(0.2)

	assert_bool(on.playing).is_true()


func test_a_lamp_that_is_already_on_does_not_sound_again() -> void:
	stamp()
	var lamp := spawn()
	var on := lamp.get_node("On") as AudioStreamPlayer3D
	lamp._process(Lamp.FIRST_WAIT + 0.01)
	on.stop()
	lamp._process(1.0)
	lamp._process(1.0)

	assert_bool(lamp.glowing).is_true()
	assert_bool(on.playing).is_false()


func test_a_lamp_loaded_from_a_save_starts_dark_and_silent() -> void:
	stamp()
	var lamp := spawn()
	lamp._process(0.0)

	assert_bool(lamp.glowing).is_false()
	assert_bool((lamp.get_node("On") as AudioStreamPlayer3D).playing).is_false()
