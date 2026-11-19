extends GdUnitTestSuite

const SCENE := preload("res://entities/ending/ending.tscn")
const WORLD := "res://worlds/MainStoryWorld.tscn"
const WarSheetScript := preload("res://entities/map_table/war_sheet.gd")


## Stands in for CabbageGun: turn_to_player waits until the test lets it face the player.
class FakeGun extends Node3D:
	signal fired(hit: Node)
	signal turned
	var armed := false
	var raised := false
	var crosshair := false
	var turning := false

	func raise() -> void:
		raised = true

	func set_crosshair(on: bool) -> void:
		crosshair = on

	func turn_to_player(_seconds: float) -> void:
		turning = true
		await turned
		turning = false

	func shoot(hit: Node = null) -> void:
		if not armed:
			return
		if hit != null:
			hit.convert()
		fired.emit(hit)


## Stands in for BossCard: cards go at once, the rest is remembered.
class FakeCards extends Node:
	var shown: Array[String] = []
	var ticker := ""
	var remaining := -1
	var prompt := false
	var hum := 0.0
	var beating := false

	func show_card(text: String, _level: int, _voice: int) -> void:
		shown.append(text)

	func show_prompt(on: bool) -> void:
		prompt = on

	func set_ticker(text: String) -> void:
		ticker = text

	func set_remaining(n: int) -> void:
		remaining = n

	func set_hum(level: float) -> void:
		hum = level

	func heartbeat(on: bool) -> void:
		beating = on


class FakeEnd extends Node:
	signal scroll_started
	var played := false
	## The hum when the black came, and the cards it is read from.
	var hum_under_black := -1.0
	var cards: Node
	## Whether the chapter select was unlocked by the time the card started (null: no chapter select yet).
	var unlocked_at_start: Variant = null

	func play() -> void:
		played = true
		hum_under_black = cards.hum
		scroll_started.emit()
		if ResourceLoader.exists(Ending.CHAPTER_SELECT):
			unlocked_at_start = load(Ending.CHAPTER_SELECT).is_unlocked()


## Stands in for a Convertible.
class FakeTarget extends Node:
	signal converted
	var is_converted := false
	var body: Area3D

	func convert() -> void:
		is_converted = true
		converted.emit()


var _gun: FakeGun
var _cards: FakeCards
var _end: FakeEnd
var _new_games := 0


func _gun_save() -> SaveGame:
	var save := SaveGame.new()
	save.stamped.append(UpgradeDesk.Events.GUN_CARD)
	return save


## A shootable in `group`: a shown Node3D holding a FakeTarget.
func _target(group: StringName, parent: Node3D = null) -> FakeTarget:
	if parent == null:
		parent = auto_free(Node3D.new())
		add_child(parent)
	var target := FakeTarget.new()
	target.add_to_group(group)
	parent.add_child(target)
	return target


func _ending(save: SaveGame, radio: Node3D = null) -> Ending:
	_gun = auto_free(FakeGun.new())
	_cards = auto_free(FakeCards.new())
	_end = auto_free(FakeEnd.new())
	_end.cards = _cards
	var ending: Ending = auto_free(SCENE.instantiate())
	ending.gun = _gun
	ending.cards = _cards
	ending.end_card = _end
	ending.radio = radio
	ending.save = save
	_new_games = 0
	ending.hum_fade = 0.0
	ending.step_hold = 0.0
	ending.new_game = func() -> void: _new_games += 1
	add_child(ending)
	ending._camera = null  # No camera glides in a test.
	return ending


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func test_the_ending_starts_once_the_gun_card_is_stamped() -> void:
	assert_bool(Ending.due(SaveGame.new())).is_false()
	assert_bool(Ending.due(_gun_save())).is_true()


func test_every_other_interactable_is_locked_while_the_ending_runs() -> void:
	var ending := _ending(_gun_save())
	await _frames()
	assert_bool(ending.running).is_true()
	assert_bool(Hand.locked).is_true()
	remove_child(ending)
	assert_bool(Hand.locked).is_false()


func test_the_first_card_comes_with_the_gun_and_the_ticker_drops_to_all_but_the_office() -> void:
	_target(&"ending_tv")
	_ending(_gun_save())
	await _frames()
	assert_array(_cards.shown).is_equal([Ending.STEPS[0].card])
	assert_bool(_gun.raised).is_true()
	assert_str(_cards.ticker).is_equal(Ending.ticker_text(true, 0))
	assert_bool(_cards.prompt).is_true()  # The TV is the first target: the prompt is up until the first shot.


func test_the_ticker_reads_all_of_it_then_all_but_the_office_and_creeps_up_with_every_shot() -> void:
	assert_str(Ending.ticker_text(false, 0)).is_equal("100.000000%")
	assert_str(Ending.ticker_text(true, 0)).is_equal("99.99999900%*")
	assert_str(Ending.ticker_text(true, 3)).is_equal("99.99999903%*")


func test_the_desk_step_waits_until_every_desk_object_is_cabbage() -> void:
	var lamp := _target(&"ending_desk")
	var press := _target(&"ending_desk")
	var ending := _ending(_gun_save())
	await _frames()
	assert_int(ending.step).is_equal(3)  # The TV and map steps have nothing here: on at once.
	assert_int(_cards.remaining).is_equal(2)
	_gun.shoot(lamp)
	await _frames()
	assert_int(ending.step).is_equal(3)
	assert_int(_cards.remaining).is_equal(1)
	_gun.shoot(null)  # A miss changes nothing.
	await _frames()
	assert_int(ending.step).is_equal(3)
	_gun.shoot(press)
	await _frames()
	assert_int(ending.step).is_equal(Ending.STEPS.size() - 1)
	assert_int(_cards.remaining).is_equal(-1)


func test_the_first_shot_takes_the_prompt_away() -> void:
	var tv := _target(&"ending_tv")
	_ending(_gun_save())
	await _frames()
	_gun.shoot(null)
	assert_bool(_cards.prompt).is_false()
	assert_bool(tv.is_converted).is_false()


func test_the_last_shot_is_refused_until_the_gun_faces_the_player() -> void:
	var save := _gun_save()
	var ending := _ending(save)
	await _frames()
	assert_int(ending.step).is_equal(Ending.STEPS.size() - 1)
	assert_bool(_gun.armed).is_false()
	_gun.shoot()
	await _frames()
	assert_bool(_end.played).is_false()
	assert_bool(_cards.prompt).is_false()
	_gun.turned.emit()
	await _frames()
	assert_bool(_gun.armed).is_true()
	assert_bool(_cards.prompt).is_true()
	assert_float(_cards.hum).is_equal(1.0)  # The hum of the turn keeps going, at its loudest.
	assert_int(_new_games).is_equal(0)
	_gun.shoot()
	await _frames()
	assert_bool(_end.played).is_true()
	assert_bool(ending.running).is_false()
	assert_float(_end.hum_under_black).is_equal(1.0)  # The turn's hum runs on under the black and the logo...
	assert_float(_cards.hum).is_equal(0.0)  # ...and fades as the credits start to roll.
	assert_bool(_cards.beating).is_false()


func test_a_new_game_starts_once_the_credits_are_over() -> void:
	var ending := _ending(_gun_save())
	await _frames()
	_gun.turned.emit()
	await _frames()
	assert_int(_new_games).is_equal(0)
	_gun.shoot()
	await _frames()
	assert_int(_new_games).is_equal(1)
	assert_bool(ending.running).is_false()


func test_the_chapter_select_is_unlocked_when_the_end_card_starts() -> void:
	if not ResourceLoader.exists(Ending.CHAPTER_SELECT):
		return  # Not built yet (another agent's ui/sub/chapter_select.gd).
	_ending(_gun_save())
	await _frames()
	_gun.turned.emit()
	await _frames()
	_gun.shoot()
	await _frames()
	assert_bool(_end.unlocked_at_start).is_true()


func test_an_ending_left_midway_starts_again_from_the_first_step() -> void:
	var save := _gun_save()
	_target(&"ending_desk")
	var first := _ending(save)
	await _frames()
	assert_int(first.step).is_equal(3)
	remove_child(first)  # Quit midway: nothing of it is in the save.
	assert_bool(Ending.due(save)).is_true()
	var again := _ending(save)
	await _frames(1)
	assert_str(_cards.shown[0]).is_equal(Ending.STEPS[0].card)  # The first card again, the gun raised again.
	assert_bool(_gun.raised).is_true()
	assert_int(again.step).is_equal(3)


func test_the_world_greens_with_every_conversion_until_all_is_cabbage() -> void:
	assert_float(Ending.green(0, 8)).is_equal(0.0)
	assert_float(Ending.green(2, 8)).is_equal(0.25)
	assert_float(Ending.green(8, 8)).is_equal(1.0)
	assert_float(Ending.green(0, 0)).is_equal(1.0)


func test_the_hum_rises_with_every_step() -> void:
	for i in range(1, Ending.STEPS.size()):
		assert_float(Ending.STEPS[i].hum).is_greater(Ending.STEPS[i - 1].hum)


func test_shooting_the_radio_stops_the_music_for_good_and_the_room_tone_comes_back() -> void:
	var radio: Node3D = auto_free(Node3D.new())
	add_child(radio)
	var song := AudioStreamPlayer.new()
	radio.add_child(song)
	var ambience: Node = auto_free(load("res://worlds/components/ambience.gd").new())
	var target := _target(&"ending_desk", radio)
	_target(&"ending_desk")
	var ending := _ending(_gun_save(), radio)
	ending.ambience = ambience
	await _frames()
	_gun.shoot(target)
	assert_bool(_cards.beating).is_true()
	assert_int(radio.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)  # It never drops back in.
	assert_bool(song.playing).is_false()
	assert_bool(ambience.radio_gone).is_true()


func test_a_hidden_object_is_not_a_target() -> void:
	var shown := _target(&"ending_desk")
	var hidden_parent: Node3D = auto_free(Node3D.new())
	hidden_parent.visible = false
	add_child(hidden_parent)
	_target(&"ending_desk", hidden_parent)
	var ending := _ending(_gun_save())
	assert_array(ending.targets_of(3)).is_equal([shown])


func test_every_step_that_shoots_has_its_targets_in_the_main_world() -> void:
	var state := (load(WORLD) as PackedScene).get_state()
	var groups := {}
	for i in state.get_node_count():
		for group in state.get_node_groups(i):
			groups[group] = groups.get(group, 0) + 1
	for data: Dictionary in Ending.STEPS:
		if data.has("group"):
			var count: int = groups.get(data.group, 0)
			for one: StringName in data.get("as_one", []):
				count += groups.get(one, 0)
			assert_int(count).override_failure_message("%s has no targets" % data.group).is_greater(0)
	assert_int(groups.get(&"ending_desk", 0)).is_greater_equal(10)


func test_the_crosshair_goes_as_the_gun_turns_on_the_player_and_no_cursor_comes_back() -> void:
	var ending := _ending(_gun_save())
	await _frames()
	assert_bool(_gun.turning).is_true()
	assert_bool(_gun.crosshair).is_false()
	assert_int(Hand.locked_cursor).is_equal(Input.MOUSE_MODE_HIDDEN)
	_gun.turned.emit()
	await _frames()
	assert_bool(_gun.crosshair).is_false()  # Not through the prompt either.
	assert_int(Hand.locked_cursor).is_equal(Input.MOUSE_MODE_HIDDEN)
	remove_child(ending)
	assert_int(Hand.locked_cursor).is_equal(Input.MOUSE_MODE_VISIBLE)


func test_the_final_shot_cuts_to_black_on_the_same_frame() -> void:
	var ending := _ending(_gun_save())
	await _frames()
	_gun.turned.emit()
	await _frames()
	assert_bool(ending.cut.visible).is_false()
	_gun.visible = true
	_gun.shoot()
	# No frame awaited: black and the gun gone before anything of the shot renders.
	assert_bool(ending.cut.visible).is_true()
	assert_bool(_gun.visible).is_false()


## Every bigger thing in the office, by its node in MainStoryWorld.tscn, and the step it belongs to.
const STATIONS := {
	ending_tv = ["FarmTv/Corner/Tv"],
	ending_map = ["MapTable/Sheets/World", "MapTable/Sheets/War", "MapTable/Sheets/Depot", "MapTable/Holder",
		"MapTable/Tally", "MapTable/Depot", "MapTable/Weights/TopLeft", "MapTable/Weights/TopRight",
		"MapTable/Weights/BottomLeft", "MapTable/Weights/BottomRight"],
	# The money and the research display are one item, as are the chute, its catch tally and its lever.
	ending_counters = ["TallyMachine", "FindingsCounter"],
	# The paper spike goes with its papers (the cards on it, the offered ones too): one item.
	ending_cards = ["UpgradeDesk/Spike"],
	ending_chute = ["CabbageFeeder/Model", "CatchCombo", "ChuteLever/Frame", "ChuteLever/Flap", "ChuteLever/Arm"],
	ending_desk = ["PriceSlate", "SupplyConsole", "QaBay", "UpgradeDesk/Press",
		"UpgradeDesk/Tray", "Ledger/Binder", "MilestoneMemo/Folder", "GoldenLamp",
		"ResearchLight", "RottenBin", "MiniDrop/Tube", "FieldLine", "Radio", "FarmTv/Remote",
		"HandSchedule/Switch"],
	# The chute's ramp waits for the walls: its box would swallow the paper spike's shots.
	# MiniDrop/TubeDesk is the desk top once the mini tube is in (it stands in for the table's).
	# The table, and the coins lying on it (their pile's box is no use to aim at): shot, both go.
	ending_table = ["Table", "MiniDrop/TubeDesk", "Coins"],
	# The walls go with their window, blinds and framed pictures: one item.
	ending_walls = ["Room/room_wall", "Room/window", "Room/blinds", "PriorVentures/Frame1",
		"PriorVentures/Frame2", "PriorVentures/Frame3"],

}


## The world's Convertibles: {parent path: {group, mode}}.
func _world_convertibles() -> Dictionary:
	var state := (load(WORLD) as PackedScene).get_state()
	var out := {}
	for i in state.get_node_count():
		if state.get_node_name(i) != &"Convertible":
			continue
		var mode := 0
		for k in state.get_node_property_count(i):
			if state.get_node_property_name(i, k) == &"mode":
				mode = int(state.get_node_property_value(i, k))
		var groups := state.get_node_groups(i)
		out[str(state.get_node_path(i, true)).trim_prefix("./")] = {group = str(groups[0]) if groups.size() > 0 else "", mode = mode}
	return out


func test_every_station_in_the_office_carries_a_convertible_in_its_step() -> void:
	var found := _world_convertibles()
	for group: StringName in STATIONS:
		for path: String in STATIONS[group]:
			assert_bool(found.has(path)).override_failure_message("%s has no Convertible" % path).is_true()
			if found.has(path):
				assert_str(str(found[path].group)).override_failure_message("%s is in the wrong step" % path).is_equal(str(group))
	# The coin robots are bought one by one: each carries its own.
	var robot := (load("res://entities/vacuum/vacuum_body.tscn") as PackedScene).instantiate()
	var conv := robot.get_node_or_null("Convertible")
	assert_object(conv).is_not_null()
	assert_bool(conv.is_in_group(&"ending_desk")).is_true()
	robot.free()
	# So do the hired hands (one per hand on the payroll), on the glove that moves.
	var hand := (load("res://entities/associate/associate.tscn") as PackedScene).instantiate()
	assert_bool(hand.get_node("Hand/Convertible").is_in_group(&"ending_hands")).is_true()
	hand.free()


func test_the_table_and_the_walls_are_never_popped() -> void:
	var found := _world_convertibles()
	for path in ["Table", "MiniDrop/TubeDesk", "Room/room_wall", "Room/window", "Room/blinds"]:
		assert_int(found[path].mode).is_equal(Convertible.Mode.MATERIAL)
		assert_str(str(found[path].group)).is_equal({"Table": "ending_table", "MiniDrop/TubeDesk": "ending_table"}.get(path, "ending_walls"))
	assert_int(found["Coins"].mode).is_equal(Convertible.Mode.POP)  # The coin pile pops into a cabbage.
	for path: String in found:  # Nothing that pops sits on the table's or the room's own node.
		if found[path].mode == Convertible.Mode.POP:
			assert_bool(path in ["Table", "MiniDrop/TubeDesk"] or path.begins_with("Room")).is_false()


func test_something_inside_a_popped_object_counts_as_done() -> void:
	var box: Node3D = auto_free(Node3D.new())
	add_child(box)
	var inner := _target(&"ending_desk", box)
	assert_bool(Ending.done(inner)).is_false()
	box.visible = false
	assert_bool(Ending.done(inner)).is_true()
	assert_int(Ending.left([inner] as Array[Node])).is_equal(0)


func test_the_ticker_never_reaches_the_whole_universe() -> void:
	assert_str(Ending.ticker_text(true, 100000)).is_equal("99.99999999%*")


func test_a_coin_robot_and_its_dock_are_one_target_whichever_is_shot() -> void:
	for shoot_dock in [true, false]:
		var robot := _target(&"ending_desk")
		var dock_parent: Node3D = auto_free(Node3D.new())
		add_child(dock_parent)
		var dock := FakeTarget.new()  # In no step: it goes with its robot.
		dock_parent.add_child(dock)
		CoinVacuums.pair_targets(robot, dock)
		var lamp := _target(&"ending_desk")
		var ending := _ending(_gun_save())
		await _frames()
		assert_int(_cards.remaining).is_equal(2)  # The robot and the lamp: the dock is not counted.
		_gun.shoot(dock if shoot_dock else robot)
		await _frames()
		assert_bool(robot.is_converted and dock.is_converted).is_true()
		assert_int(_cards.remaining).is_equal(1)
		remove_child(ending)
		for node: Node in [robot, dock, lamp]:
			node.remove_from_group(&"ending_desk")


func test_no_target_stays_on_the_gun_layer_before_its_step() -> void:
	var desk := _target(&"ending_desk")
	var body := Area3D.new()
	body.collision_layer = Convertible.LAYER
	desk.add_child(body)
	desk.set(&"body", body)
	_target(&"ending_tv")
	_ending(_gun_save())
	await _frames()
	assert_int(body.collision_layer).is_equal(0)  # The TV step is on: the desk waits its turn.


func test_every_hand_on_the_desk_is_one_item_and_one_shot_takes_them_all() -> void:
	var hands: Array[FakeTarget] = [_target(&"ending_hands"), _target(&"ending_hands"), _target(&"ending_hands")]
	_target(&"ending_desk")
	_ending(_gun_save())
	await _frames()
	assert_int(_cards.remaining).is_equal(2)  # The lamp, and the hands as one.
	_gun.shoot(hands[2])
	await _frames()
	for hand in hands:
		assert_bool(hand.is_converted).is_true()
		assert_int(hand.get_parent().process_mode).is_equal(Node.PROCESS_MODE_DISABLED)  # No glove comes back.
	assert_int(_cards.remaining).is_equal(1)


func test_a_shot_station_stops_for_good_so_nothing_it_holds_comes_back() -> void:
	var ledger: Node3D = auto_free(Node3D.new())  # A station: its script would show its binder again.
	add_child(ledger)
	var binder := Node3D.new()
	ledger.add_child(binder)
	var target := _target(&"ending_desk", binder)
	_target(&"ending_desk")
	_ending(_gun_save())
	await _frames()
	_gun.shoot(target)
	assert_int(ledger.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_int(binder.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_int(target.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)  # Its own pop still plays.


func test_a_stopped_station_keeps_its_other_things_shootable() -> void:
	var map: Node3D = auto_free(Node3D.new())
	add_child(map)
	var holder := Node3D.new()
	map.add_child(holder)
	var sheet := Node3D.new()
	map.add_child(sheet)
	var first := _target(&"ending_desk", holder)
	var second := _target(&"ending_desk", sheet)
	second.body = Area3D.new()
	second.add_child(second.body)
	_ending(_gun_save())
	await _frames()
	_gun.shoot(first)
	assert_int(map.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_bool(second.body.can_process()).is_true()  # Still in physics: the gun's ray finds it.
	assert_int(second.body.collision_layer).is_equal(Convertible.LAYER)


## The transform node `path` of the world has in MainStoryWorld.tscn (identity if none is set).
func _world_transform(path: String) -> Transform3D:
	var state := (load(WORLD) as PackedScene).get_state()
	for i in state.get_node_count():
		if str(state.get_node_path(i)).trim_prefix("./") == path:
			for k in state.get_node_property_count(i):
				if state.get_node_property_name(i, k) == &"transform":
					return state.get_node_property_value(i, k)
	return Transform3D.IDENTITY


func test_the_paper_spike_can_be_shot_while_the_chute_lever_and_the_chute_still_stand() -> void:
	var lever: Node3D = auto_free((load("res://entities/chute_lever/chute_lever.tscn") as PackedScene).instantiate())
	var desk: Node3D = auto_free((load("res://entities/upgrade_desk/upgrade_desk.tscn") as PackedScene).instantiate())
	lever.transform = _world_transform("ChuteLever")
	desk.transform = _world_transform("UpgradeDesk")
	add_child(lever)
	add_child(desk)
	var spike := desk.get_node("Spike") as Node3D
	var top := spike.global_transform * Convertible.bounds(spike)
	var eye := _world_transform("Camera3D").origin
	var boxes: Array[AABB] = []
	for part in ["Frame", "Flap", "Arm"]:
		var node := lever.get_node(part) as Node3D
		boxes.append(node.global_transform * Convertible.bounds(node))
	# The chute's ramp beside it is a desk target too.
	var ramp: Node3D = auto_free((load("res://assets/meshes/Machines/supply_ramp.blend") as PackedScene).instantiate())
	ramp.transform = _world_transform("CabbageFeeder") * _world_transform("CabbageFeeder/Model")
	add_child(ramp)
	boxes.append(ramp.global_transform * Convertible.bounds(ramp))
	# The spike's top seen from the desk camera, on a 5 x 5 grid: a click there must reach the spike
	# (the gun's ray takes the nearest box) on most of it.
	var clear := 0
	for i in 5:
		for j in 5:
			var aim := top.position + Vector3(top.size.x * (i + 0.5) / 5.0, top.size.y, top.size.z * (j + 0.5) / 5.0)
			if not boxes.any(func(box: AABB) -> bool: return box.intersects_segment(eye, aim) != null):
				clear += 1
	assert_int(clear).is_greater_equal(13)


func test_the_walls_step_says_what_is_left_until_its_first_hit() -> void:
	var wall := _target(&"ending_room")
	_target(&"ending_room")
	var ending := _ending(_gun_save())
	await _frames()
	assert_int(ending.step).is_equal(4)
	assert_bool(ending.notice.is_visible_in_tree()).is_true()
	assert_str(ending.notice.text).is_equal(Ending.STEPS[4].notice)
	_gun.shoot(wall)
	assert_bool(ending.notice.is_visible_in_tree()).is_false()


func test_a_dropped_cabbage_goes_a_few_seconds_after_it_lands() -> void:
	_target(&"ending_desk")
	var ending := _ending(_gun_save())
	await _frames()
	var drop: Cabbage = (load("res://entities/cabbage/cabbage.tscn") as PackedScene).instantiate()
	drop.freeze = true  # Lying still.
	add_child(drop)
	ending._age_drops(Ending.DROP_LIFE - 0.5)
	assert_bool(is_instance_valid(drop)).is_true()
	ending._age_drops(1.0)
	await get_tree().create_timer(Ending.DROP_SHRINK + 0.2).timeout
	assert_bool(is_instance_valid(drop)).is_false()


func test_the_offered_cards_are_one_target_in_the_desk_step() -> void:
	var card := (load("res://entities/upgrade_desk/upgrade_card.tscn") as PackedScene).instantiate()
	assert_bool(card.get_node("Look/Convertible").is_in_group(&"ending_cards")).is_true()
	card.free()
	assert_array(Ending.STEPS[3].as_one).contains([&"ending_cards", &"ending_counters", &"ending_chute"])


func test_a_shot_cabbage_is_simply_gone_and_counts_for_nothing() -> void:
	_target(&"ending_desk")
	_target(&"ending_desk")
	var ending := _ending(_gun_save())
	await _frames()
	var cabbage: Cabbage = (load("res://entities/cabbage/cabbage.tscn") as PackedScene).instantiate()
	cabbage.freeze = true
	add_child(cabbage)
	await _frames()  # It gets its hit box (deferred).
	var puff := cabbage.get_node("Puff") as CabbagePuff
	assert_object(puff).is_not_null()
	var on_desk := get_tree().get_nodes_in_group(&"cabbages").size()
	puff.convert_at(cabbage.global_position)
	await _frames()
	assert_bool(is_instance_valid(cabbage)).is_false()
	assert_int(get_tree().get_nodes_in_group(&"cabbages").size()).is_equal(on_desk - 1)  # No new one.
	assert_int(_cards.remaining).is_equal(2)  # Not an item.
	assert_int(ending.converted).is_equal(0)


class FakeGreening extends Node:
	var amounts: Array[float] = []

	func set_amount(t: float) -> void:
		amounts.append(t)


func test_the_walls_step_skins_the_walls_and_greens_the_screen_its_share() -> void:
	var wall: MeshInstance3D = auto_free(MeshInstance3D.new())
	wall.mesh = BoxMesh.new()
	add_child(wall)
	var skin := Convertible.new()
	skin.mode = Convertible.Mode.MATERIAL
	skin.add_to_group(&"ending_room")
	wall.add_child(skin)
	_target(&"ending_desk")
	var green: FakeGreening = auto_free(FakeGreening.new())
	_gun = null
	var ending := _ending(_gun_save())
	ending.greening = green
	ending._greening = green
	await _frames()
	_gun.shoot(ending._targets[0])  # The desk.
	await _frames()
	assert_int(ending.step).is_equal(4)
	_gun.shoot(skin)
	await _frames()
	assert_object(wall.material_overlay).is_not_null()  # The leaf skin, not a pop.
	assert_bool(wall.visible).is_true()
	assert_array(green.amounts).is_equal([0.5, 1.0])
	skin.remove_from_group(&"ending_room")


func test_a_target_counts_as_in_view_when_any_of_it_is_on_screen_not_only_its_middle() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.transform = _world_transform("Camera3D")
	var view := camera.get_frustum()
	# The table: its middle lies under the camera, out of view, but its top fills the screen.
	var table := AABB(Vector3(-4.6, 0.0, -1.0), Vector3(10.4, 0.764, 4.75))
	assert_bool(Ending.box_in_view(table, view)).is_true()
	assert_bool(Ending.box_in_view(AABB(Vector3(0.0, 0.0, 40.0), Vector3.ONE), view)).is_false()  # Behind the camera.


func test_the_walls_step_waits_for_its_shots_and_skins_the_real_table_and_walls() -> void:
	var real_save := SaveManager.save
	var drops := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var root_before := drops.get_children()
	SaveManager.save = ResourceLoader.load("res://ressources/save/debug_starts/96_chapter_5_the_gun.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	var world := (load(WORLD) as PackedScene).instantiate() as Node3D
	var ending := world.get_node("Ending") as Ending
	ending.new_game = func() -> void: pass
	ending.hum_fade = 0.0
	ending.step_hold = 0.0
	ending.move_time = 0.0
	add_child(world)
	await _frames(5)
	# Through the earlier steps at once: every target converted, cards sent away.
	var cards := world.get_node("BossCard") as BossCard
	var until := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until:
		if ending.step >= 4 and (ending.gun as CabbageGun).armed:
			break  # Waiting for the walls step's shots.
		cards.dismiss()
		if ending.step < 4:
			for target in ending._targets:
				if not Ending.done(target):
					target.convert()
		await get_tree().process_frame
	assert_int(ending.step).is_equal(4)
	var table := world.get_node("Table/Table") as MeshInstance3D
	var wall := world.get_node("Room/room_wall") as MeshInstance3D
	assert_object(table.material_overlay).is_null()  # The step waits for its shots.
	# One hit on the table: the whole desk (table, mat, desk top, coins) is one item and goes at once.
	var desk_top := world.get_node("MiniDrop/TubeDesk/table_tube") as MeshInstance3D
	var table_item: Node = world.get_node("Table/Convertible")
	assert_bool(table_item in ending._targets).is_true()
	var left_before := Ending.left(ending._targets)
	table_item.convert()
	await _frames(3)
	assert_object(table.material_overlay).is_not_null()
	assert_object(desk_top.material_overlay).is_not_null()
	assert_bool((world.get_node("Coins") as Node3D).visible).is_false()
	assert_int(Ending.left(ending._targets)).is_equal(left_before - 1)
	assert_object(wall.material_overlay).is_null()  # The walls are their own item.
	for target in ending._targets.duplicate():
		if not Ending.done(target):
			target.convert()
	await _frames(3)
	assert_object(wall.material_overlay).is_not_null()
	var until_next := Time.get_ticks_msec() + 5000
	while ending.step < 5 and Time.get_ticks_msec() < until_next:
		await get_tree().process_frame
	assert_int(ending.step).is_equal(5)
	world.free()
	# The pops' cabbages and leaves landed in the scene root: none may stay for the next suites.
	for node in drops.get_children():
		if node is Node3D and node not in root_before:
			node.free()
	# What the world set game-wide goes back for the suites after this one.
	SaveManager.save = real_save
	BossReport.up = false
	BossReport.hold = 0.0
	FarmTv.away = false
	WarSheetScript.at_war = false
	FarmRegister.lamp_held = false
	Hand.locked = false
	Engine.time_scale = 1.0


func test_the_coffee_cups_are_left_alone() -> void:
	var found := _world_convertibles()
	assert_bool(found.has("CoffeeMug") or found.has("CoffeeMug2")).is_false()


func test_the_walls_go_with_their_window_and_pictures_as_one_item() -> void:
	assert_array(Ending.STEPS[4].as_one).contains([&"ending_walls", &"ending_table"])

