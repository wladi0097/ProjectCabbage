class_name MapBuilding
extends Node3D
## Something standing on a map sheet (MapSheet `Things`): a farm token on a farm site or a parcel
## (props/farm_token.tscn), a site token on a farm site abroad (props/site_token.tscn). On the
## country sheet (FarmRegister) it knows its farm site. It has two looks, each a node: `ForSale`,
## and `Owned` once it is company property (cabbage green). A new model keeps this root, its script
## and those two nodes; the sheet only moves and scales the root.

## The farm site it stands on ("K-1": the id in save.farms_owned) and its name; empty off the register.
@export var site := &""
@export var title := ""

## Company property: shows the owned look.
var owned := false:
	set(value):
		owned = value
		$Owned.visible = value
		$ForSale.visible = not value
