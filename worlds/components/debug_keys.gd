extends Node
## Test shortcuts, debug builds only: 1 sells 10 cabbages, 2 sells 100, instantly and whether or
## not there are any. Each pays the chalked price straight onto the tally, and as many findings (research).
## 3 puts STOCK_GIFT cabbages into stock, past the storage cap if need be (loading clamps it back).
## 4 takes the camera to chapter 3's map table and back (MapTable.toggle_view; nothing before
## chapter 3): the shortcut for the FieldLine's handset.
## 5 gives the company one more farm for free (save.farms_owned, up to GameEvents.FARMS), the home
## sites not yet bought on the map first: the first brings the "first_farm" paper, the fifth lets
## HOME PORTFOLIO REVIEW be stamped (its stamp brings "no_more_sellers"), the eighth (every home site) "home_country"; then the farms abroad, nearest
## country first (WorldRegister.next_farm: a country turns green on the world sheet with its last).

const SALES := {KEY_1: 10, KEY_2: 100}
const STOCK_KEY := KEY_3
const STOCK_GIFT := 100
const MAP_KEY := KEY_4
const FARM_KEY := KEY_5
const Events := preload("res://globalScripts/game_events.gd")
const WorldRegister := preload("res://entities/map_table/world_register.gd")


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	press(key.keycode, SaveManager.save)
	if key.keycode == MAP_KEY:
		get_tree().call_group(&"map_table", &"toggle_view")


## What debug key `keycode` does to `save` (nothing for any other key).
static func press(keycode: Key, save: SaveGame) -> void:
	if keycode == STOCK_KEY:
		save.stock += STOCK_GIFT
		print("debug: stock now %d" % save.stock)
	if keycode == FARM_KEY and save.farms_owned.size() < Events.FARMS and WorldRegister.next_farm(save) != "":
		# The home sites' real ids first (K-1..K-8, the ones not bought on the map yet), then the
		# farms abroad, nearest country first ("veldmark-1").
		save.farms_owned.append(WorldRegister.next_farm(save))
		print("debug: farms owned %d" % save.farms_owned.size())
	if not SALES.has(keycode):
		return
	var count: int = SALES[keycode]
	save.sold += count
	save.earn(&"coins", count * save.sale_price)  # Under the limits, like any income.
	save.earn(&"findings", count * save.sale_price)
	print("debug: sold %d, coins now %d, findings %d" % [count, save.coins, save.findings])
