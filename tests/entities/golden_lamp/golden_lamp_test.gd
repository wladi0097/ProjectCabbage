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


const LIGHT_SCENE := preload("res://entities/golden_lamp/research_light.tscn")


func _light() -> GoldenLamp:
	var light := LIGHT_SCENE.instantiate() as GoldenLamp
	add_child(auto_free(light))
	return light


func test_the_research_light_is_the_golden_lamp_with_its_own_card_numbers_and_the_labs_boost() -> void:
	var light := _light()
	assert_bool(light.visible).is_false()  # Before its card.
	assert_str(light.card).is_equal("research_light")
	var save: SaveGame = SaveManager.save
	save.stamped.append("research_light")
	save.lab_lamp_time = 30.0
	light._process(0.0)
	assert_bool(light.visible).is_true()
	light._process(Lamp.FIRST_WAIT + 0.01)
	assert_bool(light.glowing).is_true()
	light._process(29.0)
	assert_bool(light.glowing).is_true()  # lab_lamp_time, not the golden lamp's 20 s.
	light._process(1.1)
	assert_bool(light.glowing).is_false()


func test_while_the_research_light_glows_the_lab_takes_its_multiplier_and_drops_it_after() -> void:
	SaveManager.save.stamped.append("research_light")
	SaveManager.save.lab_lamp_mult = 8.0
	var lab := GDScript.new()  # Stands in for the QaBay: only its boosts are read.
	lab.source_code = "extends Node\nvar boosts := {}\n"
	lab.reload()
	var bay: Node = auto_free(Node.new())
	bay.set_script(lab)
	bay.add_to_group(&"qa_bay")
	add_child(bay)
	var light := _light()
	light._window_boost(SaveManager.save.lab_lamp_mult)
	assert_dict(bay.boosts).is_equal({lab_lamp = 8.0})
	light._window_boost(0.0)
	assert_dict(bay.boosts).is_empty()


func test_hovering_the_research_light_explains_it_with_its_own_numbers_and_golden_cabbages_until_its_node() -> void:
	TranslationServer.set_locale("en")
	var light: GoldenLamp = auto_free(LIGHT_SCENE.instantiate())
	var save := SaveGame.new()
	save.lab_lamp_every = 90.0
	save.lab_lamp_mult = 8.0
	var text := Lamp.hint(save, light.stats, light.hint_text, light.gold_node)
	for part: String in ["research lab", "90 s", "8×", "Golden cabbages excluded."]:
		assert_bool(text.contains(part)).override_failure_message(text).is_true()
	save.tree_bought.append(QaBay.LAB_GOLD)
	assert_str(Lamp.hint(save, light.stats, light.hint_text, light.gold_node)).not_contains("Golden cabbages excluded.")


func test_both_lamps_glowing_tint_the_desk_light_together_and_one_going_out_leaves_the_other() -> void:
	var base := Color(1, 0.86, 0.68)
	var gold := Color(Lamp.GOLD, 0.35)
	var blue := Color(0.35, 0.9, 1, 0.22)
	var both := Lamp.tinted(base, [gold, blue])
	assert_object(both).is_not_equal(Lamp.tinted(base, [gold]))
	assert_object(Lamp.tinted(base, [gold, Color(blue, 0.0)])).is_equal(Lamp.tinted(base, [gold]))
	assert_object(Lamp.tinted(base, [Color(gold, 0.0), Color(blue, 0.0)])).is_equal(base)


func test_the_research_lights_rings_turn_slowly_and_steadily_never_a_blink() -> void:
	var light := _light()
	assert_float(light.spin_speed).is_between(0.05, 1.0)
	assert_float(light.spin_speed * Lamp.SPIN_GLOWING / TAU).is_less(0.5)  # Under half a turn a second while glowing.
	var ring := light.get_node("Model/Spin1") as Node3D
	var was := ring.rotation.y
	light._spin(1.0)
	assert_float(ring.rotation.y - was).is_equal_approx(light.spin_speed, 0.0001)
