extends Node3D
## One of the developer's earlier games, framed on the back wall. Decoration only.

@export var cover: Material
@export var plate := ""

@onready var _cover: MeshInstance3D = $Model/Cover
@onready var _plate: Label3D = $Plate


func _ready() -> void:
	_cover.material_override = cover
	_plate.text = plate
