extends Node3D
## A mortar shell coming down on the war sheet. Built at radius 1: FightView scales it to the
## splash radius, so it covers exactly where the splash hurts. A graphite shock ring runs out to the
## edge, a pencil circle marks the edge a moment, paper dust rises over the whole disc, graphite
## bits fly out to the rim and a smudge stays a while. It starts as it enters and frees itself.

## The edge of every part, at scale 1 (Ring's and Edge's outer radius, Dust's disc).
const RADIUS := 1.0
const RING_FROM := 0.12
const RING_TIME := 0.3
const EDGE_HOLD := 0.45
const EDGE_FADE := 0.6
const SMUDGE_HOLD := 1.6
const SMUDGE_FADE := 1.4

@onready var _ring: MeshInstance3D = $Ring
@onready var _edge: MeshInstance3D = $Edge
@onready var _smudge: MeshInstance3D = $Smudge


func _ready() -> void:
	($Dust as CPUParticles3D).emitting = true
	($Bits as CPUParticles3D).emitting = true
	var flat := _ring.scale.y
	_ring.scale = Vector3(RING_FROM, flat, RING_FROM)
	var tween := create_tween().set_parallel()
	tween.tween_property(_ring, "scale", Vector3(1.0, flat, 1.0), RING_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "transparency", 1.0, RING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_edge, "transparency", 1.0, EDGE_FADE).set_delay(EDGE_HOLD)
	tween.tween_property(_smudge, "transparency", 1.0, SMUDGE_FADE).set_delay(SMUDGE_HOLD)
	tween.chain().tween_callback(queue_free)
