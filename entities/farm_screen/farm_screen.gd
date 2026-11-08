class_name FarmScreen
extends Control
## CH1 FIELDS of the family farm on the TV (stage 2, card family_farm; entities/farm_tv/ shows this
## in its SubViewport): an old green-screen game. The left 3/4 is the field, a grid of squares:
## START_PLOTS open, the rest locked (each shows its price; click the next one to clear it). Press on
## the seed box (bottom of the yard, the right 1/4) to pick up a seed, let go over an empty square to
## plant it (anywhere else it flies back into the box). Squares are drawn with pixel sprites like an
## old home-computer game: bare soil (SOILS), a plant growing through the STAGES over grow_time, then
## the ripe cabbage (CABBAGE_SPRITE) is grabbed and pulled
## PULL_DISTANCE out of its square to harvest yield_of units into the desk's stock (save.stock).
## The status row along the top (seeds, cabbages, money) only shows once STATUS_CARD is stamped.
## The cursor (cursor_for, set as the OS cursor by entities/farm_tv/) shows what a press would do.
## The seed packs are the two buttons under the box. Farm hands (a work glove) and tractors
## (save.farm_hands / farm_tractors) stand in the yard and go out on shifts (Worker, work): a hand takes
## seeds from the crate and plants empty squares, a tractor harvests ripe ones; after
## save.farm_hand_shift / farm_tractor_shift jobs they come back to the yard. The farm's
## one-off upgrades are bought on CH2 (save.farm_bought, read by grow_time, yield_of, seed_price).
## The fields grow and the workers work while the camera is at the desk; only the redraw stops.
## save.farm_growth holds each open square's seconds grown (EMPTY: unplanted).

const SIZE := Vector2(1512, 768)
const START_PLOTS := 4
const MAX_PLOTS := 24
const COLUMNS := 6
const GROW_TIME := 30.0
const YIELD := 3
const EMPTY := -1.0
## Seeds the uncle leaves you, and the seed packs under the box: [seeds, dollars].
const START_SEEDS := 10
const SEED_PACKS := [[10, 50], [50, 220]]
## Clearing a plot: the first costs PLOT_PRICE, each next PLOT_STEP times more.
const PLOT_PRICE := 150
const PLOT_STEP := 1.15
## Workers at speed 1.0 (save.farm_hand_speed / farm_tractor_speed multiply both walking and work):
## a farm hand walks HAND_SPEED px/s across the 1512 px screen (a square is ~157 px apart, the field
## ~5 s to the far corner) and plants for HAND_WORK s; a tractor drives TRACTOR_SPEED px/s and
## harvests for TRACTOR_WORK s.
const HAND_SPEED := 160.0
const HAND_WORK := 1.5
const TRACTOR_SPEED := 220.0
const TRACTOR_WORK := 2.0
## No seeds to plant: the SEEDS count and box blink red for SEED_BLINK seconds, BLINK_RATE blinks a second.
const SEED_BLINK := 0.8
const BLINK_RATE := 5.0
## Every warning on the hint line (_warn: no seeds or money, storage full, a wrong click) shakes it: SHAKE_TIME s, SHAKE_PX px
## at most, SHAKE_HZ swings a second, dying away.
const SHAKE_TIME := 0.45
const SHAKE_PX := 9.0
const SHAKE_HZ := 9.0
const DENIED_RED := Color(1, 0.25, 0.2)
## The desk card that adds the status row.
const STATUS_CARD := "farm_readout"
## Cursors over the screen: a pointer on what is clicked (the next locked square, the pack buttons
## in the scene), an open hand on what can be picked up or pulled (the seed box, a ripe cabbage), a
## closed one while holding a seed or pulling. FarmTv skins the three shapes with glove images.
const POINT := Input.CURSOR_POINTING_HAND
const OPEN_HAND := Input.CURSOR_CAN_DROP
const GRAB := Input.CURSOR_DRAG
## A ripe cabbage pops out once dragged PULL_DISTANCE px from where it was grabbed; until then it
## strains toward the mouse, at most STRAIN px, stretched by up to STRETCH. Let go sooner (or with
## storage full) it springs back in SNAP_TIME.
const PULL_DISTANCE := 70.0
const STRAIN := 20.0
const STRETCH := 0.22
const SNAP_TIME := 0.25
## The pop: BURST_BITS bits of leaf and soil fly for BURST_TIME s.
const BURST_BITS := 16
const BURST_TIME := 0.5
## A seed let go off an empty square flies back into the box in SEED_BACK s.
const SEED_BACK := 0.22
## A sprout's stages over grow_time, one string per line, in the screen font at growing sizes.
## The squares' pixel sprites (assets/sprites/farm/, PIXEL px SVGs made by tools/make_farm_sprites.py),
## drawn at a whole multiple of their size with the scene's nearest filter: bare soil (a variant per
## square, soil_variant), the growth STAGES from seed to young head, and the ripe cabbage.
const PIXEL := 16
## The most of a square's width its sprites take (whole pixels round it down a little).
const SPRITE_FILL := 0.8
## The seed box: a pixel crate (32x12) with a pile of seeds on it (32x8, three sizes), drawn at
## SEED_SCALE screen px per pixel (the squares' 7), the count on its label in CRATE_INK. The pile
## is small under PILE_SOME seeds and full from PILE_LOTS.
const SEED_CRATE: Texture2D = preload("res://assets/sprites/farm/seed_crate.svg")
const SEED_PILES: Array[Texture2D] = [preload("res://assets/sprites/farm/seed_pile_1.svg"),
		preload("res://assets/sprites/farm/seed_pile_2.svg"), preload("res://assets/sprites/farm/seed_pile_3.svg")]
const SEED_SCALE := 7.0
const SEED_SPRITE: Texture2D = preload("res://assets/sprites/farm/seed.svg")
const CRATE_INK := Color(0.1, 0.11, 0.1)
const PILE_SOME := 10
const PILE_LOTS := 50
const SOILS: Array[Texture2D] = [preload("res://assets/sprites/farm/soil_0.svg"),
		preload("res://assets/sprites/farm/soil_1.svg"), preload("res://assets/sprites/farm/soil_2.svg")]
const STAGES: Array[Texture2D] = [preload("res://assets/sprites/farm/stage_0.svg"),
		preload("res://assets/sprites/farm/stage_1.svg"), preload("res://assets/sprites/farm/stage_2.svg"),
		preload("res://assets/sprites/farm/stage_3.svg"), preload("res://assets/sprites/farm/stage_4.svg")]
const CABBAGE_SPRITE: Texture2D = preload("res://assets/sprites/farm/cabbage.svg")
## The burst's soil bits.
const SOIL_INK := Color(0.52, 0.51, 0.44)

const GLASS := Color(0.05, 0.07, 0.06)
const PHOSPHOR := Color(0.88, 0.94, 0.89)
const DIM := Color(0.62, 0.68, 0.63)
const LINE := Color(0.34, 0.4, 0.37)
const SOIL := Color(0.22, 0.21, 0.18)
const SOIL_HI := Color(0.3, 0.29, 0.24)
## The workers' pixel sprites: the farm hand's glove open (walking empty), carrying seeds, pressing
## one in, at WORKER_PIXEL screen px per pixel; the tractor facing right and left, two wheel frames
## each, at TRACTOR_PIXEL. The frame changes every WALK_STEP px moved (wheels turn, the glove bobs).
const HAND_OPEN: Texture2D = preload("res://assets/sprites/farm/hand_open.svg")
const HAND_CARRY: Texture2D = preload("res://assets/sprites/farm/hand_carry.svg")
const HAND_PRESS: Texture2D = preload("res://assets/sprites/farm/hand_press.svg")
const TRACTOR_SPRITES: Array[Texture2D] = [preload("res://assets/sprites/farm/tractor_right_0.svg"),
		preload("res://assets/sprites/farm/tractor_right_1.svg"), preload("res://assets/sprites/farm/tractor_left_0.svg"),
		preload("res://assets/sprites/farm/tractor_left_1.svg")]
const WORKER_PIXEL := 3.0
const TRACTOR_PIXEL := 5.0
const WALK_STEP := 16.0
## A farm hand's target while it goes to the seed crate (squares are 0 and up, -1 is none).
const CRATE := -2
## The only saturated thing: the cabbage.
const CABBAGE := Color(0.48, 0.75, 0.26)
## Kept ~36 px off the edges: the CRT glass warps the corners (FarmTv.WARP). The field is the left
## 3/4, the yard the right 1/4: idle workers stand in its top, the seed box sits at its bottom with
## the seed pack buttons (the scene's Packs) under it.
const FIELD := Rect2(36, 80, 1080, 620)
const YARD := Rect2(1134, 80, 342, 620)
const SEED_BOX := Rect2(1134, 486, 342, 140)
const GAP := 8.0


## A farm hand (plants) or a tractor (harvests) on its shift. Not saved: rebuilt from the save's
## counts, standing in the yard.
class Worker:
	var tractor: bool
	## Its place in the yard among workers of its kind (FarmScreen.home).
	var slot: int
	var pos: Vector2
	## The square it heads for or works on, CRATE (a hand fetching seeds), or -1: none, it goes home.
	var target := -1
	## Seconds of work left on `target` (0: walking).
	var busy := 0.0
	## Seeds a farm hand carries from the crate.
	var seeds := 0
	## Jobs done this trip, and whether it is walking back to the yard (shift done or nothing to do).
	var jobs := 0
	var going_home := false
	## Px moved so far (turns the wheels, bobs the glove) and whether it last moved to the left.
	var walked := 0.0
	var left := false

	func _init(is_tractor: bool, n: int) -> void:
		tractor = is_tractor
		slot = n
		pos = FarmScreen.home(is_tractor, n)


var _font := screen_font()
var _hot := -1
var _mouse := Vector2.ZERO
## A seed taken from the box follows the cursor until let go; one flying back is at _fly.
var _held := false
var _flying := false
var _fly := Vector2.ZERO
## The ripe square being pulled (-1 none) and where it was grabbed; the one springing back after
## a pull let go too soon; the mouse's offset from the grab (shared by both).
var _pull := -1
var _grip := Vector2.ZERO
var _snap := -1
var _tug := Vector2.ZERO
## The pop's bits ([position, velocity, is_leaf]) and the seconds they still fly.
var _bits: Array = []
var _burst_left := 0.0
## The opening hint, filled with the current grow time and yield when drawn.
const OPENING := "Drag a seed from the box on the right onto an empty square. Ripe after %d s: pull the cabbage out to harvest %d."
var _msg := OPENING
var _workers: Array[Worker] = []
@onready var _seed_buttons: Array[Button] = [$Packs/Seeds0, $Packs/Seeds1]
## Seconds the SEEDS count still blinks red.
var _seed_blink := 0.0
## Seconds the hint line still shakes.
var _shake := 0.0


func _ready() -> void:
	return_carried(SaveManager.save)
	for i in _seed_buttons.size():
		_seed_buttons[i].pressed.connect(_buy_seeds.bind(i))


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.stamped.has("family_farm"):
		return
	ensure(save)
	save.farm_seconds += delta
	tick(save, delta)
	sync_workers(_workers, save)
	work(_workers, save, delta)
	_seed_blink = maxf(_seed_blink - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	_burst_left = maxf(_burst_left - delta, 0.0)
	for bit: Array in _bits:
		bit[0] += bit[1] * delta
		bit[1].y += 900.0 * delta
	# The button went up where the screen didn't see it (off the glass): let go there.
	if _pull >= 0 and not is_ripe(save, _pull):
		_pull = -1  # A tractor harvested it under the cursor.
	if (_held or _pull >= 0) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release(_mouse)
	# Only redrawn while the TV's viewport renders (the camera is off the desk) or shown on its own.
	var tv := get_viewport() as SubViewport
	if tv == null or tv.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_refresh(save)
		queue_redraw()
	else:
		_held = false  # Left the TV (Esc, BACK): the seed goes back in the box, the cabbage stays.
		_pull = -1


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
	return save.stamped.has("family_farm") and (save.farm_seeds + save.farm_seeds_carried > 0 or Array(save.farm_growth).any(func(g: float) -> bool: return g >= 0.0))


static func grow_time(save: SaveGame) -> float:
	if save.farm_bought.has("greenhouse"):
		return 15.0
	return 20.0 if save.farm_bought.has("fertiliser") else GROW_TIME


static func yield_of(save: SaveGame) -> int:
	return YIELD + (1 if save.farm_bought.has("irrigation") else 0)


static func seed_price(pack: int, save: SaveGame) -> int:
	var price: int = SEED_PACKS[pack][1]
	return roundi(price * 0.5) if save.farm_bought.has("seed_contract") else price


## The price of locked square `i` (cleared in order: the next is save.farm_plots).
static func plot_price_of(i: int) -> int:
	return roundi(PLOT_PRICE * pow(PLOT_STEP, i - START_PLOTS))


static func plot_price(save: SaveGame) -> int:
	return plot_price_of(save.farm_plots)


## Clears the next locked square with coins; false at MAX_PLOTS or too dear.
static func clear_plot(save: SaveGame) -> bool:
	var price := plot_price(save)
	if save.farm_plots >= MAX_PLOTS or save.coins < price:
		return false
	save.coins -= price
	save.farm_plots += 1
	ensure(save)
	return true


## The font size the hint line `text` fits `width` px at: 22, smaller for long (German) hints.
static func msg_size(font: Font, text: String, width: float) -> int:
	var px := 22
	while px > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	return px


## How far the hint line sits off its place with `left` seconds of its shake to go: a side to side
## swing that dies away, 0 once it is over.
static func shake_offset(left: float) -> float:
	if left <= 0.0:
		return 0.0
	return sin((SHAKE_TIME - left) * TAU * SHAKE_HZ) * SHAKE_PX * left / SHAKE_TIME


## Whether the SEEDS count shows red with `left` seconds of its blink to go (on and off BLINK_RATE times a second).
static func blink_on(left: float) -> bool:
	return left > 0.0 and fmod(left * BLINK_RATE, 1.0) < 0.5


static func is_ripe(save: SaveGame, i: int) -> bool:
	return save.farm_growth[i] >= grow_time(save)


## Every planted square grows by `delta` seconds, up to ripe.
static func tick(save: SaveGame, delta: float) -> void:
	var ripe := grow_time(save)
	for i in save.farm_growth.size():
		if save.farm_growth[i] >= 0.0:
			save.farm_growth[i] = minf(save.farm_growth[i] + delta, ripe)


## Plants square `i` with a seed from the crate; false if it isn't empty or there are no seeds.
static func plant(save: SaveGame, i: int) -> bool:
	if save.farm_seeds <= 0 or not sow(save, i):
		return false
	save.farm_seeds -= 1
	return true


## Puts a seed already in hand (a farm hand's) into square `i`; false if it isn't empty.
static func sow(save: SaveGame, i: int) -> bool:
	if save.farm_growth[i] != EMPTY:
		return false
	save.farm_growth[i] = 0.0
	return true


## Harvests square `i` if ripe and its cabbages fit under save.storage_cap: they go into stock.
## Returns how many (0 if not ripe or storage is full; the square stays ripe). The first harvest
## records its farm_seconds (save.farm_first_harvest).
static func harvest(save: SaveGame, i: int) -> int:
	if save.farm_growth[i] < 0.0 or not is_ripe(save, i) or not storage_room(save):
		return 0
	save.farm_growth[i] = EMPTY
	var units := yield_of(save)
	save.stock += units
	save.farm_harvests += 1
	if save.farm_first_harvest < 0.0:
		save.farm_first_harvest = save.farm_seconds
	return units


## Whether one more harvest fits in storage.
static func storage_room(save: SaveGame) -> bool:
	return save.stock + yield_of(save) <= save.storage_cap


## Whether a worker could do its job on open square `i` now: a farm hand plants an empty square
## (with a seed it carries), a tractor harvests a ripe one (with storage room).
static func can_work(save: SaveGame, tractor: bool, i: int) -> bool:
	if tractor:
		return save.farm_growth[i] >= 0.0 and is_ripe(save, i) and storage_room(save)
	return save.farm_growth[i] == EMPTY


## The square a worker heads for next (-1: no job anywhere, it goes home and waits). Route 0: any
## open square at random, checked only on arrival (wasted trips). Route 1: one it can work on that no
## other worker of its kind (`taken`) heads for.
static func target_for(save: SaveGame, tractor: bool, route: int, taken: Array) -> int:
	var open := range(save.farm_plots).filter(func(i: int) -> bool: return can_work(save, tractor, i) and not (route == 1 and taken.has(i)))
	if open.is_empty():
		return -1
	return randi() % save.farm_plots if route == 0 else open.pick_random()


## Jobs a worker does on the lot before it walks back to the yard (at least 1).
static func shift(save: SaveGame, tractor: bool) -> int:
	return maxi(1, save.farm_tractor_shift if tractor else save.farm_hand_shift)


## Where idle worker number `n` stands in the top of the yard: farm hands in a row, tractors below.
static func home(tractor: bool, n: int) -> Vector2:
	if tractor:
		return YARD.position + Vector2(64 + (n % 3) * 106, 270 + floorf(n / 3.0) * 70)
	return YARD.position + Vector2(44 + (n % 4) * 84, 80 + floorf(n / 4.0) * 76)


## Where a farm hand takes its seeds: on the crate's pile.
static func crate_spot() -> Vector2:
	return pile_rect().get_center()


## Seeds the farm hands were carrying when the game last saved (workers aren't saved) go back into
## the crate: called once as the screen comes up, before any worker exists.
static func return_carried(save: SaveGame) -> void:
	save.farm_seeds += maxi(save.farm_seeds_carried, 0)
	save.farm_seeds_carried = 0


## Adds or removes workers until there are save.farm_hands farm hands and save.farm_tractors tractors
## (a hand sent away puts its seeds back in the crate).
static func sync_workers(workers: Array[Worker], save: SaveGame) -> void:
	for tractor: bool in [false, true]:
		var want := save.farm_tractors if tractor else save.farm_hands
		var mine := workers.filter(func(w: Worker) -> bool: return w.tractor == tractor)
		for n in range(mine.size(), want):
			workers.append(Worker.new(tractor, n))
		for n in range(want, mine.size()):
			save.farm_seeds += mine[n].seeds
			save.farm_seeds_carried -= mine[n].seeds
			workers.erase(mine[n])


## What worker `w` heads for next (a square, CRATE or -1). A farm hand without seeds goes to the
## crate, but only while it has seeds and an empty square waits; one with seeds picks a square.
static func next_job(w: Worker, workers: Array[Worker], save: SaveGame) -> int:
	var taken := workers.filter(func(o: Worker) -> bool: return o != w and o.tractor == w.tractor).map(func(o: Worker) -> int: return o.target)
	if not w.tractor and w.seeds == 0:
		return CRATE if save.farm_seeds > 0 and target_for(save, false, 1, taken) >= 0 else -1
	return target_for(save, w.tractor, save.farm_tractor_route if w.tractor else save.farm_hand_route, taken)


## Where worker `w` walks to: its square, the crate, or its spot in the yard.
static func goal_of(w: Worker) -> Vector2:
	if w.going_home or w.target == -1:
		return home(w.tractor, w.slot)
	return crate_spot() if w.target == CRATE else square(w.target).get_center()


## Moves every worker `delta` seconds on. A shift: from the yard a farm hand walks to the crate and
## takes up to shift() seeds (none there: it waits in the yard), then plants them one empty square
## after another (HAND_WORK each); a tractor drives to ripe squares and harvests them (TRACTOR_WORK
## each; storage full: it waits in the yard). After shift() jobs, or out of seeds, it walks back to
## the yard (unplanted seeds go back in the crate) and sets out again. A square it can't work on
## when it gets there (a wasted trip, or someone was quicker) sends it on to the next.
static func work(workers: Array[Worker], save: SaveGame, delta: float) -> void:
	for w in workers:
		var mult := save.farm_tractor_speed if w.tractor else save.farm_hand_speed
		if w.busy > 0.0:
			w.busy -= delta * mult
			if w.busy <= 0.0:
				_finish(w, save)
			continue
		if not w.going_home and w.target == -1:
			w.target = next_job(w, workers, save)
		var goal := goal_of(w)
		var step := (TRACTOR_SPEED if w.tractor else HAND_SPEED) * mult * delta
		if not is_equal_approx(goal.x, w.pos.x):
			w.left = goal.x < w.pos.x
		w.walked += minf(step, w.pos.distance_to(goal))
		w.pos = w.pos.move_toward(goal, step)
		if w.pos != goal:
			continue
		if w.going_home or w.target == -1:  # In the yard: the trip is over.
			w.going_home = false
			w.jobs = 0
			save.farm_seeds += w.seeds
			save.farm_seeds_carried -= w.seeds
			w.seeds = 0
		elif w.target == CRATE:
			w.seeds = mini(shift(save, false), save.farm_seeds)
			save.farm_seeds -= w.seeds
			save.farm_seeds_carried += w.seeds
			w.target = -1
			w.going_home = w.seeds == 0
		elif can_work(save, w.tractor, w.target):
			w.busy = TRACTOR_WORK if w.tractor else HAND_WORK
		else:
			w.target = -1


## Worker `w`'s job on its square is done: plant or harvest it, then on to the next or home.
static func _finish(w: Worker, save: SaveGame) -> void:
	var done := harvest(save, w.target) > 0 if w.tractor else sow(save, w.target)
	if done:
		w.jobs += 1
		if not w.tractor:
			w.seeds -= 1
			save.farm_seeds_carried -= 1
	w.target = -1
	w.going_home = w.jobs >= shift(save, w.tractor) or (not w.tractor and w.seeds == 0)


## Which of a worker's two frames shows after it moved `walked` px.
static func worker_frame(walked: float) -> int:
	return floori(walked / WALK_STEP) % 2


## Square `i` on the field: COLUMNS wide, centred in FIELD.
static func square(i: int) -> Rect2:
	var rows := ceili(float(MAX_PLOTS) / COLUMNS)
	var side := minf((FIELD.size.x - GAP * (COLUMNS - 1)) / COLUMNS, (FIELD.size.y - GAP * (rows - 1)) / rows)
	var corner := FIELD.position + (FIELD.size - Vector2(COLUMNS, rows) * side - Vector2(COLUMNS - 1, rows - 1) * GAP) * 0.5
	return Rect2(corner + Vector2(i % COLUMNS, floorf(i / float(COLUMNS))) * (side + GAP), Vector2(side, side))


## The square under `point`, or -1.
static func square_at(point: Vector2) -> int:
	for i in MAX_PLOTS:
		if square(i).has_point(point):
			return i
	return -1


## Whether the status row along the top shows: only once STATUS_CARD is stamped.
static func status_shown(save: SaveGame) -> bool:
	return save.stamped.has(STATUS_CARD)


## The STAGES sprite of a square grown `grown` of `ripe` seconds: 0 just planted, the last near ripe.
static func growth_stage(grown: float, ripe: float) -> int:
	return clampi(floori(grown / ripe * STAGES.size()), 0, STAGES.size() - 1)


## Whether a cabbage dragged `offset` px from where it was grabbed comes out of the ground.
static func pulled_out(offset: Vector2) -> bool:
	return offset.length() >= PULL_DISTANCE


## How far a cabbage dragged `offset` px leans after the mouse: up to STRAIN at the pop.
static func strain(offset: Vector2) -> Vector2:
	return offset.limit_length(PULL_DISTANCE) * (STRAIN / PULL_DISTANCE)


## The cursor at `point` for `save`, `holding` a seed or a cabbage: see POINT, OPEN_HAND, GRAB.
static func cursor_for(save: SaveGame, point: Vector2, holding: bool) -> Input.CursorShape:
	if holding:
		return GRAB
	if SEED_BOX.has_point(point):
		return OPEN_HAND
	var i := square_at(point)
	if i < 0 or i > save.farm_plots:
		return Input.CURSOR_ARROW
	if i == save.farm_plots:
		return POINT
	return OPEN_HAND if save.farm_growth[i] >= 0.0 and is_ripe(save, i) else Input.CURSOR_ARROW


## Square `i`'s soil sprite (SOILS): the same every time, varying between squares.
static func soil_variant(i: int) -> int:
	return posmod(hash(i * 7919 + 17), SOILS.size())


## The seed crate's sprite at the bottom of SEED_BOX, centred, SEED_SCALE screen px per pixel.
static func crate_rect() -> Rect2:
	var side := Vector2(SEED_CRATE.get_width(), SEED_CRATE.get_height()) * SEED_SCALE
	return Rect2(Vector2(SEED_BOX.get_center().x - side.x * 0.5, SEED_BOX.end.y - side.y), side)


## The pile of seeds, sitting on the crate's rim (one pixel row down into it).
static func pile_rect() -> Rect2:
	var crate := crate_rect()
	var side := Vector2(SEED_PILES[0].get_width(), SEED_PILES[0].get_height()) * SEED_SCALE
	return Rect2(Vector2(crate.position.x, crate.position.y - side.y + SEED_SCALE), side)


## Which pile of seeds shows on the crate for `seeds` seeds: none when empty, 1 for a few, 2 for
## a pack's worth, 3 for a big stock.
static func pile_stage(seeds: int) -> int:
	if seeds <= 0:
		return 0
	return 1 if seeds < PILE_SOME else 2 if seeds < PILE_LOTS else 3


## Where square `r`'s sprites go: centred, the largest whole multiple of PIXEL within SPRITE_FILL
## of the square (149 px squares: 112 px, 7 screen pixels per sprite pixel).
static func sprite_rect(r: Rect2) -> Rect2:
	var side := floorf(r.size.x * SPRITE_FILL / PIXEL) * PIXEL
	return Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func _buy_seeds(pack: int) -> void:
	var save := SaveManager.save
	var price := seed_price(pack, save)
	if save.coins < price:
		$Denied.play()
		_warn(tr("Not enough money for seeds."))
		return
	save.coins -= price
	save.farm_seeds += SEED_PACKS[pack][0]
	$Buy.play()
	_say(tr("%d seeds delivered.") % SEED_PACKS[pack][0])


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	_mouse = mouse.position
	_hot = square_at(mouse.position)
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(mouse.position)
		else:
			_release(mouse.position)
		accept_event()
	elif _pull >= 0:
		_drag(mouse.position)
	mouse_default_cursor_shape = int(cursor_for(SaveManager.save, mouse.position, _held or _pull >= 0)) as Control.CursorShape


## The mouse goes down at `point`: pick up a seed, grab a ripe cabbage, or clear the next plot.
func _press(point: Vector2) -> void:
	var save := SaveManager.save
	if SEED_BOX.has_point(point):
		if save.farm_seeds > 0:
			_held = true
			_say(tr("Seed in hand. Let go over an empty square to plant it."))
		else:
			_no_seeds()
		return
	var i := square_at(point)
	if i < 0:
		return
	if i >= save.farm_plots:
		if i > save.farm_plots:
			_warn(tr("Clear the squares in order."))
		elif clear_plot(save):
			$Buy.play()
			SaveManager.log_event("farm", "plot", plot_price_of(i), "coins")
			_say(tr("Square cleared."))
		else:
			$Denied.play()
			_warn(tr("Not enough money."))
		return
	if save.farm_growth[i] >= 0.0 and is_ripe(save, i):
		_pull = i
		_snap = -1
		_grip = point
		_tug = Vector2.ZERO
		$Grip.play()
	elif save.farm_growth[i] == EMPTY:
		_warn(tr("Drag a seed from the box onto an empty square."))


## The mouse moves to `point` while pulling: the cabbage strains after it and pops out past
## PULL_DISTANCE (with storage full it springs back instead).
func _drag(point: Vector2) -> void:
	var save := SaveManager.save
	if _pull >= save.farm_growth.size() or save.farm_growth[_pull] < 0.0 or not is_ripe(save, _pull):
		_pull = -1  # A tractor got there first.
		return
	_tug = point - _grip
	if not pulled_out(_tug):
		return
	var i := _pull
	_pull = -1
	if not storage_room(save):
		$Denied.play()
		_warn(tr("Storage full (%d units). Sell some first.") % save.storage_cap)
		_spring_back(i)
		return
	_burst(square(i).get_center() + strain(_tug))
	_tug = Vector2.ZERO
	$Harvest.play()
	_say(tr("Harvested: +%d cabbages to stock.") % harvest(save, i))


## The mouse goes up at `point`: a held seed is planted on an empty square or flies back into the
## box; a cabbage not pulled out yet springs back.
func _release(point: Vector2) -> void:
	if _pull >= 0:
		_spring_back(_pull)
		_pull = -1
		_warn(tr("Grab the cabbage and yank it off its square."))
	if not _held:
		return
	_held = false
	var save := SaveManager.save
	var i := square_at(point)
	if i >= 0 and i < save.farm_plots and save.farm_growth[i] == EMPTY and plant(save, i):
		$Plant.play()
		_say(tr("Planted. Ripe in %d s.") % grow_time(save))
		return
	_flying = true
	_fly = point
	var back := create_tween()
	back.tween_property(self, "_fly", SEED_BOX.get_center(), SEED_BACK).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	back.tween_callback(func() -> void: _flying = false)
	_say(tr("Seed back in the box."))


## Square `i`'s cabbage springs back into the ground from where it was pulled to.
func _spring_back(i: int) -> void:
	_snap = i
	var snap := create_tween()
	snap.tween_property(self, "_tug", Vector2.ZERO, SNAP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	snap.tween_callback(func() -> void: _snap = -1)


## The cabbage pops out at `at`: bits of leaf and soil fly.
func _burst(at: Vector2) -> void:
	_bits.clear()
	for k in BURST_BITS:
		_bits.append([at, Vector2.from_angle(randf_range(PI, TAU)) * randf_range(140.0, 380.0), k % 2 == 0])
	_burst_left = BURST_TIME


func _no_seeds() -> void:
	$Denied.play()
	_seed_blink = SEED_BLINK
	_held = false
	_warn(tr("No seeds. Buy a pack under the seed box."))


func _say(text: String) -> void:
	_msg = text


## A warning (no seeds, no money, storage full, a wrong click): said on the hint line, which shakes
## so it gets read.
func _warn(text: String) -> void:
	_say(text)
	_shake = SHAKE_TIME


func _refresh(save: SaveGame) -> void:
	for i in _seed_buttons.size():
		var price := seed_price(i, save)
		(_seed_buttons[i].get_node("Row/Price") as Label).text = "%d×  $%d" % [SEED_PACKS[i][0], price]
		_seed_buttons[i].modulate.a = 1.0 if save.coins >= price else 0.55


func _draw() -> void:
	var save := SaveManager.save
	var blink := blink_on(_seed_blink)
	draw_rect(Rect2(Vector2.ZERO, SIZE), GLASS)
	if status_shown(save):  # Top: seeds and cabbages left, money right.
		var seeds := tr("SEEDS %d") % save.farm_seeds
		draw_string(_font, Vector2(36, 52), seeds, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, DENIED_RED if blink else PHOSPHOR)
		var after := 36.0 + _font.get_string_size(seeds + "   ", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		draw_string(_font, Vector2(after, 52), tr("CABBAGES %d/%d") % [save.stock, save.storage_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, PHOSPHOR)
		draw_string(_font, Vector2(0, 52), "$ %s" % _thousands(save.coins), HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 36, 32, PHOSPHOR)
		draw_line(Vector2(36, 66), Vector2(SIZE.x - 36, 66), LINE, 2.0)
	for i in MAX_PLOTS:
		_draw_square(save, i)
	_draw_yard(save, blink)
	for w in _workers:
		_draw_worker(w)
	if _pull >= 0 or _snap >= 0:  # On top of its neighbours while it strains.
		_draw_cabbage(save, _pull if _pull >= 0 else _snap)
	if _burst_left > 0.0:
		var fade := _burst_left / BURST_TIME
		for bit: Array in _bits:
			var ink: Color = CABBAGE if bit[2] else SOIL_INK
			draw_rect(Rect2(bit[0] - Vector2(4, 4), Vector2(8, 8) * (0.5 + fade * 0.5)), Color(ink, fade))
	if _held:
		draw_texture(SEED_SPRITE, _mouse - SEED_SPRITE.get_size() * 0.5)
	elif _flying:
		draw_texture(SEED_SPRITE, _fly - SEED_SPRITE.get_size() * 0.5)
	var msg := tr(_msg) % [roundi(grow_time(save)), yield_of(save)] if _msg == OPENING else tr(_msg)
	draw_string(_font, Vector2(36 + shake_offset(_shake), SIZE.y - 30), msg, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 72, msg_size(_font, msg, SIZE.x - 72), PHOSPHOR)


func _draw_square(save: SaveGame, i: int) -> void:
	var r := square(i)
	var mid := r.get_center().y
	if i >= save.farm_plots:
		var next := i == save.farm_plots
		draw_rect(r, Color(0.14, 0.15, 0.13) if next and i == _hot else Color(0.1, 0.11, 0.1))
		for k in range(0, int(r.size.x * 2), 12):
			var a := r.position + Vector2(k, 0)
			var b := r.position + Vector2(k - r.size.y, r.size.y)
			draw_line(a.clamp(r.position, r.end), b.clamp(r.position, r.end), Color(0.15, 0.17, 0.15), 4.0)
		if next:
			draw_rect(r, LINE, false, 2.0)
		var ink := DIM if next else LINE
		draw_string(_font, Vector2(r.position.x, mid - 6), tr("CLEAR A PLOT") if next else tr("LOCKED"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, ink)
		draw_string(_font, Vector2(r.position.x, mid + 22), "$%s" % _thousands(plot_price_of(i)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, ink)
		return
	var grown: float = save.farm_growth[i]
	var open := grown == EMPTY
	draw_rect(r, SOIL_HI if i == _hot and (_held or not open) else SOIL)
	draw_rect(r, PHOSPHOR if open and _held and i == _hot else LINE, false, 2.0)
	# Bare soil, brighter under a seed about to go in.
	var lit := open and _held and i == _hot
	draw_texture_rect(SOILS[soil_variant(i)], sprite_rect(r), false, Color(1.35, 1.35, 1.3) if lit else Color.WHITE)
	if open:
		return
	var ripe := grow_time(save)
	if grown < ripe:
		draw_texture_rect(STAGES[growth_stage(grown, ripe)], sprite_rect(r), false)
		var bar := Rect2(r.position + Vector2(10, r.size.y - 14), Vector2(r.size.x - 20, 6))
		draw_rect(bar, LINE)
		draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * grown / ripe / 6.0) * 6.0, bar.size.y)), DIM)
	elif i != _pull and i != _snap:
		_draw_cabbage(save, i)


## Square `i`'s ripe cabbage, leaning and stretched toward the mouse while it is pulled.
func _draw_cabbage(save: SaveGame, i: int) -> void:
	var r := square(i)
	var lean := strain(_tug) if i == _pull or i == _snap else Vector2.ZERO
	var k := lean.length() / STRAIN * STRETCH
	var turn := lean.angle()
	var stretch := Transform2D(0.0, Vector2(1.0 + k, 1.0 - k * 0.5), 0.0, Vector2.ZERO)
	var place := Transform2D(turn, r.get_center() + lean) * stretch * Transform2D(-turn, Vector2.ZERO)
	draw_set_transform_matrix(place)
	var sprite := sprite_rect(r)
	draw_texture_rect(CABBAGE_SPRITE, Rect2(-sprite.size * 0.5, sprite.size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if i != _pull:
		draw_string(_font, r.position + Vector2(0, 20), "x%d " % yield_of(save), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4, 22, PHOSPHOR)


## The yard (idle workers stand here) and the seed box at its bottom.
func _draw_yard(save: SaveGame, blink: bool) -> void:
	var yard := Rect2(YARD.position, Vector2(YARD.size.x, SEED_BOX.position.y - YARD.position.y - 12))
	draw_rect(yard, Color(0.08, 0.1, 0.09))
	draw_rect(yard, LINE, false, 2.0)
	draw_string(_font, yard.position + Vector2(10, 22), tr("YARD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DIM)
	# The seed crate, its pile of seeds on top (smaller as they run out), the count on its label.
	var hot := SEED_BOX.has_point(_mouse)
	var tint := Color(1.6, 0.55, 0.5) if blink else (Color(1.3, 1.3, 1.25) if hot or _held else Color.WHITE)
	var crate := crate_rect()
	var stage := pile_stage(save.farm_seeds - (1 if _held or _flying else 0))
	if stage > 0:
		draw_texture_rect(SEED_PILES[stage - 1], pile_rect(), false, tint)
	draw_texture_rect(SEED_CRATE, crate, false, tint)
	var label := Rect2(crate.position + Vector2(6, 4) * SEED_SCALE, Vector2(20, 5) * SEED_SCALE)
	draw_string(_font, Vector2(label.position.x, label.get_center().y + 8), tr("SEEDS %d") % save.farm_seeds, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, 22, DENIED_RED if blink else CRATE_INK)


## A farm hand (a glove: open, carrying seeds, pressing one in; it bobs as it goes) or a tractor
## (facing the way it drives, wheels turning, shuddering while it harvests), at whole pixels.
func _draw_worker(w: Worker) -> void:
	var at := w.pos
	var tex: Texture2D
	var px := TRACTOR_PIXEL if w.tractor else WORKER_PIXEL
	if w.tractor:
		tex = TRACTOR_SPRITES[(2 if w.left else 0) + worker_frame(w.walked)]
		if w.busy > 0.0:
			at.y -= px * (floori(w.busy * 10.0) % 2)
	else:
		tex = HAND_PRESS if w.busy > 0.0 else HAND_CARRY if w.seeds > 0 else HAND_OPEN
		at.y -= px * worker_frame(w.walked)
	var side := tex.get_size() * px
	draw_texture_rect(tex, Rect2((at - side * 0.5).round(), side), false)


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
