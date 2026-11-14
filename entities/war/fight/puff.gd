extends CPUParticles3D
## A one-shot dust puff on the war sheet (a splash, a blast, a building going down): frees itself.


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
