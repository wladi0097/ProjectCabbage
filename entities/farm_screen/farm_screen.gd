class_name FarmScreen
extends Control
## The family farm on the TV (stage 2, card family_farm; entities/farm_tv/ shows this in its
## SubViewport): an old green-screen game. Left, a grid of square fields: click an empty one to
## plant a seed, a bar fills over grow_time, then a click harvests yield_of units into the desk's
## stock (save.stock). Locked squares are cleared with CLEAR A PLOT. Right, the homestead picture,
## the farm's own upgrades (UPGRADES, a scrolling list) and the seed shop. Top: seeds, cabbages in
## stock, money. Everything is done by hand until FARM HAND (plants) and TRACTOR (harvests) are
## bought: plots are cheap, the machines dear. The fields grow while the camera is at the desk.
## save.farm_growth holds each open square's seconds grown (EMPTY: unplanted).

const SIZE := Vector2(1296, 768)
const START_PLOTS := 12
const MAX_PLOTS := 24
const COLUMNS := 6
const GROW_TIME := 30.0
const YIELD := 3
const EMPTY := -1.0
## Seeds the uncle leaves you, and the seed shop: [seeds, dollars].
const START_SEEDS := 10
const SEED_PACKS := [[10, 50], [50, 220]]
## CLEAR A PLOT: the first costs PLOT_PRICE, each next PLOT_STEP times more.
const PLOT_PRICE := 150
const PLOT_STEP := 1.15
## Seconds between the farm hand's plantings and the tractor's harvests.
const AUTO_EVERY := 1.0
## The farm's upgrades, bought once each (tools/pace.py reads the prices). Effects: apply-free,
## read where they matter (grow_time, yield_of, seed_price, auto).
const UPGRADES := [
	{id = "seed_contract", price = 2500, title = "SEED CONTRACT", body = "Seed packs in the shop cost half."},
	{id = "fertiliser", price = 3000, title = "FERTILISER", body = "Squares ripen in 20 s instead of 30 s."},
	{id = "farm_hand", price = 4000, title = "FARM HAND", body = "Plants an empty square every second (uses seeds)."},
	{id = "irrigation", price = 12000, title = "IRRIGATION", body = "Every harvest gives 4 cabbages instead of 3."},
	{id = "tractor", price = 9000, title = "TRACTOR", body = "Harvests a ripe square every second."},
	{id = "greenhouse", price = 30000, title = "GREENHOUSE", body = "Squares ripen in 15 s."},
]

const GLASS := Color(0.05, 0.07, 0.06)
const PHOSPHOR := Color(0.88, 0.94, 0.89)
const DIM := Color(0.62, 0.68, 0.63)
const LINE := Color(0.34, 0.4, 0.37)
const SOIL := Color(0.22, 0.21, 0.18)
const SOIL_HI := Color(0.3, 0.29, 0.24)
const SPROUT := Color(0.31, 0.42, 0.25)
## The only saturated thing: the cabbage.
const CABBAGE := Color(0.48, 0.75, 0.26)
## Kept ~36 px off the edges: the CRT glass warps the corners (FarmTv.WARP).
const FIELD := Rect2(36, 80, 846, 620)
const SIDE := Rect2(900, 80, 360, 620)
const GAP := 8.0

var _font := screen_font()
var _auto := 0.0
var _hot := -1
var _msg := "Click a square to plant a seed (1 seed). Ripe after 30 s: click it to harvest 3 cabbages."
var _buttons := {}
## The upgrade rows (built from UPGRADES) and the seed packs (one button per SEED_PACKS entry).
@onready var _list: VBoxContainer = $Scroll/List
@onready var _seed_buttons: Array[Button] = [$Shop/Seeds0, $Shop/Seeds1]
var _clock := 0.0


func _ready() -> void:
	_add_upgrade("plot")
	for u: Dictionary in UPGRADES:
		_add_upgrade(u.id)
	for i in _seed_buttons.size():
		_seed_buttons[i].pressed.connect(_buy_seeds.bind(i))


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.stamped.has("family_farm"):
		return
	ensure(save)
	save.farm_seconds += delta
	tick(save, delta)
	_auto += delta
	if _auto >= AUTO_EVERY:
		_auto -= AUTO_EVERY
		auto(save)
	_clock += delta
	# Only redrawn while the TV's viewport renders (the camera is off the desk) or shown on its own.
	var tv := get_viewport() as SubViewport
	if tv == null or tv.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_refresh(save)
		queue_redraw()


## The screen's terminal font: a bold monospace (the scene's theme uses it too).
static func screen_font() -> SystemFont:
	return preload("res://assets/fonts/terminal_font.tres")


## Fits save.farm_growth to the open squares (new ones empty) and hands out the uncle's seeds once.
static func ensure(save: SaveGame) -> void:
	if save.farm_plots == 0:
		save.farm_plots = START_PLOTS
		save.farm_seeds = START_SEEDS
	while save.farm_growth.size() < save.farm_plots:
		save.farm_growth.append(EMPTY)


## Whether the farm (once bought) can still feed the desk: seeds to plant or a square planted.
static func feeds(save: SaveGame) -> bool:
	return save.stamped.has("family_farm") and (save.farm_seeds > 0 or Array(save.farm_growth).any(func(g: float) -> bool: return g >= 0.0))


static func grow_time(save: SaveGame) -> float:
	if save.farm_bought.has("greenhouse"):
		return 15.0
	return 20.0 if save.farm_bought.has("fertiliser") else GROW_TIME


static func yield_of(save: SaveGame) -> int:
	return YIELD + (1 if save.farm_bought.has("irrigation") else 0)


static func seed_price(pack: int, save: SaveGame) -> int:
	var price: int = SEED_PACKS[pack][1]
	return roundi(price * 0.5) if save.farm_bought.has("seed_contract") else price


static func plot_price(save: SaveGame) -> int:
	return roundi(PLOT_PRICE * pow(PLOT_STEP, save.farm_plots - START_PLOTS))


static func upgrade_price(id: String, save: SaveGame) -> int:
	if id == "plot":
		return plot_price(save)
	for u: Dictionary in UPGRADES:
		if u.id == id:
			return u.price
	return 0


## The price shown at the bottom right of upgrade `id`'s entry: "$2,500", or OWNED once bought.
static func price_tag(id: String, save: SaveGame) -> String:
	return "$%s" % _thousands(upgrade_price(id, save)) if on_offer(id, save) else "OWNED"


## The font size the hint line `text` fits `width` px at: 22, smaller for long (German) hints.
static func msg_size(font: Font, text: String, width: float) -> int:
	var px := 22
	while px > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	return px


## Whether upgrade `id` can still be bought (CLEAR A PLOT until MAX_PLOTS; the rest once).
static func on_offer(id: String, save: SaveGame) -> bool:
	return save.farm_plots < MAX_PLOTS if id == "plot" else not save.farm_bought.has(id)


static func is_ripe(save: SaveGame, i: int) -> bool:
	return save.farm_growth[i] >= grow_time(save)


## Every planted square grows by `delta` seconds, up to ripe.
static func tick(save: SaveGame, delta: float) -> void:
	var ripe := grow_time(save)
	for i in save.farm_growth.size():
		if save.farm_growth[i] >= 0.0:
			save.farm_growth[i] = minf(save.farm_growth[i] + delta, ripe)


## Plants square `i` with a seed; false if it isn't empty or there are no seeds.
static func plant(save: SaveGame, i: int) -> bool:
	if save.farm_growth[i] != EMPTY or save.farm_seeds <= 0:
		return false
	save.farm_seeds -= 1
	save.farm_growth[i] = 0.0
	return true


## Harvests square `i` if ripe: its cabbages go into stock. Returns how many (0 if not ripe).
static func harvest(save: SaveGame, i: int) -> int:
	if save.farm_growth[i] < 0.0 or not is_ripe(save, i):
		return 0
	save.farm_growth[i] = EMPTY
	var units := yield_of(save)
	save.stock += units
	save.farm_harvests += 1
	return units


## One step of the machines: the tractor harvests the first ripe square, the farm hand plants the
## first empty one.
static func auto(save: SaveGame) -> void:
	if save.farm_bought.has("tractor"):
		for i in save.farm_growth.size():
			if harvest(save, i) > 0:
				break
	if save.farm_bought.has("farm_hand"):
		for i in save.farm_growth.size():
			if plant(save, i):
				break


## Buys upgrade `id` with coins; false if it isn't on offer or too dear.
static func buy(id: String, save: SaveGame) -> bool:
	var price := upgrade_price(id, save)
	if not on_offer(id, save) or save.coins < price:
		return false
	save.coins -= price
	if id == "plot":
		save.farm_plots += 1
		ensure(save)
	else:
		save.farm_bought.append(id)
	return true


func _buy_seeds(pack: int) -> void:
	var save := SaveManager.save
	var price := seed_price(pack, save)
	if save.coins < price:
		_say(tr("Not enough money for seeds."))
		return
	save.coins -= price
	save.farm_seeds += SEED_PACKS[pack][0]
	$Buy.play()
	_say(tr("%d seeds delivered.") % SEED_PACKS[pack][0])


func _buy(id: String) -> void:
	var price := upgrade_price(id, SaveManager.save)
	if buy(id, SaveManager.save):
		$Buy.play()
		SaveManager.log_event("farm", id, price, "coins")
		_say(tr("%s approved.") % tr(_title(id)))
	else:
		_say(tr("Not enough money."))


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouse
	if motion == null:
		return
	_hot = _square_at(motion.position)
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT or _hot < 0:
		return
	var save := SaveManager.save
	if _hot >= save.farm_plots:
		_say(tr("Locked. Clear a plot on the right."))
		return
	var units := harvest(save, _hot)
	if units > 0:
		$Harvest.play()
		_say(tr("Harvested: +%d cabbages to stock.") % units)
	elif save.farm_growth[_hot] == EMPTY:
		if plant(save, _hot):
			$Plant.play()
			_say(tr("Planted. Ripe in %d s.") % grow_time(save))
		else:
			_say(tr("No seeds. Buy some in the seed shop."))
	accept_event()


func _say(text: String) -> void:
	_msg = text


## The square under `point`, or -1.
func _square_at(point: Vector2) -> int:
	for i in MAX_PLOTS:
		if _square(i).has_point(point):
			return i
	return -1


func _square(i: int) -> Rect2:
	var side := (FIELD.size.x - GAP * (COLUMNS - 1)) / COLUMNS
	var rows := ceili(float(MAX_PLOTS) / COLUMNS)
	var top := FIELD.position.y + (FIELD.size.y - rows * side - (rows - 1) * GAP) * 0.5
	return Rect2(FIELD.position.x + (i % COLUMNS) * (side + GAP), top + floorf(i / float(COLUMNS)) * (side + GAP), side, side)


func _title(id: String) -> String:
	if id == "plot":
		return "CLEAR A PLOT"
	for u: Dictionary in UPGRADES:
		if u.id == id:
			return u.title
	return id


func _add_upgrade(id: String) -> void:
	var b := Button.new()
	b.theme_type_variation = &"UpgradeButton"  # Room for the price below the text.
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(SIDE.size.x - 14, 100)
	b.pressed.connect(_buy.bind(id))
	var price := Label.new()
	price.add_theme_font_size_override("font_size", 21)
	price.add_theme_color_override("font_color", PHOSPHOR)
	price.name = "Price"
	price.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	price.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	price.grow_vertical = Control.GROW_DIRECTION_BEGIN
	price.offset_right = -10
	price.offset_bottom = -5
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(price)
	_list.add_child(b)
	_buttons[id] = b


func _refresh(save: SaveGame) -> void:
	for id: String in _buttons:
		var b: Button = _buttons[id]
		var body: String = tr("One more square of soil (%d / %d).") % [save.farm_plots, MAX_PLOTS] if id == "plot" else ""
		for u: Dictionary in UPGRADES:
			if u.id == id:
				body = tr(u.body)
		var offer := on_offer(id, save)
		b.text = "%s\n%s" % [tr(_title(id)), body]
		(b.get_node("Price") as Label).text = tr(price_tag(id, save))
		b.disabled = not offer
		b.modulate.a = 1.0 if offer and save.coins >= upgrade_price(id, save) else 0.55
	for i in _seed_buttons.size():
		_seed_buttons[i].text = tr("%d seeds    $%d") % [SEED_PACKS[i][0], seed_price(i, save)]


func _draw() -> void:
	var save := SaveManager.save
	draw_rect(Rect2(Vector2.ZERO, SIZE), GLASS)
	# Top: seeds and cabbages left, money right.
	draw_string(_font, Vector2(36, 52), tr("SEEDS %d   CABBAGES %d") % [save.farm_seeds, save.stock], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, PHOSPHOR)
	draw_string(_font, Vector2(0, 52), "$ %s" % _thousands(save.coins), HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 36, 32, PHOSPHOR)
	draw_line(Vector2(36, 66), Vector2(SIZE.x - 36, 66), LINE, 2.0)
	var ripe := grow_time(save)
	for i in MAX_PLOTS:
		var r := _square(i)
		if i >= save.farm_plots:
			draw_rect(r, Color(0.1, 0.11, 0.1))
			for k in range(0, int(r.size.x * 2), 12):
				var a := r.position + Vector2(k, 0)
				var b := r.position + Vector2(k - r.size.y, r.size.y)
				draw_line(a.clamp(r.position, r.end), b.clamp(r.position, r.end), Color(0.15, 0.17, 0.15), 4.0)
			draw_string(_font, Vector2(r.position.x, r.get_center().y + 6), tr("LOCKED"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, DIM)
			continue
		draw_rect(r, SOIL_HI if i == _hot else SOIL)
		draw_rect(r, LINE, false, 2.0)
		var grown: float = save.farm_growth[i]
		if grown == EMPTY:
			draw_string(_font, Vector2(r.position.x, r.get_center().y + 6), tr("+ PLANT"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 21, PHOSPHOR)
		elif grown < ripe:
			var k := grown / ripe
			draw_circle(r.get_center(), r.size.x * (0.06 + 0.12 * k), SPROUT)
			var bar := Rect2(r.position + Vector2(8, r.size.y - 16), Vector2(r.size.x - 16, 8))
			draw_rect(bar, DIM, false, 1.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), PHOSPHOR.darkened(0.1))
		else:
			var c := r.get_center()
			draw_circle(c, r.size.x * 0.24, CABBAGE.darkened(0.25))
			draw_circle(c + Vector2(-3, -3), r.size.x * 0.19, CABBAGE)
			draw_string(_font, r.position + Vector2(0, 20), "x%d " % yield_of(save), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4, 22, PHOSPHOR)
	_draw_homestead(save, Rect2(SIDE.position, Vector2(SIDE.size.x, 160)))
	var msg := tr(_msg)
	draw_string(_font, Vector2(36, SIZE.y - 30), msg, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 72, msg_size(_font, msg, SIZE.x - 72), PHOSPHOR)


## The homestead: a barn, a silo, the farm hand and the tractor once bought.
func _draw_homestead(save: SaveGame, r: Rect2) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.62)), Color(0.1, 0.13, 0.12))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.62), Vector2(r.size.x, r.size.y * 0.38)), Color(0.14, 0.14, 0.11))
	draw_rect(r, LINE, false, 2.0)
	draw_string(_font, r.position + Vector2(8, 18), tr("FAMILY FARM - CH 3"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DIM)
	var ground := r.position.y + r.size.y * 0.8
	var barn := Rect2(r.position.x + 16, ground - 56, 76, 56)
	draw_rect(barn, Color(0.3, 0.31, 0.29))
	draw_colored_polygon(PackedVector2Array([barn.position + Vector2(-6, 0), barn.position + Vector2(barn.size.x * 0.5, -28), barn.position + Vector2(barn.size.x + 6, 0)]), Color(0.35, 0.37, 0.34))
	draw_rect(Rect2(barn.get_center().x - 11, ground - 30, 22, 30), Color(0.17, 0.18, 0.17))
	draw_rect(Rect2(r.position.x + 100, ground - 82, 26, 82), Color(0.37, 0.38, 0.36))
	draw_circle(Vector2(r.position.x + 113, ground - 82), 13, Color(0.37, 0.38, 0.36))
	if save.farm_bought.has("farm_hand"):
		var x := r.position.x + 150 + sin(_clock * 2.0) * 6.0
		draw_circle(Vector2(x, ground - 30), 6, Color(0.55, 0.56, 0.5))
		draw_rect(Rect2(x - 5, ground - 24, 10, 22), Color(0.42, 0.44, 0.4))
	if save.farm_bought.has("tractor"):
		var x := r.position.x + 160 + 60.0 * (0.5 + 0.5 * sin(_clock * 0.8))
		draw_rect(Rect2(x, ground - 22, 38, 16), Color(0.42, 0.44, 0.41))
		draw_rect(Rect2(x + 22, ground - 34, 14, 12), Color(0.36, 0.38, 0.35))
		draw_circle(Vector2(x + 6, ground - 6), 9, Color(0.12, 0.13, 0.12))
		draw_circle(Vector2(x + 32, ground - 4), 6, Color(0.12, 0.13, 0.12))


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
