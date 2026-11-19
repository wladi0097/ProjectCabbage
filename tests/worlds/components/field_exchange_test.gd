extends GdUnitTestSuite

const Exchange := preload("res://worlds/components/field_exchange.gd")
const DESK := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))
## Long enough for the handset to be fully up.
const LIFTED := FieldLine.SWING_LAG + FieldLine.SWING_TIME + 0.2

var _real_save: SaveGame
var _line: FieldLine
var _map: MapTable
var _exchange: Node


func before_test() -> void:
	_real_save = SaveManager.save
	FarmTv.away = false
	var camera := Camera3D.new()
	camera.transform = DESK
	add_child(auto_free(camera))
	camera.make_current()


func after_test() -> void:
	FarmRegister.lamp_held = false
	SaveManager.save = _real_save
	FarmTv.away = false
	BossReport.up = false


## The desk's corner as the world scene wires it: the machine, the map table, and the exchange
## between them, for a save with `stamped` cards and `farms` owned (or `loaded`, as it is).
func _desk(stamped: Array, farms: Array = [], loaded: SaveGame = null) -> void:
	var save := loaded if loaded != null else SaveGame.new()
	if loaded == null:
		save.stamped = PackedStringArray(stamped)
		save.farms_owned = PackedStringArray(farms)
	SaveManager.save = save
	_line = auto_free(load("res://entities/field_line/field_line.tscn").instantiate())
	_map = auto_free(load("res://entities/map_table/map_table.tscn").instantiate())
	_exchange = auto_free(Exchange.new())
	_exchange.line = _line
	_exchange.map = _map
	add_child(_line)
	add_child(_map)
	add_child(_exchange)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_the_field_line_is_not_on_the_desk_before_the_market_intelligence_card() -> void:
	_desk(["consolidation"])
	assert_bool(_line.visible).is_false()
	assert_float(_line.position.y).is_greater(5.0)  # Out of the hand's reach.
	_exchange._process(0.1)
	assert_bool(_line.visible).is_false()


func test_stamping_market_intelligence_drops_the_field_line_in_once_the_console_is_lifted_away() -> void:
	_desk(["consolidation"])
	SaveManager.save.stamped.append("market_intelligence")
	_exchange._process(0.0)
	assert_bool(_line.visible).is_false()  # The console is still going up.
	await _wait(SupplyConsole.LIFT_TIME + 0.1)
	assert_bool(_line.visible).is_true()
	assert_float(_line.position.y).is_greater(0.5)  # Falling.
	await _wait(FieldLine.DROP_TIME + 0.1)
	assert_float(_line.position.y).is_equal_approx(0.0, 0.001)
	assert_str((_line.get_node("Count") as Label3D).text).is_equal("0/24")


func test_a_loaded_save_with_the_card_finds_the_field_line_standing_in_place() -> void:
	_desk(["consolidation", "market_intelligence"])
	assert_bool(_line.visible).is_true()
	assert_float(_line.position.y).is_equal(0.0)
	assert_str((_line.get_node("Count") as Label3D).text).is_equal("0/24")


func test_the_field_line_shows_how_many_of_the_24_farms_are_owned_and_follows_the_count() -> void:
	_desk(["consolidation", "market_intelligence"])
	SaveManager.save.farms_owned = PackedStringArray(["K-1", "K-2", "K-3"])
	_exchange._process(0.0)
	assert_str((_line.get_node("Count") as Label3D).text).is_equal("3/24")
	await _wait(FieldLine.RELAY_STEP * 4)
	assert_int(_line.lit()).is_equal(3)
	assert_int(Exchange.Events.FARMS).is_equal(FieldLine.LAMPS)


func test_a_farm_bought_at_the_map_gets_its_lamp_only_when_its_moment_there_has_played() -> void:
	_desk(["consolidation", "market_intelligence"])
	SaveManager.save.coins = 1000000
	SaveManager.save.storage_cap = 5000
	SaveManager.save.stock = 5000
	var country := _map.sheet_of(&"kohlmark") as FarmRegister
	country.open = 1.0
	country.press(&"K-1")
	country.press(FarmRegister.STAMP)
	assert_int(SaveManager.save.farms_owned.size()).is_equal(1)
	_exchange._process(0.0)
	assert_str((_line.get_node("Count") as Label3D).text).is_equal("0/24")  # The stamp is still falling.
	country._dealing.custom_step(FarmRegister.STAMP_DROP_TIME + FarmRegister.HIT_PAUSE + FarmRegister.LAMP_AFTER + 0.01)
	_exchange._process(0.0)
	assert_str((_line.get_node("Count") as Label3D).text).is_equal("1/24")
	await _wait(FieldLine.RELAY_STEP * 2)
	assert_int(_line.lit()).is_equal(1)  # Its relay clicks as it lights: heard from the map.
	country._dealing.custom_step(10.0)
	assert_bool(FarmRegister.lamp_held).is_false()


func test_a_loaded_save_lights_the_lamps_of_its_farms_at_once() -> void:
	_desk(["consolidation", "market_intelligence"], ["K-1", "K-2", "K-3", "K-4", "K-5"])
	assert_int(_line.lit()).is_equal(5)


func test_lifting_the_handset_takes_the_camera_to_the_map_and_coming_home_hangs_it_up() -> void:
	_desk(["consolidation", "market_intelligence"])
	_line.lift()
	await _wait(LIFTED)
	assert_bool(_map.is_away()).is_true()
	_exchange._process(0.0)
	assert_bool(_line.is_open()).is_true()  # At the map: the line stays open.
	_map._pan_tween.custom_step(10.0)
	_map.back_to_desk()  # However the player returns: the plate, Esc and the debug key all end here.
	_exchange._process(0.0)
	assert_bool(_line.is_open()).is_true()  # Still gliding home.
	_map._pan_tween.custom_step(10.0)
	_exchange._process(0.0)
	assert_bool(_line.is_open()).is_false()


func test_a_handset_lifted_while_the_farm_tv_has_the_camera_is_hung_up_again() -> void:
	_desk(["consolidation", "market_intelligence"])
	FarmTv.away = true
	_line.lift()
	await _wait(LIFTED)
	assert_bool(_map.is_away()).is_false()
	_exchange._process(0.0)
	assert_bool(_line.is_open()).is_false()


func test_the_handset_rings_until_the_line_is_first_answered_and_never_again_after_a_reload() -> void:
	_desk(["consolidation", "market_intelligence"])
	assert_bool(_line.ringing).is_true()
	_line.lift()
	assert_bool(_line.ringing).is_false()
	await _wait(LIFTED)
	assert_bool(SaveManager.save.field_line_answered).is_true()
	_desk(["consolidation", "market_intelligence"], [], SaveManager.save)  # The answered save, reloaded.
	assert_bool(_line.ringing).is_false()


func test_the_world_scene_wires_the_field_line_and_the_map_table_to_the_exchange_on_the_consoles_spot() -> void:
	var state := (load("res://worlds/MainStoryWorld.tscn") as PackedScene).get_state()
	var at := {}
	var wired := {}
	for i in state.get_node_count():
		var node := str(state.get_node_name(i))
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"transform":
				at[node] = state.get_node_property_value(i, p)
			if node == "FieldExchange":
				wired[str(state.get_node_property_name(i, p))] = state.get_node_property_value(i, p)
	assert_bool(at.has("FieldLine")).is_true()
	assert_that((at["FieldLine"] as Transform3D).origin).is_equal((at["SupplyConsole"] as Transform3D).origin)
	assert_that(wired.get("line")).is_equal(NodePath("../FieldLine"))
	assert_that(wired.get("map")).is_equal(NodePath("../MapTable"))


func test_the_field_line_count_turns_the_readouts_green_once_print_larger_numbers_is_stamped() -> void:
	_desk(["market_intelligence"])
	_exchange._process(0.0)
	assert_bool(_line.digital).is_false()
	SaveManager.save.stamped.append(DigitalReadout.CARD)
	_exchange._process(0.0)
	assert_bool(_line.digital).is_true()
