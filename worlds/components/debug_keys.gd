extends Node
## Test shortcuts, debug builds only: 1 sells 10 cabbages, 2 sells 100, instantly and whether or
## not there are any. Each pays the chalked price straight onto the tally.

const SALES := {KEY_1: 10, KEY_2: 100}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not SALES.has(key.keycode):
		return
	var save := SaveManager.save
	var count: int = SALES[key.keycode]
	save.sold += count
	save.coins += count * save.sale_price
	print("debug: sold %d, coins now %d" % [count, save.coins])
