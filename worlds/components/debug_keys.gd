extends Node
## Test shortcuts, debug builds only: 1 sells 10 cabbages, 2 sells 100, instantly and whether or
## not there are any. Each pays the chalked price straight onto the tally, and as many findings (research).
## 3 puts STOCK_GIFT cabbages into stock, past the storage cap if need be (loading clamps it back).

const SALES := {KEY_1: 10, KEY_2: 100}
const STOCK_KEY := KEY_3
const STOCK_GIFT := 100


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	press(key.keycode, SaveManager.save)


## What debug key `keycode` does to `save` (nothing for any other key).
static func press(keycode: Key, save: SaveGame) -> void:
	if keycode == STOCK_KEY:
		save.stock += STOCK_GIFT
		print("debug: stock now %d" % save.stock)
	if not SALES.has(keycode):
		return
	var count: int = SALES[keycode]
	save.sold += count
	save.coins += count * save.sale_price
	save.findings += count * save.sale_price
	print("debug: sold %d, coins now %d, findings %d" % [count, save.coins, save.findings])
