class_name Greening
extends CanvasLayer
## The chapter 5 colour flip: a screen shader over the 3D view (below every UI layer) that pushes
## saturation up and tints toward cabbage green as the amount goes 0 -> 1. At 0 it is switched off.

## How green it is now (0..1).
var amount := 0.0

@onready var _screen: ColorRect = $Screen


func _ready() -> void:
	set_amount(amount)


func set_amount(t: float) -> void:
	amount = clampf(t, 0.0, 1.0)
	if not is_node_ready():
		return
	_screen.visible = amount > 0.0
	(_screen.material as ShaderMaterial).set_shader_parameter(&"amount", amount)
