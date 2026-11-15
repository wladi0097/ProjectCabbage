class_name DepotSheet
extends MapSheet
## The depot sheet (FORM 7-P PERSONNEL REQUISITION): rolls out when the PERSONNEL DEPOT on the map
## table is clicked (MapTable.open_depot), with the sheet it replaced rolled up in the holder (the
## way back). One column per unit type the depot deals in (Depot.units: hired ones only; the
## others are not on the sheet at all), across the top of the sheet at fixed places (COLUMN_LEFT, then
## one COLUMN_WIDTH + COLUMN_GAP further each), so later types fill in to the right; all five fit at
## full size. Each column (depot_column.tscn):
## - its name (shrunk to fit: German runs long), and its figure standing on the paper in 3D (entities/war/soldiers/<unit>.tscn under
##   `Things`, FIGURE_SCALE times its fighting size so it reads, less for the big ones so it stands
##   no wider than FIGURE_FOOT: figure_size); the mouse on it (spot
##   "figure:<unit>") lifts it and turns it towards the camera, eased back when it leaves;
## - its stats as small plates (WarRules.unit_stats, research applied): HP, damage, speed, target;
## - how many are ready (save.army), big under the figure: "3×"; it bumps when a trainee joins;
## - the round HIRE AND TRAIN button (spot "buy:<unit>", a click: requisition()) with the cabbage
##   icon and the price under it, and under that why it is refused (STAFF AT CAPACITY: the HEADCOUNT
##   in the title block, bottom right; NOT ENOUGH CABBAGES), blinking with the jam when it is;
## - the trainee: the front of this unit's training queue as a small grey (unpainted) figure beside
##   the button, a progress bar under its feet (an inked track, filling green with its training:
##   bar_fill), under that the seconds it has left (seconds_left) and "+N" for the rest of the queue
##   (training_of). A new front lands with a drop; finished, it jumps into the big figure.
##   A loaded save shows the queue as it stands, without the moments;
## - a ¶ mark while a research node of its unit can be bought (has_news).
## Below the columns, the one DEVELOPMENT PROGRAMME, beside the title block of the same height (bottom
## right: PERSONNEL DEPOT, the form line, the FILED stamp, STAFF n / cap): the shared upgrade tree
## (UpgradeTree, `Tree`, rules DepotResearch: an org chart, the hub on top, a department per hired
## unit in a row below it, each unit's research going down under its plate, the GENERAL programme
## above the hub; Findings or coins, parent first, held to buy; panned and zoomed and hovered like the
## projector's, its popup drawn popup_scale times bigger so it reads from the map camera). The table
## hands the mouse to the tree (take_mouse) while it is over the tree's box.
## The page is printed every frame while the sheet is out (the tree's hover and hold animate on it).
## ponytail: a 2560 x 1440 page redrawn each frame while the depot sheet is open; reprint on
## changes only if that ever shows in a profile.

const COLUMN := preload("res://entities/war/depot/depot_column.tscn")
const SOLDIER := "res://entities/war/soldiers/%s.tscn"
## Columns (px): the first one's left edge, each this wide and this far apart, their tops here.
const COLUMN_LEFT := 110.0
const COLUMN_WIDTH := 560.0
const COLUMN_GAP := 45.0
const COLUMN_TOP := 150.0
## A figure on the sheet is this many times its size on a fighting map; the mouse within FIGURE_HIT
## px of its stage is on it. Hovered it lifts FIGURE_LIFT m and turns to the camera, leaning
## FIGURE_LEAN of the way back towards it, in FIGURE_TIME s.
const FIGURE_SCALE := 2.3
const FIGURE_FOOT := 0.27
const FIGURE_HIT := 120.0
const FIGURE_LIFT := 0.05
const FIGURE_LEAN := 0.15
const FIGURE_TIME := 0.18
## The research tree's zoom on the sheet: every branch in its box, its nodes read from the map camera.
const TREE_ZOOM := 1.25
## Each unit's name as printed, and each target rule (WarRules.BASE_STATS `target`) in words.
const NAMES := {field_associate = "FIELD ASSOCIATE", restructuring_charge = "RESTRUCTURING CHARGE",
		senior_asset = "SENIOR ASSET", pult_crew = "CABBAGE-PULT CREW", courier = "EXPRESS COURIER"}
## The same in a sentence (hint slips).
const CALLED := {field_associate = "field associate", restructuring_charge = "restructuring charge",
		senior_asset = "senior asset", pult_crew = "cabbage-pult crew", courier = "express courier"}
const TARGETS := {defence = "NEAREST DEFENCE", wall = "WALLS FIRST"}
const BUY := "buy:"
const FIGURE := "figure:"
const NEWS := "news:"
const TRAINEE := "trainee:"
## The grey trainee's figure on the art round its Trainee mark (px): it stands up from its feet.
const TRAINEE_BOX := Rect2(-45.0, -120.0, 90.0, 125.0)
## What the ¶ mark on a column means (its hint slip).
const NEWS_HINT := "Development available: the Findings on hand cover at least one item of this programme below."
const DENIED_RED := Color(0.9, 0.12, 0.08)
const BLINK_TIME := 0.12
## A figure just requisitioned jumps to this size and settles.
const JUMP := 1.25
const JUMP_TIME := 0.4
## The trainee: this many times its fighting size; it lands from TRAINEE_DROP m above in DROP_TIME s,
## and jumps into the big figure over JUMP_OVER s, JUMP_HEIGHT m high at the top of its arc.
const TRAINEE_SCALE := 0.9
const TRAINEE_DROP := 0.25
const DROP_TIME := 0.3
const JUMP_OVER := 0.45
const JUMP_HEIGHT := 0.18
## The count under the big figure swells this much when it goes up.
const BUMP := 1.3
## fit never prints smaller than this (px).
const MIN_FIT := 16

## The unpainted plastic of a figure still in training.
@export var grey_plastic: Material

## Each unit's column and figure (every unit IN_SERVICE; the hired ones are shown).
var _columns: Dictionary[String, Control] = {}
var _figures: Dictionary[String, Node3D] = {}
var _trainees: Dictionary[String, Node3D] = {}
var _jumpers: Dictionary[String, Node3D] = {}
## Each unit's figure_size: its figure, trainee and jumper are printed that much smaller.
var _sizes: Dictionary[String, float] = {}
## What each unit's trainee showed last (queue length, figures ready): changes play its moments.
var _seen: Dictionary[String, Vector2i] = {}
var _landing: Dictionary[String, Tween] = {}
var _turning: Dictionary[String, Tween] = {}
var _hot := &""
var _printed := ""
var _blinking: Tween
## The research tree when the mouse is in it (null: not).
var _tree_in: UpgradeTree

@onready var _staff: Label = $Page/Sheet/Staff
@onready var _sheet_root: Control = $Page/Sheet
@onready var _tree: UpgradeTree = $Page/Sheet/Tree
@onready var _denied_sound: SoundCue = $Denied
@onready var _research_sound: SoundCue = $Research
@onready var _hire_sound: SoundCue = $Hire
@onready var _jam_sound: SoundCue = $Jam
@onready var _land_sound: SoundCue = $Land
@onready var _hop_sound: SoundCue = $Hop


func _ready() -> void:
	for unit in Depot.IN_SERVICE:
		_build(unit)
	_tree.bought.connect(_approved)
	_tree.denied.connect(func() -> void: _denied_sound.cue(global_position))
	_tree.rules = DepotResearch
	_tree.home(TREE_ZOOM, 0.0)
	super()  # The figures are things on the sheet: they tuck away and pop up with it.
	refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	_page.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for unit in Depot.units(SaveManager.save):
		_train(unit, true)
	if _state(SaveManager.save, _out()) != _printed:
		refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_printed = ""
		refresh()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		if not visible:  # Put away (kept): the page stops printing every frame.
			_page.render_target_update_mode = SubViewport.UPDATE_DISABLED
			return
		for unit in Depot.units(SaveManager.save):  # Training went on while it was away: no moments for it.
			_train(unit, false)
		refresh()


## Everything the page prints for `save`, as one string: when it changes, the page is printed again
## (the seconds of training left only in whole seconds).
static func _state(save: SaveGame, out: Vector2i) -> String:
	var parts := [save.army, save.army_training.size(), WarRules.army_cap(save), save.unit_research, Depot.units(save),
			DepotResearch.drawn_key(save)]
	if not save.army_training.is_empty():
		parts.append([save.army_training[0].unit, ceili(float(save.army_training[0].left))])
	for unit in Depot.units(save):
		parts.append(WarRules.can_buy(save, unit, out))
		parts.append(WarRules.unit_stats(save, unit))
	return var_to_str(parts)


## What a column's note under its REQUISITION box says for `save` (a key; "": it can be bought).
static func refusal(save: SaveGame, unit: String, out := Vector2i.ZERO) -> String:
	if not WarRules.fits(save, unit):
		return "STAFF AT CAPACITY"
	if UpgradeDesk.spendable(save, "stock", out) < WarRules.unit_cabbage_price(unit):
		return "NOT ENOUGH CABBAGES"
	return ""


## `unit`'s figures in training for `save`, front of the queue first, each 0..1 through its training
## (only the front one trains): the trainee, its line and its "+N".
static func training_of(save: SaveGame, unit: String) -> Array[float]:
	var out: Array[float] = []
	for i in save.army_training.size():
		var entry: Dictionary = save.army_training[i]
		if entry.unit == unit:
			var total := float(entry.get("total", WarRules.training_seconds(save, unit)))  # Old saves: no total kept.
			out.append(clampf(1.0 - float(entry.left) / total, 0.0, 1.0) if i == 0 else 0.0)
	return out


## The width of a training bar's fill at `progress` (0..1): the track `track` px wide, inset `inset`
## px on each side by its inked frame.
static func bar_fill(track: float, inset: float, progress: float) -> float:
	return maxf(track - 2.0 * inset, 0.0) * clampf(progress, 0.0, 1.0)


## Whole seconds `unit`'s trainee still trains for `save` (-1: none of its figures is training now:
## its queue is empty or waits behind another unit's).
static func seconds_left(save: SaveGame, unit: String) -> int:
	if save.army_training.is_empty() or save.army_training[0].unit != unit:
		return -1
	return ceili(float(save.army_training[0].left))


## Seconds until `unit`'s next figure is ready for `save`: what the queue in front of it still trains,
## and its own training (0: nothing of it in training).
static func ready_in(save: SaveGame, unit: String) -> float:
	var wait := 0.0
	for entry: Dictionary in save.army_training:
		wait += float(entry.left)
		if entry.unit == unit:
			return wait
	return 0.0


## Prints the whole page as the save has it.
func refresh() -> void:
	var save := SaveManager.save
	var out := _out()
	_printed = _state(save, out)
	var shown := Depot.units(save)
	_staff.text = tr("STAFF %d / %d") % [WarRules.army_size(save), WarRules.army_cap(save)]
	fit(_staff)
	var x := COLUMN_LEFT
	for unit: String in _columns:
		var column := _columns[unit]
		column.visible = shown.has(unit)
		if not column.visible:
			_figures[unit].hide()
			_trainees[unit].hide()
			continue
		column.position = Vector2(x, COLUMN_TOP)
		x += COLUMN_WIDTH + COLUMN_GAP
		(column.get_node("News") as Control).visible = has_news(save, unit)
		var stage := _stage(unit)
		var figure: Node3D = _figures[unit]
		var i := _standing.find(figure)
		if open > 0.0 and i >= 0 and figure.scale.x > _stand_scale[i].x * 0.002:
			figure.show()  # Hired while the sheet lies open: it stands raised as the others (raise_thing hid it).
		_figures[unit].position = Vector3(stage.x / PIXELS_PER_METRE - SIZE.x / 2.0, _figures[unit].position.y, stage.y / PIXELS_PER_METRE)
		_train(unit, false)  # The trainee on its place, as the queue stands.
		_print_column(save, unit, column, out)
	reprint()


## Whether one of `unit`'s research nodes can be bought for `save` now (its column's ¶ mark).
static func has_news(save: SaveGame, unit: String) -> bool:
	for node: Dictionary in DepotResearch.ALL:
		if DepotResearch.unit_of(node.id) == unit and DepotResearch.can_buy(node.id, save):
			return true
	return false


## `label` printed at the size its scene gives it, or smaller (steps of 2 px) until its text fits its
## box: its width on one line, or width and height wrapped if the label wraps (a word is never split).
static func fit(label: Label) -> void:
	var base: int = label.get_meta(&"base_size", label.get_theme_font_size(&"font_size"))
	label.set_meta(&"base_size", base)
	var size := base
	while size > MIN_FIT and not fits(label, size):
		size -= 2
	label.add_theme_font_size_override(&"font_size", size)


## Whether `label`'s text fits its box at font size `size` (as fit).
static func fits(label: Label, size: int) -> bool:
	var font := label.get_theme_font(&"font")
	var text := label.tr(label.text) if label.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else label.text
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= label.size.x
	var drawn := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, size)
	return drawn.x <= label.size.x and drawn.y <= label.size.y


## One figure of `unit` requisitioned for `save`: its cabbages paid, queued for training (WarRules.buy),
## logged and saved, the button's stamp; its trainee lands if it is the front. Refused: the jam, the
## button and the note under it blink. Whether it was bought. The only way to buy a figure (the
## HIRE AND TRAIN button calls it).
func requisition(unit: String) -> bool:
	if not WarRules.buy(SaveManager.save, unit, _out()):
		_jam_sound.cue(global_position)
		_refused(_columns[unit].get_node("Note"), _columns[unit].get_node("Hire"))
		return false
	SaveManager.log_event("staff", unit, WarRules.unit_cabbage_price(unit), "stock")
	SaveManager.autosave()
	_hire_sound.cue(global_position)
	_train(unit, true)
	refresh()
	return true


func spot_at(pixel: Vector2) -> StringName:
	for unit in Depot.units(SaveManager.save):
		var news := _columns[unit].get_node("News") as Control
		if news.visible and _art_rect(news).grow(6.0).has_point(pixel):
			return StringName(NEWS + unit)
		if not training_of(SaveManager.save, unit).is_empty() and _trainee_box(unit).has_point(pixel):
			return StringName(TRAINEE + unit)
		var hire := _art_rect(_columns[unit].get_node("Hire"))
		if pixel.distance_to(hire.get_center()) < hire.size.x / 2.0:
			return StringName(BUY + unit)
		if pixel.distance_to(_stage(unit)) < FIGURE_HIT:
			return StringName(FIGURE + unit)
	return &""


func hint(spot: StringName) -> String:
	var save := SaveManager.save
	var what := String(spot)
	if what.begins_with(NEWS):
		return tr(NEWS_HINT)
	if what.begins_with(TRAINEE):
		var queue := training_of(save, what.trim_prefix(TRAINEE)).size()
		var soon := tr("IN TRAINING. Available for deployment in %d s.") % ceili(ready_in(save, what.trim_prefix(TRAINEE)))
		return soon + (" " + tr("%d more awaiting induction.") % (queue - 1) if queue > 1 else "")
	if not what.begins_with(BUY):
		return ""
	var unit := what.trim_prefix(BUY)
	var text := tr("Requisition one %s: %s cabbages, %d s of training.") % [tr(CALLED[unit]),
			FarmScreen._thousands(WarRules.unit_cabbage_price(unit)), ceili(WarRules.training_seconds(save, unit))]
	var why := refusal(save, unit, _out())
	if why == "STAFF AT CAPACITY":
		text += " " + tr("Staff at capacity: %d / %d.") % [WarRules.army_size(save), WarRules.army_cap(save)]
	elif why != "":
		text += " " + tr("Short: %s cabbages.") % FarmScreen._thousands(WarRules.unit_cabbage_price(unit) - UpgradeDesk.spendable(save, "stock", _out()))
	return text


## What spot `spot` covers of the art (px), for the hint slip to lie beside it (MapTable.beside): a
## HIRE AND TRAIN button with its price, refusal note and the trainee's bar under it (the slip never
## hides them), or a column's ¶ mark.
func spot_box(spot: StringName) -> Rect2:
	var what := String(spot)
	if what.begins_with(NEWS):
		return _art_rect(_columns[what.trim_prefix(NEWS)].get_node("News"))
	if what.begins_with(TRAINEE):
		var bar := _columns[what.trim_prefix(TRAINEE)]
		var figure := _trainee_box(what.trim_prefix(TRAINEE))
		for part: String in ["Line", "Left", "More"]:
			figure = figure.merge(_art_rect(bar.get_node(part)))
		return figure
	if not what.begins_with(BUY):
		return Rect2()
	var column := _columns[what.trim_prefix(BUY)]
	var box := _art_rect(column.get_node("Hire"))
	for part: String in ["Price", "Note", "Line", "Left", "More"]:
		box = box.merge(_art_rect(column.get_node(part)))
	return box


## Where a slip without a spot_box would lie (none here: every spot with words has its box): the
## title block.
func hint_pixel() -> Vector2:
	return Vector2(2500.0, 1100.0)


func hover(spot: StringName) -> void:
	if spot == _hot:
		return
	var was := String(_hot)
	_hot = spot
	for unit: String in _columns:  # The button under the mouse is inked darker.
		(_columns[unit].get_node("Hire") as Control).self_modulate = Color(0.86, 0.86, 0.84) if spot == StringName(BUY + unit) else Color.WHITE
	if was.begins_with(FIGURE):
		_turn(was.trim_prefix(FIGURE), false)
	if String(spot).begins_with(FIGURE):
		_turn(String(spot).trim_prefix(FIGURE), true)
	reprint()


## A click on a HIRE AND TRAIN button hires one figure of its unit.
func press(spot: StringName) -> void:
	if String(spot).begins_with(BUY):
		requisition(String(spot).trim_prefix(BUY))


## The map table's mouse at art pixel `pixel`: taken (true) while it is over a research tree (or a
## hold or pan begun there), handed into the page for the tree; else left to spot_at and press.
func take_mouse(event: InputEventMouse, pixel: Vector2) -> bool:
	var over: UpgradeTree = _tree if _art_rect(_tree).has_point(pixel) else null
	var held := _tree_in != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not event is InputEventMouseButton
	if over == null and not held:
		if _tree_in != null:
			_page.notification(NOTIFICATION_VP_MOUSE_EXIT)
			_tree_in = null
		return false
	if over != null and _tree_in == null:
		_page.notification(NOTIFICATION_VP_MOUSE_ENTER)
	if over != null:
		_tree_in = over
	var inner := event.duplicate() as InputEventMouse
	inner.position = _sheet_root.get_global_transform() * pixel
	inner.global_position = inner.position
	_page.push_input(inner, true)
	return true


## A locked figure stays hidden however the sheet pops its things up, and so do a trainee with
## nobody in training and the jumper (it only shows mid-jump).
func raise_thing(k: float, i: int) -> void:
	super(k, i)
	var thing := _standing[i]
	var unit := String(thing.get_meta(&"unit", ""))
	var role := String(thing.get_meta(&"role", ""))
	if not Depot.units(SaveManager.save).has(unit) or role == "jumper" 			or (role == "trainee" and training_of(SaveManager.save, unit).is_empty()):
		thing.hide()


func _build(unit: String) -> void:
	var column: Control = COLUMN.instantiate()
	column.name = unit
	$Page/Sheet/Columns.add_child(column)
	_columns[unit] = column
	(column.get_node("Name") as Label).text = NAMES[unit]
	var figure: Node3D = (load(SOLDIER % unit) as PackedScene).instantiate()
	figure.name = unit
	figure.set_meta(&"unit", unit)
	$Things.add_child(figure)
	_sizes[unit] = figure_size(figure)
	figure.scale = Vector3.ONE * FIGURE_SCALE * _sizes[unit]
	_figures[unit] = figure
	for role: String in ["trainee", "jumper"]:  # The one in training, and the one jumping over.
		var grey: Node3D = (load(SOLDIER % unit) as PackedScene).instantiate()
		grey.name = "%s_%s" % [role, unit]
		grey.set_meta(&"unit", unit)
		grey.set_meta(&"role", role)
		grey.scale = Vector3.ONE * TRAINEE_SCALE * _sizes[unit]
		(grey.get_node("Model") as GeometryInstance3D).material_override = grey_plastic
		$Things.add_child(grey)
		grey.hide()
		(_trainees if role == "trainee" else _jumpers)[unit] = grey
	_train(unit, false)


## How much smaller than FIGURE_SCALE `figure` (at its fighting size, in the tree) is printed so its
## footprint on the paper is at most FIGURE_FOOT m across: 1 for the small ones.
static func figure_size(figure: Node3D) -> float:
	var model := figure.get_node("Model") as VisualInstance3D
	var box := (figure.global_transform.affine_inverse() * model.global_transform) * model.get_aabb()
	return minf(1.0, FIGURE_FOOT / (FIGURE_SCALE * maxf(box.size.x, box.size.z)))


## `unit`'s trainee as the save has it: shown with its line and "+N" while its queue is not empty.
## `moments`: a new front lands, and a figure that joined the ready ones jumps into the big figure
## (off when the sheet is set up: a loaded save shows what is, without the moments).
func _train(unit: String, moments: bool) -> void:
	var save := SaveManager.save
	var queue := training_of(save, unit)
	var now := Vector2i(queue.size(), int(save.army.get(unit, 0)))
	var was: Vector2i = _seen.get(unit, now)
	_seen[unit] = now
	var column := _columns[unit]
	var trainee := _trainees[unit]
	var at := _art_to_local(column.position + (column.get_node("Trainee") as Control).position)
	var line := column.get_node("Line") as Control
	var fill := line.get_node("Fill") as Control
	fill.size.x = bar_fill(line.size.x, fill.position.x, queue[0] if not queue.is_empty() else 0.0)
	line.visible = not queue.is_empty()
	var left := column.get_node("Left") as Label
	var seconds := seconds_left(save, unit)
	left.visible = seconds >= 0
	left.text = "%d s" % seconds
	var more := column.get_node("More") as Label
	more.visible = queue.size() > 1
	more.text = "+%d" % (queue.size() - 1)
	if not moments or not visible:
		trainee.visible = not queue.is_empty() and column.visible
		if not (_landing.has(unit) and _landing[unit].is_running()):
			trainee.position = at
		return
	if now.y > was.y:
		_jump(unit, trainee.position if trainee.visible else at)
		trainee.hide()
	var landing := not queue.is_empty() and (not trainee.visible or now.y > was.y)
	if landing:
		_land(unit, at)
	elif queue.is_empty() and trainee.visible:
		trainee.hide()


## A new trainee drops onto its place with a little bounce.
func _land(unit: String, at: Vector3) -> void:
	var trainee := _trainees[unit]
	trainee.show()
	trainee.position = at + Vector3.UP * TRAINEE_DROP
	_landing[unit] = create_tween()
	_landing[unit].tween_property(trainee, "position", at, DROP_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_land_sound.cue(global_position)


## A finished trainee jumps from `from` into the big figure; the count under it bumps.
func _jump(unit: String, from: Vector3) -> void:
	var jumper := _jumpers[unit]
	var to := _figures[unit].position
	jumper.position = from
	jumper.show()
	_hop_sound.cue(global_position)
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		jumper.position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * JUMP_HEIGHT
		jumper.scale = Vector3.ONE * lerpf(TRAINEE_SCALE, FIGURE_SCALE, k) * _sizes[unit], 0.0, 1.0, JUMP_OVER).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(jumper.hide)
	tween.tween_callback(_bump.bind(unit))


## The count under the big figure swells and settles; the big figure jumps.
func _bump(unit: String) -> void:
	var count := _columns[unit].get_node("Ready") as Control
	count.pivot_offset = count.size / 2.0
	create_tween().tween_property(count, "scale", Vector2.ONE, JUMP_TIME).from(Vector2.ONE * BUMP) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(_figures[unit], "scale", Vector3.ONE * FIGURE_SCALE * _sizes[unit], JUMP_TIME).from(Vector3.ONE * FIGURE_SCALE * JUMP * _sizes[unit]) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	refresh()


## Art pixel `pixel` as a point on the sheet (its Things' space), on the paper.
func _art_to_local(pixel: Vector2) -> Vector3:
	return Vector3(pixel.x / PIXELS_PER_METRE - SIZE.x / 2.0, 0.0, pixel.y / PIXELS_PER_METRE)


## A research node bought on the tree (held): logged, saved, its stamp.
func _approved(node_id: String, paid: int) -> void:
	SaveManager.log_event("staff_research", node_id, paid, UpgradeTree.currency_of(DepotResearch.node_data(node_id)))
	SaveManager.autosave()
	_research_sound.cue(global_position)
	refresh()


## Figure `unit` lifts and turns to the camera (`up`), or settles back on its stage.
func _turn(unit: String, up: bool) -> void:
	var figure := _figures[unit]
	if _turning.has(unit):
		_turning[unit].kill()
	var to := Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if up and camera != null:
		var look := ($Things as Node3D).global_basis.inverse() * (camera.global_position - figure.global_position)
		to = Vector3(-atan2(look.y, Vector2(look.x, look.z).length()) * FIGURE_LEAN, atan2(look.x, look.z), 0.0)
	_turning[unit] = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turning[unit].tween_property(figure, "position:y", FIGURE_LIFT if up else 0.0, FIGURE_TIME)
	_turning[unit].tween_property(figure, "rotation", to, FIGURE_TIME)


## What `unit`'s grey trainee covers on the art (px).
func _trainee_box(unit: String) -> Rect2:
	var column := _columns[unit]
	return Rect2(column.position + (column.get_node("Trainee") as Control).position + TRAINEE_BOX.position, TRAINEE_BOX.size)


## Where `unit`'s figure stands on the art (px): its column's Stage.
func _stage(unit: String) -> Vector2:
	var column := _columns[unit]
	return column.position + (column.get_node("Stage") as Control).position


func _print_column(save: SaveGame, unit: String, column: Control, out: Vector2i) -> void:
	(column.get_node("Name") as Label).text = tr(NAMES[unit])
	var stats := WarRules.unit_stats(save, unit)
	(column.get_node("Hp/Text") as Label).text = tr("HP %d") % roundi(stats.hp)
	(column.get_node("Damage/Text") as Label).text = tr("DAMAGE %d") % roundi(stats.damage)
	(column.get_node("Speed/Text") as Label).text = tr("SPEED %s") % String.num(stats.speed, 1)
	(column.get_node("Target/Text") as Label).text = tr(TARGETS[stats.target])
	(column.get_node("Ready") as Label).text = "%d×" % int(save.army.get(unit, 0))  # Ready, under the figure: a count on a game piece.
	(column.get_node("Price/Amount") as Label).text = FarmScreen._thousands(WarRules.unit_cabbage_price(unit))  # After the cabbage icon.
	var why := refusal(save, unit, out)
	(column.get_node("Note") as Label).text = tr(why) if why != "" else ""
	for label: String in ["Name", "Hire/Word", "Note", "Hp/Text", "Damage/Text", "Speed/Text", "Target/Text"]:
		fit(column.get_node(label) as Label)


## Where control `c` lies on the art (px).
func _art_rect(c: Control) -> Rect2:
	return Rect2(_sheet_root.get_global_transform().affine_inverse() * c.get_global_transform().origin, c.size)


## `label` (why it was refused) and the `button` flash red twice.
func _refused(label: Label, button: Control) -> void:
	if _blinking != null:
		_blinking.kill()
	var ink := label.get_theme_color(&"font_color")
	_blinking = create_tween()
	for colour: Color in [DENIED_RED, ink, DENIED_RED, ink]:
		_blinking.tween_callback(func() -> void:
			label.add_theme_color_override(&"font_color", colour)
			button.modulate = Color.WHITE.lerp(DENIED_RED, 0.5) if colour == DENIED_RED else Color.WHITE)
		_blinking.tween_interval(BLINK_TIME)


## The stock cabbages out of the chute: they cannot pay (UpgradeDesk.units_out).
func _out() -> Vector2i:
	return UpgradeDesk.units_out(get_tree().get_nodes_in_group(&"cabbages")) if is_inside_tree() else Vector2i.ZERO
