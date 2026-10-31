extends Node
## Run: Godot --headless --path . res://tests/entities/manager/test_manager.tscn

const Mgr := preload("res://entities/manager/manager.gd")


func _ready() -> void:
	var failed := false
	# 60 sold over 5 minutes (60 samples of 5 s): 0.2 a second, 45 s at x1.25 asks ceil(11.25) = 12.
	var samples := PackedInt32Array()
	for i in 60:
		samples.append(i)
	if Mgr.quota_for(samples, 60, 45.0, 1.25) != 12:
		failed = true
		push_error("quota should be the 5-minute pace over 45 s, raised 25%%: got %d" % Mgr.quota_for(samples, 60, 45.0, 1.25))
	if Mgr.quota_for(PackedInt32Array([5]), 5, 45.0, 1.25) != Mgr.MIN_QUOTA:
		failed = true
		push_error("nothing sold yet should ask the minimum quota")
	if Mgr.quota_for(samples, 60, 60.0, 1.25) <= Mgr.quota_for(samples, 60, 45.0, 1.25):
		failed = true
		push_error("more time should ask for more units")
	if Mgr.bonus_for(12, 3, 1.0) != 36 or Mgr.bonus_for(12, 3, 1.5) != 54:
		failed = true
		push_error("bonus should be quota x price x reward")
	# Stamped late: 300 units sold since the load at 1 a second, then 0.2 a second once stamped. The
	# first visit (FIRST_VISIT s after the stamp) asks the pace since the stamp: ceil(0.2 x 45 x 1.25) = 12.
	var real := SaveManager.save
	SaveManager.save = SaveGame.new()
	var manager: Node = preload("res://entities/manager/manager.tscn").instantiate()
	add_child(manager)
	manager.set_process(false)
	for i in 300:
		SaveManager.save.sold += 1
		manager._process(1.0)
	SaveManager.save.stamped.append(Mgr.CARD)
	for i in ceili(Mgr.FIRST_VISIT * 10.0):
		if i % 50 == 0:
			SaveManager.save.sold += 1
		manager._process(0.1)
	if manager.phase == Mgr.Phase.AWAY or manager.quota < 11 or manager.quota > 13:
		failed = true
		push_error("a late stamp should ask the pace since the stamp: phase %d, quota %d" % [manager.phase, manager.quota])
	manager.free()
	SaveManager.save = real
	print("manager tests failed" if failed else "manager tests passed")
	get_tree().quit(1 if failed else 0)
