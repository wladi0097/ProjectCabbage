class_name HandlingSheet
extends Control
## The handling schedule's paper (HandSchedule): opens when its switch on the desk is clicked. Two
## halves, lab hands left and hired hands right, each a row of cabbage pictures (ScheduleCell, fixed
## in the scene). A click on a picture strikes that kind for that half's hands, or clears it
## (HandSchedule.toggle); a kind not met yet is not printed at all, one met but not listed yet is
## faint and padlocked.
## Mouse only; X, Esc or a click beside the paper closes it. The game keeps running behind it.

@onready var _cells: Array[Node] = $Paper/Stack/Halves/Lab/Row.get_children() + $Paper/Stack/Halves/Hired/Row.get_children()


func _ready() -> void:
	visible = false
	%Close.pressed.connect(close)
	for cell: ScheduleCell in _cells:
		cell.pressed.connect(_toggle.bind(cell))
	$Shade.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			close())


func open() -> void:
	visible = true
	$"../Open".play()
	_show(SaveManager.save)


func close() -> void:
	if visible:
		$"../Close".play()
	visible = false


## Every frame while open: a card stamped or node bought behind it lists its kind at once.
func _process(_delta: float) -> void:
	if visible:
		_show(SaveManager.save)


## Esc closes it, in _input so it gets Esc before the in-game menu (unhandled) opens.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## A click on `cell`: its kind is struck for its half's hands (a stamp), or cleared (paper).
func _toggle(cell: ScheduleCell) -> void:
	var save := SaveManager.save
	if not HandSchedule.toggle(save, cell.research, cell.kind):
		return
	($"../Stamp" if HandSchedule.forbidden(save, cell.research).has(cell.kind) else $"../Clear").play()
	_show(save)


func _show(save: SaveGame) -> void:
	for cell: ScheduleCell in _cells:
		cell.visible = HandSchedule.seen(save, cell.kind)
		cell.show_state(HandSchedule.listed(save, cell.kind), HandSchedule.forbidden(save, cell.research).has(cell.kind))
