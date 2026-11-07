extends Node
## Run: Godot --headless --path . res://tests/entities/associate/test_associate.tscn

const CABBAGE := preload("res://entities/cabbage/cabbage.tscn")
const Feeder := preload("res://worlds/components/cabbage_feeder.gd")


func _ready() -> void:
	var failed := false
	# Picks the nearest free cabbage resting on the mat; skips held, sold, frozen and stray ones.
	var spots := [Vector3(1.2, 0.87, 0.9), Vector3(0.9, 0.87, 0.6), Vector3(0.2, 0.87, 0.0), Vector3(-1.2, 0.87, 0.3)]
	var cabbages: Array[Cabbage] = []
	for spot: Vector3 in spots:
		var cabbage := CABBAGE.instantiate() as Cabbage
		add_child(cabbage)
		cabbage.global_position = spot
		cabbages.append(cabbage)
	var held := cabbages[0].get_node("Interactable") as Interactable
	var entry := Vector3(1.15, 1.2, 1.75)
	if Associate.pick_target(cabbages, entry, null) != cabbages[0]:
		failed = true
		push_error("should pick the nearest cabbage")
	if Associate.pick_target(cabbages, entry, held) != cabbages[1]:
		failed = true
		push_error("should leave the player's cabbage alone")
	if Associate.pick_target(cabbages, entry, held, [cabbages[1]]) != cabbages[2]:
		failed = true
		push_error("should skip a cabbage another hand has claimed")
	cabbages[1].sold = true
	if Associate.pick_target(cabbages, entry, held) != cabbages[2]:
		failed = true
		push_error("should skip a sold cabbage (and never the stray one)")
	cabbages[2].freeze = true
	if Associate.pick_target(cabbages, entry, held) != null:
		failed = true
		push_error("frozen and stray cabbages are not targets")
	# Rotten units are targets too: sold out of the window (fined) until hands_bin, then binned.
	var rotten := CABBAGE.instantiate() as Cabbage
	rotten.rotten = true
	add_child(rotten)
	rotten.global_position = Vector3(1.1, 0.87, 1.0)
	if Associate.pick_target([rotten], entry, null) != rotten:
		failed = true
		push_error("hands should take rotten units too")
	# The spoilage memo: hands leave rotten units on the mat until they bin them (hands_bin).
	var memo := SaveGame.new()
	var skip_before := Associate.skips_rotten(memo)
	memo.stamped.append("spoilage_memo")
	var skip_memo := Associate.skips_rotten(memo)
	memo.hands_bin = 1
	if skip_before or not skip_memo or Associate.skips_rotten(memo) or Associate.pick_target([rotten], entry, null, [], true) != null:
		failed = true
		push_error("the spoilage memo should keep hands off rotten units until hands_bin")
	# Research hands never take rotten units, whatever the memo says.
	if Associate.pick_target([rotten], entry, null, [], false, true) != null:
		failed = true
		push_error("research hands should leave rotten units alone")
	# lab_priority: before it anyone takes a research unit; after it money hands never do and research
	# hands take one before any nearer ordinary unit.
	var unit := CABBAGE.instantiate() as Cabbage
	unit.research = true
	add_child(unit)
	unit.global_position = Vector3(0.6, 0.87, 0.75)
	var plain := CABBAGE.instantiate() as Cabbage
	add_child(plain)
	plain.global_position = Vector3(0.0, 0.87, 0.3)
	var pool: Array = [plain, unit]
	var lab_entry := Associate.park_spot(0, true)
	if Associate.pick_target(pool, entry, held, [], false, false, false) != unit \
			or Associate.pick_target(pool, lab_entry, held, [], false, true, false) != plain \
			or Associate.pick_target(pool, entry, held, [], false, false, true) != plain \
			or Associate.pick_target([unit], entry, held, [], false, false, true) != null \
			or Associate.pick_target(pool, lab_entry, held, [], false, true, true) != unit \
			or Associate.pick_target(pool, lab_entry, held, [unit], false, true, true) != plain:
		failed = true
		push_error("lab_priority picks wrong")
	unit.queue_free()
	plain.queue_free()
	# The toss into the QA bay (MainStoryWorld QaBay at (-0.08, 0.75, -0.8): mouth (0.055, 0.89, -0.84),
	# front plane z -0.64, opening x -0.07..0.335 local, y 0.76..1.035): a cabbage (r 0.11) passes clear.
	var mouth := Vector3(0.055, 0.89, -0.84)
	for jitter: float in [-1.0, 1.0]:
		var aim := Associate.bay_aim(mouth, jitter)
		var from := mouth + Associate.RESEARCH_RELEASE
		var v := Feeder.ballistic_velocity(from, aim, Associate.BAY_LOB)
		var t := (-0.64 - from.z) / v.z
		var y := from.y + v.y * t - 0.5 * 9.8 * t * t
		if y < 0.76 + 0.11 or y > 1.035 - 0.11 or aim.x < -0.08 - 0.07 + 0.11 or aim.x > -0.08 + 0.335 - 0.11:
			failed = true
			push_error("toss to %s crosses the bay front at y %.2f" % [aim, y])
	var bin :=RottenBin.new()  # never in the tree: only its visibility counts here
	if Associate.bin_for(rotten, 0, bin) != null or Associate.bin_for(rotten, 1, bin) != bin \
			or Associate.bin_for(cabbages[3], 1, bin) != null or Associate.bin_for(rotten, 1, null) != null:
		failed = true
		push_error("bin_for wrong")
	bin.visible = false
	if Associate.bin_for(rotten, 1, bin) != null:
		failed = true
		push_error("no bin on the desk yet: the hand sells it")
	bin.free()
	rotten.queue_free()
	if not Associate.gives_up(cabbages[0], held) or Associate.gives_up(cabbages[0], null):
		failed = true
		push_error("should give up only when the player holds its cabbage")
	# Snatching: only the player's hold on the hand's own cabbage counts; a freed target is no snatch.
	if not Associate.snatched(cabbages[0], held) or Associate.snatched(cabbages[3], held) \
			or Associate.snatched(cabbages[0], null) or Associate.snatched(null, held):
		failed = true
		push_error("snatched wrong")
	# A carried cabbage stays on a layer the player's ray hits and nothing collides with.
	if Associate.CARRIED_LAYER & Hand.PLAY_AREA_LAYER or Associate.CARRIED_LAYER & cabbages[3].collision_mask:
		failed = true
		push_error("carried layer must be pickable and collide with nothing")
	# Every aim lies in the right ~30% of the gap (the street, far from the QA bay), and the lob is still under the wall above the gap
	# (bottom y 1.07) and over the sill where it reaches the sale zone (z -0.6).
	for roll: float in [0.0, 1.0]:
		for jitter: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
			var aim := Associate.aim_at(roll, jitter)
			var right := SaleWindow.GAP_X.y - 0.3 * (SaleWindow.GAP_X.y - SaleWindow.GAP_X.x)
			if aim.x < right - 0.02 or aim.x > 1.7:
				failed = true
				push_error("aim %s outside the sale zone" % aim)
			for lob: float in [Associate.LOB_TIME - Associate.LOB_JITTER, Associate.LOB_TIME + Associate.LOB_JITTER]:
				var from := Vector3(aim.x, Associate.RELEASE_Y, Associate.RELEASE_Z)
				var v := Feeder.ballistic_velocity(from, aim, lob)
				var t := (-0.6 - from.z) / v.z
				var y := from.y + v.y * t - 0.5 * 9.8 * t * t
				if y < 0.8 or y > 1.07 + 0.05:
					failed = true
					push_error("lob to %s crosses z -0.6 at y %.2f" % [aim, y])
	# Idle hands lie in two loose piles inside the bottom edge of the world camera's 16:9 frame, clear
	# of the waste bin (MainStoryWorld RottenBin at x 0.95): research hands on the QA bay's side, all
	# left of every money hand, so the lanes don't cross. Later hands rest a layer higher, a little turned.
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.4826, -0.8758), Vector3(0, 0.8758, 0.4826)), Vector3(0.25, 3.2, 1.6))
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	add_child(view)
	view.add_child(camera)
	var research_right := -INF
	var money_left := INF
	for kind: bool in [false, true]:
		for k in (Associate.MAX_RESEARCH if kind else Associate.MAX_VISIBLE):
			var spot := Associate.park_spot(k, kind)
			var at := camera.unproject_position(spot) / Vector2(view.size)
			if kind:
				research_right = maxf(research_right, spot.x)
			else:
				money_left = minf(money_left, spot.x)
			if absf(spot.x - 0.95) < Associate.BIN_CLEAR or at.x < 0.03 or at.x > 0.97 or at.y < 0.8 or at.y > 0.97 					or spot.y < Associate.park_spot(maxi(k - Associate.PILE_ROW, 0), kind).y + (Associate.PILE_LAYER - 1e-4 if k >= Associate.PILE_ROW else 0.0) 					or absf(Associate.park_turn(k)) > Associate.PILE_TURN + 1e-4:
				failed = true
				push_error("parking spot %s at screen %s" % [spot, at])
	if research_right >= money_left or Associate.park_spot(3, false) != Associate.park_spot(3, false):
		failed = true
		push_error("research pile should lie left of the money pile, spots fixed per index")
	print("associate tests failed" if failed else "associate tests passed")
	get_tree().quit(1 if failed else 0)
