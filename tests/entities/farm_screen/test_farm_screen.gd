extends Node
## Run: Godot --headless --path . res://tests/entities/farm_screen/test_farm_screen.tscn
## The farm's rules: planting uses seeds, squares ripen after grow_time, harvests go into stock,
## upgrades and the machines.

var failed := false


func _ready() -> void:
	var save := SaveGame.new()
	FarmScreen.ensure(save)
	_check(save.farm_plots == FarmScreen.START_PLOTS and save.farm_growth.size() == FarmScreen.START_PLOTS
			and save.farm_seeds == FarmScreen.START_SEEDS, "the uncle's farm: 12 squares, 10 seeds")
	FarmScreen.ensure(save)
	_check(save.farm_seeds == FarmScreen.START_SEEDS, "seeds handed out once")
	_check(FarmScreen.plant(save, 0) and save.farm_seeds == FarmScreen.START_SEEDS - 1 and not FarmScreen.plant(save, 0), "planting uses a seed, once")
	FarmScreen.tick(save, FarmScreen.GROW_TIME - 1.0)
	_check(FarmScreen.harvest(save, 0) == 0, "not ripe yet")
	FarmScreen.tick(save, 5.0)
	var stock := save.stock
	_check(FarmScreen.harvest(save, 0) == FarmScreen.YIELD and save.stock == stock + FarmScreen.YIELD
			and save.farm_growth[0] == FarmScreen.EMPTY and save.farm_harvests == 1, "a ripe square gives 3 into stock")
	save.farm_seeds = 0
	_check(not FarmScreen.plant(save, 1), "no seeds, no planting")
	# Upgrades: plots get dearer, the machines plant and harvest.
	save.coins = 100000
	var first := FarmScreen.plot_price(save)
	_check(FarmScreen.buy("plot", save) and save.farm_plots == FarmScreen.START_PLOTS + 1 and save.farm_growth.size() == save.farm_plots
			and FarmScreen.plot_price(save) > first, "a plot opens a square and gets dearer")
	_check(FarmScreen.buy("fertiliser", save) and FarmScreen.grow_time(save) == 20.0 and not FarmScreen.buy("fertiliser", save), "fertiliser once")
	_check(FarmScreen.buy("irrigation", save) and FarmScreen.yield_of(save) == FarmScreen.YIELD + 1, "irrigation adds one")
	_check(FarmScreen.buy("seed_contract", save) and FarmScreen.seed_price(0, save) == FarmScreen.SEED_PACKS[0][1] / 2, "seed contract halves seeds")
	FarmScreen.buy("farm_hand", save)
	FarmScreen.buy("tractor", save)
	save.farm_seeds = 1
	FarmScreen.auto(save)
	_check(save.farm_seeds == 0 and save.farm_growth.has(0.0), "the farm hand plants")
	FarmScreen.tick(save, 30.0)
	stock = save.stock
	FarmScreen.auto(save)
	_check(save.stock == stock + FarmScreen.yield_of(save), "the tractor harvests")
	var poor := SaveGame.new()
	FarmScreen.ensure(poor)
	_check(not FarmScreen.buy("tractor", poor), "no money, no tractor")
	_check(FarmScreen._thousands(1234567) == "1,234,567" and FarmScreen._thousands(12) == "12", "thousands")
	print("farm screen tests failed" if failed else "farm screen tests passed")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		push_error(what)
