class_name OfferBundle
extends Node3D
## One bundle on the negotiation letter (NegotiationLetter): a small cabbage standing for `units`
## cabbages from stock, its count on its leaves the way a condensed cabbage shows it
## (Cabbage.count_texture, upright to the camera), or for a bribe (`coins`) a stack of coins. Only a
## picture on the paper: it is no stock and no Cabbage, and nothing is taken until the offer is sent.

## The number sits this far (m) toward the camera from the cabbage's centre (Cabbage.NUMBER_LIFT at
## this cabbage's size).
const NUMBER_LIFT := 0.03

## A stack of coins instead of a cabbage (set before it enters the tree).
@export var coins := false

@onready var _cabbage: MeshInstance3D = $Cabbage
@onready var _stack: Node3D = $Coins
@onready var _number: Decal = $Number


func _ready() -> void:
	_cabbage.mesh = Cabbage.MESHES[randi() % Cabbage.MESHES.size()]
	_cabbage.rotate_y(randf() * TAU)
	_stack.rotate_y(randf() * TAU)
	_number.visible = false
	restyle()


## A cabbage, or a stack of coins (`coins`).
func restyle() -> void:
	_cabbage.visible = not coins
	_stack.visible = coins


## Shows `count` on its leaves (a cabbage of 2 or more; a coin stack shows none).
func label(count: int) -> void:
	_number.visible = not coins and count > 1
	set_process(_number.visible)
	if _number.visible:
		_number.texture_albedo = Cabbage.count_texture(count)
		_number.texture_emission = _number.texture_albedo
		_number.modulate = Cabbage.count_colour(count)


## The number faces the camera, just in front of the cabbage, every frame (it moves with the paper).
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var level := Basis.IDENTITY if camera == null else Cabbage.number_basis(camera.global_basis)
	_number.global_transform = Transform3D(level, _cabbage.global_position + level.y * NUMBER_LIFT)
