extends Node
## Run: Godot --headless --path . res://tests/entities/upgrade_desk/test_upgrade_desk.tscn


func _ready() -> void:
	var failed := false
	if UpgradeDesk.next_cards(PackedStringArray(), 3) != ["price_slate"]:
		failed = true
		push_error("only the price slate should be offered before it is stamped")
	if UpgradeDesk.next_cards(PackedStringArray(["price_slate"]), 3) != ["desk_space", "acceptance_meter", "bulk_procurement"]:
		failed = true
		push_error("the slate should open the three cards that need it")
	if UpgradeDesk.next_cards(PackedStringArray(["price_slate", "desk_space"]), 3) != ["acceptance_meter", "bulk_procurement"]:
		failed = true
		push_error("a stamped card should leave the offer")
	var save := SaveGame.new()
	for card: Dictionary in UpgradeDesk.CARDS:
		UpgradeDesk.apply(card.id, save)
	if not save.slate_unlocked or save.desk_capacity != 2 or save.pack_size != 13:
		failed = true
		push_error("card effects wrong: slate %s, desk %d, pack %d" % [save.slate_unlocked, save.desk_capacity, save.pack_size])
	print("upgrade desk tests failed" if failed else "upgrade desk tests passed")
	get_tree().quit(1 if failed else 0)
