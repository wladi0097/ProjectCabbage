class_name AlphaEnd
extends Control
## The alpha's end: when chapter 3 unlocks (GameEvents.chapter_3, the capstone card stamped) a big
## memo over a dimmed screen thanks the player, once per save (save.alpha_end, set on closing). For
## the alpha it stands in for the chapter's boss paper (BossReport.HELD). Closed by its button or
## Esc; the game keeps running behind it. The demo has its own end (BossReport.DEMO_END).

const Events := preload("res://globalScripts/game_events.gd")


## Whether the popup comes now for `save`.
static func due(save: SaveGame) -> bool:
	return not Events.Demo.active() and not save.alpha_end and Events.chapter_3(save)


func open() -> void:
	show()
	BossReport.up = true  # The TV and the combo treat it like a report.
	$Land.play()


func close() -> void:
	SaveManager.save.alpha_end = true
	hide()
	BossReport.up = false


func _input(event: InputEvent) -> void:
	# _input: the pause menu would take Esc first otherwise.
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
