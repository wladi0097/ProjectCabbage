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
	if Associate.pick_target(cabbages, Associate.ENTRY, null) != cabbages[0]:
		failed = true
		push_error("should pick the nearest cabbage")
	if Associate.pick_target(cabbages, Associate.ENTRY, held) != cabbages[1]:
		failed = true
		push_error("should leave the player's cabbage alone")
	if Associate.pick_target(cabbages, Associate.ENTRY, held, [cabbages[1]]) != cabbages[2]:
		failed = true
		push_error("should skip a cabbage another hand has claimed")
	cabbages[1].sold = true
	if Associate.pick_target(cabbages, Associate.ENTRY, held) != cabbages[2]:
		failed = true
		push_error("should skip a sold cabbage (and never the stray one)")
	cabbages[2].freeze = true
	if Associate.pick_target(cabbages, Associate.ENTRY, held) != null:
		failed = true
		push_error("frozen and stray cabbages are not targets")
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
	# Every aim lies in the sale part of the gap, and the lob is still under the wall above the gap
	# (bottom y 1.07) and over the sill where it reaches the sale zone (z -0.6).
	for roll: float in [0.0, 1.0]:
		for jitter: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
			var aim := Associate.aim_at(roll, jitter)
			if aim.x < SaleWindow.SPLIT_X + 0.05 or aim.x > 1.7:
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
	if Associate.ENTRY_X.size() < Associate.MAX_VISIBLE or Associate.MAX_VISIBLE < 10:
		failed = true
		push_error("every visible hand (10) needs an entry slot")
	# The QA intake rota: every n-th trip, only when the bay has a free bench.
	if Associate.feeds_qa(6, 0, true) or not Associate.feeds_qa(6, 6, true) or Associate.feeds_qa(6, 6, false) \
			or Associate.feeds_qa(5, 6, true) or not Associate.feeds_qa(9, 3, true):
		failed = true
		push_error("feeds_qa wrong")
	print("associate tests failed" if failed else "associate tests passed")
	get_tree().quit(1 if failed else 0)
