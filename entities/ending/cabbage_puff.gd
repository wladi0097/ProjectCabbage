class_name CabbagePuff
extends Convertible
## A cabbage lying around in the ending (on the mat, or one a pop dropped): the gun's ray meets it
## like any target (the hit box Convertible builds), and shot it bursts in the same leaves as a shot
## object, sized to it, and is gone: no new cabbage, no item counted (it is in no step's group). So
## cabbages never block a shot.



func convert_at(_point: Vector3) -> void:
	if is_converted:
		return
	is_converted = true
	var cabbage := get_parent() as Node3D
	var burst := LEAF_BURST.instantiate() as Node3D
	burst.set(&"size", cabbage_scale(bounds(cabbage).size * cabbage.global_basis.get_scale()))
	var world: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world.add_child(burst)
	burst.global_position = cabbage.global_position
	converted.emit()
	cabbage.queue_free()
