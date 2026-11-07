extends CanvasLayer
## Memos (also the game's Steam achievements): each entry in MEMOS has a condition on the save. Every
## CHECK_EVERY seconds the first one met and not yet filed is filed (its id goes into save.milestones),
## its bonus (if any) applied once, logged, pushed to Steam (SteamAchievements), and a paper memo
## slides up from the bottom edge, gets stamped, and after HOLD seconds flies into the FILES folder
## (a click on it removes it at once). Several due at once queue up. A memo filed makes the folder
## glow softly until it is clicked or GLOW_TIME seconds pass. The game keeps running; only the paper's own rect takes the mouse.
## Memos already met when the scene loads (an old save meeting new memos) are filed without the paper.
## The FILES folder, a 3D manila folder lying in the desk's bottom-right corner (once a memo is
## filed), opens on hover a little and, clicked, shows every memo as a grid of paper cards on a dark
## shade: the filed ones newest first, then the ones not yet filed, greyed and stamped CLASSIFIED.
## An X in the top-right corner, a click outside the cards or Esc closes it.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const BODY_FONT := preload("res://assets/fonts/NunitoSans.ttf")
const PAPER := Color(0.72, 0.73, 0.69)
const INK := Color(0.13, 0.15, 0.14)
const STAMP := Color(0.55, 0.12, 0.1)
## The only saturated colours: the cabbage's green, and research's cold cyan.
const CABBAGE := Color(0.42, 0.68, 0.25)
const CYAN := Color(0.35, 0.85, 0.95)

## id: save key and, upper-cased, the Steam achievement API name (never rename one). re: the title.
## how: how to file it. Condition, one of: `stat` (a save number) at least `at`; `card` stamped on the
## upgrade desk ("*" every card); `node` bought on the projector. Optional bonus: the save number
## `key` multiplied by `mul` (times-only, so it stacks with upgrades) and its text `bonus`.
## note: the memo's line. icon: the glyph on its card (_draw_icon).
const MEMOS := [
	{id = "units_10", stat = "sold", at = 10, re = "10 UNITS MOVED", how = "Sell 10 units.", icon = "cabbage",
		note = "Ten units have left the building. This has been noted in triplicate."},
	{id = "units_25", stat = "sold", at = 25, key = "marketing", mul = 1.25, re = "25 UNITS MOVED", how = "Sell 25 units.",
		icon = "cabbage", note = "Your output has been observed.", bonus = "The street accepts prices 25% higher."},
	{id = "units_100", stat = "sold", at = 100, key = "findings_per_cabbage", mul = 2, re = "100 UNITS MOVED",
		how = "Sell 100 units.", icon = "cabbage", note = "Management notes your contribution.",
		bonus = "The research lab files twice the Findings."},
	{id = "units_250", stat = "sold", at = 250, key = "associate_speed", mul = 1.5, re = "250 UNITS MOVED",
		how = "Sell 250 units.", icon = "cabbage", note = "Associates were reminded that walking is billable.",
		bonus = "Hired hands move 50% faster."},
	{id = "units_1000", stat = "sold", at = 1000, key = "hand_output", mul = 1.5, re = "1,000 UNITS MOVED",
		how = "Sell 1,000 units.", icon = "cabbage", note = "The board has been informed. It did not respond.",
		bonus = "Hired hands make 50% more trips."},
	{id = "units_2500", stat = "sold", at = 2500, key = "associate_speed", mul = 1.5, re = "2,500 UNITS MOVED",
		how = "Sell 2,500 units.", icon = "cabbage", note = "Your figures have been laminated.",
		bonus = "Hired hands move 50% faster."},
	{id = "units_10000", stat = "sold", at = 10000, key = "marketing", mul = 2.0, re = "10,000 UNITS MOVED",
		how = "Sell 10,000 units.", icon = "cabbage", note = "A plaque is under consideration.",
		bonus = "The street accepts prices twice as high."},
	{id = "units_50000", stat = "sold", at = 50000, re = "50,000 UNITS MOVED", how = "Sell 50,000 units.",
		icon = "cabbage", note = "The plaque has been reconsidered."},
	{id = "coins_1000", stat = "coins", at = 1000, re = "$1,000 ON HAND", how = "Hold $1,000 at once.",
		icon = "coin", note = "Liquidity has been detected at your desk."},
	{id = "coins_10000", stat = "coins", at = 10000, re = "$10,000 ON HAND", how = "Hold $10,000 at once.",
		icon = "coin", note = "Accounts asks that you stop counting it aloud."},
	{id = "coins_100000", stat = "coins", at = 100000, re = "$100,000 ON HAND", how = "Hold $100,000 at once.",
		icon = "coin", note = "This sum is now the property of a spreadsheet."},
	{id = "catches_1", stat = "catches", at = 1, re = "UNIT INTERCEPTED", how = "Catch a unit as it leaves the chute.",
		icon = "catch", note = "Gravity has been overruled. Gravity has been informed."},
	{id = "catches_50", stat = "catches", at = 50, re = "50 INTERCEPTIONS", how = "Catch 50 units in mid-air.",
		icon = "catch", note = "Your reflexes are company property."},
	{id = "catches_500", stat = "catches", at = 500, re = "500 INTERCEPTIONS", how = "Catch 500 units in mid-air.",
		icon = "catch", note = "The chute has filed a complaint."},
	{id = "refusals_1", stat = "refusals", at = 1, re = "UNIT REFUSED", how = "Have the street refuse a unit.",
		icon = "window", note = "The street has an opinion. It is not binding."},
	{id = "refusals_100", stat = "refusals", at = 100, re = "100 REFUSALS", how = "Have the street refuse 100 units.",
		icon = "window", note = "Pricing remains your responsibility."},
	{id = "price_10", stat = "sale_price", at = 10, re = "PREMIUM POSITIONING", how = "Chalk a price of $10 or more.",
		icon = "coin", note = "The unit has not changed. Its story has."},
	{id = "hands_1", stat = "hands", at = 1, re = "FIRST HIRE", how = "Hire an associate.",
		icon = "hand", note = "You are now responsible for another person. Sign here."},
	{id = "hands_10", stat = "hands", at = 10, re = "FULL HEADCOUNT", how = "Employ 10 associates.",
		icon = "hand", note = "Ten associates. None of them have names on file."},
	{id = "findings_1", stat = "findings", at = 1, re = "FIRST FINDING", how = "File a Finding in the research lab.",
		icon = "lens", note = "Something has been found. Nobody asked what."},
	{id = "findings_1000", stat = "findings", at = 1000, re = "1,000 FINDINGS ON FILE", how = "Hold 1,000 Findings at once.",
		icon = "lens", note = "The filing cabinet has been extended."},
	{id = "research_directive", card = "research_inspection", re = "FIRST RESEARCH DIRECTIVE",
		how = "Stamp the first research directive.", icon = "stamp", note = "The inspection will be inspected."},
	{id = "research_units_1", stat = "research_units", at = 1, re = "RESEARCH UNIT ANALYSED",
		how = "Have the research lab analyse a research unit.", icon = "research", note = "It was blue. It is now data."},
	{id = "minis_1000", stat = "minis_sold", at = 1000, re = "1,000 MINIATURE UNITS", how = "Sell 1,000 mini units.",
		icon = "mini", note = "The units are small. So are the margins."},
	{id = "lever_split", stat = "tube_split", at = 0.5, re = "OUTPUT DIVERTED", how = "Divert tube minis to research (lever on SPLIT or RESEARCH).",
		icon = "lever", note = "Half of everything now goes somewhere else."},
	{id = "fines_1", stat = "fines", at = 1, re = "FIRST FINE", how = "Sell a rotten unit.",
		icon = "bin", note = "The deduction has been made. The lesson has not."},
	{id = "binned_100", stat = "binned", at = 100, re = "100 UNITS DISPOSED", how = "Bin 100 rotten units.",
		icon = "bin", note = "Waste is a process. You are the process."},
	{id = "quotas_1", stat = "quotas_met", at = 1, re = "QUOTA MET", how = "Meet a manager's quota.",
		icon = "chart", note = "Expectations have been adjusted upward."},
	{id = "quotas_25", stat = "quotas_met", at = 25, re = "25 QUOTAS MET", how = "Meet 25 of the manager's quotas.",
		icon = "chart", note = "The manager has started to rely on you. This is not a compliment."},
	{id = "songs_20", stat = "songs_skipped", at = 20, re = "20 SONGS SKIPPED", how = "Skip 20 songs on the radio.",
		icon = "radio", note = "Your taste in music has been entered into your file."},
	{id = "radio_silent", stat = "radio_silent", at = 3600, re = "ONE HOUR OF SILENCE",
		how = "Keep the radio off for an hour in total.", icon = "radio", note = "Silence is also productivity."},
	{id = "double_findings", node = "double_findings", re = "METHODOLOGY DOUBLED",
		how = "Buy DOUBLE FINDINGS on the projector.", icon = "tree", note = "Twice the findings. The same questions."},
	{id = "slogan_6", node = "slogan_6", re = "MESSAGING FINALISED", how = "Buy the last slogan on the projector.",
		icon = "tree", note = "There is nothing left to say about cabbage."},
	{id = "every_card", card = "*", re = "INBOX ZERO", how = "Stamp every card on the upgrade desk.",
		icon = "stamp", note = "There is nothing left to approve. Please wait for something."},
]
## The paper's line under a memo without a bonus.
const NO_BONUS := "No action is required. None will be taken."
## Seconds between checks for a memo come due.
const CHECK_EVERY := 0.5
const SIZE := Vector2(560, 250)
const IN_TIME := 0.35
## Seconds the paper takes to fly into the folder, and its scale on arrival.
const FLY_TIME := 0.55
const FLY_SCALE := 0.08
const HOLD := 6.0
const STAMP_AT := 0.7
## One card in the FILES grid.
const CARD := Vector2(540, 150)
## The FILES view's close button (px square), in its top-right corner.
const CLOSE := 40.0
## The FILES folder on the desk: hover animation seconds, how far the cover opens (rad), the
## papers rise (m) and it grows hovered, and its glow band's brightest emission.
const HOVER_TIME := 0.15
const COVER_OPEN := 0.3
const PAPERS_RISE := 0.006
const HOVER_GROW := 0.06
const GLOW_ENERGY := 2.4
const GLOW := Color(0.85, 0.86, 0.78)
## Seconds the folder glows after a memo is filed, and one pulse's seconds.
const GLOW_TIME := 45.0
const GLOW_PULSE := 1.8

var _queue: Array[Dictionary] = []
var _memo := {}
var _t := 0.0
## Where the paper's centre rests once up, and where the folder takes it (screen px).
var _rest := Vector2.ZERO
var _glow_left := 0.0
var _clock := 0.0
## Whether the mouse is on the folder (what the hover eases back to after a flick).
var _hovered := 0.0
var _stamped := false
var _check_in := 0.0
## 0 rest .. 1 hovered: the folder's cover lifts, its papers rise, it grows a little.
var _hover := 0.0
var _hovering: Tween
## The glow band's own material (the model's surface 1), its emission driven by glow_at().
var _glow: StandardMaterial3D

@onready var _paper: Control = $Paper
@onready var _folder: Node3D = $Folder
@onready var _folder_model: Node3D = $Folder/Model
@onready var _skeleton: Skeleton3D = $Folder/Model/Armature/Skeleton3D
@onready var _cover := _skeleton.find_bone("CoverHinge")
@onready var _papers := _skeleton.find_bone("Papers")
@onready var _files: CanvasLayer = $Files
@onready var _shade: Control = $Files/Shade
@onready var _list: Control = $Files/Shade/List
@onready var _grid: Control = $Files/Shade/List/Grid


func _ready() -> void:
	_paper.size = SIZE
	_paper.pivot_offset = SIZE / 2.0
	_paper.rotation = deg_to_rad(-1.5)
	_paper.visible = false
	_paper.draw.connect(_draw_paper)
	_paper.gui_input.connect(_on_paper_input)
	var hit: Interactable = $Folder/Hit/Interactable
	hit.grabbed.connect(_open_files)
	hit.hovered.connect(_on_folder_hover.bind(1.0))
	hit.unhovered.connect(_on_folder_hover.bind(0.0))
	var band: MeshInstance3D = $Folder/Model/Armature/Skeleton3D/files_folder
	_glow = band.get_active_material(1).duplicate()
	_glow.emission_enabled = true
	_glow.emission = GLOW
	band.set_surface_override_material(1, _glow)
	_set_hover(0.0)
	_shade.draw.connect(_draw_shade)
	_shade.gui_input.connect(_on_shade_input)
	_files.visible = false
	_file_due(false)
	SteamAchievements.sync(SaveManager.save.milestones)


func _process(delta: float) -> void:
	_clock += delta
	if _glow_left > 0.0:
		_glow_left -= delta
	_glow.emission_energy_multiplier = GLOW_ENERGY * glow_at(_glow_left, _clock)
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = CHECK_EVERY
		_file_due(true)
		_folder.visible = not SaveManager.save.milestones.is_empty()
		$Folder/Hit/Interactable.enabled = _folder.visible and not _files.visible
	if _memo.is_empty():
		if _queue.is_empty():
			_paper.visible = false
			return
		_memo = _queue.pop_front()
		_t = 0.0
		_stamped = false
		_paper.visible = true
		$Land.play()
	_t += delta
	if not _stamped and _t >= STAMP_AT:
		_stamped = true
		$Stamp.play()
	var view := get_viewport().get_visible_rect().size
	_rest = Vector2(view.x * 0.5, view.y - SIZE.y * 0.5 - 40.0)
	var centre := _rest.lerp(_rest + Vector2(0, SIZE.y + 70.0), 1.0 - slide_at(_t))
	var p := clampf((_t - HOLD) / FLY_TIME, 0.0, 1.0)
	if p > 0.0:
		centre = fly_at(p, _rest, get_viewport().get_camera_3d().unproject_position(_folder.global_position))
	var size := lerpf(1.0, FLY_SCALE, ease(p, 2.0))
	_paper.scale = Vector2(size, size)
	_paper.rotation = deg_to_rad(lerpf(-1.5, 14.0, p))
	_paper.position = centre - SIZE * 0.5
	_paper.queue_redraw()
	if p >= 1.0:
		# Tucked in: the folder's cover flicks open and shut.
		_memo = {}
		$Rustle.play()
		_hover_to(1.0, func() -> void: _hover_to(_hovered))


## Files every memo come due: applied, logged, sent to Steam, and queued for the paper if `with_paper`.
func _file_due(with_paper: bool) -> void:
	var save := SaveManager.save
	var m := due(save)
	while not m.is_empty():
		apply(save, m)
		SaveManager.log_event("milestone", m.id)
		SteamAchievements.unlock(m.id)
		if with_paper:
			_queue.append(m)
			_glow_left = GLOW_TIME
		m = due(save)


func _unhandled_input(event: InputEvent) -> void:
	if _files.visible and event.is_action_pressed("ui_cancel"):
		_files.visible = false
		get_viewport().set_input_as_handled()


## Queues a memo from elsewhere (the manager's performance concern): `re`, `note` and `bonus` as in
## MEMOS, nothing applied.
func post(m: Dictionary) -> void:
	_queue.append(m)


func _on_paper_input(event: InputEvent) -> void:
	if _clicked(event):
		_memo = {}
		_paper.visible = false
		_paper.accept_event()


## The folder clicked: every memo as a card on the dark shade.
func _open_files() -> void:
	_glow_left = 0.0
	for card in _grid.get_children():
		card.free()
	for m in files_order(SaveManager.save):
		var card := Control.new()
		card.custom_minimum_size = CARD
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.draw.connect(_draw_card.bind(card, m))
		_grid.add_child(card)
	_list.scroll_vertical = 0
	_shade.queue_redraw()
	_files.visible = true


## A click on the X or on the shade outside the cards closes the files (the shade keeps it from the desk).
func _on_shade_input(event: InputEvent) -> void:
	var at := _shade.get_global_mouse_position()
	if _clicked(event) and (_close_rect().has_point(at) or not _list.get_global_rect().intersection(_grid.get_global_rect()).has_point(at)):
		_files.visible = false


## The close X's rect on the shade, top right.
func _close_rect() -> Rect2:
	return Rect2(_shade.size.x - CLOSE - 24.0, 24.0, CLOSE, CLOSE)


static func _clicked(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT


## Whether memo `m`'s condition holds in `save`.
static func met(save: SaveGame, m: Dictionary) -> bool:
	if m.has("card"):
		if m.card == "*":
			return UpgradeDesk.CARDS.all(func(card: Dictionary) -> bool: return save.stamped.has(card.id))
		return save.stamped.has(m.card)
	if m.has("node"):
		return save.tree_bought.has(m.node)
	return save.get(m.stat) >= m.at


## The first memo met in `save` and not yet filed, or {} if none.
static func due(save: SaveGame) -> Dictionary:
	for m: Dictionary in MEMOS:
		if not save.milestones.has(m.id) and met(save, m):
			return m
	return {}


## Files memo `m`: multiplies its save number by its mul, if it has a bonus, and records it.
static func apply(save: SaveGame, m: Dictionary) -> void:
	if m.has("key"):
		var value: Variant = save.get(m.key)
		save.set(m.key, roundi(value * m.mul) if value is int else value * m.mul)
	save.milestones.append(m.id)


## The FILES grid's order: filed memos newest first, then the rest in MEMOS order.
static func files_order(save: SaveGame) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(save.milestones.size() - 1, -1, -1):
		var m := memo(save.milestones[i])
		if not m.is_empty():
			out.append(m)
	for m: Dictionary in MEMOS:
		if not save.milestones.has(m.id):
			out.append(m)
	return out


## The memo with id `id`, or {} if there is none.
static func memo(id: String) -> Dictionary:
	for m: Dictionary in MEMOS:
		if m.id == id:
			return m
	return {}


## 0 hidden .. 1 fully up: eases up over IN_TIME.
static func slide_at(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t / IN_TIME, 0.0, 1.0), 3.0)


## The paper's centre `p` (0..1) of the way from `from` into the folder at `to`: eased in and out,
## bowing up over a curve (a quadratic Bezier through a point above the midpoint).
static func fly_at(p: float, from: Vector2, to: Vector2) -> Vector2:
	var e := smoothstep(0.0, 1.0, p)
	var bow := (from + to) * 0.5 + Vector2(0, -0.35 * from.distance_to(to))
	return from.lerp(bow, e).lerp(bow.lerp(to, e), e)


## The folder's glow (0..1) with `left` seconds of it remaining, at clock `t`: a soft pulse that
## fades out over its last second; 0 once over.
static func glow_at(left: float, t: float) -> float:
	if left <= 0.0:
		return 0.0
	return (0.6 + 0.4 * sin(t * TAU / GLOW_PULSE)) * clampf(left, 0.0, 1.0)


func _draw_paper() -> void:
	if _memo.is_empty():
		return
	var w := SIZE.x
	_paper.draw_rect(Rect2(Vector2(10, 10), SIZE), Color(0, 0, 0, 0.4))
	_paper.draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	_paper.draw_string(FONT, Vector2(28, 52), tr("MEMORANDUM"), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, INK)
	_paper.draw_string(FONT, Vector2(28, 52), tr("INTERNAL  |  DO NOT REPLY"), HORIZONTAL_ALIGNMENT_RIGHT, w - 56, 14, Color(INK, 0.6))
	_paper.draw_line(Vector2(28, 66), Vector2(w - 28, 66), INK, 2.0)
	_paper.draw_string(FONT, Vector2(28, 92), tr("TO: DESK 4     FROM: MANAGEMENT     RE: ") + tr(_memo.re), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 16, Color(INK, 0.8))
	_paper.draw_string(FONT, Vector2(28, 132), tr(_memo.note), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21, INK)
	var line: String = tr("Effective immediately: ") + tr(_memo.bonus) if _memo.has("bonus") else tr(NO_BONUS)
	_paper.draw_string(FONT, Vector2(28, 168), line, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21, INK)
	_paper.draw_line(Vector2(28, 196), Vector2(w - 28, 196), Color(INK, 0.3), 1.0)
	_paper.draw_string(FONT, Vector2(28, 222), tr("Retain for your records. Records are retained regardless."), HORIZONTAL_ALIGNMENT_LEFT, w - 200, 13, Color(INK, 0.55))
	if _stamped:
		# The stamp thumps down slightly too big and settles.
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - (_t - STAMP_AT) / 0.12)
		_paper.draw_set_transform(Vector2(w - 92, 214), deg_to_rad(-9.0), Vector2(pop, pop))
		_paper.draw_rect(Rect2(-62, -24, 124, 46), Color(STAMP, 0.8), false, 3.0)
		_paper.draw_string(FONT, Vector2(-62, 12), tr("NOTED"), HORIZONTAL_ALIGNMENT_CENTER, 124, 30, Color(STAMP, 0.8))
		_paper.draw_set_transform(Vector2.ZERO)


## The mouse on (1) or off (0) the folder: it eases open or shut, a paper rustle as it opens.
func _on_folder_hover(to: float) -> void:
	_hovered = to
	if to > 0.5:
		$Rustle.play()
	_hover_to(to)


## Eases the folder's hover towards `to` (1 open, 0 rest), then calls `then` if given.
func _hover_to(to: float, then := Callable()) -> void:
	if _hovering != null:
		_hovering.kill()
	_hovering = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hovering.tween_method(_set_hover, _hover, to, HOVER_TIME)
	if then.is_valid():
		_hovering.tween_callback(then)


## Poses the folder `h` of the way open: the cover tips up about its back edge, the papers rise,
## the whole folder grows a little.
func _set_hover(h: float) -> void:
	_hover = h
	_skeleton.set_bone_pose_rotation(_cover, Quaternion(Vector3.RIGHT, -COVER_OPEN * h))
	_skeleton.set_bone_pose_position(_papers, _skeleton.get_bone_rest(_papers).origin + Vector3.UP * PAPERS_RISE * h)
	_folder_model.scale = Vector3.ONE * (1.0 + HOVER_GROW * h)


## The shade's header: what this is and how much of it is filed.
func _draw_shade() -> void:
	var filed := MEMOS.filter(func(m: Dictionary) -> bool: return SaveManager.save.milestones.has(m.id)).size()
	var w := _shade.size.x
	_shade.draw_string(FONT, Vector2(0, 70), tr("PERSONNEL FILE  |  DESK 4"), HORIZONTAL_ALIGNMENT_CENTER, w, 40, PAPER)
	_shade.draw_string(FONT, Vector2(0, 104), tr("%d / %d FILED") % [filed, MEMOS.size()], HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(PAPER, 0.7))
	# The close button: a dark stamped square with an X, as on the projector.
	var close := _close_rect()
	_shade.draw_rect(close, Color(INK, 0.9))
	var x := close.grow(-12.0)
	_shade.draw_line(x.position, x.end, PAPER, 3.0, true)
	_shade.draw_line(Vector2(x.end.x, x.position.y), Vector2(x.position.x, x.end.y), PAPER, 3.0, true)


## One memo's card: its icon in a box on the left, title, how to file it, and the bonus (or, once
## filed, its note). Not yet filed: grey paper, stamped CLASSIFIED.
func _draw_card(card: Control, m: Dictionary) -> void:
	var filed := SaveManager.save.milestones.has(m.id)
	var ink := INK if filed else Color(INK, 0.75)
	card.draw_rect(Rect2(Vector2(6, 6), CARD), Color(0, 0, 0, 0.4))
	card.draw_rect(Rect2(Vector2.ZERO, CARD), PAPER if filed else PAPER.darkened(0.4))
	if not filed:
		# Under the writing, so the title and how stay readable through it.
		card.draw_set_transform(Vector2(CARD.x - 120, CARD.y * 0.55), deg_to_rad(-12.0))
		card.draw_rect(Rect2(-92, -22, 184, 42), Color(STAMP, 0.6), false, 3.0)
		card.draw_string(FONT, Vector2(-92, 11), tr("CLASSIFIED"), HORIZONTAL_ALIGNMENT_CENTER, 184, 28, Color(STAMP, 0.6))
		card.draw_set_transform(Vector2.ZERO)
	var box := Rect2(16, 16, CARD.y - 32, CARD.y - 32)
	card.draw_rect(box, Color(INK, 0.1))
	card.draw_rect(box, Color(INK, 0.45), false, 2.0)
	_draw_icon(card, m.icon, box.get_center(), box.size.x * 0.32, ink, filed)
	var x := box.end.x + 18.0
	var w := CARD.x - x - 18.0
	card.draw_string(FONT, Vector2(x, 42), tr(m.re), HORIZONTAL_ALIGNMENT_LEFT, w, 24, ink)
	card.draw_multiline_string(BODY_FONT, Vector2(x, 72), tr(m.how), HORIZONTAL_ALIGNMENT_LEFT, w, 17, 2, Color(ink, 0.85))
	var foot: String = tr("Effective: ") + tr(m.bonus) if m.has("bonus") else (tr(m.note) if filed else "")
	card.draw_multiline_string(FONT, Vector2(x, 122), foot, HORIZONTAL_ALIGNMENT_LEFT, w, 15, 2, Color(ink, 0.7))


## Simple glyphs on `item`, centred on `at`, about `s` from the centre to the edge. The cabbage
## glyphs turn green and research cyan once `lit` (filed).
static func _draw_icon(item: CanvasItem, icon: String, at: Vector2, s: float, ink: Color, lit: bool) -> void:
	match icon:
		"cabbage", "mini":
			# A head seen from above: a ring of outer leaves, the tight core, its veins.
			var r := s * (0.95 if icon == "cabbage" else 0.5)
			var green := CABBAGE if lit else ink
			for i in 6:
				item.draw_circle(at + Vector2.from_angle(i * TAU / 6.0 + 0.3) * r * 0.45, r * 0.55, green.darkened(0.3))
			item.draw_circle(at, r * 0.62, green.lightened(0.15))
			for i in 3:
				var a := i * TAU / 3.0
				item.draw_arc(at + Vector2.from_angle(a) * r * 0.3, r * 0.45, a + PI * 0.6, a + PI * 1.3, 8, green.darkened(0.45), 1.5, true)
			if icon == "mini":
				item.draw_string(FONT, at + Vector2(-s, s * 1.05), "MINI", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.5), ink)
		"research":
			item.draw_circle(at, s * 0.9, CYAN if lit else ink)
			item.draw_arc(at, s * 0.55, 0.0, TAU, 20, Color(INK, 0.5), 2.0, true)
		"coin":
			for i in 3:
				var c := at + Vector2(0, s * (0.5 - i * 0.35))
				item.draw_circle(c, s * 0.8, ink)
				item.draw_arc(c, s * 0.8, 0.0, TAU, 24, Color(PAPER, 0.6), 1.5, true)
			item.draw_string(FONT, at + Vector2(-s, -s * 0.05), "$", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.9), PAPER)
		"catch":
			item.draw_arc(at + Vector2(0, s * 0.9), s * 1.1, PI * 1.1, PI * 1.9, 16, ink, 2.5, true)
			item.draw_circle(at + Vector2(s * 0.75, -s * 0.05), s * 0.3, CABBAGE if lit else ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.9, s * 0.4), Vector2(s * 0.5, s * 0.5)), ink)
		"window":
			var pane := Rect2(at - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7)
			item.draw_rect(pane, ink, false, 3.0)
			item.draw_line(Vector2(at.x, pane.position.y), Vector2(at.x, pane.end.y), ink, 2.5)
			item.draw_line(Vector2(pane.position.x, at.y), Vector2(pane.end.x, at.y), ink, 2.5)
		"hand":
			item.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.15), Vector2(s, s * 0.85)), ink)
			for i in 4:
				var tall := s * (0.55 if i in [0, 3] else 0.7)
				item.draw_rect(Rect2(at + Vector2(-s * 0.5 + i * s * 0.26, -s * 0.15 - tall), Vector2(s * 0.2, tall)), ink)
		"lens":
			item.draw_arc(at + Vector2(-s * 0.2, -s * 0.2), s * 0.55, 0.0, TAU, 20, ink, 3.0, true)
			item.draw_line(at + Vector2(s * 0.2, s * 0.2), at + Vector2(s * 0.85, s * 0.85), ink, 5.0)
		"stamp":
			item.draw_rect(Rect2(at + Vector2(-s * 0.2, -s * 0.9), Vector2(s * 0.4, s * 0.8)), ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.75, -s * 0.15), Vector2(s * 1.5, s * 0.45)), ink)
			item.draw_line(at + Vector2(-s * 0.9, s * 0.75), at + Vector2(s * 0.9, s * 0.75), STAMP, 3.0)
		"lever":
			item.draw_rect(Rect2(at + Vector2(-s * 0.8, s * 0.45), Vector2(s * 1.6, s * 0.4)), ink)
			item.draw_line(at + Vector2(0, s * 0.5), at + Vector2(s * 0.55, -s * 0.75), ink, 4.0)
			item.draw_circle(at + Vector2(s * 0.55, -s * 0.75), s * 0.22, ink)
		"bin":
			item.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.7, -s * 0.6), at + Vector2(s * 0.7, -s * 0.6),
					at + Vector2(s * 0.5, s * 0.85), at + Vector2(-s * 0.5, s * 0.85)]), ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.85, -s * 0.85), Vector2(s * 1.7, s * 0.18)), ink)
		"chart":
			for i in 4:
				var tall := s * (0.45 + i * 0.4)
				item.draw_rect(Rect2(at + Vector2(-s * 0.9 + i * s * 0.48, s * 0.85 - tall), Vector2(s * 0.34, tall)), ink)
		"radio":
			item.draw_rect(Rect2(at + Vector2(-s * 0.9, -s * 0.45), Vector2(s * 1.8, s * 1.2)), ink)
			item.draw_circle(at + Vector2(-s * 0.35, s * 0.15), s * 0.32, PAPER.darkened(0.3))
			item.draw_line(at + Vector2(s * 0.5, -s * 0.45), at + Vector2(s * 0.9, -s * 1.0), ink, 2.5)
		"tree":
			var nodes := [at + Vector2(0, -s * 0.6), at + Vector2(-s * 0.65, s * 0.55), at + Vector2(s * 0.65, s * 0.55)]
			for n: Vector2 in nodes.slice(1):
				item.draw_line(nodes[0], n, ink, 2.5)
			for n: Vector2 in nodes:
				item.draw_circle(n, s * 0.28, ink)
