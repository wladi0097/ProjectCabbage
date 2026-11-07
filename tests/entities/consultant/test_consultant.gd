extends Node
## Run: Godot --headless --path . res://tests/entities/consultant/test_consultant.tscn

const Con := preload("res://entities/consultant/consultant.gd")
const Slate := preload("res://entities/price_slate/price_slate.gd")


func _ready() -> void:
	var failed := false
	var save := SaveGame.new()
	save.marketing = 1.5  # textbook full-sale price $4.50
	save.demand_mood = 1.2  # really $5.40
	# $5 sells 81% at $4.50 (nearer 90% than $4's 100%); with the mood, $6 sells 81% at $5.40.
	if Con.target_price(save, 0) != 5:
		failed = true
		push_error("skill 0 should keep acceptance nearest 90%%: got %d" % Con.target_price(save, 0))
	if Con.target_price(save, 1) != 6:
		failed = true
		push_error("skill 1 should read the mood: got %d" % Con.target_price(save, 1))
	save.marketing = 3.0  # $9 full sale: no whole price is nearer 90% than the one aimed at
	var aim := Con.target_price(save, 0)
	for price in range(Slate.MIN_PRICE, Slate.max_price(save.marketing) + 1):
		if absf(Slate.demand(price, 9.0) - 0.9) < absf(Slate.demand(aim, 9.0) - 0.9) - 0.0001:
			failed = true
			push_error("skill 0: $%d is nearer 90%% than $%d" % [price, aim])
	save.marketing = 1.5
	var smart := Con.target_price(save, 2)
	var ref := Slate.ref_price(save.marketing, save.demand_mood)
	var cost := SupplyConsole.pack_price(save.price_factor, save.pack_size) / float(save.pack_size)
	for price in range(Slate.MIN_PRICE, Slate.max_price(save.marketing) + 1):
		if Con.income(price, ref, cost) > Con.income(smart, ref, cost) + 0.001:
			failed = true
			push_error("skill 2 should earn the most per unit: $%d beats $%d" % [price, smart])
	# Throttle: a step up per starved decision, capped at THROTTLE × ref, a step back when one waits.
	if Con.throttle(0, false, 5, 5.0) != 1 or Con.throttle(3, false, 5, 5.0) != 3 or Con.throttle(2, true, 5, 5.0) != 1 \
			or Con.throttle(0, true, 5, 5.0) != 0:
		failed = true
		push_error("the throttle should climb to ceil(ref × THROTTLE) - base and step back down")
	save.marketing = 0.2
	if Con.target_price(save, 0) != Slate.MIN_PRICE:
		failed = true
		push_error("the target never drops under the slate's minimum")
	print("consultant tests failed" if failed else "consultant tests passed")
	get_tree().quit(1 if failed else 0)
