extends GdUnitTestSuite


func test_only_objects_that_carry_an_interactable_can_be_hovered() -> void:
	assert_object(Interactable.of(null)).is_null()
	var plain: StaticBody3D = auto_free(StaticBody3D.new())
	add_child(plain)
	assert_object(Interactable.of(plain)).is_null()


func test_an_enabled_visible_object_is_found_by_the_hand() -> void:
	var body := _grabbable()
	assert_object(Interactable.of(body)).is_not_null()


func test_a_disabled_object_does_not_catch_the_hand() -> void:
	var body := _grabbable()
	Interactable.of(body).enabled = false
	assert_object(Interactable.of(body)).is_null()


func test_an_object_hidden_off_the_desk_does_not_catch_the_hand() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var body := _grabbable(holder)
	holder.visible = false
	assert_object(Interactable.of(body)).is_null()


func test_a_hover_box_shows_its_text_and_collides_with_nothing() -> void:
	var display: Node3D = auto_free(Node3D.new())
	add_child(display)
	var hover := Interactable.hover_box(display, AABB(Vector3(0.1, 0.0, 0.0), Vector3(0.2, 0.1, 0.4)), "Units sold")
	var body := hover.get_parent() as StaticBody3D
	var shape := body.get_child(0) as CollisionShape3D

	assert_object(Interactable.of(body)).is_same(hover)
	assert_str(hover.tooltip).is_equal("Units sold")
	assert_int(body.collision_layer).is_equal(Interactable.HOVER_LAYER)
	assert_int(body.collision_mask).is_equal(0)
	assert_vector((shape.shape as BoxShape3D).size).is_equal(Vector3(0.2, 0.1, 0.4))
	assert_vector(shape.position).is_equal_approx(Vector3(0.2, 0.05, 0.2), Vector3.ONE * 0.0001)


func _grabbable(parent: Node = self) -> StaticBody3D:
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.add_child(Interactable.new())
	parent.add_child(body)
	return body
