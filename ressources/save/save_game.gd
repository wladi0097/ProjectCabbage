class_name SaveGame
extends Resource

@export var version := ""
@export var created := 0
@export var last_played := 0
@export var play_seconds := 0
@export var coins := 0
## Unsold cabbages, the ones on the mat included. The game starts with 10 to sell.
@export var stock := 10
@export var sold := 0
## Cabbages grabbed in mid-air as they fly off the chute.
@export var catches := 0
@export var buy_unlocked := false
## Coins per cabbage, chalked on the price slate. Higher sells less often (see PriceSlate.demand).
@export var sale_price := 2
## The price slate drops onto the desk the first time the coins reach PriceSlate.UNLOCK_COINS.
@export var slate_unlocked := false
## Hidden demand: marketing multiplies the full-sale price (upgrades raise it), the mood drifts it
## each minute within PriceSlate.MOOD_RANGE.
@export var marketing := 1.0
@export var demand_mood := 1.0
## Upgradeable: how many cabbages may sit on the mat, seconds between dispenses, cabbages per pack.
@export var desk_capacity := 1
@export var dispense_interval := 1.0
@export var pack_size := 10
## Pack price as a multiple of the base price (0.5..1.5), the buy pressure still pushing it up,
## and the last factors for the ticker's sparkline.
@export var price_factor := 1.0
@export var price_pressure := 0.0
@export var price_history := PackedFloat32Array()
