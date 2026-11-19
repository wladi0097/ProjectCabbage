extends GdUnitTestSuite

var _save: SaveGame
var _world: Node3D
## Where the tests' pops drop their leaves and cabbages: outside _world, whatever the current scene is.
var _drops: Node3D


func before_test() -> void:
	_save = SaveManager.save
	SaveManager.save = SaveGame.new()
	_world = auto_free(Node3D.new())
	add_child(_world)
	_drops = auto_free(Node3D.new())
	add_child(_drops)


func after_test() -> void:
	SaveManager.save = _save


## A thing with a 0.6 x 0.4 x 0.6 box mesh (and a solid body) at `at`, shootable in `mode`.
func thing(mode: Convertible.Mode, at := Vector3(1.0, 0.5, -2.0), solid := true) -> Convertible:
	var root := Node3D.new()
	root.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.4, 0.6)
	mesh.mesh = box
	root.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		root.add_child(body)
	var convertible := Convertible.new()
	convertible.mode = mode
	convertible.drop_parent = _drops
	root.add_child(convertible)
	_world.add_child(root)
	return convertible


func cabbages() -> Array[Node]:
	return _drops.get_children().filter(func(n: Node) -> bool: return n is Cabbage and not n.is_queued_for_deletion())


func bursts() -> Array[Node]:
	return _drops.get_children().filter(func(n: Node) -> bool: return n is CPUParticles3D and not n.is_queued_for_deletion())


func test_the_hit_box_covers_the_parents_meshes() -> void:
	var convertible := thing(Convertible.Mode.POP)
	assert_vector(Convertible.bounds(convertible.get_parent()).size).is_equal_approx(Vector3(0.6, 0.4, 0.6), Vector3.ONE * 0.001)
	await await_idle_frame()
	assert_object(convertible.body.get_parent()).is_same(convertible.get_parent())
	assert_int(convertible.body.collision_layer).is_equal(Convertible.LAYER)


func test_only_the_guns_ray_meets_the_hit_box() -> void:
	thing(Convertible.Mode.POP, Vector3(0.0, 0.0, -3.0), false)
	await await_idle_frame()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := _world.get_world_3d().direct_space_state
	var plain := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0.0, 0.0, -10.0))
	assert_bool(space.intersect_ray(plain).is_empty()).is_true()
	var gun := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0.0, 0.0, -10.0), Convertible.LAYER)
	gun.collide_with_areas = true
	assert_bool(space.intersect_ray(gun).is_empty()).is_false()


func test_a_popped_object_leaves_a_cabbage_just_above_where_it_stood() -> void:
	var convertible := thing(Convertible.Mode.POP)
	convertible.convert()
	var dropped := cabbages()
	assert_int(dropped.size()).is_equal(1)
	var at := (dropped[0] as Cabbage).global_position
	assert_float(Vector2(at.x, at.z).distance_to(Vector2(1.0, -2.0))).is_less(0.01)
	# Clear of the object's box (its top at 0.7), so nothing shoves it out.
	var radius := (((dropped[0] as Cabbage).get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius
	assert_float(at.y - radius).is_greater(0.7)


func test_a_popped_object_is_hidden_and_stops_colliding() -> void:
	var convertible := thing(Convertible.Mode.POP)
	var parent := convertible.get_parent() as Node3D
	convertible.convert()
	await await_idle_frame()
	assert_bool(parent.visible).is_false()
	for shape in parent.find_children("*", "CollisionShape3D", true, false):
		assert_bool((shape as CollisionShape3D).disabled).is_true()


func test_a_bigger_object_drops_a_bigger_cabbage() -> void:
	var small := Convertible.cabbage_scale(Vector3(0.3, 0.2, 0.3))
	var big := Convertible.cabbage_scale(Vector3(1.0, 0.8, 0.6))
	assert_float(big).is_greater(small * 1.25)
	assert_float(Convertible.cabbage_scale(Vector3.ONE * 50.0)).is_equal(Convertible.SCALE_RANGE.y)
	var convertible := thing(Convertible.Mode.POP)
	convertible.convert()
	var radius := (((cabbages()[0] as Node).get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius
	var size := Convertible.cabbage_scale(Vector3(0.6, 0.4, 0.6))
	assert_float(radius).is_between(0.11 * size * (1.0 - Cabbage.SIZE_SPREAD), 0.11 * size * (1.0 + Cabbage.SIZE_SPREAD))


func test_an_object_converts_only_once() -> void:
	var convertible := thing(Convertible.Mode.POP)
	var count := [0]
	convertible.converted.connect(func() -> void: count[0] += 1)
	convertible.convert()
	convertible.convert()
	assert_int(count[0]).is_equal(1)
	assert_bool(convertible.is_converted).is_true()
	assert_int(cabbages().size()).is_equal(1)


func test_a_material_object_stays_and_grows_a_leaf_skin_from_the_hit() -> void:
	var convertible := thing(Convertible.Mode.MATERIAL)
	var parent := convertible.get_parent() as Node3D
	var hit := Vector3(1.2, 0.7, -2.0)
	convertible.convert_at(hit)
	assert_bool(parent.visible).is_true()
	assert_int(cabbages().size()).is_equal(0)
	var skin := (parent.get_child(0) as MeshInstance3D).material_overlay as ShaderMaterial
	assert_object(skin).is_not_null()
	assert_vector(skin.get_shader_parameter(&"origin") as Vector3).is_equal(hit)
	await await_millis(800)
	assert_float(skin.get_shader_parameter(&"radius") as float).is_greater(0.5)


func test_a_pop_leaves_nothing_of_its_leaves_after_a_second() -> void:
	var convertible := thing(Convertible.Mode.POP)
	convertible.convert()
	assert_int(bursts().size()).is_equal(1)
	await await_millis(1300)
	assert_int(bursts().size()).is_equal(0)


func test_the_leaves_and_cabbage_carry_on_when_the_objects_holder_is_stopped_and_hidden() -> void:
	var convertible := thing(Convertible.Mode.POP)
	convertible.convert()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_world.visible = false
	assert_bool((cabbages()[0] as Node3D).is_visible_in_tree()).is_true()
	await await_millis(1300)
	assert_int(bursts().size()).is_equal(0)


func test_a_dropped_cabbage_only_hops_gently_whatever_its_size() -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(10.0, 0.2, 10.0)
	shape.shape = slab
	floor_body.add_child(shape)
	floor_body.position = Vector3(1.0, 0.2, -2.0)  # Its top at 0.3, under the thing.
	_world.add_child(floor_body)
	var big := thing(Convertible.Mode.POP)
	big.get_parent().scale = Vector3.ONE * 3.0  # A big object: a big cabbage.
	await get_tree().physics_frame
	big.convert()
	var cabbage := cabbages()[0] as Cabbage
	var fastest_sideways := 0.0
	var fastest := 0.0
	for i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(cabbage):
			break
		var v := cabbage.linear_velocity
		fastest_sideways = maxf(fastest_sideways, Vector2(v.x, v.z).length())
		fastest = maxf(fastest, v.length())
	assert_float(fastest_sideways).is_less(0.5)
	assert_float(fastest).is_less(5.0)


func test_a_static_stand_in_takes_the_objects_place_half_its_size_without_physics_resting_where_it_stood() -> void:
	var convertible := thing(Convertible.Mode.POP)
	convertible.replace_static = true
	convertible.convert()
	assert_array(cabbages()).is_empty()  # No physics cabbage.
	var stand_in := _drops.get_node_or_null("StandInCabbage") as MeshInstance3D
	assert_object(stand_in).is_not_null()
	var box := stand_in.global_transform * stand_in.get_aabb()
	assert_float(Vector2(box.get_center().x, box.get_center().z).distance_to(Vector2(1.0, -2.0))).is_less(0.01)
	assert_float(box.position.y).is_equal_approx(0.3, 0.01)  # On the bottom of the object's box (0.5 - 0.2): not floating.
	var width := box.size.x
	assert_float(width).is_equal_approx(0.6 * convertible.replace_size, 0.06)  # Half the 0.6 m object.
	assert_bool(convertible.get_parent().visible).is_false()
