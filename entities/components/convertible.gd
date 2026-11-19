class_name Convertible
extends Node
## Makes its parent (a Node3D) a target for the cabbage gun in the chapter 5 ending. It builds its
## own hit box, an Area3D round the parent's meshes on the `ending_target` physics layer: no body
## collides with it and no ray but the gun's (which looks at areas) meets it, so it never gets in the
## hand's way. Hit (convert_at), it converts once:
## - POP: a burst of leaves at the middle, the parent is hidden and stops colliding, and a cabbage
##   sized to it drops where it stood.
## - MATERIAL: the parent stays, and a cabbage-leaf skin spreads over every mesh under it from the
##   hit point (the table, the walls).

signal converted

enum Mode { POP, MATERIAL }

## Physics layer 21, "ending_target" in the project's layer names. CabbageGun's ray looks only here.
const LAYER := 1 << 20
const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const LEAF_BURST := preload("res://entities/cabbage_gun/leaf_burst.tscn")
const LEAF := preload("res://entities/cabbage_gun/cabbage_leaf.tres")
## A plain cabbage drawn on the desk is about this wide (0.18 m mesh at 1.5x).
const CABBAGE_WIDTH := 0.27
## The dropped cabbage is this much of the object's biggest side, within SCALE_RANGE of a plain one.
const CABBAGE_SHARE := 0.7
const SCALE_RANGE := Vector2(0.6, 3.0)
## The dropped cabbage hops up this fast (m/s) as the object pops.
const HOP := 0.6
## It starts this far (m) above the object's box: clear of its colliders (they switch off a frame late)
## and the desk, so physics never shoves it out.
const CLEARANCE := 0.02
## Metres per second the leaf skin spreads (MATERIAL), and its least time.
const RIPPLE_SPEED := 2.5
const RIPPLE_MIN := 0.6

@export var mode := Mode.POP
## POP only: instead of a physics cabbage, a still one (just its mesh: no body, never vanishes) takes
## the object's place, centred where it stood, its width replace_size of the object's biggest side.
@export var replace_static := false
@export var replace_size := 0.5
## Where the leaves and the dropped cabbage go (null: the current scene, else the tree root).
var drop_parent: Node
var is_converted := false
## The hit box (a child of the parent once it is set up).
var body: Area3D


func _ready() -> void:
	var parent := get_parent() as Node3D
	var box := bounds(parent)
	body = Area3D.new()
	body.monitoring = false
	body.name = &"ConvertibleHit"
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.set_meta(&"convertible", self)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size.max(Vector3.ONE * 0.02)
	shape.shape = cube
	shape.position = box.get_center()
	body.add_child(shape)
	parent.add_child.call_deferred(body)


## The box round every mesh under `root` (and root itself), in root's own space.
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_root := root.global_transform.affine_inverse()
	for node: Node in [root] + root.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D):
			continue
		var geometry := node as GeometryInstance3D
		var local := to_root * geometry.global_transform * geometry.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


## How many times a plain cabbage's size the one dropped for an object `size` big (m) is.
static func cabbage_scale(size: Vector3) -> float:
	var side := maxf(size.x, maxf(size.y, size.z))
	return clampf(side * CABBAGE_SHARE / CABBAGE_WIDTH, SCALE_RANGE.x, SCALE_RANGE.y)


## Converted from the middle of its box.
func convert() -> void:
	var parent := get_parent() as Node3D
	convert_at(parent.global_transform * bounds(parent).get_center())


func convert_at(point: Vector3) -> void:
	if is_converted:
		return
	is_converted = true
	_set_shapes_disabled(body, true)
	if mode == Mode.POP:
		_pop()
	else:
		_ripple(point)
	converted.emit()


func _pop() -> void:
	var parent := get_parent() as Node3D
	var box := bounds(parent)
	var centre := parent.global_transform * box.get_center()
	var size := cabbage_scale(box.size * parent.global_basis.get_scale())
	# Leaves and cabbage go to the scene root: under the object's own parent they would vanish or
	# freeze when that parent is converted (hidden, stopped) in turn.
	var world: Node = drop_parent
	if world == null:
		world = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var burst := LEAF_BURST.instantiate() as Node3D
	burst.set(&"size", size)
	world.add_child(burst)
	burst.global_position = centre
	if replace_static:
		_stand_in(world, centre, box.size * parent.global_basis.get_scale())
		parent.visible = false
		_set_shapes_disabled(parent, true)
		return
	var cabbage := CABBAGE.instantiate() as Cabbage
	world.add_child(cabbage)
	cabbage.resize(size)
	var top := (parent.global_transform * box).end.y
	var radius := ((cabbage.get_node(^"Shape") as CollisionShape3D).shape as SphereShape3D).radius
	cabbage.global_position = Vector3(centre.x, top + radius + CLEARANCE, centre.z)
	cabbage.linear_velocity = Vector3.UP * HOP  # The same gentle hop at any size.
	parent.visible = false
	_set_shapes_disabled(parent, true)


## The still cabbage in an object's place (replace_static): the cabbage's own mesh, at `centre`,
## replace_size of the object's biggest side (`size`) wide.
func _stand_in(world: Node, centre: Vector3, size: Vector3) -> MeshInstance3D:
	var source := CABBAGE.instantiate()
	var mesh := (source.get_node(^"Mesh") as MeshInstance3D).duplicate() as MeshInstance3D
	mesh.mesh = Cabbage.MESHES[randi() % Cabbage.MESHES.size()]  # The cabbage picks its own in _ready.
	source.free()
	mesh.name = &"StandInCabbage"
	var side := maxf(size.x, maxf(size.y, size.z))
	var factor := side * replace_size / CABBAGE_WIDTH
	world.add_child(mesh)
	mesh.global_transform = Transform3D(mesh.transform.basis.scaled(Vector3.ONE * factor), centre)
	return mesh


func _ripple(point: Vector3) -> void:
	var parent := get_parent() as Node3D
	var skin := LEAF.duplicate() as ShaderMaterial
	skin.set_shader_parameter(&"origin", point)
	skin.set_shader_parameter(&"radius", 0.0)
	var box := parent.global_transform * bounds(parent)
	var reach := 0.0
	for i in 8:
		reach = maxf(reach, point.distance_to(box.get_endpoint(i)))
	for node: Node in [parent] + parent.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			(node as GeometryInstance3D).material_overlay = skin
	create_tween().tween_property(skin, ^"shader_parameter/radius", reach + 0.2,
			maxf(RIPPLE_MIN, reach / RIPPLE_SPEED)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


static func _set_shapes_disabled(root: Node, disabled: bool) -> void:
	for node: Node in [root] + root.find_children("*", "CollisionShape3D", true, false):
		if node is CollisionShape3D:
			(node as CollisionShape3D).set_deferred(&"disabled", disabled)
