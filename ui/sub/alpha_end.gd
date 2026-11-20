class_name AlphaEnd
extends Control
## The alpha's end: when the last card built so far is stamped (CARD: chapter 4's nuclear hour ends
## with the CABBAGE STAR PROGRAMME; the flagship that follows is not built yet) a big memo over a
## dimmed screen thanks the player, once per save (save.alpha_end, set on closing). Closed by its
## button or Esc; the game keeps running behind it. The demo has its own end (BossReport.DEMO_END).

const Events := preload("res://globalScripts/game_events.gd")
## Unreachable for now: the CABBAGE STAR PROGRAMME card was dropped (2026-11-20, chapter 4 goes on
## from the TELESCOPE), so no desk card deals it. Point CARD at chapter 4's new last card when it exists.
const CARD := "star_programme"


## Whether the popup comes now for `save`.
static func due(save: SaveGame) -> bool:
	return not Events.Demo.active() and not save.alpha_end and save.stamped.has(CARD)


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
