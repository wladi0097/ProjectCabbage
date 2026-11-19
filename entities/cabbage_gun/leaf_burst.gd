extends CPUParticles3D
## The cabbage gun's pop: small curled cabbage leaves (and the pop sound) fly out where an object
## was, shrink and fade, and are gone within a second; then it frees itself. It runs even under a
## stopped node (process_mode Always), so it never freezes in mid-air as slabs.

## Linear size against a cabbage-sized object (Convertible.cabbage_scale): a bigger object throws
## the leaves wider and a few more of them, never bigger leaves.
var size := 1.0


func _ready() -> void:
	emission_sphere_radius *= size
	initial_velocity_min *= sqrt(size)
	initial_velocity_max *= sqrt(size)
	amount = roundi(amount * clampf(size, 1.0, 2.0))
	emitting = true
	$Pop.play()
	finished.connect(queue_free)
