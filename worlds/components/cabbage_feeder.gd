extends Node3D
## Tosses cabbages onto the mat from off-screen (this node's position) until the desk holds
## max_on_desk. Free for now; the price screen's BUY gates it later.

signal tossed(cabbage: Cabbage)

const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const PLAY_AREA_LAYER := 2
const FLIGHT_TIME := 0.85
## Until then a tossed cabbage ignores the screen-edge walls it flies in through.
const ENTER_TIME := 0.65

@export var max_on_desk := 20
@export var interval := 0.25
@export var landing_area := AABB(Vector3(0.0, 0.85, 0.5), Vector3(1.6, 0.0, 0.5))

var _stock: Array[Cabbage] = []
var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	_stock = _stock.filter(func(c: Cabbage) -> bool: return is_instance_valid(c) and not c.sold)
	_cooldown -= delta
	if _cooldown > 0.0 or _stock.size() >= max_on_desk:
		return
	_cooldown = interval
	_toss()


func _toss() -> void:
	var cabbage := CABBAGE.instantiate() as Cabbage
	cabbage.collision_mask &= ~PLAY_AREA_LAYER
	get_parent().add_child(cabbage)
	cabbage.global_position = global_position
	var target := landing_area.position + Vector3(randf(), 0.0, randf()) * landing_area.size
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	cabbage.linear_velocity = ballistic_velocity(global_position, target, FLIGHT_TIME, gravity)
	cabbage.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	_stock.append(cabbage)
	get_tree().create_timer(ENTER_TIME, true, true).timeout.connect(func() -> void:
		if is_instance_valid(cabbage):
			cabbage.collision_mask |= PLAY_AREA_LAYER)
	tossed.emit(cabbage)


static func ballistic_velocity(from: Vector3, to: Vector3, time: float, gravity: Vector3) -> Vector3:
	return (to - from) / time - 0.5 * gravity * time
