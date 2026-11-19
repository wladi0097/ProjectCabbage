extends GdUnitTestSuite

const SCENE := preload("res://entities/cabbage_gun/greening.tscn")


func spawn() -> Greening:
	var greening := SCENE.instantiate() as Greening
	add_child(auto_free(greening))
	return greening


func shown(greening: Greening) -> float:
	var screen := greening.get_node("Screen") as ColorRect
	return (screen.material as ShaderMaterial).get_shader_parameter(&"amount") if screen.visible else 0.0


func test_no_greening_leaves_the_screen_untouched() -> void:
	var greening := spawn()
	greening.set_amount(0.0)
	assert_bool((greening.get_node("Screen") as ColorRect).visible).is_false()


func test_greening_can_be_turned_back_to_zero() -> void:
	var greening := spawn()
	greening.set_amount(0.7)
	assert_float(shown(greening)).is_equal_approx(0.7, 0.001)
	greening.set_amount(0.0)
	assert_float(shown(greening)).is_equal(0.0)


func test_greening_never_goes_past_full() -> void:
	var greening := spawn()
	greening.set_amount(3.0)
	assert_float(greening.amount).is_equal(1.0)
